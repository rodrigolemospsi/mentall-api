"""Fase 5A.2: filtros/CSV, detalhe do usuário, auditoria e ações administrativas."""
import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, patch

import httpx

import main
from services import admin, db
from services.usuarios import hash_senha, renovar_token_confirmacao

SENHA = "SenhaForte123"
TABELAS = (
    "usuarios", "dispositivos", "eventos", "contratos", "anamneses", "lembretes",
    "wuzapi_instancias", "tokens_revogados", "admin_auditoria",
)


def _iso(dias: float = 0, horas: float = 0) -> str:
    return (datetime.now(timezone.utc) - timedelta(days=dias, hours=horas)).isoformat()


def _limpar() -> None:
    for tabela in TABELAS:
        db.executar(f"DELETE FROM {tabela}").commit()


def _usuario(uid, email, status="ativo", role="user", plano="gratis", criado=None):
    db.executar(
        "INSERT INTO usuarios (id, email, password_hash, nome, plano, status, role, criado_em) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        (uid, email, hash_senha(SENHA), "Nome", plano, status, role, criado or _iso(1)),
    ).commit()


def _dispositivo(device_id, owner_id, versao="1.0.60", heartbeat=None):
    db.executar(
        "INSERT INTO dispositivos (device_id, owner_id, plataforma, versao_app, "
        "ultimo_heartbeat_em, criado_em) VALUES (?, ?, 'android', ?, ?, ?)",
        (device_id, owner_id, versao, heartbeat or _iso(), _iso(30)),
    ).commit()


def _cliente(ip: str = "203.0.113.50") -> httpx.AsyncClient:
    return httpx.AsyncClient(
        transport=httpx.ASGITransport(app=main.app, client=(ip, 55000)),
        base_url="https://test.invalid",
        follow_redirects=False,
    )


def _base_dados() -> None:
    _limpar()
    _usuario("u1", "ativo@ex.com", plano="pro", criado=_iso(2))
    _usuario("u2", "pendente@ex.com", status="pendente", criado=_iso(10))
    _usuario("u3", "suspenso@ex.com", status="suspenso", plano="pro", criado=_iso(1))
    _dispositivo("d1", "u1", versao="1.0.60")
    _dispositivo("d2", "u2", versao="1.0.40", heartbeat=_iso(dias=2))
    db.executar(
        "INSERT INTO contratos (token, dados, status, owner_id, criado_em) "
        "VALUES ('t1', '{}', 'aceito', 'u1', ?)",
        (_iso(1),),
    ).commit()
    db.executar(
        "INSERT INTO contratos (token, dados, status, owner_id, criado_em) "
        "VALUES ('t2', '{}', 'pendente', 'u1', ?)",
        (_iso(1),),
    ).commit()
    db.executar(
        "INSERT INTO anamneses (token, template_json, owner_id, status, criado_em) "
        "VALUES ('a1', '{}', 'u1', 'respondido', ?)",
        (_iso(1),),
    ).commit()
    db.executar(
        "INSERT INTO lembretes (id, compromisso_id, horario_envio, status, owner_id, criado_em, "
        "entregue_em, lido_em) VALUES ('l1', 'c1', ?, 'enviado', 'u1', ?, ?, ?)",
        (_iso(1), _iso(1), _iso(1), _iso(1)),
    ).commit()


class FiltrosEDetalheTests(unittest.TestCase):
    def setUp(self):
        _base_dados()

    def test_filtro_status(self):
        resultado = admin.listar_usuarios(status="pendente")
        self.assertEqual([u["email"] for u in resultado["usuarios"]], ["pendente@ex.com"])

    def test_filtro_plano(self):
        resultado = admin.listar_usuarios(plano="pro")
        emails = {u["email"] for u in resultado["usuarios"]}
        self.assertEqual(emails, {"ativo@ex.com", "suspenso@ex.com"})

    def test_filtro_online_e_offline(self):
        online = admin.listar_usuarios(online="1")
        self.assertEqual([u["email"] for u in online["usuarios"]], ["ativo@ex.com"])
        offline = admin.listar_usuarios(online="0")
        self.assertEqual({u["email"] for u in offline["usuarios"]}, {"pendente@ex.com", "suspenso@ex.com"})

    def test_filtro_versao(self):
        resultado = admin.listar_usuarios(versao="1.0.40")
        self.assertEqual([u["email"] for u in resultado["usuarios"]], ["pendente@ex.com"])

    def test_busca_e_ordenacao(self):
        resultado = admin.listar_usuarios(busca="suspenso")
        self.assertEqual(resultado["total"], 1)
        por_email = admin.listar_usuarios(ordenar="email_asc")
        self.assertEqual(
            [u["email"] for u in por_email["usuarios"]],
            ["ativo@ex.com", "pendente@ex.com", "suspenso@ex.com"],
        )

    def test_listagem_traz_dispositivo_na_mesma_consulta(self):
        resultado = admin.listar_usuarios(busca="ativo@ex.com")
        usuario = resultado["usuarios"][0]
        self.assertEqual(usuario["versao_app"], "1.0.60")
        self.assertTrue(usuario["online"])

    def test_exportar_respeita_filtros(self):
        linhas = admin.exportar_usuarios(status="pendente")
        self.assertEqual(len(linhas), 1)
        self.assertEqual(linhas[0]["email"], "pendente@ex.com")

    def test_opcoes_filtros(self):
        opcoes = admin.opcoes_filtros()
        self.assertIn("pendente", opcoes["status"])
        self.assertIn("pro", opcoes["planos"])
        self.assertIn("1.0.60", opcoes["versoes"])

    def test_detalhar_usuario_sem_conteudo_clinico(self):
        detalhe = admin.detalhar_usuario("u1")
        self.assertIsNotNone(detalhe)
        self.assertEqual(detalhe["usuario"]["email"], "ativo@ex.com")
        self.assertEqual(detalhe["contratos"], {"aceitos": 1, "pendentes": 1})
        self.assertEqual(detalhe["anamneses"], {"respondidas": 1, "pendentes": 0})
        self.assertEqual(detalhe["lembretes"]["enviados"], 1)
        self.assertEqual(detalhe["lembretes"]["entregues"], 1)
        self.assertEqual(detalhe["lembretes"]["lidos"], 1)
        self.assertTrue(detalhe["online"])
        self.assertEqual(len(detalhe["dispositivos"]), 1)
        # LGPD: nenhum payload clínico nas chaves devolvidas
        for proibido in ("dados", "respostas", "template_json", "relato_clinico_organizado"):
            self.assertNotIn(proibido, detalhe)
            self.assertNotIn(proibido, detalhe["usuario"])

    def test_detalhar_inexistente(self):
        self.assertIsNone(admin.detalhar_usuario("nao-existe"))


class AuditoriaEAcoesTests(unittest.TestCase):
    def setUp(self):
        _base_dados()

    def test_auditoria_registra_e_lista(self):
        admin.registrar_auditoria("dono@ex.com", "usuario.suspender", "alvo@ex.com", "teste", "1.2.3.4")
        registros = admin.listar_auditoria(limite=5)
        self.assertEqual(len(registros), 1)
        self.assertEqual(registros[0]["ator"], "dono@ex.com")
        self.assertEqual(registros[0]["acao"], "usuario.suspender")
        self.assertEqual(admin.listar_auditoria(alvo="alvo@ex.com")[0]["detalhe"], "teste")

    def test_definir_status(self):
        self.assertTrue(admin.definir_status_usuario("u1", "suspenso"))
        self.assertEqual(
            db.executar("SELECT status FROM usuarios WHERE id = 'u1'").fetchone()["status"],
            "suspenso",
        )
        with self.assertRaises(ValueError):
            admin.definir_status_usuario("u1", "banido")

    def test_definir_plano(self):
        self.assertTrue(admin.definir_plano_usuario("u1", "Essencial"))
        self.assertEqual(
            db.executar("SELECT plano FROM usuarios WHERE id = 'u1'").fetchone()["plano"],
            "essencial",
        )
        with self.assertRaises(ValueError):
            admin.definir_plano_usuario("u1", "plano com espaço")

    def test_renovar_token_confirmacao(self):
        _usuario("pend", "novo@ex.com", status="pendente")
        db.executar(
            "UPDATE usuarios SET email_verificacao_token_hash = 'antigo' WHERE id = 'pend'"
        ).commit()
        token = renovar_token_confirmacao("novo@ex.com")
        self.assertIsNotNone(token)
        linha = db.executar(
            "SELECT email_verificacao_token_hash FROM usuarios WHERE id = 'pend'"
        ).fetchone()
        self.assertNotEqual(linha["email_verificacao_token_hash"], "antigo")
        # Conta já ativa não recebe novo token
        self.assertIsNone(renovar_token_confirmacao("ativo@ex.com"))


class AdminAcoesHttpTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        _base_dados()
        main._rate_limit_store.clear()
        _usuario("admin-1", "dono@ex.com", role="admin")
        self.alvo_id = "u1"
        self.client = _cliente()
        self.addAsyncCleanup(self.client.aclose)
        login = await self.client.post(
            "/admin/login", data={"email": "dono@ex.com", "senha": SENHA}
        )
        self.assertEqual(login.status_code, 303)
        self.cookie = login.headers["set-cookie"].split(";")[0]
        # usa o cookie apenas via header explícito (senão o jar "loga" até os testes sem cookie)
        self.client.cookies.clear()

    async def _get(self, caminho):
        return await self.client.get(caminho, headers={"Cookie": self.cookie})

    async def _acao(self, dados: dict, usuario_id: str | None = None):
        usuario_id = usuario_id or self.alvo_id
        return await self.client.post(
            f"/admin/usuarios/{usuario_id}/acao", data=dados, headers={"Cookie": self.cookie}
        )

    async def test_dashboard_com_filtro_de_status(self):
        resposta = await self._get("/admin?status=pendente")
        self.assertEqual(resposta.status_code, 200)
        self.assertIn("pendente@ex.com", resposta.text)
        self.assertNotIn("suspenso@ex.com", resposta.text)
        self.assertIn("Exportar CSV", resposta.text)

    async def test_csv_de_usuarios(self):
        resposta = await self._get("/admin/usuarios.csv?status=pendente")
        self.assertEqual(resposta.status_code, 200)
        self.assertIn("text/csv", resposta.headers["content-type"])
        self.assertIn("attachment", resposta.headers["content-disposition"])
        self.assertIn("email;nome", resposta.text)
        self.assertIn("pendente@ex.com", resposta.text)
        self.assertNotIn("suspenso@ex.com", resposta.text)

    async def test_csv_exige_login(self):
        resposta = await self.client.get("/admin/usuarios.csv")
        self.assertEqual(resposta.status_code, 401)

    async def test_pagina_de_detalhe(self):
        resposta = await self._get(f"/admin/usuarios/{self.alvo_id}")
        self.assertEqual(resposta.status_code, 200)
        self.assertIn("ativo@ex.com", resposta.text)
        self.assertIn("Metadados operacionais", resposta.text)
        self.assertIn("Suspender conta", resposta.text)
        self.assertIn("Eventos", resposta.text)

    async def test_detalhe_exige_login(self):
        resposta = await self.client.get(f"/admin/usuarios/{self.alvo_id}")
        self.assertEqual(resposta.status_code, 200)
        self.assertIn("Entrar", resposta.text)
        self.assertNotIn("Suspender conta", resposta.text)

    async def test_acao_suspender_grava_auditoria(self):
        resposta = await self._acao({"acao": "suspender"})
        self.assertEqual(resposta.status_code, 303)
        self.assertIn("msg=", resposta.headers["location"])
        status = db.executar("SELECT status FROM usuarios WHERE id = 'u1'").fetchone()["status"]
        self.assertEqual(status, "suspenso")
        auditoria = admin.listar_auditoria(limite=5)
        self.assertEqual(auditoria[0]["acao"], "usuario.suspender")
        self.assertEqual(auditoria[0]["ator"], "dono@ex.com")
        self.assertEqual(auditoria[0]["alvo"], "ativo@ex.com")

    async def test_acao_reativar(self):
        await self._acao({"acao": "suspender"})
        resposta = await self._acao({"acao": "reativar"})
        self.assertEqual(resposta.status_code, 303)
        status = db.executar("SELECT status FROM usuarios WHERE id = 'u1'").fetchone()["status"]
        self.assertEqual(status, "ativo")

    async def test_acao_mudar_plano(self):
        resposta = await self._acao({"acao": "plano", "plano": "essencial"})
        self.assertEqual(resposta.status_code, 303)
        plano = db.executar("SELECT plano FROM usuarios WHERE id = 'u1'").fetchone()["plano"]
        self.assertEqual(plano, "essencial")
        self.assertEqual(admin.listar_auditoria(limite=1)[0]["acao"], "usuario.plano")

    async def test_acao_plano_invalido_redireciona_com_erro(self):
        resposta = await self._acao({"acao": "plano", "plano": "com espaço"})
        self.assertEqual(resposta.status_code, 303)
        self.assertIn("erro=", resposta.headers["location"])
        plano = db.executar("SELECT plano FROM usuarios WHERE id = 'u1'").fetchone()["plano"]
        self.assertEqual(plano, "pro")

    async def test_reenviar_confirmacao(self):
        _usuario("pend-2", "reenvio@ex.com", status="pendente")
        db.executar(
            "UPDATE usuarios SET email_verificacao_token_hash = 'antigo' WHERE id = 'pend-2'"
        ).commit()
        with patch.object(main, "_enviar_email", new=AsyncMock(return_value=True)):
            resposta = await self._acao({"acao": "reenviar_confirmacao"}, usuario_id="pend-2")
        self.assertEqual(resposta.status_code, 303)
        linha = db.executar(
            "SELECT email_verificacao_token_hash FROM usuarios WHERE id = 'pend-2'"
        ).fetchone()
        self.assertNotEqual(linha["email_verificacao_token_hash"], "antigo")
        self.assertEqual(
            admin.listar_auditoria(limite=1)[0]["acao"], "usuario.reenviar_confirmacao"
        )

    async def test_acao_sem_login_nao_altera(self):
        resposta = await self.client.post(
            f"/admin/usuarios/{self.alvo_id}/acao", data={"acao": "suspender"}
        )
        self.assertEqual(resposta.status_code, 200)
        self.assertIn("Entrar", resposta.text)
        status = db.executar("SELECT status FROM usuarios WHERE id = 'u1'").fetchone()["status"]
        self.assertEqual(status, "ativo")

    async def test_login_do_app_bloqueado_para_conta_suspensa(self):
        _usuario("sus-1", "bloqueado@ex.com", status="suspenso")
        resposta = await self.client.post(
            "/auth/login", json={"username": "bloqueado@ex.com", "password": SENHA}
        )
        self.assertEqual(resposta.status_code, 403)
        self.assertIn("suspensa", resposta.json()["detail"].lower())


if __name__ == "__main__":
    unittest.main()
