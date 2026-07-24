import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:hive_ce/hive.dart';
import 'package:pointycastle/export.dart';

import 'logger.dart';

class EncryptionService {
  static const String _boxName = 'encryption_meta';
  static const String _encryptedKeyKey = 'encrypted_key';
  static const String _ivKey = 'iv_base64';
  static const String _verificationKey = 'verification';
  static const String _kdfVersionKey = 'kdf_version';
  static const String _recoveryPhraseHashKey = 'recovery_phrase_hash';
  static const String _recoveryEncryptedKeyKey = 'recovery_encrypted_key';
  static const int _kdfIterations = 100000;
  static const int _kdfKeyLength = 32;

  static const List<String> _palavrasRecuperacao = [
    'abacate', 'abril', 'agua', 'alegre', 'amarelo', 'amigo', 'amor', 'anel',
    'animal', 'arco', 'arvore', 'azul', 'balao', 'banana', 'barco', 'bateria',
    'beijo', 'bicicleta', 'bola', 'bolo', 'bolsa', 'bone', 'branco', 'brilho',
    'cadeira', 'caderno', 'cafe', 'calmo', 'cama', 'campo', 'caneta', 'carro',
    'carta', 'casa', 'ceu', 'chale', 'chave', 'chuva', 'cinema', 'circo',
    'cobra', 'colar', 'coracao', 'coroa', 'correr', 'costela', 'dado', 'dança',
    'dedo', 'dente', 'doce', 'dragao', 'elefante', 'escola', 'escova', 'espada',
    'espelho', 'estrela', 'fada', 'familia', 'feliz', 'ferro', 'festa', 'filme',
    'flauta', 'flecha', 'flor', 'foca', 'fogo', 'folha', 'fonte', 'forma',
    'fruta', 'fumaça', 'galinha', 'gato', 'gelo', 'girafa', 'girassol', 'golfe',
    'grama', 'grilo', 'guerra', 'heroi', 'ilha', 'irmao', 'janela', 'jardim',
    'joia', 'jornal', 'lago', 'lampada', 'lapis', 'laranja', 'leao', 'leite',
    'lenha', 'livro', 'lua', 'luva', 'maca', 'madeira', 'mae', 'magico',
    'manga', 'mansao', 'mar', 'mascara', 'mel', 'mesa', 'moeda', 'montanha',
    'morango', 'motor', 'musica', 'nave', 'neve', 'ninho', 'noiva', 'norte',
    'nuvem', 'oceano', 'oculos', 'onda', 'ouro', 'pai', 'palacio', 'palheta',
    'pano', 'papel', 'parque', 'passaro', 'pedra', 'peixe', 'pena', 'pente',
    'piano', 'pilha', 'pincel', 'planeta', 'planta', 'pluma', 'poeira', 'pomba',
    'ponte', 'porta', 'praia', 'prato', 'princesa', 'quadro', 'queijo', 'raio',
    'raposa', 'rede', 'relogio', 'rio', 'robo', 'rocha', 'rosa', 'roda',
    'sabao', 'sapato', 'selva', 'sino', 'sombra', 'sorvete', 'tela', 'tempo',
    'tesoura', 'tigre', 'tijolo', 'toalha', 'torre', 'trator', 'trem', 'trigo',
    'trono', 'uva', 'vassoura', 'vela', 'vento', 'verao', 'vidro', 'vinho',
    'violao', 'vulcao', 'zebra', 'zero',
  ];

  late final Box<String> _box = Hive.box<String>(_boxName);
  encrypt.Key? _key;
  encrypt.IV? _iv;
  int _kdfVersion = 1;

  bool _inicializado = false;

  EncryptionService();

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
    final derivedKey = _derivarChavePBKDF2(pin, salt);
    final newKey = encrypt.Key.fromSecureRandom(32);
    final iv = encrypt.IV.fromSecureRandom(16);

    final encrypter = encrypt.Encrypter(encrypt.AES(derivedKey));
    final encryptedKeyBytes = encrypter.encryptBytes(newKey.bytes, iv: iv);
    final verificationHash = _criarVerificationHashPBKDF2(pin);

    await _box.put(_encryptedKeyKey,
        '${salt}:${encryptedKeyBytes.base64}');
    await _box.put(_ivKey, iv.base64);
    await _box.put(_verificationKey, verificationHash);
    await _box.put(_kdfVersionKey, '2');

    _key = newKey;
    _iv = iv;
    _kdfVersion = 2;
  }

  Future<bool> desbloquear(String pin) async {
    await inicializar();

    final encryptedData = _box.get(_encryptedKeyKey);
    final ivBase64 = _box.get(_ivKey);

    if (encryptedData == null || ivBase64 == null) return false;

    if (!_verificarPin(pin)) return false;

    try {
      final parts = encryptedData.split(':');
      if (parts.length < 2) return false;

      final salt = parts[0];
      final encryptedPart = parts.sublist(1).join(':');

      encrypt.Key derivedKey;
      if (_kdfVersion >= 2) {
        derivedKey = _derivarChavePBKDF2(pin, salt);
      } else {
        derivedKey = _derivarChaveLegacy(pin, salt);
      }

      final iv = encrypt.IV.fromBase64(ivBase64);

      final encrypter = encrypt.Encrypter(encrypt.AES(derivedKey));
      final encryptedBytes = encrypt.Encrypted.fromBase64(encryptedPart);
      final keyBytes = encrypter.decryptBytes(encryptedBytes, iv: iv);

      _key = encrypt.Key(Uint8List.fromList(keyBytes));
      _iv = iv;
      return true;
    } catch (e) {
      if (_kdfVersion >= 2) {
        try {
          return await _tentarDesbloquearLegacy(pin, encryptedData, ivBase64);
        } catch (_) {}
      }
      Log.erro(e, contexto: 'EncryptionService.desbloquear');
      return false;
    }
  }

  Future<bool> _tentarDesbloquearLegacy(
      String pin, String encryptedData, String ivBase64) async {
    final parts = encryptedData.split(':');
    if (parts.length < 2) return false;

    final salt = parts[0];
    final encryptedPart = parts.sublist(1).join(':');

    final derivedKey = _derivarChaveLegacy(pin, salt);
    final iv = encrypt.IV.fromBase64(ivBase64);

    final encrypter = encrypt.Encrypter(encrypt.AES(derivedKey));
    final encryptedBytes = encrypt.Encrypted.fromBase64(encryptedPart);
    final keyBytes = encrypter.decryptBytes(encryptedBytes, iv: iv);

    _key = encrypt.Key(Uint8List.fromList(keyBytes));
    _iv = iv;

    await _box.put(_kdfVersionKey, '2');
    await _atualizarChaveProtegida(pin);
    _kdfVersion = 2;
    return true;
  }

  Future<void> _atualizarChaveProtegida(String pin) async {
    if (_key == null) return;

    final salt = _gerarSalt();
    final derivedKey = _derivarChavePBKDF2(pin, salt);
    final iv = _iv ?? encrypt.IV.fromSecureRandom(16);
    final verificationHash = _criarVerificationHashPBKDF2(pin);

    final encrypter = encrypt.Encrypter(encrypt.AES(derivedKey));
    final encryptedKeyBytes = encrypter.encryptBytes(_key!.bytes, iv: iv);

    await _box.put(_encryptedKeyKey, '$salt:${encryptedKeyBytes.base64}');
    await _box.put(_verificationKey, verificationHash);
    await _box.put(_kdfVersionKey, '2');
    _iv = iv;
    _kdfVersion = 2;
  }

  String criptografar(String texto) {
    if (_key == null || texto.isEmpty) return texto;

    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(_key!));
      final randomIv = encrypt.IV.fromSecureRandom(16);
      final encrypted = encrypter.encrypt(texto, iv: randomIv);
      return '2:${randomIv.base64}:${encrypted.base64}';
    } catch (e) {
      Log.erro(e, contexto: 'EncryptionService.criptografar');
      return texto;
    }
  }

  String descriptografar(String texto) {
    if (texto.isEmpty) return texto;

    if (_key == null) {
      if (possuiPinConfigurado && texto.length >= 16 && _pareceBase64ComMarker(texto)) {
        Log.erro(
          'Descriptografia solicitada com PIN configurado mas chave indisponivel',
          contexto: 'EncryptionService.descriptografar',
        );
        return '';
      }
      return texto;
    }

    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(_key!));

      if (texto.startsWith('2:')) {
        final firstColon = texto.indexOf(':');
        final secondColon = texto.indexOf(':', firstColon + 1);
        if (secondColon == -1) return texto;
        final ivBase64 = texto.substring(firstColon + 1, secondColon);
        final cipherBase64 = texto.substring(secondColon + 1);
        final iv = encrypt.IV.fromBase64(ivBase64);
        return encrypter.decrypt64(cipherBase64, iv: iv);
      }

      if (_iv != null) {
        return encrypter.decrypt64(texto, iv: _iv!);
      }

      return texto;
    } catch (_) {
      return texto;
    }
  }

  bool _pareceBase64ComMarker(String texto) {
    if (texto.startsWith('2:')) {
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

  encrypt.Key _derivarChaveLegacy(String pin, String salt) {
    final combined = utf8.encode('$pin:$salt');
    final expanded = Uint8List(32);

    for (int i = 0; i < 32; i++) {
      expanded[i] = combined[i % combined.length];
    }

    return encrypt.Key(expanded);
  }

  String _gerarSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  String _criarVerificationHashPBKDF2(String pin) {
    final salt = _gerarSalt();
    final hash = _derivarChavePBKDF2(pin, salt);
    return 'v2:$salt:${hash.base64}';
  }

  bool _verificarPin(String pin) {
    final stored = _box.get(_verificationKey);
    if (stored == null) return false;

    if (stored.startsWith('v2:')) {
      final parts = stored.substring(3).split(':');
      if (parts.length < 2) return false;
      final salt = parts[0];
      final hash = parts.sublist(1).join(':');
      final computed = _derivarChavePBKDF2(pin, salt);
      return computed.base64 == hash;
    }

    final parts = stored.split(':');
    if (parts.length != 2) return false;

    final hash = _derivarChaveLegacy(pin, parts[0]);
    return hash.base64 == parts[1];
  }

  Future<bool> trocarPin(String pinAtual, String novoPin) async {
    await inicializar();

    if (!_verificarPin(pinAtual)) return false;

    if (_key == null) {
      final desbloqueou = await desbloquear(pinAtual);
      if (!desbloqueou) return false;
    }

    final salt = _gerarSalt();
    final derivedKey = _derivarChavePBKDF2(novoPin, salt);
    final iv = _iv ?? encrypt.IV.fromSecureRandom(16);

    final encrypter = encrypt.Encrypter(encrypt.AES(derivedKey));
    final encryptedKeyBytes = encrypter.encryptBytes(_key!.bytes, iv: iv);
    final verificationHash = _criarVerificationHashPBKDF2(novoPin);

    await _box.put(_encryptedKeyKey, '$salt:${encryptedKeyBytes.base64}');
    await _box.put(_ivKey, iv.base64);
    await _box.put(_verificationKey, verificationHash);
    await _box.put(_kdfVersionKey, '2');

    _iv = iv;
    _kdfVersion = 2;
    return true;
  }

  Future<void> limpar() async {
    _key = null;
    _iv = null;
    _kdfVersion = 1;
    await _box.clear();
  }

  String gerarFraseRecuperacao() {
    final random = Random.secure();
    final words = <String>[];
    for (int i = 0; i < 12; i++) {
      words.add(_palavrasRecuperacao[random.nextInt(_palavrasRecuperacao.length)]);
    }
    return words.join(' ');
  }

  Future<void> configurarFraseRecuperacao(String frase) async {
    if (_key == null) return;

    final salt = _gerarSalt();
    final recoveryKey = _derivarChavePBKDF2(frase, salt);
    final phraseHash = sha256.convert(utf8.encode(frase)).toString();

    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(recoveryKey));
    final encryptedKeyBytes = encrypter.encryptBytes(_key!.bytes, iv: iv);

    await _box.put(_recoveryPhraseHashKey, phraseHash);
    await _box.put(_recoveryEncryptedKeyKey,
        '$salt:${iv.base64}:${encryptedKeyBytes.base64}');
  }

  bool get possuiFraseRecuperacao =>
      _box.get(_recoveryPhraseHashKey) != null &&
      _box.get(_recoveryEncryptedKeyKey) != null;

  bool verificarFraseRecuperacao(String frase) {
    final storedHash = _box.get(_recoveryPhraseHashKey);
    if (storedHash == null) return false;
    final computedHash = sha256.convert(utf8.encode(frase)).toString();
    return computedHash == storedHash;
  }

  Future<bool> recuperarComFrase(String frase) async {
    final combined = _box.get(_recoveryEncryptedKeyKey);
    if (combined == null) return false;

    final parts = combined.split(':');
    if (parts.length < 3) return false;

    final salt = parts[0];
    final ivBase64 = parts[1];
    final encryptedPart = parts.sublist(2).join(':');

    final recoveryKey = _derivarChavePBKDF2(frase, salt);
    final iv = encrypt.IV.fromBase64(ivBase64);

    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(recoveryKey));
      final encryptedBytes = encrypt.Encrypted.fromBase64(encryptedPart);
      final keyBytes = encrypter.decryptBytes(encryptedBytes, iv: iv);
      _key = encrypt.Key(Uint8List.fromList(keyBytes));
      _iv = iv;
      return true;
    } catch (e) {
      Log.erro(e, contexto: 'EncryptionService.recuperarComFrase');
      return false;
    }
  }

  Future<void> limparRecuperacao() async {
    await _box.delete(_recoveryPhraseHashKey);
    await _box.delete(_recoveryEncryptedKeyKey);
  }
}
