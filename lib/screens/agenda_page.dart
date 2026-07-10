import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/compromisso.dart';
import '../models/enums.dart';
import '../models/paciente.dart';
import '../providers/service_providers.dart';
import '../services/paciente_service.dart';
import '../screens/paciente_detail_page.dart';
import '../widgets/compromisso_form_dialog.dart';

final _dataSelecionadaProvider = StateProvider<DateTime>((ref) {
  final agora = DateTime.now();
  return DateTime(agora.year, agora.month, agora.day);
});

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
  static const _meses = [
    'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
    'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
  ];

  String _formatarDataLonga(DateTime data) {
    final diaSemana = _diasSemana[data.weekday - 1];
    final mes = _meses[data.month - 1];
    return '$diaSemana, ${data.day} de $mes';
  }

  void _diaAnterior() {
    ref.read(_dataSelecionadaProvider.notifier).update(
          (state) => state.subtract(const Duration(days: 1)),
        );
  }

  void _proximoDia() {
    ref.read(_dataSelecionadaProvider.notifier).update(
          (state) => state.add(const Duration(days: 1)),
        );
  }

  void _irParaHoje() {
    final agora = DateTime.now();
    ref.read(_dataSelecionadaProvider.notifier).state =
        DateTime(agora.year, agora.month, agora.day);
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
    final compromisso = await mostrarCompromissoFormDialog(
      context: context,
      pacientes: pacientes,
      dataSugerida: data,
    );

    if (compromisso == null) return;
    await service.adicionar(compromisso);
  }

  Future<void> _editarCompromisso(Compromisso compromisso) async {
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
              backgroundColor: Colors.red.shade600,
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    await ref.read(compromissoServiceProvider).remover(compromisso);
  }

  Future<void> _marcarRealizado(Compromisso compromisso) async {
    await ref.read(compromissoServiceProvider).marcarComoRealizado(compromisso);
  }

  Future<void> _marcarCancelado(Compromisso compromisso) async {
    await ref.read(compromissoServiceProvider).marcarComoCancelado(compromisso);
  }

  Future<void> _marcarFaltou(Compromisso compromisso) async {
    await ref.read(compromissoServiceProvider).marcarComoFaltou(compromisso);
  }

  Future<void> _marcarAgendado(Compromisso compromisso) async {
    await ref.read(compromissoServiceProvider).marcarComoAgendado(compromisso);
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
    final dataSelecionada = ref.watch(_dataSelecionadaProvider);
    final compromissoService = ref.watch(compromissoServiceProvider);
    final pacienteService = ref.watch(pacienteServiceProvider);

    final compromissosDoDia = compromissoService.listarPorData(dataSelecionada);

    final hoje = DateTime.now();
    final hojeInicio = DateTime(hoje.year, hoje.month, hoje.day);
    final isHoje = dataSelecionada == hojeInicio;

    final dataFormatada = _formatarDataLonga(dataSelecionada);

    final ontem = hojeInicio.subtract(const Duration(days: 1));
    final amanha = hojeInicio.add(const Duration(days: 1));
    final isAmanha = dataSelecionada == amanha;
    final isOntem = dataSelecionada == ontem;

    String tituloDia;
    if (isHoje) {
      tituloDia = 'Hoje';
    } else if (isOntem) {
      tituloDia = 'Ontem';
    } else if (isAmanha) {
      tituloDia = 'Amanhã';
    } else {
      tituloDia = dataFormatada;
    }

    final passaFuturo = dataSelecionada.isAfter(hojeInicio.add(const Duration(days: 365)));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FA),
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
          if (!isHoje)
            TextButton.icon(
              onPressed: _irParaHoje,
              icon: const Icon(Icons.today, color: Colors.white, size: 20),
              label: const Text(
                'Hoje',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _SeletorData(
            data: dataSelecionada,
            onAnterior: _diaAnterior,
            onProximo: !passaFuturo ? _proximoDia : null,
            titulo: tituloDia,
          ),
          Expanded(
            child: compromissosDoDia.isEmpty
                ? _EstadoVazioAgenda(
                    onNovo: () => _novoCompromisso(),
                    dataSelecionada: dataSelecionada,
                    isHoje: isHoje,
                  )
                : _ListaCompromissos(
                    compromissos: compromissosDoDia,
                    pacienteService: pacienteService,
                    onEditar: _editarCompromisso,
                    onRemover: _confirmarRemocao,
                    onMarcarRealizado: _marcarRealizado,
                    onMarcarCancelado: _marcarCancelado,
                    onMarcarFaltou: _marcarFaltou,
                    onMarcarAgendado: _marcarAgendado,
                    onAbrirPaciente: _abrirPaciente,
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _novoCompromisso(),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo compromisso'),
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
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onAnterior,
            icon: const Icon(Icons.chevron_left, color: Color(0xFF2563EB)),
            tooltip: 'Dia anterior',
          ),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2563EB),
            ),
          ),
          IconButton(
            onPressed: onProximo,
            icon: onProximo != null
                ? const Icon(Icons.chevron_right, color: Color(0xFF2563EB))
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

  const _EstadoVazioAgenda({
    required this.onNovo,
    required this.dataSelecionada,
    required this.isHoje,
  });

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
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              isHoje
                  ? 'Nenhum compromisso hoje'
                  : 'Nenhum compromisso para esta data',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Adicione sessões para organizar seu dia.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
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
  });

  @override
  Widget build(BuildContext context) {
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: compromisso.isAgendado ? corStatus.withValues(alpha: 0.3) : Colors.transparent,
          width: compromisso.isAgendado ? 1.5 : 0,
        ),
      ),
      child: InkWell(
        onTap: onEditar,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                      color: const Color(0xFFF7F9FA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.grey.shade700),
                        const SizedBox(width: 6),
                        Text(
                          '${compromisso.horarioInicioFormatado} - ${compromisso.horarioFimFormatado}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    compromisso.duracaoFormatada,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const Spacer(),
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
                    child: Text(
                      nomePaciente.isNotEmpty
                          ? nomePaciente[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: corStatus,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nomePaciente,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (titulo != null)
                          Text(
                            titulo,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
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
                        foregroundColor: const Color(0xFF2563EB),
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
                    color: const Color(0xFFF7F9FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    compromisso.observacoes.trim(),
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (compromisso.isAgendado) ...[
                    _AcaoPequena(
                      icone: Icons.check,
                      label: 'Realizado',
                      cor: const Color(0xFF2E7D32),
                      onPressed: onMarcarRealizado,
                    ),
                    const SizedBox(width: 4),
                    _AcaoPequena(
                      icone: Icons.person_off_outlined,
                      label: 'Faltou',
                      cor: const Color(0xFFC62828),
                      onPressed: onMarcarFaltou,
                    ),
                    const SizedBox(width: 4),
                    _AcaoPequena(
                      icone: Icons.cancel_outlined,
                      label: 'Cancelar',
                      cor: const Color(0xFF757575),
                      onPressed: onMarcarCancelado,
                    ),
                  ] else ...[
                    _AcaoPequena(
                      icone: Icons.restore_outlined,
                      label: 'Reagendar',
                      cor: const Color(0xFF1976D2),
                      onPressed: onMarcarAgendado,
                    ),
                  ],
                  const SizedBox(width: 4),
                  _AcaoPequena(
                    icone: Icons.delete_outline,
                    label: 'Remover',
                    cor: Colors.red.shade400,
                    onPressed: onRemover,
                  ),
                ],
              ),
            ],
          ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: cor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }
}

class _AcaoPequena extends StatelessWidget {
  final IconData icone;
  final String label;
  final Color cor;
  final VoidCallback onPressed;

  const _AcaoPequena({
    required this.icone,
    required this.label,
    required this.cor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icone, size: 14, color: cor),
      label: Text(
        label,
        style: TextStyle(fontSize: 11, color: cor),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
