"""Frente C: listar/cancelar lembretes do proprio owner (evita IDOR e permite
limpar orfaos). Roda com o runner isolado (sem rede/dotenv/DB real)."""
import unittest

import httpx

import main
from services import db

OWNER_A = "owner-aaaaaaaa"
OWNER_B = "owner-bbbbbbbb"


def _insert(rid, owner_id, compromisso_id, status="pendente", horario="2026-11-15T18:00:00+00:00"):
    db.executar(
        "INSERT INTO lembretes "
        "(id, compromisso_id, telefone, mensagem, horario_envio, canal, status, owner_id, criado_em) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (rid, compromisso_id, "+5575992298347", "Sessao amanha", horario, "whatsapp",
         status, owner_id, "2026-09-30T00:00:00+00:00"),
    ).commit()


def _token(owner_id):
    return main._criar_token_jwt(f"{owner_id}@ex.com", owner_id)


def _auth(owner_id):
    return {"Authorization": f"Bearer {_token(owner_id)}"}


class LembretesListTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        db.executar("DELETE FROM lembretes").commit()
        main._rate_limit_store.clear()
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=main.app),
            base_url="https://test.invalid",
            follow_redirects=False,
        )
        self.addAsyncCleanup(self.client.aclose)

    async def test_listar_escopa_por_owner(self):
        _insert("l-a1", OWNER_A, "comp-a1")
        _insert("l-a2", OWNER_A, "comp-a2", status="enviado")
        _insert("l-b1", OWNER_B, "comp-b1")

        r = await self.client.get("/lembretes", headers=_auth(OWNER_A))
        self.assertEqual(r.status_code, 200)
        dados = r.json()
        self.assertTrue(dados["sucesso"])
        ids = {l["compromisso_id"] for l in dados["lembretes"]}
        self.assertEqual(ids, {"comp-a1", "comp-a2"})
        self.assertNotIn("comp-b1", ids)
        # Campos necessarios para a tela
        item = next(l for l in dados["lembretes"] if l["compromisso_id"] == "comp-a1")
        self.assertEqual(item["telefone"], "+5575992298347")
        self.assertEqual(item["mensagem"], "Sessao amanha")
        self.assertEqual(item["status"], "pendente")

    async def test_listar_filtra_por_status(self):
        _insert("l-a1", OWNER_A, "comp-a1", status="pendente")
        _insert("l-a2", OWNER_A, "comp-a2", status="enviado")

        r = await self.client.get("/lembretes?status=pendente", headers=_auth(OWNER_A))
        self.assertEqual(r.status_code, 200)
        ids = {l["compromisso_id"] for l in r.json()["lembretes"]}
        self.assertEqual(ids, {"comp-a1"})

    async def test_listar_exige_autenticacao(self):
        r = await self.client.get("/lembretes")
        self.assertIn(r.status_code, (401, 403))

    async def test_cancelar_todos_afeta_so_o_owner(self):
        _insert("l-a1", OWNER_A, "comp-a1")
        _insert("l-a2", OWNER_A, "comp-a2")
        _insert("l-b1", OWNER_B, "comp-b1")

        r = await self.client.delete("/lembretes", headers=_auth(OWNER_A))
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["cancelados"], 2)

        a_pend = db.executar(
            "SELECT COUNT(*) AS c FROM lembretes WHERE owner_id = ? AND status = 'pendente'",
            (OWNER_A,),
        ).fetchone()["c"]
        b_pend = db.executar(
            "SELECT COUNT(*) AS c FROM lembretes WHERE owner_id = ? AND status = 'pendente'",
            (OWNER_B,),
        ).fetchone()["c"]
        self.assertEqual(a_pend, 0)
        self.assertEqual(b_pend, 1)

    async def test_cancelar_todos_sem_pendentes_retorna_zero(self):
        _insert("l-b1", OWNER_B, "comp-b1")
        r = await self.client.delete("/lembretes", headers=_auth(OWNER_A))
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["cancelados"], 0)


if __name__ == "__main__":
    unittest.main()
