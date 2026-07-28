import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/anamnese_enviada.dart';
import '../models/contrato_terapeutico.dart';
import '../models/paciente.dart';
import '../models/perfil_profissional.dart';
import '../models/sessao.dart';
import '../providers/service_providers.dart';
import '../services/anamnese_templates.dart';
import '../services/logger.dart';
import '../services/pdf_export_service.dart';
import '../utils/mentall_colors.dart';
import '../widgets/anamnese_card.dart';
import '../widgets/escalas_section.dart';
import '../widgets/lista_sessoes.dart';
import '../widgets/paciente_resumo_card.dart';
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
  ConsumerState<PacienteDetailPage> createState() =>
      _PacienteDetailPageState();
}

class _PacienteDetailPageState extends ConsumerState<PacienteDetailPage> {
  @override
  void initState() {
    super.initState();
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

  String get _termoSingular {
    final perfil =
        ref.read(perfilProfissionalServiceProvider).obterPerfil();
    return perfil?.termoSingular ?? 'paciente';
  }

  String get _termoSingularCapitalizado {
    final perfil =
        ref.read(perfilProfissionalServiceProvider).obterPerfil();
    return perfil?.termoSingularCapitalizado ?? 'Paciente';
  }

  bool get _usaPessoaAtendida {
    return _termoSingular == 'pessoa atendida';
  }

  String get _doOuDa {
    return _usaPessoaAtendida ? 'da' : 'do';
  }

  String get _desteOuDesta {
    return _usaPessoaAtendida ? 'desta' : 'deste';
  }

  String get _ativoOuAtiva {
    return _usaPessoaAtendida ? 'ativa' : 'ativo';
  }

  String get _atualizadoOuAtualizada {
    return _usaPessoaAtendida ? 'atualizada' : 'atualizado';
  }

  String get _nomePacienteExibicao {
    final nomeLimpo = widget.paciente.nome.trim();
    if (nomeLimpo.isEmpty) {
      return _termoSingularCapitalizado;
    }
    return nomeLimpo;
  }

  Future<void> _abrirDialogEditarPaciente() async {
    final pacienteService = ref.read(pacienteServiceProvider);
    final perfil =
        ref.read(perfilProfissionalServiceProvider).obterPerfil();

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
    String? modoAtendimentoSelecionado = widget.paciente.modoAtendimento.trim().isEmpty
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
                    backgroundColor: context.corPrimaria.withValues(alpha: 0.1),
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
                        border: Border.all(color: context.corOnPrimaria, width: 2),
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

  Future<void> _confirmarArquivamentoSessao(Sessao sessao) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Arquivar sessão'),
          content: Text(
            'Deseja arquivar a sessão ${sessao.numeroSessao}?\n\n'
            'Ela deixará de aparecer no histórico principal, mas continuará preservada no prontuário.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context, true);
              },
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Arquivar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    try {
      await ref.read(sessaoServiceProvider).arquivarSessao(sessao);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sessão arquivada com sucesso.'),
        ),
      );
    } catch (erro) {
      Log.erro(erro, contexto: 'paciente_detail_page:arquivarSessao');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível arquivar a sessão. Tente novamente.'),
        ),
      );
    }
  }

  Future<void> _confirmarRestauracaoSessao(Sessao sessao) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Restaurar sessão'),
          content: Text(
            'Deseja restaurar a sessão ${sessao.numeroSessao}?\n\n'
            'Ela voltará a aparecer no histórico ativo $_doOuDa $_termoSingular.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context, true);
              },
              icon: const Icon(Icons.restore_outlined),
              label: const Text('Restaurar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    try {
      await ref.read(sessaoServiceProvider).restaurarSessao(sessao);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sessão restaurada com sucesso.'),
        ),
      );
    } catch (erro) {
      Log.erro(erro, contexto: 'paciente_detail_page:restaurarSessao');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Não foi possível restaurar a sessão. Tente novamente.'),
        ),
      );
    }
  }

  Future<void> _abrirOpcoesExportacao() async {
    final sessaoService = ref.read(sessaoServiceProvider);
    final perfilService = ref.read(perfilProfissionalServiceProvider);

    final sessoes = sessaoService.listarSessoesDoPaciente(
      widget.paciente.id,
    );
    final perfil = perfilService.obterPerfil();

    if (perfil == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configure o perfil profissional antes de exportar.'),
        ),
      );
      return;
    }

    if (sessoes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nenhuma sessão ativa para exportar.',
          ),
        ),
      );
      return;
    }

    final exportService = PdfExportService();
    final temaEscuro = ref.read(configuracoesServiceProvider).temaEscuro;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
        builder: (context) => _bottomSheetExportacaoBody(
          exportService: exportService,
          sessoes: sessoes,
          perfil: perfil,
          context: context,
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
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Escolha o tipo de documento para exportar.',
              style: TextStyle(
                fontSize: 14,
                color: context.corTextoMuted,
              ),
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

  @override
  Widget build(BuildContext context) {
    ref.watch(_refreshProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: context.corFundo,
        appBar: AppBar(
          title: Text(_nomePacienteExibicao),
          backgroundColor: context.corPrimaria,
          foregroundColor: context.corOnPrimaria,
          actions: _appBarAcoes(),
        ),
        body: _corpoSessoes(),
      ),
    );
  }

  List<Widget> _appBarAcoes() {
    return [
      IconButton(
        tooltip: 'Exportar',
        icon: const Icon(Icons.file_download_outlined),
        onPressed: _abrirOpcoesExportacao,
      ),
      IconButton(
        tooltip: 'Editar $_termoSingular',
        icon: const Icon(Icons.edit_outlined),
        onPressed: _abrirDialogEditarPaciente,
      ),
    ];
  }

  Widget _botaoAnamnese() {
    final anamnese = ref.watch(anamnesePorPacienteProvider(widget.paciente.id)).valueOrNull;

    if (anamnese != null && anamnese.isRespondido) {
      return OutlinedButton.icon(
        onPressed: () => _verAnamnese(anamnese),
        icon: Icon(Icons.check_circle_outline, color: context.corSuccess, size: 20),
        label: Text(
          anamnese.dataResposta != null
              ? 'Respondido em ${anamnese.dataResposta!.day.toString().padLeft(2, '0')}/${anamnese.dataResposta!.month.toString().padLeft(2, '0')}'
              : 'Respondido',
          style: TextStyle(fontSize: 11, color: context.corSuccess),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          side: BorderSide(color: context.corSuccess),
        ),
      );
    }

    if (anamnese != null && anamnese.isEnviado) {
      return OutlinedButton.icon(
        onPressed: () => _enviarAnamneseWhatsApp(anamnese),
        icon: Icon(Icons.hourglass_empty, color: context.corWarning, size: 20),
        label: Text('Reenviar anamnese', style: TextStyle(fontSize: 11, color: context.corWarning)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          side: BorderSide(color: context.corWarning),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: _criarEnviarAnamnese,
      icon: const Icon(Icons.assignment_outlined, size: 20),
      label: const Text('Anamnese', style: TextStyle(fontSize: 11)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        side: BorderSide(color: context.corPrimaria),
      ),
    );
  }

  Future<void> _criarEnviarAnamnese() async {
    try {
      final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
      if (perfil == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configure o perfil profissional primeiro.')),
        );
        return;
      }

      final abordagem = perfil.abordagemClinica;
      final template = AnamneseTemplates.templatePadrao(abordagem);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Criando questionário...'), duration: Duration(seconds: 30)),
      );

      final service = ref.read(anamneseEnviadaServiceProvider);
      final anamnese = await service.criar(
        pacienteId: widget.paciente.id,
        abordagem: abordagem,
        templateJson: template,
        nomePaciente: widget.paciente.nome,
        nomeProfissional: perfil.nomeExibicao,
        registro: perfil.registroProfissional,
        tratamento: perfil.tratamento,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      _enviarAnamneseWhatsApp(anamnese);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao criar questionário: $e'), duration: const Duration(seconds: 8)),
      );
    }
  }

  Future<void> _enviarAnamneseWhatsApp(AnamneseEnviada anamnese) async {
    final contato = widget.paciente.contatoExibicao.replaceAll(RegExp(r'[^\d]'), '');
    if (contato.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadastre um telefone válido para o paciente.')),
      );
      return;
    }

    final mensagem = Uri.encodeComponent(
      'Olá ${widget.paciente.nome.trim()}! Antes da nossa consulta, gostaria que você respondesse este questionário. '
      'Leva cerca de 10 minutos e me ajuda a conhecer você melhor:\n\n'
      '${anamnese.url}',
    );
    final uri = Uri.parse('https://wa.me/$contato?text=$mensagem');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);

      final service = ref.read(anamneseEnviadaServiceProvider);
      await service.marcarComoEnviada(anamnese);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
      );
    }
  }

  void _verAnamnese(AnamneseEnviada anamnese) {
    final respostas = anamnese.respostas;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Anamnese — ${widget.paciente.nome}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: _buildRespostasAnamnese(respostas),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Widget _buildRespostasAnamnese(Map<String, dynamic> respostas) {
    if (respostas.isEmpty) {
      return const Text('Nenhuma resposta disponível.');
    }

    final blocos = <Widget>[];
    final segurancaIds = ['pensou_morte', 'pensou_machucar', 'esta_seguro'];

    for (final segId in segurancaIds) {
      if (respostas.containsKey(segId)) {
        final valor = respostas[segId];
        final texto = valor == true ? 'Sim' : 'Não';
        final isRisco = segId != 'esta_seguro' && valor == true;
        blocos.add(
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isRisco ? const Color(0xFFFFF3E0) : null,
              borderRadius: BorderRadius.circular(8),
              border: isRisco ? Border.all(color: const Color(0xFFFFB74D)) : null,
            ),
            child: Row(
              children: [
                if (isRisco)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 20),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _labelResposta(segId),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isRisco ? const Color(0xFFE65100) : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        texto,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isRisco ? const Color(0xFFC62828) : (valor == true ? const Color(0xFFE65100) : const Color(0xFF2E7D32)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    blocos.insert(0, const SizedBox(height: 8));
    blocos.insert(0, Text(
      'Segurança emocional',
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
    ));

    final outrosIds = respostas.keys.where((k) => !segurancaIds.contains(k)).toList();
    blocos.insert(0, const SizedBox(height: 16));
    for (final id in outrosIds) {
      final valor = respostas[id];
      blocos.insert(0, Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_labelResposta(id), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
            const SizedBox(height: 2),
            Text(
              valor is List ? valor.join(', ') : (valor is bool ? (valor ? 'Sim' : 'Não') : '${valor ?? ''}'),
              style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
            ),
          ],
        ),
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: blocos);
  }

  String _labelResposta(String id) {
    const labels = {
      'nome': 'Nome',
      'nascimento': 'Data de nascimento',
      'telefone': 'Telefone',
      'email': 'E-mail',
      'cidade': 'Cidade',
      'como_chamar': 'Como prefere ser chamado(a)',
      'motivos': 'O que te trouxe à terapia',
      'motivo_aberto': 'Motivo da procura',
      'sofrimento': 'Nível de sofrimento (0-10)',
      'frequencia': 'Frequência',
      'afeta_rotina': 'Afeta rotina (0-10)',
      'afeta_relacoes': 'Afeta relacionamentos (0-10)',
      'afeta_trabalho': 'Afeta trabalho/estudos (0-10)',
      'fez_terapia': 'Já fez terapia',
      'foi_psiquiatra': 'Já foi ao psiquiatra',
      'usa_medicacao': 'Usa medicação',
      'tem_diagnostico': 'Tem diagnóstico',
      'sono': 'Sono',
      'substancias': 'Usa álcool/substâncias',
      'situacoes_pioram': 'Situações que pioram',
      'pensamentos': 'Pensamentos que aparecem',
      'emocoes_frequentes': 'Emoções frequentes',
      'quando_mal': 'O que faz quando se sente mal',
      'evita': 'Evita situações',
      'busca_confirmacao': 'Busca aprovação',
      'se_cobra': 'Se cobra demais',
      'o_que_mudar': 'O que gostaria de mudar',
      'pensou_morte': 'Pensamentos de não querer viver',
      'pensou_machucar': 'Pensou em se machucar',
      'esta_seguro': 'Está em segurança',
      'objetivos': 'Objetivos',
      'expectativa': 'O que espera da terapia',
    };
    return labels[id] ?? id;
  }

  Widget _contratoCard() {
    final contrato = ref.watch(contratoPorPacienteProvider(widget.paciente.id)).valueOrNull;

    return Card(
      margin: EdgeInsets.zero,
      color: context.corCard,
      elevation: Theme.of(context).brightness == Brightness.dark ? 4 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description_outlined, color: context.corPrimaria, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Acordo Terapêutico',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.corTextoHeading,
                  ),
                ),
                const Spacer(),
                if (contrato != null && contrato.isAceito)
                  TextButton.icon(
                    onPressed: () => _verContrato(contrato),
                    icon: Icon(Icons.visibility_outlined, size: 16, color: context.corSuccess),
                    label: Text('Ver', style: TextStyle(fontSize: 13, color: context.corSuccess)),
                  )
                else if (contrato != null)
                  TextButton.icon(
                    onPressed: () => _enviarContratoWhatsApp(contrato),
                    icon: Icon(Icons.send_outlined, size: 16, color: context.corPrimaria),
                    label: Text('Enviar', style: TextStyle(fontSize: 13, color: context.corPrimaria)),
                  )
                else
                  TextButton.icon(
                    onPressed: _criarEnviarContrato,
                    icon: Icon(Icons.send_outlined, size: 16, color: context.corPrimaria),
                    label: Text('Enviar', style: TextStyle(fontSize: 13, color: context.corPrimaria)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (contrato == null)
              Text(
                'Envie o Acordo Terapêutico para leitura e aceite do $_termoSingular.',
                style: TextStyle(fontSize: 13, color: context.corTextoMuted, height: 1.4),
              )
            else ...[
              Row(
                children: [
                  _statusBadge(contrato),
                  const SizedBox(width: 10),
                  if (contrato.isAceito && contrato.nomeAceite.isNotEmpty)
                    Expanded(
                      child: Text(
                        'por ${contrato.nomeAceite} em ${contrato.dataAceiteFormatada}',
                        style: TextStyle(fontSize: 12, color: context.corTextoSecondary),
                      ),
                    )
                  else if (contrato.isEnviado)
                    Expanded(
                      child: Text(
                        'Enviado em ${contrato.dataCriacao.day.toString().padLeft(2, '0')}/${contrato.dataCriacao.month.toString().padLeft(2, '0')}/${contrato.dataCriacao.year}',
                        style: TextStyle(fontSize: 12, color: context.corTextoSecondary),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(ContratoTerapeutico contrato) {
    final Color cor;
    final String texto;
    if (contrato.isAceito) {
      cor = context.corSuccess;
      texto = 'Aceito';
    } else if (contrato.isEnviado) {
      cor = context.corWarning;
      texto = 'Aguardando';
    } else {
      cor = context.corTextoMuted;
      texto = 'Pendente';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texto,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cor),
      ),
    );
  }

  Future<void> _criarEnviarContrato() async {
    try {
      final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
      if (perfil == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configure o perfil profissional primeiro.')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onInverseSurface)),
            SizedBox(width: 12),
            Text('Criando contrato...'),
          ]),
          duration: Duration(seconds: 120),
        ),
      );

      final contratoService = ref.read(contratoServiceProvider);
      final config = ref.read(configuracoesServiceProvider);
      final contrato = await contratoService.criarContrato(
        paciente: widget.paciente,
        perfil: perfil,
        templateContrato: config.contratoTemplate,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      await _enviarContratoWhatsApp(contrato);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao criar contrato: $e'),
          backgroundColor: context.corError,
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  Future<void> _enviarContratoWhatsApp(ContratoTerapeutico contrato) async {
    final contato = widget.paciente.contato.trim();
    if (!widget.paciente.possuiContato) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_termoSingularCapitalizado não possui telefone cadastrado.'),
        ),
      );
      return;
    }

    final mensagem = Uri.encodeComponent(
      'Olá ${widget.paciente.nome.trim()}! Segue o Acordo Terapêutico para sua leitura. '
      'Por favor, acesse o link, leia com atenção e, se estiver de acordo, '
      'digite seu nome ao final para confirmar:\n\n'
      '${contrato.url}',
    );

    final numero = contato.replaceAll(RegExp(r'[^\d]'), '');
    final uri = Uri.parse('https://wa.me/$numero?text=$mensagem');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);

      final contratoService = ref.read(contratoServiceProvider);
      await contratoService.marcarComoEnviado(contrato);

      final auditoria = ref.read(auditoriaServiceProvider);
      auditoria.registrar(
        tipoEvento: 'contrato_enviado',
        descricao: 'Acordo Terapêutico enviado para ${widget.paciente.nome} via WhatsApp',
        pacienteId: widget.paciente.id,
      );

      ref.invalidate(contratoPorPacienteProvider(widget.paciente.id));
    } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Não foi possível abrir o WhatsApp.'),
            backgroundColor: context.corError,
          ),
        );
    }
  }

  Future<void> _verContrato(ContratoTerapeutico contrato) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Acordo Terap\u00eautico'),
        content: const Text(
          'Este acordo j\u00e1 foi aceito pelo paciente.\n\n'
          'Para visualizar ou editar o modelo do documento, '
          'acesse Configura\u00e7\u00f5es > Contrato.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  Widget _corpoSessoes() {
    final sessaoService = ref.read(sessaoServiceProvider);

    return StreamBuilder(
      stream: sessaoService.observarSessoes(),
      builder: (context, snapshot) {
        final sessoesAtivas = sessaoService.listarSessoesDoPaciente(
          widget.paciente.id,
        );
        final sessoesArquivadas =
            sessaoService.listarSessoesArquivadasDoPaciente(
          widget.paciente.id,
        );

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PacienteResumoCard(
                    paciente: widget.paciente,
                    termoSingular: _termoSingular,
                    usaPessoaAtendida: _usaPessoaAtendida,
                    quantidadeSessoes: sessoesAtivas.length,
                    quantidadeSessoesArquivadas:
                        sessoesArquivadas.length,
                    contrato: ref.watch(contratoPorPacienteProvider(widget.paciente.id)).valueOrNull,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SessaoFormPage(
                                  paciente: widget.paciente,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Nova sessão'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                  const SizedBox(width: 10),
                  _botaoAnamnese(),
                ],
              ),
              const SizedBox(height: 20),
              _contratoCard(),
              const SizedBox(height: 14),
              AnamneseCard(
                pacienteId: widget.paciente.id,
                termoSingular: _termoSingular,
              ),
              const SizedBox(height: 14),
              EscalasSection(pacienteId: widget.paciente.id),
              const SizedBox(height: 20),
              _tabBarComListas(
                    sessoesAtivas: sessoesAtivas,
                    sessoesArquivadas: sessoesArquivadas,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }


  Widget _tabBarComListas({
    required List<Sessao> sessoesAtivas,
    required List<Sessao> sessoesArquivadas,
  }) {
    if (sessoesArquivadas.isEmpty) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: ListaSessoesAtivas(
            sessoes: sessoesAtivas,
            paciente: widget.paciente,
            termoSingular: _termoSingular,
            doOuDa: _doOuDa,
            onArquivar: _confirmarArquivamentoSessao,
          ),
        ),
      );
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          TabBar(
            labelColor: context.corPrimaria,
            unselectedLabelColor: context.corTextoPlaceholder,
            indicatorColor: context.corPrimaria,
            tabs: [
              Tab(
                icon: const Icon(Icons.history_outlined),
                text: 'Ativas (${sessoesAtivas.length})',
              ),
              Tab(
                icon: const Icon(Icons.archive_outlined),
                text: 'Arquivadas (${sessoesArquivadas.length})',
              ),
            ],
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: TabBarView(
              children: [
                ListaSessoesAtivas(
                  sessoes: sessoesAtivas,
                  paciente: widget.paciente,
                  termoSingular: _termoSingular,
                  doOuDa: _doOuDa,
                  onArquivar: _confirmarArquivamentoSessao,
                ),
                ListaSessoesArquivadas(
                  sessoes: sessoesArquivadas,
                  paciente: widget.paciente,
                  termoSingular: _termoSingular,
                  desteOuDesta: _desteOuDesta,
                  onRestaurar: _confirmarRestauracaoSessao,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
