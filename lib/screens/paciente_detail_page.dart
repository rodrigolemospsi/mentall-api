import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/paciente.dart';
import '../models/perfil_profissional.dart';
import '../models/sessao.dart';
import '../providers/service_providers.dart';
import '../services/logger.dart';
import '../services/pdf_export_service.dart';
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
                setDialogState: setDialogState,
                onTipoAlterado: (v) => tipoAtendimento = v,
                onAtivoAlterado: (v) => ativo = v,
                onModoAlterado: (v) => modoAtendimentoSelecionado = v,
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
    required void Function(void Function()) setDialogState,
    required void Function(String) onTipoAlterado,
    required void Function(bool) onAtivoAlterado,
    required void Function(String?) onModoAlterado,
    required void Function(String) onFotoAlterada,
  }) {
    const Color corPrincipal = Color(0xFF2563EB);

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
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: corPrincipal.withValues(alpha: 0.1),
                    backgroundImage: fotoBase64.isNotEmpty
                        ? MemoryImage(base64Decode(fotoBase64))
                        : null,
                    child: fotoBase64.isEmpty
                        ? const Icon(Icons.camera_alt_outlined,
                            size: 28, color: corPrincipal)
                        : null,
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: corPrincipal,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.edit,
                        size: 13,
                        color: Colors.white,
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
                      color: const Color(0xFF64748B),
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
                color: Colors.grey[600],
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
    const Color corPrincipal = Color(0xFF2563EB);
    ref.watch(_refreshProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(_nomePacienteExibicao),
          backgroundColor: corPrincipal,
          foregroundColor: Colors.white,
          actions: _appBarAcoes(corPrincipal),
        ),
        body: _corpoSessoes(corPrincipal),
      ),
    );
  }

  List<Widget> _appBarAcoes(Color corPrincipal) {
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

  Widget _corpoSessoes(Color corPrincipal) {
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
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
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
                      backgroundColor: corPrincipal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _tabBarComListas(
                    corPrincipal: corPrincipal,
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
    required Color corPrincipal,
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
            labelColor: corPrincipal,
            unselectedLabelColor: const Color(0xFF94A3B8),
            indicatorColor: corPrincipal,
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
