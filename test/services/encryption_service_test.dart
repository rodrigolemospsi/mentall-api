import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';

void main() {
  late EncryptionService encryption;

  setUpAll(() async {
    Hive.init('test/temp_hive/encryption_pin');
    Hive.registerAdapters();
    await Hive.openBox<String>('encryption_meta');
  });

  tearDownAll(() async {
    await Hive.deleteBoxFromDisk('encryption_meta');
  });

  setUp(() async {
    await Hive.box<String>('encryption_meta').clear();
    encryption = EncryptionService();
    await encryption.inicializar();
  });

  test('validarPin rejeita PIN quando nao ha chave protegida por PIN legado', () async {
    await encryption.gerarChave();
    // Com a chave em memoria mas sem encrypted_key legado, qualquer PIN deve falhar.
    expect(await encryption.validarPin('1234'), isFalse);
    expect(await encryption.validarPin('000000'), isFalse);
  });

  test('validarPin nao aceita PIN qualquer apenas por a chave estar em memoria', () async {
    await encryption.gerarChave();
    // Garante que a chave esta em memoria (configurado == true)
    expect(encryption.configurado, isTrue);
    // Mesmo assim, sem PIN legado registrado, validarPin deve falhar
    // (bug corrigido: antes retornava true incondicionalmente quando _key != null).
    expect(await encryption.validarPin('senha-qualquer'), isFalse);
  });

  test('protecaoDuravel inicia false sem chave persistida de forma duravel', () {
    expect(encryption.protecaoDuravel, isFalse);
  });

  test('gerarChave falha (retorna false) sem persistencia duravel, sinal de fail-closed',
      () async {
    // Em ambiente sem secure storage de plataforma, a persistencia dura ta
    // indisponivel. gerarChave nao deve reportar durabilidade (retorna false),
    // permitindo que o fluxo de boot bloqueie em vez de gravar texto puro.
    final ok = await encryption.gerarChave();
    expect(ok, isFalse);
    expect(encryption.protecaoDuravel, isFalse);
  });

  test('protecaoDuravel reflete marcador de persistencia duravel', () {
    // Quando a persistencia duravel foi confirmada, o getter reflete true.
    Hive.box<String>('encryption_meta').put('chave_duravel', 'true');
    expect(encryption.protecaoDuravel, isTrue);
  });

  test('carregarChave usa a chave do gate e faz backfill no cofre duravel', () async {
    final pin = _MemStorage();
    final duravel = _MemStorage();
    pin.data['aes_master_key'] = chaveBase64;
    final enc = EncryptionService(pin: pin, duravel: duravel);
    await enc.inicializar();

    expect(await enc.carregarChaveDoSecureStorage(), isTrue);
    expect(enc.configurado, isTrue);
    // Backfill: a chave deve ser copiada para o cofre durável.
    expect(duravel.data['aes_master_key_duravel'], chaveBase64);
    expect(enc.protecaoDuravel, isTrue);
  });

  test('carregarChave usa cofre duravel quando o gate esta vazio', () async {
    final pin = _MemStorage();
    final duravel = _MemStorage();
    duravel.data['aes_master_key_duravel'] = chaveBase64;
    final enc = EncryptionService(pin: pin, duravel: duravel);
    await enc.inicializar();

    expect(await enc.carregarChaveDoSecureStorage(), isTrue);
    expect(enc.configurado, isTrue);
  });

  test('carregarChave cai no duravel quando o gate lanca erro', () async {
    final pin = _MemStorage()..throwOnRead = true;
    final duravel = _MemStorage();
    duravel.data['aes_master_key_duravel'] = chaveBase64;
    final enc = EncryptionService(pin: pin, duravel: duravel);
    await enc.inicializar();

    expect(await enc.carregarChaveDoSecureStorage(), isTrue);
  });

  test('carregarChave retorna false sem lancar quando ambos os cofres estao vazios',
      () async {
    final enc = EncryptionService(
      pin: _MemStorage(),
      duravel: _MemStorage(),
    );
    await enc.inicializar();

    expect(await enc.carregarChaveDoSecureStorage(), isFalse);
  });

  test('marcarProtecaoDuravel popula o cofre duravel a partir da chave do gate',
      () async {
    // Instalação "legada" (upgrade de APK): chave existe apenas no gate de
    // biometria/credencial, e o cofre durável ainda está vazio. A migração
    // deve copiar a chave para o cofre durável para o desbloqueio não
    // depender do gate (bug: antes só gravava o marcador chave_duravel).
    final pin = _MemStorage();
    final duravel = _MemStorage();
    pin.data['aes_master_key'] = chaveBase64;
    final enc = EncryptionService(pin: pin, duravel: duravel);
    await enc.inicializar();

    await enc.marcarProtecaoDuravel();

    expect(duravel.data['aes_master_key_duravel'], chaveBase64);
    expect(enc.protecaoDuravel, isTrue);
  });

  test('marcarProtecaoDuravel nao falha quando o gate nao tem chave', () async {
    final enc = EncryptionService(
      pin: _MemStorage(),
      duravel: _MemStorage(),
    );
    await enc.inicializar();

    await enc.marcarProtecaoDuravel();

    expect(enc.protecaoDuravel, isTrue);
  });
}

const chaveBase64 = 'MTIzNDU2Nzg5MDEyMzQ1Njc4OTA=';

/// Implementação em memória do secure storage, para testar a lógica sem o
/// platform channel do dispositivo.
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
