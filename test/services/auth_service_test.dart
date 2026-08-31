import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/services/api_client.dart';
import 'package:prontuario_tcc/services/auth_service.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';

void main() {
  late EncryptionService encryption;

  setUpAll(() async {
    Hive.init('test/temp_hive/auth_service');
    Hive.registerAdapters();
    await Hive.openBox<String>('app_config');
    await Hive.openBox<String>('auth_meta');
  });

  tearDownAll(() async {
    await Hive.box<String>('app_config').close();
    await Hive.box<String>('auth_meta').close();
    await Hive.deleteBoxFromDisk('app_config');
    await Hive.deleteBoxFromDisk('auth_meta');
  });

  setUp(() async {
    await Hive.box<String>('app_config').clear();
    await Hive.box<String>('auth_meta').clear();
    encryption = EncryptionService();
    EncryptionService.setInstance(encryption);
  });

  test('autenticarBackend nao persiste JWT em texto puro sem criptografia',
      () async {
    final auth = AuthService(encryption);
    await ApiClient.setCredentials(
      'fulano@exemplo.com',
      'senha-forte',
    );

    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({'access_token': 'jwt-token-de-teste'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final ok = await auth.autenticarBackend(client: mockClient);
    expect(ok, isTrue);

    final armazenado = Hive.box<String>('auth_meta').get('jwt_token');
    expect(armazenado, isNull,
        reason: 'sem criptografia, o JWT nao pode ser persistido em claro');
  });
}
