import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/service_providers.dart';
import '../models/paciente.dart';
import '../services/logger.dart';
import '../widgets/compromisso_form_dialog.dart';
import '../widgets/home_dashboard.dart';
import '../widgets/novo_paciente_dialog.dart';
import '../utils/mentall_colors.dart';
import 'backup_restore_page.dart';
import 'configuracoes_page.dart';
import 'lgpd/privacidade_seguranca_page.dart';
import 'agenda_page.dart';
import 'paciente_detail_page.dart';
import 'pacientes_page.dart';
import 'perfil_profissional_form_page.dart';
import 'sessao_form_page.dart';

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
          color: context.corWarning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.rate_review_outlined,
                color: context.corWarning, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${pendentes.length} sess${pendentes.length == 1 ? 'ão' : 'ões'} pendente${pendentes.length == 1 ? '' : 's'} de revisão',
                style: TextStyle(
                  color: context.corWarning,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            Icon(Icons.chevron_right,
                color: context.corWarning, size: 20),
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
      compromissoService: ref.read(compromissoServiceProvider),
    );

    if (compromisso == null) return;
    final gerados = await ref.read(compromissoServiceProvider).adicionarComRecorrencia(compromisso);

    final paciente = ref
      .read(pacienteServiceProvider)
      .buscarPacientePorId(compromisso.pacienteId);
    await ref.read(auditoriaServiceProvider).registrar(
        tipoEvento: 'Sessão agendada',
        descricao: paciente?.nome ?? 'Compromisso criado${gerados.length > 1 ? ' (${gerados.length}x)' : ''}',
        pacienteId: compromisso.pacienteId,
      );

    for (final c in gerados) {
      if (c.lembreteAtivado && c.isAgendado && paciente != null) {
        await ref.read(lembreteServiceProvider).agendarLembrete(
            compromisso: c,
            nomePaciente: paciente.nome,
            nomeProfissional: perfil?.nome ?? 'Profissional',
            telefonePaciente: paciente.contato,
          );
      }
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

  Future<void> _abrirNovaSessao() async {
    final pacientes = ref.read(pacienteServiceProvider).listarPacientesAtivos();
    if (pacientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cadastre $_termoPlural primeiro para registrar uma sessão.'),
        ),
      );
      return;
    }

    Paciente? escolhido;
    if (pacientes.length == 1) {
      escolhido = pacientes.first;
    } else {
      escolhido = await showDialog<Paciente>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Selecionar $_termoSingular'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: pacientes.length,
              itemBuilder: (_, i) {
                final p = pacientes[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: context.corPrimaria.withValues(alpha: 0.12),
                    backgroundImage: p.possuiFoto
                        ? MemoryImage(base64Decode(p.fotoBase64))
                        : null,
                    child: p.possuiFoto
                        ? null
                        : Text(
                            p.nome.isNotEmpty ? p.nome[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: context.corPrimaria,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  title: Text(p.nome),
                  onTap: () => Navigator.pop(ctx, p),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );
    }

    if (escolhido == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SessaoFormPage(paciente: escolhido!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nomeProf = _nomeProfissional();
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final sair = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sair do MentAll?'),
            content: const Text('Deseja realmente sair do aplicativo?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Permanecer'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Sair'),
              ),
            ],
          ),
        );
        if (sair == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        toolbarHeight: 80,
        title: Image.asset(
          Theme.of(context).brightness == Brightness.dark
              ? 'assets/images/logo_mentall_escuro.png'
              : 'assets/images/logo_mentall_home.png',
          height: 98,
        ),
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.primary,
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
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                onAbrirAgenda: _abrirNovaSessao,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: KpiCardsHome(
                termoPlural: _termoPlural,
                onHojeTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AgendaPage()),
                  );
                },
                onPacientesTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PacientesPage()),
                  );
                },
                onSessoesTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AgendaPage()),
                  );
                },
                onRevisoesTap: () {
                  final pendentes = ref
                      .read(sessaoServiceProvider)
                      .listarSessoesPendentesRevisao();
                  if (pendentes.isEmpty) return;
                  final paciente = ref
                      .read(pacienteServiceProvider)
                      .buscarPacientePorId(pendentes.first.pacienteId);
                  if (paciente == null) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PacienteDetailPage(
                        paciente: paciente,
                        sessaoParaAbrir: pendentes.first,
                      ),
                    ),
                  );
                },
              ),
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
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    ),
    );
  }
}
