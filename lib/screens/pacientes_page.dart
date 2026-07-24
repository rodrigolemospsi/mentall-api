import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/paciente.dart';
import '../providers/service_providers.dart';
import '../services/logger.dart';
import '../widgets/estado_vazio_pacientes.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    final pacientesAtivos =
        ref.watch(pacientesAtivosProvider).valueOrNull ?? [];
    final pacientesArquivados =
        ref.watch(pacientesArquivadosProvider).valueOrNull ?? [];

    final sessaoService = ref.watch(sessaoServiceProvider);
    final Map<String, int> ativosComPendentes = {};
    for (final p in pacientesAtivos) {
      final c = sessaoService.contarSessoesPendentesPorPaciente(p.id);
      if (c > 0) ativosComPendentes[p.id] = c;
    }
    final Map<String, int> arquivadosComPendentes = {};
    for (final p in pacientesArquivados) {
      final c = sessaoService.contarSessoesPendentesPorPaciente(p.id);
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
            color: colors.onSurface,
          ),
        ),
        backgroundColor: colors.surface,
        foregroundColor: colors.primary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _PillTab(
                  label: 'Ativos',
                  count: pacientesAtivos.length,
                  selected: _tabController.index == 0,
                  onTap: () => _tabController.animateTo(0),
                ),
                const SizedBox(width: 8),
                _PillTab(
                  label: 'Arquivados',
                  count: pacientesArquivados.length,
                  selected: _tabController.index == 1,
                  onTap: () => _tabController.animateTo(1),
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

class _PillTab extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _PillTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? colors.onPrimary.withValues(alpha: 0.25)
                    : colors.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? colors.onPrimary : colors.primary,
                ),
              ),
            ),
          ],
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

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: pacientes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 0),
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
}
