import 'package:flutter_test/flutter_test.dart';

import 'package:prontuario_tcc/services/encrypted_service_mixin.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';

class _ServiceComMixin with EncryptedServiceMixin {
  @override
  final EncryptionService? encryption;
  _ServiceComMixin(this.encryption);
}

void main() {
  test('encrypt lanca quando nao ha chave e o valor nao esta vazio',
      () async {
    final service = _ServiceComMixin(null);
    expect(() => service.encrypt('dado clinico'), throwsStateError);
  });

  test('encrypt nao lanca para valor vazio mesmo sem chave', () {
    final service = _ServiceComMixin(null);
    expect(service.encrypt(''), isEmpty);
  });

  test('encrypt cifra quando a chave esta configurada', () async {
    final encryption = EncryptionService();
    await encryption.gerarChave();
    final service = _ServiceComMixin(encryption);
    final cifrado = service.encrypt('dado clinico');
    expect(cifrado, isNot('dado clinico'));
    expect(encryption.descriptografar(cifrado), 'dado clinico');
  });

  test('decrypt devolve o texto plano para dados legados sem chave', () {
    final service = _ServiceComMixin(null);
    expect(service.decrypt('texto plano'), 'texto plano');
  });

  test('decrypt devolve o valor cifrado quando nao ha chave (boot)', () {
    final service = _ServiceComMixin(null);
    // Sem chave (ex.: antes do desbloqueio no boot), NAO lanca: devolve o
    // valor como esta para nao quebrar a leitura inicial. O app pede o
    // desbloqueio e relê.
    expect(service.decrypt('3:abc:def'), '3:abc:def');
  });

  test('estaCifrado reconhece o formato real e ignora texto clinico', () async {
    final encryption = EncryptionService();
    await encryption.gerarChave();

    expect(encryption.estaCifrado(encryption.criptografar('dado clinico')), isTrue);
    expect(encryption.estaCifrado('3:abcdefghijklmnop:ABCDEFGHIJKLMNOPQRSTUVWX'), isTrue);
    expect(encryption.estaCifrado('2:abcdefghijklmnop:ABCDEFGHIJKLMNOPQRSTUVWX'), isTrue);

    expect(encryption.estaCifrado(''), isFalse);
    expect(encryption.estaCifrado('Paciente relata ansiedade intensa.'), isFalse);
    expect(encryption.estaCifrado('3:abc:def'), isFalse);
    expect(encryption.estaCifrado('3: relato da sessao com espacos'), isFalse);
  });

  test('criptografar NAO re-cifra um valor ja cifrado', () async {
    final encryption = EncryptionService();
    await encryption.gerarChave();

    final cifrado = encryption.criptografar('dado clinico');
    final deNovo = encryption.criptografar(cifrado);

    expect(deNovo, cifrado, reason: 'o criptograma original deve ser preservado');
    expect(encryption.descriptografar(deNovo), 'dado clinico');
  });

  test('caminho do incidente: leitura sem chave + salvamento nao destroi o dado',
      () async {
    // Leitura antes do desbloqueio devolve o criptograma; se o profissional
    // salvar nesse estado, o valor nao pode ser cifrado de novo.
    final encryption = EncryptionService();
    await encryption.gerarChave();
    final original = encryption.criptografar('relato clinico sensivel');

    final lidoSemChave = _ServiceComMixin(null).decrypt(original);
    expect(lidoSemChave, original);

    final regravado = _ServiceComMixin(encryption).encrypt(lidoSemChave);
    expect(regravado, original);
    expect(encryption.descriptografar(regravado), 'relato clinico sensivel');
  });
}
