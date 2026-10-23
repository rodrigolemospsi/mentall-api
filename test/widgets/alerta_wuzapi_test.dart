import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prontuario_tcc/widgets/alerta_wuzapi.dart';

Widget _app(Future<Map<String, dynamic>> Function() status) {
  return MaterialApp(
    home: Scaffold(
      body: AlertaWuzapi(obterStatus: status, monitorar: false),
    ),
  );
}

void main() {
  testWidgets('mostra alerta quando o WhatsApp está desconectado',
      (tester) async {
    await tester.pumpWidget(_app(() async => {
          'sucesso': true,
          'configurado': true,
          'conectado': false,
          'logado': false,
        }));
    await tester.pumpAndSettle();
    expect(find.text('WhatsApp desconectado'), findsOneWidget);
    expect(find.text('Reconectar'), findsOneWidget);
  });

  testWidgets('mostra alerta quando ainda não está configurado', (tester) async {
    await tester.pumpWidget(_app(() async => {
          'sucesso': true,
          'configurado': false,
          'conectado': false,
          'logado': false,
        }));
    await tester.pumpAndSettle();
    expect(find.text('WhatsApp não conectado'), findsOneWidget);
  });

  testWidgets('não mostra nada quando conectado', (tester) async {
    await tester.pumpWidget(_app(() async => {
          'sucesso': true,
          'configurado': true,
          'conectado': true,
          'logado': true,
        }));
    await tester.pumpAndSettle();
    expect(find.text('WhatsApp desconectado'), findsNothing);
    expect(find.text('Reconectar'), findsNothing);
  });

  testWidgets('não mostra nada quando a consulta falha (sem servidor)',
      (tester) async {
    await tester.pumpWidget(_app(() async => {'sucesso': false}));
    await tester.pumpAndSettle();
    expect(find.text('WhatsApp desconectado'), findsNothing);
    expect(find.text('WhatsApp não conectado'), findsNothing);
  });
}
