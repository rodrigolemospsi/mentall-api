"""Testes da redefinicao de senha da conta (esqueci minha senha).

Cobrem o fluxo novo (distinto da recuperacao de PIN):
1. `solicitar_reset_senha` grava codigo e envia e-mail quando a conta existe.
2. `solicitar_reset_senha` responde generico e NAO grava quando a conta nao existe (anti-enumeracao).
3. `redefinir_senha` com codigo valido troca o password_hash e limpa o registro.
4. `redefinir_senha` com codigo invalido incrementa tentativas.
5. `redefinir_senha` bloqueia apos MAX_TENTATIVAS.
6. `redefinir_senha` rejeita senha fraca (422).
7. `redefinir_senha` rejeita codigo expirado.
"""
import asyncio
import os
import unittest
from unittest import mock

os.environ.setdefault("JWT_SECRET", "teste-segredo")
os.environ.setdefault("APP_PASSWORD_HASH", "teste-hash")
os.environ.setdefault("SMTP_HOST", "")
os.environ.setdefault("WUZAPI_BASE_URL", "")

import main  # noqa: E402
from fastapi import HTTPException  # noqa: E402
from models.schemas import RecuperacaoRequest, RedefinirSenhaRequest  # noqa: E402


class FakeCursor:
    def __init__(self, row=None, rowcount=0):
        self._row = row
        self._rowcount = rowcount
        self._commit = 0

    def fetchone(self):
        return self._row

    def fetchall(self):
        return [self._row] if self._row is not None else []

    @property
    def rowcount(self):
        return self._rowcount

    def commit(self):
        self._commit += 1


def _fake_request():
    req = mock.Mock()
    req.client.host = "1.2.3.4"
    req.url.path = "/auth/redefinir-senha"
    return req


class TestSolicitarResetSenha(unittest.TestCase):
    def setUp(self):
        main._rate_limit_store.clear()

    def _req(self, email="fulano@exemplo.com"):
        req = mock.Mock(spec=RecuperacaoRequest)
        req.email = email
        return req

    def test_conta_existente_grava_e_envia(self):
        cursor = FakeCursor(row=None)  # sem registro previo -> INSERT
        with mock.patch("services.usuarios.obter_por_email",
                        return_value={"email": "fulano@exemplo.com", "status": "ativo"}), \
             mock.patch("services.db.executar", return_value=cursor) as ex, \
             mock.patch("main._enviar_email", new=mock.AsyncMock(return_value=True)) as enviar:
            resp = asyncio.run(main.solicitar_reset_senha(self._req(), _fake_request()))
        self.assertTrue(resp.sucesso)
        self.assertTrue(enviar.await_count == 1)
        # gravou o codigo
        self.assertTrue(any("INSERT INTO resets_senha" in c[0][0] for c in ex.call_args_list))

    def test_conta_inexistente_nao_grava(self):
        with mock.patch("services.usuarios.obter_por_email", return_value=None), \
             mock.patch("services.db.executar") as ex, \
             mock.patch("main._enviar_email", new=mock.AsyncMock(return_value=True)) as enviar:
            resp = asyncio.run(main.solicitar_reset_senha(self._req(), _fake_request()))
        self.assertTrue(resp.sucesso)  # generico
        self.assertEqual(enviar.await_count, 0)
        ex.assert_not_called()

    def test_rate_limit(self):
        cursor = FakeCursor(row=None)
        with mock.patch("services.usuarios.obter_por_email", return_value=None), \
             mock.patch("services.db.executar", return_value=cursor), \
             mock.patch("main._enviar_email", new=mock.AsyncMock(return_value=True)):
            for _ in range(3):
                asyncio.run(main.solicitar_reset_senha(self._req(), _fake_request()))
            with self.assertRaises(HTTPException) as ctx:
                asyncio.run(main.solicitar_reset_senha(self._req(), _fake_request()))
        self.assertEqual(ctx.exception.status_code, 429)


class TestRedefinirSenha(unittest.TestCase):
    def setUp(self):
        main._rate_limit_store.clear()

    def _req(self, email="fulano@exemplo.com", codigo="ABCD1234", nova="NovaSenha123"):
        req = mock.Mock(spec=RedefinirSenhaRequest)
        req.email = email
        req.codigo = codigo
        req.nova_senha = nova
        return req

    def _registro(self, **kwargs):
        base = {
            "codigo_hash": main._hash_codigo("ABCD1234"),
            "codigo_expiracao": "2099-01-01T00:00:00+00:00",
            "tentativas": 0,
            "bloqueio_ate": None,
        }
        base.update(kwargs)
        return base

    def test_codigo_valido_troca_senha_e_limpa(self):
        cursor = FakeCursor(self._registro())
        with mock.patch("services.db.executar", return_value=cursor) as ex, \
             mock.patch("services.usuarios.redefinir_senha", return_value=True) as troca:
            resp = main.redefinir_senha(self._req(), _fake_request())
        self.assertTrue(resp.sucesso)
        troca.assert_called_once()
        self.assertEqual(troca.call_args[0][0], "fulano@exemplo.com")
        self.assertEqual(troca.call_args[0][1], "NovaSenha123")
        self.assertTrue(any("DELETE FROM resets_senha" in c[0][0] for c in ex.call_args_list))

    def test_codigo_invalido_incrementa_tentativas(self):
        cursor = FakeCursor(self._registro())
        with mock.patch("services.db.executar", return_value=cursor) as ex, \
             mock.patch("services.usuarios.redefinir_senha", return_value=True) as troca:
            resp = main.redefinir_senha(self._req(codigo="WRONG111"), _fake_request())
        self.assertFalse(resp.sucesso)
        troca.assert_not_called()
        update_args = ex.call_args_list[-1][0]
        self.assertIn("tentativas = ?", update_args[0])
        self.assertEqual(update_args[1][0], 1)

    def test_bloqueia_apos_max_tentativas(self):
        cursor = FakeCursor(self._registro(tentativas=main.MAX_TENTATIVAS_RECUPERACAO - 1))
        with mock.patch("services.db.executar", return_value=cursor) as ex, \
             mock.patch("services.usuarios.redefinir_senha", return_value=True):
            resp = main.redefinir_senha(self._req(codigo="WRONG111"), _fake_request())
        self.assertFalse(resp.sucesso)
        self.assertIn("bloqueio_ate = ?", ex.call_args_list[-1][0][0])

    def test_senha_fraca_422(self):
        with self.assertRaises(HTTPException) as ctx:
            main.redefinir_senha(self._req(nova="fraca"), _fake_request())
        self.assertEqual(ctx.exception.status_code, 422)

    def test_codigo_expirado(self):
        cursor = FakeCursor(self._registro(codigo_expiracao="2000-01-01T00:00:00+00:00"))
        with mock.patch("services.db.executar", return_value=cursor), \
             mock.patch("services.usuarios.redefinir_senha", return_value=True) as troca:
            resp = main.redefinir_senha(self._req(), _fake_request())
        self.assertFalse(resp.sucesso)
        self.assertIn("expirado", resp.erro.lower())
        troca.assert_not_called()

    def test_sem_registro_generico(self):
        cursor = FakeCursor(None)
        with mock.patch("services.db.executar", return_value=cursor), \
             mock.patch("services.usuarios.redefinir_senha", return_value=True) as troca:
            resp = main.redefinir_senha(self._req(), _fake_request())
        self.assertFalse(resp.sucesso)
        troca.assert_not_called()


if __name__ == "__main__":
    unittest.main()
