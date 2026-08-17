import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:hive_ce/hive.dart';
import 'package:local_auth/local_auth.dart';

import 'logger.dart';
import 'api_client.dart';
import 'encryption_service.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const String _authBoxName = 'auth_meta';
  static const String _tokenKey = 'jwt_token';
  static const String _usernameKey = 'auth_username';
  static const String _passwordKey = 'auth_password';

  late final Box<String> _box = Hive.box<String>(_authBoxName);
  final LocalAuthentication _localAuth = LocalAuthentication();

  final EncryptionService _encryptionService;
  bool _desbloqueado = false;

  AuthService(this._encryptionService);

  bool get desbloqueado => _desbloqueado;

  EncryptionService get encryption => _encryptionService;

  String get _username {
    final box = Hive.box<String>('app_config');
    final stored = box.get(_usernameKey);
    if (stored != null && stored.isNotEmpty) return stored;
    return '';
  }

  String get _password {
    final box = Hive.box<String>('app_config');
    final stored = box.get(_passwordKey);
    if (stored != null && stored.isNotEmpty) {
      return EncryptionService.tryDecrypt(stored);
    }
    return '';
  }

  Future<void> inicializar() async {
    final token = _box.get(_tokenKey);
    if (token != null && token.isNotEmpty) {
      ApiClient.authToken = EncryptionService.tryDecrypt(token);
    }
  }

  bool get possuiTokenJwt {
    final token = _box.get(_tokenKey);
    if (token == null || token.isEmpty) return false;
    final decrypted = EncryptionService.tryDecrypt(token);
    return decrypted.isNotEmpty;
  }

  String? get tokenJwt {
    final token = _box.get(_tokenKey);
    if (token == null || token.isEmpty) return null;
    return EncryptionService.tryDecrypt(token);
  }

  Future<bool> autenticarBackend() async {
    try {
      final user = _username;
      final pass = _password;
      if (user.isEmpty || pass.isEmpty) {
        Log.erro('Credenciais do backend nao configuradas.', contexto: 'AuthService.autenticarBackend');
        return false;
      }
      final response = await http
          .post(
            Uri.parse('${ApiClient.baseUrl}/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': user,
              'password': pass,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['access_token'] as String?;
        if (token == null || token.isEmpty) return false;
        final encryptedToken = EncryptionService.tryEncrypt(token);
        await _box.put(_tokenKey, encryptedToken ?? token);
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

  Future<bool> desbloquearComBiometria() async {
    try {
      final sucesso = await _encryptionService.carregarChaveDoSecureStorage();
      if (sucesso) {
        _desbloqueado = true;
      }
      return sucesso;
    } on PlatformException catch (e) {
      if (e.code == 'NotAvailable') return false;
      Log.erro(e, contexto: 'AuthService.desbloquearComBiometria');
      return false;
    } catch (e) {
      Log.erro(e, contexto: 'AuthService.desbloquearComBiometria');
      return false;
    }
  }

  Future<bool> gerarChave() async {
    final sucesso = await _encryptionService.gerarChave();
    if (sucesso) {
      _desbloqueado = true;
    }
    return sucesso;
  }

  Future<bool> migrarChaveDoPinLegado(String pin) async {
    final sucesso = await _encryptionService.migrarChaveDoPinLegado(pin);
    if (sucesso) {
      _desbloqueado = true;
    }
    return sucesso;
  }

  Future<bool> get dispositivoPossuiBiometria async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      if (!isSupported) return false;
      return await _localAuth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> get tiposBiometriaDisponiveis async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return <BiometricType>[];
    }
  }

  bool get requerAutenticacao => _encryptionService.possuiChaveProtegida;

  bool get possuiPinLegado => _encryptionService.possuiPinLegado;

  Future<void> bloquear() async {
    _desbloqueado = false;
    ApiClient.authToken = null;
    try {
      await Hive.box<String>('auth_meta').delete('jwt_token');
    } catch (_) {}
  }

  /// Valida o PIN sem desbloquear o app nem incrementar tentativas.
  /// Usado para operações sensíveis (ex: exportar backup) que exigem reautenticação.
  Future<bool> validarPin(String pin) async {
    return _encryptionService.validarPin(pin);
  }
}
