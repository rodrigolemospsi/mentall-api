import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/services/api_client.dart';
import 'package:prontuario_tcc/services/lembrete_service.dart';

String _tokenValido() {
  final payload = base64Encode(utf8.encode(jsonEncode({'exp': 9999999999})));
  return 'a.$payload.c';
}

void main() {
  setUpAll(() async {
    Hive.init('test/temp_hive/lembrete_service');
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

  test('listarLembretes devolve a lista retornada pelo backend', () async {
    ApiClient.httpClient = MockClient((req) async {
      expect(req.method, 'GET');
      expect(req.url.path, '/lembretes');
      return http.Response(
        jsonEncode({
          'sucesso': true,
          'lembretes': [
            {
              'id': 'l1',
              'compromisso_id': 'c1',
              'telefone': '+5575992298347',
              'mensagem': 'Sessao amanha',
              'horario_envio': '2026-11-15T18:00:00+00:00',
              'canal': 'whatsapp',
              'status': 'pendente',
              'tentativas': 0,
            }
          ],
        }),
        200,
      );
    });

    final lista = await LembreteService.listarLembretes();
    expect(lista, hasLength(1));
    expect(lista.first['compromisso_id'], 'c1');
    expect(lista.first['status'], 'pendente');
  });

  test('listarLembretes inclui o filtro de status na query', () async {
    Uri? capturada;
    ApiClient.httpClient = MockClient((req) async {
      capturada = req.url;
      return http.Response(jsonEncode({'sucesso': true, 'lembretes': []}), 200);
    });

    await LembreteService.listarLembretes(status: 'pendente');
    expect(capturada?.queryParameters['status'], 'pendente');
  });

  test('listarLembretes devolve lista vazia em erro do backend', () async {
    ApiClient.httpClient = MockClient((_) async => http.Response('erro', 500));
    expect(await LembreteService.listarLembretes(), isEmpty);
  });

  test('cancelarTodosLembretes devolve o total cancelado', () async {
    ApiClient.httpClient = MockClient((req) async {
      expect(req.method, 'DELETE');
      expect(req.url.path, '/lembretes');
      return http.Response(jsonEncode({'sucesso': true, 'cancelados': 3}), 200);
    });

    expect(await LembreteService.cancelarTodosLembretes(), 3);
  });

  test('cancelarTodosLembretes devolve 0 em erro do backend', () async {
    ApiClient.httpClient = MockClient((_) async => http.Response('erro', 401));
    expect(await LembreteService.cancelarTodosLembretes(), 0);
  });
}
