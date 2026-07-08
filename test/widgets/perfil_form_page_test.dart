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

    expect(find.text('Configuração inicial'), findsOneWidget);
    expect(find.text('Bem-vindo ao MentAll'), findsOneWidget);
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
}
