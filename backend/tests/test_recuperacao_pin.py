"""Testes do endurecimento da recuperacao de PIN (pentest Strix 28/08).

Cobrem:
1. `_gerar_codigo` gera 8+ caracteres alfanumericos (antes 6 digitos).
2. `_hash_codigo` usa hash lento com salt (bcrypt), nao sha256 puro.
3. `_verificar_codigo` valida o hash novo e aceita fallback legado sha256.
4. `verificar_recuperacao` incrementa tentativas e bloqueia apos N falhas.
5. `verificar_recuperacao` com SELECT corrigido (codigo_hash, nao `codigo`).
"""
import hashlib
import os
import string
import unittest
from unittest import mock

os.environ.setdefault("JWT_SECRET", "teste-segredo")
os.environ.setdefault("APP_PASSWORD_HASH", "teste-hash")
os.environ.setdefault("SMTP_HOST", "")
os.environ.setdefault("WUZAPI_BASE_URL", "")

import main  # noqa: E402
from models.schemas import VerificarCodigoRequest  # noqa: E402


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


class TestGerarCodigo(unittest.TestCase):
    def test_codigo_tem_8_caracteres(self):
        for _ in range(50):
            codigo = main._gerar_codigo()
            self.assertEqual(len(codigo), main.CODIGO_RECUPERACAO_COMPRIMENTO)
            self.assertEqual(len(codigo), 8)

    def test_codigo_eh_alfanumerico(self):
        alfabeto = set(string.ascii_uppercase + string.digits)
        for _ in range(50):
            codigo = main._gerar_codigo()
            self.assertTrue(set(codigo).issubset(alfabeto))
            self.assertFalse(set(codigo).issubset(set(string.digits)),
                             "codigo nao pode ser so digitos (entropia baixa)")

    def test_codigos_sao_aleatorios(self):
        gerados = {main._gerar_codigo() for _ in range(20)}
        self.assertGreater(len(gerados), 10)


class TestHashCodigo(unittest.TestCase):
    def test_hash_usa_bcrypt_com_salt(self):
        codigo = main._gerar_codigo()
        h1 = main._hash_codigo(codigo)
        h2 = main._hash_codigo(codigo)
        self.assertTrue(h1.startswith("$2"))
        self.assertNotEqual(h1, h2, "mesmo codigo precisa gerar hash diferente (salt)")
        self.assertNotEqual(h1, hashlib.sha256(codigo.encode()).hexdigest())

    def test_verificar_codigo_aceita_valido(self):
        codigo = main._gerar_codigo()
        h = main._hash_codigo(codigo)
        self.assertTrue(main._verificar_codigo(codigo, h))

    def test_verificar_codigo_rejeita_invalido(self):
        codigo = main._gerar_codigo()
        h = main._hash_codigo(codigo)
        self.assertFalse(main._verificar_codigo(codigo + "X", h))

    def test_verificar_codigo_fallback_legado_sha256(self):
        codigo = "ABC12345"
        h_legado = hashlib.sha256(codigo.encode()).hexdigest()
        self.assertTrue(main._verificar_codigo(codigo, h_legado))
        self.assertFalse(main._verificar_codigo("ZZZ99999", h_legado))

    def test_verificar_codigo_hash_nulo(self):
        self.assertFalse(main._verificar_codigo("ABC12345", None))
        self.assertFalse(main._verificar_codigo("ABC12345", ""))


class TestVerificarRecuperacao(unittest.TestCase):
    def setUp(self):
        main._rate_limit_store.clear()

    def _registro(self, **kwargs):
        base = {
            "codigo_hash": main._hash_codigo("ABCD1234"),
            "codigo_expiracao": "2099-01-01T00:00:00+00:00",
            "recovery_token": "tok123456",
            "tentativas": 0,
            "bloqueio_ate": None,
        }
        base.update(kwargs)
        return base

    def _req(self, codigo="ABCD1234"):
        req = mock.Mock(spec=VerificarCodigoRequest)
        req.email = "fulano@exemplo.com"
        req.codigo = codigo
        return req

    def _fake_request(self):
        req = mock.Mock()
        req.client.host = "1.2.3.4"
        return req

    def test_codigo_valido_retorna_token(self):
        cursor = FakeCursor(self._registro())
        with mock.patch("services.db.executar", return_value=cursor) as ex:
            resp = main.verificar_recuperacao(self._req(), self._fake_request())
        self.assertTrue(resp.sucesso)
        self.assertEqual(resp.recovery_token, "tok123456")
        # UPDATE final limpa codigo_hash (nao pode reaproveitar)
        update_args = ex.call_args_list[-1][0]
        self.assertIn("codigo_hash = NULL", update_args[0])

    def test_codigo_invalido_incrementa_tentativas(self):
        cursor = FakeCursor(self._registro())
        with mock.patch("services.db.executar", return_value=cursor) as ex:
            resp = main.verificar_recuperacao(self._req("WRONG111"), self._fake_request())
        self.assertFalse(resp.sucesso)
        update_args = ex.call_args_list[-1][0]
        self.assertIn("tentativas = ?", update_args[0])
        self.assertEqual(update_args[1][0], 1)

    def test_bloqueia_apos_max_tentativas(self):
        cursor = FakeCursor(self._registro(tentativas=main.MAX_TENTATIVAS_RECUPERACAO - 1))
        with mock.patch("services.db.executar", return_value=cursor) as ex:
            resp = main.verificar_recuperacao(self._req("WRONG111"), self._fake_request())
        self.assertFalse(resp.sucesso)
        update_args = ex.call_args_list[-1][0]
        self.assertIn("bloqueio_ate = ?", update_args[0])

    def test_respeita_bloqueio_existente(self):
        futuro = (datetime_now_futura())
        cursor = FakeCursor(self._registro(bloqueio_ate=futuro, codigo_hash=main._hash_codigo("ABCD1234")))
        with mock.patch("services.db.executar", return_value=cursor) as ex:
            resp = main.verificar_recuperacao(self._req("ABCD1234"), self._fake_request())
        self.assertFalse(resp.sucesso)
        self.assertIn("Muitas tentativas", resp.erro)
        ex.assert_called_once()  # SELECT so (nao atualiza durante bloqueio)

    def test_sem_registro_retorna_generico(self):
        cursor = FakeCursor(None)
        with mock.patch("services.db.executar", return_value=cursor):
            resp = main.verificar_recuperacao(self._req(), self._fake_request())
        self.assertFalse(resp.sucesso)
        self.assertEqual(resp.erro, "Codigo invalido.")

    def test_select_usa_codigo_hash_nao_codigo(self):
        cursor = FakeCursor(self._registro())
        with mock.patch("services.db.executar", return_value=cursor) as ex:
            main.verificar_recuperacao(self._req(), self._fake_request())
        select_args = ex.call_args_list[0][0]
        self.assertIn("codigo_hash", select_args[0])
        self.assertNotIn("SELECT codigo,", select_args[0])
        self.assertIn("bloqueio_ate", select_args[0])


def datetime_now_futura():
    from datetime import datetime, timedelta, timezone
    return (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat()


if __name__ == "__main__":
    unittest.main()
