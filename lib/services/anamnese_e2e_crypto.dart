import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Criptografia ponta-a-ponta das respostas de anamnese.
///
/// O app gera uma chave AES-256-GCM por ficha e a transporta apenas no
/// fragmento do link (`#k=...`), que o navegador não envia ao servidor. A
/// página pública cifra as respostas com WebCrypto (mesmo formato:
/// AES-GCM, IV de 12 bytes, tag de 128 bits anexada ao ciphertext) e o app
/// decifra localmente ao sincronizar.
///
/// O servidor nunca recebe a chave nem o conteúdo clínico em texto claro.
class AnamneseE2ECrypto {
  AnamneseE2ECrypto._();

  static const int tamanhoChaveBytes = 32; // AES-256
  static const int tamanhoIvBytes = 12;
  static const int tamanhoTagBits = 128;
  static const int tamanhoMinimoCifradoBytes = 17; // tag (16) + 1 byte

  static final Random _random = Random.secure();

  static Uint8List _aleatorio(int bytes) {
    final saida = Uint8List(bytes);
    for (var i = 0; i < bytes; i++) {
      saida[i] = _random.nextInt(256);
    }
    return saida;
  }

  /// Gera a chave da ficha (32 bytes) em base64url sem padding.
  static String gerarChaveBase64Url() {
    return _base64Url(_aleatorio(tamanhoChaveBytes));
  }

  /// Gera um IV aleatório de 12 bytes em base64 padrão (para testes/uso local).
  static String gerarIvBase64() => base64Encode(_aleatorio(tamanhoIvBytes));

  /// Cifra [texto] com AES-256-GCM. Retorna `ciphertext || tag`.
  static Uint8List cifrar({
    required Uint8List chave,
    required Uint8List iv,
    required Uint8List texto,
  }) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(KeyParameter(chave), tamanhoTagBits, iv, Uint8List(0)),
      );
    return cipher.process(texto);
  }

  /// Decifra `ciphertext || tag`. Lança em caso de chave/IV/tag inválidos.
  static Uint8List decifrar({
    required Uint8List chave,
    required Uint8List iv,
    required Uint8List cifrado,
  }) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(KeyParameter(chave), tamanhoTagBits, iv, Uint8List(0)),
      );
    return cipher.process(cifrado);
  }

  static String _base64Url(Uint8List bytes) {
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static Uint8List _bytesDeBase64Url(String texto) {
    final normalizado = texto.replaceAll('-', '+').replaceAll('_', '/');
    final padding = (4 - normalizado.length % 4) % 4;
    return base64Decode(normalizado + ('=' * padding));
  }

  static Uint8List _bytesDeBase64(String texto) => base64Decode(texto.trim());

  /// Decifra o envelope vindo do backend (`iv` e `ct` em base64 padrão).
  ///
  /// Retorna o JSON em texto claro ou `null` se a chave estiver ausente/
  /// errada ou o payload estiver corrompido (a UI mostra que não foi possível
  /// decifrar neste aparelho).
  static String? decifrarRespostas({
    required String chaveBase64Url,
    required String ivBase64,
    required String ctBase64,
  }) {
    if (chaveBase64Url.isEmpty || ivBase64.isEmpty || ctBase64.isEmpty) {
      return null;
    }
    try {
      final chave = _bytesDeBase64Url(chaveBase64Url);
      final iv = _bytesDeBase64(ivBase64);
      final cifrado = _bytesDeBase64(ctBase64);
      if (chave.length != tamanhoChaveBytes ||
          iv.length != tamanhoIvBytes ||
          cifrado.length < tamanhoMinimoCifradoBytes) {
        return null;
      }
      final claro = decifrar(chave: chave, iv: iv, cifrado: cifrado);
      final json = utf8.decode(claro);
      jsonDecode(json); // garante que é JSON válido
      return json;
    } catch (_) {
      return null;
    }
  }

  /// Utilitário para testes: cifra um JSON com a chave da ficha.
  static Map<String, String> cifrarJson({
    required String chaveBase64Url,
    required String json,
  }) {
    final chave = _bytesDeBase64Url(chaveBase64Url);
    final iv = _aleatorio(tamanhoIvBytes);
    final cifrado = cifrar(
      chave: chave,
      iv: iv,
      texto: Uint8List.fromList(utf8.encode(json)),
    );
    return {'iv': base64Encode(iv), 'ct': base64Encode(cifrado)};
  }
}
