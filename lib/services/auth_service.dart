import 'dart:convert';

import 'package:hive_ce/hive.dart';

import 'logger.dart';
import 'api_client.dart';
import 'encryption_service.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const String _authBoxName = 'auth_meta';
  static const String _tokenKey = 'jwt_token';

  late final Box<String> _box;

  final EncryptionService _encryptionService;
  bool _desbloqueado = false;

  AuthService(this._encryptionService);

  bool get desbloqueado => _desbloqueado;

  EncryptionService get encryption => _encryptionService;

  Future<void> inicializar() async {
    _box = await Hive.openBox<String>(_authBoxName);
    final token = _box.get(_tokenKey);
    if (token != null && token.isNotEmpty) {
      ApiClient.authToken = token;
    }
    await _tentarAutenticarBackend();
  }

  bool get possuiTokenJwt {
    final token = _box.get(_tokenKey);
    return token != null && token.isNotEmpty;
  }

  String? get tokenJwt => _box.get(_tokenKey);

  Future<bool> autenticarBackend() async {
    try {
      final response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': 'admin',
          'password': 'admin',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['access_token'] as String;
        await _box.put(_tokenKey, token);
        ApiClient.authToken = token;
        return true;
      }
      return false;
    } catch (e) {
      Log.erro(e, contexto: 'AuthService.autenticarBackend');
      return false;
    }
  }

  Map<String, String> get authHeaders {
    final token = tokenJwt;
    if (token == null || token.isEmpty) return {};
    return {'Authorization': 'Bearer $token'};
  }

  Future<void> desbloquearComPin(String pin) async {
    final sucesso = await _encryptionService.desbloquear(pin);
    if (sucesso) {
      _desbloqueado = true;
      await _tentarAutenticarBackend();
    }
  }

  Future<void> configurarPin(String pin) async {
    await _encryptionService.configurarPin(pin);
    _desbloqueado = true;
    await _tentarAutenticarBackend();
  }

  Future<void> _tentarAutenticarBackend() async {
    try {
      await autenticarBackend();
    } catch (_) {}
  }

  bool get requerPin => _encryptionService.possuiPinConfigurado;

  Future<void> bloquear() async {
    _desbloqueado = false;
  }
}
