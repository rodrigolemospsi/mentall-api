import 'dart:async';
import 'dart:convert';

import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;

import 'logger.dart';

class ApiClient {
  static const String _baseUrlKey = 'backend_url';
  static const String _defaultBaseUrl = 'https://mentall-api.onrender.com';

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

  static String? _authToken;

  static String? get authToken => _authToken;

  static set authToken(String? token) => _authToken = token;

  static Map<String, String> get authHeaders {
    final token = _authToken;
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
    if (_authToken != null && _authToken!.isNotEmpty) {
      if (_tokenExpirado(_authToken!)) {
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
    _authToken = null;
    try {
      await Hive.box<String>('auth_meta').delete('jwt_token');
    } catch (_) {}

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': 'admin', 'password': 'admin'}),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _authToken = data['access_token'] as String;
        try {
          await Hive.box<String>('auth_meta').put('jwt_token', _authToken!);
        } catch (_) {}
        return true;
      }
    } catch (e) {
      Log.erro(e, contexto: 'ApiClient.forceReauthenticate');
    }

    return false;
  }
}
