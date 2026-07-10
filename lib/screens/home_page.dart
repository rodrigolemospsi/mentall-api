import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/service_providers.dart';
import '../models/compromisso.dart';
import '../models/enums.dart';
import '../models/paciente.dart';
import '../services/api_client.dart';
import '../services/logger.dart';
import '../widgets/compromisso_form_dialog.dart';
import '../widgets/estado_vazio_pacientes.dart';
import '../widgets/novo_paciente_dialog.dart';
import '../widgets/paciente_card_home.dart';
import 'backup_restore_page.dart';
import 'lgpd/privacidade_seguranca_page.dart';
import 'agenda_page.dart';
import 'paciente_detail_page.dart';
import 'perfil_profissional_form_page.dart';

final _agendaDataProvider = StateProvider<DateTime>((ref) {
  final agora = DateTime.now();
  return DateTime(agora.year, agora.month, agora.day);
});

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

  String get _saudacao {
    final agora = DateTime.now();
    final hora = agora.hour;
    if (hora < 12) return 'Bom dia';
    if (hora < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  String _nomeProfissional() {
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
    if (perfil == null) return '';
    return perfil.nomeExibicao;
  }

  Widget _indicadorPendencias() {
    final pendentes = ref.read(sessaoServiceProvider)
        .contarSessoesPendentesRevisao();
    if (pendentes == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                '$pendentes sess${pendentes == 1 ? 'ão' : 'ões'} pendente${pendentes == 1 ? '' : 's'} de revisão',
                style: const TextStyle(
                  color: Color(0xFFE65100),
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ],
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

  Future<void> _abrirConfigServidor() async {
    final controller = TextEditingController(text: ApiClient.baseUrlExibicao);
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Servidor backend'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'URL do servidor',
                hintText: 'http://192.168.1.24:8000',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.dns_outlined),
              ),
              keyboardType: TextInputType.url,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Informe a URL';
                final uri = Uri.tryParse(v.trim());
                if (uri == null || !uri.hasScheme) return 'URL invalida';
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                await ApiClient.setBaseUrl(controller.text.trim());
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('URL do servidor atualizada.')),
                );
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  Future<void> _abrirDialogNovoPaciente() async {
    final pacienteService = ref.read(pacienteServiceProvider);
    await mostrarDialogNovoPaciente(
      context: context,
      pacienteService: pacienteService,
      termoSingular: _termoSingular,
      termoSingularCapitalizado: _termoSingularCapitalizado,
      novoOuNova: _novoOuNova,
      cadastradoOuCadastrada: _cadastradoOuCadastrada,
      doOuDa: _doOuDa,
    );
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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FA),
        appBar: AppBar(
          title: Image.asset(
            'assets/images/logo_mentall.png',
            height: 32,
          ),
          centerTitle: false,
          backgroundColor: _azul,
          foregroundColor: Colors.white,
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
                  case 'servidor':
                    _abrirConfigServidor();
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
                PopupMenuItem(
                  value: 'servidor',
                  child: Row(
                    children: [
                      Icon(Icons.dns_outlined, size: 20),
                      SizedBox(width: 10),
                      Text('Configurar servidor'),
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
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _saudacaoCabecalho(nomeProf),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            const SliverToBoxAdapter(child: _AgendaInline()),
            SliverToBoxAdapter(child: _indicadorPendencias()),
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
                  tabs: const [
                    Tab(text: 'Ativos'),
                    Tab(text: 'Arquivados'),
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

  Widget _saudacaoCabecalho(String nomeProf) {
    final saudacao = _saudacao;
    final texto = nomeProf.isNotEmpty ? '$saudacao, $nomeProf!' : saudacao;
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w300,
        color: Color(0xFF1E293B),
        height: 1.3,
      ),
    );
  }
}

class _AgendaInline extends ConsumerWidget {
  static const _diasSemana = [
    'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo',
  ];
  static const _meses = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];

  const _AgendaInline();

  String _formatarDataCompacta(DateTime data) {
    final hoje = DateTime.now();
    final hojeDia = DateTime(hoje.year, hoje.month, hoje.day);
    final dataDia = DateTime(data.year, data.month, data.day);
    final diff = dataDia.difference(hojeDia).inDays;

    if (diff == 0) return 'Hoje';
    if (diff == -1) return 'Ontem';
    if (diff == 1) return 'Amanhã';

    final diaSemana = _diasSemana[data.weekday - 1];
    final mes = _meses[data.month - 1];
    return '$diaSemana, ${data.day} $mes';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataSelecionada = ref.watch(_agendaDataProvider);
    final compService = ref.watch(compromissoServiceProvider);
    final pacService = ref.watch(pacienteServiceProvider);

    final compromissos = compService.listarPorData(dataSelecionada);
    final hoje = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final isHoje = dataSelecionada == hoje;

    final titulo = _formatarDataCompacta(dataSelecionada);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDBEAFE), width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 4, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      ref.read(_agendaDataProvider.notifier).update(
                            (d) => d.subtract(const Duration(days: 1)),
                          );
                    },
                    icon: const Icon(Icons.chevron_left, size: 20),
                    splashRadius: 18,
                    color: const Color(0xFF2563EB),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 14, color: Color(0xFF2563EB)),
                        const SizedBox(width: 6),
                        Text(
                          titulo,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      ref.read(_agendaDataProvider.notifier).update(
                            (d) => d.add(const Duration(days: 1)),
                          );
                    },
                    icon: const Icon(Icons.chevron_right, size: 20),
                    splashRadius: 18,
                    color: const Color(0xFF2563EB),
                  ),
                ],
              ),
            ),
            if (compromissos.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isHoje
                            ? 'Nenhum compromisso para hoje'
                            : 'Nenhum compromisso nesta data',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    _AddAgendaButton(
                      dataSelecionada: dataSelecionada,
                    ),
                  ],
                ),
              )
            else ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
                  itemCount: compromissos.length,
                  itemBuilder: (context, index) {
                    final c = compromissos[index];
                    final paciente =
                        pacService.buscarPacientePorId(c.pacienteId);
                    final nomePaciente =
                        paciente?.nomeExibicao ?? 'Pessoa não encontrada';

                    return _CompromissoMiniCard(
                      compromisso: c,
                      nomePaciente: nomePaciente,
                      onTap: () => _editarCompromisso(context, ref, c),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _AddAgendaButton(dataSelecionada: dataSelecionada),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editarCompromisso(
    BuildContext context,
    WidgetRef ref,
    Compromisso compromisso,
  ) async {
    final service = ref.read(compromissoServiceProvider);
    final pacientes = ref.read(pacienteServiceProvider).listarPacientesAtivos();

    final editado = await mostrarCompromissoFormDialog(
      context: context,
      pacientes: pacientes,
      compromissoExistente: compromisso,
    );

    if (editado == null) return;
    await service.atualizar(editado);
  }
}

class _CompromissoMiniCard extends StatelessWidget {
  final Compromisso compromisso;
  final String nomePaciente;
  final VoidCallback onTap;

  const _CompromissoMiniCard({
    required this.compromisso,
    required this.nomePaciente,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = compromisso.statusEnum;
    final cor = status == StatusCompromisso.agendado
        ? const Color(0xFF2563EB)
        : status == StatusCompromisso.realizado
            ? const Color(0xFF2E7D32)
            : status == StatusCompromisso.cancelado
                ? const Color(0xFF757575)
                : const Color(0xFFC62828);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              compromisso.horarioInicioFormatado,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                nomePaciente,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF475569),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!compromisso.isAgendado)
              Text(
                status == StatusCompromisso.realizado
                    ? 'OK'
                    : status == StatusCompromisso.cancelado
                        ? 'Canc'
                        : 'Faltou',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: cor,
                ),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }
}

class _AddAgendaButton extends ConsumerWidget {
  final DateTime dataSelecionada;
  const _AddAgendaButton({required this.dataSelecionada});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        final service = ref.read(compromissoServiceProvider);
        final pacientes =
            ref.read(pacienteServiceProvider).listarPacientesAtivos();
        if (pacientes.isEmpty) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cadastre pacientes primeiro.')),
          );
          return;
        }
        final compromisso = await mostrarCompromissoFormDialog(
          context: context,
          pacientes: pacientes,
          dataSugerida: dataSelecionada,
        );
        if (compromisso == null) return;
        await service.adicionar(compromisso);
      },
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, size: 16, color: Color(0xFF2563EB)),
          SizedBox(width: 4),
          Text(
            'Novo compromisso',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2563EB),
            ),
          ),
        ],
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
