"""Testes do retry para indisponibilidade transitoria dos provedores de IA.

Contexto: um 503 do Gemini derrubava a busca de artigos e a geracao de progresso
sem nenhuma retentativa, e o log rotulava tudo como "JSON error" — rotulo
enganoso. Ver AGENTS.md (secao 06/10/2026).
"""
import json
import unittest
from unittest import mock

import services.ia_clinica as mod


class _Erro503(Exception):
    """Imita google.genai.errors.ServerError, que expoe .code."""

    def __init__(self, mensagem="503 UNAVAILABLE. high demand"):
        super().__init__(mensagem)
        self.code = 503


class TestClassificacaoTransitorio(unittest.TestCase):
    def test_status_transitorios_sao_retentaveis(self):
        for status in (408, 429, 500, 502, 503, 504):
            e = Exception("falhou")
            e.code = status
            self.assertTrue(mod._erro_transitorio(e), "status %s" % status)

    def test_status_transitorio_no_atributo_status_code(self):
        e = Exception("falhou")
        e.status_code = 503
        self.assertTrue(mod._erro_transitorio(e))

    def test_status_no_texto_e_detectado(self):
        self.assertTrue(mod._erro_transitorio(Exception("ServerError: 503 UNAVAILABLE.")))

    def test_erro_de_formato_nao_e_retentavel(self):
        self.assertFalse(mod._erro_transitorio(json.JSONDecodeError("x", "y", 0)))

    def test_erro_de_conexao_e_retentavel(self):
        self.assertTrue(mod._erro_transitorio(ConnectionError("caiu")))
        self.assertTrue(mod._erro_transitorio(TimeoutError("demorou")))

    def test_erro_sem_status_nao_e_retentavel(self):
        self.assertFalse(mod._erro_transitorio(ValueError("parametro invalido")))


class TestRetry(unittest.TestCase):
    def test_retenta_e_tem_sucesso_na_segunda(self):
        tentativas = []

        def tentar():
            tentativas.append(1)
            if len(tentativas) < 2:
                raise _Erro503()
            return {"sucesso": True}

        with mock.patch("time.sleep") as dormir:
            resultado = mod._executar_com_retry("Teste", tentar)
        self.assertEqual(resultado, {"sucesso": True})
        self.assertEqual(len(tentativas), 2)
        self.assertEqual(dormir.call_count, 1)

    def test_desiste_apos_o_maximo_de_tentativas(self):
        tentativas = []

        def tentar():
            tentativas.append(1)
            raise _Erro503()

        with mock.patch("time.sleep"):
            resultado = mod._executar_com_retry("Teste", tentar)
        self.assertEqual(len(tentativas), mod.MAX_TENTATIVAS_LLM)
        self.assertFalse(resultado["sucesso"])
        self.assertIn("503", resultado["erro"])

    def test_erro_nao_transitorio_nao_retenta_nem_dorme(self):
        tentativas = []

        def tentar():
            tentativas.append(1)
            raise ValueError("nao adianta repetir")

        with mock.patch("time.sleep") as dormir:
            resultado = mod._executar_com_retry("Teste", tentar)
        self.assertEqual(len(tentativas), 1)
        self.assertEqual(dormir.call_count, 0)
        self.assertFalse(resultado["sucesso"])

    def test_contrato_de_sucesso_preservado(self):
        self.assertEqual(mod._executar_com_retry("Teste", lambda: {"selecionados": []}),
                         {"selecionados": []})


if __name__ == "__main__":
    unittest.main()
