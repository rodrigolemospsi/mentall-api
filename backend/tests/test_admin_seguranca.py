"""Fase 5B.1: 2FA TOTP, sessões com inatividade, logout global, papéis e CSRF."""
import os
import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

import httpx
import jwt

import main
from services import admin_seguranca as seg, db
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


def _usuario(uid, email, role="admin", status="ativo"):
    db.executar(
        "INSERT INTO usuarios (id, email, password_hash, nome, plano, status, role, criado_em) "
        "VALUES (?, ?, ?, 'Nome', 'pro', ?, ?, ?)",
        (uid, email, hash_senha(SENHA), status, role, _iso(30)),
    ).commit()


def _cliente(ip="203.0.113.60"):
    return httpx.AsyncClient(
        transport=httpx.ASGITransport(app=main.app, client=(ip, 55000)),
        base_url="https://test.invalid",
        follow_redirects=False,
    )


def _csrf_de(header_cookie: str) -> str:
    token = header_cookie.split("=", 1)[1]
    payload = jwt.decode(token, main.JWT_SECRET, algorithms=[main.JWT_ALGORITHM])
    return payload.get("csrf") or ""


class TotpTests(unittest.TestCase):
    def test_vetor_rfc6238(self):
        # RFC 6238, SHA1, segredo ASCII "12345678901234567890", T=59 s → 94287082;
        # our implementation uses 6 digits → últimos 6 = 287082.
        import base64
        segredo = base64.b32encode(b"12345678901234567890").decode()
        self.assertEqual(seg.codigo_totp(segredo, quando=59), "287082")
        self.assertEqual(seg.codigo_totp(segredo, quando=1111111109)[-6:], seg.codigo_totp(segredo, quando=1111111109))

    def test_verificacao_aceita_janela(self):
        segredo = seg.gerar_segredo()
        codigo = seg.codigo_totp(segredo)
        self.assertTrue(seg.verificar_codigo_totp(segredo, codigo))
        self.assertFalse(seg.verificar_codigo_totp(segredo, "000000"))
        self.assertFalse(seg.verificar_codigo_totp(segredo, "abc"))

    def test_uri_otpauth(self):
        segredo = seg.gerar_segredo()
        uri = seg.uri_otpauth(segredo, "dono@ex.com")
        self.assertTrue(uri.startswith("otpauth://totp/"))
        self.assertIn(segredo, uri)
        self.assertIn("issuer=MentAll%20PRO", uri)


class Ativacao2FATests(unittest.TestCase):
    def setUp(self):
        _limpar()

    def test_fluxo_de_ativacao_e_backup(self):
        _usuario("a1", "dono@ex.com")
        self.assertFalse(seg.totp_ativo("dono@ex.com"))
        dados = seg.iniciar_ativacao("dono@ex.com")
        self.assertIn("segredo", dados)
        self.assertTrue(seg.estado("dono@ex.com")["pendente"])

        codigo = seg.codigo_totp(dados["segredo"])
        recuperacao = seg.confirmar_ativacao("dono@ex.com", codigo)
        self.assertIsNotNone(recuperacao)
        self.assertEqual(len(recuperacao), 8)
        self.assertTrue(seg.totp_ativo("dono@ex.com"))
        self.assertEqual(seg.estado("dono@ex.com")["backup_restantes"], 8)

        # código de recuperação consome (uma vez)
        self.assertTrue(seg.validar_codigo("dono@ex.com", recuperacao[0]))
        self.assertFalse(seg.validar_codigo("dono@ex.com", recuperacao[0]))
        self.assertEqual(seg.estado("dono@ex.com")["backup_restantes"], 7)

        # TOTP atual continua válido
        self.assertTrue(seg.validar_codigo("dono@ex.com", seg.codigo_totp(dados["segredo"])))

        seg.desativar("dono@ex.com")
        self.assertFalse(seg.totp_ativo("dono@ex.com"))
        self.assertFalse(seg.validar_codigo("dono@ex.com", codigo))

    def test_confirmar_com_codigo_errado(self):
        _usuario("a1", "dono@ex.com")
        seg.iniciar_ativacao("dono@ex.com")
        self.assertIsNone(seg.confirmar_ativacao("dono@ex.com", "000000"))
        self.assertFalse(seg.totp_ativo("dono@ex.com"))


class SessoesTests(unittest.TestCase):
    def setUp(self):
        _limpar()

    def test_sessao_valida_e_expira_por_inatividade(self):
        seg.registrar_sessao("jti-1", "dono@ex.com")
        self.assertTrue(seg.sessao_valida("jti-1", "dono@ex.com"))
        db.executar(
            "UPDATE admin_sessoes SET ultimo_visto_em = ? WHERE jti = 'jti-1'", (_iso(61),)
        ).commit()
        self.assertFalse(seg.sessao_valida("jti-1", "dono@ex.com"))

    def test_sessao_de_outro_ator_invalida(self):
        seg.registrar_sessao("jti-1", "dono@ex.com")
        self.assertFalse(seg.sessao_valida("jti-1", "outro@ex.com"))

    def test_sessao_desconhecida_e_criada(self):
        self.assertTrue(seg.sessao_valida("jti-novo", "dono@ex.com"))
        self.assertIsNotNone(
            db.executar("SELECT 1 FROM admin_sessoes WHERE jti = 'jti-novo'").fetchone()
        )

    def test_revogar_todas(self):
        seg.registrar_sessao("jti-1", "dono@ex.com")
        seg.registrar_sessao("jti-2", "dono@ex.com")
        seg.registrar_sessao("jti-3", "outro@ex.com")
        self.assertEqual(seg.revogar_todas_sessoes("dono@ex.com"), 2)
        self.assertEqual(
            db.executar("SELECT COUNT(*) AS n FROM admin_sessoes WHERE ator='dono@ex.com'").fetchone()["n"], 0
        )
        self.assertEqual(
            db.executar("SELECT COUNT(*) AS n FROM tokens_revogados").fetchone()["n"], 2
        )
        self.assertEqual(
            db.executar("SELECT COUNT(*) AS n FROM admin_sessoes WHERE ator='outro@ex.com'").fetchone()["n"], 1
        )


class AdminSegurancaHttpTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        _limpar()
        main._rate_limit_store.clear()
        _usuario("admin-1", "dono@ex.com", role="admin")
        _usuario("fin-1", "financeiro@ex.com", role="financeiro")
        _usuario("sup-1", "suporte@ex.com", role="suporte")
        self.client = _cliente()
        self.addAsyncCleanup(self.client.aclose)

    async def _login(self, email="dono@ex.com", senha=SENHA):
        return await self.client.post("/admin/login", data={"email": email, "senha": senha})

    async def _cookie_de(self, resposta) -> str:
        return resposta.headers["set-cookie"].split(";")[0]

    async def test_login_sem_2fa_registra_sessao(self):
        resposta = await self._login()
        self.assertEqual(resposta.status_code, 303)
        cookie = await self._cookie_de(resposta)
        self.assertEqual(
            db.executar("SELECT COUNT(*) AS n FROM admin_sessoes").fetchone()["n"], 1
        )
        painel = await self.client.get("/admin", headers={"Cookie": cookie})
        self.assertEqual(painel.status_code, 200)
        self.assertIn("Psicólogos", painel.text)

    async def test_login_com_2fa_pede_codigo_e_abre_painel(self):
        dados = seg.iniciar_ativacao("dono@ex.com")
        self.assertIsNotNone(
            seg.confirmar_ativacao("dono@ex.com", seg.codigo_totp(dados["segredo"]))
        )
        primeira = await self._login()
        self.assertEqual(primeira.status_code, 303)
        self.assertTrue(primeira.headers["location"].endswith("/admin/2fa"))
        pre_cookie = await self._cookie_de(primeira)

        pagina = await self.client.get("/admin/2fa", headers={"Cookie": pre_cookie})
        self.assertEqual(pagina.status_code, 200)
        self.assertIn("Verificação em 2 etapas", pagina.text)

        errado = await self.client.post(
            "/admin/2fa", data={"codigo": "000000"}, headers={"Cookie": pre_cookie}
        )
        self.assertEqual(errado.status_code, 200)
        self.assertIn("Código inválido", errado.text)

        segredo = db.executar(
            "SELECT totp_secret FROM admin_seguranca WHERE ator = 'dono@ex.com'"
        ).fetchone()["totp_secret"]
        certo = await self.client.post(
            "/admin/2fa",
            data={"codigo": seg.codigo_totp(segredo)},
            headers={"Cookie": pre_cookie},
        )
        self.assertEqual(certo.status_code, 303)
        sessao = await self._cookie_de(certo)
        painel = await self.client.get("/admin", headers={"Cookie": sessao})
        self.assertEqual(painel.status_code, 200)
        self.assertIn("Saúde do sistema", painel.text)

    async def test_sessao_expira_por_inatividade(self):
        resposta = await self._login()
        cookie = await self._cookie_de(resposta)
        db.executar(
            "UPDATE admin_sessoes SET ultimo_visto_em = ?", (_iso(120),)
        ).commit()
        painel = await self.client.get("/admin", headers={"Cookie": cookie})
        self.assertIn("Entrar", painel.text)
        self.assertNotIn("Psicólogos", painel.text)

    async def test_logout_global_derruba_todas_as_sessoes(self):
        resposta = await self._login()
        cookie = await self._cookie_de(resposta)
        saida = await self.client.post(
            "/admin/logout-todos", headers={"Cookie": cookie}
        )
        self.assertEqual(saida.status_code, 303)
        depois = await self.client.get("/admin", headers={"Cookie": cookie})
        self.assertIn("Entrar", depois.text)
        self.assertEqual(
            db.executar("SELECT COUNT(*) AS n FROM admin_sessoes").fetchone()["n"], 0
        )

    async def test_papel_financeiro_nao_gerencia_email_nem_usuarios(self):
        resposta = await self._login("financeiro@ex.com")
        self.assertEqual(resposta.status_code, 303)
        cookie = await self._cookie_de(resposta)

        painel = await self.client.get("/admin", headers={"Cookie": cookie})
        self.assertEqual(painel.status_code, 200)
        self.assertNotIn('href="/admin/email"', painel.text)

        email = await self.client.get("/admin/email", headers={"Cookie": cookie})
        self.assertEqual(email.status_code, 403)

        csv = await self.client.get("/admin/usuarios.csv", headers={"Cookie": cookie})
        self.assertEqual(csv.status_code, 200)

        acao = await self.client.post(
            "/admin/usuarios/admin-1/acao",
            data={"acao": "suspender"},
            headers={"Cookie": cookie},
        )
        self.assertEqual(acao.status_code, 403)
        self.assertEqual(
            db.executar("SELECT status FROM usuarios WHERE id = 'admin-1'").fetchone()["status"],
            "ativo",
        )

    async def test_papel_suporte_apenas_visualiza(self):
        resposta = await self._login("suporte@ex.com")
        cookie = await self._cookie_de(resposta)
        painel = await self.client.get("/admin", headers={"Cookie": cookie})
        self.assertEqual(painel.status_code, 200)
        detalhe = await self.client.get("/admin/usuarios/admin-1", headers={"Cookie": cookie})
        self.assertEqual(detalhe.status_code, 200)
        self.assertIn("Metadados operacionais", detalhe.text)
        self.assertNotIn("Suspender conta", detalhe.text)
        csv = await self.client.get("/admin/usuarios.csv", headers={"Cookie": cookie})
        self.assertEqual(csv.status_code, 403)
        email = await self.client.get("/admin/email", headers={"Cookie": cookie})
        self.assertEqual(email.status_code, 403)

    async def test_origem_cross_site_bloqueada(self):
        resposta = await self._login()
        cookie = await self._cookie_de(resposta)
        ataque = await self.client.post(
            "/admin/logout",
            headers={"Cookie": cookie, "Origin": "https://evil.example"},
        )
        self.assertEqual(ataque.status_code, 403)
        legitimo = await self.client.post(
            "/admin/logout",
            headers={"Cookie": cookie, "Origin": "https://test.invalid"},
        )
        self.assertEqual(legitimo.status_code, 303)

    async def test_2fa_obrigatorio_redireciona_para_seguranca(self):
        with patch.dict(os.environ, {"ADMIN_2FA_OBRIGATORIO": "1"}, clear=False):
            resposta = await self._login()
            self.assertEqual(resposta.status_code, 303)
            cookie = await self._cookie_de(resposta)
            painel = await self.client.get("/admin", headers={"Cookie": cookie})
            self.assertEqual(painel.status_code, 303)
            self.assertIn("/admin/seguranca", painel.headers["location"])
            seguranca = await self.client.get("/admin/seguranca", headers={"Cookie": cookie})
            self.assertEqual(seguranca.status_code, 200)
            self.assertIn("Verificação em 2 etapas", seguranca.text)


if __name__ == "__main__":
    unittest.main()
