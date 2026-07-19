import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/service_providers.dart';
import '../models/paciente.dart';
import '../services/logger.dart';
import '../widgets/compromisso_form_dialog.dart';
import '../widgets/estado_vazio_pacientes.dart';
import '../widgets/home_dashboard.dart';
import '../widgets/novo_paciente_dialog.dart';
import '../widgets/paciente_card_home.dart';
import 'backup_restore_page.dart';
import 'configuracoes_page.dart';
import 'lgpd/privacidade_seguranca_page.dart';
import 'agenda_page.dart';
import 'paciente_detail_page.dart';
import 'perfil_profissional_form_page.dart';

final _saudacaoProvider = StateProvider<String>((ref) => _calcularSaudacao());

String _calcularSaudacao() {
  final hora = DateTime.now().hour;
  if (hora < 12) return 'Bom dia';
  if (hora < 18) return 'Boa tarde';
  return 'Boa noite';
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static const Color _azul = Color(0xFF2563EB);

  String get _termoSingular {
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
    return perfil?.termoSingular ?? 'paciente';
  }

  String get _termoSingularCapitalizado {
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
    return perfil?.termoSingularCapitalizado ?? 'Paciente';
  }

  String get _termoPlural {
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
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

  String get _restauradoOuRestaurada {
    return _termoFeminino ? 'restaurada' : 'restaurado';
  }

  String get _doOuDa {
    return _termoFeminino ? 'da' : 'do';
  }

  Timer? _saudacaoTimer;

  @override
  void initState() {
    super.initState();
    _saudacaoTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final nova = _calcularSaudacao();
      if (ref.read(_saudacaoProvider) != nova) {
        ref.read(_saudacaoProvider.notifier).state = nova;
      }
    });
  }

  @override
  void dispose() {
    _saudacaoTimer?.cancel();
    super.dispose();
  }

  String _nomeProfissional() {
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
    if (perfil == null) return '';
    return perfil.nomeExibicao;
  }

  Widget _indicadorPendencias() {
    final sessaoService = ref.read(sessaoServiceProvider);
    final pendentes = sessaoService.listarSessoesPendentesRevisao();
    if (pendentes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: GestureDetector(
        onTap: () {
          final primeira = pendentes.first;
          final pacienteService = ref.read(pacienteServiceProvider);
          final paciente = pacienteService.buscarPacientePorId(primeira.pacienteId);
          if (paciente == null) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PacienteDetailPage(
                paciente: paciente,
                sessaoParaAbrir: primeira,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.rate_review_outlined,
                  color: Color(0xFFE65100), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${pendentes.length} sess${pendentes.length == 1 ? 'ão' : 'ões'} pendente${pendentes.length == 1 ? '' : 's'} de revisão',
                  style: const TextStyle(
                    color: Color(0xFFE65100),
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: Color(0xFFE65100), size: 20),
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

  Future<void> _abrirDialogNovoPaciente() async {
    final pacienteService = ref.read(pacienteServiceProvider);
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
    await mostrarDialogNovoPaciente(
      context: context,
      pacienteService: pacienteService,
      termoSingular: _termoSingular,
      termoSingularCapitalizado: _termoSingularCapitalizado,
      novoOuNova: _novoOuNova,
      cadastradoOuCadastrada: _cadastradoOuCadastrada,
      doOuDa: _doOuDa,
      opcoesModoAtendimento: perfil?.opcoesModoAtendimento ?? const [],
      auditoriaService: ref.read(auditoriaServiceProvider),
    );
  }

  Future<void> _novoCompromissoRapido() async {
    final pacientes =
        ref.read(pacienteServiceProvider).listarPacientesAtivos();
    if (pacientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Cadastre $_termoPlural primeiro para agendar sessões.'),
        ),
      );
      return;
    }

    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
    final config = ref.read(configuracoesServiceProvider);
    final compromisso = await mostrarCompromissoFormDialog(
      context: context,
      pacientes: pacientes,
      termoPessoa: perfil?.termoSingularCapitalizado ?? 'Pessoa atendida',
      duracaoPadraoMinutos: config.duracaoPadraoSessaoMinutos,
      lembretePadraoAtivado: config.lembretePadraoAtivado,
      antecedenciaPadraoMinutos: config.antecedenciaPadraoMinutos,
    );

    if (compromisso == null) return;
    await ref.read(compromissoServiceProvider).adicionar(compromisso);

    final paciente = ref
        .read(pacienteServiceProvider)
        .buscarPacientePorId(compromisso.pacienteId);
    await ref.read(auditoriaServiceProvider).registrar(
          tipoEvento: 'Sessão agendada',
          descricao: paciente?.nome ?? 'Compromisso criado',
          pacienteId: compromisso.pacienteId,
        );

    if (compromisso.lembreteAtivado &&
        compromisso.isAgendado &&
        paciente != null) {
      await ref.read(lembreteServiceProvider).agendarLembrete(
            compromisso: compromisso,
            nomePaciente: paciente.nome,
            nomeProfissional: perfil?.nome ?? 'Profissional',
            telefonePaciente: paciente.contato,
          );
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
      await ref.read(pacienteServiceProvider).arquivarPaciente(paciente);
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
      await ref.read(pacienteServiceProvider).restaurarPaciente(paciente);
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
    final pacientesAtivosAsync = ref.watch(pacientesAtivosProvider);
    final pacientesArquivadosAsync = ref.watch(pacientesArquivadosProvider);

    final pacientesAtivos = pacientesAtivosAsync.valueOrNull ?? [];
    final pacientesArquivados = pacientesArquivadosAsync.valueOrNull ?? [];
    final nomeProf = _nomeProfissional();

    final sessaoService = ref.watch(sessaoServiceProvider);
    final ativosComPendentes = <String, int>{};
    for (final p in pacientesAtivos) {
      final count = sessaoService.contarSessoesPendentesPorPaciente(p.id);
      if (count > 0) ativosComPendentes[p.id] = count;
    }
    final arquivadosComPendentes = <String, int>{};
    for (final p in pacientesArquivados) {
      final count = sessaoService.contarSessoesPendentesPorPaciente(p.id);
      if (count > 0) arquivadosComPendentes[p.id] = count;
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          toolbarHeight: 112,
          title: Image.asset(
            'assets/images/logo_mentall.png',
            height: 88,
          ),
          centerTitle: false,
          backgroundColor: Colors.white,
          foregroundColor: _azul,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_month_outlined),
              tooltip: 'Agenda',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AgendaPage(),
                  ),
                );
              },
            ),
            PopupMenuButton<String>(
              tooltip: 'Mais',
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'perfil':
                    _abrirPerfil();
                    break;
                  case 'configuracoes':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ConfiguracoesPage(),
                      ),
                    );
                    break;
                  case 'backup':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BackupRestorePage(),
                      ),
                    );
                    break;
                  case 'privacidade':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrivacidadeSegurancaPage(),
                      ),
                    );
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'perfil',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, size: 20),
                      SizedBox(width: 10),
                      Text('Perfil profissional'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'configuracoes',
                  child: Row(
                    children: [
                      Icon(Icons.settings_outlined, size: 20),
                      SizedBox(width: 10),
                      Text('Configurações'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'backup',
                  child: Row(
                    children: [
                      Icon(Icons.backup_outlined, size: 20),
                      SizedBox(width: 10),
                      Text('Backup e restauração'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'privacidade',
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 20),
                      SizedBox(width: 10),
                      Text('Privacidade e Segurança'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SaudacaoResumoHome(
                  saudacao: ref.watch(_saudacaoProvider),
                  nomeProfissional: nomeProf,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AcoesRapidasHome(
                  termoSingular: _termoSingular,
                  termoFeminino: _termoFeminino,
                  onAgendar: _novoCompromissoRapido,
                  onNovoPaciente: _abrirDialogNovoPaciente,
                  onAbrirAgenda: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AgendaPage()),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: KpiCardsHome(termoPlural: _termoPlural),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SessoesHojeCard(onAgendar: _novoCompromissoRapido),
              ),
            ),
            SliverToBoxAdapter(child: _indicadorPendencias()),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const AtividadeRecenteCard(),
              ),
            ),
            SliverToBoxAdapter(child: const SizedBox(height: 8)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TabBar(
                  labelColor: _azul,
                  unselectedLabelColor: const Color(0xFF94A3B8),
                  indicatorColor: _azul,
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  tabs: [
                    Tab(text: 'Ativos (${pacientesAtivos.length})'),
                    Tab(text: 'Arquivados (${pacientesArquivados.length})'),
                  ],
                ),
              ),
            ),
            SliverFillRemaining(
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
                    sessoesPendentesPorPaciente: ativosComPendentes,
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
                    sessoesPendentesPorPaciente: arquivadosComPendentes,
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
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _abrirDialogNovoPaciente,
          backgroundColor: _azul,
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
  final Map<String, int> sessoesPendentesPorPaciente;
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
    this.sessoesPendentesPorPaciente = const {},
    required this.onAbrirPaciente,
    required this.onArquivarPaciente,
    required this.onRestaurarPaciente,
  });

  @override
  Widget build(BuildContext context) {
    if (pacientes.isEmpty) {
      return EstadoVazioPacientes(
        termoSingular: termoSingular,
        termoPlural: termoPlural,
        nenhumOuNenhuma: nenhumOuNenhuma,
        primeiroOuPrimeira: primeiroOuPrimeira,
        cadastradoOuCadastrada: cadastradoOuCadastrada,
        listaArquivada: listaArquivada,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: pacientes.length,
      itemBuilder: (context, index) {
        final paciente = pacientes[index];
        return PacienteCardHome(
          paciente: paciente,
          termoSingular: termoSingular,
          listaArquivada: listaArquivada,
          sessoesPendentes: sessoesPendentesPorPaciente[paciente.id] ?? 0,
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
