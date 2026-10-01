import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/screens/lembretes_page.dart';
import 'package:prontuario_tcc/services/api_client.dart';

String _tokenValido() {
  final payload = base64Encode(utf8.encode(jsonEncode({'exp': 9999999999})));
  return 'a.$payload.c';
}

Map<String, dynamic> _lembrete({String status = 'pendente'}) => {
      'id': 'l1',
      'compromisso_id': 'c1',
      'telefone': '+5575992298347',
      'mensagem': 'Sessao amanha',
      'horario_envio': '2026-11-15T18:00:00+00:00',
      'canal': 'whatsapp',
      'status': status,
      'tentativas': 0,
    };

void main() {
  setUpAll(() async {
    Hive.init('test/temp_hive/lembretes_page');
    Hive.registerAdapters();
    await Hive.openBox<String>('app_config');
    await Hive.openBox<String>('auth_meta');
  });

  tearDownAll(() async {
    await Hive.deleteBoxFromDisk('app_config');
    await Hive.deleteBoxFromDisk('auth_meta');
  });

  setUp(() async {
    await Hive.box<String>('app_config').clear();
    await Hive.box<String>('auth_meta').clear();
    ApiClient.authToken = _tokenValido();
  });

  testWidgets('lista os lembretes e mostra o botao cancelar todos',
      (tester) async {
    ApiClient.httpClient = MockClient((req) async {
      return http.Response(
        jsonEncode({'sucesso': true, 'lembretes': [_lembrete()]}),
        200,
      );
    });

    await tester.pumpWidget(const MaterialApp(home: LembretesPage()));
    await tester.pumpAndSettle();

    expect(find.text('Sessao amanha'), findsOneWidget);
    expect(find.text('Pendente'), findsOneWidget);
    expect(find.text('Cancelar todos'), findsOneWidget);
  });

  testWidgets('mostra estado vazio quando nao ha lembretes', (tester) async {
    ApiClient.httpClient = MockClient((_) async =>
        http.Response(jsonEncode({'sucesso': true, 'lembretes': []}), 200));

    await tester.pumpWidget(const MaterialApp(home: LembretesPage()));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum lembrete agendado.'), findsOneWidget);
  });

  testWidgets('cancelar todos pede confirmacao e mostra o total',
      (tester) async {
    var cancelou = false;
    ApiClient.httpClient = MockClient((req) async {
      if (req.method == 'DELETE') {
        cancelou = true;
        return http.Response(jsonEncode({'sucesso': true, 'cancelados': 1}), 200);
      }
      return http.Response(
        jsonEncode({
          'sucesso': true,
          'lembretes': cancelou ? [] : [_lembrete()],
        }),
        200,
      );
    });

    await tester.pumpWidget(const MaterialApp(home: LembretesPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar todos'));
    await tester.pumpAndSettle();
    expect(find.text('Cancelar todos os lembretes?'), findsOneWidget);

    // Confirma no dialogo (botao de acao).
    await tester.tap(find.widgetWithText(FilledButton, 'Cancelar todos'));
    await tester.pumpAndSettle();

    expect(cancelou, isTrue);
    expect(find.text('1 lembrete(s) cancelado(s).'), findsOneWidget);
    expect(find.text('Nenhum lembrete agendado.'), findsOneWidget);
  });
}
