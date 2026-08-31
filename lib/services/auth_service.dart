import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce/hive.dart';
import 'package:local_auth/local_auth.dart';

import 'logger.dart';
import 'api_client.dart';
import 'encryption_service.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const String _authBoxName = 'auth_meta';
  static const String _tokenKey = 'jwt_token';

  // SecureStorage keys for server credentials (protected by device PIN/biometrics)
  static const String _serverUserKey = 'server_username';
  static const String _serverPassKey = 'server_password';

  late final Box<String> _box = Hive.box<String>(_authBoxName);
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final EncryptionService _encryptionService;
  bool _desbloqueado = false;

  AuthService(this._encryptionService);

  bool get desbloqueado => _desbloqueado;

  EncryptionService get encryption => _encryptionService;

  String get _username => ApiClient.username;

  String get _password => ApiClient.password;

  Future<void> inicializar() async {
    final token = _box.get(_tokenKey);
    if (token != null && token.isNotEmpty) {
      ApiClient.authToken = EncryptionService.tryDecrypt(token);
    }
  }

  bool get possuiTokenJwt {
    if (ApiClient.authToken != null && ApiClient.authToken!.isNotEmpty) {
      return true;
    }
    final token = _box.get(_tokenKey);
    if (token == null || token.isEmpty) return false;
    final decrypted = EncryptionService.tryDecrypt(token);
    return decrypted.isNotEmpty;
  }

  String? get tokenJwt {
    if (ApiClient.authToken != null && ApiClient.authToken!.isNotEmpty) {
      return ApiClient.authToken;
    }
    final token = _box.get(_tokenKey);
    if (token == null || token.isEmpty) return null;
    return EncryptionService.tryDecrypt(token);
  }
  Future<bool> autenticarBackend({http.Client? client}) async {
    try {
      final user = _username;
      final pass = _password;
      if (user.isEmpty || pass.isEmpty) {
        Log.erro('Credenciais do backend não configuradas.', contexto: 'AuthService.autenticarBackend');
        return false;
      }

      final httpClient = client ?? http.Client();
      final response = await httpClient
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
        if (encryptedToken != null) {
          await _box.put(_tokenKey, encryptedToken);
        } else {
          // Sem criptografia disponível: mantém o token apenas em memória,
          // nunca persiste o JWT em texto puro (mesmo padrão do ApiClient).
          await _box.delete(_tokenKey);
        }
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

  /// Salva credenciais do servidor no SecureStorage (protegido por PIN/biometria do dispositivo).
  Future<void> salvarCredenciaisServidor(String username, String password) async {
    await _secureStorage.write(key: _serverUserKey, value: username);
    await _secureStorage.write(key: _serverPassKey, value: password);
  }

  /// Carrega credenciais do servidor do SecureStorage.
  /// Retorna (username, password) ou (null, null) se não existirem.
  Future<(String?, String?)> carregarCredenciaisServidor() async {
    final username = await _secureStorage.read(key: _serverUserKey);
    final password = await _secureStorage.read(key: _serverPassKey);
    return (username, password);
  }

  /// Remove credenciais do servidor do SecureStorage.
  Future<void> limparCredenciaisServidor() async {
    await _secureStorage.delete(key: _serverUserKey);
    await _secureStorage.delete(key: _serverPassKey);
  }

  /// Tenta auto-login com credenciais salvas no SecureStorage.
  /// Deve ser chamado após desbloqueio bem-sucedido (biometria/PIN).
  Future<bool> tentarAutoLoginServidor() async {
    final (username, password) = await carregarCredenciaisServidor();
    if (username == null || password == null || username.isEmpty || password.isEmpty) {
      return false;
    }

    // Configura no ApiClient e tenta autenticar
    await ApiClient.setCredentials(username, password);
    return autenticarBackend();
  }
}
