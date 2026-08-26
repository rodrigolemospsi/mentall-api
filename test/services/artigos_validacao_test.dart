import 'package:flutter_test/flutter_test.dart';

import 'package:prontuario_tcc/utils/artigos_validacao.dart';

void main() {
  group('limparArtigosAntigos', () {
    test('limpa formato antigo com "Título:" e "Link:"', () {
      const antigo =
          '1. Título: Estudo sobre ansiedade Link: https://bit.ly/xyz\n'
          '2. Título: Outro estudo Link: https://exemplo.com/falso';
      expect(limparArtigosAntigos(antigo), '');
    });

    test('limpa formato antigo com "Acesse:"', () {
      const antigo =
          '1. Título: Pesquisa qualquer\n   Acesse: https://bit.ly/fake';
      expect(limparArtigosAntigos(antigo), '');
    });

    test('mantem artigos novos (doi.org)', () {
      const novo =
          '1. Transtorno de Ansiedade Social (2019) - Autor\n'
          '   Relevância: relacionado ao caso.\n'
          '   https://doi.org/10.1590/abc';
      expect(limparArtigosAntigos(novo), novo);
    });

    test('mantem artigos novos (openalex.org)', () {
      const novo = '1. Artigo Real (2020) - Autor\n   https://openalex.org/W123';
      expect(limparArtigosAntigos(novo), novo);
    });

    test('mantem fallback de busca sugerida', () {
      const fallback =
          'Busca sugerida 1: Ansiedade social\n'
          '   SciELO: https://search.scielo.org/?q=ansiedade&lang=pt\n'
          '   Periódicos CAPES: https://www.periodicos.capes.gov.br/buscar?q=ansiedade';
      expect(limparArtigosAntigos(fallback), fallback);
    });

    test('retorna vazio para null', () {
      expect(limparArtigosAntigos(null), '');
      expect(limparArtigosAntigos(''), '');
    });
  });

  group('pareceFormatoAntigo', () {
    test('detecta apenas numeracao sem link confiavel', () {
      expect(pareceFormatoAntigo('1. Qualquer coisa inventada'), isTrue);
    });

    test('nao marca texto com link confiavel', () {
      expect(
        pareceFormatoAntigo(
            '1. Artigo\n   https://doi.org/10.1590/abc'),
        isFalse,
      );
      expect(
        pareceFormatoAntigo('1. Artigo\n   https://openalex.org/W123'),
        isFalse,
      );
    });
  });
}
