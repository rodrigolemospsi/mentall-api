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
        self.assertIn("NAO sao enviados", html)
        # A observacao agora aparece no detalhe (a lista fica compacta).
        detalhe = admin_ui.pagina_reporte_ia_detalhe(
            reportes_ia.obter_reporte(projeto)
        )
        self.assertIn("apareceu um telefone", detalhe)

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
        self.assertIn("Abrir", pagina.text)

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



class ResolucaoServicoTests(unittest.TestCase):
    def setUp(self):
        _limpar()

    def _resolver(self, reporte_id, **kwargs):
        dados = dict(
            reporte_id=reporte_id,
            status="resolvido",
            severidade="alta",
            causa_raiz="prompt",
            contato_feito=True,
            contato_canal="whatsapp",
            contato_em="2026-10-28",
            contato_resumo="Falei com o profissional no WhatsApp",
            devolutiva="Expliquei o que aconteceu e o ajuste",
            como_ficou="Prompt ajustado e caso documentado",
            mudanca_aplicada="prompt_ajustado",
            resolvido_por="dono@ex.com",
        )
        dados.update(kwargs)
        return reportes_ia.atualizar_resolucao(**dados)

    def test_salva_tratamento_completo(self):
        rid = _reporte("tom_inadequado", detalhe="tom agressivo")
        self.assertTrue(self._resolver(rid))
        item = reportes_ia.obter_reporte(rid)
        self.assertEqual(item["status"], "resolvido")
        self.assertEqual(item["severidade"], "alta")
        self.assertEqual(item["causa_raiz"], "prompt")
        self.assertEqual(item["contato_feito"], 1)
        self.assertEqual(item["contato_canal"], "whatsapp")
        self.assertEqual(item["contato_em"], "2026-10-28")
        self.assertIn("Falei com o profissional", item["contato_resumo"])
        self.assertIn("Expliquei", item["devolutiva"])
        self.assertIn("Prompt ajustado", item["como_ficou"])
        self.assertEqual(item["mudanca_aplicada"], "prompt_ajustado")
        self.assertEqual(item["resolvido_por"], "dono@ex.com")
        self.assertTrue(item["resolvido_em"])
        self.assertTrue(item["atualizado_em"])

    def test_reabrir_limpa_data_de_resolucao(self):
        rid = _reporte("outro")
        self._resolver(rid)
        self._resolver(rid, status="em_analise")
        item = reportes_ia.obter_reporte(rid)
        self.assertEqual(item["status"], "em_analise")
        self.assertEqual(item["resolvido_em"], "")
        self.assertEqual(item["resolvido_por"], "")

    def test_status_invalido_recusado(self):
        rid = _reporte("outro")
        with self.assertRaises(ValueError):
            self._resolver(rid, status="nao_existe")

    def test_severidade_invalida_recusada(self):
        rid = _reporte("outro")
        with self.assertRaises(ValueError):
            self._resolver(rid, severidade="urgentissima")

    def test_listar_filtra_por_status(self):
        aberto = _reporte("outro")
        resolvido = _reporte("tom_inadequado")
        self._resolver(resolvido)
        self.assertEqual(len(reportes_ia.listar_reportes(status="aberto")), 1)
        self.assertEqual(reportes_ia.listar_reportes(status="aberto")[0]["id"], aberto)
        self.assertEqual(len(reportes_ia.listar_reportes(status="resolvido")), 1)

    def test_resumo_por_status(self):
        self._resolver(_reporte("outro"))
        _reporte("tom_inadequado")
        resumo = reportes_ia.resumo_reportes()
        self.assertEqual(resumo["por_status"].get("resolvido"), 1)
        self.assertEqual(resumo["por_status"].get("aberto"), 1)


class DetalhePaginaTests(unittest.TestCase):
    def setUp(self):
        _limpar()

    def test_pagina_detalhe_mostra_metadados_e_formulario(self):
        _usuario("u1", "pro@ex.com")
        rid = _reporte("dado_sensivel", detalhe="apareceu um telefone")
        reportes_ia.atualizar_resolucao(
            reporte_id=rid,
            status="resolvido",
            severidade="alta",
            causa_raiz="prompt",
            contato_feito=True,
            contato_canal="whatsapp",
            contato_em="2026-10-28",
            contato_resumo="Contato feito",
            devolutiva="Devolutiva registrada",
            como_ficou="Prompt ajustado",
            mudanca_aplicada="prompt_ajustado",
            resolvido_por="dono@ex.com",
        )
        item = reportes_ia.obter_reporte(rid)
        html = admin_ui.pagina_reporte_ia_detalhe(item)
        for trecho in (
            "Reporte",
            "Exposicao de dado sensivel",
            "pro@ex.com",
            "Observacao do profissional",
            "Resolucao",
            "Entrei em contato com o profissional",
            "Devolutiva ao profissional",
            "Como ficou no sistema",
            "Causa raiz",
            "Salvar resolucao",
            "Resolvido em",
        ):
            self.assertIn(trecho, html)
        self.assertIn(rid[:8], html)

    def test_pagina_detalhe_aberto_tem_status_aberto(self):
        rid = _reporte("outro")
        html = admin_ui.pagina_reporte_ia_detalhe(reportes_ia.obter_reporte(rid))
        self.assertIn("Aberto", html)


class ResolucaoHttpTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        _limpar()
        db.executar("DELETE FROM admin_auditoria").commit()
        _usuario("admin-1", "dono@ex.com", role="admin")
        _usuario("sup-1", "suporte@ex.com", role="suporte")
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=main.app, client=("203.0.113.92", 55002)),
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

    async def test_admin_salva_resolucao(self):
        rid = _reporte("tom_inadequado", detalhe="tom agressivo")
        cookie = await self._login()
        resposta = await self.client.post(
            f"/admin/reportes-ia/{rid}/resolver",
            data={
                "status": "resolvido",
                "severidade": "alta",
                "causa_raiz": "prompt",
                "contato_feito": "1",
                "contato_canal": "whatsapp",
                "contato_em": "2026-10-28",
                "contato_resumo": "Contato feito",
                "devolutiva": "Devolutiva registrada",
                "como_ficou": "Prompt ajustado",
                "mudanca_aplicada": "prompt_ajustado",
            },
            headers={"Cookie": cookie},
        )
        self.assertEqual(resposta.status_code, 303)
        item = db.executar(
            "SELECT status, severidade, resolvido_por, resolvido_em, devolutiva "
            "FROM reportes_ia WHERE id = ?",
            (rid,),
        ).fetchone()
        self.assertEqual(item["status"], "resolvido")
        self.assertEqual(item["severidade"], "alta")
        self.assertEqual(item["resolvido_por"], "dono@ex.com")
        self.assertTrue(item["resolvido_em"])
        self.assertEqual(item["devolutiva"], "Devolutiva registrada")
        auditoria = db.executar(
            "SELECT COUNT(*) AS n FROM admin_auditoria WHERE acao = 'reporte_ia.resolver'"
        ).fetchone()
        self.assertEqual(int(auditoria["n"]), 1)

    async def test_status_invalido_retorna_400(self):
        rid = _reporte("outro")
        cookie = await self._login()
        resposta = await self.client.post(
            f"/admin/reportes-ia/{rid}/resolver",
            data={"status": "nao_existe", "severidade": "alta"},
            headers={"Cookie": cookie},
        )
        self.assertEqual(resposta.status_code, 400)

    async def test_suporte_nao_resolve(self):
        rid = _reporte("outro")
        cookie = await self._login("suporte@ex.com")
        resposta = await self.client.post(
            f"/admin/reportes-ia/{rid}/resolver",
            data={"status": "resolvido", "severidade": "media"},
            headers={"Cookie": cookie},
        )
        self.assertEqual(resposta.status_code, 403)

    async def test_detalhe_inexistente_404(self):
        cookie = await self._login()
        resposta = await self.client.get(
            "/admin/reportes-ia/nao-existe", headers={"Cookie": cookie}
        )
        self.assertEqual(resposta.status_code, 404)
