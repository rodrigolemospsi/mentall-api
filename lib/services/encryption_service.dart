import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:hive_ce/hive.dart';

import 'logger.dart';

class EncryptionService {
  static const String _boxName = 'encryption_meta';
  static const String _encryptedKeyKey = 'encrypted_key';
  static const String _ivKey = 'iv_base64';
  static const String _verificationKey = 'verification';

  late final Box<String> _box;
  encrypt.Key? _key;
  encrypt.IV? _iv;

  bool _inicializado = false;

  EncryptionService();

  bool get configurado => _inicializado && _key != null;

  Future<void> inicializar() async {
    if (_inicializado) return;

    _box = await Hive.openBox<String>(_boxName);
    _inicializado = true;

    final ivBase64 = _box.get(_ivKey);
    if (ivBase64 != null && ivBase64.isNotEmpty) {
      _iv = encrypt.IV.fromBase64(ivBase64);
    }
  }

  bool get possuiPinConfigurado {
    if (!_inicializado) return false;
    final hash = _box.get(_verificationKey);
    return hash != null && hash.isNotEmpty;
  }

  Future<void> configurarPin(String pin) async {
    final salt = _gerarSalt();
    final derivedKey = _derivarChave(pin, salt);
    final newKey = encrypt.Key.fromSecureRandom(32);
    final iv = encrypt.IV.fromSecureRandom(16);

    final encrypter = encrypt.Encrypter(encrypt.AES(derivedKey));
    final encryptedKeyBytes = encrypter.encryptBytes(newKey.bytes, iv: iv);
    final verificationHash = _criarVerificationHash(pin);

    await _box.put(_encryptedKeyKey,
        '${salt}:${encryptedKeyBytes.base64}');
    await _box.put(_ivKey, iv.base64);
    await _box.put(_verificationKey, verificationHash);

    _key = newKey;
    _iv = iv;
  }

  Future<bool> desbloquear(String pin) async {
    final encryptedData = _box.get(_encryptedKeyKey);
    final ivBase64 = _box.get(_ivKey);

    if (encryptedData == null || ivBase64 == null) return false;

    if (!_verificarPin(pin)) return false;

    try {
      final parts = encryptedData.split(':');
      if (parts.length != 2) return false;

      final salt = parts[0];
      final derivedKey = _derivarChave(pin, salt);
      final iv = encrypt.IV.fromBase64(ivBase64);

      final encrypter = encrypt.Encrypter(encrypt.AES(derivedKey));
      final encryptedBytes =
          encrypt.Encrypted.fromBase64(parts[1]);
      final keyBytes = encrypter.decryptBytes(encryptedBytes, iv: iv);

      _key = encrypt.Key(Uint8List.fromList(keyBytes));
      _iv = iv;
      return true;
    } catch (e) {
      Log.erro(e, contexto: 'EncryptionService.desbloquear');
      return false;
    }
  }

  String criptografar(String texto) {
    if (_key == null || _iv == null || texto.isEmpty) return texto;

    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(_key!));
      final encrypted = encrypter.encrypt(texto, iv: _iv!);
      return encrypted.base64;
    } catch (e) {
      Log.erro(e, contexto: 'EncryptionService.criptografar');
      return texto;
    }
  }

  String descriptografar(String texto) {
    if (_key == null || _iv == null || texto.isEmpty) return texto;

    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(_key!));
      return encrypter.decrypt64(texto, iv: _iv!);
    } catch (_) {
      return texto;
    }
  }

  encrypt.Key _derivarChave(String pin, String salt) {
    final combined = utf8.encode('$pin:$salt');
    final expanded = Uint8List(32);

    for (int i = 0; i < 32; i++) {
      expanded[i] = combined[i % combined.length];
    }

    return encrypt.Key(expanded);
  }

  String _gerarSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  String _criarVerificationHash(String pin) {
    final salt = _gerarSalt();
    final hash = _derivarChave(pin, salt);
    return '$salt:${hash.base64}';
  }

  bool _verificarPin(String pin) {
    final stored = _box.get(_verificationKey);
    if (stored == null) return false;

    final parts = stored.split(':');
    if (parts.length != 2) return false;

    final hash = _derivarChave(pin, parts[0]);
    return hash.base64 == parts[1];
  }

  Future<void> limpar() async {
    _key = null;
    _iv = null;
    await _box.clear();
  }
}
