import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../models/lgpd/registro_auditoria.dart';
import '../providers/service_providers.dart';
import '../screens/paciente_detail_page.dart';
import '../utils/mentall_colors.dart';
import '../utils/raio.dart';
import '../utils/responsivo.dart';
import '../utils/tipografia.dart';
import 'mentall_card.dart';

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
            fontSize: Tipografia.xl,
            fontWeight: FontWeight.w700,
            color: context.corTextoHeading,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          resumo,
          style: TextStyle(fontSize: Tipografia.base, color: context.corTextoMuted),
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
            icone: Icons.person_add_alt_outlined,
            label: termoFeminino ? 'Nova p.' : 'Novo $termoSingular',
            semanticLabel: 'Novo paciente',
            onTap: onNovoPaciente,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _AcaoRapida(
            icone: Icons.event_available_outlined,
            label: 'Agendar',
            semanticLabel: 'Agendar sessão',
            onTap: onAgendar,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _AcaoRapida(
            icone: Icons.note_add_outlined,
            label: 'Nova sessão',
            semanticLabel: 'Nova sessão',
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
  final String? semanticLabel;
  final VoidCallback onTap;

  const _AcaoRapida({
    required this.icone,
    required this.label,
    this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inkWell = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Raio.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: context.corAcaoBorda),
          borderRadius: BorderRadius.circular(Raio.lg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 22, color: context.corAcaoFg),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: Tipografia.xs,
                fontWeight: FontWeight.w600,
                color: context.corAcaoFg,
              ),
            ),
          ],
        ),
      ),
    );

    final wrapped = semanticLabel != null
        ? Semantics(label: semanticLabel!, child: inkWell)
        : inkWell;

    return Material(
      color: context.corAcaoFundo,
      borderRadius: BorderRadius.circular(Raio.lg),
      child: wrapped,
    );
  }
}

class KpiCardsHome extends ConsumerWidget {
  final String termoPlural;
  final VoidCallback onHojeTap;
  final VoidCallback onPacientesTap;
  final VoidCallback? onReceitaTap;
  final VoidCallback? onPendenteTap;

  const KpiCardsHome({
    super.key,
    required this.termoPlural,
    required this.onHojeTap,
    required this.onPacientesTap,
    this.onReceitaTap,
    this.onPendenteTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compromissosHoje =
        ref.watch(compromissosHojeProvider).valueOrNull ?? [];
    final hoje = compromissosHoje
        .where((c) => c.statusEnum != StatusCompromisso.cancelado)
        .length;
    final ativos = ref.watch(pacientesAtivosProvider).valueOrNull?.length ?? 0;

    final financeiro = ref.watch(_sessoesDoMesHomeProvider).valueOrNull;
    final receita = financeiro?.receita ?? 0;
    final pendente = financeiro?.pendente ?? 0;

    final termoCapitalizado = termoPlural == 'pessoas atendidas'
        ? 'P. atendidas'
        : termoPlural.isNotEmpty
            ? '${termoPlural[0].toUpperCase()}${termoPlural.substring(1)}'
            : 'Pacientes';

    return LayoutBuilder(
      builder: (_, constraints) {
        if (Responsivo.isTablet(context)) {
          return Row(
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
                  cor: context.corSuccess,
                  onTap: onPacientesTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _KpiCard(
                  valor: 'R\$ ${receita.toStringAsFixed(0)}',
                  titulo: 'Receita',
                  subtitulo: 'recebido no mês',
                  icone: Icons.payments_outlined,
                  cor: context.corSuccess,
                  onTap: onReceitaTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _KpiCard(
                  valor: 'R\$ ${pendente.toStringAsFixed(0)}',
                  titulo: 'Pendente',
                  subtitulo: 'a receber',
                  icone: Icons.hourglass_bottom_outlined,
                  cor: context.corWarning,
                  onTap: onPendenteTap,
                ),
              ),
            ],
          );
        }
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
                    cor: context.corSuccess,
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
                    valor: 'R\$ ${receita.toStringAsFixed(0)}',
                    titulo: 'Receita',
                    subtitulo: 'recebido no mês',
                    icone: Icons.payments_outlined,
                    cor: context.corSuccess,
                    onTap: onReceitaTap,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _KpiCard(
                    valor: 'R\$ ${pendente.toStringAsFixed(0)}',
                    titulo: 'Pendente',
                    subtitulo: 'a receber',
                    icone: Icons.hourglass_bottom_outlined,
                    cor: context.corWarning,
                    onTap: onPendenteTap,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String valor;
  final String titulo;
  final String subtitulo;
  final IconData icone;
  final Color cor;
  final VoidCallback? onTap;

  const _KpiCard({
    required this.valor,
    required this.titulo,
    required this.subtitulo,
    required this.icone,
    required this.cor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = MentAllCard(
      borderRadius: Raio.lg,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
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
                    fontSize: Tipografia.sm,
                    fontWeight: FontWeight.w600,
                    color: context.corTextoMuted,
                  ),
                ),
              ),
              Icon(icone, size: 18, color: cor),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              valor,
              style: TextStyle(
                fontSize: Tipografia.xxl,
                fontWeight: FontWeight.w800,
                color: cor,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              subtitulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: Tipografia.xs, color: context.corTextoMuted),
            ),
          ),
        ],
      ),
    );

    return card;
  }
}


class AtividadeRecenteCard extends ConsumerWidget {
  const AtividadeRecenteCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registros = ref.watch(atividadeRecenteProvider).valueOrNull ?? [];
    final pacService = ref.watch(pacienteServiceProvider);
    final pacientesPorId = {
      for (final p in pacService.listarPacientes()) p.id: p,
    };

    if (registros.isEmpty) return const SizedBox.shrink();

    return MentAllCard(
      borderRadius: Raio.lg,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              'Atividade recente',
              style: TextStyle(
                fontSize: Tipografia.baseMd,
                fontWeight: FontWeight.w700,
                color: context.corTextoHeading,
              ),
            ),
          ),
          ...registros.map((r) {
            final paciente = pacientesPorId[r.pacienteId];
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
              color: context.corAtividadeIconeFundo,
              shape: BoxShape.circle,
            ),
            child: Icon(_icone, size: 17, color: context.corAtividadeIcone),
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
                    fontSize: Tipografia.smMd,
                    fontWeight: FontWeight.w600,
                    color: context.corTextoHeading,
                  ),
                ),
                Text(
                  registro.descricao,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: Tipografia.sm, color: context.corTextoMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _tempoRelativo,
            style: TextStyle(fontSize: Tipografia.xs, color: context.corTextoMuted),
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

final _sessoesDoMesHomeProvider =
    StreamProvider<({double receita, double pendente})>((ref) async* {
  final service = ref.watch(sessaoServiceProvider);

  ({double receita, double pendente}) calcular() {
    final now = DateTime.now();
    final inicio = DateTime(now.year, now.month, 1);
    final fim = DateTime(now.year, now.month + 1, 1);
    return service.somarFinanceiroPorPeriodo(inicio, fim);
  }

  yield calcular();
  await for (final _ in service.observarSessoes()) {
    yield calcular();
  }
});
