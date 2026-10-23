"""Painel operacional (Fase 5A, 22/10/2026).

Cobre: KPIs operacionais (contratos/anamneses/lembretes/versões), saúde do
sistema (isolamento das verificações), rate limit do login (por IP e por conta)
e revogação do cookie de sessão no logout.
"""
import os
import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

import httpx

import main
from services import admin, db, email_admin, saude
from services.usuarios import hash_senha

SENHA = "SenhaForte123"
TABELAS = (
    "usuarios", "dispositivos", "eventos", "contratos", "anamneses",
    "lembretes", "wuzapi_instancias", "tokens_revogados",
)


def _iso(dias: float = 0, horas: float = 0) -> str:
    return (datetime.now(timezone.utc) - timedelta(days=dias, hours=horas)).isoformat()


def _limpar() -> None:
    for tabela in TABELAS:
        db.executar(f"DELETE FROM {tabela}").commit()


def _usuario(uid, email, status="ativo", role="user", criado=None):
    db.executar(
        "INSERT INTO usuarios (id, email, password_hash, nome, plano, status, role, criado_em) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        (uid, email, hash_senha(SENHA), "Nome", "gratis", status, role, criado or _iso(1)),
    ).commit()


def _cliente(ip: str) -> httpx.AsyncClient:
    return httpx.AsyncClient(
        transport=httpx.ASGITransport(app=main.app, client=(ip, 55000)),
        base_url="https://test.invalid",
        follow_redirects=False,
    )


class KpisOperacionaisTests(unittest.TestCase):
    def setUp(self):
        _limpar()

    def test_contas_ativas_pendentes_e_janelas(self):
        _usuario("u1", "a@ex.com", criado=_iso(2))
        _usuario("u2", "b@ex.com", criado=_iso(20))
        _usuario("u3", "c@ex.com", status="pendente", criado=_iso(0))
        kpis = admin.kpis_operacionais()
        self.assertEqual(kpis["usuarios_ativos"], 2)
        self.assertEqual(kpis["usuarios_pendentes"], 1)
        self.assertEqual(kpis["novos_7d"], 2)
        self.assertEqual(kpis["novos_30d"], 3)

    def test_contratos_anamneses_e_lembretes(self):
        db.executar(
            "INSERT INTO contratos (token, dados, status, owner_id, criado_em) "
            "VALUES ('t1', '{}', 'aceito', 'o1', ?)",
            (_iso(1),),
        ).commit()
        db.executar(
            "INSERT INTO contratos (token, dados, status, owner_id, criado_em) "
            "VALUES ('t2', '{}', 'pendente', 'o1', ?)",
            (_iso(1),),
        ).commit()
        db.executar(
            "INSERT INTO anamneses (token, template_json, owner_id, status, criado_em) "
            "VALUES ('a1', '{}', 'o1', 'respondido', ?)",
            (_iso(1),),
        ).commit()
        for i, (status, entregue, lido) in enumerate(
            [("enviado", _iso(1), _iso(1)), ("enviado", None, None), ("falha", None, None),
             ("pendente", None, None)]
        ):
            db.executar(
                "INSERT INTO lembretes (id, compromisso_id, horario_envio, status, owner_id, "
                "criado_em, entregue_em, lido_em) VALUES (?, 'c1', ?, ?, 'o1', ?, ?, ?)",
                (f"l{i}", _iso(horas=1), status, _iso(1), entregue, lido),
            ).commit()
        kpis = admin.kpis_operacionais()
        self.assertEqual(kpis["contratos_aceitos"], 1)
        self.assertEqual(kpis["contratos_pendentes"], 1)
        self.assertEqual(kpis["anamneses_respondidas"], 1)
        self.assertEqual(kpis["lembretes_enviados"], 2)
        self.assertEqual(kpis["lembretes_entregues"], 1)
        self.assertEqual(kpis["lembretes_lidos"], 1)
        self.assertEqual(kpis["lembretes_falhas"], 1)
        self.assertEqual(kpis["lembretes_pendentes"], 1)

    def test_versoes_do_app_top3(self):
        for indice, versao in enumerate(["1.0.60", "1.0.60", "1.0.61", "1.0.62", "1.0.63"]):
            db.executar(
                "INSERT INTO dispositivos (device_id, owner_id, plataforma, versao_app, "
                "ultimo_heartbeat_em, criado_em) VALUES (?, 'o1', 'android', ?, ?, ?)",
                (f"d{indice}", versao, _iso(), _iso()),
            ).commit()
        versoes = admin.kpis_operacionais()["versoes"]
        self.assertEqual(len(versoes), 3)
        self.assertEqual(versoes[0], ("1.0.60", 2))

    def test_sem_dados_nao_quebra(self):
        kpis = admin.kpis_operacionais()
        self.assertEqual(kpis["novos_7d"], 0)
        self.assertEqual(kpis["versoes"], [])


class SaudeTests(unittest.TestCase):
    def setUp(self):
        _limpar()

    def test_coletar_isola_falha_de_uma_verificacao(self):
        def ok():
            return "ok", "teste"

        def falha():
            raise RuntimeError("boom")

        with patch.object(saude, "_VERIFICACOES", (("Fake ok", ok), ("Fake erro", falha))):
            itens = saude.coletar()
        self.assertEqual([i["estado"] for i in itens], ["ok", "erro"])
        self.assertIn("ms", itens[0])

    def test_banco_responde(self):
        estado, detalhe = saude._banco()
        self.assertIn(estado, ("ok", "atencao"))
        self.assertTrue(detalhe)

    def test_wuzapi_sem_configuracao_e_info(self):
        with patch.dict(os.environ, {}, clear=True):
            estado, _ = saude._wuzapi()
        self.assertEqual(estado, "info")
        db.executar(
            "INSERT INTO wuzapi_instancias (owner_id, conectado, atualizado_em) "
            "VALUES ('o1', 0, ?)",
            (_iso(),),
        ).commit()
        with patch.dict(os.environ, {}, clear=True):
            estado, detalhe = saude._wuzapi()
        self.assertEqual(estado, "atencao")
        self.assertIn("não configurado", detalhe)

    def test_wuzapi_conectado(self):
        db.executar(
            "INSERT INTO wuzapi_instancias (owner_id, conectado, atualizado_em) "
            "VALUES ('o1', 1, ?)",
            (_iso(),),
        ).commit()
        db.executar(
            "INSERT INTO wuzapi_instancias (owner_id, conectado, atualizado_em) "
            "VALUES ('o2', 0, ?)",
            (_iso(),),
        ).commit()
        with patch.dict(
            os.environ, {"WUZAPI_BASE_URL": "https://wuzapi.exemplo", "WUZAPI_ADMIN_TOKEN": "x"},
            clear=True,
        ):
            estado, detalhe = saude._wuzapi()
        self.assertEqual(estado, "ok")
        self.assertIn("1 de 2", detalhe)

    def test_lembretes_atrasados_geram_atencao(self):
        estado, _ = saude._lembretes()
        self.assertEqual(estado, "ok")
        db.executar(
            "INSERT INTO lembretes (id, compromisso_id, horario_envio, status, owner_id, criado_em) "
            "VALUES ('l1', 'c1', ?, 'pendente', 'o1', ?)",
            (_iso(horas=2), _iso(1)),
        ).commit()
        estado, detalhe = saude._lembretes()
        self.assertEqual(estado, "atencao")
        self.assertIn("atrasado", detalhe)

    def test_smtp(self):
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(saude._smtp()[0], "erro")
        with patch.dict(os.environ, {"SMTP_HOST": "smtp.gmail.com", "SMTP_PORT": "587"}, clear=True):
            estado, detalhe = saude._smtp()
        self.assertEqual(estado, "ok")
        self.assertIn("smtp.gmail.com:587", detalhe)

    def test_mailu_nao_configurado_ou_ok(self):
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(saude._mailu()[0], "info")
        with patch.object(email_admin, "configurado", return_value=True), patch.object(
            email_admin, "listar_caixas", return_value=[{"ativo": True}, {"ativo": False}]
        ):
            estado, detalhe = saude._mailu()
        self.assertEqual(estado, "ok")
        self.assertIn("2 caixas (1 ativas)", detalhe)


class LoginRateLimitTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        _limpar()
        main._rate_limit_store.clear()
        _usuario("admin-1", "dono@ex.com", role="admin")
        _usuario("admin-2", "segundo@ex.com", role="admin")
        self.a = _cliente("203.0.113.10")
        self.b = _cliente("198.51.100.20")
        self.addAsyncCleanup(self.a.aclose)
        self.addAsyncCleanup(self.b.aclose)

    async def _tentar(self, cliente, email="dono@ex.com", senha="errada"):
        return await cliente.post("/admin/login", data={"email": email, "senha": senha})

    async def test_conta_bloqueada_apos_5_erros_mesmo_de_outro_ip(self):
        for _ in range(5):
            resposta = await self._tentar(self.a)
            self.assertEqual(resposta.status_code, 401)
        # 6ª tentativa, de OUTRO IP, para a MESMA conta: bloqueada (anti brute-force distribuído)
        self.assertEqual((await self._tentar(self.b)).status_code, 429)
        # outra conta do mesmo IP continua podendo logar (o bloqueio não é global)
        resposta = await self._tentar(self.b, email="segundo@ex.com", senha=SENHA)
        self.assertEqual(resposta.status_code, 303)

    async def test_ip_limitado_apos_muitas_tentativas(self):
        for indice in range(30):
            resposta = await self._tentar(self.a, email=f"inexistente{indice}@ex.com")
            self.assertEqual(resposta.status_code, 401)
        self.assertEqual((await self._tentar(self.a, email="outro@ex.com")).status_code, 429)


class LogoutRevogaSessaoTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        _limpar()
        main._rate_limit_store.clear()
        _usuario("admin-1", "dono@ex.com", role="admin")
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=main.app, client=("203.0.113.30", 55000)),
            base_url="https://test.invalid",
            follow_redirects=False,
        )
        self.addAsyncCleanup(self.client.aclose)
        login = await self.client.post(
            "/admin/login", data={"email": "dono@ex.com", "senha": SENHA}
        )
        self.assertEqual(login.status_code, 303)
        self.cookie = login.headers["set-cookie"].split(";")[0]

    async def test_logout_invalida_o_cookie_na_hora(self):
        antes = await self.client.get("/admin", headers={"Cookie": self.cookie})
        self.assertEqual(antes.status_code, 200)
        self.assertIn("Psicólogos", antes.text)

        saida = await self.client.post("/admin/logout", headers={"Cookie": self.cookie})
        self.assertEqual(saida.status_code, 303)

        depois = await self.client.get("/admin", headers={"Cookie": self.cookie})
        self.assertEqual(depois.status_code, 200)
        self.assertIn("Entrar", depois.text)
        self.assertNotIn("Psicólogos", depois.text)
        self.assertGreaterEqual(
            db.executar("SELECT COUNT(*) AS n FROM tokens_revogados").fetchone()["n"], 1
        )

    async def test_logout_sem_cookie_nao_quebra(self):
        resposta = await self.client.post("/admin/logout")
        self.assertEqual(resposta.status_code, 303)


class DashboardOperacionalTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        _limpar()
        main._rate_limit_store.clear()
        _usuario("admin-1", "dono@ex.com", role="admin")
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=main.app, client=("203.0.113.40", 55000)),
            base_url="https://test.invalid",
            follow_redirects=False,
        )
        self.addAsyncCleanup(self.client.aclose)
        login = await self.client.post(
            "/admin/login", data={"email": "dono@ex.com", "senha": SENHA}
        )
        self.cookie = login.headers["set-cookie"].split(";")[0]

    async def _dashboard(self):
        resposta = await self.client.get("/admin", headers={"Cookie": self.cookie})
        self.assertEqual(resposta.status_code, 200)
        return resposta.text

    async def test_mostra_saude_kpis_e_operacao(self):
        saude_fake = [
            {"nome": "Banco de dados", "estado": "ok", "detalhe": "Turso (nuvem)", "ms": 3},
        ]
        with patch.object(main.saude_service, "coletar", return_value=saude_fake):
            html = await self._dashboard()
        self.assertIn("Saúde do sistema", html)
        self.assertIn("Banco de dados: ok", html)
        self.assertIn("Operação", html)
        self.assertIn("Novos (7 dias)", html)
        self.assertIn("Contas pendentes", html)
        self.assertNotIn("Receita do mês", html)

    async def test_saude_com_problema_aparece_como_atencao(self):
        saude_fake = [
            {"nome": "WhatsApp (Wuzapi)", "estado": "atencao", "detalhe": "0 de 2", "ms": 1},
        ]
        with patch.object(main.saude_service, "coletar", return_value=saude_fake):
            html = await self._dashboard()
        self.assertIn("1 ponto(s) de atenção", html)
        self.assertIn("WhatsApp (Wuzapi): atenção", html)


if __name__ == "__main__":
    unittest.main()
