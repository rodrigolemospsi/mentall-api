"""Criptografia ponta-a-ponta da anamnese (envelope AES-256-GCM no servidor)."""
import base64
import json
import unittest

import httpx
import main
from services import anamnese_service as service, db

TEMPLATE = json.dumps({"secoes": [{"perguntas": []}]})


def envelope(ct_bytes: bytes = b"x" * 48):
    iv = base64.b64encode(b"\x01" * 12).decode()
    ct = base64.b64encode(ct_bytes).decode()
    return {"cifrada": True, "iv": iv, "ct": ct}


class AnamneseE2ETests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        db.executar("DELETE FROM anamneses").commit()
        main._rate_limit_store.clear()
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=main.app), base_url="https://test.invalid")
        self.addAsyncCleanup(self.client.aclose)
        self.owner = "owner-e2e"
        self.jwt = main._criar_token_jwt("e2e@example.invalid", self.owner)
        self.headers = {"Authorization": f"Bearer {self.jwt}"}

    # -- criação -----------------------------------------------------------
    async def test_criar_e2e_pela_api_marca_flag_no_banco(self):
        response = await self.client.post(
            "/anamneses",
            headers=self.headers,
            json={
                "template_json": TEMPLATE,
                "abordagem": "TCC",
                "nome_paciente": "Paciente Teste",
                "nome_profissional": "Profissional Teste",
                "registro": "06/123456",
                "e2e": True,
            },
        )
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertTrue(body["sucesso"])
        armazenada = service.obter_anamnese(body["token"])
        self.assertTrue(armazenada["e2e"])
        self.assertFalse(armazenada["cifrada"])
        # A chave NUNCA vai ao servidor: o payload de criação não tem chave.
        self.assertNotIn("k=", body["url"])

    async def test_criar_sem_e2e_mantem_compatibilidade(self):
        response = await self.client.post(
            "/anamneses",
            headers=self.headers,
            json={
                "template_json": TEMPLATE,
                "abordagem": "TCC",
                "nome_paciente": "Paciente Teste",
                "nome_profissional": "Profissional Teste",
            },
        )
        self.assertEqual(response.status_code, 200)
        armazenada = service.obter_anamnese(response.json()["token"])
        self.assertFalse(armazenada["e2e"])

    # -- submissão cifrada -------------------------------------------------
    async def test_submissao_cifrada_e_armazenada_como_envelope(self):
        token = service.criar_anamnese(TEMPLATE, self.owner, e2e=True)
        env = envelope()
        response = await self.client.post(f"/anamneses/{token}/responder", json=env)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"sucesso": True, "status": "respondido"})

        armazenada = service.obter_anamnese(token)
        self.assertEqual(armazenada["status"], "respondido")
        self.assertTrue(armazenada["cifrada"])
        envelope_salvo = json.loads(armazenada["respostas"])
        self.assertEqual(envelope_salvo["alg"], "A256GCM")
        self.assertEqual(envelope_salvo["v"], 1)
        self.assertEqual(envelope_salvo["iv"], env["iv"])
        self.assertEqual(envelope_salvo["ct"], env["ct"])
        # Nada de texto claro do conteúdo no banco.
        self.assertNotIn("relato", armazenada["respostas"])

    async def test_status_entrega_envelope_ao_dono_sem_texto_claro(self):
        token = service.criar_anamnese(TEMPLATE, self.owner, e2e=True)
        env = envelope()
        await self.client.post(f"/anamneses/{token}/responder", json=env)

        response = await self.client.get(
            f"/anamneses/{token}/status", headers=self.headers)
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertTrue(body["sucesso"])
        self.assertTrue(body["cifrada"])
        self.assertEqual(body["iv"], env["iv"])
        self.assertEqual(body["ct"], env["ct"])
        self.assertEqual(body["respostas_json"], "")

        # Outro dono não lê.
        outro = main._criar_token_jwt("outro@example.invalid", "owner-outro")
        negado = await self.client.get(
            f"/anamneses/{token}/status",
            headers={"Authorization": f"Bearer {outro}"},
        )
        self.assertEqual(negado.status_code, 200)
        self.assertFalse(negado.json()["sucesso"])

    async def test_ficha_e2e_recusa_submissao_em_texto_claro(self):
        token = service.criar_anamnese(TEMPLATE, self.owner, e2e=True)
        response = await self.client.post(
            f"/anamneses/{token}/responder",
            json={"respostas": json.dumps({"relato": "conteudo clinico"})},
        )
        self.assertEqual(response.status_code, 422)
        self.assertIn("ponta a ponta", response.json()["detail"])
        armazenada = service.obter_anamnese(token)
        self.assertEqual(armazenada["status"], "pendente")
        self.assertIsNone(armazenada["respostas"])

    async def test_payload_cifrado_invalido_rejeitado(self):
        token = service.criar_anamnese(TEMPLATE, self.owner, e2e=True)
        invalidos = [
            {"cifrada": True, "iv": "", "ct": ""},
            {"cifrada": True, "iv": base64.b64encode(b"curto").decode(),
             "ct": base64.b64encode(b"x" * 48).decode()},
            {"cifrada": True, "iv": base64.b64encode(b"\x01" * 12).decode(),
             "ct": "***nao-base64***"},
            {"cifrada": True, "iv": base64.b64encode(b"\x01" * 12).decode(),
             "ct": base64.b64encode(b"x").decode()},
        ]
        for payload in invalidos:
            with self.subTest(payload=payload):
                response = await self.client.post(
                    f"/anamneses/{token}/responder", json=payload)
                self.assertEqual(response.status_code, 422)
        self.assertEqual(service.obter_anamnese(token)["status"], "pendente")

    async def test_reenvio_cifrado_nao_sobrescreve_resposta(self):
        token = service.criar_anamnese(TEMPLATE, self.owner, e2e=True)
        primeiro = envelope(b"a" * 48)
        await self.client.post(f"/anamneses/{token}/responder", json=primeiro)
        segundo = envelope(b"b" * 48)
        response = await self.client.post(f"/anamneses/{token}/responder", json=segundo)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "respondido")
        salvo = json.loads(service.obter_anamnese(token)["respostas"])
        self.assertEqual(salvo["ct"], primeiro["ct"])

    # -- compatibilidade legada -------------------------------------------
    async def test_ficha_legada_continua_aceitando_texto_claro(self):
        token = service.criar_anamnese(TEMPLATE, self.owner)
        response = await self.client.post(
            f"/anamneses/{token}/responder",
            json={"respostas": json.dumps({"relato": "legado"})},
        )
        self.assertEqual(response.status_code, 200)
        armazenada = service.obter_anamnese(token)
        self.assertFalse(armazenada["cifrada"])
        self.assertEqual(json.loads(armazenada["respostas"]), {"relato": "legado"})
        status = await self.client.get(
            f"/anamneses/{token}/status", headers=self.headers)
        self.assertFalse(status.json()["cifrada"])
        self.assertIn("legado", status.json()["respostas_json"])

    # -- página pública ----------------------------------------------------
    async def test_pagina_marca_e2e_conforme_a_ficha(self):
        e2e_token = service.criar_anamnese(TEMPLATE, self.owner, e2e=True)
        legado_token = service.criar_anamnese(TEMPLATE, self.owner)
        pagina_e2e = await self.client.get(f"/anamneses/{e2e_token}")
        self.assertEqual(pagina_e2e.status_code, 200)
        self.assertIn("const E2E = true;", pagina_e2e.text)
        # A chave nunca chega ao servidor: só existe no fragmento do link,
        # criado pelo app; a página servida é a mesma para todos os pacientes.
        self.assertNotIn("const E2E = false;", pagina_e2e.text)
        pagina_legado = await self.client.get(f"/anamneses/{legado_token}")
        self.assertIn("const E2E = false;", pagina_legado.text)


if __name__ == "__main__":
    unittest.main()
