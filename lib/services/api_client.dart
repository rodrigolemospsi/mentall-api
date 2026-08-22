import 'dart:async';
import 'dart:convert';

import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;

import 'encryption_service.dart';
import 'logger.dart';

class ApiClient {
  static const String _baseUrlKey = 'backend_url';
  static const String _defaultBaseUrl = 'https://mentall-api.fly.dev';
  static const String _usernameKey = 'auth_username';
  static const String _passwordKey = 'auth_password';
  static const String _accountEmailKey = 'account_email';

  static String get defaultBaseUrl => _defaultBaseUrl;

  static String get baseUrl {
    final box = Hive.box<String>('app_config');
    return box.get(_baseUrlKey, defaultValue: _defaultBaseUrl) as String;
  }

  static Future<void> setBaseUrl(String url) async {
    final box = Hive.box<String>('app_config');
    await box.put(_baseUrlKey, url.trim());
  }

  static String get baseUrlExibicao => baseUrl;

  static const Duration timeout = Duration(seconds: 120);

  static String? authToken;

  static String get username {
    final box = Hive.box<String>('app_config');
    final stored = box.get(_usernameKey);
    return (stored != null && stored.isNotEmpty) ? stored : '';
  }

  static String get password {
    final box = Hive.box<String>('app_config');
    final stored = box.get(_passwordKey);
    if (stored != null && stored.isNotEmpty) {
      return EncryptionService.tryDecrypt(stored);
    }
    return '';
  }

  static Future<void> setCredentials(String username, String password) async {
    final box = Hive.box<String>('app_config');
    await box.put(_usernameKey, username);
    final encrypted = EncryptionService.tryEncrypt(password);
    await box.put(_passwordKey, encrypted ?? password);
  }

  static String get _username => username;
  static String get _password => password;

  static Map<String, String> get authHeaders {
    final token = authToken;
    if (token == null || token.isEmpty) return {};
    return {'Authorization': 'Bearer $token'};
  }

  static Map<String, String> defaultHeaders() {
    return {
      'Content-Type': 'application/json',
      ...authHeaders,
    };
  }

  static Future<bool> ensureAuthenticated() async {
    if (authToken != null && authToken!.isNotEmpty) {
      if (_tokenExpirado(authToken!)) {
        return forceReauthenticate();
      }
      return true;
    }

    return forceReauthenticate();
  }

  static bool _tokenExpirado(String token) {
    try {
      final partes = token.split('.');
      if (partes.length != 3) return true;

      String payloadBase64 = partes[1];
      final resto = payloadBase64.length % 4;
      if (resto != 0) {
        payloadBase64 += '=' * (4 - resto);
      }

      final payloadBytes = base64Decode(payloadBase64);
      final payload = jsonDecode(utf8.decode(payloadBytes)) as Map<String, dynamic>;
      final exp = payload['exp'] as int?;
      if (exp == null) return false;

      final agora = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return agora >= exp;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> forceReauthenticate() async {
    authToken = null;
    try {
      await Hive.box<String>('auth_meta').delete('jwt_token');
    } catch (_) {}

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': _username,
              'password': _password,
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['access_token'] as String?;
        if (token == null || token.isEmpty) return false;
        authToken = token;
        try {
          final encryptedToken = EncryptionService.tryEncrypt(token);
          await Hive.box<String>('auth_meta')
              .put('jwt_token', encryptedToken ?? token);
        } catch (_) {}
        return true;
      }
    } catch (e) {
      Log.erro(e, contexto: 'ApiClient.forceReauthenticate');
    }

    return false;
  }

  static String? get accountEmail {
    final box = Hive.box<String>('auth_meta');
    final valor = box.get(_accountEmailKey);
    return (valor != null && valor.isNotEmpty) ? valor : null;
  }

  static bool get possuiConta => accountEmail != null;

  static Future<void> salvarConta(String email) async {
    await Hive.box<String>('auth_meta')
        .put(_accountEmailKey, email.trim().toLowerCase());
  }

  static Future<Map<String, dynamic>> registrarConta({
    required String email,
    required String senha,
    String nome = '',
  }) async {
    try {
      final response = await post(
        '/auth/registrar',
        body: {'email': email.trim(), 'senha': senha, 'nome': nome.trim()},
        customTimeout: const Duration(seconds: 30),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return {
          'sucesso': data['sucesso'] == true,
          'mensagem': data['mensagem'] ?? '',
          'erro': data['erro'] ?? '',
        };
      }
      return {
        'sucesso': false,
        'erro': _extrairDetalhe(data) ?? 'Falha ao criar conta.',
      };
    } catch (_) {
      return {'sucesso': false, 'erro': 'Erro de conexao. Verifique a internet.'};
    }
  }

  static Future<Map<String, dynamic>> entrarComEmailSenha({
    required String email,
    required String senha,
  }) async {
    try {
      final response = await post(
        '/auth/login',
        body: {'username': email.trim(), 'password': senha},
        customTimeout: const Duration(seconds: 30),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        return {
          'sucesso': false,
          'erro': _extrairDetalhe(data) ?? 'Email ou senha invalidos.',
        };
      }
      final token = data['access_token'] as String?;
      if (token == null || token.isEmpty) {
        return {'sucesso': false, 'erro': 'Resposta invalida do servidor.'};
      }
      authToken = token;
      final encryptedToken = EncryptionService.tryEncrypt(token);
      await Hive.box<String>('auth_meta')
          .put('jwt_token', encryptedToken ?? token);
      await salvarConta(email);
      await setCredentials(email.trim(), senha);
      return {'sucesso': true};
    } catch (_) {
      return {'sucesso': false, 'erro': 'Erro de conexao. Verifique a internet.'};
    }
  }

  static String? _extrairDetalhe(Map<String, dynamic> data) {
    final detalhe = data['detail'];
    if (detalhe is String && detalhe.isNotEmpty) return detalhe;
    if (detalhe is List && detalhe.isNotEmpty) {
      final primeiro = detalhe.first;
      if (primeiro is Map && primeiro['msg'] is String) {
        return primeiro['msg'] as String;
      }
    }
    return null;
  }

  static Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
    Duration? customTimeout,
  }) async {
    return http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: defaultHeaders(),
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(customTimeout ?? timeout);
  }

  static Future<http.Response> get(String path, {Duration? customTimeout}) async {
    return http
        .get(
          Uri.parse('$baseUrl$path'),
          headers: defaultHeaders(),
        )
        .timeout(customTimeout ?? timeout);
  }

  static Future<void> registrarRecuperacao(String email, String recoveryToken) async {
    await post('/auth/registrar-recuperacao', body: {
      'email': email,
      'recovery_token': recoveryToken,
    });
  }

  static Future<bool> solicitarCodigoRecuperacao(String email) async {
    try {
      final res = await post('/auth/solicitar-recuperacao', body: {'email': email});
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> verificarCodigoRecuperacao(String email, String codigo) async {
    try {
      final res = await post('/auth/verificar-recuperacao', body: {
        'email': email,
        'codigo': codigo,
      });
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['recovery_token'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
