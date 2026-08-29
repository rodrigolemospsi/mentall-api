"""Testes do fix de stored XSS na anamnese (pentest Strix 28/08).

O `dados_extra` (incl. `abordagem` e `tratamento`) era injetado sem escape
via `json.dumps` dentro de um bloco `<script>` no template da anamnese. Um
valor com `</script><script>...</script>` em `abordagem` quebrava o script
e executava código arbitrário no navegador da vítima.
"""
import os
import unittest

os.environ.setdefault("JWT_SECRET", "teste-segredo")
os.environ.setdefault("APP_PASSWORD_HASH", "teste-hash")
os.environ.setdefault("SMTP_HOST", "")
os.environ.setdefault("WUZAPI_BASE_URL", "")

import main  # noqa: E402


class TestJsonScriptSeguro(unittest.TestCase):
    def test_escapa_chaves_menor_maior_ampersand(self):
        payload = {"abordagem": "</script><script>alert(1)</script>"}
        saida = main._json_script_seguro(payload)
        self.assertNotIn("</script>", saida)
        self.assertNotIn("<script>", saida)
        self.assertIn("\\u003c", saida)

    def test_json_segue_valido(self):
        import json
        payload = {"a": "</script>", "b": "&", "c": ">", "nome": "João"}
        saida = main._json_script_seguro(payload)
        obj = json.loads(saida)
        self.assertEqual(obj["a"], "</script>")
        self.assertEqual(obj["b"], "&")
        self.assertEqual(obj["nome"], "João")

    def test_nulos_e_listas(self):
        saida = main._json_script_seguro({"x": None, "y": [1, 2]})
        self.assertIn("null", saida)
        self.assertIn("[1, 2]", saida)

    def test_dados_da_anamnese_nao_quebram_script(self):
        dados = {
            "nome_paciente": "Maria",
            "nome_profissional": "Dr. Fulano",
            "registro": "CRP 06/12345",
            "abordagem": '"></script><script>alert("x")</script>',
            "tratamento": "feminino",
            "crp_verificado": True,
        }
        html = main._montar_pagina_anamnese_script(dados)
        self.assertNotIn("</script><script>", html)
        self.assertNotIn('"></script>', html)


if __name__ == "__main__":
    unittest.main()
