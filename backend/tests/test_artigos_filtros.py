"""Testes da cascata de filtros da busca de artigos (OpenAlex).

A ORDEM importa: preferimos periodico (tira repositorio e agregador), mas se o
filtro mais restrito zerar a consulta a busca precisa degradar para o proximo em
vez de devolver nada. Ver AGENTS.md (secao 06/10/2026, qualidade das indicacoes).
"""
import unittest
from unittest import mock

import services.ia_clinica as mod


class _Resp:
    def __init__(self, results):
        self.status_code = 200
        self._results = results

    def json(self):
        return {"results": self._results}


def _work(titulo):
    return {
        "id": "https://openalex.org/W1",
        "title": titulo,
        "doi": "https://doi.org/10.1/x",
        "publication_year": 2020,
        "cited_by_count": 3,
        "authorships": [{"author": {"display_name": "A. Autor"}}],
    }


class TestCascataFiltros(unittest.TestCase):
    def _rodar(self, respostas):
        chamados = []

        def fake_get(url, params=None, timeout=None):
            chamados.append(params["filter"])
            return respostas[len(chamados) - 1]

        with mock.patch.object(mod.requests, "get", side_effect=fake_get):
            candidatos = mod._buscar_candidatos_openalex("ruminacao")
        return chamados, candidatos

    def test_primeiro_filtro_prefere_periodico(self):
        chamados, candidatos = self._rodar([_Resp([_work("A")])])
        self.assertEqual(len(chamados), 1)
        self.assertIn("primary_location.source.type:journal", chamados[0])
        self.assertIn("fields/32", chamados[0])
        self.assertEqual(candidatos[0]["titulo"], "A")

    def test_cai_para_psicologia_quando_periodico_zera(self):
        chamados, candidatos = self._rodar([_Resp([]), _Resp([_work("B")])])
        self.assertEqual(len(chamados), 2)
        self.assertIn("primary_location.source.type:journal", chamados[0])
        self.assertNotIn("primary_location.source.type:journal", chamados[1])
        self.assertIn("fields/32", chamados[1])
        self.assertEqual(candidatos[0]["titulo"], "B")

    def test_cai_para_qualquer_area_no_ultimo(self):
        chamados, candidatos = self._rodar([_Resp([]), _Resp([]), _Resp([_work("C")])])
        self.assertEqual(len(chamados), 3)
        self.assertNotIn("fields/32", chamados[2])
        self.assertEqual(candidatos[0]["titulo"], "C")

    def test_sem_resultado_em_nenhum_filtro_devolve_vazio(self):
        chamados, candidatos = self._rodar([_Resp([]), _Resp([]), _Resp([])])
        self.assertEqual(len(chamados), 3)
        self.assertEqual(candidatos, [])

    def test_candidato_nao_carrega_mais_resumo(self):
        _, candidatos = self._rodar([_Resp([_work("A")])])
        self.assertNotIn("resumo", candidatos[0])


if __name__ == "__main__":
    unittest.main()
