import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:hive_ce/hive.dart';
import 'package:local_auth/local_auth.dart';

import 'logger.dart';
import 'api_client.dart';
import 'encryption_service.dart';
import 'paciente_service.dart';
import 'sessao_service.dart';
import 'perfil_profissional_service.dart';
import 'avaliacao_inicial_service.dart';
import 'escala_service.dart';
import 'contrato_service.dart';
import 'anamnese_enviada_service.dart';
import 'compromisso_service.dart';
import 'progresso_service.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const String _authBoxName = 'auth_meta';
  static const String _tokenKey = 'jwt_token';
  static const String _usernameKey = 'auth_username';
  static const String _passwordKey = 'auth_password';

  late final Box<String> _box = Hive.box<String>(_authBoxName);
  final LocalAuthentication _localAuth = LocalAuthentication();

  final EncryptionService _encryptionService;
  final PacienteService? _pacienteService;
  final SessaoService? _sessaoService;
  final PerfilProfissionalService? _perfilProfissionalService;
  final AvaliacaoInicialService? _avaliacaoInicialService;
  final EscalaService? _escalaService;
  final ContratoService? _contratoService;
  final AnamneseEnviadaService? _anamneseEnviadaService;
  final CompromissoService? _compromissoService;
  final ProgressoService? _progressoService;
  bool _desbloqueado = false;

  AuthService(
    this._encryptionService, {
    PacienteService? pacienteService,
    SessaoService? sessaoService,
    PerfilProfissionalService? perfilProfissionalService,
    AvaliacaoInicialService? avaliacaoInicialService,
    EscalaService? escalaService,
    ContratoService? contratoService,
    AnamneseEnviadaService? anamneseEnviadaService,
    CompromissoService? compromissoService,
    ProgressoService? progressoService,
  })  : _pacienteService = pacienteService,
        _sessaoService = sessaoService,
        _perfilProfissionalService = perfilProfissionalService,
        _avaliacaoInicialService = avaliacaoInicialService,
        _escalaService = escalaService,
        _contratoService = contratoService,
        _anamneseEnviadaService = anamneseEnviadaService,
        _compromissoService = compromissoService,
        _progressoService = progressoService;

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
    unawaited(_tentarAutenticarBackend());
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
      final username = _username;
      final password = _password;
      if (username.isEmpty || password.isEmpty) {
        await ApiClient.setCredentials('admin', 'admin');
      }
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

  Future<bool> desbloquearComPin(String pin) async {
    final sucesso = await _encryptionService.desbloquear(pin);
    if (sucesso) {
      _desbloqueado = true;
      unawaited(_encryptionService.salvarChaveNoSecureStorage());
      unawaited(_tentarAutenticarBackend());
    }
    return sucesso;
  }

  Future<void> configurarPin(String pin, {String? email}) async {
    await _encryptionService.configurarPin(pin);
    _desbloqueado = true;
    unawaited(_encryptionService.salvarChaveNoSecureStorage());
    if (email != null && email.isNotEmpty) {
      await _configurarRecuperacao(email);
    }
    unawaited(_tentarAutenticarBackend());
  }

  Future<void> _configurarRecuperacao(String email) async {
    final recoveryToken = _gerarRecoveryToken();
    await _encryptionService.configurarRecuperacaoEmail(recoveryToken);
    await ApiClient.registrarRecuperacao(email, recoveryToken);
  }

  String _gerarRecoveryToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  bool get possuiRecuperacaoConfigurada =>
      _encryptionService.possuiRecuperacaoConfigurada;

  Future<bool> validarPin(String pin) => _encryptionService.validarPin(pin);

  int get tentativasRestantes => _encryptionService.tentativasRestantes;

  Future<bool> solicitarCodigoRecuperacao(String email) async {
    return ApiClient.solicitarCodigoRecuperacao(email);
  }

  Future<String?> verificarCodigoRecuperacao(String email, String codigo) async {
    return ApiClient.verificarCodigoRecuperacao(email, codigo);
  }

  Future<bool> redefinirPinComRecuperacao(String recoveryToken, String novoPin) async {
    final sucesso = await _encryptionService.recuperarComToken(recoveryToken);
    if (!sucesso) return false;

    await _encryptionService.reprotegerChaveComNovoPin(novoPin);
    _desbloqueado = true;
    await _encryptionService.salvarChaveNoSecureStorage();
    return true;
  }

  Future<bool> autenticarComBiometria() async {
    try {
      final podeAutenticar = await _localAuth.canCheckBiometrics;
      if (!podeAutenticar) return false;

      final autenticado = await _localAuth.authenticate(
        localizedReason: 'Autentique-se para acessar o prontuario',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (!autenticado) return false;

      final sucesso = await _encryptionService.recuperarChaveDoSecureStorage();
      if (sucesso) {
        _desbloqueado = true;
        unawaited(_tentarAutenticarBackend());
      }
      return sucesso;
    } on PlatformException catch (e) {
      if (e.code == 'NotAvailable') return false;
      Log.erro(e, contexto: 'AuthService.autenticarComBiometria');
      return false;
    } catch (e) {
      Log.erro(e, contexto: 'AuthService.autenticarComBiometria');
      return false;
    }
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
    ApiClient.authToken = null;
    try {
      await Hive.box<String>('auth_meta').delete('jwt_token');
    } catch (_) {}
  }

  Future<bool> trocarPin(String pinAtual, String novoPin) async {
    final sucesso = await _encryptionService.trocarPin(pinAtual, novoPin);
    if (sucesso) {
      _desbloqueado = true;
      await _encryptionService.salvarChaveNoSecureStorage();
    }
    return sucesso;
  }

  Future<void> removerPin() async {
    await _pacienteService?.removerCriptografiaExistente();
    await _sessaoService?.removerCriptografiaExistente();
    await _perfilProfissionalService?.removerCriptografiaExistente();
    await _avaliacaoInicialService?.removerCriptografiaExistente();
    await _escalaService?.removerCriptografiaExistente();
    await _contratoService?.removerCriptografiaExistente();
    await _anamneseEnviadaService?.removerCriptografiaExistente();
    await _compromissoService?.removerCriptografiaExistente();
    await _progressoService?.removerCriptografiaExistente();
    await _encryptionService.limpar();
    _desbloqueado = false;
    ApiClient.authToken = null;
    try {
      await Hive.box<String>('auth_meta').delete('jwt_token');
    } catch (_) {}
  }
}
