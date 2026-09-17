import 'package:flutter_test/flutter_test.dart';

import 'package:prontuario_tcc/services/pacote_service.dart';

void main() {
  group('PacoteService.deveConsumirAoSalvar', () {
    test('consome quando cria sessao nova por pacote', () {
      expect(
        PacoteService.deveConsumirAoSalvar(
          editando: false,
          statusPacote: true,
        ),
        isTrue,
      );
    });

    test('nao consome quando edita sessao existente por pacote', () {
      expect(
        PacoteService.deveConsumirAoSalvar(
          editando: true,
          statusPacote: true,
        ),
        isFalse,
      );
    });

    test('nao consome quando cria com outro status de pagamento', () {
      expect(
        PacoteService.deveConsumirAoSalvar(
          editando: false,
          statusPacote: false,
        ),
        isFalse,
      );
    });

    test('nao consome quando edita com outro status de pagamento', () {
      expect(
        PacoteService.deveConsumirAoSalvar(
          editando: true,
          statusPacote: false,
        ),
        isFalse,
      );
    });
  });
}
