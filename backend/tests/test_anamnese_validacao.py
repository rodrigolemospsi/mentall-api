"""Synthetic templates: unanswered is not false/zero; server enforces required fields."""
import json
import unittest

import httpx
import main
from services import anamnese_service as service, db


class AnamneseValidacaoTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        db.executar("DELETE FROM anamneses").commit()
        main._rate_limit_store.clear()
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=main.app), base_url="https://test.invalid")
        self.addAsyncCleanup(self.client.aclose)

    async def submit(self, questions, answers, raw=False):
        token = service.criar_anamnese(json.dumps({"secoes": [{"perguntas": questions}]}), "owner")
        response = await self.client.post(f"/anamneses/{token}/responder", json={
            "respostas": answers if raw else json.dumps(answers)})
        return response, service.obter_anamnese(token)

    async def test_obrigatorios_ausentes_nao_persistem(self):
        for kind in ("yesno", "scale", "text", "textarea", "date", "radio", "checklist"):
            with self.subTest(kind=kind):
                response, stored = await self.submit([{"id": "q", "tipo": kind, "required": True}], {})
                self.assertEqual(response.status_code, 422)
                self.assertEqual(stored["status"], "pendente")
                self.assertIsNone(stored["respostas"])

    async def test_false_e_zero_explicitos_sao_validos(self):
        response, stored = await self.submit([
            {"id": "risco", "tipo": "yesno", "required": True},
            {"id": "intensidade", "tipo": "scale", "required": True, "min": 0, "max": 10},
        ], {"risco": False, "intensidade": 0})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(json.loads(stored["respostas"]), {"risco": False, "intensidade": 0})

    async def test_tipos_invalidos_nao_passam_por_resposta(self):
        for kind, value in (("yesno", "false"), ("yesno", 0), ("scale", True),
                            ("scale", "5"), ("scale", 11), ("scale", float("nan")),
                            ("text", {}), ("text", "  "), ("date", "2026-02-30"),
                            ("radio", "inexistente"), ("checklist", ["inexistente"])):
            with self.subTest(kind=kind, value=value):
                response, stored = await self.submit([
                    {"id": "q", "tipo": kind, "required": True, "opcoes": ["opcao"]}
                ], {"q": value})
                self.assertEqual(response.status_code, 422)
                self.assertEqual(stored["status"], "pendente")

    async def test_json_invalido_ou_nao_objeto_rejeitado(self):
        for value in ("{invalid}", "[]", "null", '"text"'):
            response, stored = await self.submit([], value, raw=True)
            self.assertEqual(response.status_code, 422)
            self.assertIsNone(stored["respostas"])

    async def test_inteiro_extremo_rejeitado_sem_erro_500(self):
        response, stored = await self.submit([
            {"id": "q", "tipo": "scale", "required": True}
        ], {"q": 10 ** 400})
        self.assertEqual(response.status_code, 422)
        self.assertIsNone(stored["respostas"])

    async def test_opcionais_vazios_e_condicional_oculto_omitidos(self):
        response, stored = await self.submit([
            {"id": "medicacao", "tipo": "yesno", "condicional_sim": {
                "id": "quais", "tipo": "text", "required": True}},
            {"id": "texto", "tipo": "text"}, {"id": "lista", "tipo": "checklist"},
            {"id": "escala", "tipo": "scale"},
        ], {"medicacao": False, "quais": "resposta antiga oculta", "texto": "  ", "lista": []})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(json.loads(stored["respostas"]), {"medicacao": False})

    async def test_condicional_visivel_obrigatorio_validado(self):
        questions = [{"id": "medicacao", "tipo": "yesno", "condicional_sim": {
            "id": "quais", "tipo": "text", "required": True}}]
        response, _ = await self.submit(questions, {"medicacao": True})
        self.assertEqual(response.status_code, 422)
        response, stored = await self.submit(questions, {"medicacao": True, "quais": "sintetica"})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(json.loads(stored["respostas"])["quais"], "sintetica")
