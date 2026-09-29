"""Telemetria (Fase 2): heartbeat online/offline + eventos de uso.

Regra LGPD: a nuvem só recebe números (owner_id, device_id, plataforma, versão,
tipo de evento) — nunca nome de paciente nem conteúdo clínico.
"""
import unittest

import httpx

import main
from services import db, telemetria


class TelemetriaServiceTests(unittest.TestCase):
    def setUp(self):
        db.executar("DELETE FROM dispositivos").commit()
        db.executar("DELETE FROM eventos").commit()

    def test_heartbeat_insere_e_atualiza(self):
        telemetria.registrar_heartbeat("owner-a", "dev-12345678", "android", "1.0.42")
        row = db.executar(
            "SELECT * FROM dispositivos WHERE device_id = ?", ("dev-12345678",)
        ).fetchone()
        self.assertEqual(row["owner_id"], "owner-a")
        self.assertEqual(row["plataforma"], "android")

        # Segundo heartbeat atualiza (não duplica).
        telemetria.registrar_heartbeat("owner-a", "dev-12345678", "android", "1.0.43")
        total = db.executar("SELECT COUNT(*) AS c FROM dispositivos").fetchone()["c"]
        self.assertEqual(total, 1)
        row2 = db.executar(
            "SELECT versao_app FROM dispositivos WHERE device_id = ?", ("dev-12345678",)
        ).fetchone()
        self.assertEqual(row2["versao_app"], "1.0.43")

    def test_evento_aceita_tipo_permitido(self):
        self.assertTrue(telemetria.registrar_evento("owner-a", "dev-12345678", "sintese"))
        row = db.executar(
            "SELECT * FROM eventos WHERE owner_id = ?", ("owner-a",)
        ).fetchone()
        self.assertEqual(row["tipo"], "sintese")

    def test_evento_rejeita_tipo_desconhecido(self):
        self.assertFalse(telemetria.registrar_evento("owner-a", "dev-12345678", "nome_paciente"))
        total = db.executar("SELECT COUNT(*) AS c FROM eventos").fetchone()["c"]
        self.assertEqual(total, 0)


class TelemetriaHttpTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        db.executar("DELETE FROM dispositivos").commit()
        db.executar("DELETE FROM eventos").commit()
        main._rate_limit_store.clear()
        self.jwt = main._criar_token_jwt("psi@exemplo.com", "owner-a")
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=main.app), base_url="https://test.invalid")
        self.addAsyncCleanup(self.client.aclose)

    def _auth(self):
        return {"Authorization": f"Bearer {self.jwt}"}

    async def test_heartbeat_exige_autenticacao(self):
        r = await self.client.post("/telemetria/heartbeat", json={"device_id": "dev-12345678"})
        self.assertEqual(r.status_code, 401)

    async def test_heartbeat_grava_owner_do_token(self):
        r = await self.client.post(
            "/telemetria/heartbeat",
            json={"device_id": "dev-12345678", "plataforma": "android", "versao_app": "1.0.42"},
            headers=self._auth(),
        )
        self.assertEqual(r.status_code, 200)
        row = db.executar(
            "SELECT owner_id FROM dispositivos WHERE device_id = ?", ("dev-12345678",)
        ).fetchone()
        self.assertEqual(row["owner_id"], "owner-a")

    async def test_evento_aceito_e_gravado(self):
        r = await self.client.post(
            "/telemetria/evento",
            json={"device_id": "dev-12345678", "tipo": "transcricao"},
            headers=self._auth(),
        )
        self.assertEqual(r.status_code, 200)
        total = db.executar("SELECT COUNT(*) AS c FROM eventos").fetchone()["c"]
        self.assertEqual(total, 1)

    async def test_evento_tipo_invalido_422(self):
        r = await self.client.post(
            "/telemetria/evento",
            json={"device_id": "dev-12345678", "tipo": "conteudo_clinico"},
            headers=self._auth(),
        )
        self.assertEqual(r.status_code, 422)

    async def test_lgpd_campo_extra_rejeitado(self):
        # Tentar enviar PII (nome de paciente) deve ser rejeitado pelo schema.
        r = await self.client.post(
            "/telemetria/evento",
            json={"device_id": "dev-12345678", "tipo": "sintese", "nome_paciente": "Maria"},
            headers=self._auth(),
        )
        self.assertEqual(r.status_code, 422)


if __name__ == "__main__":
    unittest.main()
