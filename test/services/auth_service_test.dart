import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:local_auth/local_auth.dart';

import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/services/api_client.dart';
import 'package:prontuario_tcc/services/auth_service.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';

void main() {
  late EncryptionService encryption;

  setUpAll(() async {
    Hive.init('test/temp_hive/auth_service');
    Hive.registerAdapters();
    await Hive.openBox<String>('app_config');
    await Hive.openBox<String>('auth_meta');
    await Hive.openBox<String>('encryption_meta');
  });

  tearDownAll(() async {
    await Hive.box<String>('app_config').close();
    await Hive.box<String>('auth_meta').close();
    await Hive.box<String>('encryption_meta').close();
    await Hive.deleteBoxFromDisk('app_config');
    await Hive.deleteBoxFromDisk('auth_meta');
    await Hive.deleteBoxFromDisk('encryption_meta');
  });

  setUp(() async {
    await Hive.box<String>('app_config').clear();
    await Hive.box<String>('auth_meta').clear();
    await Hive.box<String>('encryption_meta').clear();
    encryption = EncryptionService();
    EncryptionService.setInstance(encryption);
  });

  test('autenticarBackend nao persiste JWT em texto puro sem criptografia',
      () async {
    final auth = AuthService(encryption);
    await ApiClient.setCredentials(
      'fulano@exemplo.com',
      'senha-forte',
    );

    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({'access_token': 'jwt-token-de-teste'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final ok = await auth.autenticarBackend(client: mockClient);
    expect(ok, isTrue);

    final armazenado = Hive.box<String>('auth_meta').get('jwt_token');
    expect(armazenado, isNull,
        reason: 'sem criptografia, o JWT nao pode ser persistido em claro');
  });

  group('desbloquearComBiometria — gate de biometria/credencial', () {
    test('exige o gate quando ativado e suportado, e autenticou', () async {
      await Hive.box<String>('app_config').put('biometria_ativada', 'true');
      final gate = _FakeGate()..suporta = true..autenticou = true;
      final auth = AuthService(_encComChave(), gate: gate);

      final ok = await auth.desbloquearComBiometria();

      expect(ok, isTrue);
      expect(gate.autenticarChamado, isTrue,
          reason: 'com a opcao ligada, deve apresentar o prompt de verdade');
      expect(auth.desbloqueado, isTrue);
      expect(auth.ultimoAcessoFailSafe, isFalse,
          reason: 'autenticou de verdade: nao deve avisar fail-safe');
    });

    test('nao desbloqueia quando o usuario cancela/falha o prompt', () async {
      await Hive.box<String>('app_config').put('biometria_ativada', 'true');
      final gate = _FakeGate()..suporta = true..autenticou = false;
      final auth = AuthService(_encComChave(), gate: gate);

      final ok = await auth.desbloquearComBiometria();

      expect(ok, isFalse);
      expect(auth.desbloqueado, isFalse,
          reason: 'cancelar o prompt nao pode burlar o gate');
    });

    test('nao desbloqueia quando o erro do gate nao e de indisponibilidade',
        () async {
      await Hive.box<String>('app_config').put('biometria_ativada', 'true');
      final gate = _FakeGate()
        ..suporta = true
        ..erro = const LocalAuthException(code: LocalAuthExceptionCode.userCanceled);
      final auth = AuthService(_encComChave(), gate: gate);

      final ok = await auth.desbloquearComBiometria();

      expect(ok, isFalse);
      expect(auth.desbloqueado, isFalse);
    });

    test('erro de indisponibilidade do gate cai no cofre duravel (fail-safe)',
        () async {
      await Hive.box<String>('app_config').put('biometria_ativada', 'true');
      final gate = _FakeGate()
        ..suporta = true
        ..erro = const LocalAuthException(
            code: LocalAuthExceptionCode.noBiometricsEnrolled);
      final auth = AuthService(_encComChave(), gate: gate);

      final ok = await auth.desbloquearComBiometria();

      expect(ok, isTrue,
          reason:
              'gate indisponivel deve desbloquear pelo cofre duravel, sem travar');
      expect(auth.desbloqueado, isTrue);
    });

    test('desbloqueio silencioso quando a opcao esta desligada (nao chama o gate)',
        () async {
      await Hive.box<String>('app_config').put('biometria_ativada', 'false');
      final gate = _FakeGate()..suporta = true..autenticou = false;
      final auth = AuthService(_encComChave(), gate: gate);

      final ok = await auth.desbloquearComBiometria();

      expect(ok, isTrue);
      expect(gate.autenticarChamado, isFalse,
          reason: 'com a opcao desligada, nao deve apresentar prompt');
      expect(auth.desbloqueado, isTrue);
    });

    test('fail-safe silencioso quando o aparelho nao suporta o gate', () async {
      await Hive.box<String>('app_config').put('biometria_ativada', 'true');
      final gate = _FakeGate()..suporta = false;
      final auth = AuthService(_encComChave(), gate: gate);

      final ok = await auth.desbloquearComBiometria();

      expect(ok, isTrue);
      expect(gate.autenticarChamado, isFalse,
          reason: 'sem gate disponivel, deve usar o cofre duravel (fail-safe)');
      expect(auth.desbloqueado, isTrue);
      expect(auth.ultimoAcessoFailSafe, isTrue,
          reason: 'sem gate, a UI deve avisar que o acesso nao foi protegido');
    });

    test('gerarChave nao marca como desbloqueado (gate exigido no boot)',
        () async {
      await Hive.box<String>('app_config').put('biometria_ativada', 'true');
      final auth = AuthService(_encComChave(), gate: _FakeGate());

      await auth.gerarChave();

      expect(auth.desbloqueado, isFalse,
          reason: 'o boot nao pode pular o gate de seguranca');
    });
  });
}

/// Cria um [EncryptionService] com a chave já no cofre durável, para que a
/// leitura da chave tenha sucesso nos testes de desbloqueio.
EncryptionService _encComChave() {
  return EncryptionService(
    pin: _MemStorage(),
    duravel: _MemStorage()..data['aes_master_key_duravel'] = chaveBase64,
  );
}

const chaveBase64 = 'MTIzNDU2Nzg5MDEyMzQ1Njc4OTA=';

/// Fake do [GateDeAutenticacao] para controlar o suporte e o resultado do
/// prompt sem o platform channel do dispositivo.
class _FakeGate extends GateDeAutenticacao {
  bool suporta = true;
  bool autenticou = true;
  LocalAuthException? erro;
  bool autenticarChamado = false;

  @override
  Future<bool> suportaGate() async => suporta;

  @override
  Future<bool> autenticar() async {
    autenticarChamado = true;
    if (erro != null) throw erro!;
    return autenticou;
  }
}

/// Implementação em memória do secure storage (sem o platform channel real).
class _MemStorage extends FlutterSecureStorage {
  final Map<String, String> data = {};
  bool throwOnRead = false;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (throwOnRead) throw Exception('autenticacao falhou');
    return data[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.remove(key);
  }
}
