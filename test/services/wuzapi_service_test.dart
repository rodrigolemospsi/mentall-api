import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/services/api_client.dart';
import 'package:prontuario_tcc/services/wuzapi_service.dart';

String _tokenValido() {
  final payload = base64Encode(utf8.encode(jsonEncode({'exp': 9999999999})));
  return 'a.$payload.c';
}

void main() {
  setUpAll(() async {
    Hive.init('test/temp_hive/wuzapi_service');
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

  test('status devolve o estado da conexao', () async {
    ApiClient.httpClient = MockClient((req) async {
      expect(req.url.path, '/wuzapi/status');
      return http.Response(
        jsonEncode({
          'sucesso': true,
          'configurado': true,
          'conectado': true,
          'logado': true,
          'numero': '557592298347@s.whatsapp.net',
        }),
        200,
      );
    });

    final r = await WuzapiService.status();
    expect(r['sucesso'], isTrue);
    expect(r['conectado'], isTrue);
    expect(r['numero'], contains('557592298347'));
  });

  test('parear devolve o codigo de pareamento', () async {
    ApiClient.httpClient = MockClient((req) async {
      expect(req.url.path, '/wuzapi/parear');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['telefone'], '(75) 9229-8347');
      return http.Response(
        jsonEncode({'sucesso': true, 'codigo': 'ABCD-EFGH', 'erro': ''}),
        200,
      );
    });

    final r = await WuzapiService.parear('(75) 9229-8347');
    expect(r['sucesso'], isTrue);
    expect(r['codigo'], 'ABCD-EFGH');
  });

  test('qr devolve o data uri', () async {
    ApiClient.httpClient = MockClient((req) async {
      expect(req.url.path, '/wuzapi/qr');
      return http.Response(
        jsonEncode({'sucesso': true, 'qr_code': 'data:image/png;base64,AAA'}),
        200,
      );
    });

    final r = await WuzapiService.qr();
    expect(r['sucesso'], isTrue);
    expect(r['qr_code'], startsWith('data:image/png;base64,'));
  });

  test('desconectar devolve true no sucesso', () async {
    ApiClient.httpClient = MockClient((req) async {
      expect(req.url.path, '/wuzapi/desconectar');
      return http.Response(jsonEncode({'sucesso': true, 'mensagem': 'ok'}), 200);
    });

    expect(await WuzapiService.desconectar(logout: true), isTrue);
  });

  test('testar devolve sucesso', () async {
    ApiClient.httpClient = MockClient((req) async {
      expect(req.url.path, '/wuzapi/testar');
      return http.Response(jsonEncode({'sucesso': true, 'mensagem': 'enviada'}), 200);
    });

    final r = await WuzapiService.testar('(75) 9229-8347');
    expect(r['sucesso'], isTrue);
  });

  test('erro do backend vira sucesso=false com a mensagem', () async {
    ApiClient.httpClient = MockClient((_) async =>
        http.Response(jsonEncode({'erro': 'WhatsApp nao configurado'}), 500));

    final r = await WuzapiService.parear('(75) 9229-8347');
    expect(r['sucesso'], isFalse);
    expect(r['erro'], contains('configurado'));
  });
}
