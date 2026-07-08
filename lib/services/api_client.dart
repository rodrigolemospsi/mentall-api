import 'package:hive_ce/hive.dart';

class ApiClient {
  static const String _baseUrlKey = 'backend_url';
  static const String _defaultBaseUrl = 'https://mentall-api.onrender.com';

  static String get baseUrl {
    final box = Hive.box<String>('app_config');
    return box.get(_baseUrlKey, defaultValue: _defaultBaseUrl) as String;
  }

  static Future<void> setBaseUrl(String url) async {
    final box = Hive.box<String>('app_config');
    await box.put(_baseUrlKey, url.trim());
  }

  static String get baseUrlExibicao => baseUrl;

  static const Duration timeout = Duration(seconds: 30);

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
}
