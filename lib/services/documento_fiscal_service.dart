import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:hive_ce/hive.dart';

import '../models/documento_emitido.dart';
import '../models/paciente.dart';
import '../models/perfil_profissional.dart';
import '../models/sessao.dart';
import '../utils/documentos.dart';
import 'encrypted_service_mixin.dart';
import 'encryption_service.dart';

/// Resultado da geração do arquivo de integração do Receita Saúde (lote).
class ResultadoLoteReceitaSaude {
  ResultadoLoteReceitaSaude({
    required this.conteudo,
    required this.erros,
    required this.sessoesIncluidas,
  });

  final String conteudo;
  final List<String> erros;
  final List<Sessao> sessoesIncluidas;

  bool get valido => erros.isEmpty;
  int get quantidade => sessoesIncluidas.length;
  double get total => sessoesIncluidas.fold(0, (s, x) => s + x.valorSessao);
}

/// Documentos fiscais/comprovantes gerados localmente (sem conteúdo clínico).
///
/// O recibo **oficial** para IR de profissional pessoa física é emitido pelo
/// Receita Saúde; este serviço gera o arquivo de lote no leiaute oficial para
/// importação no Carnê-Leão/e-CAC, além de comprovantes/informes internos e
/// declarações de comparecimento.
class DocumentoFiscalService with EncryptedServiceMixin {
  static const String _boxName = 'documentos_emitidos';

  /// Leiaute oficial do arquivo de lote do Receita Saúde (Carnê-Leão).
  static const String codigoRendimento = 'R01.001.001';
  static const String codigoOcupacaoPsicologo = '255';

  @override
  final EncryptionService? encryption;

  DocumentoFiscalService({this.encryption});

  Box<DocumentoEmitido>? get _caixa =>
      Hive.isBoxOpen(_boxName) ? Hive.box<DocumentoEmitido>(_boxName) : null;

  String _encrypt(String value) => encrypt(value);
  String _decrypt(String value) => decrypt(value);

  List<DocumentoEmitido> listarPorPaciente(String pacienteId) {
    final box = _caixa;
    if (box == null) return const [];
    final lista = box.values
        .where((d) => d.pacienteId == pacienteId)
        .map((d) => _lerCopia(d))
        .toList()
      ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
    return lista;
  }

  List<DocumentoEmitido> listarRecentes({int limite = 10}) {
    final box = _caixa;
    if (box == null) return const [];
    final lista = box.values.map(_lerCopia).toList()
      ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
    return lista.take(limite).toList();
  }

  DocumentoEmitido _lerCopia(DocumentoEmitido d) {
    final copia = d.copyWith();
    copia.codigo = _decrypt(copia.codigo);
    copia.hash = _decrypt(copia.hash);
    copia.snapshotJson = _decrypt(copia.snapshotJson);
    return copia;
  }

  int proximoNumero(String tipo, int ano) {
    final box = _caixa;
    if (box == null) return 1;
    var maior = 0;
    for (final d in box.values) {
      if (d.tipo == tipo && d.ano == ano && d.numero > maior) {
        maior = d.numero;
      }
    }
    return maior + 1;
  }

  String gerarCodigo() {
    const alfabeto = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final bruto = List.generate(10, (_) => alfabeto[random.nextInt(alfabeto.length)]).join();
    return '${bruto.substring(0, 5)}-${bruto.substring(5)}';
  }

  String calcularHash(String conteudo) {
    return sha256.convert(utf8.encode(conteudo)).toString();
  }

  Future<DocumentoEmitido> registrar({
    required String pacienteId,
    required String tipo,
    required int ano,
    required String snapshotJson,
    required String hashConteudo,
  }) async {
    final numero = proximoNumero(tipo, ano);
    final doc = DocumentoEmitido(
      id: '${DateTime.now().microsecondsSinceEpoch}-$tipo',
      pacienteId: pacienteId,
      tipo: tipo,
      numero: numero,
      ano: ano,
      criadoEm: DateTime.now(),
      codigo: gerarCodigo(),
      hash: hashConteudo,
      snapshotJson: snapshotJson,
    );
    final box = _caixa;
    if (box == null) {
      throw StateError('Armazenamento de documentos indisponível.');
    }
    final paraSalvar = doc.copyWith();
    paraSalvar.codigo = _encrypt(paraSalvar.codigo);
    paraSalvar.hash = _encrypt(paraSalvar.hash);
    paraSalvar.snapshotJson = _encrypt(paraSalvar.snapshotJson);
    await box.put(paraSalvar.id, paraSalvar);
    return doc;
  }

  /// Formata valor no padrão do arquivo: sem milhar, vírgula decimal.
  String formatarValorArquivo(double valor) {
    final texto = valor.toStringAsFixed(2).replaceAll('.', ',');
    return texto;
  }

  String _dataArquivo(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  /// Sessões pagas de um paciente no mês/ano (base para recibos).
  List<Sessao> sessoesPagasNoPeriodo(
    List<Sessao> sessoes, {
    required int mes,
    required int ano,
  }) {
    final lista = sessoes
        .where((s) =>
            s.statusPagamento == 'pago' &&
            s.dataPagamento != null &&
            s.dataPagamento!.month == mes &&
            s.dataPagamento!.year == ano &&
            s.valorSessao > 0)
        .toList()
      ..sort((a, b) => (a.dataPagamento ?? a.data)
          .compareTo(b.dataPagamento ?? b.data));
    return lista;
  }

  /// Gera o CSV do arquivo de integração do Receita Saúde (lote de recibos).
  ///
  /// Leiaute oficial (Manual Receita Saúde v2.1, pergunta 24): CSV com campos
  /// separados por `;`, 16 campos por linha, até 1000 linhas, todos os
  /// pagamentos do mesmo ano. Não inclui dados clínicos (descrição genérica).
  ResultadoLoteReceitaSaude gerarArquivoReceitaSaude({
    required PerfilProfissional perfil,
    required Paciente paciente,
    required List<Sessao> todasSessoes,
    required int mes,
    required int ano,
  }) {
    final erros = <String>[];
    final cpfProfissional = Documentos.limpar(perfil.cpf);
    if (cpfProfissional.length != 11) {
      erros.add('Informe o CPF do profissional (11 dígitos) no perfil.');
    }
    final cpfPaciente = Documentos.limpar(paciente.cpf);
    if (cpfPaciente.length != 11) {
      erros.add('Informe o CPF do paciente (11 dígitos) no cadastro.');
    }
    final registro = perfil.registroProfissional.trim();
    if (registro.length > 15) {
      erros.add('O registro profissional deve ter no máximo 15 caracteres.');
    }

    final sessoes = sessoesPagasNoPeriodo(todasSessoes, mes: mes, ano: ano);
    if (sessoes.isEmpty) {
      erros.add('Nenhuma sessão paga em '
          '${mes.toString().padLeft(2, '0')}/$ano.');
    }
    if (sessoes.length > 1000) {
      erros.add('O arquivo permite no máximo 1000 recibos por lote.');
    }
    if (erros.isNotEmpty) {
      return ResultadoLoteReceitaSaude(
        conteudo: '',
        erros: erros,
        sessoesIncluidas: const [],
      );
    }

    final linhas = <String>[];
    for (final sessao in sessoes) {
      final data = sessao.dataPagamento!;
      if (data.year != ano) {
        erros.add('Pagamentos de anos diferentes não podem ir no mesmo arquivo.');
        break;
      }
      final descricao = 'Sessão de psicoterapia em ${_dataArquivo(data)}';
      final campos = <String>[
        _dataArquivo(data),
        codigoRendimento,
        codigoOcupacaoPsicologo,
        formatarValorArquivo(sessao.valorSessao),
        '', // valor da dedução (não se aplica)
        descricao.length > 255 ? descricao.substring(0, 255) : descricao,
        'PF',
        cpfPaciente, // CPF do pagador
        cpfPaciente, // CPF do beneficiário do serviço
        '', // ind. CPF não informado
        '', // CNPJ
        '', // indicador de IRRF
        '', // valor IRRF
        'S', // indicador de recibo
        cpfProfissional,
        registro,
      ];
      linhas.add(campos.join(';'));
    }

    if (erros.isNotEmpty) {
      return ResultadoLoteReceitaSaude(
        conteudo: '',
        erros: erros,
        sessoesIncluidas: const [],
      );
    }

    return ResultadoLoteReceitaSaude(
      conteudo: '${linhas.join('\n')}\n',
      erros: const [],
      sessoesIncluidas: sessoes,
    );
  }

  Stream<BoxEvent> observar() =>
      _caixa?.watch() ?? const Stream<BoxEvent>.empty();
}
