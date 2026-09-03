import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce/hive.dart';
import 'package:pointycastle/export.dart';

import 'logger.dart';

Uint8List _derivarPbkdf2Sync(String pin, String saltBase64, int iterations, int keyLength) {
  final saltBytes = base64Decode(saltBase64);
  final derivator = KeyDerivator('SHA-256/HMAC/PBKDF2');
  derivator.init(Pbkdf2Parameters(saltBytes, iterations, keyLength));
  final derived = derivator.process(utf8.encode(pin));
  return Uint8List.fromList(derived);
}

Future<Uint8List> _executarPbkdf2Isolate(
  String pin,
  String saltBase64,
  int iterations,
  int keyLength,
) {
  return Isolate.run(() => _derivarPbkdf2Sync(pin, saltBase64, iterations, keyLength));
}

class EncryptionService {
  static const String _boxName = 'encryption_meta';
  static const String _encryptedKeyKey = 'encrypted_key';
  static const String _ivKey = 'iv_base64';
  static const String _chaveGeradaKey = 'chave_gerada';
  static const String _pinAttemptsKey = 'pin_attempts';
  static const String _pinLockedUntilKey = 'pin_locked_until';
  static const int _kdfIterations = 10000;
  static const int _kdfIterationsV3 = 100000;
  static const int _kdfKeyLength = 32;
  static const int _maxPinAttempts = 5;
  static const List<int> _backoffSeconds = [1, 2, 4, 8, 16, 32, 60];

  static const _secureKeyName = 'aes_master_key';
  static const _secureKeyDuravel = 'aes_master_key_duravel';
  static const _chaveDuravelKey = 'chave_duravel';

  /// Cofre durável (Android Keystore RSA OAEP + AES-GCM / iOS Keychain) que
  /// NÃO exige biometria/tela bloqueada. É a persistência OBRIGATÓRIA da chave
  /// mestra: garante que os dados clínicos sejam sempre cifrados, mesmo em um
  /// dispositivo sem bloqueio configurado (correção da falha fail-open da
  /// vuln-0013). A biometria/credencial permanece como um GATE de acesso
  /// opcional (ver [carregarChaveDoSecureStorage]), não como pré-requisito.
  final FlutterSecureStorage _pin;
  final FlutterSecureStorage _duravel;

  /// Permite injetar as implementações de storage em testes. Por padrão usa os
  /// cofres reais do sistema (Android Keystore / iOS Keychain).
  EncryptionService({
    FlutterSecureStorage? pin,
    FlutterSecureStorage? duravel,
  })  : _pin = pin ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions.biometric(
                enforceBiometrics: true,
                biometricType: AndroidBiometricType.biometricOrDeviceCredential,
                biometricPromptTitle: 'Acesso com PIN',
                biometricPromptSubtitle: 'Digite o PIN do dispositivo',
              ),
            ),
        _duravel = duravel ?? const FlutterSecureStorage(aOptions: AndroidOptions());

  late final Box<String> _box = Hive.box<String>(_boxName);
  encrypt.Key? _key;
  encrypt.IV? _iv;

  encrypt.Encrypter? _encrypterGcm;
  encrypt.Encrypter? _encrypterCbc;

  void _limparCacheCripto() {
    _encrypterGcm = null;
    _encrypterCbc = null;
  }

  void _setKey(encrypt.Key key) {
    _key = key;
    _limparCacheCripto();
  }

  encrypt.Encrypter get _gcm => _encrypterGcm ??= encrypt.Encrypter(encrypt.AES(_key!, mode: encrypt.AESMode.gcm));
  encrypt.Encrypter get _cbc => _encrypterCbc ??= encrypt.Encrypter(encrypt.AES(_key!));

  bool _inicializado = false;

  static EncryptionService? _instance;

  /// Sinal de fail-closed definido no boot (`main.dart`): quando a chave
  /// mestra não pôde ser persistida de forma durável, o app deve bloquear em
  /// vez de gravar dados clínicos em texto puro.
  static bool protecaoIndisponivel = false;

  static void setInstance(EncryptionService instance) {
    _instance = instance;
  }

  static String? tryEncrypt(String texto) {
    if (_instance == null || texto.isEmpty || !_instance!.configurado) return null;
    try {
      return _instance!.criptografar(texto);
    } catch (_) {
      return null;
    }
  }

  static String tryDecrypt(String texto) {
    if (_instance == null || texto.isEmpty) return texto;
    if (!_instance!.configurado) return texto;
    return _instance!.descriptografar(texto);
  }

  /// Cabeçalho mágico do formato binário de áudio criptografado ("MAV1").
  static const List<int> _magicAudio = [0x4D, 0x41, 0x56, 0x31];

  static bool _ehFormatoBinario(Uint8List bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == _magicAudio[0] &&
        bytes[1] == _magicAudio[1] &&
        bytes[2] == _magicAudio[2] &&
        bytes[3] == _magicAudio[3];
  }

  /// Criptografa bytes crus (sem base64) com AES-GCM em isolate.
  ///
  /// Retorna `[MAV1][nonce 12 bytes][ciphertext]` ou `null` se a chave não
  /// estiver configurada (sem PIN).
  static Future<Uint8List?> criptografarBytes(Uint8List dados) async {
    final instance = _instance;
    if (instance == null || !instance.configurado || dados.isEmpty) return null;
    final chave = instance.chaveBytes;
    if (chave == null) return null;
    final nonce = encrypt.IV.fromSecureRandom(12);
    final nonceBytes = Uint8List.fromList(nonce.bytes);
    try {
      final cifrado = await Isolate.run(
        () => _criptografarBytesGcm(chave, nonceBytes, dados),
      );
      final builder = BytesBuilder();
      builder.add(_magicAudio);
      builder.add(nonceBytes);
      builder.add(cifrado);
      return builder.toBytes();
    } catch (e) {
      Log.erro(e, contexto: 'EncryptionService.criptografarBytes');
      return null;
    }
  }

  /// Descriptografa bytes no formato `[MAV1][nonce][ciphertext]` em isolate.
  ///
  /// Retorna os bytes originais ou `null` se a chave não estiver configurada
  /// ou o formato for inválido.
  static Future<Uint8List?> descriptografarBytes(Uint8List arquivo) async {
    final instance = _instance;
    if (instance == null || !instance.configurado) return null;
    final chave = instance.chaveBytes;
    if (chave == null) return null;
    if (!_ehFormatoBinario(arquivo) || arquivo.length < 16) return null;
    final nonceBytes = arquivo.sublist(4, 16);
    final cifrado = arquivo.sublist(16);
    try {
      return await Isolate.run(
        () => _descriptografarBytesGcm(chave, nonceBytes, cifrado),
      );
    } catch (e) {
      Log.erro(e, contexto: 'EncryptionService.descriptografarBytes');
      return null;
    }
  }

  bool get configurado => _inicializado && _key != null;

  Uint8List? get chaveBytes => _key?.bytes;

  Future<void> inicializar() async {
    if (_inicializado) return;
    _inicializado = true;
  }

  bool get possuiChaveProtegida {
    if (_key != null) return true;
    try {
      return _box.get(_chaveGeradaKey) != null || _box.get(_encryptedKeyKey) != null;
    } catch (_) {
      return false;
    }
  }

  bool get possuiPinLegado {
    try {
      return _box.get(_encryptedKeyKey) != null;
    } catch (_) {
      return false;
    }
  }

  /// Indica se a chave mestra está persistida de forma durável (cofre de
  /// hardware sem exigir biometria/tela bloqueada). Se false, os dados podem
  /// ser gravados em texto puro — o fluxo de boot deve bloquear (fail-closed).
  bool get protecaoDuravel {
    try {
      return _box.get(_chaveDuravelKey) == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Propaga o marcador de persistência durável para instalações antigas que
  /// já possuem uma chave (ex.: cofre protegido por biometria/tela bloqueada).
  /// Evita falso fail-closed em upgrades de versões anteriores à vuln-0013.
  ///
  /// Além do marcador, faz a MIGRAÇÃO BEM-SUCEDIDA da chave para o cofre
  /// durável. Bug corrigido: antes só gravava o marcador `chave_duravel`,
  /// deixando o cofre durável vazio — o desbloqueio ficava dependente do gate
  /// de biometria/credencial, que ao falhar (biometria indisponível ou
  /// invalidada) produzia "Não foi possível autenticar" ao voltar ao app.
  Future<void> marcarProtecaoDuravel() async {
    try {
      await _box.put(_chaveDuravelKey, 'true');
    } catch (_) {
      // Melhor esforço.
    }
    if (_key == null) {
      try {
        await carregarChaveDoSecureStorage();
      } catch (_) {
        // Melhor esforço; a chave pode estar inacessível agora (ex.: sem
        // biometria/credencial configurada) e ser recuperada depois.
      }
    }
  }

  /// Observa mudanças no cofre de metadados (usado por providers reativos).
  Stream<BoxEvent> observar() => _box.watch();

  Future<bool> gerarChave() async {
    await inicializar();

    final newKey = encrypt.Key.fromSecureRandom(32);
    final newIv = encrypt.IV.fromSecureRandom(16);
    _setKey(newKey);
    _iv = newIv;

    // 1) Persistência durável (OBRIGATÓRIA). Usa o cofre de hardware SEM
    //    exigir biometria/tela bloqueada, então funciona em qualquer aparelho.
    //    Só grava texto puro se nem isso for possível (fail-closed no boot).
    var duravel = false;
    try {
      await _duravel.write(
        key: _secureKeyDuravel,
        value: newKey.base64,
      );
      duravel = true;
    } catch (_) {
      // Keystore/Keychain indisponível (raro): chave fica só em memória.
    }

    // 2) Gate opcional por biometria/credencial do dispositivo (UX de acesso).
    //    Se existir, a chave também fica nesse cofre (que exige o prompt);
    //    se não, o desbloqueio usa a cópia durável. Nunca é pré-requisito.
    try {
      await _pin.write(key: _secureKeyName, value: newKey.base64);
    } catch (_) {
      // Sem biometria/tela bloqueada -> seguimos com a cópia durável.
    }

    if (!duravel) {
      return false;
    }
    try {
      await _box.put(_chaveGeradaKey, 'true');
      await _box.put(_chaveDuravelKey, 'true');
    } catch (_) {
      // A flag é apenas otimização de detecção; a chave em memória é o que importa.
    }
    return true;
  }

  Future<bool> carregarChaveDoSecureStorage() async {
    await inicializar();

    // 1º passo: cofre durável (fonte primária, sem exigir biometria/tela).
    // GARANTE o desbloqueio mesmo quando o gate de biometria/credencial está
    // indisponível ou foi invalidado (causa do "Não foi possível autenticar").
    String? chave;
    try {
      final keyBase64 = await _duravel.read(key: _secureKeyDuravel);
      if (keyBase64 != null && keyBase64.isNotEmpty) {
        chave = keyBase64;
      }
    } catch (_) {
      // Keystore indisponível -> tentamos o gate.
    }

    // 2º passo: gate de credencial/biometria do dispositivo (instalações
    // antigas cuja chave só existe no cofre protegido).
    if (chave == null) {
      try {
        final keyBase64 = await _pin.read(key: _secureKeyName);
        if (keyBase64 != null && keyBase64.isNotEmpty) {
          chave = keyBase64;
        }
      } catch (_) {
        // Sem biometria/credencial -> só resta o cofre durável.
      }
    }

    if (chave == null) {
      return false;
    }

    _setKey(encrypt.Key.fromBase64(chave));
    _resetarTentativas();

    // Backfill: garante que o cofre durável sempre tenha a chave (migração de
    // instalações antigas), evitando futuro travamento por biometria/keystore.
    try {
      await _duravel.write(key: _secureKeyDuravel, value: chave);
      await _box.put(_chaveDuravelKey, 'true');
    } catch (_) {
      // Melhor esforço; a chave já foi carregada em memória.
    }

    return true;
  }

  Future<bool> migrarChaveDoPinLegado(String pin) async {
    await inicializar();
    _verificarLockoutOuLancar();

    if (_key != null) return true;

    final encryptedData = _box.get(_encryptedKeyKey);
    final ivBase64 = _box.get(_ivKey);

    if (encryptedData == null || ivBase64 == null) return false;

    final keyParts = encryptedData.split(':');
    if (keyParts.length < 2) return false;

    final keySalt = keyParts[0];
    final encryptedPart = keyParts.sublist(1).join(':');

    final kdfVersion = int.tryParse(_box.get('kdf_version') ?? '1') ?? 1;
    final iterations = kdfVersion >= 3 ? _kdfIterationsV3 : _kdfIterations;

    try {
      final derivedKeyBytes = await _executarPbkdf2Isolate(
        pin,
        keySalt,
        iterations,
        _kdfKeyLength,
      );

      final ivBytes = base64Decode(ivBase64);
      final iv = encrypt.IV(Uint8List.fromList(ivBytes));
      final derivedKey = encrypt.Key(derivedKeyBytes);
      final encrypter = encrypt.Encrypter(encrypt.AES(derivedKey));
      final encryptedBytes = encrypt.Encrypted.fromBase64(encryptedPart);
      final keyBytes = encrypter.decryptBytes(encryptedBytes, iv: iv);

      _setKey(encrypt.Key(Uint8List.fromList(keyBytes)));
      _iv = iv;
      await _pin.write(key: _secureKeyName, value: _key!.base64);
      try {
        await _duravel.write(
          key: _secureKeyDuravel,
          value: _key!.base64,
        );
      } catch (_) {
        // Sem persistência durável: não migra para um estado sem proteção.
        return false;
      }
      await _box.clear();
      await _box.put(_chaveGeradaKey, 'true');
      await _box.put(_chaveDuravelKey, 'true');
      _resetarTentativas();
      return true;
    } catch (e) {
      _registrarTentativaFalha();
      Log.erro(e, contexto: 'EncryptionService.migrarChaveDoPinLegado');
      return false;
    }
  }

  /// Valida o PIN sem modificar estado (não incrementa tentativas, não desbloqueia).
  /// Retorna true se o PIN estiver correto e a chave puder ser derivada.
  ///
  /// Observação: mesmo com a chave já em memória (`_key != null`), o PIN deve
  /// ser verificado de verdade — nunca aceitar qualquer PIN por estar desbloqueado.
  Future<bool> validarPin(String pin) async {
    await inicializar();
    _verificarLockoutOuLancar();

    final encryptedData = _box.get(_encryptedKeyKey);
    final ivBase64 = _box.get(_ivKey);

    if (encryptedData == null || ivBase64 == null) return false;

    final keyParts = encryptedData.split(':');
    if (keyParts.length < 2) return false;

    final keySalt = keyParts[0];
    final encryptedPart = keyParts.sublist(1).join(':');

    final kdfVersion = int.tryParse(_box.get('kdf_version') ?? '1') ?? 1;
    final iterations = kdfVersion >= 3 ? _kdfIterationsV3 : _kdfIterations;

    try {
      final derivedKeyBytes = await _executarPbkdf2Isolate(
        pin,
        keySalt,
        iterations,
        _kdfKeyLength,
      );

      final ivBytes = base64Decode(ivBase64);
      final iv = encrypt.IV(Uint8List.fromList(ivBytes));
      final derivedKey = encrypt.Key(derivedKeyBytes);
      final encrypter = encrypt.Encrypter(encrypt.AES(derivedKey));
      final encryptedBytes = encrypt.Encrypted.fromBase64(encryptedPart);
      encrypter.decryptBytes(encryptedBytes, iv: iv);

      return true;
    } catch (_) {
      _registrarTentativaFalha();
      return false;
    }
  }

  /// Verifica se o PIN está bloqueado por excesso de tentativas.
  /// Retorna (bloqueado, segundosRestantes) ou (false, 0) se não bloqueado.
  (bool, int) get _pinLockStatus {
    final lockedUntilStr = _box.get(_pinLockedUntilKey);
    if (lockedUntilStr == null) return (false, 0);
    final lockedUntil = DateTime.tryParse(lockedUntilStr);
    if (lockedUntil == null) return (false, 0);
    final agora = DateTime.now();
    if (agora.isBefore(lockedUntil)) {
      return (true, lockedUntil.difference(agora).inSeconds + 1);
    }
    return (false, 0);
  }

  /// Incrementa contador de tentativas falhas e aplica backoff exponencial.
  void _registrarTentativaFalha() {
    int attempts = int.tryParse(_box.get(_pinAttemptsKey) ?? '0') ?? 0;
    attempts += 1;
    _box.put(_pinAttemptsKey, attempts.toString());

    if (attempts >= _maxPinAttempts) {
      final backoffIndex = (attempts - _maxPinAttempts).clamp(0, _backoffSeconds.length - 1);
      final segundos = _backoffSeconds[backoffIndex];
      final lockedUntil = DateTime.now().add(Duration(seconds: segundos)).toIso8601String();
      _box.put(_pinLockedUntilKey, lockedUntil);
      Log.info('PIN bloqueado por $segundos segundos (tentativa $attempts)');
    }
  }

  /// Reseta contador de tentativas falhas (chamado no desbloqueio bem-sucedido).
  void _resetarTentativas() {
    _box.delete(_pinAttemptsKey);
    _box.delete(_pinLockedUntilKey);
  }

  /// Verifica lockout antes de tentar validar PIN.
  /// Lança exceção se bloqueado.
  void _verificarLockoutOuLancar() {
    final (bloqueado, segundos) = _pinLockStatus;
    if (bloqueado) {
      throw Exception('PIN bloqueado por $segundos segundos. Tente novamente mais tarde.');
    }
  }

  String criptografar(String texto) {
    if (_key == null || texto.isEmpty) return texto;

    try {
      final nonce = encrypt.IV.fromSecureRandom(12);
      final encrypted = _gcm.encrypt(texto, iv: nonce);
      return '3:${nonce.base64}:${encrypted.base64}';
    } catch (e) {
      Log.erro(e, contexto: 'EncryptionService.criptografar');
      rethrow;
    }
  }

  /// Cifra um JSON de backup em envelope AES-GCM + HMAC-SHA256.
  ///
  /// Formato do envelope (JSON): `{tipo, nonce, cifrado, mac}` onde `mac` é
  /// HMAC-SHA256 sobre (nonce || cifrado) com chave derivada da chave mestra.
  /// Retorna `null` se a chave não estiver configurada (sem PIN).
  String? criptografarEnvelope(String jsonClaro) {
    if (_key == null || jsonClaro.isEmpty) return null;
    try {
      final nonce = encrypt.IV.fromSecureRandom(12);
      final nonceBytes = Uint8List.fromList(nonce.bytes);
      final cifrado = _gcm.encrypt(jsonClaro, iv: nonce);
      final cifradoBytes = Uint8List.fromList(cifrado.bytes);
      final mac = _hmacBackup(nonceBytes, cifradoBytes);
      return jsonEncode({
        'tipo': 'mentall_backup_v1',
        'nonce': base64Encode(nonceBytes),
        'cifrado': base64Encode(cifradoBytes),
        'mac': base64Encode(mac),
      });
    } catch (e) {
      Log.erro(e, contexto: 'EncryptionService.criptografarEnvelope');
      return null;
    }
  }

  /// Abre um envelope de backup: verifica o HMAC e descriptografa o JSON.
  ///
  /// Retorna o JSON claro original, ou `null` se a chave não estiver
  /// configurada, o formato for inválido ou a integridade falhar.
  String? descriptografarEnvelope(String envelopeJson) {
    if (_key == null || envelopeJson.isEmpty) return null;
    try {
      final env = jsonDecode(envelopeJson) as Map<String, dynamic>;
      if (env['tipo'] != 'mentall_backup_v1') return null;

      final nonce = base64Decode(env['nonce'] as String);
      final cifrado = base64Decode(env['cifrado'] as String);
      final macEsperado = base64Decode(env['mac'] as String);
      final macCalculado = _hmacBackup(Uint8List.fromList(nonce), Uint8List.fromList(cifrado));

      // Comparação em tempo constante para evitar timing attacks.
      if (macCalculado.length != macEsperado.length ||
          !_constEq(macCalculado, macEsperado)) {
        return null;
      }

      return _gcm.decrypt(
        encrypt.Encrypted(Uint8List.fromList(cifrado)),
        iv: encrypt.IV(nonce),
      );
    } catch (_) {
      return null;
    }
  }

  /// HMAC-SHA256 sobre (nonce || cifrado) usando chave derivada da chave mestra.
  Uint8List _hmacBackup(Uint8List nonce, Uint8List cifrado) {
    final derivado = _derivarChaveMacEnvelope();
    final hmac = Hmac(sha256, derivado);
    final dados = Uint8List.fromList([...nonce, ...cifrado]);
    return Uint8List.fromList(hmac.convert(dados).bytes);
  }

  /// Chave MAC derivada da chave mestra com contexto (não reusa a chave AES).
  Uint8List _derivarChaveMacEnvelope() {
    final ctx = utf8.encode('mentall-backup-mac-v1:');
    return Uint8List.fromList(sha256.convert([...ctx, ..._key!.bytes]).bytes);
  }

  bool _constEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  String descriptografar(String texto) {
    if (texto.isEmpty) return texto;

    if (_key == null) {
      if (possuiChaveProtegida && texto.length >= 16 && _pareceBase64ComMarker(texto)) {
        return texto;
      }
      return texto;
    }

    try {
      if (texto.startsWith('3:')) {
        final firstColon = texto.indexOf(':');
        final secondColon = texto.indexOf(':', firstColon + 1);
        if (secondColon == -1) return texto;
        final nonceBase64 = texto.substring(firstColon + 1, secondColon);
        final cipherBase64 = texto.substring(secondColon + 1);
        final nonce = encrypt.IV.fromBase64(nonceBase64);
        return _gcm.decrypt64(cipherBase64, iv: nonce);
      }

      if (texto.startsWith('2:')) {
        final firstColon = texto.indexOf(':');
        final secondColon = texto.indexOf(':', firstColon + 1);
        if (secondColon == -1) return texto;
        final ivBase64 = texto.substring(firstColon + 1, secondColon);
        final cipherBase64 = texto.substring(secondColon + 1);
        final iv = encrypt.IV.fromBase64(ivBase64);
        return _cbc.decrypt64(cipherBase64, iv: iv);
      }

      if (_iv != null) {
        return _cbc.decrypt64(texto, iv: _iv!);
      }

      return texto;
    } catch (_) {
      return texto;
    }
  }

  bool _pareceBase64ComMarker(String texto) {
    if (texto.startsWith('3:') || texto.startsWith('2:')) {
      final rest = texto.substring(2);
      return _pareceBase64(rest.replaceFirst(RegExp(r'^[^:]+:'), ''));
    }
    return _pareceBase64(texto);
  }

  bool _pareceBase64(String texto) {
    return RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(texto) && texto.length % 4 == 0;
  }

  Future<void> limpar() async {
    _key = null;
    _iv = null;
    _limparCacheCripto();
    await _pin.delete(key: _secureKeyName);
    await _duravel.delete(key: _secureKeyDuravel);
    await _box.clear();
  }

  /// Re-criptografa um texto do formato legado (2:CBC) para o formato atual (3:GCM).
  /// Retorna o texto re-criptografado ou o original se já estiver no formato atual.
  String migrarParaGcm(String texto) {
    if (_key == null || texto.isEmpty) return texto;

    if (texto.startsWith('3:')) {
      return texto;
    }

    if (texto.startsWith('2:')) {
      try {
        final firstColon = texto.indexOf(':');
        final secondColon = texto.indexOf(':', firstColon + 1);
        if (secondColon == -1) return texto;
        final ivBase64 = texto.substring(firstColon + 1, secondColon);
        final cipherBase64 = texto.substring(secondColon + 1);
        final iv = encrypt.IV.fromBase64(ivBase64);
        final decrypted = _cbc.decrypt64(cipherBase64, iv: iv);
        return criptografar(decrypted);
      } catch (_) {
        return texto;
      }
    }

    return texto;
  }
}

Uint8List _criptografarBytesGcm(Uint8List chave, Uint8List nonce, Uint8List dados) {
  final key = encrypt.Key(chave);
  final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
  final resultado = encrypter.encryptBytes(dados, iv: encrypt.IV(nonce));
  return Uint8List.fromList(resultado.bytes);
}

Uint8List _descriptografarBytesGcm(Uint8List chave, Uint8List nonce, Uint8List cifrado) {
  final key = encrypt.Key(chave);
  final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
  final resultado = encrypter.decryptBytes(
    encrypt.Encrypted(cifrado),
    iv: encrypt.IV(nonce),
  );
  return Uint8List.fromList(resultado);
}
