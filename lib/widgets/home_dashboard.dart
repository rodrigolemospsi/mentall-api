import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/compromisso.dart';
import '../models/enums.dart';
import '../models/lgpd/registro_auditoria.dart';
import '../providers/service_providers.dart';
import '../screens/agenda_page.dart';
import '../screens/paciente_detail_page.dart';
import '../utils/mentall_colors.dart';
import 'compromisso_form_dialog.dart';

class SaudacaoResumoHome extends ConsumerWidget {
  final String saudacao;
  final String nomeProfissional;

  const SaudacaoResumoHome({
    super.key,
    required this.saudacao,
    required this.nomeProfissional,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compromissosAsync = ref.watch(compromissosHojeProvider);
    final compromissos = compromissosAsync.valueOrNull ?? [];
    final total = compromissos
        .where((c) => c.statusEnum != StatusCompromisso.cancelado)
        .length;

    final texto =
        nomeProfissional.isNotEmpty ? '$saudacao, $nomeProfissional!' : saudacao;
    final resumo = total == 0
        ? 'Você não tem sessões hoje'
        : total == 1
            ? 'Você tem 1 sessão hoje'
            : 'Você tem $total sessões hoje';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          texto,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: context.corTextoHeading,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          resumo,
          style: TextStyle(fontSize: 14, color: context.corTextoMuted),
        ),
      ],
    );
  }
}

class AcoesRapidasHome extends StatelessWidget {
  final String termoSingular;
  final bool termoFeminino;
  final VoidCallback onAgendar;
  final VoidCallback onNovoPaciente;
  final VoidCallback onAbrirAgenda;

  const AcoesRapidasHome({
    super.key,
    required this.termoSingular,
    required this.termoFeminino,
    required this.onAgendar,
    required this.onNovoPaciente,
    required this.onAbrirAgenda,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AcaoRapida(
            icone: Icons.event_available_outlined,
            label: 'Agendar',
            onTap: onAgendar,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _AcaoRapida(
            icone: Icons.person_add_alt_outlined,
            label: termoFeminino ? 'Nova pessoa' : 'Novo $termoSingular',
            onTap: onNovoPaciente,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _AcaoRapida(
            icone: Icons.note_add_outlined,
            label: 'Nova sessão',
            onTap: onAbrirAgenda,
          ),
        ),
      ],
    );
  }
}

class _AcaoRapida extends StatelessWidget {
  final IconData icone;
  final String label;
  final VoidCallback onTap;

  const _AcaoRapida({
    required this.icone,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primaryContainer,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: cs.primaryContainer),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, size: 22, color: cs.primary),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class KpiCardsHome extends ConsumerWidget {
  final String termoPlural;
  final VoidCallback onHojeTap;
  final VoidCallback onPacientesTap;
  final VoidCallback onSessoesTap;
  final VoidCallback onRevisoesTap;

  const KpiCardsHome({
    super.key,
    required this.termoPlural,
    required this.onHojeTap,
    required this.onPacientesTap,
    required this.onSessoesTap,
    required this.onRevisoesTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compromissosHoje =
        ref.watch(compromissosHojeProvider).valueOrNull ?? [];
    final hoje = compromissosHoje
        .where((c) => c.statusEnum != StatusCompromisso.cancelado)
        .length;
    final ativos = ref.watch(pacientesAtivosProvider).valueOrNull?.length ?? 0;
    final kpis = ref.watch(dashboardKpisSessoesProvider).valueOrNull;

    final termoCapitalizado = termoPlural.isNotEmpty
        ? '${termoPlural[0].toUpperCase()}${termoPlural.substring(1)}'
        : 'Pacientes';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                valor: '$hoje',
                titulo: 'Hoje',
                subtitulo: hoje == 1 ? 'sessão agendada' : 'sessões agendadas',
                icone: Icons.today_outlined,
                cor: context.corPrimaria,
                onTap: onHojeTap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                valor: '$ativos',
                titulo: termoCapitalizado,
                subtitulo: 'em acompanhamento',
                icone: Icons.people_outline,
                cor: const Color(0xFF2E7D32),
                onTap: onPacientesTap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
              Expanded(
              child: _KpiCard(
                valor: '${kpis?.sessoesUltimos30Dias ?? 0}',
                titulo: 'Sessões',
                subtitulo: 'últimos 30 dias',
                icone: Icons.description_outlined,
                cor: const Color(0xFF7C3AED),
                onTap: onSessoesTap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                valor: '${kpis?.pendentesRevisao ?? 0}',
                titulo: 'Revisões',
                subtitulo: 'pendentes',
                icone: Icons.rate_review_outlined,
                cor: const Color(0xFFE65100),
                onTap: onRevisoesTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String valor;
  final String titulo;
  final String subtitulo;
  final IconData icone;
  final Color cor;
  final VoidCallback onTap;

  const _KpiCard({
    required this.valor,
    required this.titulo,
    required this.subtitulo,
    required this.icone,
    required this.cor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.corTextoMuted,
                      ),
                    ),
                  ),
                  Icon(icone, size: 18, color: cor),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                valor,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: cor,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: context.corTextoMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SessoesHojeCard extends ConsumerWidget {
  final VoidCallback onAgendar;

  const SessoesHojeCard({super.key, required this.onAgendar});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compromissos =
        ref.watch(compromissosHojeProvider).valueOrNull ?? [];
    final pacService = ref.watch(pacienteServiceProvider);

    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Sessões de hoje',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.corTextoHeading,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AgendaPage()),
                    );
                  },
                  child: Text(
                    'Ver todas',
                    style: TextStyle(fontSize: 12, color: cs.primary),
                  ),
                ),
              ],
            ),
          ),
          if (compromissos.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Nenhuma sessão agendada para hoje.',
                      style: TextStyle(fontSize: 13, color: context.corTextoMuted),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onAgendar,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text(
                      'Agendar',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            )
          else
            ...compromissos.map((c) {
              final paciente = pacService.buscarPacientePorId(c.pacienteId);
              return _SessaoHojeItem(
                compromisso: c,
                nomePaciente:
                    paciente?.nomeExibicao ?? 'Pessoa não encontrada',
                fotoBase64: paciente?.fotoBase64 ?? '',
                onTap: () => _editarCompromisso(context, ref, c),
              );
            }),
          const SizedBox(height: 6),
        ],
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
      termoPessoa: ref
              .read(perfilProfissionalServiceProvider)
              .obterPerfil()
              ?.termoSingularCapitalizado ??
          'Pessoa atendida',
      compromissoExistente: compromisso,
    );

    if (editado == null) return;
    await service.atualizar(editado);

    if (!editado.lembreteAtivado || !editado.isAgendado) return;
    final paciente =
        ref.read(pacienteServiceProvider).buscarPacientePorId(editado.pacienteId);
    if (paciente == null) return;
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
    await ref.read(lembreteServiceProvider).agendarLembrete(
          compromisso: editado,
          nomePaciente: paciente.nome,
          nomeProfissional: perfil?.nome ?? 'Profissional',
          telefonePaciente: paciente.contato,
        );
  }
}

class _SessaoHojeItem extends StatelessWidget {
  final Compromisso compromisso;
  final String nomePaciente;
  final String fotoBase64;
  final VoidCallback onTap;

  const _SessaoHojeItem({
    required this.compromisso,
    required this.nomePaciente,
    required this.fotoBase64,
    required this.onTap,
  });

  Color get _corStatus {
    switch (compromisso.statusEnum) {
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

  String get _labelStatus {
    switch (compromisso.statusEnum) {
      case StatusCompromisso.agendado:
        return 'Agendada';
      case StatusCompromisso.realizado:
        return 'Realizada';
      case StatusCompromisso.cancelado:
        return 'Cancelada';
      case StatusCompromisso.faltou:
        return 'Faltou';
    }
  }

  @override
  Widget build(BuildContext context) {
    final inicial =
        nomePaciente.isNotEmpty ? nomePaciente[0].toUpperCase() : '?';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: context.corContainerPrimario,
              backgroundImage: fotoBase64.isNotEmpty
                  ? MemoryImage(base64Decode(fotoBase64))
                  : null,
              child: fotoBase64.isEmpty
                  ? Text(
                      inicial,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: context.corPrimaria,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.corTextoHeading,
                    ),
                  ),
                  Text(
                    compromisso.horarioInicioFormatado,
                    style: TextStyle(fontSize: 12, color: context.corTextoMuted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _corStatus.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _labelStatus,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _corStatus,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AtividadeRecenteCard extends ConsumerWidget {
  const AtividadeRecenteCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registros = ref.watch(atividadeRecenteProvider).valueOrNull ?? [];
    final pacService = ref.watch(pacienteServiceProvider);

    if (registros.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              'Atividade recente',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.corTextoHeading,
              ),
            ),
          ),
          ...registros.map((r) {
            final paciente =
                pacService.buscarPacientePorId(r.pacienteId);
            return _AtividadeItem(
              registro: r,
              nomePaciente: paciente?.nomeExibicao,
              onTap: paciente != null
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PacienteDetailPage(paciente: paciente),
                        ),
                      );
                    }
                  : null,
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _AtividadeItem extends StatelessWidget {
  final RegistroAuditoria registro;
  final String? nomePaciente;
  final VoidCallback? onTap;

  const _AtividadeItem({
    required this.registro,
    this.nomePaciente,
    this.onTap,
  });

  IconData get _icone {
    final tipo = registro.tipoEvento.toLowerCase();
    if (tipo.contains('agendad')) return Icons.event_outlined;
    if (tipo.contains('cadastrad')) return Icons.person_add_alt_outlined;
    if (tipo.contains('ia') || tipo.contains('sintese')) {
      return Icons.auto_awesome_outlined;
    }
    if (tipo.contains('transcri')) return Icons.mic_outlined;
    if (tipo.contains('revis')) return Icons.rate_review_outlined;
    if (tipo.contains('gravacao') || tipo.contains('audio')) {
      return Icons.graphic_eq_outlined;
    }
    if (tipo.contains('registrad') || tipo.contains('sessao')) {
      return Icons.description_outlined;
    }
    return Icons.history_outlined;
  }

  String get _tempoRelativo {
    final diff = DateTime.now().difference(registro.dataHora);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min atrás';
    if (diff.inHours < 24) return '${diff.inHours}h atrás';
    if (diff.inDays == 1) return 'ontem';
    if (diff.inDays < 7) return '${diff.inDays} dias atrás';
    final d = registro.dataHora;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final titulo = nomePaciente != null && nomePaciente!.isNotEmpty
        ? '$nomePaciente - ${registro.tipoEvento}'
        : registro.tipoEvento;

    final item = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: context.corContainerPrimario,
              shape: BoxShape.circle,
            ),
            child: Icon(_icone, size: 17, color: context.corPrimaria),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.corTextoHeading,
                  ),
                ),
                Text(
                  registro.descricao,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: context.corTextoMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _tempoRelativo,
            style: TextStyle(fontSize: 11, color: context.corTextoMuted),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: item,
        ),
      );
    }

    return item;
  }
}
