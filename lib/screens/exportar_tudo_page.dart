import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/exportacao_paciente.dart';
import '../providers/service_providers.dart';
import '../services/pdf_export_service.dart';
import '../utils/mentall_colors.dart';
import '../utils/raio.dart';
import '../utils/tipografia.dart';

/// Resumo do acervo exibido antes de gerar a exportação completa.
class ResumoExportacaoCompleta {
  final int pacientes;
  final int ativos;
  final int sessoes;
  final int contratos;
  final int anamneses;

  const ResumoExportacaoCompleta({
    required this.pacientes,
    required this.ativos,
    required this.sessoes,
    required this.contratos,
    required this.anamneses,
  });
}

/// Exporta tudo em PDF (Fase 5Q): prontuário/documentos consolidados + resumo
/// financeiro em arquivo separado.
///
/// É a forma de "utilização posterior" fora do app: o PDF é legível/arquivável.
/// NÃO substitui o backup cifrado (único formato restaurável) e os PDFs não são
/// cifrados — a tela avisa isso e exige autenticação local antes de gerar.
class ExportarTudoPage extends ConsumerStatefulWidget {
  const ExportarTudoPage({
    super.key,
    this.resumo,
    this.exportar,
    this.autenticar,
  });

  /// Injetáveis nos testes; em produção usam os serviços do app.
  final ResumoExportacaoCompleta Function()? resumo;
  final Future<void> Function()? exportar;
  final Future<bool> Function()? autenticar;

  @override
  ConsumerState<ExportarTudoPage> createState() => _ExportarTudoPageState();
}

class _ExportarTudoPageState extends ConsumerState<ExportarTudoPage> {
  late final ResumoExportacaoCompleta _resumo;
  bool _processando = false;
  bool _exportado = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _resumo = (widget.resumo ?? _resumoDosServicos)();
  }

  ResumoExportacaoCompleta _resumoDosServicos() {
    final pacientes = ref.read(pacienteServiceProvider).listarPacientes();
    final sessoes = ref.read(sessaoServiceProvider).listarTodasSessoes();
    final contratoService = ref.read(contratoServiceProvider);
    final anamneseService = ref.read(anamneseEnviadaServiceProvider);
    var contratos = 0;
    var anamneses = 0;
    for (final paciente in pacientes) {
      if (contratoService.obterPorPaciente(paciente.id) != null) contratos++;
      final anamnese = anamneseService.obterPorPaciente(paciente.id);
      if (anamnese != null && anamnese.isRespondido) anamneses++;
    }
    return ResumoExportacaoCompleta(
      pacientes: pacientes.length,
      ativos: pacientes.where((p) => p.ativo).length,
      sessoes: sessoes.where((s) => s.estaAtiva).length,
      contratos: contratos,
      anamneses: anamneses,
    );
  }

  Future<void> _exportarPadrao() async {
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
    if (perfil == null) {
      throw StateError('Perfil profissional não preenchido.');
    }
    final pacientes = ref.read(pacienteServiceProvider).listarPacientes();
    final sessoes = ref.read(sessaoServiceProvider).listarTodasSessoes();
    final contratoService = ref.read(contratoServiceProvider);
    final anamneseService = ref.read(anamneseEnviadaServiceProvider);
    final config = ref.read(configuracoesServiceProvider);
    final itens = <ExportacaoPaciente>[
      for (final paciente in pacientes)
        ExportacaoPaciente(
          paciente: paciente,
          sessoes: sessoes
              .where((s) => s.pacienteId == paciente.id)
              .toList(growable: false),
          contrato: contratoService.obterPorPaciente(paciente.id),
          anamnese: anamneseService.obterPorPaciente(paciente.id),
        ),
    ];
    await PdfExportService().exportarTudoEmPdf(
      perfil: perfil,
      pacientes: itens,
      todasSessoes: sessoes,
      contratoTemplate: config.contratoTemplate,
    );
  }

  Future<bool> _autenticar() async {
    final autenticar = widget.autenticar;
    if (autenticar != null) return autenticar();
    final authService = ref.read(authServiceProvider);
    if (authService.desbloqueado) return true;
    if (!authService.requerAutenticacao) return true;
    final biometriaOk = await authService.desbloquearComBiometria();
    if (biometriaOk) return true;
    if (!mounted) return false;
    return _solicitarPin();
  }

  Future<bool> _solicitarPin() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Autenticação necessária'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Digite seu PIN para autorizar a exportação dos dados clínicos:',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'PIN',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (result != true) {
      controller.dispose();
      return false;
    }
    final pin = controller.text.trim();
    controller.dispose();
    if (pin.isEmpty) return false;
    return ref.read(authServiceProvider).validarPin(pin);
  }

  Future<void> _exportar() async {
    if (_processando) return;
    setState(() {
      _processando = true;
      _erro = null;
    });

    final autorizado = await _autenticar();
    if (!autorizado) {
      if (!mounted) return;
      setState(() {
        _processando = false;
        _erro = 'Autenticação necessária para exportar dados clínicos.';
      });
      return;
    }

    try {
      final acao = widget.exportar ?? _exportarPadrao;
      await acao();
      if (!mounted) return;
      setState(() {
        _processando = false;
        _exportado = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'PDFs gerados: prontuário consolidado e resumo financeiro.',
          ),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _processando = false;
        _erro = 'Não foi possível gerar os PDFs. Tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.corFundo,
      appBar: AppBar(
        title: const Text('Exportar tudo em PDF'),
        backgroundColor: context.corFundo,
        foregroundColor: context.corPrimaria,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _card(
              context,
              titulo: 'O que será exportado',
              icone: Icons.inventory_2_outlined,
              filhos: [
                _linhaResumo(
                  context,
                  'Pacientes',
                  '${_resumo.pacientes} (${_resumo.ativos} ativos)',
                ),
                _linhaResumo(context, 'Sessões ativas', '${_resumo.sessoes}'),
                _linhaResumo(context, 'Contratos', '${_resumo.contratos}'),
                _linhaResumo(
                  context,
                  'Anamneses respondidas',
                  '${_resumo.anamneses}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _card(
              context,
              titulo: 'Como o PDF é montado',
              icone: Icons.picture_as_pdf_outlined,
              filhos: [
                _paragrafo(
                  context,
                  'Prontuário consolidado (arquivo 1): capa, índice, modelo do '
                  'acordo terapêutico e, por paciente, dados cadastrais, '
                  'contrato (status e aceite), anamnese respondida e todas as '
                  'sessões ativas.',
                ),
                _paragrafo(
                  context,
                  'Resumo financeiro (arquivo 2): histórico por mês com '
                  'recebido, a receber, convênio e pacote.',
                ),
                _paragrafo(
                  context,
                  'Os dois arquivos são abertos juntos no compartilhamento do '
                  'sistema — você escolhe onde salvar (Drive, arquivos, e-mail '
                  'etc.).',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _card(
              context,
              titulo: 'Atenção: dados sensíveis',
              icone: Icons.warning_amber_outlined,
              corIcone: context.corWarning,
              filhos: [
                _paragrafo(
                  context,
                  'Os PDFs NÃO são cifrados e contêm dados clínicos. Guarde-os '
                  'em local seguro e compartilhe só com quem deve ter acesso.',
                ),
                _paragrafo(
                  context,
                  'Para restauração/portabilidade (voltar os dados para o app '
                  'depois), use o backup cifrado em "Backup e dados" — o PDF '
                  'não substitui o backup.',
                ),
              ],
            ),
            if (_erro != null) ...[
              const SizedBox(height: 12),
              Text(
                _erro!,
                style: TextStyle(
                  color: context.corError,
                  fontSize: Tipografia.smMd,
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('botao_exportar_tudo'),
              onPressed: _processando ? null : _exportar,
              icon: _processando
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.corOnPrimaria,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: Text(
                _processando ? 'Gerando PDFs...' : 'Exportar tudo em PDF',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Raio.lg),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Autenticação local (biometria ou PIN) é exigida antes de gerar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: Tipografia.xs,
                color: context.corTextoMuted,
              ),
            ),
            if (_exportado) ...[
              const SizedBox(height: 12),
              Text(
                'Exportação concluída. Se o compartilhamento foi fechado sem '
                'salvar, toque no botão novamente para gerar os arquivos.',
                style: TextStyle(
                  fontSize: Tipografia.sm,
                  color: context.corSuccess,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _linhaResumo(BuildContext context, String rotulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              rotulo,
              style: TextStyle(
                fontSize: Tipografia.sm,
                color: context.corTextoSecondary,
              ),
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: Tipografia.sm,
              fontWeight: FontWeight.w700,
              color: context.corTextoHeading,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paragrafo(BuildContext context, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: Tipografia.sm,
          color: context.corTextoSecondary,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required String titulo,
    required IconData icone,
    required List<Widget> filhos,
    Color? corIcone,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Raio.xxl),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, size: 20, color: corIcone ?? context.corPrimaria),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: TextStyle(
                      fontSize: Tipografia.md,
                      fontWeight: FontWeight.bold,
                      color: context.corTextoHeading,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...filhos,
          ],
        ),
      ),
    );
  }
}
