import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/compromisso.dart';
import '../models/enums.dart';
import '../models/paciente.dart';
import '../providers/service_providers.dart';
import '../services/paciente_service.dart';
import '../services/compromisso_service.dart';
import '../screens/paciente_detail_page.dart';
import '../widgets/compromisso_form_dialog.dart';
import '../utils/mentall_colors.dart';

final _dataSelecionadaProvider = StateProvider<DateTime>((ref) {
  final agora = DateTime.now();
  return DateTime(agora.year, agora.month, agora.day);
});

final _modoAgendaProvider = StateProvider<String>((ref) => 'dia');

final _refreshAgendaProvider = StateProvider<int>((ref) => 0);

class AgendaPage extends ConsumerStatefulWidget {
  const AgendaPage({super.key});

  @override
  ConsumerState<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends ConsumerState<AgendaPage> {
  static const _diasSemana = [
    'Segunda-feira', 'Terça-feira', 'Quarta-feira',
    'Quinta-feira', 'Sexta-feira', 'Sábado', 'Domingo',
  ];
  static const _diasSemanaAbrev = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
  static const _meses = [
    'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
    'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
  ];
  static const _mesesAbrev = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];
  static const _mesesLongos = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  List<Compromisso> _compromissosDoModo(
    DateTime data,
    String modo,
    CompromissoService service,
  ) {
    switch (modo) {
      case 'semana':
        return service.listarPorSemana(data);
      case 'mes':
        return service.listarPorMes(data);
      default:
        return service.listarPorData(data);
    }
  }

  String _formatarDataLonga(DateTime data) {
    final diaSemana = _diasSemana[data.weekday - 1];
    final mes = _meses[data.month - 1];
    return '$diaSemana, ${data.day} de $mes';
  }

  List<DateTime> _diasDaSemana(DateTime data) {
    final segunda = data.subtract(Duration(days: data.weekday - 1));
    return List.generate(7, (i) => segunda.add(Duration(days: i)));
  }

  void _navegarAnterior() {
    final modo = ref.read(_modoAgendaProvider);
    if (modo == 'mes') {
      ref.read(_dataSelecionadaProvider.notifier).update(
        (d) {
          final novoMes = d.month - 1;
          if (novoMes < 1) return DateTime(d.year - 1, 12, 1);
          return DateTime(d.year, novoMes, 1);
        },
      );
    } else if (modo == 'semana') {
      ref.read(_dataSelecionadaProvider.notifier).update(
            (state) => state.subtract(const Duration(days: 7)),
          );
    } else {
      ref.read(_dataSelecionadaProvider.notifier).update(
            (state) => state.subtract(const Duration(days: 1)),
          );
    }
  }

  void _navegarProximo() {
    final modo = ref.read(_modoAgendaProvider);
    if (modo == 'mes') {
      ref.read(_dataSelecionadaProvider.notifier).update(
        (d) {
          final novoMes = d.month + 1;
          if (novoMes > 12) return DateTime(d.year + 1, 1, 1);
          return DateTime(d.year, novoMes, 1);
        },
      );
    } else if (modo == 'semana') {
      ref.read(_dataSelecionadaProvider.notifier).update(
            (state) => state.add(const Duration(days: 7)),
          );
    } else {
      ref.read(_dataSelecionadaProvider.notifier).update(
            (state) => state.add(const Duration(days: 1)),
          );
    }
  }

  void _irParaHoje() {
    final agora = DateTime.now();
    ref.read(_dataSelecionadaProvider.notifier).state =
        DateTime(agora.year, agora.month, agora.day);
    ref.read(_modoAgendaProvider.notifier).state = 'dia';
  }

  Future<void> _novoCompromisso({DateTime? dataSugerida}) async {
    final service = ref.read(compromissoServiceProvider);
    final pacientes = ref.read(pacienteServiceProvider).listarPacientesAtivos();

    if (pacientes.isEmpty) {
      if (!mounted) return;
      final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
      final termo = perfil?.termoPlural ?? 'pacientes';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cadastre $termo primeiro para agendar sessões.')),
      );
      return;
    }

    final data = dataSugerida ?? ref.read(_dataSelecionadaProvider);
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
    final config = ref.read(configuracoesServiceProvider);
    final compromisso = await mostrarCompromissoFormDialog(
      context: context,
      pacientes: pacientes,
      termoPessoa: perfil?.termoSingularCapitalizado ?? 'Pessoa atendida',
      dataSugerida: data,
      duracaoPadraoMinutos: config.duracaoPadraoSessaoMinutos,
      lembretePadraoAtivado: config.lembretePadraoAtivado,
      antecedenciaPadraoMinutos: config.antecedenciaPadraoMinutos,
    );

    if (compromisso == null) return;

    final gerados = await service.adicionarComRecorrencia(compromisso);
    final pacienteAgendado = pacientes
        .where((p) => p.id == compromisso.pacienteId)
        .toList();
    await ref.read(auditoriaServiceProvider).registrar(
          tipoEvento: 'Sessão agendada',
          descricao: pacienteAgendado.isNotEmpty
              ? pacienteAgendado.first.nome
              : 'Compromisso criado${gerados.length > 1 ? ' (${gerados.length}x)' : ''}',
          pacienteId: compromisso.pacienteId,
        );
    for (final c in gerados) {
      await _agendarLembrete(ref, c);
    }
    ref.read(_refreshAgendaProvider.notifier).update((n) => n + 1);
  }

  Future<void> _editarCompromisso(Compromisso compromisso) async {
    final service = ref.read(compromissoServiceProvider);
    final pacientes = ref.read(pacienteServiceProvider).listarPacientesAtivos();

    final editado = await mostrarCompromissoFormDialog(
      context: context,
      pacientes: pacientes,
      termoPessoa: ref.read(perfilProfissionalServiceProvider).obterPerfil()?.termoSingularCapitalizado ?? 'Pessoa atendida',
      compromissoExistente: compromisso,
    );

    if (editado == null) return;
    await service.atualizar(editado);
    await _agendarLembrete(ref, editado);
    ref.read(_refreshAgendaProvider.notifier).update((n) => n + 1);
  }

  Future<void> _agendarLembrete(WidgetRef ref, Compromisso compromisso) async {
    if (!compromisso.lembreteAtivado || !compromisso.isAgendado) return;
    final pacienteService = ref.read(pacienteServiceProvider);
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
    final paciente = pacienteService.buscarPacientePorId(compromisso.pacienteId);
    if (paciente == null) return;
    final lembreteService = ref.read(lembreteServiceProvider);
    await lembreteService.agendarLembrete(
      compromisso: compromisso,
      nomePaciente: paciente.nome,
      nomeProfissional: perfil?.nome ?? 'Profissional',
      telefonePaciente: paciente.contato,
    );
  }

  Future<void> _confirmarRemocao(Compromisso compromisso) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover compromisso'),
        content: const Text('Deseja remover este compromisso da agenda?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    await ref.read(compromissoServiceProvider).remover(compromisso);
    ref.read(_refreshAgendaProvider.notifier).update((n) => n + 1);
  }

  Future<void> _marcarRealizado(Compromisso compromisso) async {
    await ref.read(compromissoServiceProvider).marcarComoRealizado(compromisso);
    ref.read(_refreshAgendaProvider.notifier).update((n) => n + 1);
  }

  Future<void> _marcarCancelado(Compromisso compromisso) async {
    await ref.read(compromissoServiceProvider).marcarComoCancelado(compromisso);
    ref.read(_refreshAgendaProvider.notifier).update((n) => n + 1);
  }

  Future<void> _marcarFaltou(Compromisso compromisso) async {
    await ref.read(compromissoServiceProvider).marcarComoFaltou(compromisso);
    ref.read(_refreshAgendaProvider.notifier).update((n) => n + 1);
  }

  Future<void> _marcarAgendado(Compromisso compromisso) async {
    await ref.read(compromissoServiceProvider).marcarComoAgendado(compromisso);
    ref.read(_refreshAgendaProvider.notifier).update((n) => n + 1);
  }

  void _abrirPaciente(Paciente paciente) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PacienteDetailPage(paciente: paciente),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(_refreshAgendaProvider);
    final dataSelecionada = ref.watch(_dataSelecionadaProvider);
    final modo = ref.watch(_modoAgendaProvider);
    final compService = ref.watch(compromissoServiceProvider);
    final pacienteService = ref.watch(pacienteServiceProvider);
    final theme = Theme.of(context);
    final corPrimaria = theme.colorScheme.primary;
    final corSurface = theme.colorScheme.surface;
    final corOnPrimaria = theme.colorScheme.onPrimary;
    final corMuted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    final compromissosDoPeriodo =
        _compromissosDoModo(dataSelecionada, modo, compService);

    final hoje = DateTime.now();
    final hojeInicio = DateTime(hoje.year, hoje.month, hoje.day);
    final isHoje = dataSelecionada == hojeInicio;

    final dataFormatada = _formatarDataLonga(dataSelecionada);

    final ontem = hojeInicio.subtract(const Duration(days: 1));
    final amanha = hojeInicio.add(const Duration(days: 1));
    final isAmanha = dataSelecionada == amanha;
    final isOntem = dataSelecionada == ontem;

    String titulo;
    if (modo == 'mes') {
      titulo =
          '${_mesesLongos[dataSelecionada.month - 1]} ${dataSelecionada.year}';
    } else if (modo == 'semana') {
      final dias = _diasDaSemana(dataSelecionada);
      titulo =
          '${dias.first.day} ${_mesesAbrev[dias.first.month - 1]} - ${dias.last.day} ${_mesesAbrev[dias.last.month - 1]}';
    } else if (isHoje) {
      titulo = 'Hoje';
    } else if (isOntem) {
      titulo = 'Ontem';
    } else if (isAmanha) {
      titulo = 'Amanhã';
    } else {
      titulo = dataFormatada;
    }

    return Scaffold(
      backgroundColor: corSurface,
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
          if (!isHoje || modo != 'dia')
            TextButton.icon(
              onPressed: _irParaHoje,
              icon: Icon(Icons.today, color: corOnPrimaria, size: 20),
              label: Text(
                'Hoje',
                style: TextStyle(color: corOnPrimaria),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _buildModoSelector(modo, corPrimaria, corMuted),
          _SeletorData(
            data: dataSelecionada,
            onAnterior: _navegarAnterior,
            onProximo: _navegarProximo,
            titulo: titulo,
          ),
          if (modo == 'semana')
            _buildWeekStrip(dataSelecionada, hojeInicio),
          if (modo == 'mes')
            _buildMonthGrid(dataSelecionada, hojeInicio, compService),
          Expanded(
            child: compromissosDoPeriodo.isEmpty
                ? _EstadoVazioAgenda(
                    onNovo: () => _novoCompromisso(),
                    dataSelecionada: dataSelecionada,
                    isHoje: isHoje,
                    modo: modo,
                  )
                : _ListaCompromissos(
                    compromissos: compromissosDoPeriodo,
                    pacienteService: pacienteService,
                    onEditar: _editarCompromisso,
                    onRemover: _confirmarRemocao,
                    onMarcarRealizado: _marcarRealizado,
                    onMarcarCancelado: _marcarCancelado,
                    onMarcarFaltou: _marcarFaltou,
                    onMarcarAgendado: _marcarAgendado,
                    onAbrirPaciente: _abrirPaciente,
                    modo: modo,
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _novoCompromisso(),
        icon: const Icon(Icons.add),
        label: const Text('Novo compromisso'),
      ),
    );
  }

  Widget _buildModoSelector(String modo, Color corPrimaria, Color corMuted) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _modoTab('Dia', 'dia', modo, corPrimaria, corMuted),
        const SizedBox(width: 4),
        _modoTab('Semana', 'semana', modo, corPrimaria, corMuted),
        const SizedBox(width: 4),
        _modoTab('Mês', 'mes', modo, corPrimaria, corMuted),
      ],
    );
  }

  Widget _modoTab(String label, String valor, String atual, Color corPrimaria, Color corMuted) {
    final selecionado = atual == valor;
    return GestureDetector(
      onTap: () => ref.read(_modoAgendaProvider.notifier).state = valor,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selecionado ? corPrimaria : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selecionado ? context.corOnPrimaria : corMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildWeekStrip(DateTime centro, DateTime hoje) {
    final dias = _diasDaSemana(centro);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: dias.map((dia) {
          final isSelected = dia == centro;
          final isToday = dia == hoje;
          return Expanded(
            child: GestureDetector(
              onTap: () =>
                  ref.read(_dataSelecionadaProvider.notifier).state = dia,
              child: Container(
                height: 48,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? context.corPrimaria
                      : isToday
                          ? context.cs.primaryContainer
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isToday && !isSelected
                      ? Border.all(color: context.corPrimaria, width: 1)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _diasSemanaAbrev[dia.weekday - 1],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? context.corOnPrimaria
                            : isToday
                                ? context.corPrimaria
                                : context.corTextoMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${dia.day}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? context.corOnPrimaria
                            : isToday
                                ? context.corPrimaria
                                : context.corTextoHeading,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMonthGrid(
    DateTime data,
    DateTime hoje,
    CompromissoService compService,
  ) {
    final inicioMes = DateTime(data.year, data.month, 1);
    final fimMes = DateTime(data.year, data.month + 1, 0);
    final totalDias = fimMes.day;
    final primeiroDiaSemana = inicioMes.weekday;

    final compromissosMes = compService.listarPorMes(data);
    final diasComCompromissos = <int>{
      for (final c in compromissosMes) c.dataHoraInicio.day,
    };

    final celulas = <Widget>[];

    final diasMesAnterior = DateTime(data.year, data.month, 0).day;
    for (int i = primeiroDiaSemana - 1; i > 0; i--) {
      celulas.add(_buildDiaCelula(
        diasMesAnterior - i + 1, data, hoje, diasComCompromissos,
        foraLimite: true, mesAnterior: true,
      ));
    }

    for (int dia = 1; dia <= totalDias; dia++) {
      celulas.add(_buildDiaCelula(dia, data, hoje, diasComCompromissos));
    }

    final resto = celulas.length % 7;
    if (resto != 0) {
      for (int d = 1; d <= 7 - resto; d++) {
        celulas.add(_buildDiaCelula(
          d, data, hoje, diasComCompromissos,
          foraLimite: true, mesAnterior: false,
        ));
      }
    }

    final linhas = <Widget>[];
    for (int i = 0; i < celulas.length; i += 7) {
      linhas.add(Row(
        children: celulas
            .sublist(i, i + 7)
            .map((c) => Expanded(child: Center(child: c)))
            .toList(),
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: _diasSemanaAbrev
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: context.corTextoMuted,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          ...linhas,
        ],
      ),
    );
  }

  Widget _buildDiaCelula(
    int dia,
    DateTime mesAtual,
    DateTime hoje,
    Set<int> diasComCompromissos, {
    bool foraLimite = false,
    bool mesAnterior = false,
  }) {
    DateTime dataDia;
    if (foraLimite) {
      if (mesAnterior) {
        dataDia = DateTime(mesAtual.year, mesAtual.month - 1, dia);
      } else {
        dataDia = DateTime(mesAtual.year, mesAtual.month + 1, dia);
      }
    } else {
      dataDia = DateTime(mesAtual.year, mesAtual.month, dia);
    }

    final isSelected = !foraLimite && dataDia == ref.read(_dataSelecionadaProvider);
    final isToday = dataDia == hoje;
    final temCompromisso = !foraLimite && diasComCompromissos.contains(dia);

    return GestureDetector(
      onTap: () {
        if (!foraLimite) {
          ref.read(_dataSelecionadaProvider.notifier).state = dataDia;
          ref.read(_modoAgendaProvider.notifier).state = 'dia';
        }
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected
              ? context.corPrimaria
              : isToday
                  ? context.cs.primaryContainer
                  : null,
          borderRadius: BorderRadius.circular(8),
          border: isToday && !isSelected
              ? Border.all(color: context.corPrimaria, width: 1)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$dia',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? context.corOnPrimaria
                    : foraLimite
                        ? context.corTextoDisabled
                        : isToday
                            ? context.corPrimaria
                            : context.corTextoHeading,
              ),
            ),
            if (temCompromisso && !isSelected)
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: context.corPrimaria,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SeletorData extends StatelessWidget {
  final DateTime data;
  final VoidCallback onAnterior;
  final VoidCallback? onProximo;
  final String titulo;

  const _SeletorData({
    required this.data,
    required this.onAnterior,
    required this.onProximo,
    required this.titulo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onAnterior,
            icon: Icon(Icons.chevron_left,
                color: Theme.of(context).colorScheme.primary),
            tooltip: 'Dia anterior',
          ),
          Text(
            titulo,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          IconButton(
            onPressed: onProximo,
            icon: onProximo != null
                ? Icon(Icons.chevron_right,
                    color: Theme.of(context).colorScheme.primary)
                : const SizedBox(width: 24),
            tooltip: onProximo != null ? 'Próximo dia' : null,
          ),
        ],
      ),
    );
  }
}

class _EstadoVazioAgenda extends StatelessWidget {
  final VoidCallback onNovo;
  final DateTime dataSelecionada;
  final bool isHoje;
  final String modo;

  const _EstadoVazioAgenda({
    required this.onNovo,
    required this.dataSelecionada,
    required this.isHoje,
    required this.modo,
  });

  String get _mensagem {
    if (modo == 'mes') return 'Nenhum compromisso neste mês';
    if (modo == 'semana') return 'Nenhum compromisso nesta semana';
    return isHoje
        ? 'Nenhum compromisso hoje'
        : 'Nenhum compromisso para esta data';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 64,
              color: context.corTextoDisabled,
            ),
            const SizedBox(height: 16),
            Text(
              _mensagem,
              style: TextStyle(
                fontSize: 18,
                color: context.corTextoSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Adicione sessões para organizar sua agenda.',
              style: TextStyle(fontSize: 14, color: context.corTextoMuted),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onNovo,
              icon: const Icon(Icons.add),
              label: const Text('Novo compromisso'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListaCompromissos extends StatelessWidget {
  final List<Compromisso> compromissos;
  final PacienteService pacienteService;
  final void Function(Compromisso) onEditar;
  final void Function(Compromisso) onRemover;
  final void Function(Compromisso) onMarcarRealizado;
  final void Function(Compromisso) onMarcarCancelado;
  final void Function(Compromisso) onMarcarFaltou;
  final void Function(Compromisso) onMarcarAgendado;
  final void Function(Paciente) onAbrirPaciente;
  final String modo;

  const _ListaCompromissos({
    required this.compromissos,
    required this.pacienteService,
    required this.onEditar,
    required this.onRemover,
    required this.onMarcarRealizado,
    required this.onMarcarCancelado,
    required this.onMarcarFaltou,
    required this.onMarcarAgendado,
    required this.onAbrirPaciente,
    required this.modo,
  });

  @override
  Widget build(BuildContext context) {
    if (modo == 'semana' || modo == 'mes') {
      return _buildAgrupadoPorData();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: compromissos.length,
      itemBuilder: (context, index) {
        final compromisso = compromissos[index];
        final paciente = pacienteService.buscarPacientePorId(
          compromisso.pacienteId,
        );
        return _CompromissoCard(
          compromisso: compromisso,
          paciente: paciente,
          onEditar: () => onEditar(compromisso),
          onRemover: () => onRemover(compromisso),
          onMarcarRealizado: () => onMarcarRealizado(compromisso),
          onMarcarCancelado: () => onMarcarCancelado(compromisso),
          onMarcarFaltou: () => onMarcarFaltou(compromisso),
          onMarcarAgendado: () => onMarcarAgendado(compromisso),
          onAbrirPaciente: paciente != null
              ? () => onAbrirPaciente(paciente)
              : null,
        );
      },
    );
  }

  Widget _buildAgrupadoPorData() {
    final Map<String, List<Compromisso>> agrupados = {};
    for (final c in compromissos) {
      final chave = '${c.dataHoraInicio.year}-'
          '${c.dataHoraInicio.month.toString().padLeft(2, '0')}-'
          '${c.dataHoraInicio.day.toString().padLeft(2, '0')}';
      agrupados.putIfAbsent(chave, () => []).add(c);
    }

    final chaves = agrupados.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: chaves.length,
      itemBuilder: (context, index) {
        final chave = chaves[index];
        final comps = agrupados[chave]!;
        final data = comps.first.dataHoraInicio;
        final dataFormatada =
            '${data.day.toString().padLeft(2, '0')}/'
            '${data.month.toString().padLeft(2, '0')}';

        final diaSemana = [
          '', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab', 'Dom',
        ][data.weekday];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
              child: Text(
                '$diaSemana, $dataFormatada',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.corTextoMuted,
                ),
              ),
            ),
            ...comps.map((c) {
              final paciente = pacienteService.buscarPacientePorId(
                c.pacienteId,
              );
              return _CompromissoCard(
                compromisso: c,
                paciente: paciente,
                onEditar: () => onEditar(c),
                onRemover: () => onRemover(c),
                onMarcarRealizado: () => onMarcarRealizado(c),
                onMarcarCancelado: () => onMarcarCancelado(c),
                onMarcarFaltou: () => onMarcarFaltou(c),
                onMarcarAgendado: () => onMarcarAgendado(c),
                onAbrirPaciente: paciente != null
                    ? () => onAbrirPaciente(paciente)
                    : null,
              );
            }),
          ],
        );
      },
    );
  }
}

class _CompromissoCard extends StatelessWidget {
  final Compromisso compromisso;
  final Paciente? paciente;
  final VoidCallback onEditar;
  final VoidCallback onRemover;
  final VoidCallback onMarcarRealizado;
  final VoidCallback onMarcarCancelado;
  final VoidCallback onMarcarFaltou;
  final VoidCallback onMarcarAgendado;
  final VoidCallback? onAbrirPaciente;

  const _CompromissoCard({
    required this.compromisso,
    required this.paciente,
    required this.onEditar,
    required this.onRemover,
    required this.onMarcarRealizado,
    required this.onMarcarCancelado,
    required this.onMarcarFaltou,
    required this.onMarcarAgendado,
    required this.onAbrirPaciente,
  });

  Color _corStatus(StatusCompromisso status) {
    switch (status) {
      case StatusCompromisso.agendado:
        return const Color(0xFF1976D2);
      case StatusCompromisso.realizado:
        return const Color(0xFF2E7D32);
      case StatusCompromisso.cancelado:
        return const Color(0xFF757575);
      case StatusCompromisso.faltou:
        return const Color(0xFFC62828);
    }
  }

  String _labelStatus(StatusCompromisso status) {
    switch (status) {
      case StatusCompromisso.agendado:
        return 'Agendado';
      case StatusCompromisso.realizado:
        return 'Realizado';
      case StatusCompromisso.cancelado:
        return 'Cancelado';
      case StatusCompromisso.faltou:
        return 'Faltou';
    }
  }

  IconData _iconeStatus(StatusCompromisso status) {
    switch (status) {
      case StatusCompromisso.agendado:
        return Icons.schedule;
      case StatusCompromisso.realizado:
        return Icons.check_circle_outline;
      case StatusCompromisso.cancelado:
        return Icons.cancel_outlined;
      case StatusCompromisso.faltou:
        return Icons.person_off_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = compromisso.statusEnum;
    final corStatus = _corStatus(status);
    final nomePaciente = paciente?.nome ?? 'Pessoa não encontrada';
    final titulo = compromisso.titulo.trim().isNotEmpty
        ? compromisso.titulo.trim()
        : null;
    final c = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: compromisso.isAgendado ? corStatus.withValues(alpha: 0.3) : Colors.transparent,
          width: compromisso.isAgendado ? 1.5 : 0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onEditar,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time, size: 16, color: c.onSurface.withValues(alpha: 0.6)),
                              const SizedBox(width: 6),
                              Text(
                                '${compromisso.horarioInicioFormatado} - ${compromisso.horarioFimFormatado}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: c.onSurface,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          compromisso.duracaoFormatada,
                          style: TextStyle(
                            fontSize: 11,
                            color: c.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const Spacer(),
                        if (compromisso.temRecorrencia || compromisso.ehFilhoDeRecorrencia)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.repeat,
                              size: 18,
                              color: corStatus.withValues(alpha: 0.7),
                            ),
                          ),
                        if (compromisso.lembreteAtivado && compromisso.isAgendado)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.notifications_active_rounded,
                              size: 18,
                              color: corStatus.withValues(alpha: 0.7),
                            ),
                          ),
                        _ChipStatus(
                          label: _labelStatus(status),
                          cor: corStatus,
                          icone: _iconeStatus(status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: corStatus.withValues(alpha: 0.15),
                          backgroundImage: paciente?.possuiFoto == true
                              ? MemoryImage(base64Decode(paciente!.fotoBase64))
                              : null,
                          child: paciente?.possuiFoto != true
                              ? Text(
                                  nomePaciente.isNotEmpty
                                      ? nomePaciente[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: corStatus,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nomePaciente,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              if (titulo != null)
                                Text(
                                  titulo,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: c.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (onAbrirPaciente != null)
                          IconButton(
                            onPressed: onAbrirPaciente,
                            icon: const Icon(Icons.person_outline, size: 20),
                            tooltip: 'Ver ${paciente?.nome ?? 'pessoa'}',
                            style: IconButton.styleFrom(
                              foregroundColor: c.primary,
                            ),
                          ),
                      ],
                    ),
                    if (compromisso.observacoes.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          compromisso.observacoes.trim(),
                          style: TextStyle(fontSize: 13, color: c.onSurface.withValues(alpha: 0.6)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (compromisso.isAgendado) ...[
                  _IconAcao(
                    icone: Icons.check_circle_outline,
                    cor: const Color(0xFF2E7D32),
                    tooltip: 'Realizado',
                    onPressed: onMarcarRealizado,
                  ),
                  const SizedBox(width: 4),
                  _IconAcao(
                    icone: Icons.person_off_outlined,
                    cor: const Color(0xFFC62828),
                    tooltip: 'Faltou',
                    onPressed: onMarcarFaltou,
                  ),
                  const SizedBox(width: 4),
                  _IconAcao(
                    icone: Icons.cancel_outlined,
                    cor: const Color(0xFF757575),
                    tooltip: 'Cancelar',
                    onPressed: onMarcarCancelado,
                  ),
                ] else ...[
                  _IconAcao(
                    icone: Icons.restore_outlined,
                    cor: const Color(0xFF1976D2),
                    tooltip: 'Reagendar',
                    onPressed: onMarcarAgendado,
                  ),
                ],
                const SizedBox(width: 4),
                _IconAcao(
                  icone: Icons.delete_outline,
                  cor: const Color(0xFFD32F2F),
                  tooltip: 'Remover',
                  onPressed: onRemover,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipStatus extends StatelessWidget {
  final String label;
  final Color cor;
  final IconData icone;

  const _ChipStatus({
    required this.label,
    required this.cor,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icone, size: 16, color: cor),
      ),
    );
  }
}

class _IconAcao extends StatelessWidget {
  final IconData icone;
  final Color cor;
  final String tooltip;
  final VoidCallback onPressed;

  const _IconAcao({
    required this.icone,
    required this.cor,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icone, size: 20, color: cor),
        ),
      ),
    );
  }
}
