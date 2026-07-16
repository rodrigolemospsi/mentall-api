import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/compromisso.dart';
import '../models/enums.dart';
import '../providers/service_providers.dart';
import '../services/compromisso_service.dart';
import 'compromisso_form_dialog.dart';

final agendaDataProvider = StateProvider<DateTime>((ref) {
  final agora = DateTime.now();
  return DateTime(agora.year, agora.month, agora.day);
});

final agendaModoProvider = StateProvider<String>((ref) => 'dia');

class AgendaInlineWidget extends ConsumerWidget {
  static const _diasSemana = [
    'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo',
  ];
  static const _diasSemanaAbrev = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
  static const _meses = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];
  static const _mesesLongos = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
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

  List<DateTime> _diasDaSemana(DateTime data) {
    final segunda = data.subtract(Duration(days: data.weekday - 1));
    return List.generate(7, (i) => segunda.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataSelecionada = ref.watch(agendaDataProvider);
    final modo = ref.watch(agendaModoProvider);
    final compromissosAsync = ref.watch(compromissosPorDataProvider(dataSelecionada));
    final pacService = ref.watch(pacienteServiceProvider);
    final compService = ref.watch(compromissoServiceProvider);

    final compromissos = compromissosAsync.value ?? [];
    final hoje = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    String titulo;
    if (modo == 'mes') {
      titulo = '${_mesesLongos[dataSelecionada.month - 1]} ${dataSelecionada.year}';
    } else if (modo == 'semana') {
      final dias = _diasDaSemana(dataSelecionada);
      titulo = '${dias.first.day} ${_meses[dias.first.month - 1]} - ${dias.last.day} ${_meses[dias.last.month - 1]}';
    } else {
      titulo = _formatarDataCompacta(dataSelecionada);
    }

    void navegarAnterior() {
      if (modo == 'mes') {
        ref.read(agendaDataProvider.notifier).update(
          (d) {
            final novoMes = d.month - 1;
            if (novoMes < 1) return DateTime(d.year - 1, 12, 1);
            return DateTime(d.year, novoMes, 1);
          },
        );
      } else if (modo == 'semana') {
        ref.read(agendaDataProvider.notifier).update(
          (d) => d.subtract(const Duration(days: 7)),
        );
      } else {
        ref.read(agendaDataProvider.notifier).update(
          (d) => d.subtract(const Duration(days: 1)),
        );
      }
    }

    void navegarProximo() {
      if (modo == 'mes') {
        ref.read(agendaDataProvider.notifier).update(
          (d) {
            final novoMes = d.month + 1;
            if (novoMes > 12) return DateTime(d.year + 1, 1, 1);
            return DateTime(d.year, novoMes, 1);
          },
        );
      } else if (modo == 'semana') {
        ref.read(agendaDataProvider.notifier).update(
          (d) => d.add(const Duration(days: 7)),
        );
      } else {
        ref.read(agendaDataProvider.notifier).update(
          (d) => d.add(const Duration(days: 1)),
        );
      }
    }

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
            const SizedBox(height: 8),
            _buildModoSelector(ref, modo),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(
                children: [
                  IconButton(
                    onPressed: navegarAnterior,
                    icon: const Icon(Icons.chevron_left, size: 20),
                    splashRadius: 18,
                    color: const Color(0xFF2563EB),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        ref.read(agendaDataProvider.notifier).state = hoje;
                        ref.read(agendaModoProvider.notifier).state = 'dia';
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 14, color: Color(0xFF2563EB)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              titulo,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563EB),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: navegarProximo,
                    icon: const Icon(Icons.chevron_right, size: 20),
                    splashRadius: 18,
                    color: const Color(0xFF2563EB),
                  ),
                ],
              ),
            ),
            if (modo == 'semana') _buildWeekStrip(ref, dataSelecionada, hoje),
            if (modo == 'mes') _buildMonthGrid(ref, dataSelecionada, hoje, compService),
            if (compromissos.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
                child: Text(
                  dataSelecionada == hoje
                      ? 'Nenhum compromisso para hoje'
                      : 'Nenhum compromisso nesta data',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
            ],
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
        ),
      ),
    );
  }

  Widget _buildModoSelector(WidgetRef ref, String modo) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _modoTab('Dia', 'dia', modo, ref),
          const SizedBox(width: 4),
          _modoTab('Semana', 'semana', modo, ref),
          const SizedBox(width: 4),
          _modoTab('Mês', 'mes', modo, ref),
        ],
      ),
    );
  }

  Widget _modoTab(String label, String valor, String atual, WidgetRef ref) {
    final selecionado = atual == valor;
    return GestureDetector(
      onTap: () => ref.read(agendaModoProvider.notifier).state = valor,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selecionado ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selecionado ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildWeekStrip(WidgetRef ref, DateTime centro, DateTime hoje) {
    final dias = _diasDaSemana(centro);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: dias.map((dia) {
          final isSelected = dia == centro;
          final isToday = dia == hoje;
          return GestureDetector(
            onTap: () => ref.read(agendaDataProvider.notifier).state = dia,
            child: Container(
              width: 36,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : isToday
                        ? const Color(0xFFDBEAFE)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isToday && !isSelected
                    ? Border.all(color: const Color(0xFF2563EB), width: 1)
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
                          ? Colors.white
                          : isToday
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${dia.day}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : isToday
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMonthGrid(WidgetRef ref, DateTime data, DateTime hoje, CompromissoService compService) {
    final inicioMes = DateTime(data.year, data.month, 1);
    final fimMes = DateTime(data.year, data.month + 1, 0);
    final totalDias = fimMes.day;
    final primeiroDiaSemana = inicioMes.weekday;

    final compromissosMes = compService.listarPorMes(data);
    final diasComCompromissos = <int>{};
    for (final c in compromissosMes) {
      diasComCompromissos.add(c.dataHoraInicio.day);
    }

    final celulas = <Widget>[];

    // Dias do mês anterior (preencher células vazias)
    final diasMesAnterior = DateTime(data.year, data.month, 0).day;
    for (int i = primeiroDiaSemana - 1; i > 0; i--) {
      final dia = diasMesAnterior - i + 1;
      celulas.add(_buildDiaCelula(
        ref, dia, data, hoje, diasComCompromissos, foraLimite: true, mesAnterior: true,
      ));
    }

    // Dias do mês atual
    for (int dia = 1; dia <= totalDias; dia++) {
      celulas.add(_buildDiaCelula(ref, dia, data, hoje, diasComCompromissos));
    }

    // Preencher até completar a última semana
    final totalCelulas = celulas.length;
    final resto = totalCelulas % 7;
    if (resto != 0) {
      for (int d = 1; d <= 7 - resto; d++) {
        celulas.add(_buildDiaCelula(
          ref, d, data, hoje, diasComCompromissos, foraLimite: true, mesAnterior: false,
        ));
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _diasSemanaAbrev.map((d) => SizedBox(
              width: 36,
              child: Center(
                child: Text(d, style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B),
                )),
              ),
            )).toList(),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 0,
            runSpacing: 0,
            children: celulas,
          ),
        ],
      ),
    );
  }

  Widget _buildDiaCelula(
    WidgetRef ref,
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

    final isSelected = !foraLimite &&
        dataDia == ref.read(agendaDataProvider);
    final isToday = dataDia == hoje;
    final temCompromisso = !foraLimite && diasComCompromissos.contains(dia);

    return GestureDetector(
      onTap: () {
        if (!foraLimite) {
          ref.read(agendaDataProvider.notifier).state = dataDia;
        }
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB)
              : isToday
                  ? const Color(0xFFDBEAFE)
                  : null,
          borderRadius: BorderRadius.circular(8),
          border: isToday && !isSelected
              ? Border.all(color: const Color(0xFF2563EB), width: 1)
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
                    ? Colors.white
                    : foraLimite
                        ? const Color(0xFFCBD5E1)
                        : isToday
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF1E293B),
              ),
            ),
            if (temCompromisso && !isSelected)
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
              ),
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
