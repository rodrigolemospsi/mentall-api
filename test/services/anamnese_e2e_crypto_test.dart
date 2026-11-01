import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prontuario_tcc/models/anamnese_enviada.dart';
import 'package:prontuario_tcc/services/anamnese_e2e_crypto.dart';

void main() {
  group('AnamneseE2ECrypto (AES-256-GCM)', () {
    test('roundtrip cifra/decifra com chave gerada no app', () {
      final chave = AnamneseE2ECrypto.gerarChaveBase64Url();
      final iv = base64Decode(AnamneseE2ECrypto.gerarIvBase64());
      final texto = Uint8List.fromList(utf8.encode('{"relato":"conteudo clinico"}'));

      final cifrado = AnamneseE2ECrypto.cifrar(
        chave: base64UrlDecodeSemPadding(chave),
        iv: iv,
        texto: texto,
      );
      expect(cifrado.length, greaterThan(texto.length));
      // Ciphertext não contém o texto claro.
      expect(utf8.decode(cifrado, allowMalformed: true), isNot(contains('relato')));

      final decifrado = AnamneseE2ECrypto.decifrar(
        chave: base64UrlDecodeSemPadding(chave),
        iv: iv,
        cifrado: cifrado,
      );
      expect(utf8.decode(decifrado), '{"relato":"conteudo clinico"}');
    });

    test('interoperabilidade: decifra cifra gerada por WebCrypto (Node)', () {
      final fixture = jsonDecode(
        File('test/fixtures/anamnese_e2e_webcrypto.json').readAsStringSync(),
      ) as Map<String, dynamic>;

      final claro = AnamneseE2ECrypto.decifrarRespostas(
        chaveBase64Url: fixture['chave_base64url'] as String,
        ivBase64: fixture['iv'] as String,
        ctBase64: fixture['ct'] as String,
      );

      expect(claro, isNotNull);
      expect(claro, equals(fixture['plaintext']));
      expect(jsonDecode(claro!), {
        'queixa_principal': 'Resposta sintética de teste',
        'pensou_morte': false,
        'escala_ansiedade': 4,
        'lista': ['opcao_a', 'opcao_b'],
      });
    });

    test('formato produzido pelo app é decifrável pelo próprio utilitário', () {
      final chave = AnamneseE2ECrypto.gerarChaveBase64Url();
      final envelope = AnamneseE2ECrypto.cifrarJson(
        chaveBase64Url: chave,
        json: '{"q":true}',
      );
      final claro = AnamneseE2ECrypto.decifrarRespostas(
        chaveBase64Url: chave,
        ivBase64: envelope['iv']!,
        ctBase64: envelope['ct']!,
      );
      expect(claro, '{"q":true}');
    });

    test('chave errada não decifra', () {
      final chave = AnamneseE2ECrypto.gerarChaveBase64Url();
      final envelope = AnamneseE2ECrypto.cifrarJson(
        chaveBase64Url: chave,
        json: '{"q":1}',
      );
      final outraChave = AnamneseE2ECrypto.gerarChaveBase64Url();
      expect(
        AnamneseE2ECrypto.decifrarRespostas(
          chaveBase64Url: outraChave,
          ivBase64: envelope['iv']!,
          ctBase64: envelope['ct']!,
        ),
        isNull,
      );
    });

    test('payload corrompido ou inválido retorna null', () {
      final chave = AnamneseE2ECrypto.gerarChaveBase64Url();
      final envelope = AnamneseE2ECrypto.cifrarJson(
        chaveBase64Url: chave,
        json: '{"q":1}',
      );
      final ct = envelope['ct']!;
      final corrompido =
          ct.substring(0, ct.length - 4) + (ct.endsWith('AAAA') ? 'BBBB' : 'CCCC');
      expect(
        AnamneseE2ECrypto.decifrarRespostas(
          chaveBase64Url: chave,
          ivBase64: envelope['iv']!,
          ctBase64: corrompido,
        ),
        isNull,
      );
      expect(
        AnamneseE2ECrypto.decifrarRespostas(
          chaveBase64Url: chave,
          ivBase64: 'curto',
          ctBase64: envelope['ct']!,
        ),
        isNull,
      );
      expect(
        AnamneseE2ECrypto.decifrarRespostas(
          chaveBase64Url: '',
          ivBase64: envelope['iv']!,
          ctBase64: envelope['ct']!,
        ),
        isNull,
      );
    });

    test('URL do paciente inclui a chave no fragmento só em fichas E2E', () {
      final e2e = AnamneseEnviada(
        id: '1',
        pacienteId: 'p1',
        token: 'token123',
        abordagem: 'TCC',
        status: 'pendente',
        url: 'https://mentall-api.fly.dev/anamneses/token123',
        dataCriacao: DateTime(2026, 10, 31),
        chaveCripto: 'chave_abc',
        e2e: true,
      );
      expect(
        e2e.urlComChave,
        'https://mentall-api.fly.dev/anamneses/token123#k=chave_abc',
      );

      final legado = AnamneseEnviada(
        id: '2',
        pacienteId: 'p1',
        token: 'token123',
        abordagem: 'TCC',
        status: 'pendente',
        url: 'https://mentall-api.fly.dev/anamneses/token123',
        dataCriacao: DateTime(2026, 10, 31),
      );
      expect(legado.urlComChave, legado.url);
      expect(legado.temChaveE2e, isFalse);
    });
  });
}

/// base64url (sem padding) -> bytes, usado nos testes do app.
Uint8List base64UrlDecodeSemPadding(String texto) {
  final normalizado = texto.replaceAll('-', '+').replaceAll('_', '/');
  final padding = (4 - normalizado.length % 4) % 4;
  return base64Decode(normalizado + ('=' * padding));
}
