"""Testes da guarda de schema do resultado da sintese.

Contexto: uma resposta JSON valida mas fora do schema ({} ou {"erro": ...})
era tratada como sucesso com todos os campos clinicos vazios. O app entao
sobrescrevia os campos com vazio e gravava um prontuario em branco, sem erro
visivel. Ver AGENTS.md (secao 06/10/2026).
"""
import unittest

import services.ia_clinica as mod


class TestGuardaDeSchema(unittest.TestCase):
    def test_resposta_completa_e_sucesso(self):
        r = mod._parse_resultado_sucesso({
            "relato_clinico_organizado": "Relato",
            "sintese_clinica": "Sintese",
        })
        self.assertTrue(r["sucesso"])
        self.assertEqual(r["sintese_clinica"], "Sintese")

    def test_objeto_vazio_e_falha(self):
        r = mod._parse_resultado_sucesso({})
        self.assertFalse(r["sucesso"])
        self.assertTrue(r["erro"])

    def test_resposta_so_com_erro_e_falha(self):
        r = mod._parse_resultado_sucesso({"erro": "recusado pelo modelo"})
        self.assertFalse(r["sucesso"])

    def test_recusa_em_texto_e_falha(self):
        r = mod._parse_resultado_sucesso({"resposta": "Nao posso ajudar com isso."})
        self.assertFalse(r["sucesso"])

    def test_campo_so_com_espacos_nao_conta_como_conteudo(self):
        r = mod._parse_resultado_sucesso({"sintese_clinica": "   \n  "})
        self.assertFalse(r["sucesso"])

    def test_temas_pesquisa_sozinho_nao_e_conteudo_clinico(self):
        r = mod._parse_resultado_sucesso({"temas_pesquisa": ["ansiedade"]})
        self.assertFalse(r["sucesso"])

    def test_resposta_parcial_e_sucesso(self):
        r = mod._parse_resultado_sucesso({"plano_proxima_sessao": "Retomar exposicao"})
        self.assertTrue(r["sucesso"])
        self.assertEqual(r["plano_proxima_sessao"], "Retomar exposicao")
        self.assertEqual(r["sintese_clinica"], "")

    def test_campos_sao_normalizados(self):
        r = mod._parse_resultado_sucesso({"sintese_clinica": "  texto  "})
        self.assertEqual(r["sintese_clinica"], "texto")

    def test_temas_pesquisa_preservados(self):
        r = mod._parse_resultado_sucesso({
            "sintese_clinica": "ok",
            "temas_pesquisa": [{"especifico": "ruminacao", "amplo": "ansiedade"}],
        })
        self.assertEqual(r["temas_pesquisa"], [{"especifico": "ruminacao", "amplo": "ansiedade"}])


if __name__ == "__main__":
    unittest.main()
