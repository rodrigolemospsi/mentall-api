// Testes da decisao sobre indicacoes de artigos (achado A1 da auditoria).
//
// Antes: uma falha na busca (retorno null) deixava o campo vazio e o app
// persistia `artigosSugeridos = ''`, apagando as indicacoes ja salvas na sessao,
// sem nenhum aviso. Ver AGENTS.md (secao 06/10/2026).
import 'package:flutter_test/flutter_test.dart';
import 'package:prontuario_tcc/utils/sessao_form_helpers.dart';

void main() {
  const anteriores = '1. Artigo antigo\n   https://doi.org/10.1/a';

  test('falha na busca mantem as indicacoes anteriores', () {
    final r = resolverBuscaArtigos(
      artigosBuscados: null,
      artigosAnteriores: anteriores,
    );
    expect(r.falhou, isTrue);
    expect(r.artigos, anteriores);
  });

  test('falha sem indicacoes anteriores deixa vazio e sinaliza', () {
    final r = resolverBuscaArtigos(
      artigosBuscados: null,
      artigosAnteriores: '',
    );
    expect(r.falhou, isTrue);
    expect(r.artigos, isEmpty);
  });

  test('sucesso com resultados substitui os anteriores', () {
    final r = resolverBuscaArtigos(
      artigosBuscados: '1. Artigo novo\n   https://doi.org/10.2/b',
      artigosAnteriores: anteriores,
    );
    expect(r.falhou, isFalse);
    expect(r.artigos, contains('Artigo novo'));
    expect(r.artigos, isNot(contains('Artigo antigo')));
  });

  test('sucesso sem resultados limpa (as antigas eram de outra sintese)', () {
    final r = resolverBuscaArtigos(
      artigosBuscados: '   ',
      artigosAnteriores: anteriores,
    );
    expect(r.falhou, isFalse);
    expect(r.artigos, isEmpty);
  });

  test('normaliza espacos do resultado', () {
    final r = resolverBuscaArtigos(
      artigosBuscados: '  1. Artigo\n  ',
      artigosAnteriores: '',
    );
    expect(r.artigos, '1. Artigo');
  });
}
