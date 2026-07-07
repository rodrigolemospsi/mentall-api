import 'package:flutter/material.dart';

import '../models/paciente.dart';
import '../services/logger.dart';
import '../services/paciente_service.dart';
import '../services/perfil_profissional_service.dart';
import '../services/sessao_service.dart';
import 'backup_restore_page.dart';
import 'paciente_detail_page.dart';
import 'perfil_profissional_form_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PacienteService _pacienteService = PacienteService();
  final PerfilProfissionalService _perfilService =
      PerfilProfissionalService();
  final SessaoService _sessaoService = SessaoService();

  final TextEditingController _buscaController = TextEditingController();
  String _termoBusca = '';

  @override
  void initState() {
    super.initState();
    _buscaController.addListener(() {
      setState(() => _termoBusca = _buscaController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  List<Paciente> _filtrarPacientes(List<Paciente> pacientes) {
    if (_termoBusca.isEmpty) return pacientes;
    return pacientes.where((p) {
      return p.nome.trim().toLowerCase().contains(_termoBusca);
    }).toList();
  }

  String get _termoSingular {
    final perfil = _perfilService.obterPerfil();
    return perfil?.termoSingular ?? 'paciente';
  }

  String get _termoSingularCapitalizado {
    final perfil = _perfilService.obterPerfil();
    return perfil?.termoSingularCapitalizado ?? 'Paciente';
  }

  String get _termoPlural {
    final perfil = _perfilService.obterPerfil();
    return perfil?.termoPlural ?? 'pacientes';
  }

  bool get _termoFeminino {
    return _termoSingular == 'pessoa atendida';
  }

  String get _novoOuNova {
    return _termoFeminino ? 'Nova' : 'Novo';
  }

  String get _nenhumOuNenhuma {
    return _termoFeminino ? 'Nenhuma' : 'Nenhum';
  }

  String get _primeiroOuPrimeira {
    return _termoFeminino ? 'primeira' : 'primeiro';
  }

  String get _cadastradoOuCadastrada {
    return _termoFeminino ? 'cadastrada' : 'cadastrado';
  }

  String get _arquivadoOuArquivada {
    return _termoFeminino ? 'arquivada' : 'arquivado';
  }

  String get _saudacao {
    final perfil = _perfilService.obterPerfil();
    if (perfil == null) return 'MentAll';
    final nome = perfil.nomeExibicao;
    return 'Olá, $nome';
  }

  Widget _indicadorPendencias() {
    final pendentes = _sessaoService.contarSessoesPendentesRevisao();
    if (pendentes == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        color: const Color(0xFFFFF3E0),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.rate_review_outlined, color: Color(0xFFE65100)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$pendentes sess${pendentes == 1 ? 'ão' : 'ões'} pendente${pendentes == 1 ? '' : 's'} de revisão',
                  style: const TextStyle(
                    color: Color(0xFFE65100),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _abrirPerfil() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PerfilProfissionalFormPage(),
      ),
    );
  }

  String get _restauradoOuRestaurada {
    return _termoFeminino ? 'restaurada' : 'restaurado';
  }

  String get _doOuDa {
    return _termoFeminino ? 'da' : 'do';
  }

  Future<void> _abrirDialogNovoPaciente() async {
    final paginaContext = context;

    final nomeController = TextEditingController();
    final contatoController = TextEditingController();
    final observacoesController = TextEditingController();

    String tipoAtendimento = 'Particular';
    bool salvando = false;

    try {
      await showDialog<void>(
        context: paginaContext,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: Text('$_novoOuNova $_termoSingular'),
                content: SingleChildScrollView(
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
                        items: const [
                          DropdownMenuItem(
                            value: 'Particular',
                            child: Text('Particular'),
                          ),
                          DropdownMenuItem(
                            value: 'Convênio',
                            child: Text('Convênio'),
                          ),
                          DropdownMenuItem(
                            value: 'Outro',
                            child: Text('Outro'),
                          ),
                        ],
                        onChanged: salvando
                            ? null
                            : (value) {
                                if (value == null) return;

                                setDialogState(() {
                                  tipoAtendimento = value;
                                });
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
                ),
                actions: [
                  TextButton(
                    onPressed: salvando
                        ? null
                        : () {
                            Navigator.of(dialogContext).pop();
                          },
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: salvando
                        ? null
                        : () async {
                            final nome = nomeController.text.trim();

                            if (nome.isEmpty) {
                              if (!mounted) return;

                              ScaffoldMessenger.of(paginaContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Informe o nome $_doOuDa $_termoSingular.',
                                  ),
                                ),
                              );

                              return;
                            }

                            setDialogState(() {
                              salvando = true;
                            });

                            try {
                              final paciente = Paciente(
                                id: DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString(),
                                nome: nome,
                                contato: contatoController.text.trim(),
                                tipoAtendimento: tipoAtendimento,
                                observacoes:
                                    observacoesController.text.trim(),
                              );

                              await _pacienteService.adicionarPaciente(
                                paciente,
                              );

                              if (!mounted) return;

                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }

                              ScaffoldMessenger.of(paginaContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '$_termoSingularCapitalizado $_cadastradoOuCadastrada com sucesso.',
                                  ),
                                ),
                              );
                            } catch (erro) {
                              Log.erro(erro, contexto: 'home_page:cadastrarPaciente');
                              if (!mounted) return;

                              ScaffoldMessenger.of(paginaContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Não foi possível cadastrar $_doOuDa $_termoSingular. Tente novamente.',
                                  ),
                                ),
                              );

                              if (dialogContext.mounted) {
                                setDialogState(() {
                                  salvando = false;
                                });
                              }
                            }
                          },
                    child: salvando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Salvar'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 300));

      nomeController.dispose();
      contatoController.dispose();
      observacoesController.dispose();
    }
  }

  Future<void> _confirmarArquivamentoPaciente(Paciente paciente) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Arquivar $_termoSingular'),
          content: Text(
            'Deseja arquivar $_termoSingular ${paciente.nome}?\n\n'
            'O cadastro deixará de aparecer na lista ativa, mas continuará preservado e poderá ser restaurado posteriormente.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
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
      await _pacienteService.arquivarPaciente(paciente);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$_termoSingularCapitalizado $_arquivadoOuArquivada com sucesso.',
          ),
        ),
      );
    } catch (erro) {
      Log.erro(erro, contexto: 'home_page:arquivarPaciente');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível arquivar $_doOuDa $_termoSingular. Tente novamente.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmarRestauracaoPaciente(Paciente paciente) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Restaurar $_termoSingular'),
          content: Text(
            'Deseja restaurar $_termoSingular ${paciente.nome}?\n\n'
            'O cadastro voltará a aparecer na lista ativa.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
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
      await _pacienteService.restaurarPaciente(paciente);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$_termoSingularCapitalizado $_restauradoOuRestaurada com sucesso.',
          ),
        ),
      );
    } catch (erro) {
      Log.erro(erro, contexto: 'home_page:restaurarPaciente');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível restaurar $_doOuDa $_termoSingular. Tente novamente.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color corPrincipal = Color(0xFF1F6F78);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FA),
        appBar: AppBar(
          title: Text(_saudacao),
          centerTitle: false,
          backgroundColor: corPrincipal,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: 'Perfil profissional',
              onPressed: _abrirPerfil,
            ),
            IconButton(
              icon: const Icon(Icons.backup_outlined),
              tooltip: 'Backup e restauração',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BackupRestorePage(),
                  ),
                );
              },
            ),
          ],
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.75),
            indicatorColor: Colors.white,
            tabs: const [
              Tab(
                icon: Icon(Icons.people_alt_outlined),
                text: 'Ativos',
              ),
              Tab(
                icon: Icon(Icons.archive_outlined),
                text: 'Arquivados',
              ),
            ],
          ),
        ),
        body: StreamBuilder(
          stream: _pacienteService.observarPacientes(),
          builder: (context, snapshot) {
            final pacientesAtivos = _filtrarPacientes(
              _pacienteService.listarPacientesAtivos(),
            );

            final pacientesArquivados = _filtrarPacientes(
              _pacienteService.listarPacientesArquivados(),
            );

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TextField(
                    controller: _buscaController,
                    decoration: InputDecoration(
                      hintText: _perfilService.obterPerfil()
                              ?.buscarPessoaHint ??
                          'Buscar',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                _indicadorPendencias(),
                Expanded(
                  child: TabBarView(
                    children: [
                      _ListaPacientes(
                        pacientes: pacientesAtivos,
                  termoSingular: _termoSingular,
                  termoPlural: _termoPlural,
                  nenhumOuNenhuma: _nenhumOuNenhuma,
                  primeiroOuPrimeira: _primeiroOuPrimeira,
                  cadastradoOuCadastrada: _cadastradoOuCadastrada,
                  listaArquivada: false,
                  onAbrirPaciente: (paciente) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PacienteDetailPage(
                          paciente: paciente,
                        ),
                      ),
                    );
                  },
                  onArquivarPaciente: _confirmarArquivamentoPaciente,
                  onRestaurarPaciente: _confirmarRestauracaoPaciente,
                ),
                _ListaPacientes(
                  pacientes: pacientesArquivados,
                  termoSingular: _termoSingular,
                  termoPlural: _termoPlural,
                  nenhumOuNenhuma: _nenhumOuNenhuma,
                  primeiroOuPrimeira: _primeiroOuPrimeira,
                  cadastradoOuCadastrada: _cadastradoOuCadastrada,
                  listaArquivada: true,
                  onAbrirPaciente: (paciente) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PacienteDetailPage(
                          paciente: paciente,
                        ),
                      ),
                    );
                  },
                  onArquivarPaciente: _confirmarArquivamentoPaciente,
                  onRestaurarPaciente: _confirmarRestauracaoPaciente,
                ),
              ],
            ),
          ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _abrirDialogNovoPaciente,
          backgroundColor: corPrincipal,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: Text('$_novoOuNova $_termoSingular'),
        ),
      ),
    );
  }
}

class _ListaPacientes extends StatelessWidget {
  final List<Paciente> pacientes;
  final String termoSingular;
  final String termoPlural;
  final String nenhumOuNenhuma;
  final String primeiroOuPrimeira;
  final String cadastradoOuCadastrada;
  final bool listaArquivada;
  final void Function(Paciente paciente) onAbrirPaciente;
  final void Function(Paciente paciente) onArquivarPaciente;
  final void Function(Paciente paciente) onRestaurarPaciente;

  const _ListaPacientes({
    required this.pacientes,
    required this.termoSingular,
    required this.termoPlural,
    required this.nenhumOuNenhuma,
    required this.primeiroOuPrimeira,
    required this.cadastradoOuCadastrada,
    required this.listaArquivada,
    required this.onAbrirPaciente,
    required this.onArquivarPaciente,
    required this.onRestaurarPaciente,
  });

  @override
  Widget build(BuildContext context) {
    if (pacientes.isEmpty) {
      return _EstadoVazioPacientes(
        termoSingular: termoSingular,
        termoPlural: termoPlural,
        nenhumOuNenhuma: nenhumOuNenhuma,
        primeiroOuPrimeira: primeiroOuPrimeira,
        cadastradoOuCadastrada: cadastradoOuCadastrada,
        listaArquivada: listaArquivada,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pacientes.length,
      itemBuilder: (context, index) {
        final paciente = pacientes[index];

        return _PacienteCard(
          paciente: paciente,
          termoSingular: termoSingular,
          listaArquivada: listaArquivada,
          onTap: () {
            onAbrirPaciente(paciente);
          },
          onArquivar: () {
            onArquivarPaciente(paciente);
          },
          onRestaurar: () {
            onRestaurarPaciente(paciente);
          },
        );
      },
    );
  }
}

class _EstadoVazioPacientes extends StatelessWidget {
  final String termoSingular;
  final String termoPlural;
  final String nenhumOuNenhuma;
  final String primeiroOuPrimeira;
  final String cadastradoOuCadastrada;
  final bool listaArquivada;

  const _EstadoVazioPacientes({
    required this.termoSingular,
    required this.termoPlural,
    required this.nenhumOuNenhuma,
    required this.primeiroOuPrimeira,
    required this.cadastradoOuCadastrada,
    required this.listaArquivada,
  });

  @override
  Widget build(BuildContext context) {
    const Color corPrincipal = Color(0xFF1F6F78);

    final titulo = listaArquivada
        ? 'Nenhum cadastro arquivado'
        : '$nenhumOuNenhuma $termoSingular $cadastradoOuCadastrada';

    final mensagem = listaArquivada
        ? 'Quando algum $termoSingular for arquivado, aparecerá aqui para consulta ou restauração.'
        : 'Toque no botão + para cadastrar seu $primeiroOuPrimeira $termoSingular.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              listaArquivada
                  ? Icons.archive_outlined
                  : Icons.psychology_alt_outlined,
              size: 72,
              color: corPrincipal.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              mensagem,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black54,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PacienteCard extends StatelessWidget {
  final Paciente paciente;
  final String termoSingular;
  final bool listaArquivada;
  final VoidCallback onTap;
  final VoidCallback onArquivar;
  final VoidCallback onRestaurar;

  const _PacienteCard({
    required this.paciente,
    required this.termoSingular,
    required this.listaArquivada,
    required this.onTap,
    required this.onArquivar,
    required this.onRestaurar,
  });

  String get _nomeExibicao {
    final nomeLimpo = paciente.nome.trim();

    if (nomeLimpo.isEmpty) {
      return 'Sem nome';
    }

    return nomeLimpo;
  }

  String get _tipoAtendimentoExibicao {
    final tipoLimpo = paciente.tipoAtendimento.trim();

    if (tipoLimpo.isEmpty) {
      return 'Particular';
    }

    return tipoLimpo;
  }

  @override
  Widget build(BuildContext context) {
    const Color corPrincipal = Color(0xFF1F6F78);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: listaArquivada
                    ? Colors.grey.withValues(alpha: 0.14)
                    : corPrincipal.withValues(alpha: 0.12),
                child: Text(
                  paciente.inicial,
                  style: TextStyle(
                    color: listaArquivada
                        ? Colors.grey.shade700
                        : corPrincipal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Opacity(
                  opacity: listaArquivada ? 0.75 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nomeExibicao,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tipoAtendimentoExibicao,
                        style: const TextStyle(
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _StatusPacienteChip(
                        ativo: paciente.ativo,
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opções $termoSingular',
                icon: const Icon(
                  Icons.more_vert,
                  color: Colors.black45,
                ),
                onSelected: (value) {
                  if (value == 'arquivar') {
                    onArquivar();
                  }

                  if (value == 'restaurar') {
                    onRestaurar();
                  }
                },
                itemBuilder: (context) {
                  if (listaArquivada) {
                    return const [
                      PopupMenuItem(
                        value: 'restaurar',
                        child: Row(
                          children: [
                            Icon(Icons.restore_outlined),
                            SizedBox(width: 8),
                            Text('Restaurar cadastro'),
                          ],
                        ),
                      ),
                    ];
                  }

                  return const [
                    PopupMenuItem(
                      value: 'arquivar',
                      child: Row(
                        children: [
                          Icon(Icons.archive_outlined),
                          SizedBox(width: 8),
                          Text('Arquivar cadastro'),
                        ],
                      ),
                    ),
                  ];
                },
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPacienteChip extends StatelessWidget {
  final bool ativo;

  const _StatusPacienteChip({
    required this.ativo,
  });

  @override
  Widget build(BuildContext context) {
    final Color cor = ativo ? const Color(0xFF2E7D32) : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        ativo ? 'Ativo' : 'Arquivado',
        style: TextStyle(
          color: cor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}