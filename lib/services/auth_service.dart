import 'dart:async';
import 'dart:convert';

import 'package:hive_ce/hive.dart';

import 'logger.dart';
import 'api_client.dart';
import 'encryption_service.dart';
import 'paciente_service.dart';
import 'sessao_service.dart';
import 'perfil_profissional_service.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const String _authBoxName = 'auth_meta';
  static const String _tokenKey = 'jwt_token';
  static const String _usernameKey = 'auth_username';
  static const String _passwordKey = 'auth_password';
  static const String _defaultUsername = 'admin';
  static const String _defaultPassword = 'admin';

  late final Box<String> _box = Hive.box<String>(_authBoxName);

  final EncryptionService _encryptionService;
  final PacienteService? _pacienteService;
  final SessaoService? _sessaoService;
  final PerfilProfissionalService? _perfilProfissionalService;
  bool _desbloqueado = false;

  AuthService(
    this._encryptionService, {
    PacienteService? pacienteService,
    SessaoService? sessaoService,
    PerfilProfissionalService? perfilProfissionalService,
  })  : _pacienteService = pacienteService,
        _sessaoService = sessaoService,
        _perfilProfissionalService = perfilProfissionalService;

  bool get desbloqueado => _desbloqueado;

  EncryptionService get encryption => _encryptionService;

  String get _username {
    final box = Hive.box<String>('app_config');
    return box.get(_usernameKey, defaultValue: _defaultUsername) as String;
  }

  String get _password {
    final box = Hive.box<String>('app_config');
    return box.get(_passwordKey, defaultValue: _defaultPassword) as String;
  }

  Future<void> inicializar() async {
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
      final response = await http
          .post(
            Uri.parse('${ApiClient.baseUrl}/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': _username,
              'password': _password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['access_token'] as String?;
        if (token == null || token.isEmpty) return false;
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
      unawaited(_tentarAutenticarBackend());
    }
  }

  Future<void> configurarPin(String pin) async {
    await _encryptionService.configurarPin(pin);
    _desbloqueado = true;
    unawaited(_tentarAutenticarBackend());
  }

  Future<String> configurarPinComFraseRecuperacao(String pin) async {
    await _encryptionService.configurarPin(pin);
    final frase = _encryptionService.gerarFraseRecuperacao();
    await _encryptionService.configurarFraseRecuperacao(frase);
    _desbloqueado = true;
    unawaited(_tentarAutenticarBackend());
    return frase;
  }

  bool get possuiFraseRecuperacao => _encryptionService.possuiFraseRecuperacao;

  bool verificarFraseRecuperacao(String frase) =>
      _encryptionService.verificarFraseRecuperacao(frase);

  Future<bool> recuperarComFrase(String frase) async {
    final sucesso = await _encryptionService.recuperarComFrase(frase);
    if (sucesso) {
      _desbloqueado = true;
      await _encryptionService.limparRecuperacao();
    }
    return sucesso;
  }

  Future<void> _tentarAutenticarBackend() async {
    try {
      await autenticarBackend();
    } catch (e) {
      Log.erro(e, contexto: 'AuthService._tentarAutenticarBackend');
    }
  }

  bool get requerPin => _encryptionService.possuiPinConfigurado;

  Future<void> bloquear() async {
    _desbloqueado = false;
  }

  Future<bool> trocarPin(String pinAtual, String novoPin) async {
    final sucesso = await _encryptionService.trocarPin(pinAtual, novoPin);
    if (sucesso) {
      _desbloqueado = true;
    }
    return sucesso;
  }

  Future<void> removerPin() async {
    await _pacienteService?.removerCriptografiaExistente();
    await _sessaoService?.removerCriptografiaExistente();
    await _perfilProfissionalService?.removerCriptografiaExistente();
    await _encryptionService.limpar();
    _desbloqueado = false;
  }
}
