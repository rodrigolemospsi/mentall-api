import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/models/documento_emitido.dart';
import 'package:prontuario_tcc/models/paciente.dart';
import 'package:prontuario_tcc/models/perfil_profissional.dart';
import 'package:prontuario_tcc/models/sessao.dart';
import 'package:prontuario_tcc/services/documento_fiscal_service.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';
import 'package:prontuario_tcc/utils/documentos.dart';

const _chaveMestraBase64 = 'MTIzNDU2Nzg5MDEyMzQ1Njc4OTA=';

void main() {
  late EncryptionService encryption;
  late DocumentoFiscalService service;

  setUpAll(() async {
    Hive.init('test/temp_hive/documento_fiscal_service');
    Hive.registerAdapters();
    await Hive.openBox<DocumentoEmitido>('documentos_emitidos');
    await Hive.openBox<String>('app_config');
    await Hive.openBox<String>('auth_meta');
    await Hive.openBox<String>('encryption_meta');
  });

  tearDownAll(() async {
    await Hive.deleteBoxFromDisk('documentos_emitidos');
    await Hive.deleteBoxFromDisk('app_config');
    await Hive.deleteBoxFromDisk('auth_meta');
    await Hive.deleteBoxFromDisk('encryption_meta');
  });

  setUp(() async {
    await Hive.box<DocumentoEmitido>('documentos_emitidos').clear();
    await Hive.box<String>('app_config').clear();
    await Hive.box<String>('auth_meta').clear();
    await Hive.box<String>('encryption_meta').clear();
    final duravel = _MemStorage()
      ..data['aes_master_key_duravel'] = _chaveMestraBase64;
    encryption = EncryptionService(pin: _MemStorage(), duravel: duravel);
    EncryptionService.setInstance(encryption);
    await encryption.inicializar();
    if (!encryption.configurado) await encryption.gerarChave();
    service = DocumentoFiscalService(encryption: encryption);
  });

  PerfilProfissional perfil({String cpf = '11144477735'}) =>
      PerfilProfissional(
        id: 'perf',
        nome: 'Rodrigo Lemos',
        registroProfissional: '06/123456',
        cpf: cpf,
        tratamento: 'masculino',
      );

  Paciente paciente({String cpf = '52998224725'}) =>
      Paciente(id: 'p1', nome: 'Maria Teste', cpf: cpf);

  Sessao sessaoPaga(DateTime pagoEm, {double valor = 250}) => Sessao(
        id: 's-${pagoEm.millisecondsSinceEpoch}',
        pacienteId: 'p1',
        numeroSessao: 1,
        data: pagoEm.subtract(const Duration(days: 1)),
        valorSessao: valor,
        statusPagamento: 'pago',
        dataPagamento: pagoEm,
        metodoPagamento: 'pix',
      );

  group('Arquivo Receita Saúde (lote CSV)', () {
    test('gera linhas no leiaute oficial (16 campos, ;, valores BR)', () {
      final sessoes = [
        sessaoPaga(DateTime(2026, 10, 5), valor: 250),
        sessaoPaga(DateTime(2026, 10, 19), valor: 1234.5),
        // fora do período/sem pagamento: não pode entrar
        sessaoPaga(DateTime(2026, 9, 10)),
        Sessao(
          id: 'pendente',
          pacienteId: 'p1',
          numeroSessao: 2,
          data: DateTime(2026, 10, 1),
          valorSessao: 300,
        ),
      ];
      final resultado = service.gerarArquivoReceitaSaude(
        perfil: perfil(),
        paciente: paciente(),
        todasSessoes: sessoes,
        mes: 10,
        ano: 2026,
      );
      expect(resultado.valido, isTrue);
      expect(resultado.quantidade, 2);
      expect(resultado.total, 1484.5);
      final linhas =
          resultado.conteudo.trim().split('\n').map((l) => l.split(';')).toList();
      expect(linhas.length, 2);
      for (final campos in linhas) {
        expect(campos.length, 16);
        expect(campos[1], 'R01.001.001');
        expect(campos[2], '255');
        expect(campos[6], 'PF');
        expect(campos[7], '52998224725');
        expect(campos[8], '52998224725');
        expect(campos[13], 'S');
        expect(campos[14], '11144477735');
        expect(campos[15], '06/123456');
        expect(campos[4], '');
        expect(campos[9], '');
        expect(campos[10], '');
        expect(campos[11], '');
        expect(campos[12], '');
      }
      expect(linhas[0][0], '05/10/2026');
      expect(linhas[0][3], '250,00');
      expect(linhas[1][3], '1234,50'); // sem separador de milhar
      expect(resultado.conteudo.endsWith('\n'), isTrue);
      // Sem conteúdo clínico na descrição.
      expect(linhas[0][5].toLowerCase(), contains('sessão de psicoterapia'));
    });

    test('CPF ausente bloqueia a geração', () {
      final semCpfPaciente = service.gerarArquivoReceitaSaude(
        perfil: perfil(),
        paciente: paciente(cpf: ''),
        todasSessoes: [sessaoPaga(DateTime(2026, 10, 5))],
        mes: 10,
        ano: 2026,
      );
      expect(semCpfPaciente.valido, isFalse);
      expect(semCpfPaciente.erros.join(' '), contains('CPF do paciente'));

      final semCpfProf = service.gerarArquivoReceitaSaude(
        perfil: perfil(cpf: ''),
        paciente: paciente(),
        todasSessoes: [sessaoPaga(DateTime(2026, 10, 5))],
        mes: 10,
        ano: 2026,
      );
      expect(semCpfProf.valido, isFalse);
      expect(semCpfProf.erros.join(' '), contains('CPF do profissional'));
    });

    test('período sem sessões pagas retorna erro claro', () {
      final resultado = service.gerarArquivoReceitaSaude(
        perfil: perfil(),
        paciente: paciente(),
        todasSessoes: [sessaoPaga(DateTime(2026, 9, 5))],
        mes: 10,
        ano: 2026,
      );
      expect(resultado.valido, isFalse);
      expect(resultado.erros.join(' '), contains('Nenhuma sessão paga'));
    });

    test('formata valor sem milhar e com vírgula', () {
      expect(service.formatarValorArquivo(250), '250,00');
      expect(service.formatarValorArquivo(1234.5), '1234,50');
      expect(service.formatarValorArquivo(0.7), '0,70');
    });
  });

  group('Registro local de documentos', () {
    test('numeração é sequencial por tipo e ano', () async {
      final d1 = await service.registrar(
        pacienteId: 'p1',
        tipo: 'declaracao_comparecimento',
        ano: 2026,
        snapshotJson: jsonEncode({'a': 1}),
        hashConteudo: service.calcularHash('x'),
      );
      final d2 = await service.registrar(
        pacienteId: 'p1',
        tipo: 'declaracao_comparecimento',
        ano: 2026,
        snapshotJson: jsonEncode({'a': 2}),
        hashConteudo: service.calcularHash('y'),
      );
      final outroTipo = await service.registrar(
        pacienteId: 'p1',
        tipo: 'informe_pagamentos',
        ano: 2026,
        snapshotJson: '{}',
        hashConteudo: service.calcularHash('z'),
      );
      expect(d1.numero, 1);
      expect(d2.numero, 2);
      expect(outroTipo.numero, 1);
      expect(d1.numeroFormatado, 'DOC-2026-0001');
    });

    test('snapshot/código/hash ficam cifrados no Hive e legíveis na leitura',
        () async {
      final doc = await service.registrar(
        pacienteId: 'p1',
        tipo: 'comprovante_pagamento',
        ano: 2026,
        snapshotJson: jsonEncode({'cpf': '52998224725', 'valor': 250}),
        hashConteudo: service.calcularHash('conteudo'),
      );
      final bruto =
          Hive.box<DocumentoEmitido>('documentos_emitidos').get(doc.id)!;
      expect(bruto.snapshotJson, isNot(contains('52998224725')));
      expect(bruto.snapshotJson, startsWith('3:'));

      final lido = service.listarPorPaciente('p1').first;
      expect(lido.codigo, doc.codigo);
      expect(lido.snapshotJson, contains('52998224725'));
      expect(jsonDecode(lido.snapshotJson)['valor'], 250);
    });

    test('CPF do paciente e formatadores', () {
      expect(Documentos.formatarCpf('52998224725'), '529.982.247-25');
      expect(Documentos.limpar('529.982.247-25'), '52998224725');
    });
  });
}

class _MemStorage extends FlutterSecureStorage {
  final Map<String, String> data = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.remove(key);
  }
}
