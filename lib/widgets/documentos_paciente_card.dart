import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

import '../models/compromisso.dart';
import '../models/documento_emitido.dart';
import '../models/paciente.dart';
import '../models/perfil_profissional.dart';
import '../models/sessao.dart';
import '../providers/service_providers.dart';
import '../services/exportacao_arquivos.dart';
import '../services/pdf_export_service.dart';
import '../utils/documentos.dart';
import '../utils/mentall_colors.dart';
import '../utils/raio.dart';
import '../utils/tipografia.dart';
import 'mentall_card.dart';

/// Card de documentos do paciente: declaração de comparecimento, comprovante de
/// pagamento, informe anual e arquivo de lote do Receita Saúde.
class DocumentosPacienteCard extends ConsumerStatefulWidget {
  const DocumentosPacienteCard({
    super.key,
    required this.paciente,
    required this.termoSingular,
  });

  final Paciente paciente;
  final String termoSingular;

  @override
  ConsumerState<DocumentosPacienteCard> createState() =>
      _DocumentosPacienteCardState();
}

class _DocumentosPacienteCardState
    extends ConsumerState<DocumentosPacienteCard> {
  List<DocumentoEmitido> _documentos = const [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    if (!mounted) return;
    try {
      final service = ref.read(documentoFiscalServiceProvider);
      setState(() {
        _documentos = service.listarPorPaciente(widget.paciente.id);
      });
    } catch (_) {
      // Em testes/ambientes sem a box aberta: card continua funcional vazio.
      setState(() => _documentos = const []);
    }
  }

  PerfilProfissional? get _perfil =>
      ref.read(perfilProfissionalServiceProvider).obterPerfil();

  List<Sessao> get _sessoes =>
      ref.read(sessaoServiceProvider).listarSessoesDoPaciente(widget.paciente.id);

  List<Sessao> get _sessoesPagas => _sessoes
      .where((s) =>
          s.statusPagamento == 'pago' &&
          s.dataPagamento != null &&
          s.valorSessao > 0)
      .toList()
    ..sort((a, b) => (b.dataPagamento ?? b.data)
        .compareTo(a.dataPagamento ?? a.data));

  void _snack(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }

  String _data(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _hora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  ({String entrada, String saida}) _horariosDaSessao(Sessao sessao) {
    try {
      final box = Hive.box<Compromisso>('compromissos');
      for (final compromisso in box.values) {
        if (compromisso.sessaoId == sessao.id) {
          return (
            entrada: _hora(compromisso.dataHoraInicio),
            saida: _hora(compromisso.dataHoraFim),
          );
        }
      }
    } catch (_) {
      // Sem compromisso vinculado: usa horário estimado da sessão.
    }
    return (
      entrada: _hora(sessao.data),
      saida: _hora(sessao.data.add(const Duration(minutes: 50))),
    );
  }

  String _localPadrao(PerfilProfissional perfil) {
    for (final endereco in perfil.enderecosConsultorios) {
      final cidade = endereco.cidade.trim();
      final estado = endereco.estado.trim();
      if (cidade.isNotEmpty) {
        return estado.isEmpty ? cidade : '$cidade/$estado';
      }
    }
    return '';
  }

  Future<DocumentoEmitido?> _registrar({
    required String tipo,
    required int ano,
    required Map<String, dynamic> snapshot,
    required String hash,
  }) async {
    final service = ref.read(documentoFiscalServiceProvider);
    try {
      final doc = await service.registrar(
        pacienteId: widget.paciente.id,
        tipo: tipo,
        ano: ano,
        snapshotJson: jsonEncode(snapshot),
        hashConteudo: hash,
      );
      _carregar();
      return doc;
    } catch (erro) {
      _snack('Não foi possível registrar o documento: $erro');
      return null;
    }
  }

  // -- declaração de comparecimento -------------------------------------
  Future<void> _declaracao() async {
    final perfil = _perfil;
    if (perfil == null) {
      _snack('Preencha o perfil profissional primeiro.');
      return;
    }
    final sessoes = _sessoes
      ..sort((a, b) => b.data.compareTo(a.data));
    if (sessoes.isEmpty) {
      _snack('Cadastre ao menos uma sessão para emitir a declaração.');
      return;
    }

    final sessaoEscolhida = ValueNotifier<Sessao>(sessoes.first);
    final horarios = _horariosDaSessao(sessoes.first);
    final entradaController = TextEditingController(text: horarios.entrada);
    final saidaController = TextEditingController(text: horarios.saida);
    final localController = TextEditingController(text: _localPadrao(perfil));
    final gerar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Declaração de comparecimento'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Documento para comprovação junto ao empregador. Não inclui '
                    'diagnóstico, CID ou conteúdo clínico.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Sessao>(
                    initialValue: sessaoEscolhida.value,
                    decoration: const InputDecoration(
                      labelText: 'Sessão',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final sessao in sessoes.take(30))
                        DropdownMenuItem(
                          value: sessao,
                          child: Text(_data(sessao.data)),
                        ),
                    ],
                    onChanged: (valor) {
                      if (valor == null) return;
                      sessaoEscolhida.value = valor;
                      final h = _horariosDaSessao(valor);
                      entradaController.text = h.entrada;
                      saidaController.text = h.saida;
                      setDialogState(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: entradaController,
                          decoration: const InputDecoration(
                            labelText: 'Entrada (HH:mm)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: saidaController,
                          decoration: const InputDecoration(
                            labelText: 'Saída (HH:mm)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: localController,
                    decoration: const InputDecoration(
                      labelText: 'Local (cidade/UF)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Gerar PDF'),
            ),
          ],
        ),
      ),
    );
    if (gerar != true) return;

    final entrada = entradaController.text.trim();
    final saida = saidaController.text.trim();
    final regexHora = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
    if (!regexHora.hasMatch(entrada) || !regexHora.hasMatch(saida)) {
      _snack('Informe os horários no formato HH:mm.');
      return;
    }
    final sessao = sessaoEscolhida.value;
    final local = localController.text.trim();
    final hash = ref
        .read(documentoFiscalServiceProvider)
        .calcularHash(jsonEncode({
          'tipo': 'declaracao_comparecimento',
          'paciente': widget.paciente.id,
          'data': sessao.data.toIso8601String(),
          'entrada': entrada,
          'saida': saida,
          'local': local,
        }));
    final doc = await _registrar(
      tipo: 'declaracao_comparecimento',
      ano: sessao.data.year,
      snapshot: {
        'data': sessao.data.toIso8601String(),
        'entrada': entrada,
        'saida': saida,
        'local': local,
        'sessaoId': sessao.id,
      },
      hash: hash,
    );
    if (doc == null) return;
    try {
      await PdfExportService().exportarDeclaracaoComparecimento(
        paciente: widget.paciente,
        perfil: perfil,
        data: sessao.data,
        horaEntrada: entrada,
        horaSaida: saida,
        local: local,
        numero: doc.numero,
        codigo: doc.codigo,
        hash: hash,
      );
    } catch (erro) {
      _snack('Não foi possível gerar a declaração: $erro');
    }
  }

  // -- arquivo Receita Saúde --------------------------------------------
  Future<void> _arquivoReceitaSaude() async {
    final perfil = _perfil;
    if (perfil == null) {
      _snack('Preencha o perfil profissional primeiro.');
      return;
    }
    final agora = DateTime.now();
    var mes = agora.month;
    var ano = agora.year;
    final service = ref.read(documentoFiscalServiceProvider);

    final gerar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final inclusas =
              service.sessoesPagasNoPeriodo(_sessoes, mes: mes, ano: ano);
          final total = inclusas.fold<double>(0, (s, x) => s + x.valorSessao);
          final faltando = <String>[
            if (Documentos.limpar(perfil.cpf).length != 11)
              'CPF do profissional',
            if (Documentos.limpar(widget.paciente.cpf).length != 11)
              'CPF do paciente',
          ];
          return AlertDialog(
            title: const Text('Arquivo Receita Saúde (lote)'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gera o CSV no leiaute oficial para importar em e-CAC → '
                      'Carnê-Leão → Escrituração → Importar Escrituração. '
                      'O recibo oficial é emitido pelo Receita Saúde.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: mes,
                            decoration: const InputDecoration(
                              labelText: 'Mês',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (var m = 1; m <= 12; m++)
                                DropdownMenuItem(
                                  value: m,
                                  child: Text(m.toString().padLeft(2, '0')),
                                ),
                            ],
                            onChanged: (v) {
                              if (v != null) setDialogState(() => mes = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: ano,
                            decoration: const InputDecoration(
                              labelText: 'Ano',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (var a = agora.year - 3; a <= agora.year; a++)
                                DropdownMenuItem(value: a, child: Text('$a')),
                            ],
                            onChanged: (v) {
                              if (v != null) setDialogState(() => ano = v);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${inclusas.length} sessão(ões) paga(s) · '
                      'total R\$ ${total.toStringAsFixed(2).replaceAll('.', ',')}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (faltando.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Falta preencher: ${faltando.join(' e ')}.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: inclusas.isEmpty || faltando.isNotEmpty
                    ? null
                    : () => Navigator.pop(ctx, true),
                child: const Text('Gerar arquivo'),
              ),
            ],
          );
        },
      ),
    );
    if (gerar != true) return;

    final resultado = service.gerarArquivoReceitaSaude(
      perfil: perfil,
      paciente: widget.paciente,
      todasSessoes: _sessoes,
      mes: mes,
      ano: ano,
    );
    if (!resultado.valido) {
      _snack(resultado.erros.join(' '));
      return;
    }
    final hash = service.calcularHash(resultado.conteudo);
    final doc = await _registrar(
      tipo: 'arquivo_receita_saude',
      ano: ano,
      snapshot: {
        'mes': mes,
        'ano': ano,
        'sessoes': [
          for (final s in resultado.sessoesIncluidas)
            {
              'id': s.id,
              'dataPagamento': s.dataPagamento?.toIso8601String(),
              'valor': s.valorSessao,
            }
        ],
        'total': resultado.total,
      },
      hash: hash,
    );
    if (doc == null) return;
    final nome = 'receita_saude_${mes.toString().padLeft(2, '0')}_$ano.csv';
    try {
      await compartilharTexto(
        nome: nome,
        conteudo: resultado.conteudo,
        mimeType: 'text/csv',
        subject: 'MentAll PRO — arquivo Receita Saúde $mes/$ano',
      );
      _snack('Arquivo $nome gerado e enviado para compartilhamento.');
    } catch (erro) {
      _snack('Não foi possível compartilhar o arquivo: $erro');
    }
  }

  // -- informe anual -----------------------------------------------------
  Future<void> _informe() async {
    final perfil = _perfil;
    if (perfil == null) {
      _snack('Preencha o perfil profissional primeiro.');
      return;
    }
    final pagas = _sessoesPagas;
    if (pagas.isEmpty) {
      _snack('Nenhuma sessão paga registrada.');
      return;
    }
    final anos = pagas
        .map((s) => s.dataPagamento!.year)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    var ano = anos.first;
    final gerar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Informe de pagamentos'),
          content: DropdownButtonFormField<int>(
            initialValue: ano,
            decoration: const InputDecoration(
              labelText: 'Ano',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final a in anos) DropdownMenuItem(value: a, child: Text('$a')),
            ],
            onChanged: (v) {
              if (v != null) setDialogState(() => ano = v);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Gerar PDF'),
            ),
          ],
        ),
      ),
    );
    if (gerar != true) return;
    final sessoesAno = pagas.where((s) => s.dataPagamento!.year == ano).toList();
    final hash = ref.read(documentoFiscalServiceProvider).calcularHash(jsonEncode({
      'tipo': 'informe_pagamentos',
      'ano': ano,
      'sessoes': [for (final s in sessoesAno) s.id],
      'total': sessoesAno.fold<double>(0, (a, b) => a + b.valorSessao),
    }));
    final doc = await _registrar(
      tipo: 'informe_pagamentos',
      ano: ano,
      snapshot: {
        'ano': ano,
        'sessoes': [
          for (final s in sessoesAno)
            {'id': s.id, 'data': s.data.toIso8601String(), 'valor': s.valorSessao}
        ],
      },
      hash: hash,
    );
    if (doc == null) return;
    try {
      await PdfExportService().exportarInformePagamentos(
        paciente: widget.paciente,
        perfil: perfil,
        ano: ano,
        sessoesPagas: sessoesAno,
        numero: doc.numero,
        codigo: doc.codigo,
        hash: hash,
      );
    } catch (erro) {
      _snack('Não foi possível gerar o informe: $erro');
    }
  }

  // -- comprovante de pagamento -----------------------------------------
  Future<void> _comprovante() async {
    final perfil = _perfil;
    if (perfil == null) {
      _snack('Preencha o perfil profissional primeiro.');
      return;
    }
    final pagas = _sessoesPagas;
    if (pagas.isEmpty) {
      _snack('Nenhuma sessão paga registrada.');
      return;
    }
    var sessao = pagas.first;
    final gerar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Comprovante de pagamento'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<Sessao>(
                  initialValue: sessao,
                  decoration: const InputDecoration(
                    labelText: 'Sessão paga',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final s in pagas.take(40))
                      DropdownMenuItem(
                        value: s,
                        child: Text(
                          '${_data(s.dataPagamento ?? s.data)} — '
                          'R\$ ${s.valorSessao.toStringAsFixed(2).replaceAll('.', ',')}',
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => sessao = v);
                  },
                ),
                const SizedBox(height: 10),
                const Text(
                  'Comprovante interno (não fiscal). O documento fiscal oficial é '
                  'o recibo do Receita Saúde (PF) ou a NFS-e (PJ/CNPJ).',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Gerar PDF'),
            ),
          ],
        ),
      ),
    );
    if (gerar != true) return;
    final hash = ref.read(documentoFiscalServiceProvider).calcularHash(jsonEncode({
      'tipo': 'comprovante_pagamento',
      'sessao': sessao.id,
      'valor': sessao.valorSessao,
      'dataPagamento': sessao.dataPagamento?.toIso8601String(),
    }));
    final doc = await _registrar(
      tipo: 'comprovante_pagamento',
      ano: (sessao.dataPagamento ?? sessao.data).year,
      snapshot: {
        'sessaoId': sessao.id,
        'data': sessao.data.toIso8601String(),
        'dataPagamento': sessao.dataPagamento?.toIso8601String(),
        'valor': sessao.valorSessao,
      },
      hash: hash,
    );
    if (doc == null) return;
    try {
      await PdfExportService().exportarComprovantePagamento(
        paciente: widget.paciente,
        perfil: perfil,
        sessao: sessao,
        numero: doc.numero,
        codigo: doc.codigo,
        hash: hash,
      );
    } catch (erro) {
      _snack('Não foi possível gerar o comprovante: $erro');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MentAllCard(
      borderRadius: Raio.xxl,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_shared_outlined,
                  color: context.corPrimaria, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Documentos',
                  style: TextStyle(
                    fontSize: Tipografia.md,
                    fontWeight: FontWeight.w700,
                    color: context.corTextoHeading,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Declarações, comprovantes e arquivo do Receita Saúde. '
            'Documentos fiscais oficiais são emitidos pelo Receita Saúde (PF) '
            'ou pela prefeitura (NFS-e/PJ).',
            style: TextStyle(
              fontSize: Tipografia.sm,
              color: context.corTextoMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          _botao(
            context,
            icon: Icons.event_available_outlined,
            label: 'Declaração de comparecimento',
            onPressed: _declaracao,
          ),
          const SizedBox(height: 8),
          _botao(
            context,
            icon: Icons.receipt_long_outlined,
            label: 'Arquivo Receita Saúde (CSV em lote)',
            onPressed: _arquivoReceitaSaude,
          ),
          const SizedBox(height: 8),
          _botao(
            context,
            icon: Icons.picture_as_pdf_outlined,
            label: 'Comprovante de pagamento',
            onPressed: _comprovante,
          ),
          const SizedBox(height: 8),
          _botao(
            context,
            icon: Icons.summarize_outlined,
            label: 'Informe anual de pagamentos',
            onPressed: _informe,
          ),
          if (_documentos.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(color: context.corBorda),
            Text(
              'Últimos documentos emitidos',
              style: TextStyle(
                fontSize: Tipografia.smMd,
                fontWeight: FontWeight.w600,
                color: context.corTextoHeading,
              ),
            ),
            const SizedBox(height: 6),
            for (final doc in _documentos.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 16, color: context.corSuccess),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${doc.tipoExibicao} · ${doc.numeroFormatado}',
                        style: TextStyle(
                          fontSize: Tipografia.sm,
                          color: context.corTextoSecondary,
                        ),
                      ),
                    ),
                    Text(
                      doc.codigo,
                      style: TextStyle(
                        fontSize: Tipografia.xs,
                        color: context.corTextoMuted,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _botao(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(label),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          side: BorderSide(color: context.corBorda),
        ),
      ),
    );
  }
}
