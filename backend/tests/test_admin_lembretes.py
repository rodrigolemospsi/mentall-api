"""Lembretes no painel (Fase 5H): resumo, reenviar, arquivar e teto de retry."""
import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

import httpx

import main
from services import admin, db, lembrete_service, saude
from services.usuarios import hash_senha

SENHA = "SenhaForte123"
TABELAS = ("lembretes", "usuarios", "admin_auditoria", "admin_sessoes", "tokens_revogados")


def _iso(dias: float = 0, minutos: float = 0) -> str:
    return (datetime.now(timezone.utc) - timedelta(days=dias, minutes=minutos)).isoformat()


def _limpar() -> None:
    for tabela in TABELAS:
        db.executar(f"DELETE FROM {tabela}").commit()
    main._rate_limit_store.clear()


def _usuario(uid, email, role="admin"):
    db.executar(
        "INSERT INTO usuarios (id, email, password_hash, nome, plano, status, role, criado_em) "
        "VALUES (?, ?, ?, 'Nome', 'pro', 'ativo', ?, ?)",
        (uid, email, hash_senha(SENHA), role, _iso(30)),
    ).commit()


def _lembrete(lid, status="pendente", horario=None, tentativas=0, owner_id="u1"):
    db.executar(
        "INSERT INTO lembretes (id, compromisso_id, telefone, mensagem, horario_envio, canal, "
        "status, owner_id, criado_em, tentativas) VALUES (?, ?, ?, 'conteudo clinico', ?, "
        "'whatsapp', ?, ?, ?, ?)",
        (
            lid,
            f"comp-{lid}",
            "551199999999",
            horario or _iso(),
            status,
            owner_id,
            _iso(10),
            tentativas,
        ),
    ).commit()


class ResumoELimpezaTests(unittest.TestCase):
    def setUp(self):
        _limpar()

    def test_resumo_conta_status_e_janelas(self):
        _lembrete("l1", status="pendente", horario=_iso(minutos=-30))  # futuro
        _lembrete("l2", status="pendente", horario=_iso(dias=1))  # atrasado
        _lembrete("l3", status="falha", horario=_iso(dias=10))  # antiga
        _lembrete("l4", status="falha", horario=_iso(dias=30))  # antiga
        _lembrete("l5", status="enviado", horario=_iso(dias=1))
        resumo = admin.resumo_lembretes()
        self.assertEqual(resumo["total"], 5)
        self.assertEqual(resumo["pendentes"], 2)
        self.assertEqual(resumo["enviados"], 1)
        self.assertEqual(resumo["falhas"], 2)
        self.assertEqual(resumo["atrasados"], 1)
        self.assertEqual(resumo["falhas_antigas"], 2)
        self.assertEqual(resumo["falhas_recentes"], 0)

    def test_falha_recente_nao_conta_como_antiga(self):
        _lembrete("l1", status="falha", horario=_iso(minutos=10))
        resumo = admin.resumo_lembretes()
        self.assertEqual(resumo["falhas_recentes"], 1)
        self.assertEqual(resumo["falhas_antigas"], 0)

    def test_listar_nao_expoe_mensagem_nem_telefone_completo(self):
        _lembrete("l1", status="falha", horario=_iso(dias=2))
        itens = admin.listar_lembretes_painel()
        self.assertEqual(len(itens), 1)
        self.assertNotIn("mensagem", itens[0])
        self.assertIn("*", itens[0]["telefone"])
        self.assertNotEqual(itens[0]["telefone"], "551199999999")

    def test_reenviar_falha_volta_para_pendente(self):
        _lembrete("l1", status="falha", horario=_iso(dias=1))
        self.assertTrue(admin.reenviar_lembrete("l1"))
        linha = db.executar("SELECT status, tentativas FROM lembretes WHERE id='l1'").fetchone()
        self.assertEqual(linha["status"], "pendente")
        self.assertEqual(linha["tentativas"], 0)

    def test_reenviar_so_aceita_falha_ou_cancelado(self):
        _lembrete("l1", status="enviado")
        self.assertFalse(admin.reenviar_lembrete("l1"))

    def test_arquivar_lembrete(self):
        _lembrete("l1", status="falha", horario=_iso(dias=1))
        self.assertTrue(admin.arquivar_lembrete("l1"))
        status = db.executar("SELECT status FROM lembretes WHERE id='l1'").fetchone()["status"]
        self.assertEqual(status, "cancelado")

    def test_arquivar_falhas_antigas_nao_toca_nas_recentes(self):
        _lembrete("antiga", status="falha", horario=_iso(dias=10))
        _lembrete("recente", status="falha", horario=_iso(minutos=5))
        total = admin.arquivar_falhas_antigas(dias=7)
        self.assertEqual(total, 1)
        status_antiga = db.executar("SELECT status FROM lembretes WHERE id='antiga'").fetchone()["status"]
        status_recente = db.executar("SELECT status FROM lembretes WHERE id='recente'").fetchone()["status"]
        self.assertEqual(status_antiga, "cancelado")
        self.assertEqual(status_recente, "falha")


class SaudeLembretesTests(unittest.TestCase):
    def setUp(self):
        _limpar()

    def test_sem_lembretes_ok(self):
        self.assertEqual(saude._lembretes()[0], "ok")

    def test_atrasado_gera_atencao(self):
        _lembrete("l1", status="pendente", horario=_iso(dias=1))
        estado, detalhe = saude._lembretes()
        self.assertEqual(estado, "atencao")
        self.assertIn("atrasado", detalhe)

    def test_so_falhas_antigas_nao_alerta(self):
        _lembrete("l1", status="falha", horario=_iso(dias=30))
        estado, detalhe = saude._lembretes()
        self.assertEqual(estado, "ok")
        self.assertIn("antiga", detalhe)

    def test_falha_recente_gera_atencao(self):
        _lembrete("l1", status="falha", horario=_iso(minutos=30))
        estado, detalhe = saude._lembretes()
        self.assertEqual(estado, "atencao")
        self.assertIn("7 dias", detalhe)


class TetoDeTentativasTests(unittest.TestCase):
    def setUp(self):
        _limpar()

    def test_para_de_tentar_apos_o_teto(self):
        _lembrete("l1", status="pendente", horario=_iso(minutos=5),
                  tentativas=lembrete_service.MAX_TENTATIVAS_LEMBRETE - 1)
        with patch.object(lembrete_service, "_enviar_whatsapp_via_wuzapi", return_value=(False, None)):
            lembrete_service._processar_pendentes(datetime.now(timezone.utc))
        linha = db.executar("SELECT status, tentativas FROM lembretes WHERE id='l1'").fetchone()
        self.assertEqual(linha["status"], "falha")
        self.assertEqual(linha["tentativas"], lembrete_service.MAX_TENTATIVAS_LEMBRETE)

    def test_dentro_da_janela_continua_pendente(self):
        _lembrete("l1", status="pendente", horario=_iso(minutos=5), tentativas=0)
        with patch.object(lembrete_service, "_enviar_whatsapp_via_wuzapi", return_value=(False, None)):
            lembrete_service._processar_pendentes(datetime.now(timezone.utc))
        linha = db.executar("SELECT status, tentativas FROM lembretes WHERE id='l1'").fetchone()
        self.assertEqual(linha["status"], "pendente")
        self.assertEqual(linha["tentativas"], 1)


class PainelLembretesHttpTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        _limpar()
        _usuario("admin-1", "dono@ex.com", role="admin")
        _usuario("sup-1", "suporte@ex.com", role="suporte")
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=main.app, client=("203.0.113.90", 55000)),
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

    async def test_pagina_lista_lembretes(self):
        _lembrete("l1", status="falha", horario=_iso(dias=30))
        cookie = await self._login()
        pagina = await self.client.get("/admin/lembretes", headers={"Cookie": cookie})
        self.assertEqual(pagina.status_code, 200)
        self.assertIn("Lembretes do WhatsApp", pagina.text)
        self.assertIn("Arquivar falhas antigas", pagina.text)
        self.assertNotIn("conteudo clinico", pagina.text)

    async def test_reenviar_pela_acao(self):
        _lembrete("l1", status="falha", horario=_iso(dias=1))
        cookie = await self._login()
        resposta = await self.client.post(
            "/admin/lembretes/l1/acao", data={"acao": "reenviar"}, headers={"Cookie": cookie}
        )
        self.assertEqual(resposta.status_code, 303)
        status = db.executar("SELECT status FROM lembretes WHERE id='l1'").fetchone()["status"]
        self.assertEqual(status, "pendente")
        self.assertGreaterEqual(
            db.executar("SELECT COUNT(*) AS n FROM admin_auditoria").fetchone()["n"], 1
        )

    async def test_arquivar_antigas_pela_acao(self):
        _lembrete("l1", status="falha", horario=_iso(dias=30))
        cookie = await self._login()
        resposta = await self.client.post(
            "/admin/lembretes/arquivar-antigas", headers={"Cookie": cookie}
        )
        self.assertEqual(resposta.status_code, 303)
        status = db.executar("SELECT status FROM lembretes WHERE id='l1'").fetchone()["status"]
        self.assertEqual(status, "cancelado")

    async def test_suporte_nao_acessa(self):
        cookie = await self._login("suporte@ex.com")
        resposta = await self.client.get("/admin/lembretes", headers={"Cookie": cookie})
        self.assertEqual(resposta.status_code, 403)

    async def test_link_no_menu(self):
        cookie = await self._login()
        painel = await self.client.get("/admin", headers={"Cookie": cookie})
        self.assertIn('href="/admin/lembretes"', painel.text)


if __name__ == "__main__":
    unittest.main()
