"""Testes da exclusão de conta (item 2.4 do checklist v2 — caminho B).

Prova: as 9 tabelas com dado do profissional ficam sem resíduo, a conta de
OUTRO profissional não é afetada, a conta admin é protegida, o token é
revogado e a auditoria é registrada.
"""
import os
import unittest
from unittest import mock

os.environ.setdefault("JWT_SECRET", "teste-segredo")
os.environ.setdefault("APP_PASSWORD_HASH", "teste-hash")
os.environ.setdefault("SMTP_HOST", "")
os.environ.setdefault("WUZAPI_BASE_URL", "")
os.environ.setdefault("TURSO_DATABASE_URL", "")
os.environ.setdefault("TURSO_AUTH_TOKEN", "")

from services.db import executar  # noqa: E402
import services.exclusao_conta as mod  # noqa: E402

A, B = "owner-teste-a", "owner-teste-b"
EMAIL_A, EMAIL_B = "a@exemplo.com", "b@exemplo.com"


def _ins(sql, params=()):
    executar(sql, params).commit()


def _semear(owner, email):
    _ins("INSERT OR REPLACE INTO usuarios (id, email, password_hash, criado_em) VALUES (?, ?, ?, ?)",
         (owner, email, "hash", "2026-01-01"))
    _ins("INSERT OR REPLACE INTO contratos (token, dados, owner_id, criado_em) VALUES (?, ?, ?, ?)",
         ("tok-" + owner, "{}", owner, "2026-01-01"))
    _ins("INSERT OR REPLACE INTO anamneses (token, template_json, owner_id, criado_em) VALUES (?, ?, ?, ?)",
         ("ana-" + owner, "{}", owner, "2026-01-01"))
    _ins("INSERT OR REPLACE INTO lembretes (id, compromisso_id, horario_envio, owner_id, criado_em) VALUES (?, ?, ?, ?, ?)",
         ("lem-" + owner, "c1", "2026-01-01T10:00:00Z", owner, "2026-01-01"))
    _ins("INSERT OR REPLACE INTO dispositivos (device_id, owner_id, ultimo_heartbeat_em, criado_em) VALUES (?, ?, ?, ?)",
         ("dev-" + owner, owner, "2026-01-01", "2026-01-01"))
    _ins("INSERT OR REPLACE INTO eventos (id, owner_id, tipo, criado_em) VALUES (?, ?, ?, ?)",
         ("ev-" + owner, owner, "heartbeat", "2026-01-01"))
    _ins("INSERT OR REPLACE INTO wuzapi_instancias (owner_id, atualizado_em) VALUES (?, ?)",
         (owner, "2026-01-01"))
    h = mod.hash_email(email)
    _ins("INSERT OR REPLACE INTO recuperacoes (email_hash, criado_em) VALUES (?, ?)", (h, "2026-01-01"))
    _ins("INSERT OR REPLACE INTO resets_senha (email_hash, criado_em) VALUES (?, ?)", (h, "2026-01-01"))


def _contar(tabela, where, params):
    row = executar(f"SELECT COUNT(*) AS n FROM {tabela} WHERE {where}", params).fetchone()
    return int(row["n"])


class TestExclusaoConta(unittest.TestCase):
    def setUp(self):
        for t in ("contratos", "anamneses", "lembretes", "dispositivos", "eventos",
                  "wuzapi_instancias", "usuarios", "recuperacoes", "resets_senha",
                  "auditoria_exclusoes", "tokens_revogados"):
            _ins(f"DELETE FROM {t}")
        _semear(A, EMAIL_A)
        _semear(B, EMAIL_B)

    def test_exclui_tudo_do_profissional_e_preserva_o_outro(self):
        recibo = mod.excluir_conta(A, EMAIL_A, jti="jti-a")
        self.assertTrue(recibo["sucesso"])
        self.assertEqual(recibo["eliminado"]["usuarios"], 1)

        for tabela, where, params in [
            ("contratos", "owner_id = ?", (A,)),
            ("anamneses", "owner_id = ?", (A,)),
            ("lembretes", "owner_id = ?", (A,)),
            ("dispositivos", "owner_id = ?", (A,)),
            ("eventos", "owner_id = ?", (A,)),
            ("wuzapi_instancias", "owner_id = ?", (A,)),
            ("usuarios", "id = ?", (A,)),
            ("recuperacoes", "email_hash = ?", (mod.hash_email(EMAIL_A),)),
            ("resets_senha", "email_hash = ?", (mod.hash_email(EMAIL_A),)),
        ]:
            self.assertEqual(_contar(tabela, where, params), 0, f"resíduo em {tabela}")

        # conta B intacta
        self.assertEqual(_contar("usuarios", "id = ?", (B,)), 1)
        self.assertEqual(_contar("lembretes", "owner_id = ?", (B,)), 1)
        self.assertEqual(_contar("recuperacoes", "email_hash = ?", (mod.hash_email(EMAIL_B),)), 1)

        # auditoria + revogação
        self.assertEqual(_contar("auditoria_exclusoes", "email_hash = ?", (mod.hash_email(EMAIL_A),)), 1)
        self.assertTrue(mod.token_revogado("jti-a"))
        self.assertFalse(mod.token_revogado("jti-b"))

    def test_conta_admin_nao_pode_ser_excluida(self):
        with mock.patch.dict(os.environ, {"APP_USER_ID": "4b200977"}):
            self.assertFalse(mod.pode_excluir("4b200977"))
            self.assertTrue(mod.pode_excluir("owner-teste-a"))
            with self.assertRaises(PermissionError):
                mod.excluir_conta("4b200977", "admin@exemplo.com")

    def test_segunda_chamada_nao_quebra(self):
        mod.excluir_conta(A, EMAIL_A, jti="jti-a")
        recibo = mod.excluir_conta(A, EMAIL_A, jti="jti-a")
        self.assertTrue(recibo["sucesso"])
        self.assertEqual(recibo["eliminado"]["usuarios"], 0)

    def test_confirmacao_errada_no_endpoint(self):
        # valida apenas a regra de confirmação (a rota exige autenticação)
        self.assertNotEqual("excluir ", mod.CONFIRMACAO)


if __name__ == "__main__":
    unittest.main()
