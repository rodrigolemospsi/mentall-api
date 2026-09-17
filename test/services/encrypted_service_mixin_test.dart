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
}
