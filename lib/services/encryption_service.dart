import 'dart:convert';
import 'dart:isolate';
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

class EncryptionService {
  static const String _boxName = 'encryption_meta';
  static const String _encryptedKeyKey = 'encrypted_key';
  static const String _ivKey = 'iv_base64';
  static const String _chaveGeradaKey = 'chave_gerada';
  static const int _kdfIterations = 10000;
  static const int _kdfIterationsV3 = 100000;
  static const int _kdfKeyLength = 32;

  static const _secureStorageBiometria = FlutterSecureStorage(
    aOptions: AndroidOptions.biometric(
      enforceBiometrics: true,
      biometricType: AndroidBiometricType.strongBiometricOnly,
      biometricPromptTitle: 'Acesso com biometria',
      biometricPromptSubtitle: 'Toque no leitor de impressão digital',
      biometricPromptNegativeButton: 'Usar PIN',
    ),
  );

  static const _secureStoragePin = FlutterSecureStorage(
    aOptions: AndroidOptions.biometric(
      enforceBiometrics: true,
      biometricType: AndroidBiometricType.biometricOrDeviceCredential,
      biometricPromptTitle: 'Acesso com PIN',
      biometricPromptSubtitle: 'Digite o PIN do dispositivo',
    ),
  );

  static const _secureKeyName = 'aes_master_key';

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

  Future<bool> gerarChave() async {
    await inicializar();

    final newKey = encrypt.Key.fromSecureRandom(32);
    final newIv = encrypt.IV.fromSecureRandom(16);
    _setKey(newKey);
    _iv = newIv;

    try {
      await _secureStoragePin.write(key: _secureKeyName, value: newKey.base64);
    } catch (_) {
      // Em plataformas sem secure storage, a chave fica em memória.
    }
    try {
      await _box.put(_chaveGeradaKey, 'true');
    } catch (_) {
      // A flag é apenas otimização de detecção; a chave em memória é o que importa.
    }
    return true;
  }

  Future<bool> carregarChaveDoSecureStorage() async {
    await inicializar();

    // 1º passo: tenta a biometria ("Acesso com biometria").
    // Se o usuário tocar "Usar PIN", o prompt é cancelado e caímos no 2º passo.
    try {
      final keyBase64 =
          await _secureStorageBiometria.read(key: _secureKeyName);
      if (keyBase64 != null && keyBase64.isNotEmpty) {
        _setKey(encrypt.Key.fromBase64(keyBase64));
        return true;
      }
    } catch (_) {
      // cancelado ou biometria indisponível -> tenta credencial do dispositivo.
    }

    // 2º passo: credencial do dispositivo ("Acesso com PIN").
    try {
      final keyBase64 = await _secureStoragePin.read(key: _secureKeyName);
      if (keyBase64 == null || keyBase64.isEmpty) return false;
      _setKey(encrypt.Key.fromBase64(keyBase64));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> migrarChaveDoPinLegado(String pin) async {
    await inicializar();

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
      await _secureStoragePin.write(key: _secureKeyName, value: _key!.base64);
      await _box.clear();
      await _box.put(_chaveGeradaKey, 'true');
      return true;
    } catch (e) {
      Log.erro(e, contexto: 'EncryptionService.migrarChaveDoPinLegado');
      return false;
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
    await _secureStoragePin.delete(key: _secureKeyName);
    await _box.clear();
  }
}
