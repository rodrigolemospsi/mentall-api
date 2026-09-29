import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/services/api_client.dart';
import 'package:prontuario_tcc/services/telemetria_service.dart';

void main() {
  setUpAll(() async {
    Hive.init('test/temp_hive/telemetria');
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
    ApiClient.authToken = 'token-de-teste';
    ApiClient.httpClient = MockClient((_) async => throw StateError('nao mockado'));
  });

  test('deviceId é estável e persistido no app_config', () async {
    final s = TelemetriaService();
    final id1 = s.deviceId;
    final id2 = TelemetriaService().deviceId;

    expect(id1, isNotEmpty);
    expect(id1, id2);
    expect(Hive.box<String>('app_config').get('device_id'), id1);
  });

  test('registrarEvento envia POST com device_id e tipo', () async {
    late http.Request capturado;
    ApiClient.httpClient = MockClient((req) async {
      capturado = req;
      return http.Response(jsonEncode({'sucesso': true}), 200);
    });

    await TelemetriaService().registrarEvento('sintese');

    expect(capturado.url.path, '/telemetria/evento');
    final body = jsonDecode(capturado.body) as Map<String, dynamic>;
    expect(body['tipo'], 'sintese');
    expect(body['device_id'], isNotEmpty);
  });

  test('heartbeat envia POST com plataforma', () async {
    late http.Request capturado;
    ApiClient.httpClient = MockClient((req) async {
      capturado = req;
      return http.Response(jsonEncode({'sucesso': true}), 200);
    });

    await TelemetriaService().heartbeat();

    expect(capturado.url.path, '/telemetria/heartbeat');
    final body = jsonDecode(capturado.body) as Map<String, dynamic>;
    expect(body['plataforma'], isNotEmpty);
  });

  test('evento fica na fila se falhar e é reenviado no próximo heartbeat', () async {
    ApiClient.httpClient = MockClient((_) async => throw StateError('offline'));
    await TelemetriaService().registrarEvento('transcricao');

    final fila = Hive.box<String>('app_config').get('telemetria_fila');
    expect(fila, isNotNull);
    expect(fila, contains('transcricao'));

    final enviados = <String>[];
    ApiClient.httpClient = MockClient((req) async {
      if (req.url.path == '/telemetria/evento') {
        enviados.add(jsonDecode(req.body)['tipo'] as String);
      }
      return http.Response(jsonEncode({'sucesso': true}), 200);
    });

    await TelemetriaService().heartbeat();

    expect(enviados, contains('transcricao'));
    expect(Hive.box<String>('app_config').get('telemetria_fila'), isNull);
  });

  test('tipo fora da allowlist não é enviado', () async {
    var chamou = false;
    ApiClient.httpClient = MockClient((_) async {
      chamou = true;
      return http.Response('{}', 200);
    });

    await TelemetriaService().registrarEvento('nome_paciente');

    expect(chamou, isFalse);
  });
}
