"""Relevância das indicações de artigos: pares de descritores + crivo por metadado.

Contexto (medido em 07/10/2026): o extrator empilhava 3 conceitos numa consulta,
a base devolvia ZERO, e o fallback para um termo amplo trazia homônimos
("Inventário de Depressão Maior"). Ver AGENTS.md.
"""
import os
import unittest
from unittest import mock

import services.ia_clinica as mod


class TestCrivoTratamento(unittest.TestCase):
    def test_artigo_de_instrumento_e_recusado(self):
        c = {"keywords": ["Major Depression Inventory", "psychometric validation"]}
        self.assertFalse(mod._tem_sinal_tratamento(c))

    def test_artigo_de_tratamento_e_aceito(self):
        c = {"keywords": ["cognitive behavioral therapy", "treatment efficacy"]}
        self.assertTrue(mod._tem_sinal_tratamento(c))

    def test_sem_keywords_usa_o_resumo(self):
        c = {"keywords": [], "palavras_resumo": "cbt therapy randomized controlled trial"}
        self.assertTrue(mod._tem_sinal_tratamento(c))

    def test_sem_metadado_nenhum_e_recusado(self):
        self.assertFalse(mod._tem_sinal_tratamento({}))

    def test_marcas_configuraveis_por_env(self):
        with mock.patch.dict(os.environ, {"IA_ARTIGOS_SINAL_TRATAMENTO": "acolhimento"}):
            self.assertTrue(mod._tem_sinal_tratamento({"keywords": ["acolhimento"]}))
            self.assertFalse(mod._tem_sinal_tratamento({"keywords": ["therapy"]}))


class TestBuscaPorPares(unittest.TestCase):
    DESCRITORES = [
        {"especifico": "terapia cognitivo-comportamental"},
        {"especifico": "depressão maior"},
        {"especifico": "idoso"},
    ]

    def test_consulta_cada_par_e_nunca_os_tres(self):
        chamadas = []

        def fake(consulta, *a, **k):
            chamadas.append(consulta)
            return []

        with mock.patch.object(mod, "_buscar_candidatos_openalex", side_effect=fake):
            mod._montar_artigos(self.DESCRITORES)

        self.assertIn("terapia cognitivo-comportamental depressão maior", chamadas)
        self.assertIn("terapia cognitivo-comportamental idoso", chamadas)
        self.assertIn("depressão maior idoso", chamadas)
        for c in chamadas:
            casados = sum(1 for d in ("terapia cognitivo-comportamental", "depressão maior", "idoso") if d in c)
            self.assertLessEqual(casados, 2, "nenhuma consulta pode juntar os tres conceitos")

    def test_sem_aprovado_usa_buscas_sugeridas(self):
        ruim = [{"id": "W1", "titulo": "Inventário de Depressão Maior",
                 "link": "https://doi.org/10.1/x", "keywords": ["psychometric validation"]}]
        with mock.patch.object(mod, "_buscar_candidatos_openalex", return_value=ruim):
            saida = mod._montar_artigos([{"especifico": "depressão maior"}])
        self.assertIn("Busca sugerida", saida)
        self.assertNotIn("Inventário", saida)

    def test_aprovado_e_formatado(self):
        bom = [{"id": "W2", "titulo": "TCC da depressão", "link": "https://doi.org/10.2/y",
                "ano": 2020, "citacoes": 3, "autores": "A. Autor",
                "keywords": ["cognitive behavioral therapy"]}]
        with mock.patch.object(mod, "_buscar_candidatos_openalex", return_value=bom):
            saida = mod._montar_artigos([{"especifico": "depressão maior"}])
        self.assertIn("TCC da depressão", saida)
        self.assertNotIn("Busca sugerida", saida)

    def test_quem_casa_mais_pares_vem_primeiro(self):
        um_par = {"id": "W1", "titulo": "So o primeiro par", "link": "https://doi.org/10.1/a",
                  "keywords": ["therapy"]}
        dois_pares = {"id": "W2", "titulo": "Casa dois pares", "link": "https://doi.org/10.2/b",
                      "keywords": ["therapy"]}

        def fake(consulta, *a, **k):
            if consulta == "terapia cognitivo-comportamental depressão maior":
                return [um_par, dois_pares]
            return [dois_pares]

        with mock.patch.object(mod, "_buscar_candidatos_openalex", side_effect=fake):
            saida = mod._montar_artigos(self.DESCRITORES)
        self.assertLess(saida.index("Casa dois pares"), saida.index("So o primeiro par"))


if __name__ == "__main__":
    unittest.main()
