"""Testes das indicacoes de artigos cientificos (anti-alucinacao).

Cobrem:
1. `_montar_artigos_sugeridos` (fallback) usa rotulo "Busca sugerida:" em vez
   de um titulo numerado que parecia artigo inventado.
2. `_formatar_artigos` gera titulos/links reais no formato esperado pelo app.
3. `_normalizar_temas` aceita dicts e strings.
"""
import unittest

import services.ia_clinica as mod


class TestFallbackArtigos(unittest.TestCase):
    def test_fallback_usa_rotulo_busca_sugerida(self):
        out = mod._montar_artigos_sugeridos(["ansiedade social", "terapia cognitiva"])
        self.assertIn("Busca sugerida 1: Ansiedade social", out)
        self.assertIn("Busca sugerida 2: Terapia cognitiva", out)
        # Nao deve parecer titulo de artigo ("1. Tema")
        self.assertNotRegex(out, r"^1\.\s+[A-Za-z]")
        self.assertIn("SciELO: https://search.scielo.org", out)
        self.assertIn("Periódicos CAPES: https://", out)

    def test_fallback_com_string_plana(self):
        out = mod._montar_artigos_sugeridos(["ansiedade social"])
        self.assertIn("Busca sugerida 1: Ansiedade social", out)
        self.assertIn("Oasisbr: https://oasisbr.ibict.br", out)

    def test_fallback_vazio_sem_temas(self):
        self.assertEqual(mod._montar_artigos_sugeridos([]), "")
        self.assertEqual(mod._montar_artigos_sugeridos(None), "")
        self.assertEqual(mod._montar_artigos_sugeridos(["   "]), "")


class TestFormatarArtigos(unittest.TestCase):
    def test_formata_titulo_metadados_e_link(self):
        artigos = [{
            "titulo": "Transtorno de Ansiedade Social",
            "ano": 2019,
            "citacoes": 10,
            "autores": "Autor A; Autor B",
            "link": "https://doi.org/10.1590/abc",
        }]
        out = mod._formatar_artigos(artigos)
        self.assertIn("1. Transtorno de Ansiedade Social (2019, 10 citações) - Autor A; Autor B", out)
        self.assertIn("https://doi.org/10.1590/abc", out)

    def test_formata_sem_metadados(self):
        artigos = [{"titulo": "Artigo", "link": "https://openalex.org/W123"}]
        out = mod._formatar_artigos(artigos)
        self.assertIn("1. Artigo", out)
        self.assertIn("https://openalex.org/W123", out)


class TestNormalizarTemas(unittest.TestCase):
    def test_aceita_dicts_e_strings_na_ordem(self):
        norm = mod._normalizar_temas([
            {"especifico": "terapia cognitivo-comportamental", "amplo": ""},
            {"especifico": "depressão maior", "amplo": ""},
            "idoso",
        ])
        self.assertEqual(
            norm, ["terapia cognitivo-comportamental", "depressão maior", "idoso"])

    def test_expande_sigla_homonima(self):
        # "TCC" traz majoritariamente "Trabalho de Conclusão de Curso" na base.
        self.assertEqual(mod._normalizar_temas(["TCC"]), ["terapia cognitivo-comportamental"])
        self.assertEqual(mod._normalizar_temas(["act"]), ["terapia de aceitação e compromisso"])

    def test_limita_a_tres_descritores(self):
        self.assertEqual(len(mod._normalizar_temas(["a", "b", "c", "d"])), 3)

    def test_usa_amplo_quando_especifico_vazio(self):
        self.assertEqual(mod._normalizar_temas([{"amplo": "luto"}]), ["luto"])

    def test_ignora_itens_invalidos(self):
        self.assertEqual(mod._normalizar_temas([{"especifico": "  "}]), [])
        self.assertEqual(mod._normalizar_temas([]), [])


if __name__ == "__main__":
    unittest.main()
