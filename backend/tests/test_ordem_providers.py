"""Ordem de tentativa dos provedores de texto (sintese e progresso).

O Gemini saiu da cascata em 07/10/2026 (503 em toda a familia Flash, medido).
Estes testes existem para ele NAO voltar por engano ao mexer em secret.
"""
import os
import unittest
from unittest import mock

import services.ia_clinica as mod


class TestOrdemProviders(unittest.TestCase):
    def _ordem(self, valor):
        # None = variavel ausente
        amb = {} if valor is None else {"IA_PROVIDER_ORDER": valor}
        with mock.patch.dict(os.environ, amb, clear=False):
            if valor is None:
                os.environ.pop("IA_PROVIDER_ORDER", None)
            return mod._ordem_providers()

    def test_padrao_e_openai_depois_deepseek(self):
        self.assertEqual(self._ordem(None), ["openai", "deepseek"])

    def test_gemini_e_descartado_mesmo_se_pedido(self):
        # A regressao que este teste protege: alguem poe "gemini,openai"
        # no secret e o provedor que falha volta para a primeira posicao.
        self.assertEqual(self._ordem("gemini,openai"), ["openai"])

    def test_gemini_sozinho_cai_no_padrao(self):
        self.assertEqual(self._ordem("gemini"), ["openai", "deepseek"])

    def test_ordem_invertida_e_respeitada(self):
        self.assertEqual(self._ordem("deepseek,openai"), ["deepseek", "openai"])

    def test_espacos_e_maiusculas_sao_normalizados(self):
        self.assertEqual(self._ordem(" DeepSeek , OpenAI "), ["deepseek", "openai"])

    def test_nome_desconhecido_e_ignorado(self):
        self.assertEqual(self._ordem("openai,anthropic"), ["openai"])

    def test_vazio_cai_no_padrao(self):
        self.assertEqual(self._ordem("   "), ["openai", "deepseek"])

    def test_nao_muta_a_lista_padrao(self):
        # Se devolvesse a propria constante, um caller poderia altera-la.
        a = self._ordem("gemini")
        a.append("gemini")
        self.assertNotIn("gemini", mod.PROVEDORES_DISPONIVEIS)


if __name__ == "__main__":
    unittest.main()
