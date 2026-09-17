"""Teste do fail-closed do fallback SQLite (item 13). Verifica que, com
`ALLOW_SQLITE_FALLBACK=false`, o backend recusa operar sem o Turso em vez de
aceitar escritas efemeras. Roda com o runner isolado."""
import os
import unittest
from unittest import mock

os.environ.setdefault("JWT_SECRET", "teste")
os.environ.setdefault("SMTP_HOST", "")
os.environ.setdefault("WUZAPI_BASE_URL", "")

from services import db  # noqa: E402


class TestFallbackFailClosed(unittest.TestCase):
    def tearDown(self):
        # Restaura o estado do modulo para nao afetar os demais testes.
        db.ALLOW_SQLITE_FALLBACK = True
        db._conexao = None
        db._usa_turso = False

    def test_fallback_desabilitado_lanca_em_vez_de_aceitar_escrita(self):
        with mock.patch.object(db, "ALLOW_SQLITE_FALLBACK", False):
            with mock.patch.object(db, "TURSO_URL", ""):
                with mock.patch.object(db, "TURSO_TOKEN", ""):
                    with mock.patch.object(db, "_conexao", None):
                        db._turso_ultima_tentativa = 0
                        with self.assertRaises(RuntimeError):
                            db._obter_conexao()

    def test_fallback_habilitado_cai_no_sqlite_local(self):
        with mock.patch.object(db, "ALLOW_SQLITE_FALLBACK", True):
            with mock.patch.object(db, "TURSO_URL", ""):
                with mock.patch.object(db, "TURSO_TOKEN", ""):
                    with mock.patch.object(db, "_conexao", None):
                        db._turso_ultima_tentativa = 0
                        with mock.patch.object(db, "_tentar_conectar_turso", return_value=None):
                            conn = db._obter_conexao()
                            self.assertIsNotNone(conn)
                            self.assertEqual(db._usa_turso, False)


if __name__ == "__main__":
    unittest.main()
