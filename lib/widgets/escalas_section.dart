import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/resposta_escala.dart';
import '../providers/service_providers.dart';
import '../services/escala_service.dart';
import '../utils/mentall_colors.dart';

class EscalasSection extends ConsumerWidget {
  final String pacienteId;

  const EscalasSection({super.key, required this.pacienteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final respostasAsync = ref.watch(respostasEscalasPorPacienteProvider(pacienteId));
    final respostas = respostasAsync.valueOrNull ?? [];
    final escalas = EscalaService.escalasDisponiveis;

    return Card(
      margin: EdgeInsets.zero,
      color: context.corCard,
      elevation: Theme.of(context).brightness == Brightness.dark ? 4 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, color: context.corPrimaria, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Escalas Psicológicas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.corTextoHeading,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...escalas.entries.map((entry) {
              final escalaId = entry.key;
              final escala = entry.value;
              final ultimaResposta = respostas.where((r) => r.escalaId == escalaId).toList();
              final temResultado = ultimaResposta.isNotEmpty;

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: temResultado
                      ? () => _mostrarResultado(context, ref, ultimaResposta.first, escala)
                      : () => _aplicarEscala(context, ref, escalaId, escala),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: context.corContainerPrimario.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                escala['nome'] as String,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: context.corTextoHeading,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                escala['descricao'] as String,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.corTextoMuted,
                                ),
                              ),
                              if (temResultado) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: context.corPrimaria.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${ultimaResposta.first.pontuacao} pts — ${ultimaResposta.first.interpretacao}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: context.corPrimaria,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatarData(ultimaResposta.first.dataAplicacao),
                                      style: TextStyle(fontSize: 10, color: context.corTextoMuted),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(
                          temResultado ? Icons.chevron_right : Icons.add_circle_outline,
                          size: 22,
                          color: context.corPrimaria,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatarData(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _aplicarEscala(
    BuildContext context,
    WidgetRef ref,
    String escalaId,
    Map<String, dynamic> escala,
  ) async {
    final questoes = (escala['questoes'] as List).cast<String>();
    final opcoes = (escala['opcoes'] as List).cast<String>();
    final respostas = List<int>.filled(questoes.length, 0);

    final concluido = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(escala['nome'] as String),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    escala['instrucoes'] as String,
                    style: TextStyle(fontSize: 12, color: context.corTextoMuted, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 16),
                  ...questoes.asMap().entries.map((q) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${q.key + 1}. ${q.value}',
                            style: TextStyle(fontSize: 13, color: context.corTextoHeading, height: 1.4),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: opcoes.asMap().entries.map((o) {
                              final selecionado = respostas[q.key] == o.key;
                              return ChoiceChip(
                                label: Text(o.value, style: TextStyle(fontSize: 11)),
                                selected: selecionado,
                                selectedColor: context.corPrimaria,
                                labelStyle: TextStyle(
                                  color: selecionado ? context.corOnPrimaria : context.corTextoBody,
                                  fontWeight: selecionado ? FontWeight.w600 : FontWeight.normal,
                                ),
                                onSelected: (val) {
                                  setDialogState(() => respostas[q.key] = o.key);
                                },
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                visualDensity: VisualDensity.compact,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Concluir'),
            ),
          ],
        ),
      ),
    );

    if (concluido != true) return;

    final pontuacao = respostas.fold(0, (a, b) => a + b);
    final interpretacao = EscalaService.interpretar(escalaId, pontuacao);

    final resposta = RespostaEscala(
      id: '',
      pacienteId: pacienteId,
      escalaId: escalaId,
      respostasJson: jsonEncode(respostas),
      pontuacao: pontuacao,
      interpretacao: interpretacao,
      dataAplicacao: DateTime.now(),
    );

    await ref.read(escalaServiceProvider).salvarResposta(resposta);

    if (context.mounted) {
      _mostrarResultado(context, ref, resposta, escala);
    }
  }

  Future<void> _mostrarResultado(
    BuildContext context,
    WidgetRef ref,
    RespostaEscala resposta,
    Map<String, dynamic> escala,
  ) async {
    final respostasList = (jsonDecode(resposta.respostasJson) as List).cast<int>();
    final questoes = (escala['questoes'] as List).cast<String>();
    final opcoes = (escala['opcoes'] as List).cast<String>();
    final historico = ref.read(escalaServiceProvider).listarPorPacienteEEscala(pacienteId, resposta.escalaId);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(escala['nome'] as String),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.corPrimaria.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${resposta.pontuacao}',
                            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: context.corPrimaria),
                          ),
                          Text(
                            'pontos',
                            style: TextStyle(fontSize: 12, color: context.corTextoMuted),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          resposta.interpretacao,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.corTextoHeading),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Aplicado em ${_formatarData(resposta.dataAplicacao)}',
                  style: TextStyle(fontSize: 11, color: context.corTextoMuted),
                ),
                if (historico.length > 1) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Histórico',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.corTextoHeading),
                  ),
                  const SizedBox(height: 6),
                  ...historico.map((h) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Text(
                          _formatarData(h.dataAplicacao),
                          style: TextStyle(fontSize: 12, color: context.corTextoMuted),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${h.pontuacao} pts',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.corPrimaria),
                        ),
                        Text(
                          ' — ${h.interpretacao}',
                          style: TextStyle(fontSize: 11, color: context.corTextoSecondary),
                        ),
                      ],
                    ),
                  )),
                ],
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Respostas detalhadas',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.corTextoHeading),
                ),
                const SizedBox(height: 6),
                ...questoes.asMap().entries.map((q) {
                  final val = q.key < respostasList.length ? respostasList[q.key] : 0;
                  final respostaTexto = val < opcoes.length ? opcoes[val] : '$val';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${q.key + 1}.',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.corTextoMuted),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                q.value,
                                style: TextStyle(fontSize: 12, color: context.corTextoBody, height: 1.3),
                              ),
                              Text(
                                respostaTexto,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.corPrimaria),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _aplicarEscala(context, ref, resposta.escalaId, escala);
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reaplicar'),
          ),
        ],
      ),
    );
  }
}
