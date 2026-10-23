"""Fase 5L: gráficos de contratos/lembretes e mini-KPIs no dashboard."""
import unittest
from datetime import datetime, timedelta, timezone

import httpx

import main
from services import admin, db
from services.usuarios import hash_senha

SENHA = "SenhaForte123"
TABELAS = (
    "usuarios", "dispositivos", "eventos", "contratos", "anamneses", "lembretes",
    "admin_auditoria", "admin_sessoes", "tokens_revogados",
)


def _iso(dias: float = 0) -> str:
    return (datetime.now(timezone.utc) - timedelta(days=dias)).isoformat()


def _limpar() -> None:
    for tabela in TABELAS:
        db.executar(f"DELETE FROM {tabela}").commit()
    main._rate_limit_store.clear()


def _usuario(uid, email, role="user", criado=None):
    db.executar(
        "INSERT INTO usuarios (id, email, password_hash, nome, plano, status, role, "
        "criado_em, eh_psicologo) VALUES (?, ?, ?, 'Nome', 'gratis', 'ativo', ?, ?, 1)",
        (uid, email, hash_senha(SENHA), role, criado or _iso(10)),
    ).commit()


def _contrato(token, status, criado=None, aceito=None):
    db.executar(
        "INSERT INTO contratos (token, dados, status, owner_id, criado_em, aceito_em) "
        "VALUES (?, '{}', ?, 'u1', ?, ?)",
        (token, status, criado or _iso(5), aceito),
    ).commit()


def _anamnese(token, status, criado=None):
    db.executar(
        "INSERT INTO anamneses (token, template_json, owner_id, status, respostas, criado_em) "
        "VALUES (?, '{}', 'u1', ?, '{}', ?)",
        (token, status, criado or _iso(5)),
    ).commit()


def _lembrete(lid, status, criado=None, entregue=None):
    db.executar(
        "INSERT INTO lembretes (id, compromisso_id, telefone, mensagem, horario_envio, "
        "canal, status, owner_id, criado_em, entregue_em) "
        "VALUES (?, ?, '5511999999999', 'x', ?, 'whatsapp', ?, 'u1', ?, ?)",
        (lid, f"comp-{lid}", criado or _iso(5), status, criado or _iso(5), entregue),
    ).commit()


class SeriesGraficosTests(unittest.TestCase):
    def setUp(self):
        _limpar()
        _usuario("u1", "psi@ex.com")

    def test_series_tem_12_meses(self):
        dados = admin.estatisticas_dashboard()
        self.assertEqual(len(dados["serie_contratos"]), 12)
        self.assertEqual(len(dados["serie_lembretes"]), 12)
        self.assertEqual(len(dados["serie_meses"]), 12)

    def test_contratos_por_status_e_aceitos_no_mes(self):
        _contrato("c1", "aceito", criado=_iso(2), aceito=_iso(1))
        _contrato("c2", "pendente", criado=_iso(2))
        dados = admin.estatisticas_dashboard()
        self.assertEqual(dados["contratos_status"]["aceito"], 1)
        self.assertEqual(dados["contratos_status"]["pendente"], 1)
        total_mes = sum(linha[1] for linha in dados["serie_contratos"])
        aceitos_mes = sum(linha[2] for linha in dados["serie_contratos"])
        self.assertEqual(total_mes, 2)
        self.assertEqual(aceitos_mes, 1)

    def test_lembretes_por_status_e_entregues_no_mes(self):
        _lembrete("l1", "enviado", criado=_iso(1), entregue=_iso(1))
        _lembrete("l2", "falha", criado=_iso(1))
        _lembrete("l3", "pendente", criado=_iso(1))
        dados = admin.estatisticas_dashboard()
        self.assertEqual(dados["lembretes_status"]["enviado"], 1)
        self.assertEqual(dados["lembretes_status"]["falha"], 1)
        self.assertEqual(dados["lembretes_status"]["pendente"], 1)
        entregues_mes = sum(linha[2] for linha in dados["serie_lembretes"])
        self.assertEqual(entregues_mes, 1)

    def test_anamneses_por_status(self):
        _anamnese("a1", "respondido")
        _anamnese("a2", "pendente")
        dados = admin.estatisticas_dashboard()
        self.assertEqual(dados["anamneses_status"]["respondido"], 1)
        self.assertEqual(dados["anamneses_status"]["pendente"], 1)


class DashboardGraficosHttpTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        _limpar()
        _usuario("admin-1", "dono@ex.com", role="admin")
        # dados para os gráficos não caírem no estado vazio
        _contrato("c1", "aceito", criado=_iso(1), aceito=_iso(1))
        _contrato("c2", "pendente", criado=_iso(1))
        _lembrete("l1", "enviado", criado=_iso(1), entregue=_iso(1))
        _lembrete("l2", "falha", criado=_iso(1))
        _lembrete("l3", "pendente", criado=_iso(1))
        _lembrete("l4", "cancelado", criado=_iso(1))
        _anamnese("a1", "respondido")
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=main.app, client=("203.0.113.96", 55000)),
            base_url="https://test.invalid",
            follow_redirects=False,
        )
        self.addAsyncCleanup(self.client.aclose)
        login = await self.client.post(
            "/admin/login", data={"email": "dono@ex.com", "senha": SENHA}
        )
        self.cookie = login.headers["set-cookie"].split(";")[0]
        self.client.cookies.clear()

    async def test_dashboard_mostra_os_novos_graficos(self):
        pagina = await self.client.get("/admin", headers={"Cookie": self.cookie})
        self.assertEqual(pagina.status_code, 200)
        for marcador in (
            "Contratos por mês", "Criados", "Aceitos",
            "Lembretes por status", "Cancelados",
            "Contratos aceitos", "Anamneses respondidas",
            "Lembretes entregues", "Falhas de lembrete",
        ):
            self.assertIn(marcador, pagina.text, marcador)


if __name__ == "__main__":
    unittest.main()
