"""Testes do link de confirmacao de email (fix 03/09/2026).

Problema reproduzido em producao: o link de confirmacao usa token de uso
unico consumido em um GET nao-idempotente. O primeiro hit ativa a conta
(200) mas o segundo hit (duplo toque / scanner de email / reabrir o link)
encontra o token ja consumido e exibe "Link invalido ou expirado" (400),
mesmo com a conta ativa.

Fix: `confirmar_email` torna-se idempotente - nao zera mais o hash ao
confirmar, mantendo o token valido ate a expiracao; re-confirmacao de uma
conta ja ativa retorna sucesso em vez de invalido.
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

from services.usuarios import _hash_token, confirmar_email  # noqa: E402


class _Cursor:
    def __init__(self, row):
        self._row = row

    def fetchone(self):
        return self._row

    def fetchall(self):
        return [self._row] if self._row is not None else []

    def commit(self):
        pass


class _FakeDb:
    """Banco em memoria que simula fielmente a tabela `usuarios` para as
    queries usadas por `confirmar_email`/`obter_por_id`.

    Importante: e o CODIGO (via SQL) que decide o que gravar. Este fake
    apenas executa a escrita que a SQL pede - se a SQL nulificar o hash
    (comportamento antigo), o hash sai da lookup; se nao (fix), permanece.
    """

    def __init__(self):
        self.usuarios = {}

    def executar(self, sql, params=()):
        s = " ".join(sql.split())
        su = s.upper()
        if su.startswith("SELECT"):
            if "WHERE ID = ?" in su:
                row = self.usuarios.get(params[0])
            elif "EMAIL_VERIFICACAO_TOKEN_HASH = ?" in su:
                th = params[0]
                row = next(
                    (u for u in self.usuarios.values()
                     if u["email_verificacao_token_hash"] == th),
                    None,
                )
            else:
                row = None
            return _Cursor(row)

        if su.startswith("UPDATE"):
            uid = params[0]
            user = self.usuarios.get(uid)
            if user is not None:
                if "STATUS = 'ATIVO'" in su or "STATUS = ?" in su:
                    user["status"] = "ativo"
                if "EMAIL_VERIFICACAO_TOKEN_HASH = NULL" in su:
                    user["email_verificacao_token_hash"] = None
                if "EMAIL_VERIFICACAO_EXPIRACAO = NULL" in su:
                    user["email_verificacao_expiracao"] = None
            return _Cursor(None)

        return _Cursor(None)


def _usuario_pendente(token):
    return {
        "id": "u-1",
        "email": "fulano@exemplo.com",
        "password_hash": "x",
        "nome": "Fulano",
        "plano": "gratis",
        "status": "pendente",
        "criado_em": "2026-01-01T00:00:00+00:00",
        "ultimo_acesso_em": None,
        "email_verificacao_token_hash": _hash_token(token),
        "email_verificacao_expiracao": "2099-01-01T00:00:00+00:00",
    }


class TestConfirmarEmailIdempotente(unittest.TestCase):
    def setUp(self):
        self.db = _FakeDb()
        patcher = mock.patch("services.usuarios.executar", side_effect=self.db.executar)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_token_valido_ativa_conta(self):
        token = "tok-abc-123"
        self.db.usuarios["u-1"] = _usuario_pendente(token)
        user = confirmar_email(token)
        self.assertIsNotNone(user)
        self.assertEqual(user["status"], "ativo")

    def test_reclique_nao_retorna_invalido(self):
        token = "tok-abc-123"
        self.db.usuarios["u-1"] = _usuario_pendente(token)
        primeira = confirmar_email(token)
        segunda = confirmar_email(token)
        self.assertIsNotNone(primeira)
        self.assertIsNotNone(segunda, "re-clique deve retornar sucesso, nao 'invalido'")
        self.assertEqual(primeira["id"], segunda["id"])

    def test_status_permanece_ativo_ao_reconfirmar(self):
        token = "tok-abc-123"
        self.db.usuarios["u-1"] = _usuario_pendente(token)
        confirmar_email(token)
        confirmar_email(token)
        self.assertEqual(self.db.usuarios["u-1"]["status"], "ativo")

    def test_token_expirado_retorna_none(self):
        token = "tok-abc-123"
        self.db.usuarios["u-1"] = _usuario_pendente(token)
        self.db.usuarios["u-1"]["email_verificacao_expiracao"] = "2000-01-01T00:00:00+00:00"
        self.assertIsNone(confirmar_email(token))

    def test_token_desconhecido_retorna_none(self):
        self.assertIsNone(confirmar_email("tok-inexistente"))


if __name__ == "__main__":
    unittest.main()
