import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sessao_form_providers.dart';
import '../utils/mentall_colors.dart';
import '../utils/raio.dart';
import '../utils/tipografia.dart';

/// Cor de tendência da evolução clínica (usada pela seção de progresso).
Color corTendencia(BuildContext context, String tendencia) {
  switch (tendencia) {
    case 'melhora':
      return context.corSuccess;
    case 'piora':
      return context.corError;
    case 'mista':
      return context.corWarning;
    default:
      return context.corScheduled;
  }
}

/// Card "Evolução Clínica" da tela de sessão.
///
/// ConsumerWidget autocontido: lê os providers de progresso diretamente
/// (sem callbacks) — padrão já usado por ArtigosSugeridosCard/BotoesAudioWidget.
class SecaoProgressoWidget extends ConsumerWidget {
  const SecaoProgressoWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gerando = ref.watch(sessaoProgressoGerandoProvider);
    if (gerando) {
      return const _ProgressoCarregandoCard();
    }

    final sintomas = ref.watch(sessaoProgressoSintomasProvider);
    if (sintomas.isEmpty) return const SizedBox.shrink();

    final tendencia = ref.watch(sessaoProgressoTendenciaProvider);
    final avaliacaoGeral = ref.watch(sessaoProgressoGeralProvider);
    final cor = corTendencia(context, tendencia);

    return Card(
      margin: EdgeInsets.zero,
      color: context.corCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Raio.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: cor, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Evolução Clínica',
                  style: TextStyle(
                    fontSize: Tipografia.base,
                    fontWeight: FontWeight.w700,
                    color: context.corTextoHeading,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...sintomas
                .take(4)
                .map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          s['tendencia'] == 'melhora'
                              ? Icons.arrow_downward
                              : s['tendencia'] == 'piora'
                              ? Icons.arrow_upward
                              : Icons.remove,
                          size: 14,
                          color: s['tendencia'] == 'melhora'
                              ? context.corSuccess
                              : s['tendencia'] == 'piora'
                              ? context.corError
                              : context.corTextoMuted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${s['nome']} — ${s['intensidade']}/10',
                            style: TextStyle(
                              fontSize: Tipografia.sm,
                              color: context.corTextoBody,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            if (avaliacaoGeral.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cor.withAlpha(15),
                  borderRadius: BorderRadius.circular(Raio.xxs),
                ),
                child: Row(
                  children: [
                    Icon(Icons.insights, size: 14, color: cor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        avaliacaoGeral,
                        style: TextStyle(
                          fontSize: Tipografia.xs,
                          color: cor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressoCarregandoCard extends StatelessWidget {
  const _ProgressoCarregandoCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: context.corCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Raio.lg),
      ),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text(
              'Gerando análise de evolução...',
              style: TextStyle(fontSize: Tipografia.smMd),
            ),
          ],
        ),
      ),
    );
  }
}
