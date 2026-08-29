"""Testes do fix de IDOR em /lembretes (pentest Strix 28/08).

Cobrem:
1. Dois profissionais com o mesmo `compromisso_id` não podem sobrescrever
   o lembrete um do outro (antes: INSERT OR REPLACE com id=compromisso_id).
2. `cancelar_lembrete` só remove lembretes do próprio owner.
3. Reagendamento do mesmo owner+compromisso atualiza em vez de duplicar.
"""
import asyncio
import sqlite3
import unittest
from unittest import mock

import services.lembrete_service as mod


class MemExecutar:
    """Substituto em memoria de services.db.executar usando SQLite real."""

    def __init__(self):
        self.conn = sqlite3.connect(":memory:")
        self.conn.row_factory = sqlite3.Row
        self.conn.executescript(
            """
            CREATE TABLE lembretes (
                id TEXT PRIMARY KEY,
                compromisso_id TEXT NOT NULL,
                telefone TEXT NOT NULL DEFAULT '',
                mensagem TEXT NOT NULL DEFAULT '',
                horario_envio TEXT NOT NULL,
                canal TEXT NOT NULL DEFAULT 'whatsapp',
                status TEXT NOT NULL DEFAULT 'pendente',
                owner_id TEXT NOT NULL DEFAULT '',
                criado_em TEXT NOT NULL,
                enviado_em TEXT,
                tentativas INTEGER NOT NULL DEFAULT 0,
                ultima_tentativa_em TEXT,
                mensagem_id TEXT,
                entregue_em TEXT,
                lido_em TEXT
            );
            """
        )

    def executar(self, sql, params=()):
        cur = self.conn.execute(sql, params)
        return _Cur(cur, self.conn)


class _Cur:
    def __init__(self, cur, conn):
        self._cur = cur
        self._conn = conn

    @property
    def rowcount(self):
        return self._cur.rowcount

    def fetchone(self):
        row = self._cur.fetchone()
        return dict(row) if row is not None else None

    def fetchall(self):
        return [dict(r) for r in self._cur.fetchall()]

    def commit(self):
        self._conn.commit()


class TestIDORLembretes(unittest.TestCase):
    def setUp(self):
        self.db = MemExecutar()
        self._patcher = mock.patch(
            "services.lembrete_service.executar", side_effect=self.db.executar
        )
        self._patcher.start()
        self.addCleanup(self._patcher.stop)

    def _agendar(self, compromisso_id, owner_id, telefone="(75) 9229-8347"):
        return asyncio.run(
            mod.agendar_lembrete(
                compromisso_id=compromisso_id,
                telefone=telefone,
                mensagem="teste",
                horario_envio="2026-08-25T18:00:00+00:00",
                canal="whatsapp",
                owner_id=owner_id,
            )
        )

    def test_mesmo_compromisso_id_entre_owners_nao_sobrescreve(self):
        rid_a = self._agendar("cmp1", "ownerA")
        rid_b = self._agendar("cmp1", "ownerB")

        rows = mod.listar_lembretes()
        self.assertEqual(len(rows), 2)
        self.assertNotEqual(rid_a, rid_b)
        self.assertNotEqual(rid_a, "cmp1")
        owners = {r["owner_id"] for r in rows}
        self.assertEqual(owners, {"ownerA", "ownerB"})

    def test_cancelar_so_remove_do_proprio_owner(self):
        self._agendar("cmp1", "ownerA")
        self._agendar("cmp1", "ownerB")

        deletado = asyncio.run(mod.cancelar_lembrete("cmp1", "ownerB"))
        self.assertTrue(deletado)

        rows = mod.listar_lembretes()
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["owner_id"], "ownerA")

    def test_cancelar_de_outro_owner_nao_encontra(self):
        self._agendar("cmp1", "ownerA")
        deletado = asyncio.run(mod.cancelar_lembrete("cmp1", "ownerB"))
        self.assertFalse(deletado)
        self.assertEqual(len(mod.listar_lembretes()), 1)

    def test_reagendamento_mesmo_owner_atualiza_sem_duplicar(self):
        rid_1 = self._agendar("cmp1", "ownerA", telefone="(75) 9229-8347")
        rid_2 = self._agendar("cmp1", "ownerA", telefone="(75) 9000-0000")

        self.assertEqual(rid_1, rid_2)
        rows = mod.listar_lembretes()
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["telefone"], "(75) 9000-0000")


if __name__ == "__main__":
    unittest.main()
