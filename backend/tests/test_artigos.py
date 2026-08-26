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
            "justificativa": "Relevante para o caso.",
        }]
        out = mod._formatar_artigos(artigos)
        self.assertIn("1. Transtorno de Ansiedade Social (2019, 10 citações) - Autor A; Autor B", out)
        self.assertIn("Relevância: Relevante para o caso.", out)
        self.assertIn("https://doi.org/10.1590/abc", out)

    def test_formata_sem_metadados(self):
        artigos = [{"titulo": "Artigo", "link": "https://openalex.org/W123"}]
        out = mod._formatar_artigos(artigos)
        self.assertIn("1. Artigo", out)
        self.assertIn("https://openalex.org/W123", out)


class TestNormalizarTemas(unittest.TestCase):
    def test_aceita_dicts_e_strings(self):
        temas = [
            {"especifico": "terapia cognitiva ansiedade", "amplo": "ansiedade"},
            "depressão",
        ]
        norm = mod._normalizar_temas(temas)
        self.assertEqual(len(norm), 2)
        self.assertEqual(norm[0], ("terapia cognitiva ansiedade", "ansiedade"))
        self.assertEqual(norm[1], ("depressão", ""))

    def test_ignora_itens_invalidos(self):
        self.assertEqual(mod._normalizar_temas([{"especifico": "  "}]), [])
        self.assertEqual(mod._normalizar_temas([]), [])


if __name__ == "__main__":
    unittest.main()
