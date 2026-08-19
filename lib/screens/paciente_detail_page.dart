import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/contrato_terapeutico.dart';
import '../models/paciente.dart';
import '../models/perfil_profissional.dart';
import '../models/sessao.dart';
import '../providers/service_providers.dart';
import '../services/pdf_export_service.dart';
import '../utils/mentall_colors.dart';
import '../widgets/escalas_section.dart';
import '../widgets/paciente_financeiro_tab.dart';
import '../widgets/paciente_resumo_tab.dart';
import '../widgets/paciente_sessoes_tab.dart';
import 'sessao_form_page.dart';

final _refreshProvider = StateProvider<int>((ref) => 0);

class PacienteDetailPage extends ConsumerStatefulWidget {
  final Paciente paciente;
  final Sessao? sessaoParaAbrir;

  const PacienteDetailPage({
    super.key,
    required this.paciente,
    this.sessaoParaAbrir,
  });

  @override
  ConsumerState<PacienteDetailPage> createState() => _PacienteDetailPageState();
}

class _PacienteDetailPageState extends ConsumerState<PacienteDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.sessaoParaAbrir != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SessaoFormPage(
              paciente: widget.paciente,
              sessaoExistente: widget.sessaoParaAbrir,
            ),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Term helpers
  // ---------------------------------------------------------------------------

  String get _termoSingular {
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
    return perfil?.termoSingular ?? 'paciente';
  }

  String get _termoSingularCapitalizado {
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
    return perfil?.termoSingularCapitalizado ?? 'Paciente';
  }

  bool get _usaPessoaAtendida => _termoSingular == 'pessoa atendida';

  String get _doOuDa => _usaPessoaAtendida ? 'da' : 'do';

  String get _ativoOuAtiva => _usaPessoaAtendida ? 'ativa' : 'ativo';

  String get _atualizadoOuAtualizada =>
      _usaPessoaAtendida ? 'atualizada' : 'atualizado';

  String get _nomePacienteExibicao {
    final nomeLimpo = widget.paciente.nome.trim();
    if (nomeLimpo.isEmpty) return _termoSingularCapitalizado;
    return nomeLimpo;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    ref.watch(_refreshProvider);

    final totalSessoes = ref
            .watch(sessoesRealizadasPorPacienteProvider(widget.paciente.id))
            .valueOrNull ??
        0;

    return Scaffold(
      backgroundColor: context.corFundo,
      appBar: AppBar(
        title: Text(_nomePacienteExibicao),
        backgroundColor: context.corPrimaria,
        foregroundColor: context.corOnPrimaria,
        bottom: TabBar(
          controller: _tabController,
          labelColor: context.corOnPrimaria,
          unselectedLabelColor: context.corOnPrimaria.withValues(alpha: 0.6),
          indicatorColor: context.corOnPrimaria,
          indicatorWeight: 3,
          tabs: [
            const Tab(text: 'Resumo'),
            Tab(text: 'Sessões ($totalSessoes)'),
            const Tab(text: 'Financeiro'),
          ],
        ),
        actions: _appBarAcoes(),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          PacienteResumoTab(paciente: widget.paciente),
          PacienteSessoesTab(paciente: widget.paciente),
          PacienteFinanceiroTab(paciente: widget.paciente),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AppBar actions
  // ---------------------------------------------------------------------------

  List<Widget> _appBarAcoes() {
    final contratoAtivo =
        ref.watch(contratoPorPacienteProvider(widget.paciente.id)).valueOrNull;
    final contratoArquivado = ref
        .watch(contratoArquivadoPorPacienteProvider(widget.paciente.id))
        .valueOrNull;
    final temContratoAceito = (contratoAtivo != null && contratoAtivo.isAceito) ||
        (contratoArquivado != null && contratoArquivado.isAceito);

    return [
      Semantics(
        label: 'Exportar dados',
        child: IconButton(
          tooltip: 'Exportar',
          icon: const Icon(Icons.file_download_outlined),
          onPressed: _abrirOpcoesExportacao,
        ),
      ),
      Semantics(
        label: 'Editar paciente',
        child: IconButton(
          tooltip: 'Editar $_termoSingular',
          icon: const Icon(Icons.edit_outlined),
          onPressed: _abrirDialogEditarPaciente,
        ),
      ),
      PopupMenuButton<String>(
        tooltip: 'Mais opcoes',
        icon: const Icon(Icons.more_vert),
        onSelected: (value) {
          if (value == 'escalas') {
            _abrirEscalas();
          } else if (value == 'acordo') {
            _abrirDialogoAcordoArquivado(contratoAtivo, contratoArquivado);
          }
        },
        itemBuilder: (_) {
          final items = <PopupMenuItem<String>>[
            PopupMenuItem(
              value: 'escalas',
              child: Row(
                children: [
                  Icon(Icons.analytics_outlined, size: 20, color: context.corPrimaria),
                  const SizedBox(width: 8),
                  const Text('Escalas Psicologicas'),
                ],
              ),
            ),
          ];
          if (temContratoAceito) {
            items.add(PopupMenuItem(
              value: 'acordo',
              child: Row(
                children: [
                  Icon(Icons.description_outlined, size: 20, color: context.corPrimaria),
                  const SizedBox(width: 8),
                  const Text('Acordo Terapeutico'),
                ],
              ),
            ));
          }
          return items;
        },
      ),
    ];
  }

  void _abrirEscalas() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Escalas Psicologicas'),
        content: SizedBox(
          width: double.maxFinite,
          child: EscalasSection(pacienteId: widget.paciente.id),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Edit dialog
  // ---------------------------------------------------------------------------

  Future<void> _abrirDialogEditarPaciente() async {
    final pacienteService = ref.read(pacienteServiceProvider);
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();

    final nomeController = TextEditingController(text: widget.paciente.nome);
    final contatoController =
        TextEditingController(text: widget.paciente.contato);
    final emailController =
        TextEditingController(text: widget.paciente.email);
    final observacoesController =
        TextEditingController(text: widget.paciente.observacoes);

    String tipoAtendimento = widget.paciente.tipoAtendimento.trim().isEmpty
        ? 'Particular'
        : widget.paciente.tipoAtendimento;

    bool ativo = widget.paciente.ativo;
    String fotoBase64 = widget.paciente.fotoBase64;
    String tratamento = widget.paciente.tratamento;

    final opcoesModo = perfil?.opcoesModoAtendimento ?? <String>[];
    String? modoAtendimentoSelecionado =
        widget.paciente.modoAtendimento.trim().isEmpty
            ? null
            : widget.paciente.modoAtendimento.trim();

    final opcoesDropdown = <String>[...opcoesModo];
    if (modoAtendimentoSelecionado != null &&
        !opcoesDropdown.contains(modoAtendimentoSelecionado)) {
      opcoesDropdown.add(modoAtendimentoSelecionado);
    }

    final tiposAtendimentoDisponiveis = <String>{
      'Particular',
      'Convênio',
      'Outro',
      if (tipoAtendimento.trim().isNotEmpty) tipoAtendimento,
    }.toList();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (_, setDialogState) {
            return AlertDialog(
              title: Text('Editar $_termoSingular'),
              content: _dialogEditarPacienteBody(
                nomeController: nomeController,
                contatoController: contatoController,
                emailController: emailController,
                observacoesController: observacoesController,
                tiposAtendimentoDisponiveis: tiposAtendimentoDisponiveis,
                tipoAtendimento: tipoAtendimento,
                ativo: ativo,
                fotoBase64: fotoBase64,
                opcoesModo: opcoesDropdown,
                modoAtendimentoSelecionado: modoAtendimentoSelecionado,
                tratamento: tratamento,
                setDialogState: setDialogState,
                onTipoAlterado: (v) => tipoAtendimento = v,
                onAtivoAlterado: (v) => ativo = v,
                onModoAlterado: (v) => modoAtendimentoSelecionado = v,
                onTratamentoAlterado: (v) => tratamento = v,
                onFotoAlterada: (v) => fotoBase64 = v,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    final nome = nomeController.text.trim();
                    if (nome.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Informe o nome $_doOuDa $_termoSingular.',
                          ),
                        ),
                      );
                      return;
                    }
                    widget.paciente.nome = nome;
                    widget.paciente.contato = contatoController.text.trim();
                    widget.paciente.email = emailController.text.trim();
                    widget.paciente.tipoAtendimento = tipoAtendimento;
                    widget.paciente.observacoes =
                        observacoesController.text.trim();
                    widget.paciente.modoAtendimento =
                        modoAtendimentoSelecionado ?? '';
                    widget.paciente.ativo = ativo;
                    widget.paciente.fotoBase64 = fotoBase64;
                    widget.paciente.tratamento = tratamento;
                    await pacienteService.atualizarPaciente(widget.paciente);
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    if (!mounted) return;
                    ref.read(_refreshProvider.notifier).state++;
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          '$_termoSingularCapitalizado $_atualizadoOuAtualizada com sucesso.',
                        ),
                      ),
                    );
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    nomeController.dispose();
    contatoController.dispose();
    emailController.dispose();
    observacoesController.dispose();
  }

  Widget _dialogEditarPacienteBody({
    required TextEditingController nomeController,
    required TextEditingController contatoController,
    required TextEditingController emailController,
    required TextEditingController observacoesController,
    required List<String> tiposAtendimentoDisponiveis,
    required String tipoAtendimento,
    required bool ativo,
    required String fotoBase64,
    required List<String> opcoesModo,
    required String? modoAtendimentoSelecionado,
    required String tratamento,
    required void Function(void Function()) setDialogState,
    required void Function(String) onTipoAlterado,
    required void Function(bool) onAtivoAlterado,
    required void Function(String?) onModoAlterado,
    required void Function(String) onTratamentoAlterado,
    required void Function(String) onFotoAlterada,
  }) {
    Future<void> selecionarFoto() async {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setDialogState(() => onFotoAlterada(base64Encode(bytes)));
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: GestureDetector(
              onTap: selecionarFoto,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor:
                        context.corPrimaria.withValues(alpha: 0.1),
                    backgroundImage: fotoBase64.isNotEmpty
                        ? MemoryImage(base64Decode(fotoBase64))
                        : null,
                    child: fotoBase64.isEmpty
                        ? Icon(Icons.camera_alt_outlined,
                            size: 28, color: context.corPrimaria)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: context.corPrimaria,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: context.corOnPrimaria, width: 2),
                      ),
                      child: Icon(
                        Icons.edit,
                        size: 13,
                        color: context.corOnPrimaria,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: nomeController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nome completo',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: contatoController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Contato',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-mail',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: tipoAtendimento,
            decoration: const InputDecoration(
              labelText: 'Tipo de atendimento',
              border: OutlineInputBorder(),
            ),
            items: tiposAtendimentoDisponiveis.map((tipo) {
              return DropdownMenuItem(
                value: tipo,
                child: Text(tipo),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;
              setDialogState(() => onTipoAlterado(value));
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: modoAtendimentoSelecionado,
            decoration: const InputDecoration(
              labelText: 'Modalidade de atendimento',
              border: OutlineInputBorder(),
            ),
            hint: const Text('Selecione a modalidade'),
            items: opcoesModo.map((modo) {
              return DropdownMenuItem(
                value: modo,
                child: Row(
                  children: [
                    Icon(
                      modo == 'Online'
                          ? Icons.videocam_outlined
                          : Icons.location_on_outlined,
                      size: 16,
                      color: context.corTextoMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(modo),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setDialogState(() => onModoAlterado(value));
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: tratamento,
            decoration: const InputDecoration(
              labelText: 'Tratamento',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'masculino', child: Text('Masculino')),
              DropdownMenuItem(value: 'feminino', child: Text('Feminino')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setDialogState(() => onTratamentoAlterado(value));
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: ativo,
            title: Text('$_termoSingularCapitalizado $_ativoOuAtiva'),
            contentPadding: EdgeInsets.zero,
            onChanged: (value) {
              setDialogState(() => onAtivoAlterado(value));
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: observacoesController,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Observações',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  Future<void> _abrirOpcoesExportacao() async {
    final sessaoService = ref.read(sessaoServiceProvider);
    final perfilService = ref.read(perfilProfissionalServiceProvider);

    final sessoes = sessaoService.listarSessoesDoPaciente(widget.paciente.id);
    final perfil = perfilService.obterPerfil();

    if (perfil == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configure o perfil profissional antes de exportar.'),
          ),
        );
      }
      return;
    }

    if (sessoes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nenhuma sessão ativa para exportar.'),
          ),
        );
      }
      return;
    }

    final exportService = PdfExportService();

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => _bottomSheetExportacaoBody(
        exportService: exportService,
        sessoes: sessoes,
        perfil: perfil,
        context: ctx,
      ),
    );
  }

  Widget _bottomSheetExportacaoBody({
    required PdfExportService exportService,
    required List<Sessao> sessoes,
    required PerfilProfissional perfil,
    required BuildContext context,
  }) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Exportar',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Escolha o tipo de documento para exportar.',
              style: TextStyle(fontSize: 14, color: context.corTextoMuted),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  exportService.exportarHistoricoPaciente(
                    paciente: widget.paciente,
                    sessoes: sessoes,
                    perfil: perfil,
                  );
                },
                icon: const Icon(Icons.history_outlined),
                label: const Text('Histórico completo'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  exportService.exportarRelatorioClinico(
                    paciente: widget.paciente,
                    sessoes: sessoes,
                    perfil: perfil,
                  );
                },
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('Relatório clínico'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  exportService.exportarSinteseRevisada(
                    sessao: sessoes.first,
                    paciente: widget.paciente,
                    perfil: perfil,
                  );
                },
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('Síntese revisada (última sessão)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  exportService.exportarSessao(
                    sessao: sessoes.first,
                    paciente: widget.paciente,
                    perfil: perfil,
                  );
                },
                icon: const Icon(Icons.description_outlined),
                label: const Text('Última sessão'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  exportService.exportarProntuarioCompleto(
                    paciente: widget.paciente,
                    sessoes: sessoes,
                    perfil: perfil,
                  );
                },
                icon: const Icon(Icons.folder_zip_outlined),
                label: const Text('Prontuário completo'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Acordo Terapêutico dialog (menu)
  // ---------------------------------------------------------------------------

  void _abrirDialogoAcordoArquivado(
      ContratoTerapeutico? ativo, ContratoTerapeutico? arquivado) {
    final contrato = arquivado ?? ativo;
    if (contrato == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Acordo Terapêutico'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _linhaInfo(ctx, 'Status', contrato.statusExibicao),
            if (contrato.isAceito && contrato.nomeAceite.isNotEmpty)
              _linhaInfo(ctx, 'Aceito por', contrato.nomeAceite),
            if (contrato.dataAceite != null)
              _linhaInfo(ctx, 'Data', contrato.dataAceiteFormatada),
            if (contrato.dataEnvio != null) ...[
              const SizedBox(height: 4),
              Text(
                'Enviado em ${contrato.dataEnvio!.day.toString().padLeft(2, '0')}/${contrato.dataEnvio!.month.toString().padLeft(2, '0')}/${contrato.dataEnvio!.year}',
                style: TextStyle(fontSize: 12, color: context.corTextoMuted),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
          if (contrato.arquivado)
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                final service = ref.read(contratoServiceProvider);
                await service.restaurarContrato(contrato);
                ref.invalidate(
                    contratoPorPacienteProvider(widget.paciente.id));
                ref.invalidate(
                    contratoArquivadoPorPacienteProvider(widget.paciente.id));
              },
              icon: const Icon(Icons.unarchive_outlined, size: 18),
              label: const Text('Restaurar'),
            )
          else
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                final service = ref.read(contratoServiceProvider);
                await service.arquivarContrato(contrato);
                ref.invalidate(
                    contratoPorPacienteProvider(widget.paciente.id));
                ref.invalidate(
                    contratoArquivadoPorPacienteProvider(widget.paciente.id));
              },
              icon: const Icon(Icons.archive_outlined, size: 18),
              label: const Text('Arquivar'),
            ),
        ],
      ),
    );
  }

  Widget _linhaInfo(BuildContext ctx, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
                text: '$label: ',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: ctx.corTextoHeading,
                    fontSize: 13)),
            TextSpan(
                text: valor,
                style: TextStyle(color: ctx.corTextoBody, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
