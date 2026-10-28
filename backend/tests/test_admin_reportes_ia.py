"""Reportes de IA no painel (item 3.4): servico, pagina e HTTP."""

import unittest
from datetime import datetime, timedelta, timezone

import httpx

import admin_ui
import main
from services import db, reportes_ia
from services.usuarios import hash_senha

SENHA = "SenhaForte123"
TABELAS = ("reportes_ia", "usuarios", "admin_sessoes", "admin_seguranca", "tokens_revogados")


def _iso(dias: float = 0) -> str:
    return (datetime.now(timezone.utc) - timedelta(days=dias)).isoformat()


def _limpar() -> None:
    for tabela in TABELAS:
        db.executar(f"DELETE FROM {tabela}").commit()
    main._rate_limit_store.clear()


def _usuario(uid: str, email: str, role: str = "admin") -> None:
    db.executar(
        "INSERT INTO usuarios (id, email, password_hash, nome, plano, status, role, criado_em) "
        "VALUES (?, ?, ?, 'Nome', 'pro', 'ativo', ?, ?)",
        (uid, email, hash_senha(SENHA), role, _iso(30)),
    ).commit()


def _reporte(motivo="conteudo_incorreto", owner="u1", sessao="sessao-1", detalhe="", provedor="openai"):
    return reportes_ia.registrar_reporte(
        owner_id=owner, sessao_id=sessao, motivo=motivo, detalhe=detalhe, provedor=provedor
    )


class ServicoTests(unittest.TestCase):
    def setUp(self):
        _limpar()

    def test_resumo_conta_total_7d_e_por_motivo(self):
        antigo = _reporte("tom_inadequado", detalhe="antigo")
        db.executar(
            "UPDATE reportes_ia SET criado_em = ? WHERE id = ?", (_iso(10), antigo)
        ).commit()
        _reporte("conteudo_incorreto")
        _reporte("dado_sensivel")
        resumo = reportes_ia.resumo_reportes()
        self.assertEqual(resumo["total"], 3)
        self.assertEqual(resumo["ultimos_7d"], 2)
        self.assertEqual(resumo["por_motivo"]["dado_sensivel"], 1)
        self.assertEqual(resumo["por_motivo"]["conteudo_incorreto"], 1)

    def test_listar_ordena_filtra_e_junta_email(self):
        _usuario("u1", "pro@ex.com")
        _reporte("tom_inadequado")
        segundo = _reporte("dado_sensivel", detalhe="expos telefone")
        lista = reportes_ia.listar_reportes()
        self.assertEqual(len(lista), 2)
        self.assertEqual(lista[0]["id"], segundo)  # mais recente primeiro
        self.assertEqual(lista[0]["dono_email"], "pro@ex.com")
        self.assertEqual(lista[0]["detalhe"], "expos telefone")
        so_tom = reportes_ia.listar_reportes(motivo="tom_inadequado")
        self.assertEqual(len(so_tom), 1)
        self.assertEqual(so_tom[0]["motivo"], "tom_inadequado")

    def test_filtro_invalido_nao_filtra(self):
        _reporte("outro")
        self.assertEqual(len(reportes_ia.listar_reportes(motivo="nao_existe")), 1)

    def test_limite_do_listar(self):
        for _ in range(3):
            _reporte("outro")
        self.assertEqual(len(reportes_ia.listar_reportes(limite=2)), 2)


class PaginaTests(unittest.TestCase):
    def setUp(self):
        _limpar()

    def test_pagina_mostra_metadados_sem_conteudo_clinico(self):
        _usuario("u1", "pro@ex.com")
        projeto = _reporte("dado_sensivel", detalhe="apareceu um telefone")
        resumo = reportes_ia.resumo_reportes()
        lista = reportes_ia.listar_reportes()
        html = admin_ui.pagina_reportes_ia(resumo, lista)
        self.assertIn("Reportes de saida de IA", html)
        self.assertIn("Exposicao de dado sensivel", html)
        self.assertIn(projeto[:8], html)
        self.assertIn("pro@ex.com", html)
        self.assertIn("apareceu um telefone", html)
        self.assertIn("NAO sao enviados", html)

    def test_pagina_vazia_mostra_estado(self):
        html = admin_ui.pagina_reportes_ia(reportes_ia.resumo_reportes(), [])
        self.assertIn("Nenhum reporte com esse filtro", html)


class PainelReportesHttpTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        _limpar()
        _usuario("admin-1", "dono@ex.com", role="admin")
        _usuario("sup-1", "suporte@ex.com", role="suporte")
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=main.app, client=("203.0.113.91", 55001)),
            base_url="https://test.invalid",
            follow_redirects=False,
        )
        self.addAsyncCleanup(self.client.aclose)

    async def _login(self, email="dono@ex.com"):
        resposta = await self.client.post(
            "/admin/login", data={"email": email, "senha": SENHA}
        )
        self.assertEqual(resposta.status_code, 303)
        cookie = resposta.headers["set-cookie"].split(";")[0]
        self.client.cookies.clear()
        return cookie

    async def test_admin_ve_pagina_com_reportes(self):
        _reporte("tom_inadequado", detalhe="tom agressivo")
        cookie = await self._login()
        pagina = await self.client.get("/admin/reportes-ia", headers={"Cookie": cookie})
        self.assertEqual(pagina.status_code, 200)
        self.assertIn("Reportes de saida de IA", pagina.text)
        self.assertIn("Tom/linguagem inadequada", pagina.text)
        self.assertIn("tom agressivo", pagina.text)

    async def test_filtro_por_motivo(self):
        _reporte("tom_inadequado")
        _reporte("outro")
        cookie = await self._login()
        pagina = await self.client.get(
            "/admin/reportes-ia?motivo=tom_inadequado", headers={"Cookie": cookie}
        )
        self.assertEqual(pagina.status_code, 200)
        self.assertIn("Tom/linguagem inadequada", pagina.text)

    async def test_suporte_nao_acessa(self):
        cookie = await self._login("suporte@ex.com")
        pagina = await self.client.get("/admin/reportes-ia", headers={"Cookie": cookie})
        self.assertEqual(pagina.status_code, 403)

    async def test_sem_sessao_mostra_login(self):
        pagina = await self.client.get("/admin/reportes-ia")
        self.assertEqual(pagina.status_code, 200)
        self.assertIn("senha", pagina.text.lower())
