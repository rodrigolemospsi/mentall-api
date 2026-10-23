"""Fase 5B.2: papéis editáveis no painel e revogação de JWT de app (token_version)."""
import unittest
from datetime import datetime, timedelta, timezone

import httpx
import jwt
from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials

import main
from services import admin, db
from services.usuarios import hash_senha

SENHA = "SenhaForte123"
TABELAS = (
    "usuarios", "dispositivos", "eventos", "contratos", "anamneses", "lembretes",
    "wuzapi_instancias", "tokens_revogados", "admin_auditoria", "admin_seguranca",
    "admin_sessoes",
)


def _iso(minutos_atras: int = 0) -> str:
    return (datetime.now(timezone.utc) - timedelta(minutes=minutos_atras)).isoformat()


def _limpar() -> None:
    for tabela in TABELAS:
        db.executar(f"DELETE FROM {tabela}").commit()
    main._rate_limit_store.clear()
    main._ESTADO_TOKEN_CACHE.clear()


def _usuario(uid, email, role="admin", status="ativo", plano="pro"):
    db.executar(
        "INSERT INTO usuarios (id, email, password_hash, nome, plano, status, role, criado_em) "
        "VALUES (?, ?, ?, 'Nome', ?, ?, ?, ?)",
        (uid, email, hash_senha(SENHA), plano, status, role, _iso(30)),
    ).commit()


def _credencial(token: str) -> HTTPAuthorizationCredentials:
    return HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)


def _cliente(ip="203.0.113.70"):
    return httpx.AsyncClient(
        transport=httpx.ASGITransport(app=main.app, client=(ip, 55000)),
        base_url="https://test.invalid",
        follow_redirects=False,
    )


class TokenVersionTests(unittest.TestCase):
    def setUp(self):
        _limpar()
        _usuario("u1", "user@ex.com", role="user")

    def test_token_com_tv_valido(self):
        token = main._criar_token_jwt("user@ex.com", "u1", token_version=0)
        self.assertEqual(main._verificar_token(_credencial(token)), ("user@ex.com", "u1"))

    def test_revogacao_invalida_token_antigo(self):
        token = main._criar_token_jwt("user@ex.com", "u1", token_version=0)
        self.assertEqual(main._verificar_token(_credencial(token))[0], "user@ex.com")
        nova_versao = admin.revogar_sessoes_app("u1")
        self.assertEqual(nova_versao, 1)
        main._invalidar_cache_token("u1")
        with self.assertRaises(HTTPException) as contexto:
            main._verificar_token(_credencial(token))
        self.assertEqual(contexto.exception.status_code, 401)

    def test_token_novo_apos_revogacao_funciona(self):
        admin.revogar_sessoes_app("u1")
        token = main._criar_token_jwt("user@ex.com", "u1", token_version=1)
        self.assertEqual(main._verificar_token(_credencial(token))[0], "user@ex.com")

    def test_token_legado_sem_tv_continua_valido(self):
        token = main._criar_token_jwt("user@ex.com", "u1")
        self.assertEqual(main._verificar_token(_credencial(token))[0], "user@ex.com")

    def test_conta_suspensa_derruba_token(self):
        token = main._criar_token_jwt("user@ex.com", "u1", token_version=0)
        db.executar("UPDATE usuarios SET status = 'suspenso' WHERE id = 'u1'").commit()
        main._invalidar_cache_token("u1")
        with self.assertRaises(HTTPException) as contexto:
            main._verificar_token(_credencial(token))
        self.assertIn("indisponível", contexto.exception.detail.lower())


class PapelTests(unittest.TestCase):
    def setUp(self):
        _limpar()
        _usuario("u1", "user@ex.com", role="user")

    def test_definir_papel(self):
        self.assertTrue(admin.definir_papel_usuario("u1", "financeiro"))
        self.assertEqual(
            db.executar("SELECT role FROM usuarios WHERE id = 'u1'").fetchone()["role"],
            "financeiro",
        )
        with self.assertRaises(ValueError):
            admin.definir_papel_usuario("u1", "super-admin")


class HttpPainelSegurancaAppTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        _limpar()
        _usuario("admin-1", "dono@ex.com", role="admin")
        _usuario("u1", "user@ex.com", role="user")
        self.client = _cliente()
        self.addAsyncCleanup(self.client.aclose)
        login = await self.client.post(
            "/admin/login", data={"email": "dono@ex.com", "senha": SENHA}
        )
        self.assertEqual(login.status_code, 303)
        self.cookie = login.headers["set-cookie"].split(";")[0]
        # cookie só via header explícito (para testar requisições sem sessão também)
        self.client.cookies.clear()

    async def _acao(self, dados, usuario_id="u1"):
        return await self.client.post(
            f"/admin/usuarios/{usuario_id}/acao",
            data=dados,
            headers={"Cookie": self.cookie},
        )

    async def test_detalhe_mostra_formularios_de_papel_e_sessoes(self):
        pagina = await self.client.get("/admin/usuarios/u1", headers={"Cookie": self.cookie})
        self.assertEqual(pagina.status_code, 200)
        self.assertIn("Salvar papel", pagina.text)
        self.assertIn("Encerrar sessões do app", pagina.text)
        self.assertIn("Sessões do app revogadas", pagina.text)

    async def test_mudar_papel_pela_acao(self):
        resposta = await self._acao({"acao": "papel", "papel": "financeiro"})
        self.assertEqual(resposta.status_code, 303)
        self.assertEqual(
            db.executar("SELECT role FROM usuarios WHERE id = 'u1'").fetchone()["role"],
            "financeiro",
        )
        auditoria = admin.listar_auditoria(limite=1)
        self.assertEqual(auditoria[0]["acao"], "usuario.papel")

    async def test_nao_pode_remover_o_proprio_admin(self):
        resposta = await self._acao(
            {"acao": "papel", "papel": "suporte"}, usuario_id="admin-1"
        )
        self.assertEqual(resposta.status_code, 303)
        self.assertIn("erro=", resposta.headers["location"])
        self.assertEqual(
            db.executar("SELECT role FROM usuarios WHERE id = 'admin-1'").fetchone()["role"],
            "admin",
        )

    async def test_encerrar_sessoes_do_app(self):
        resposta = await self._acao({"acao": "encerrar_sessoes_app"})
        self.assertEqual(resposta.status_code, 303)
        self.assertEqual(
            db.executar("SELECT token_version FROM usuarios WHERE id = 'u1'").fetchone()["token_version"],
            1,
        )
        auditoria = admin.listar_auditoria(limite=1)
        self.assertEqual(auditoria[0]["acao"], "usuario.encerrar_sessoes_app")

    async def test_suspender_tambem_revoga_sessoes_do_app(self):
        await self._acao({"acao": "suspender"})
        linha = db.executar(
            "SELECT status, token_version FROM usuarios WHERE id = 'u1'"
        ).fetchone()
        self.assertEqual(linha["status"], "suspenso")
        self.assertEqual(linha["token_version"], 1)

    async def test_login_do_app_emite_token_com_versao(self):
        resposta = await self.client.post(
            "/auth/login", json={"username": "user@ex.com", "password": SENHA}
        )
        self.assertEqual(resposta.status_code, 200)
        payload = jwt.decode(
            resposta.json()["access_token"], main.JWT_SECRET, algorithms=[main.JWT_ALGORITHM]
        )
        self.assertEqual(payload.get("tv"), 0)


if __name__ == "__main__":
    unittest.main()
