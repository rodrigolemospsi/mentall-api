"""HTTP contracts, real SQL in memory; run with run_isolated.py."""
import json
import unittest
from unittest.mock import patch

import httpx
import main
from services import anamnese_service as service, db


class AnamnesePublicaTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        db.executar("DELETE FROM anamneses").commit()
        main._rate_limit_store.clear()
        self.token = service.criar_anamnese('{"secoes": []}', "owner-a")
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=main.app), base_url="https://test.invalid")
        self.addAsyncCleanup(self.client.aclose)

    async def post(self, answers):
        return await self.client.post(f"/anamneses/{self.token}/responder",
                                      json={"respostas": json.dumps(answers)})

    async def test_primeira_resposta_publica_minima(self):
        response = await self.post({"relato": "conteudo clinico sintetico"})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"sucesso": True, "status": "respondido"})
        self.assertEqual(response.headers.get("cache-control"), "no-store")

    async def test_resubmissao_nao_revela_nem_sobrescreve(self):
        await self.post({"relato": "conteudo clinico sintetico"})
        response = await self.post({})
        self.assertEqual(response.json(), {"sucesso": True, "status": "respondido"})
        self.assertIn("conteudo clinico", service.obter_anamnese(self.token)["respostas"])

    async def test_get_somente_owner_le_respostas(self):
        await self.post({"relato": "conteudo clinico sintetico"})
        path = f"/anamneses/{self.token}/status"
        unauthorized = await self.client.get(path)
        self.assertIn(unauthorized.status_code, (401, 403))
        for owner, allowed in (("owner-a", True), ("owner-b", False)):
            jwt = main._criar_token_jwt("test@example.invalid", owner)
            response = await self.client.get(path, headers={"Authorization": f"Bearer {jwt}"})
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()["sucesso"], allowed)
            self.assertEqual("conteudo clinico" in response.text, allowed)
            self.assertEqual(response.headers.get("cache-control"), "no-store")

    async def test_status_revogado_ou_expirado_nao_aceita_escrita(self):
        for status in ("revogado", "expirado"):
            db.executar("UPDATE anamneses SET status = ? WHERE token = ?", (status, self.token)).commit()
            response = await self.post({})
            self.assertEqual(response.status_code, 404)
            self.assertIsNone(service.obter_anamnese(self.token)["respostas"])
            page = await self.client.get(f"/anamneses/{self.token}")
            self.assertEqual(page.status_code, 404)
            self.assertEqual(page.headers.get("cache-control"), "no-store")

    async def test_resposta_concorrente_nao_sobrescreve_vencedora(self):
        intercalated = False

        def execute(sql, params=()):
            nonlocal intercalated
            if sql.startswith("UPDATE anamneses SET status") and not intercalated:
                intercalated = True
                service.registrar_resposta(self.token, '{"relato":"vencedora"}')
            return db.executar(sql, params)

        with patch("services.anamnese_service.executar", side_effect=execute):
            response = await self.post({"relato": "perdedora"})
        self.assertTrue(intercalated)
        self.assertEqual(response.json(), {"sucesso": True, "status": "respondido"})
        self.assertEqual(json.loads(service.obter_anamnese(self.token)["respostas"]), {"relato": "vencedora"})
