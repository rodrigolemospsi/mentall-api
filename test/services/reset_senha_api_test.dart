import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/services/api_client.dart';

void main() {
  setUpAll(() async {
    Hive.init('test/temp_hive/reset_senha_api');
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

  test('solicitarResetSenha faz POST e retorna true em 200', () async {
    late http.Request capturado;
    ApiClient.httpClient = MockClient((req) async {
      capturado = req;
      return http.Response(jsonEncode({'sucesso': true}), 200);
    });

    final ok = await ApiClient.solicitarResetSenha('a@b.com');

    expect(ok, isTrue);
    expect(capturado.url.path, '/auth/solicitar-reset-senha');
    expect(jsonDecode(capturado.body)['email'], 'a@b.com');
  });

  test('redefinirSenha envia email/codigo/nova_senha e retorna sucesso', () async {
    Map<String, dynamic>? enviado;
    ApiClient.httpClient = MockClient((req) async {
      enviado = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(jsonEncode({'sucesso': true, 'mensagem': 'ok'}), 200);
    });

    final r = await ApiClient.redefinirSenha(
      email: 'a@b.com',
      codigo: 'ABC12345',
      novaSenha: 'NovaSenha123',
    );

    expect(r['sucesso'], isTrue);
    expect(enviado?['email'], 'a@b.com');
    expect(enviado?['codigo'], 'ABC12345');
    expect(enviado?['nova_senha'], 'NovaSenha123');
  });

  test('redefinirSenha expõe o erro do servidor', () async {
    ApiClient.httpClient = MockClient(
      (_) async => http.Response(jsonEncode({'sucesso': false, 'erro': 'Codigo invalido.'}), 200),
    );

    final r = await ApiClient.redefinirSenha(
      email: 'a@b.com',
      codigo: 'X',
      novaSenha: 'NovaSenha123',
    );

    expect(r['sucesso'], isFalse);
    expect(r['erro'], 'Codigo invalido.');
  });
}
