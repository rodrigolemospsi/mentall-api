import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/screens/whatsapp_conexao_page.dart';
import 'package:prontuario_tcc/services/api_client.dart';
import 'package:prontuario_tcc/utils/telefone_whatsapp.dart';

String _tokenValido() {
  final payload = base64Encode(utf8.encode(jsonEncode({'exp': 9999999999})));
  return 'a.$payload.c';
}

http.Response _status({required bool logado, String numero = ''}) => http.Response(
      jsonEncode({
        'sucesso': true,
        'configurado': true,
        'conectado': logado,
        'logado': logado,
        'numero': numero,
      }),
      200,
    );

void main() {
  setUpAll(() async {
    Hive.init('test/temp_hive/whatsapp_conexao_page');
    Hive.registerAdapters();
    await Hive.openBox<String>('app_config');
    await Hive.openBox<String>('auth_meta');
  });

  tearDownAll(() async {
    await Hive.deleteBoxFromDisk('app_config');
    await Hive.deleteBoxFromDisk('auth_meta');
  });

  test('formata número/JID do WhatsApp para exibição', () {
    expect(formatarNumeroWhatsapp('557592298347@s.whatsapp.net'),
        '(75) 9229-8347');
    expect(formatarNumeroWhatsapp('557592298347:10@s.whatsapp.net'),
        '(75) 9229-8347');
    expect(formatarNumeroWhatsapp(''), '');
  });

  setUp(() async {
    await Hive.box<String>('app_config').clear();
    await Hive.box<String>('auth_meta').clear();
    ApiClient.authToken = _tokenValido();
  });

  testWidgets('desconectado permite gerar o codigo de pareamento',
      (tester) async {
    ApiClient.httpClient = MockClient((req) async {
      if (req.url.path == '/wuzapi/parear') {
        return http.Response(
          jsonEncode({'sucesso': true, 'codigo': 'ABCD-EFGH', 'erro': ''}),
          200,
        );
      }
      return _status(logado: false);
    });

    await tester.pumpWidget(const MaterialApp(home: WhatsappConexaoPage()));
    await tester.pumpAndSettle();

    expect(find.text('Desconectado'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '(75) 9229-8347');
    await tester.tap(find.text('Gerar código de pareamento'));
    await tester.pumpAndSettle();

    expect(find.text('ABCD-EFGH'), findsOneWidget);
  });

  testWidgets('conectado mostra o estado e permite testar', (tester) async {
    ApiClient.httpClient = MockClient((req) async {
      if (req.url.path == '/wuzapi/testar') {
        return http.Response(jsonEncode({'sucesso': true, 'mensagem': 'ok'}), 200);
      }
      return _status(logado: true, numero: '557592298347');
    });

    await tester.pumpWidget(const MaterialApp(home: WhatsappConexaoPage()));
    await tester.pumpAndSettle();

    expect(find.text('Conectado'), findsOneWidget);
    // Campo "Número do WhatsApp" preenchido com o número conectado formatado.
    expect(find.text('(75) 9229-8347'), findsWidgets);

    await tester.tap(find.text('Enviar mensagem de teste'));
    await tester.pumpAndSettle();

    expect(find.text('Mensagem de teste enviada.'), findsOneWidget);
  });
}
