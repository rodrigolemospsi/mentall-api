import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/screens/redefinir_senha_page.dart';
import 'package:prontuario_tcc/services/api_client.dart';

void main() {
  setUpAll(() async {
    Hive.init('test/temp_hive/redefinir_senha');
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
    ApiClient.authToken = null;
  });

  testWidgets('renderiza e-mail e avança para o código', (tester) async {
    ApiClient.httpClient = MockClient((req) async {
      if (req.url.path == '/auth/solicitar-reset-senha') {
        return http.Response(jsonEncode({'sucesso': true}), 200);
      }
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(
      const MaterialApp(home: RedefinirSenhaPage(emailInicial: 'a@b.com')),
    );

    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Enviar código'), findsOneWidget);

    await tester.tap(find.text('Enviar código'));
    await tester.pumpAndSettle();

    expect(find.text('Código recebido'), findsOneWidget);
    expect(find.text('Nova senha'), findsOneWidget);
  });

  testWidgets('valida e-mail inválido sem chamar a rede', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RedefinirSenhaPage()));

    await tester.tap(find.text('Enviar código'));
    await tester.pump();

    expect(find.text('Informe um e-mail válido.'), findsOneWidget);
  });
}
