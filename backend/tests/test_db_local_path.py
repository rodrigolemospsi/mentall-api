"""SQLite persistente no volume do Fly (Fase 5C)."""
import os
import unittest
from unittest.mock import MagicMock, patch

from services import db


class SqlitePathTests(unittest.TestCase):
    def test_sqlite_path_lido_do_ambiente(self):
        with patch.dict(os.environ, {"SQLITE_PATH": "/data/mentall.db"}, clear=False):
            self.assertEqual(db._sqlite_path(), "/data/mentall.db")

    def test_sem_sqlite_path(self):
        with patch.dict(os.environ, {"SQLITE_PATH": ""}, clear=False):
            self.assertEqual(db._sqlite_path(), "")

    def test_conectar_local_usa_sqlite_path(self):
        conexao = MagicMock()
        with patch.dict(os.environ, {"SQLITE_PATH": "/data/mentall.db"}, clear=False), \
             patch.object(db.os, "makedirs"), \
             patch.object(db.sqlite3, "connect", return_value=conexao) as conectar:
            resultado = db._conectar_local()
        self.assertIs(resultado, conexao)
        conectar.assert_called_once_with("/data/mentall.db", check_same_thread=False)
        conexao.execute.assert_any_call("PRAGMA journal_mode=WAL")

    def test_conectar_local_sem_path_usa_data(self):
        conexao = MagicMock()
        with patch.dict(os.environ, {"SQLITE_PATH": ""}, clear=False), \
             patch.object(db.os, "makedirs"), \
             patch.object(db.sqlite3, "connect", return_value=conexao) as conectar:
            db._conectar_local()
        caminho = conectar.call_args[0][0]
        self.assertTrue(caminho.endswith(os.path.join("data", "mentall.db")))
