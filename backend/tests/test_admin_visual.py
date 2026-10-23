"""Fase 5K: dashboard v2 (layout novo, anéis, gráficos) e estatísticas."""
import unittest
from datetime import datetime, timedelta, timezone

import httpx

import main
from services import admin, db
from services.usuarios import hash_senha

SENHA = "SenhaForte123"
TABELAS = (
    "usuarios", "dispositivos", "eventos", "contratos", "lembretes",
    "admin_auditoria", "admin_sessoes", "tokens_revogados",
)


def _iso(dias: float = 0) -> str:
    return (datetime.now(timezone.utc) - timedelta(days=dias)).isoformat()


def _limpar() -> None:
    for tabela in TABELAS:
        db.executar(f"DELETE FROM {tabela}").commit()
    main._rate_limit_store.clear()


def _usuario(uid, email, role="user", eh_psicologo=1, status="ativo", criado=None):
    db.executar(
        "INSERT INTO usuarios (id, email, password_hash, nome, plano, status, role, "
        "criado_em, eh_psicologo) VALUES (?, ?, ?, 'Nome', 'gratis', ?, ?, ?, ?)",
        (uid, email, hash_senha(SENHA), status, role, criado or _iso(10), eh_psicologo),
    ).commit()


def _lembrete(lid, status="enviado", entregue=None):
    db.executar(
        "INSERT INTO lembretes (id, compromisso_id, telefone, mensagem, horario_envio, "
        "canal, status, owner_id, criado_em, entregue_em) "
        "VALUES (?, ?, '5511999999999', 'x', ?, 'whatsapp', ?, 'u1', ?, ?)",
        (lid, f"comp-{lid}", _iso(1), status, _iso(2), entregue),
    ).commit()


class EstatisticasTests(unittest.TestCase):
    def setUp(self):
        _limpar()

    def test_serie_tem_12_meses_e_status(self):
        _usuario("u1", "a@ex.com", status="ativo", criado=_iso(1))
        _usuario("u2", "b@ex.com", status="pendente", criado=_iso(10))
        _usuario("u3", "c@ex.com", status="suspenso", criado=_iso(40))
        dados = admin.estatisticas_dashboard()
        self.assertEqual(len(dados["serie_meses"]), 12)
        self.assertEqual(dados["status"]["ativo"], 1)
        self.assertEqual(dados["status"]["pendente"], 1)
        self.assertEqual(dados["status"]["suspenso"], 1)

    def test_percentuais_sem_dados_nao_estouram(self):
        dados = admin.estatisticas_dashboard()
        for chave in ("online_pct", "contratos_pct", "lembretes_pct"):
            self.assertGreaterEqual(int(dados[chave]), 0)
            self.assertLessEqual(int(dados[chave]), 100)

    def test_variacao_de_novos_7_dias(self):
        _usuario("u1", "novo@ex.com", criado=_iso(2))
        _usuario("u2", "antigo@ex.com", criado=_iso(10))
        dados = admin.estatisticas_dashboard()
        self.assertEqual(int(dados["novos_7d_antes"]), 1)

    def test_lembretes_entregues_entram_no_percentual(self):
        _usuario("u1", "a@ex.com")
        _lembrete("l1", status="enviado", entregue=_iso(1))
        _lembrete("l2", status="falha")
        dados = admin.estatisticas_dashboard()
        self.assertEqual(int(dados["lembretes_ok"]), 1)
        self.assertEqual(int(dados["lembretes_total"]), 2)
        self.assertEqual(int(dados["lembretes_pct"]), 50)


class DashboardHttpTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        _limpar()
        _usuario("admin-1", "dono@ex.com", role="admin", eh_psicologo=1)
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=main.app, client=("203.0.113.99", 55000)),
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

    async def _get(self, url):
        return await self.client.get(url, headers={"Cookie": self.cookie})

    async def test_dashboard_tem_layout_novo_e_graficos(self):
        pagina = await self._get("/admin")
        self.assertEqual(pagina.status_code, 200)
        for marcador in (
            'class="sidebar"', 'class="topbar"', "Visão geral", "E-mail",
            "Lembretes", "Segurança", "Cadastros por mês", "Distribuição de contas",
            'class="anel"', "Novos (7 dias)", "Contas pendentes",
            "Saúde do sistema", "Exportar CSV", "@media (max-width: 760px)",
        ):
            self.assertIn(marcador, pagina.text, marcador)

    async def test_outras_paginas_usam_o_mesmo_layout(self):
        _usuario("psi-1", "psi@ex.com")
        for url in ("/admin/seguranca", "/admin/lembretes", "/admin/email",
                    "/admin/usuarios/psi-1"):
            resposta = await self._get(url)
            self.assertEqual(resposta.status_code, 200, url)
            self.assertIn('class="sidebar"', resposta.text, url)

    async def test_login_continua_com_entrar(self):
        # GET /admin sem cookie renderiza a tela de login (200 com "Entrar").
        resposta = await self.client.get("/admin")
        self.assertEqual(resposta.status_code, 200)
        self.assertIn("Entrar", resposta.text)
        self.assertIn('class="login"', resposta.text)


if __name__ == "__main__":
    unittest.main()
