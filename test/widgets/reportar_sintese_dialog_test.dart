import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prontuario_tcc/widgets/reportar_sintese_dialog.dart';

/// Abre o diálogo pela própria função pública e guarda o resultado devolvido.
Future<void> _abrirDialogo(
  WidgetTester tester,
  void Function(ReporteSintese?) aoConcluir,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              final resultado = await mostrarDialogoReportarSintese(context);
              aoConcluir(resultado);
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mostra os motivos e só habilita Enviar após escolher um',
      (tester) async {
    await _abrirDialogo(tester, (_) {});

    expect(find.text('Reportar problema com o texto gerado'), findsOneWidget);
    for (final rotulo in motivosReporteSintese.values) {
      expect(find.text(rotulo), findsOneWidget);
    }

    final botaoEnviar = find.widgetWithText(FilledButton, 'Enviar reporte');
    expect(botaoEnviar, findsOneWidget);
    expect(tester.widget<FilledButton>(botaoEnviar).onPressed, isNull);

    await tester.tap(find.text('Conteúdo incorreto ou inventado'));
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(botaoEnviar).onPressed, isNotNull);
  });

  testWidgets('devolve motivo e observação ao enviar', (tester) async {
    ReporteSintese? recebido;
    await _abrirDialogo(tester, (resultado) => recebido = resultado);

    await tester.tap(find.text('Exposição de dado sensível'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Apareceu um telefone no texto gerado',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Enviar reporte'));
    await tester.pumpAndSettle();

    expect(recebido, isNotNull);
    expect(recebido!.motivo, 'dado_sensivel');
    expect(recebido!.detalhe, 'Apareceu um telefone no texto gerado');
  });

  testWidgets('cancelar devolve null', (tester) async {
    ReporteSintese? recebido = const ReporteSintese(motivo: 'outro');
    await _abrirDialogo(tester, (resultado) => recebido = resultado);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(recebido, isNull);
  });
}
