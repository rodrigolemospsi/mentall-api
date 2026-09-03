import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prontuario_tcc/screens/perfil_profissional_form_page.dart';

void main() {
  testWidgets('deve renderizar formulário inicial',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PerfilProfissionalFormPage(),
        ),
      ),
    );

    await tester.pump();

    expect(
      find.text(
          'O app MentAll Pro valoriza a abordagem psicológica que você atua! Configure agora o seu perfil profissional:'),
      findsOneWidget,
    );
    expect(find.text('Salvar e começar'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('deve mostrar snackbar quando nome estiver vazio',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PerfilProfissionalFormPage(),
        ),
      ),
    );

    await tester.pump();

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.text('Informe seu nome profissional.'), findsOneWidget);
  });

  testWidgets('novo perfil: dropdown de abordagem sem pre-selecao e labels novos',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PerfilProfissionalFormPage(),
        ),
      ),
    );

    await tester.pump();

    // Placeholder de abordagem (sem valor selecionado) — agora "Escolher"
    // nos 3 dropdowns (Abordagem, Como se referir, Tratamento).
    expect(find.text('Escolher'), findsNWidgets(3));
    // Exemplo dentro da caixa de Registro profissional.
    expect(find.text('Ex.: 00/000000'), findsOneWidget);
    // Labels renomeados (sempre visíveis)
    expect(find.text('Registro profissional - CRP'), findsOneWidget);
    expect(find.text('Como se referir'), findsOneWidget);
  });

  testWidgets('salvar sem abordagem mostra snackbar de bloqueio',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PerfilProfissionalFormPage(),
        ),
      ),
    );

    await tester.pump();

    // Preenche nome (para passar na 1a validacao)
    await tester.enterText(find.byType(TextField).first, 'Dr. Teste');
    await tester.pump();

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.text('Defina sua abordagem clínica.'), findsOneWidget);
  });
}
