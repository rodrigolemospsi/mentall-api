"""Testes do endurecimento de senha no registrar (pentest Strix 28/08).

A senha aceitava 6 chars sem complexidade (ex: `123456`), viabilizando
brute-force online combinado com rate-limit bypass. Agora exige >= 10 chars
com maiuscula, minuscula e numero.
"""
import os
import unittest
from unittest import mock

os.environ.setdefault("JWT_SECRET", "teste-segredo")
os.environ.setdefault("APP_PASSWORD_HASH", "teste-hash")
os.environ.setdefault("SMTP_HOST", "")
os.environ.setdefault("WUZAPI_BASE_URL", "")

import main  # noqa: E402
from models.schemas import RegistrarRequest  # noqa: E402


class TestSenhaForte(unittest.TestCase):
    def test_senha_curta_rejeitada(self):
        self.assertFalse(main._senha_forte("abc123"))

    def test_senha_sem_maiuscula_rejeitada(self):
        self.assertFalse(main._senha_forte("abcdefgh1"))

    def test_senha_sem_numero_rejeitada(self):
        self.assertFalse(main._senha_forte("Abcdefghi"))

    def test_senha_valida_aceita(self):
        self.assertTrue(main._senha_forte("SenhaForte123"))

    def test_schema_valida_10_chars_min(self):
        with self.assertRaises(Exception):
            RegistrarRequest(email="a@b.com", senha="Curta1", nome="X")

    def test_schema_aceita_senha_forte(self):
        req = RegistrarRequest(email="a@b.com", senha="SenhaForte123", nome="X")
        self.assertEqual(req.senha, "SenhaForte123")

    def test_registrar_rejeita_senha_fraca(self):
        req = mock.Mock(spec=RegistrarRequest)
        req.email = "a@b.com"
        req.senha = "123456"
        req.nome = "X"
        with mock.patch("services.db.executar"):
            from fastapi import HTTPException
            with self.assertRaises(HTTPException) as ctx:
                main._validar_registro_ou_raise(req)
        self.assertEqual(ctx.exception.status_code, 422)


if __name__ == "__main__":
    unittest.main()
