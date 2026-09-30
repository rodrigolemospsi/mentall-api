"""Painel do dono (Fase 3): login por cookie httpOnly + KPIs + lista (LGPD: só números)."""
import unittest

import httpx

import main
from services import admin, db
from services.usuarios import hash_senha

SENHA = "SenhaForte123"


def _criar_usuario(uid, email, role):
    db.executar(
        "INSERT INTO usuarios (id, email, password_hash, nome, plano, status, role, criado_em) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        (uid, email, hash_senha(SENHA), "Nome", "gratis", "ativo", role, "2026-01-01T00:00:00+00:00"),
    ).commit()


class AdminServiceTests(unittest.TestCase):
    def setUp(self):
        db.executar("DELETE FROM usuarios").commit()
        db.executar("DELETE FROM dispositivos").commit()
        db.executar("DELETE FROM eventos").commit()
        _criar_usuario("u1", "a@ex.com", "user")
        _criar_usuario("u2", "b@ex.com", "user")

    def test_kpis_contam_usuarios_e_online(self):
        from services.telemetria import registrar_heartbeat, registrar_evento
        registrar_heartbeat("u1", "dev-aaaaaaaa", "android", "1.0.43")
        registrar_evento("u1", "dev-aaaaaaaa", "sintese")
        registrar_evento("u1", "dev-aaaaaaaa", "sintese")

        k = admin.kpis()
        self.assertEqual(k["total_usuarios"], 2)
        self.assertEqual(k["online_agora"], 1)
        self.assertIn(("android", 1), k["aparelhos"])
        self.assertIn(("sintese", 2), k["eventos_por_tipo"])

    def test_listar_usuarios_traz_online_e_aparelho(self):
        from services.telemetria import registrar_heartbeat
        registrar_heartbeat("u1", "dev-aaaaaaaa", "ios", "1.0.43")
        pagina = admin.listar_usuarios(pagina=1, limite=10, busca="")
        self.assertEqual(pagina["total"], 2)
        por_id = {u["id"]: u for u in pagina["usuarios"]}
        self.assertTrue(por_id["u1"]["online"])
        self.assertEqual(por_id["u1"]["aparelho"], "ios")
        self.assertFalse(por_id["u2"]["online"])

    def test_listar_usuarios_busca_por_email(self):
        pagina = admin.listar_usuarios(pagina=1, limite=10, busca="b@ex")
        self.assertEqual(pagina["total"], 1)
        self.assertEqual(pagina["usuarios"][0]["email"], "b@ex.com")

    def test_online_considera_heartbeat_recente_fora_da_janela_antiga(self):
        # Antes a janela era 5 min: um heartbeat de 8 min aparecia offline.
        # Agora (10 min) o app pausado/suspenso continua contando como online.
        from datetime import datetime, timedelta, timezone
        ha_8min = (datetime.now(timezone.utc) - timedelta(minutes=8)).isoformat()
        db.executar(
            "INSERT INTO dispositivos "
            "(device_id, owner_id, plataforma, versao_app, ultimo_heartbeat_em, criado_em) "
            "VALUES (?, ?, ?, ?, ?, ?)",
            ("dev-8min", "u1", "android", "1.0.44", ha_8min, ha_8min),
        ).commit()
        pagina = admin.listar_usuarios(pagina=1, limite=10, busca="")
        por_id = {u["id"]: u for u in pagina["usuarios"]}
        self.assertTrue(por_id["u1"]["online"])

    def test_listar_usuarios_expoe_ultimo_heartbeat(self):
        from services.telemetria import registrar_heartbeat
        registrar_heartbeat("u1", "dev-bbbbbbbb", "android", "1.0.44")
        pagina = admin.listar_usuarios(pagina=1, limite=10, busca="")
        por_id = {u["id"]: u for u in pagina["usuarios"]}
        self.assertTrue(por_id["u1"]["ultimo_hb"])
        self.assertIsNone(por_id["u2"]["ultimo_hb"])


class AdminUiTests(unittest.TestCase):
    def test_quando_converte_para_horario_de_brasilia(self):
        from admin_ui import _quando
        self.assertEqual(_quando("2026-09-30T12:08:00+00:00"), "30/09/2026 09:08")

    def test_quando_vazio_retorna_traco(self):
        from admin_ui import _quando
        self.assertEqual(_quando(""), "-")
        self.assertEqual(_quando(None), "-")

    def test_visto_ha_formata_tempo_relativo(self):
        from datetime import datetime, timedelta, timezone
        from admin_ui import _visto_ha
        agora = datetime.now(timezone.utc)
        self.assertEqual(_visto_ha(agora.isoformat()), "agora")
        self.assertEqual(
            _visto_ha((agora - timedelta(minutes=3)).isoformat()), "há 3 min"
        )
        self.assertEqual(
            _visto_ha((agora - timedelta(hours=2)).isoformat()), "há 2 h"
        )
        self.assertEqual(_visto_ha(None), "-")


class AdminHttpTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        db.executar("DELETE FROM usuarios").commit()
        db.executar("DELETE FROM dispositivos").commit()
        db.executar("DELETE FROM eventos").commit()
        main._rate_limit_store.clear()
        _criar_usuario("admin-1", "dono@ex.com", "admin")
        _criar_usuario("user-1", "psi@ex.com", "user")
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=main.app),
            base_url="https://test.invalid",
            follow_redirects=False,
        )
        self.addAsyncCleanup(self.client.aclose)

    async def test_login_admin_seta_cookie_httponly(self):
        r = await self.client.post("/admin/login", data={"email": "dono@ex.com", "senha": SENHA})
        self.assertEqual(r.status_code, 303)
        set_cookie = r.headers.get("set-cookie", "")
        self.assertIn("mentall_admin=", set_cookie)
        self.assertIn("HttpOnly", set_cookie)
        self.assertIn("SameSite=strict", set_cookie)

    async def test_login_usuario_comum_recusado(self):
        r = await self.client.post("/admin/login", data={"email": "psi@ex.com", "senha": SENHA})
        self.assertEqual(r.status_code, 401)
        self.assertNotIn("mentall_admin=", r.headers.get("set-cookie", ""))

    async def test_login_senha_errada_recusado(self):
        r = await self.client.post("/admin/login", data={"email": "dono@ex.com", "senha": "Errada123"})
        self.assertEqual(r.status_code, 401)

    async def test_dashboard_sem_cookie_mostra_login(self):
        r = await self.client.get("/admin")
        self.assertEqual(r.status_code, 200)
        self.assertIn("Entrar", r.text)
        self.assertNotIn("Psicólogos", r.text)

    async def test_dashboard_com_cookie_admin_mostra_kpis(self):
        login = await self.client.post("/admin/login", data={"email": "dono@ex.com", "senha": SENHA})
        cookie = login.headers["set-cookie"].split(";")[0]
        r = await self.client.get("/admin", headers={"Cookie": cookie})
        self.assertEqual(r.status_code, 200)
        self.assertIn("Psicólogos", r.text)
        self.assertIn("psi@ex.com", r.text)

    async def test_cookie_de_usuario_comum_nao_acessa(self):
        # Um token JWT válido de usuário comum NÃO deve abrir o painel.
        token = main._criar_token_jwt("psi@ex.com", "user-1")
        r = await self.client.get("/admin", headers={"Cookie": f"mentall_admin={token}"})
        self.assertEqual(r.status_code, 200)
        self.assertIn("Entrar", r.text)
        self.assertNotIn("Psicólogos", r.text)

    async def test_logout_limpa_cookie(self):
        r = await self.client.post("/admin/logout")
        self.assertEqual(r.status_code, 303)
        self.assertIn("mentall_admin=", r.headers.get("set-cookie", ""))


if __name__ == "__main__":
    unittest.main()
