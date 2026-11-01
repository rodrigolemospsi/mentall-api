"""Recuperação de senha do painel (self-service, sem depender do app)."""
import re
import unittest
from unittest.mock import AsyncMock, patch

import httpx
import main
from services import db, usuarios


class AdminRecuperacaoTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        db.executar("DELETE FROM usuarios").commit()
        db.executar("DELETE FROM resets_senha").commit()
        db.executar("DELETE FROM admin_sessoes").commit()
        main._rate_limit_store.clear()
        self.email = "admin.teste@example.invalid"
        usuarios.criar_usuario_pendente(self.email, "SenhaAntiga123", "Admin Teste")
        db.executar(
            "UPDATE usuarios SET role = 'admin', status = 'ativo' WHERE email = ?",
            (self.email,),
        ).commit()
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=main.app),
            base_url="https://test.invalid",
        )
        self.addAsyncCleanup(self.client.aclose)

    async def test_login_tem_link_esqueci_senha(self):
        # A página de login é renderizada em GET /admin quando não há sessão.
        pagina = await self.client.get("/admin")
        self.assertEqual(pagina.status_code, 200)
        self.assertIn("Esqueci minha senha", pagina.text)
        self.assertIn("/admin/esqueci-senha", pagina.text)

    async def test_paginas_de_recuperacao_renderizam(self):
        p1 = await self.client.get("/admin/esqueci-senha")
        self.assertEqual(p1.status_code, 200)
        self.assertIn("Enviar código por e-mail", p1.text)

        p2 = await self.client.get("/admin/redefinir-senha")
        self.assertEqual(p2.status_code, 200)
        self.assertIn("Definir nova senha", p2.text)

        p3 = await self.client.get(
            "/admin/redefinir-senha", params={"email": self.email})
        self.assertIn(self.email, p3.text)

    async def test_email_desconhecido_recebe_resposta_generica_sem_enviar(self):
        with patch.object(
            main, "_enviar_email", new=AsyncMock(return_value=True)
        ) as enviar:
            resposta = await self.client.post(
                "/admin/esqueci-senha",
                data={"email": "ninguem@example.invalid"},
            )
        self.assertEqual(resposta.status_code, 200)
        self.assertIn("Se o e-mail for de uma conta do painel", resposta.text)
        enviar.assert_not_awaited()
        self.assertEqual(
            db.executar("SELECT COUNT(*) AS n FROM resets_senha").fetchone()["n"], 0
        )

    async def _solicitar_codigo(self) -> str:
        enviar = AsyncMock(return_value=True)
        with patch.object(main, "_enviar_email", new=enviar):
            resposta = await self.client.post(
                "/admin/esqueci-senha", data={"email": self.email}
            )
        self.assertEqual(resposta.status_code, 200)
        enviar.assert_awaited_once()
        corpo = enviar.await_args.args[2]
        achado = re.search(r'letter-spacing:4px;">([A-Z0-9]+)<', corpo)
        self.assertIsNotNone(achado, "código não encontrado no e-mail")
        return achado.group(1)

    async def test_fluxo_completo_redefine_senha_e_encerra_sessoes(self):
        db.executar(
            "INSERT INTO admin_sessoes (jti, ator, criado_em, ultimo_visto_em) "
            "VALUES ('j1', ?, 'x', 'x')",
            (self.email,),
        ).commit()
        codigo = await self._solicitar_codigo()

        resposta = await self.client.post(
            "/admin/redefinir-senha",
            data={
                "email": self.email,
                "codigo": codigo,
                "nova_senha": "SenhaNova123",
                "confirmar": "SenhaNova123",
            },
        )
        self.assertEqual(resposta.status_code, 200)
        self.assertIn("Senha redefinida com sucesso", resposta.text)

        self.assertIsNotNone(usuarios.autenticar(self.email, "SenhaNova123"))
        self.assertIsNone(usuarios.autenticar(self.email, "SenhaAntiga123"))
        self.assertEqual(
            db.executar("SELECT COUNT(*) AS n FROM admin_sessoes").fetchone()["n"], 0
        )

    async def test_codigo_errado_e_senha_fraca_nao_alteram(self):
        await self._solicitar_codigo()
        errado = await self.client.post(
            "/admin/redefinir-senha",
            data={
                "email": self.email,
                "codigo": "00000000",
                "nova_senha": "SenhaNova123",
                "confirmar": "SenhaNova123",
            },
        )
        self.assertEqual(errado.status_code, 400)
        self.assertIn("Código inválido", errado.text)

        fraca = await self.client.post(
            "/admin/redefinir-senha",
            data={
                "email": self.email,
                "codigo": "00000000",
                "nova_senha": "fraca",
                "confirmar": "fraca",
            },
        )
        self.assertEqual(fraca.status_code, 400)
        self.assertIn("10 caracteres", fraca.text)
        self.assertIsNotNone(usuarios.autenticar(self.email, "SenhaAntiga123"))

    async def test_confirmacao_divergente(self):
        await self._solicitar_codigo()
        resposta = await self.client.post(
            "/admin/redefinir-senha",
            data={
                "email": self.email,
                "codigo": "00000000",
                "nova_senha": "SenhaNova123",
                "confirmar": "OutraSenha123",
            },
        )
        self.assertEqual(resposta.status_code, 400)
        self.assertIn("não conferem", resposta.text)
        self.assertIsNotNone(usuarios.autenticar(self.email, "SenhaAntiga123"))


if __name__ == "__main__":
    unittest.main()
