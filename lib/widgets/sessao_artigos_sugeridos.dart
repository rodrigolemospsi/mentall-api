import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/mentall_colors.dart';
import '../utils/raio.dart';
import 'sessao_audio_controls.dart';
import '../utils/tipografia.dart';

class ArtigosSugeridosCard extends ConsumerWidget {
  const ArtigosSugeridosCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artigos = ref.watch(artigosSugeridosProvider);

    if (artigos.trim().isEmpty) return const SizedBox.shrink();

    return Semantics(
      label: 'Indicações de artigos científicos',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.corContainerPrimario,
          borderRadius: BorderRadius.circular(Raio.md),
          border: Border.all(color: context.corContainerPrimario, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book_outlined,
                    size: 18, color: context.corPrimaria),
                const SizedBox(width: 8),
                Text(
                  'INDICAÇÕES DE ARTIGOS',
                  style: TextStyle(
                    fontSize: Tipografia.xs,
                    fontWeight: FontWeight.w700,
                    color: context.corPrimaria,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text.rich(
              _buildArtigosComLinks(context, artigos),
              style: TextStyle(
                fontSize: Tipografia.sm,
                height: 1.5,
                color: context.corTextoBody,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InlineSpan _buildArtigosComLinks(BuildContext context, String texto) {
    final spans = <InlineSpan>[];

    final blocos = texto.split(RegExp(r'\n(?=\d+\.\s)'));

    for (int b = 0; b < blocos.length; b++) {
      final bloco = blocos[b];
      if (bloco.trim().isEmpty) continue;

      final urlMatch = RegExp(r'https?://[^\s\n]+').firstMatch(bloco);
      final url = urlMatch?.group(0);

      final linhas = bloco.split(RegExp(r'\r?\n'));

      for (int i = 0; i < linhas.length; i++) {
        final linha = linhas[i];
        final trimmed = linha.trimLeft();

        final isUrlLine = RegExp(r'^https?://').hasMatch(trimmed);
        final isPlatformUrlLine =
            RegExp(r'^[A-Za-z]+\s*:?\s*https?://').hasMatch(trimmed);

        if (isUrlLine || isPlatformUrlLine) {
          continue;
        }

        if (trimmed.isEmpty) {
          if (i < linhas.length - 1) {
            spans.add(const TextSpan(text: '\n'));
          }
          continue;
        }

        if (i == 0 && url != null) {
          spans.add(TextSpan(
            text: i < linhas.length - 1 ? '$trimmed\n' : trimmed,
            style: TextStyle(
              fontSize: Tipografia.smMd,
              height: 1.5,
              color: context.corPrimaria,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationColor: context.corPrimaria,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () async {
                final uri = Uri.tryParse(url);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
          ));
        } else {
          spans.add(TextSpan(text: i < linhas.length - 1 ? '$trimmed\n' : trimmed));
        }
      }

      if (b < blocos.length - 1) {
        spans.add(const TextSpan(text: '\n\n'));
      }
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: texto));
    }

    return TextSpan(children: spans);
  }
}
