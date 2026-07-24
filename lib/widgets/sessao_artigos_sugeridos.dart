import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/mentall_colors.dart';
import 'sessao_audio_controls.dart';

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
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.cs.primaryContainer, width: 0.5),
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
                    fontSize: 11,
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
                fontSize: 12,
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
    int lastEnd = 0;

    final urlRegExp = RegExp(r'https?://[^\s\n]+', caseSensitive: false);

    for (final match in urlRegExp.allMatches(texto)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: texto.substring(lastEnd, match.start)));
      }
      final url = match.group(0)!;
      spans.add(
        TextSpan(
          text: 'Acesse Aqui!',
          style: TextStyle(
            fontSize: 12,
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
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < texto.length) {
      spans.add(TextSpan(text: texto.substring(lastEnd)));
    }

    return TextSpan(children: spans);
  }
}
