// Testes do gate de revisao: IA sem revisao nao vai ao prontuario.
//
// Antes: `_salvarSessao()` nao validava a flag, embora o AGENTS.md afirmasse
// "Revisao: Obrigatoria pelo profissional". Ver AGENTS.md (secao 06/10/2026).
import 'package:flutter_test/flutter_test.dart';
import 'package:prontuario_tcc/utils/sessao_form_helpers.dart';

void main() {
  test('IA sem revisao marca bloqueio', () {
    expect(
      precisaRevisarAntesDeSalvar(
        geradoComIa: true,
        revisadoPeloProfissional: false,
      ),
      isTrue,
    );
  });

  test('IA ja revisada permite salvar', () {
    expect(
      precisaRevisarAntesDeSalvar(
        geradoComIa: true,
        revisadoPeloProfissional: true,
      ),
      isFalse,
    );
  });

  test('sessao sem IA nao e afetada', () {
    expect(
      precisaRevisarAntesDeSalvar(
        geradoComIa: false,
        revisadoPeloProfissional: false,
      ),
      isFalse,
    );
  });

  test('revisado sem IA tambem passa', () {
    expect(
      precisaRevisarAntesDeSalvar(
        geradoComIa: false,
        revisadoPeloProfissional: true,
      ),
      isFalse,
    );
  });
}
