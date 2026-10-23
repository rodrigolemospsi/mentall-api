import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/services/api_client.dart';
import 'package:prontuario_tcc/services/credenciais_store.dart';

/// JWT sintético com `exp` no futuro: evita que `ensureAuthenticated` tente
/// reautenticar durante os testes de exclusão.
String _jwtValido() {
  final payload = base64Url.encode(utf8.encode(jsonEncode(<String, dynamic>{
    'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
        1000,
  })));
  return 'header.$payload.assinatura';
}

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('api_client_exclusao_');
    Hive.init(dir.path);
    Hive.registerAdapters();
    await Hive.openBox<String>('app_config');
    await Hive.openBox<String>('auth_meta');
  });

  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  setUp(() async {
    await Hive.box<String>('app_config').clear();
    await Hive.box<String>('auth_meta').clear();
    ApiClient.authToken = null;
    ApiClient.resetarCredenciaisEmMemoria();
    ApiClient.credenciaisStore = _FakeCredenciaisStore();
    ApiClient.httpClient =
        MockClient((_) async => throw StateError('http nao mockado'));
  });

  test('excluirConta envia DELETE /conta com confirmação e Bearer', () async {
    ApiClient.authToken = _jwtValido();
    http.Request? recebida;
    ApiClient.httpClient = MockClient((request) async {
      recebida = request;
      return http.Response(
        jsonEncode(<String, dynamic>{
          'sucesso': true,
          'quando': '2026-10-23T18:00:00+00:00',
          'eliminado': <String, dynamic>{'usuarios': 1, 'contratos': 2},
          'retido': <String, dynamic>{'prontuario': 'fica no aparelho'},
        }),
        200,
      );
    });

    final resultado = await ApiClient.excluirConta(confirmacao: 'EXCLUIR');

    expect(resultado['sucesso'], isTrue);
    expect(recebida?.method, 'DELETE');
    expect(recebida?.url.path, '/conta');
    final autorizacao =
        recebida?.headers['Authorization'] ?? recebida?.headers['authorization'];
    expect(autorizacao, startsWith('Bearer '));
    expect(jsonDecode(recebida!.body), <String, dynamic>{'confirmacao': 'EXCLUIR'});

    final recibo = resultado['recibo'] as Map<String, dynamic>;
    expect(recibo['quando'], '2026-10-23T18:00:00+00:00');
    expect(
      (recibo['eliminado'] as Map<String, dynamic>)['contratos'],
      2,
    );
  });

  test('excluirConta devolve o erro 403 da conta administrativa', () async {
    ApiClient.authToken = _jwtValido();
    ApiClient.httpClient = MockClient(
      (_) async => http.Response(
        jsonEncode(<String, dynamic>{
          'detail': 'A conta administrativa não pode ser excluída pelo aplicativo.',
        }),
        403,
      ),
    );

    final resultado = await ApiClient.excluirConta(confirmacao: 'EXCLUIR');

    expect(resultado['sucesso'], isFalse);
    expect(resultado['status'], 403);
    expect(resultado['erro'], contains('administrativa'));
  });

  test('excluirConta devolve o erro 400 de confirmação inválida', () async {
    ApiClient.authToken = _jwtValido();
    ApiClient.httpClient = MockClient(
      (_) async => http.Response(
        jsonEncode(<String, dynamic>{
          'detail': "Confirmação inválida. Envie 'EXCLUIR'.",
        }),
        400,
      ),
    );

    final resultado = await ApiClient.excluirConta(confirmacao: 'excluir');

    expect(resultado['sucesso'], isFalse);
    expect(resultado['status'], 400);
    expect(resultado['erro'], contains('Confirmação'));
  });

  test('excluirConta sem sessão devolve 401 sem chamar a rede', () async {
    var chamouRede = false;
    ApiClient.httpClient = MockClient((_) async {
      chamouRede = true;
      return http.Response('{}', 200);
    });

    final resultado = await ApiClient.excluirConta(confirmacao: 'EXCLUIR');

    expect(resultado['sucesso'], isFalse);
    expect(resultado['status'], 401);
    expect(resultado['erro'], contains('Sessão expirada'));
    expect(chamouRede, isFalse);
  });

  test('excluirConta trata falha de conexão', () async {
    ApiClient.authToken = _jwtValido();
    ApiClient.httpClient =
        MockClient((_) async => throw const SocketException('sem rede'));

    final resultado = await ApiClient.excluirConta(confirmacao: 'EXCLUIR');

    expect(resultado['sucesso'], isFalse);
    expect(resultado['erro'], contains('conexão'));
  });

  test('limparSessaoLocal apaga token, conta e credenciais do cofre', () async {
    ApiClient.authToken = _jwtValido();
    final auth = Hive.box<String>('auth_meta');
    await auth.put('jwt_token', 'token-cifrado');
    await auth.put('account_email', 'psi@exemplo.com');
    final config = Hive.box<String>('app_config');
    await config.put('auth_username', 'psi@exemplo.com');
    await config.put('auth_password', 'senha-cifrada');
    final store = _FakeCredenciaisStore('psi@exemplo.com', 'senha');
    ApiClient.credenciaisStore = store;

    await ApiClient.limparSessaoLocal();

    expect(ApiClient.authToken, isNull);
    expect(ApiClient.accountEmail, isNull);
    expect(auth.get('jwt_token'), isNull);
    expect(auth.get('account_email'), isNull);
    expect(config.get('auth_username'), isNull);
    expect(config.get('auth_password'), isNull);
    expect(store.username, isNull);
    expect(store.password, isNull);
  });
}

class _FakeCredenciaisStore implements CredenciaisStore {
  _FakeCredenciaisStore([this.username, this.password]);

  String? username;
  String? password;

  @override
  Future<void> salvar(String user, String pass) async {
    username = user;
    password = pass;
  }

  @override
  Future<(String?, String?)> carregar() async => (username, password);

  @override
  Future<void> limpar() async {
    username = null;
    password = null;
  }
}
