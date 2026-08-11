import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

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

Future<Uint8List?> _desbloquearPbkdf2(
  String pin,
  String keySalt,
  String encryptedPart,
  String ivBase64,
  String? verificationSalt,
  String? verificationHash,
  int iterations,
  int keyLength,
) {
  return Isolate.run(() {
    final mesmoSalt = verificationSalt != null && verificationSalt == keySalt;

    if (verificationSalt != null && verificationHash != null) {
      if (mesmoSalt) {
        final derived64 = _derivarPbkdf2Sync(pin, keySalt, iterations, keyLength * 2);
        final vCheck = base64Encode(Uint8List.view(derived64.buffer, 0, keyLength));
        if (vCheck != verificationHash) return null;
        final keyPart = Uint8List.view(derived64.buffer, keyLength, keyLength);
        final ivBytes = base64Decode(ivBase64);
        final iv = encrypt.IV(Uint8List.fromList(ivBytes));
        final encrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(Uint8List.fromList(keyPart))));
        final encryptedBytes = encrypt.Encrypted.fromBase64(encryptedPart);
        return Uint8List.fromList(encrypter.decryptBytes(encryptedBytes, iv: iv));
      } else {
        final vDerived = _derivarPbkdf2Sync(pin, verificationSalt, iterations, keyLength);
        if (base64Encode(vDerived) != verificationHash) return null;
      }
    }

    final derivedKey = _derivarPbkdf2Sync(pin, keySalt, iterations, keyLength);
    final ivBytes = base64Decode(ivBase64);
    final iv = encrypt.IV(Uint8List.fromList(ivBytes));
    final encrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(derivedKey)));
    final encryptedBytes = encrypt.Encrypted.fromBase64(encryptedPart);
    return Uint8List.fromList(encrypter.decryptBytes(encryptedBytes, iv: iv));
  });
}

class EncryptionService {
  static const String _boxName = 'encryption_meta';
  static const String _encryptedKeyKey = 'encrypted_key';
  static const String _ivKey = 'iv_base64';
  static const String _verificationKey = 'verification';
  static const String _kdfVersionKey = 'kdf_version';
  static const String _recoveryEncryptedKeyKey = 'recovery_encrypted_key';
  static const String _pinAttemptsKey = 'pin_attempts';
  static const String _pinLockedUntilKey = 'pin_locked_until';
  static const int _kdfIterations = 10000;
  static const int _kdfIterationsV3 = 100000;
  static const int _kdfKeyLength = 32;
  static const int _maxPinAttempts = 5;

  static const _secureStorage = FlutterSecureStorage();
  static const _secureKeyName = 'aes_master_key';

  late final Box<String> _box = Hive.box<String>(_boxName);
  encrypt.Key? _key;
  encrypt.IV? _iv;
  int _kdfVersion = 1;

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

  EncryptionService();

  static EncryptionService? _instance;

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
    try {
      return _instance!.descriptografar(texto);
    } catch (_) {
      return texto;
    }
  }

  bool get configurado => _inicializado && _key != null;

  Future<void> inicializar() async {
    if (_inicializado) return;

    try {
      _kdfVersion = int.tryParse(_box.get(_kdfVersionKey) ?? '1') ?? 1;
    } catch (_) {
      _kdfVersion = 1;
    }

    final ivBase64 = _box.get(_ivKey);
    if (ivBase64 != null && ivBase64.isNotEmpty) {
      try {
        _iv = encrypt.IV.fromBase64(ivBase64);
      } catch (_) {}
    }

    _inicializado = true;
  }

  bool get possuiPinConfigurado {
    try {
      final box = Hive.box<String>(_boxName);
      final hash = box.get(_verificationKey);
      return hash != null && hash.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> configurarPin(String pin) async {
    await inicializar();

    final salt = _gerarSalt();
    final derivedKey = await _derivarChavePBKDF2_V3Async(pin, salt);
    final newKey = encrypt.Key.fromSecureRandom(32);
    final iv = encrypt.IV.fromSecureRandom(16);

    final encrypter = encrypt.Encrypter(encrypt.AES(derivedKey));
    final encryptedKeyBytes = encrypter.encryptBytes(newKey.bytes, iv: iv);
    final verificationHash = _criarVerificationHashV3WithSalt(pin, salt);

    await _box.put(_encryptedKeyKey,
        '${salt}:${encryptedKeyBytes.base64}');
    await _box.put(_ivKey, iv.base64);
    await _box.put(_verificationKey, verificationHash);
    await _box.put(_kdfVersionKey, '3');

    _setKey(newKey);
    _iv = iv;
    _kdfVersion = 3;
  }

  Future<bool> desbloquear(String pin) async {
    await inicializar();

    if (_estaBloqueado()) return false;

    final encryptedData = _box.get(_encryptedKeyKey);
    final ivBase64 = _box.get(_ivKey);

    if (encryptedData == null || ivBase64 == null) return false;

    final keyParts = encryptedData.split(':');
    if (keyParts.length < 2) return false;

    final keySalt = keyParts[0];
    final encryptedPart = keyParts.sublist(1).join(':');
    final iterations = _kdfVersion >= 3 ? _kdfIterationsV3 : _kdfIterations;

    String? verificationSalt;
    String? verificationHash;
    final storedVerification = _box.get(_verificationKey);
    if (storedVerification != null) {
      if (storedVerification.startsWith('v3:') || storedVerification.startsWith('v2:')) {
        final prefixEnd = storedVerification.indexOf(':');
        final vParts = storedVerification.substring(prefixEnd + 1).split(':');
        if (vParts.length >= 2) {
          verificationSalt = vParts[0];
          verificationHash = vParts.sublist(1).join(':');
        }
      }
    }

    try {
      final keyBytes = await _desbloquearPbkdf2(
        pin,
        keySalt,
        encryptedPart,
        ivBase64,
        verificationSalt,
        verificationHash,
        iterations,
        _kdfKeyLength,
      );

      if (keyBytes == null) {
        await _incrementarTentativaPin();
        return false;
      }

      _setKey(encrypt.Key(keyBytes));
      _iv = encrypt.IV.fromBase64(ivBase64);
      _resetarTentativasPin();
      await _migrarParaV3SeNecessario(pin, encryptedData, ivBase64);
      return true;
    } catch (e) {
      if (_kdfVersion >= 3) {
        try {
          return await _tentarDesbloquearV2(pin, encryptedData, ivBase64);
        } catch (_) {}
      }
      Log.erro(e, contexto: 'EncryptionService.desbloquear');
      return false;
    }
  }

  Future<void> configurarRecuperacaoEmail(String recoveryToken) async {
    if (_key == null) return;
    final salt = _gerarSalt();
    final derivedKey = _derivarChavePBKDF2_V3(recoveryToken, salt);
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(derivedKey));
    final encrypted = encrypter.encryptBytes(_key!.bytes, iv: iv);
    await _box.put(_recoveryEncryptedKeyKey, '$salt:${iv.base64}:${encrypted.base64}');
  }

  bool get possuiRecuperacaoConfigurada =>
      _box.get(_recoveryEncryptedKeyKey) != null;

  Future<bool> recuperarComToken(String recoveryToken) async {
    final combined = _box.get(_recoveryEncryptedKeyKey);
    if (combined == null) return false;

    final parts = combined.split(':');
    if (parts.length < 3) return false;

    final salt = parts[0];
    final ivBase64 = parts[1];
    final encryptedPart = parts.sublist(2).join(':');

    try {
      final derivedKey = _derivarChavePBKDF2_V3(recoveryToken, salt);
      final iv = encrypt.IV.fromBase64(ivBase64);
      final encrypter = encrypt.Encrypter(encrypt.AES(derivedKey));
      final encryptedBytes = encrypt.Encrypted.fromBase64(encryptedPart);
      final keyBytes = encrypter.decryptBytes(encryptedBytes, iv: iv);
      _setKey(encrypt.Key(Uint8List.fromList(keyBytes)));
      _iv = iv;
      _resetarTentativasPin();
      return true;
    } catch (e) {
      Log.erro(e, contexto: 'EncryptionService.recuperarComToken');
      return false;
    }
  }

  Future<bool> _tentarDesbloquearV2(
      String pin, String encryptedData, String ivBase64) async {
    final parts = encryptedData.split(':');
    if (parts.length < 2) return false;

    final salt = parts[0];
    final encryptedPart = parts.sublist(1).join(':');

    final derivedKey = await _derivarChavePBKDF2Async(pin, salt);
    final iv = encrypt.IV.fromBase64(ivBase64);

    final encrypter = encrypt.Encrypter(encrypt.AES(derivedKey));
    final encryptedBytes = encrypt.Encrypted.fromBase64(encryptedPart);
    final keyBytes = encrypter.decryptBytes(encryptedBytes, iv: iv);

    _setKey(encrypt.Key(Uint8List.fromList(keyBytes)));
    _iv = iv;
    _resetarTentativasPin();

    await _atualizarChaveProtegida(pin);
    _kdfVersion = 3;
    return true;
  }

  Future<void> _atualizarChaveProtegida(String pin) async {
    if (_key == null) return;

    final salt = _gerarSalt();
    final derivedKey = await _derivarChavePBKDF2_V3Async(pin, salt);
    final iv = _iv ?? encrypt.IV.fromSecureRandom(16);
    final verificationHash = _criarVerificationHashV3WithSalt(pin, salt);

    final encrypter = encrypt.Encrypter(encrypt.AES(derivedKey));
    final encryptedKeyBytes = encrypter.encryptBytes(_key!.bytes, iv: iv);

    await _box.put(_encryptedKeyKey, '$salt:${encryptedKeyBytes.base64}');
    await _box.put(_ivKey, iv.base64);
    await _box.put(_verificationKey, verificationHash);
    await _box.put(_kdfVersionKey, '3');
    _iv = iv;
    _kdfVersion = 3;
  }

  Future<void> _migrarParaV3SeNecessario(String pin, String encryptedData, String ivBase64) async {
    if (_kdfVersion >= 3) return;
    await _atualizarChaveProtegida(pin);
  }

  Future<void> reprotegerChaveComNovoPin(String novoPin) async {
    await inicializar();
    await _atualizarChaveProtegida(novoPin);
    _resetarTentativasPin();
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

  String descriptografar(String texto) {
    if (texto.isEmpty) return texto;

    if (_key == null) {
      if (possuiPinConfigurado && texto.length >= 16 && _pareceBase64ComMarker(texto)) {
        Log.erro(
          'Tentativa de descriptografar com PIN configurado mas chave indisponivel. '
          'Dados mantidos em formato seguro (criptografado) ate o desbloqueio.',
          contexto: 'EncryptionService.descriptografar',
        );
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

  encrypt.Key _derivarChavePBKDF2(String pin, String salt) {
    final saltBytes = base64Decode(salt);
    final derivator = KeyDerivator('SHA-256/HMAC/PBKDF2');
    derivator.init(Pbkdf2Parameters(saltBytes, _kdfIterations, _kdfKeyLength));
    final derived = derivator.process(utf8.encode(pin));
    return encrypt.Key(Uint8List.fromList(derived));
  }

  encrypt.Key _derivarChavePBKDF2_V3(String pin, String salt) {
    final saltBytes = base64Decode(salt);
    final derivator = KeyDerivator('SHA-256/HMAC/PBKDF2');
    derivator.init(Pbkdf2Parameters(saltBytes, _kdfIterationsV3, _kdfKeyLength));
    final derived = derivator.process(utf8.encode(pin));
    return encrypt.Key(Uint8List.fromList(derived));
  }

  encrypt.Key _derivarChaveLegacy(String pin, String salt) {
    final combined = utf8.encode('$pin:$salt');
    final expanded = Uint8List(32);

    for (int i = 0; i < 32; i++) {
      expanded[i] = combined[i % combined.length];
    }

    return encrypt.Key(expanded);
  }

  Future<encrypt.Key> _derivarChavePBKDF2Async(String pin, String salt) async {
    final result = await _executarPbkdf2Isolate(
      pin,
      salt,
      _kdfIterations,
      _kdfKeyLength,
    );
    return encrypt.Key(result);
  }

  Future<encrypt.Key> _derivarChavePBKDF2_V3Async(String pin, String salt) async {
    final result = await _executarPbkdf2Isolate(
      pin,
      salt,
      _kdfIterationsV3,
      _kdfKeyLength,
    );
    return encrypt.Key(result);
  }

  Future<bool> _verificarPinAsync(String pin) async {
    final stored = _box.get(_verificationKey);
    if (stored == null) return false;

    if (stored.startsWith('v3:')) {
      final parts = stored.substring(3).split(':');
      if (parts.length < 2) return false;
      final salt = parts[0];
      final hash = parts.sublist(1).join(':');
      final computed = await _derivarChavePBKDF2_V3Async(pin, salt);
      return computed.base64 == hash;
    }

    if (stored.startsWith('v2:')) {
      final parts = stored.substring(3).split(':');
      if (parts.length < 2) return false;
      final salt = parts[0];
      final hash = parts.sublist(1).join(':');
      final computed = await _derivarChavePBKDF2Async(pin, salt);
      return computed.base64 == hash;
    }

    final parts = stored.split(':');
    if (parts.length != 2) return false;

    final hash = _derivarChaveLegacy(pin, parts[0]);
    return hash.base64 == parts[1];
  }

  String _gerarSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  String _criarVerificationHashV3WithSalt(String pin, String salt) {
    final hash = _derivarChavePBKDF2_V3(pin, salt);
    return 'v3:$salt:${hash.base64}';
  }

  Future<bool> validarPin(String pin) async {
    if (_estaBloqueado()) return false;
    final valido = await _verificarPinAsync(pin);
    if (!valido) {
      await _incrementarTentativaPin();
      return false;
    }
    return true;
  }

  Future<bool> trocarPin(String pinAtual, String novoPin) async {
    await inicializar();

    if (_estaBloqueado()) return false;
    if (!await _verificarPinAsync(pinAtual)) {
      await _incrementarTentativaPin();
      return false;
    }

    if (_key == null) {
      final desbloqueou = await desbloquear(pinAtual);
      if (!desbloqueou) return false;
    }

    final salt = _gerarSalt();
    final derivedKey = _derivarChavePBKDF2_V3(novoPin, salt);
    final iv = _iv ?? encrypt.IV.fromSecureRandom(16);

    final encrypter = encrypt.Encrypter(encrypt.AES(derivedKey));
    final encryptedKeyBytes = encrypter.encryptBytes(_key!.bytes, iv: iv);
    final verificationHash = _criarVerificationHashV3WithSalt(novoPin, salt);

    await _box.put(_encryptedKeyKey, '$salt:${encryptedKeyBytes.base64}');
    await _box.put(_ivKey, iv.base64);
    await _box.put(_verificationKey, verificationHash);
    await _box.put(_kdfVersionKey, '3');

    _iv = iv;
    _kdfVersion = 3;
    _resetarTentativasPin();
    return true;
  }

  Future<void> limpar() async {
    _key = null;
    _iv = null;
    _kdfVersion = 1;
    _limparCacheCripto();
    await _secureStorage.delete(key: _secureKeyName);
    await _box.clear();
  }

  Future<void> salvarChaveNoSecureStorage() async {
    if (_key == null) return;
    await _secureStorage.write(key: _secureKeyName, value: _key!.base64);
  }

  Future<bool> recuperarChaveDoSecureStorage() async {
    await inicializar();
    try {
      final keyBase64 = await _secureStorage.read(key: _secureKeyName);
      if (keyBase64 == null || keyBase64.isEmpty) return false;
      _setKey(encrypt.Key.fromBase64(keyBase64));
      _resetarTentativasPin();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> removerChaveDoSecureStorage() async {
    await _secureStorage.delete(key: _secureKeyName);
  }

  bool _estaBloqueado() {
    final lockedUntil = _box.get(_pinLockedUntilKey);
    if (lockedUntil == null) return false;
    final until = int.tryParse(lockedUntil);
    if (until == null) return false;
    if (DateTime.now().millisecondsSinceEpoch < until) return true;
    _box.delete(_pinLockedUntilKey);
    return false;
  }

  Future<void> _incrementarTentativaPin() async {
    final attempts = (int.tryParse(_box.get(_pinAttemptsKey) ?? '0') ?? 0) + 1;
    await _box.put(_pinAttemptsKey, attempts.toString());

    if (attempts >= _maxPinAttempts) {
      final extra = attempts - _maxPinAttempts + 1;
      final delayMs = (1000 * (1 << extra)).clamp(1000, 3600000);
      await _box.put(
        _pinLockedUntilKey,
        (DateTime.now().millisecondsSinceEpoch + delayMs).toString(),
      );
    }
  }

  void _resetarTentativasPin() {
    _box.delete(_pinAttemptsKey);
    _box.delete(_pinLockedUntilKey);
  }

  int get tentativasRestantes {
    final attempts = int.tryParse(_box.get(_pinAttemptsKey) ?? '0') ?? 0;
    final restantes = _maxPinAttempts - attempts;
    return restantes < 0 ? 0 : restantes;
  }
}
