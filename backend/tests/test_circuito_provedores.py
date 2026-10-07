"""Circuito por provedor: nao insistir em quem acabou de falhar.

Contexto: em 07/10/2026 a cascata tentava o Gemini a cada sintese e pagava o 503
outra vez, porque nao guardava a falha anterior (ver AGENTS.md).
"""
import unittest

import services.ia_clinica as mod


class TestCircuitoProvedores(unittest.TestCase):
    def setUp(self):
        mod._limpar_estado_provedores()

    def tearDown(self):
        mod._limpar_estado_provedores()

    def test_sem_falhas_todos_disponiveis(self):
        self.assertEqual(mod._provedores_a_tentar(), ["openai", "deepseek"])

    def test_uma_falha_transitoria_ainda_nao_abre(self):
        mod._registrar_falha("openai", "503 UNAVAILABLE")
        self.assertEqual(mod._provedores_a_tentar(), ["openai", "deepseek"])

    def test_duas_falhas_transitorias_abrem_o_circuito(self):
        mod._registrar_falha("openai", "503 UNAVAILABLE")
        mod._registrar_falha("openai", "503 UNAVAILABLE")
        self.assertEqual(mod._provedores_a_tentar(), ["deepseek"])

    def test_falha_dura_abre_de_imediato(self):
        mod._registrar_falha("openai", "429 insufficient_quota: credit_balance_exhausted")
        self.assertEqual(mod._provedores_a_tentar(), ["deepseek"])

    def test_modelo_inexistente_e_falha_dura(self):
        mod._registrar_falha("openai", "403 model_not_found: does not have access to model")
        self.assertEqual(mod._provedores_a_tentar(), ["deepseek"])

    def test_sucesso_limpa_o_circuito(self):
        mod._registrar_falha("openai", "429 insufficient_quota")
        mod._registrar_sucesso("openai")
        self.assertEqual(mod._provedores_a_tentar(), ["openai", "deepseek"])

    def test_falha_transitoria_expira(self):
        mod._registrar_falha("openai", "503")
        mod._registrar_falha("openai", "503")
        mod._estado_provedores["openai"]["quando"] -= mod.CIRCUITO_SOFT_SEGUNDOS + 1
        self.assertIn("openai", mod._provedores_a_tentar())

    def test_falha_dura_expira_na_janela_longa(self):
        mod._registrar_falha("openai", "insufficient_quota")
        self.assertNotIn("openai", mod._provedores_a_tentar())
        mod._estado_provedores["openai"]["quando"] -= mod.CIRCUITO_HARD_SEGUNDOS + 1
        self.assertIn("openai", mod._provedores_a_tentar())

    def test_todos_abertos_deixa_uma_tentativa(self):
        mod._registrar_falha("openai", "insufficient_quota")
        mod._registrar_falha("deepseek", "insufficient_quota")
        self.assertEqual(mod._provedores_a_tentar(), ["openai"])

    def test_o_pulado_nao_aparece(self):
        mod._registrar_falha("deepseek", "insufficient_quota")
        self.assertNotIn("deepseek", mod._provedores_a_tentar())

    def test_falha_de_um_nao_afeta_o_outro(self):
        mod._registrar_falha("openai", "insufficient_quota")
        self.assertTrue(mod._provedor_disponivel("deepseek"))
        self.assertFalse(mod._provedor_disponivel("openai"))


if __name__ == "__main__":
    unittest.main()
