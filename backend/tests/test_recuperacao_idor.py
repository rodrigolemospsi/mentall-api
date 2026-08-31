"""Testes do fix de IDOR em /auth/registrar-recuperacao (pentest Strix 30/08).

Cobrem:
1. Um profissional autenticado NÃO pode registrar/sobrescrever o
   `recovery_token` de um email que não é o dele (antes: upsert por
   sha256(email) sem comparar com o JWT).
2. O registro do próprio email continua funcionando.
"""
import os
import unittest
from unittest import mock

os.environ.setdefault("JWT_SECRET", "teste-segredo")
os.environ.setdefault("APP_PASSWORD_HASH", "teste-hash")
os.environ.setdefault("SMTP_HOST", "")
os.environ.setdefault("WUZAPI_BASE_URL", "")

import main  # noqa: E402
from fastapi import HTTPException  # noqa: E402
from models.schemas import RegistrarRecuperacaoRequest  # noqa: E402


class FakeCursor:
    def __init__(self, row=None, rowcount=0):
        self._row = row
        self._rowcount = rowcount
        self._commit = 0

    def fetchone(self):
        return self._row

    @property
    def rowcount(self):
        return self._rowcount

    def commit(self):
        self._commit += 1


class TestRegistrarRecuperacaoIDOR(unittest.TestCase):
    def setUp(self):
        main._rate_limit_store.clear()

    def _req(self, email="fulano@exemplo.com", token="tok1234567890"):
        req = mock.Mock(spec=RegistrarRecuperacaoRequest)
        req.email = email
        req.recovery_token = token
        return req

    def _fake_request(self):
        req = mock.Mock()
        req.client.host = "1.2.3.4"
        req.url.path = "/auth/registrar-recuperacao"
        return req

    def test_rejeita_email_de_outra_conta(self):
        """Atacante com JWT proprio tenta registrar recovery_token de vitima."""
        cursor = FakeCursor(None)
        with mock.patch("services.db.executar", return_value=cursor) as ex:
            with self.assertRaises(HTTPException) as ctx:
                main.registrar_recuperacao(
                    self._req(email="vitima@exemplo.com"),
                    self._fake_request(),
                    auth=("atacante@exemplo.com", "owner-atacante"),
                )
        self.assertEqual(ctx.exception.status_code, 403)
        ex.assert_not_called()  # nenhum SELECT/UPDATE/INSERT executado

    def test_aceita_email_proprio(self):
        """Profissional registra o proprio recovery_token."""
        cursor = FakeCursor(None)  # sem registro -> INSERT
        with mock.patch("services.db.executar", return_value=cursor) as ex:
            resp = main.registrar_recuperacao(
                self._req(email="fulano@exemplo.com"),
                self._fake_request(),
                auth=("fulano@exemplo.com", "owner-1"),
            )
        self.assertTrue(resp.sucesso)
        self.assertGreater(len(ex.call_args_list), 0)

    def test_aceita_email_proprio_maiusculo_vs_minusculo(self):
        """Comparacao de email deve ignorar caixa."""
        cursor = FakeCursor(None)
        with mock.patch("services.db.executar", return_value=cursor):
            resp = main.registrar_recuperacao(
                self._req(email="Fulano@Exemplo.COM"),
                self._fake_request(),
                auth=("fulano@exemplo.com", "owner-1"),
            )
        self.assertTrue(resp.sucesso)


if __name__ == "__main__":
    unittest.main()
