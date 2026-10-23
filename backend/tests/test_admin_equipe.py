"""Fase 5I: psicólogo é um eixo separado do papel do painel (equipe)."""
import re
import unittest
from datetime import datetime, timedelta, timezone

import httpx

import main
from services import admin, db
from services.usuarios import hash_senha

SENHA = "SenhaForte123"
TABELAS = (
    "usuarios", "dispositivos", "eventos", "admin_auditoria", "admin_sessoes",
    "tokens_revogados",
)


def _iso(dias: float = 0) -> str:
    return (datetime.now(timezone.utc) - timedelta(days=dias)).isoformat()


def _limpar() -> None:
    for tabela in TABELAS:
        db.executar(f"DELETE FROM {tabela}").commit()
    main._rate_limit_store.clear()


def _usuario(uid, email, role="user", eh_psicologo=1, status="ativo"):
    db.executar(
        "INSERT INTO usuarios (id, email, password_hash, nome, plano, status, role, "
        "criado_em, eh_psicologo) VALUES (?, ?, ?, 'Nome', 'gratis', ?, ?, ?, ?)",
        (uid, email, hash_senha(SENHA), status, role, _iso(10), eh_psicologo),
    ).commit()


def _base() -> None:
    _limpar()
    _usuario("dono", "dono@ex.com", role="admin", eh_psicologo=1)
    _usuario("anderson", "anderson@ex.com", role="admin", eh_psicologo=0)
    _usuario("psi", "psi@ex.com", role="user", eh_psicologo=1)
    _usuario("pendente", "pendente@ex.com", role="user", eh_psicologo=1, status="pendente")


class KpisEListagemTests(unittest.TestCase):
    def setUp(self):
        _base()

    def test_kpis_separa_psicologos_e_equipe(self):
        k = admin.kpis()
        self.assertEqual(k["total_usuarios"], 4)
        self.assertEqual(k["psicologos"], 3)  # dono + psi + pendente
        self.assertEqual(k["equipe"], 2)  # dono + anderson

    def test_lista_default_mostra_psicologos(self):
        pagina = admin.listar_usuarios()
        emails = {u["email"] for u in pagina["usuarios"]}
        self.assertIn("dono@ex.com", emails)
        self.assertIn("psi@ex.com", emails)
        self.assertNotIn("anderson@ex.com", emails)

    def test_filtro_equipe_mostra_administradores(self):
        pagina = admin.listar_usuarios(tipo="equipe")
        emails = {u["email"] for u in pagina["usuarios"]}
        self.assertEqual(emails, {"dono@ex.com", "anderson@ex.com"})

    def test_filtro_todos_mostra_tudo(self):
        pagina = admin.listar_usuarios(tipo="todos")
        self.assertEqual(pagina["total"], 4)

    def test_detalhar_traz_flag_e_permite_alternar(self):
        detalhe = admin.detalhar_usuario("anderson")
        self.assertEqual(int(detalhe["usuario"]["eh_psicologo"]), 0)
        self.assertTrue(admin.definir_eh_psicologo("anderson", True))
        detalhe = admin.detalhar_usuario("anderson")
        self.assertEqual(int(detalhe["usuario"]["eh_psicologo"]), 1)
        pagina = admin.listar_usuarios()
        self.assertIn("anderson@ex.com", {u["email"] for u in pagina["usuarios"]})

    def test_exportar_inclui_flag(self):
        linhas = admin.exportar_usuarios(tipo="todos")
        por_email = {linha["email"]: linha for linha in linhas}
        self.assertEqual(int(por_email["anderson@ex.com"]["eh_psicologo"]), 0)
        self.assertEqual(int(por_email["psi@ex.com"]["eh_psicologo"]), 1)


class HTTPTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        _base()
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=main.app, client=("203.0.113.95", 55000)),
            base_url="https://test.invalid",
            follow_redirects=False,
        )
        self.addAsyncCleanup(self.client.aclose)
        login = await self.client.post(
            "/admin/login", data={"email": "dono@ex.com", "senha": SENHA}
        )
        self.assertEqual(login.status_code, 303)
        self.cookie = login.headers["set-cookie"].split(";")[0]
        self.client.cookies.clear()

    async def test_dashboard_mostra_psicologos_e_equipe(self):
        pagina = await self.client.get("/admin", headers={"Cookie": self.cookie})
        self.assertEqual(pagina.status_code, 200)
        self.assertIn("Equipe do painel", pagina.text)
        psicologos = re.search(r'<div class="n">(\d+)</div><div class="l">Psicólogos', pagina.text)
        self.assertEqual(psicologos.group(1), "3")

    async def test_filtro_equipe_na_listagem(self):
        pagina = await self.client.get(
            "/admin?tipo=equipe", headers={"Cookie": self.cookie}
        )
        self.assertEqual(pagina.status_code, 200)
        self.assertIn("anderson@ex.com", pagina.text)
        self.assertNotIn("psi@ex.com", pagina.text)

    async def test_acao_tipo_marca_psicologo(self):
        resposta = await self.client.post(
            "/admin/usuarios/anderson/acao",
            data={"acao": "tipo", "eh_psicologo": "1"},
            headers={"Cookie": self.cookie},
        )
        self.assertEqual(resposta.status_code, 303)
        flag = db.executar(
            "SELECT eh_psicologo FROM usuarios WHERE id = 'anderson'"
        ).fetchone()["eh_psicologo"]
        self.assertEqual(int(flag), 1)
        auditoria = admin.listar_auditoria(limite=1)
        self.assertEqual(auditoria[0]["acao"], "usuario.tipo")

    async def test_csv_tem_coluna_psicologo(self):
        resposta = await self.client.get(
            "/admin/usuarios.csv?tipo=todos", headers={"Cookie": self.cookie}
        )
        self.assertEqual(resposta.status_code, 200)
        self.assertIn("psicologo", resposta.text.splitlines()[0])


if __name__ == "__main__":
    unittest.main()
