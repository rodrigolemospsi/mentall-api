import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce/hive.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

import 'logger.dart';
import 'api_client.dart';
import 'audio_relato_service.dart';
import 'encryption_service.dart';
import 'package:http/http.dart' as http;

/// Abstração mínima do gate de autenticação local do aparelho (biometria ou
/// credencial do dispositivo). Permite testar o fluxo de desbloqueio sem o
/// platform channel do plugin [LocalAuthentication].
abstract class GateDeAutenticacao {
  Future<bool> suportaGate();
  Future<bool> autenticar();
}

/// Mensagens do diálogo nativo de autenticação (Android).
///
/// Sem isto, o plugin `local_auth_android` usa os defaults em inglês
/// ("Authentication required" / "Verify identity"). O subtítulo fica vazio de
/// propósito — a descrição (`localizedReason`) já orienta o usuário.
const mensagensBiometria = AndroidAuthMessages(
  signInTitle: 'Acesso com biometria',
  signInHint: '',
  cancelButton: 'Cancelar',
);

/// Implementação real: delega ao pacote `local_auth`.
class _LocalAuthGate implements GateDeAutenticacao {
  final LocalAuthentication _localAuth;
  _LocalAuthGate(this._localAuth);

  @override
  Future<bool> suportaGate() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> autenticar() async {
    return _localAuth.authenticate(
      localizedReason: 'Autentique-se para acessar o MentAll.',
      authMessages: const [mensagensBiometria],
      persistAcrossBackgrounding: true,
    );
  }
}

class AuthService {
  static const String _authBoxName = 'auth_meta';
  static const String _tokenKey = 'jwt_token';
  static const String _biometriaAtivadaKey = 'biometria_ativada';

  // SecureStorage keys for server credentials (protected by device PIN/biometrics)
  static const String _serverUserKey = 'server_username';
  static const String _serverPassKey = 'server_password';

  late final Box<String> _box = Hive.box<String>(_authBoxName);
  final LocalAuthentication _localAuth;
  late final GateDeAutenticacao _gate;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final EncryptionService _encryptionService;
  bool _desbloqueado = false;

  /// Indica que o último desbloqueio caiu no fail-safe (aparelho sem
  /// biometria/credencial ou gate indisponível), ou seja, o acesso NÃO foi
  /// protegido por prompt. A UI deve avisar o usuário ("avise e permita").
  bool _ultimoAcessoFailSafe = false;
  bool get ultimoAcessoFailSafe => _ultimoAcessoFailSafe;

  AuthService(this._encryptionService, {GateDeAutenticacao? gate})
      : _localAuth = LocalAuthentication() {
    _gate = gate ?? _LocalAuthGate(_localAuth);
  }

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

  /// Indica se o usuário ativou "Desbloquear com digital / face" em
  /// Configurações (chave `biometria_ativada`, padrão `true`).
  bool get biometriaAtivada {
    try {
      return Hive.box<String>('app_config')
              .get(_biometriaAtivadaKey, defaultValue: 'true') ==
          'true';
    } catch (_) {
      return true; // Padrão seguro: exige gate quando o aparelho suportar.
    }
  }

  /// Desbloqueia o app.
  ///
  /// - Se o usuário ativou o desbloqueio por biometria/face E o aparelho
  ///   oferece o gate (biometria ou credencial do dispositivo), EXIGE o prompt
  ///   do sistema antes de carregar a chave — nunca burla um cancelamento do
  ///   usuário (retorna `false` para exibir erro e permitir retentar).
  /// - Se o gate não está disponível (aparelho sem biometria/tela bloqueada,
  ///   biometria invalidada/hardware fora, ou a opção desligada), cai no cofre
  ///   durável como fail-safe — preserva o fix de lockout do 03/09 (nunca trava).
  Future<bool> desbloquearComBiometria() async {
    try {
      if (biometriaAtivada) {
        final temGate = await _gate.suportaGate();
        if (temGate) {
          final autenticou = await _gate.autenticar();
          if (!autenticou) {
            // Usuário cancelou ou falhou o prompt: honra o gate (não burla).
            return false;
          }
          _ultimoAcessoFailSafe = false;
        } else {
          // Aparelho sem biometria/credencial: avisa e permite.
          _ultimoAcessoFailSafe = true;
        }
      }
      return await _carregarChave();
    } on LocalAuthException catch (e) {
      if (_ehIndisponibilidade(e.code)) {
        // Gate indisponível (sem credencial, hardware fora, biocripto
        // bloqueado): avisa e permite (fail-safe).
        _ultimoAcessoFailSafe = true;
        return await _carregarChave();
      }
      Log.erro(e, contexto: 'AuthService.desbloquearComBiometria');
      return false;
    } catch (e) {
      Log.erro(e, contexto: 'AuthService.desbloquearComBiometria');
      return false;
    }
  }

  Future<bool> _carregarChave() async {
    try {
      final sucesso = await _encryptionService.carregarChaveDoSecureStorage();
      if (sucesso) {
        _desbloqueado = true;
      }
      return sucesso;
    } catch (e) {
      Log.erro(e, contexto: 'AuthService.desbloquearComBiometria');
      return false;
    }
  }

  bool _ehIndisponibilidade(LocalAuthExceptionCode code) {
    const indisponiveis = {
      LocalAuthExceptionCode.noCredentialsSet,
      LocalAuthExceptionCode.noBiometricsEnrolled,
      LocalAuthExceptionCode.noBiometricHardware,
      LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable,
      LocalAuthExceptionCode.biometricLockout,
      LocalAuthExceptionCode.temporaryLockout,
      LocalAuthExceptionCode.deviceError,
      LocalAuthExceptionCode.uiUnavailable,
      LocalAuthExceptionCode.unknownError,
    };
    return indisponiveis.contains(code);
  }

  Future<bool> gerarChave() async {
    final sucesso = await _encryptionService.gerarChave();
    // NÃO marca como desbloqueado: o gate de segurança deve ser exigido na
    // primeira abertura (antes, o boot pulava o login por completo).
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
    // Remove áudios clínicos descriptografados do cache em memória. Os
    // temporários de playback ficam no diretório temporário do sistema (o S.O.
    // os limpa) e NÃO são apagados aqui para não romper um player que ainda
    // possa estar lendo um arquivo ativo.
    AudioRelatoService.limparCacheAudio();
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

  /// Restabelece a sessão do servidor após o desbloqueio local.
  ///
  /// Tenta o cofre do sistema (SecureStorage) e, se não houver credencial lá,
  /// cai no [ApiClient.forceReauthenticate] (app_config/memória/cofre durável).
  /// Assim o JWT é obtido UMA vez após o desbloqueio, em vez de depender de
  /// reautenticação no meio de cada operação — que falhava com
  /// "Não foi possível autenticar com o servidor".
  Future<bool> estabelecerSessaoServidor() async {
    if (await tentarAutoLoginServidor()) return true;
    return ApiClient.forceReauthenticate();
  }
}
