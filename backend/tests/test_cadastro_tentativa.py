"""Real SQL regression tests for credential/token binding, including interleavings."""
import re
import unittest
from unittest.mock import AsyncMock, patch

import httpx
import main
from services import db, usuarios


class CadastroTentativaTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        db.executar("DELETE FROM usuarios").commit()
        main._rate_limit_store.clear()
        self.email = "titular@example.invalid"
        self.senha_a = "SenhaTerceiro123"
        self.senha_b = "SenhaTitular456"
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=main.app), base_url="https://test.invalid")
        self.addAsyncCleanup(self.client.aclose)
        self.mail = AsyncMock(return_value=True)
        patcher = patch("main._enviar_email", self.mail)
        patcher.start()
        self.addCleanup(patcher.stop)

    async def cadastrar(self, senha, nome):
        return await self.client.post("/auth/registrar", json={
            "email": self.email, "senha": senha, "nome": nome})

    def token_enviado(self):
        return re.search(r"confirmar-email\?token=([^\"]+)", self.mail.call_args.args[2])[1]

    async def test_nova_tentativa_invalida_link_a_e_ativa_somente_senha_b(self):
        self.assertEqual((await self.cadastrar(self.senha_a, "Terceiro")).status_code, 200)
        token_a = self.token_enviado()
        self.assertEqual((await self.cadastrar(self.senha_b, "Titular")).status_code, 200)
        token_b = self.token_enviado()
        self.assertIsNone(usuarios.confirmar_email(token_a))
        self.assertIsNotNone(usuarios.confirmar_email(token_b))
        for senha, expected in ((self.senha_a, 401), (self.senha_b, 200)):
            response = await self.client.post("/auth/login", json={"username": self.email, "password": senha})
            self.assertEqual(response.status_code, expected)
            if expected == 200:
                self.assertEqual(response.json()["nome"], "Titular")

    async def test_conta_ativa_nao_sobrescrita(self):
        await self.cadastrar(self.senha_a, "Original")
        usuarios.confirmar_email(self.token_enviado())
        original = usuarios.obter_por_email(self.email)
        self.assertEqual((await self.cadastrar(self.senha_b, "Outra")).status_code, 409)
        self.assertEqual(usuarios.obter_por_email(self.email), original)
        self.assertEqual(self.mail.await_count, 1)

    async def test_rotacao_entre_leitura_e_update_de_confirmacao(self):
        await self.cadastrar(self.senha_a, "Original")
        token_a = self.token_enviado()
        token_b = "tentativa-b-sintetica"
        senha_hash_b = usuarios.hash_senha(self.senha_b)
        rotated = False

        def intercalar(sql, params=()):
            nonlocal rotated
            if sql.startswith("UPDATE usuarios SET status") and not rotated:
                rotated = True
                db.executar(
                    "UPDATE usuarios SET password_hash = ?, nome = ?, email_verificacao_token_hash = ? "
                    "WHERE email = ? AND status = 'pendente'",
                    (senha_hash_b, "Titular", usuarios._hash_token(token_b), self.email)).commit()
            return db.executar(sql, params)

        with patch("services.usuarios.executar", side_effect=intercalar):
            self.assertIsNone(usuarios.confirmar_email(token_a))
        self.assertTrue(rotated)
        self.assertEqual(usuarios.obter_por_email(self.email)["status"], "pendente")
        self.assertEqual(usuarios.confirmar_email(token_b)["nome"], "Titular")
        self.assertIsNone(usuarios.autenticar(self.email, self.senha_a))

    async def test_confirmacao_vence_rotacao_nao_altera_conta_ativa(self):
        await self.cadastrar(self.senha_a, "Original")
        token_a = self.token_enviado()
        original = None

        def confirmar_antes_de_gravar():
            nonlocal original
            usuarios.confirmar_email(token_a)
            original = usuarios.obter_por_email(self.email)
            return "novo-token-nao-deve-ser-gravado"

        with patch("services.usuarios._gerar_token", side_effect=confirmar_antes_de_gravar):
            response = await self.cadastrar(self.senha_b, "Outra")
        self.assertEqual(response.status_code, 409)
        self.assertEqual(usuarios.obter_por_email(self.email), original)
        self.assertEqual(self.mail.await_count, 1)

    async def test_reclique_apenas_hash_correto_ativo(self):
        await self.cadastrar(self.senha_b, "Titular")
        token = self.token_enviado()
        first = usuarios.confirmar_email(token)
        self.assertEqual(usuarios.confirmar_email(token), first)
        self.assertIsNone(usuarios.confirmar_email("outro-token"))

    async def test_confirmacao_nao_reativa_suspenso(self):
        await self.cadastrar(self.senha_a, "Original")
        token = self.token_enviado()
        db.executar("UPDATE usuarios SET status = 'suspenso' WHERE email = ?", (self.email,)).commit()
        self.assertIsNone(usuarios.confirmar_email(token))
        self.assertEqual((await self.cadastrar(self.senha_b, "Outra")).status_code, 409)
        self.assertEqual(usuarios.obter_por_email(self.email)["status"], "suspenso")

    async def test_expiracao_ausente_invalida_ou_passada_rejeitada(self):
        await self.cadastrar(self.senha_a, "Original")
        token = self.token_enviado()
        for expiry in (None, "", "invalid", "2000-01-01T00:00:00+00:00"):
            db.executar("UPDATE usuarios SET email_verificacao_expiracao = ? WHERE email = ?", (expiry, self.email)).commit()
            self.assertIsNone(usuarios.confirmar_email(token))
            self.assertEqual(usuarios.obter_por_email(self.email)["status"], "pendente")

    async def test_expira_entre_select_e_update_nao_ativa(self):
        await self.cadastrar(self.senha_a, "Original")
        token = self.token_enviado()

        def expirar(sql, params=()):
            if sql.startswith("UPDATE usuarios SET status"):
                db.executar("UPDATE usuarios SET email_verificacao_expiracao = ? WHERE email = ?",
                            ("2000-01-01T00:00:00+00:00", self.email)).commit()
            return db.executar(sql, params)

        with patch("services.usuarios.executar", side_effect=expirar):
            self.assertIsNone(usuarios.confirmar_email(token))
        self.assertEqual(usuarios.obter_por_email(self.email)["status"], "pendente")
