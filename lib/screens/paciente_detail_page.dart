import 'package:flutter/material.dart';

import '../models/paciente.dart';
import '../models/perfil_profissional.dart';
import '../models/sessao.dart';
import '../services/logger.dart';
import '../services/paciente_service.dart';
import '../services/pdf_export_service.dart';
import '../services/perfil_profissional_service.dart';
import '../services/sessao_service.dart';
import '../widgets/lista_sessoes.dart';
import '../widgets/paciente_resumo_card.dart';
import 'sessao_form_page.dart';

class PacienteDetailPage extends StatefulWidget {
  final Paciente paciente;

  const PacienteDetailPage({
    super.key,
    required this.paciente,
  });

  @override
  State<PacienteDetailPage> createState() => _PacienteDetailPageState();
}

class _PacienteDetailPageState extends State<PacienteDetailPage> {
  final SessaoService _sessaoService = SessaoService();
  final PacienteService _pacienteService = PacienteService();
  final PerfilProfissionalService _perfilService =
      PerfilProfissionalService();

  String get _termoSingular {
    final perfil = _perfilService.obterPerfil();
    return perfil?.termoSingular ?? 'paciente';
  }

  String get _termoSingularCapitalizado {
    final perfil = _perfilService.obterPerfil();
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
    final nomeController = TextEditingController(text: widget.paciente.nome);
    final contatoController =
        TextEditingController(text: widget.paciente.contato);
    final observacoesController =
        TextEditingController(text: widget.paciente.observacoes);

    String tipoAtendimento = widget.paciente.tipoAtendimento.trim().isEmpty
        ? 'Particular'
        : widget.paciente.tipoAtendimento;

    bool ativo = widget.paciente.ativo;

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
                observacoesController: observacoesController,
                tiposAtendimentoDisponiveis: tiposAtendimentoDisponiveis,
                tipoAtendimento: tipoAtendimento,
                ativo: ativo,
                setDialogState: setDialogState,
                onTipoAlterado: (v) => tipoAtendimento = v,
                onAtivoAlterado: (v) => ativo = v,
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
                    widget.paciente.tipoAtendimento = tipoAtendimento;
                    widget.paciente.observacoes =
                        observacoesController.text.trim();
                    widget.paciente.ativo = ativo;
                    await _pacienteService.atualizarPaciente(widget.paciente);
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    if (!mounted) return;
                    setState(() {});
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
    observacoesController.dispose();
  }

  Widget _dialogEditarPacienteBody({
    required TextEditingController nomeController,
    required TextEditingController contatoController,
    required TextEditingController observacoesController,
    required List<String> tiposAtendimentoDisponiveis,
    required String tipoAtendimento,
    required bool ativo,
    required void Function(void Function()) setDialogState,
    required void Function(String) onTipoAlterado,
    required void Function(bool) onAtivoAlterado,
  }) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
      await _sessaoService.arquivarSessao(sessao);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sessão arquivada com sucesso.'),
        ),
      );

      setState(() {});
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
      await _sessaoService.restaurarSessao(sessao);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sessão restaurada com sucesso.'),
        ),
      );

      setState(() {});
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
    final sessoes = _sessaoService.listarSessoesDoPaciente(
      widget.paciente.id,
    );

    final perfil = _perfilService.obterPerfil();

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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color corPrincipal = Color(0xFF1F6F78);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FA),
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
    return StreamBuilder(
      stream: _sessaoService.observarSessoes(),
      builder: (context, snapshot) {
        final sessoesAtivas = _sessaoService.listarSessoesDoPaciente(
          widget.paciente.id,
        );

        final sessoesArquivadas =
            _sessaoService.listarSessoesArquivadasDoPaciente(
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
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          TabBar(
            labelColor: corPrincipal,
            unselectedLabelColor: Colors.black54,
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

