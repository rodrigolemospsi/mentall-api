import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/paciente.dart';
import '../models/sessao.dart';
import '../providers/service_providers.dart';
import '../utils/mentall_colors.dart';
import '../utils/raio.dart';
import '../screens/sessao_form_page.dart';
import '../utils/tipografia.dart';

class PacienteFinanceiroTab extends ConsumerWidget {
  final Paciente paciente;

  const PacienteFinanceiroTab({super.key, required this.paciente});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessaoService = ref.watch(sessaoServiceProvider);
    final sessoes = sessaoService.listarSessoesDoPaciente(paciente.id);

    final resumo = _calcularResumo(sessoes);

    if (sessoes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.payments_outlined, size: 48, color: context.corTextoMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              'Nenhuma sessão registrada.',
              style: TextStyle(color: context.corTextoMuted),
            ),
            const SizedBox(height: 4),
            Text(
              'Os dados financeiros aparecerão aqui conforme as sessões forem registradas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: Tipografia.sm, color: context.corTextoMuted.withValues(alpha: 0.7)),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Financeiro',
          style: TextStyle(
            fontSize: Tipografia.md,
            fontWeight: FontWeight.w700,
            color: context.corTextoHeading,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          paciente.nomeExibicao,
          style: TextStyle(fontSize: Tipografia.smMd, color: context.corTextoMuted),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _cardResumo(
                context,
                'Recebido',
                'R\$ ${resumo.recebido.toStringAsFixed(2)}',
                '${resumo.sessoesPagas} sess.',
                context.corSuccess,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _cardResumo(
                context,
                'Pendente',
                'R\$ ${resumo.pendente.toStringAsFixed(2)}',
                '${resumo.sessoesPendentes} sess.',
                context.corWarning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _cardResumo(
                context,
                'Convênio',
                'R\$ ${resumo.convenio.toStringAsFixed(2)}',
                '${resumo.sessoesConvenio} sess.',
                context.corScheduled,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _cardResumo(
                context,
                'Pacote',
                'R\$ ${resumo.pacote.toStringAsFixed(2)}',
                '${resumo.sessoesPacote} sess.',
                context.corPacote,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _cardResumo(
          context,
          'Total',
          'R\$ ${resumo.total.toStringAsFixed(2)}',
          '${sessoes.length} sess.',
          context.corPrimaria,
        ),
        const SizedBox(height: 20),
        Text(
          'Sessões',
          style: TextStyle(
            fontSize: Tipografia.baseMd,
            fontWeight: FontWeight.w700,
            color: context.corTextoHeading,
          ),
        ),
        const SizedBox(height: 8),
        ...sessoes.map((sessao) => _linhaSessao(context, sessao, paciente)),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _cardResumo(
    BuildContext context,
    String titulo,
    String valor,
    String subtitulo,
    Color cor,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.corCard,
        borderRadius: BorderRadius.circular(Raio.lg),
        boxShadow: context.corCardSombra,
        border: context.corCardBorda,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(fontSize: Tipografia.sm, fontWeight: FontWeight.w600, color: context.corTextoMuted),
          ),
          const SizedBox(height: 6),
          Text(
            valor,
            style: TextStyle(fontSize: Tipografia.xl, fontWeight: FontWeight.w800, color: cor, height: 1),
          ),
          const SizedBox(height: 4),
          Text(
            subtitulo,
            style: TextStyle(fontSize: Tipografia.xs, color: context.corTextoMuted),
          ),
        ],
      ),
    );
  }

  Widget _linhaSessao(BuildContext context, Sessao sessao, Paciente paciente) {
    final statusCor = _corStatus(context, sessao.statusPagamento);
    final statusTexto = _textoStatus(sessao.statusPagamento);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: context.corCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Raio.sm)),
      child: InkWell(
        borderRadius: BorderRadius.circular(Raio.sm),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SessaoFormPage(
                paciente: paciente,
                sessaoExistente: sessao,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sessão ${sessao.numeroSessao} - ${sessao.data.day.toString().padLeft(2, '0')}/${sessao.data.month.toString().padLeft(2, '0')}/${sessao.data.year}',
                      style: TextStyle(
                        fontSize: Tipografia.smMd,
                        fontWeight: FontWeight.w600,
                        color: context.corTextoHeading,
                      ),
                    ),
                    if (sessao.dataPagamento != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Pago em ${sessao.dataPagamento!.day.toString().padLeft(2, '0')}/${sessao.dataPagamento!.month.toString().padLeft(2, '0')}/${sessao.dataPagamento!.year}',
                        style: TextStyle(fontSize: Tipografia.xs, color: context.corTextoMuted),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                'R\$ ${sessao.valorSessao.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: Tipografia.base,
                  fontWeight: FontWeight.w700,
                  color: context.corTextoHeading,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusCor.withAlpha(25),
                  borderRadius: BorderRadius.circular(Raio.xs),
                ),
                child: Text(
                  statusTexto,
                  style: TextStyle(fontSize: Tipografia.xxs, fontWeight: FontWeight.w600, color: statusCor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _corStatus(BuildContext context, String status) {
    switch (status) {
      case 'pago':
        return context.corSuccess;
      case 'convenio':
        return context.corScheduled;
      case 'pacote':
        return context.corPacote;
      default:
        return context.corWarning;
    }
  }

  String _textoStatus(String status) {
    switch (status) {
      case 'pago':
        return 'Pago';
      case 'convenio':
        return 'Convênio';
      case 'pacote':
        return 'Pacote';
      default:
        return 'Pendente';
    }
  }

  _ResumoFinanceiroPaciente _calcularResumo(List<Sessao> sessoes) {
    double recebido = 0;
    double pendente = 0;
    double convenio = 0;
    double pacote = 0;
    int pagas = 0;
    int pend = 0;
    int conv = 0;
    int pact = 0;

    for (final s in sessoes) {
      if (s.statusPagamento == 'pago') {
        recebido += s.valorSessao;
        pagas++;
      } else if (s.statusPagamento == 'convenio') {
        convenio += s.valorSessao;
        conv++;
      } else if (s.statusPagamento == 'pacote') {
        pacote += s.valorSessao;
        pact++;
      } else {
        pendente += s.valorSessao;
        pend++;
      }
    }

    return _ResumoFinanceiroPaciente(
      recebido: recebido,
      pendente: pendente,
      convenio: convenio,
      pacote: pacote,
      total: recebido + pendente + convenio + pacote,
      sessoesPagas: pagas,
      sessoesPendentes: pend,
      sessoesConvenio: conv,
      sessoesPacote: pact,
    );
  }
}

class _ResumoFinanceiroPaciente {
  final double recebido;
  final double pendente;
  final double convenio;
  final double pacote;
  final double total;
  final int sessoesPagas;
  final int sessoesPendentes;
  final int sessoesConvenio;
  final int sessoesPacote;

  const _ResumoFinanceiroPaciente({
    required this.recebido,
    required this.pendente,
    required this.convenio,
    required this.pacote,
    required this.total,
    required this.sessoesPagas,
    required this.sessoesPendentes,
    required this.sessoesConvenio,
    required this.sessoesPacote,
  });
}
