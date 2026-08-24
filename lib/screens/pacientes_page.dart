import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/paciente.dart';
import '../providers/service_providers.dart';
import '../services/logger.dart';
import '../widgets/estado_vazio_pacientes.dart';
import '../utils/responsivo.dart';
import '../widgets/novo_paciente_dialog.dart';
import '../widgets/paciente_card_home.dart';
import 'paciente_detail_page.dart';

class PacientesPage extends ConsumerStatefulWidget {
  const PacientesPage({super.key});

  @override
  ConsumerState<PacientesPage> createState() => _PacientesPageState();
}

class _PacientesPageState extends ConsumerState<PacientesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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

  bool get _termoFeminino => _termoSingular == 'pessoa atendida';

  String get _nenhumOuNenhuma => _termoFeminino ? 'Nenhuma' : 'Nenhum';
  String get _primeiroOuPrimeira => _termoFeminino ? 'primeira' : 'primeiro';
  String get _cadastradoOuCadastrada =>
      _termoFeminino ? 'cadastrada' : 'cadastrado';
  String get _arquivadoOuArquivada =>
      _termoFeminino ? 'arquivada' : 'arquivado';
  String get _restauradoOuRestaurada =>
      _termoFeminino ? 'restaurada' : 'restaurado';
  String get _doOuDa => _termoFeminino ? 'da' : 'do';
  String get _novoOuNova => _termoFeminino ? 'Nova' : 'Novo';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
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

  Future<void> _confirmarArquivamentoPaciente(Paciente paciente) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Arquivar $_termoSingular'),
        content: Text(
          'Deseja arquivar $_termoSingular ${paciente.nome}?\n\n'
          'O cadastro deixará de aparecer na lista ativa, mas continuará preservado e poderá ser restaurado posteriormente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Arquivar'),
          ),
        ],
      ),
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
      Log.erro(erro, contexto: 'pacientes_page:arquivar');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível arquivar $_doOuDa $_termoSingular.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmarRestauracaoPaciente(Paciente paciente) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Restaurar $_termoSingular'),
        content: Text(
          'Deseja restaurar $_termoSingular ${paciente.nome}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.restore_outlined),
            label: const Text('Restaurar'),
          ),
        ],
      ),
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
      Log.erro(erro, contexto: 'pacientes_page:restaurar');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível restaurar $_doOuDa $_termoSingular.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(perfilRevisaoProvider);
    final pacientesAtivos =
        ref.watch(pacientesAtivosProvider).valueOrNull ?? [];
    final pacientesArquivados =
        ref.watch(pacientesArquivadosProvider).valueOrNull ?? [];

    final sessaoService = ref.watch(sessaoServiceProvider);
    final pendentesPorPaciente = sessaoService.contarSessoesPendentesAgrupadas();
    final Map<String, int> ativosComPendentes = {};
    for (final p in pacientesAtivos) {
      final c = pendentesPorPaciente[p.id] ?? 0;
      if (c > 0) ativosComPendentes[p.id] = c;
    }
    final Map<String, int> arquivadosComPendentes = {};
    for (final p in pacientesArquivados) {
      final c = pendentesPorPaciente[p.id] ?? 0;
      if (c > 0) arquivadosComPendentes[p.id] = c;
    }

    final termoPluralCapitalizado = _termoPlural.isNotEmpty
        ? '${_termoPlural[0].toUpperCase()}${_termoPlural.substring(1)}'
        : 'Pacientes';

    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          termoPluralCapitalizado,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: colors.onPrimary,
          ),
        ),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 0,
        actions: [
          Semantics(
            label: 'Adicionar paciente',
            child: IconButton(
              icon: const Icon(Icons.add),
              tooltip: '$_novoOuNova $_termoSingular',
              onPressed: _abrirDialogNovoPaciente,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _SegmentedControl(
              selectedIndex: _tabController.index,
              onSelected: (i) => _tabController.animateTo(i),
              segments: [
                _SegmentData(label: 'Ativos', count: pacientesAtivos.length),
                _SegmentData(
                  label: 'Arquivados',
                  count: pacientesArquivados.length,
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
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
            onAbrirPaciente: (p) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PacienteDetailPage(paciente: p),
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
            onAbrirPaciente: (p) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PacienteDetailPage(paciente: p),
                ),
              );
            },
            onArquivarPaciente: _confirmarArquivamentoPaciente,
            onRestaurarPaciente: _confirmarRestauracaoPaciente,
          ),
        ],
      ),
    );
  }
}

class _SegmentData {
  final String label;
  final int count;

  const _SegmentData({required this.label, required this.count});
}

class _SegmentedControl extends StatelessWidget {
  final List<_SegmentData> segments;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _SegmentedControl({
    required this.segments,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.onPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.onPrimary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: _Segment(
                data: segments[i],
                selected: selectedIndex == i,
                onTap: () => onSelected(i),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final _SegmentData data;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: selected ? colors.onPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                data.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? colors.primary
                      : colors.onPrimary.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? colors.primary.withValues(alpha: 0.12)
                      : colors.onPrimary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${data.count}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected ? colors.primary : colors.onPrimary,
                  ),
                ),
              ),
            ],
          ),
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

    return LayoutBuilder(
      builder: (_, constraints) {
        if (Responsivo.isTablet(context)) {
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 420,
              mainAxisExtent: 92,
              mainAxisSpacing: 0,
              crossAxisSpacing: 10,
            ),
            itemCount: pacientes.length,
            itemBuilder: (context, index) {
              final paciente = pacientes[index];
              return PacienteCardHome(
                paciente: paciente,
                termoSingular: termoSingular,
                listaArquivada: listaArquivada,
                sessoesPendentes: sessoesPendentesPorPaciente[paciente.id] ?? 0,
                onTap: () => onAbrirPaciente(paciente),
                onArquivar: () => onArquivarPaciente(paciente),
                onRestaurar: () => onRestaurarPaciente(paciente),
              );
            },
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: pacientes.length,
          separatorBuilder: (_, _) => const SizedBox(height: 0),
          itemBuilder: (context, index) {
            final paciente = pacientes[index];
            return PacienteCardHome(
              paciente: paciente,
              termoSingular: termoSingular,
              listaArquivada: listaArquivada,
              sessoesPendentes: sessoesPendentesPorPaciente[paciente.id] ?? 0,
              onTap: () => onAbrirPaciente(paciente),
              onArquivar: () => onArquivarPaciente(paciente),
              onRestaurar: () => onRestaurarPaciente(paciente),
            );
          },
        );
      },
    );
  }
}
