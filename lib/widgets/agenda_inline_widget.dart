import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/compromisso.dart';
import '../models/enums.dart';
import '../providers/service_providers.dart';
import 'compromisso_form_dialog.dart';

final agendaDataProvider = StateProvider<DateTime>((ref) {
  final agora = DateTime.now();
  return DateTime(agora.year, agora.month, agora.day);
});

class AgendaInlineWidget extends ConsumerWidget {
  static const _diasSemana = [
    'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo',
  ];
  static const _meses = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];

  const AgendaInlineWidget({super.key});

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
    final dataSelecionada = ref.watch(agendaDataProvider);
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      ref.read(agendaDataProvider.notifier).update(
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
                      ref.read(agendaDataProvider.notifier).update(
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
      termoPessoa:
          ref.read(perfilProfissionalServiceProvider).obterPerfil()?.termoSingularCapitalizado ?? 'Pessoa atendida',
      compromissoExistente: compromisso,
    );

    if (editado == null) return;
    await service.atualizar(editado);
    await _agendarLembrete(ref, editado);
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
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
            if (compromisso.lembreteAtivado && compromisso.isAgendado)
              const Padding(
                padding: EdgeInsets.only(left: 6, right: 6),
                child: Icon(
                  Icons.notifications_active_rounded,
                  size: 14,
                  color: Color(0xFF2563EB),
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
                  fontSize: 12,
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
          termoPessoa:
              ref.read(perfilProfissionalServiceProvider).obterPerfil()?.termoSingularCapitalizado ?? 'Pessoa atendida',
          dataSugerida: dataSelecionada,
        );
        if (compromisso == null) return;
        await service.adicionar(compromisso);
        if (compromisso.lembreteAtivado && compromisso.isAgendado) {
          final pacService = ref.read(pacienteServiceProvider);
          final perfilService = ref.read(perfilProfissionalServiceProvider);
          final paciente =
              pacService.buscarPacientePorId(compromisso.pacienteId);
          if (paciente != null) {
            final lembreteService = ref.read(lembreteServiceProvider);
            await lembreteService.agendarLembrete(
              compromisso: compromisso,
              nomePaciente: paciente.nome,
              nomeProfissional:
                  perfilService.obterPerfil()?.nome ?? 'Profissional',
              telefonePaciente: paciente.contato,
            );
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, size: 16, color: Color(0xFF2563EB)),
          SizedBox(width: 6),
          Text(
            'Novo compromisso',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2563EB),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

