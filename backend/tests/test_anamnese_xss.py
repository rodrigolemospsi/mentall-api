"""Testes do fix de stored XSS na anamnese (pentest Strix 28/08 e 30/08).

Vetor 1 (28/08): o `dados_extra` (incl. `abordagem` e `tratamento`) era
injetado sem escape via `json.dumps` dentro de um bloco `<script>` no template
da anamnese. Um valor com `</script><script>...</script>` em `abordagem`
quebrava o script e executava código arbitrário no navegador da vítima.

Vetor 2 (30/08): a renderização client-side (`templates/anamnese.html`) usava
`q.min`/`q.max` interpolados cru em atributos `min=`/`max=` (possível injeção
de atributos como `onfocus`+`autofocus`) e `q.id` interpolado em handler
inline `onclick` sem escapar aspas simples (quebra de string JS). O fix:
coerção numérica de `min`/`max`, `esc()` com escape de aspas simples, e
`toggleYn(this, valor)` lendo o `id` do `data-id` do elemento pai.
"""
import os
import re
import unittest

os.environ.setdefault("JWT_SECRET", "teste-segredo")
os.environ.setdefault("APP_PASSWORD_HASH", "teste-hash")
os.environ.setdefault("SMTP_HOST", "")
os.environ.setdefault("WUZAPI_BASE_URL", "")

import main  # noqa: E402

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
TEMPLATE_PATH = os.path.join(BASE_DIR, "..", "templates", "anamnese.html")


def _template_html() -> str:
    with open(TEMPLATE_PATH, encoding="utf-8") as f:
        return f.read()


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


class TestRenderizacaoClientSideSegura(unittest.TestCase):
    def test_nao_interpola_q_min_q_max_cru(self):
        html = _template_html()
        # `min`/`max` precisam passar por parseInt antes de entrar no atributo.
        self.assertRegex(html, r"parseInt\(q\.min, 10\)")
        self.assertRegex(html, r"parseInt\(q\.max, 10\)")
        self.assertNotIn("var min = q.min", html)
        self.assertNotIn("var max = q.max", html)

    def test_onclick_nao_contem_id_interpolado(self):
        html = _template_html()
        # toggleYn agora recebe apenas o botao; o id vem do data-id do pai.
        self.assertNotIn("toggleYn(\\'", html)
        self.assertNotIn("toggleYn('" , html)
        self.assertRegex(html, r"onclick=\"toggleYn\(this, true\)\"")
        self.assertRegex(html, r"onclick=\"toggleYn\(this, false\)\"")

    def test_toggleYn_resolve_id_pelo_data_id(self):
        html = _template_html()
        self.assertRegex(html, r"toggleYn\(btn, valor\)")
        self.assertRegex(html, r"closest\('\.pergunta'\)")
        self.assertRegex(html, r"getAttribute\('data-id'\)")

    def test_esc_escapa_aspas_simples(self):
        html = _template_html()
        self.assertRegex(html, r"replace\(/'/g, '&#39;'\)")

    def test_escala_coerci_swap_min_max(self):
        html = _template_html()
        self.assertIn("if (min > max)", html)


if __name__ == "__main__":
    unittest.main()
