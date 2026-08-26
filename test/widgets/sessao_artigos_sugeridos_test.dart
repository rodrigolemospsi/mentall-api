import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prontuario_tcc/widgets/sessao_artigos_sugeridos.dart';
import 'package:prontuario_tcc/widgets/sessao_audio_controls.dart';

void main() {
  Widget wrap(String artigos) {
    return ProviderScope(
      overrides: [
        artigosSugeridosProvider.overrideWith((ref) => artigos),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: ArtigosSugeridosCard(),
        ),
      ),
    );
  }

  testWidgets('fallback de busca sugerida nao renderiza como titulo de artigo',
      (tester) async {
    await tester.pumpWidget(wrap(
      'Busca sugerida 1: Ansiedade social\n'
      '   SciELO: https://search.scielo.org/?q=ansiedade&lang=pt\n'
      '   Periódicos CAPES: https://www.periodicos.capes.gov.br/buscar?q=ansiedade\n'
      '   Oasisbr: https://oasisbr.ibict.br/vufind/Search/Results?lookfor=ansiedade',
    ));
    await tester.pump();

    expect(find.textContaining('Busca sugerida 1: Ansiedade social'), findsOneWidget);
    expect(find.textContaining('SciELO'), findsOneWidget);
    expect(find.textContaining('Periódicos CAPES'), findsOneWidget);
    expect(find.textContaining('Oasisbr'), findsOneWidget);
  });

  testWidgets('artigo real renderiza titulo clicavel', (tester) async {
    await tester.pumpWidget(wrap(
      '1. Transtorno de Ansiedade Social (2019) - Autor\n'
      '   Relevância: relacionado ao caso.\n'
      '   https://doi.org/10.1590/abc',
    ));
    await tester.pump();

    expect(find.textContaining('Transtorno de Ansiedade Social'), findsOneWidget);
    expect(find.textContaining('Relevância'), findsOneWidget);
  });
}
