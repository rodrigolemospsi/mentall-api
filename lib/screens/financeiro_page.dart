import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/paciente.dart';
import '../models/sessao.dart';
import '../providers/service_providers.dart';
import '../services/pdf_export_service.dart';
import '../utils/mentall_colors.dart';
import 'sessao_form_page.dart';

final _mesFinanceiroProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

class FinanceiroPage extends ConsumerStatefulWidget {
  const FinanceiroPage({super.key});

  @override
  ConsumerState<FinanceiroPage> createState() => _FinanceiroPageState();
}

class _FinanceiroPageState extends ConsumerState<FinanceiroPage> {
  @override
  Widget build(BuildContext context) {
    final mesAtual = ref.watch(_mesFinanceiroProvider);
    final sessoes = _sessoesDoMes(ref, mesAtual);
    final resumo = _calcularResumo(sessoes);
    final pacienteService = ref.watch(pacienteServiceProvider);

    final meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];

    return Scaffold(
      backgroundColor: context.corFundo,
      appBar: AppBar(
        title: const Text('Financeiro'),
        backgroundColor: context.corPrimaria,
        foregroundColor: context.corOnPrimaria,
        actions: [
          IconButton(
            tooltip: 'Exportar relatório',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => _exportarRelatorio(mesAtual, sessoes, resumo),
          ),
        ],
      ),
      body: Column(
        children: [
          _seletorMes(mesAtual, meses),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
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
                        'A receber',
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
                        const Color(0xFF0D9488),
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
                        'Total mês',
                        'R\$ ${resumo.total.toStringAsFixed(2)}',
                        '${sessoes.length} sess.',
                        context.corPrimaria,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Sessões do mês',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.corTextoHeading,
                  ),
                ),
                const Spacer(),
                Text(
                  '${sessoes.length} sessões',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.corTextoMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: sessoes.isEmpty
                ? Center(
                    child: Text(
                      'Nenhuma sessão neste mês.',
                      style: TextStyle(color: context.corTextoMuted),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sessoes.length,
                    itemBuilder: (context, index) {
                      final sessao = sessoes[index];
                      final paciente = pacienteService.buscarPacientePorId(sessao.pacienteId);
                      return _linhaSessao(context, sessao, paciente, mesAtual);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _seletorMes(DateTime mesAtual, List<String> meses) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: context.corPrimaria),
            onPressed: () {
              ref.read(_mesFinanceiroProvider.notifier).state = DateTime(
                mesAtual.year,
                mesAtual.month - 1,
                1,
              );
            },
          ),
          Text(
            '${meses[mesAtual.month - 1]}/${mesAtual.year}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.corTextoHeading,
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: context.corPrimaria),
            onPressed: () {
              ref.read(_mesFinanceiroProvider.notifier).state = DateTime(
                mesAtual.year,
                mesAtual.month + 1,
                1,
              );
            },
          ),
        ],
      ),
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.corTextoMuted),
          ),
          const SizedBox(height: 6),
          Text(
            valor,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: cor, height: 1),
          ),
          const SizedBox(height: 4),
          Text(
            subtitulo,
            style: TextStyle(fontSize: 11, color: context.corTextoMuted),
          ),
        ],
      ),
    );
  }

  Widget _linhaSessao(
    BuildContext context,
    Sessao sessao,
    Paciente? paciente,
    DateTime mesAtual,
  ) {
    final statusCor = _corStatus(sessao.statusPagamento);
    final statusTexto = _textoStatus(sessao.statusPagamento);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: context.corCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          if (paciente == null) return;
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
                      paciente?.nomeExibicao ?? 'Paciente',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.corTextoHeading,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sessão ${sessao.numeroSessao} - ${sessao.data.day.toString().padLeft(2, '0')}/${sessao.data.month.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 11, color: context.corTextoMuted),
                    ),
                  ],
                ),
              ),
              Text(
                'R\$ ${sessao.valorSessao.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.corTextoHeading,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusCor.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusTexto,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusCor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _corStatus(String status) {
    switch (status) {
      case 'pago':
        return context.corSuccess;
      case 'convenio':
        return context.corScheduled;
      case 'pacote':
        return const Color(0xFF0D9488);
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

  List<Sessao> _sessoesDoMes(WidgetRef ref, DateTime mes) {
    final service = ref.read(sessaoServiceProvider);
    final inicio = DateTime(mes.year, mes.month, 1);
    final fim = DateTime(mes.year, mes.month + 1, 0, 23, 59, 59);
    return service.listarSessoesPorPeriodo(inicio, fim);
  }

  _ResumoFinanceiro _calcularResumo(List<Sessao> sessoes) {
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

    return _ResumoFinanceiro(
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

  Future<void> _exportarRelatorio(
    DateTime mes,
    List<Sessao> sessoes,
    _ResumoFinanceiro resumo,
  ) async {
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
    if (perfil == null) return;

    try {
      final nomesPacientes = <String, String>{};
      for (final s in sessoes) {
        final p = ref.read(pacienteServiceProvider).buscarPacientePorId(s.pacienteId);
        nomesPacientes[s.pacienteId] = p?.nomeExibicao ?? 'Paciente';
      }

      await PdfExportService().exportarRelatorioFinanceiro(
        mes: mes,
        sessoes: sessoes,
        recebido: resumo.recebido,
        pendente: resumo.pendente,
        convenio: resumo.convenio,
        pacote: resumo.pacote,
        total: resumo.total,
        perfil: perfil,
        nomesPacientes: nomesPacientes,
        temaEscuro: ref.read(configuracoesServiceProvider).temaEscuro,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível exportar o relatório.')),
        );
      }
    }
  }
}

class _ResumoFinanceiro {
  final double recebido;
  final double pendente;
  final double convenio;
  final double pacote;
  final double total;
  final int sessoesPagas;
  final int sessoesPendentes;
  final int sessoesConvenio;
  final int sessoesPacote;

  const _ResumoFinanceiro({
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
