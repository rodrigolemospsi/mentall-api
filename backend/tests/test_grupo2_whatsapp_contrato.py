"""Testes do grupo 2: precedencia de instancia wuzapi por owner e concorrencia
de aceite de contrato. Roda com o runner isolado (sqlite :memory:, sem rede,
sem dotenv)."""
import os
import unittest
from unittest import mock

os.environ.setdefault("JWT_SECRET", "teste-segredo")
os.environ.setdefault("SMTP_HOST", "")
os.environ.setdefault("WUZAPI_BASE_URL", "")
os.environ.setdefault("TURSO_DATABASE_URL", "")
os.environ.setdefault("TURSO_AUTH_TOKEN", "")

from services.lembrete_service import _resolver_token_wuzapi  # noqa: E402
from services.contrato_service import criar_contrato, registrar_aceite  # noqa: E402


class _Cursor:
    def __init__(self, row):
        self._row = row
        self._rows = []

    def fetchone(self):
        return self._row

    def fetchall(self):
        return self._rows

    def commit(self):
        pass


class _FakeDb:
    """Fake de `executar` que preserva o estado do contrato com a semantica do
    UPDATE condicionado, permitindo simular a corrida de duas submissoes."""

    def __init__(self):
        self.contratos = {}
        self.wuzapi = {}

    def executar(self, sql, params=()):
        s = " ".join(sql.split())
        su = s.upper()
        if su.startswith("SELECT"):
            if "FROM WUZAPI_INSTANCIAS" in su:
                v = self.wuzapi.get(params[0])
                return _Cursor({"wuzapi_token": v} if v else None)
            if "FROM CONTRATOS" in su:
                row = self.contratos.get(params[0])
                return _Cursor(row)
            return _Cursor(None)
        if su.startswith("INSERT"):
            return _Cursor(None)
        if su.startswith("UPDATE"):
            token = params[-1]
            row = self.contratos.get(token)
            if row is not None and row["status"] == "pendente" and "STATUS = 'ACEITO'" in su:
                self.contratos[token] = {
                    **row,
                    "status": "aceito",
                    "aceito_em": "2026-09-06T00:00:00+00:00",
                    "nome_aceite": params[1],
                }
            return _Cursor(None)
        return _Cursor(None)


class TestWuzapiPorOwner(unittest.TestCase):
    def test_instancia_do_owner_tem_precedencia_sobre_env_global(self):
        db = _FakeDb()
        db.wuzapi["owner-a"] = "token-a"
        with mock.patch.dict(os.environ, {"WUZAPI_TOKEN": "token-global"}, clear=False):
            with mock.patch("services.lembrete_service.executar", side_effect=db.executar):
                self.assertEqual(_resolver_token_wuzapi("owner-a"), "token-a")

    def test_owner_sem_instancia_nao_usa_token_global(self):
        db = _FakeDb()
        with mock.patch.dict(os.environ, {"WUZAPI_TOKEN": "token-global"}, clear=False):
            with mock.patch("services.lembrete_service.executar", side_effect=db.executar):
                self.assertEqual(_resolver_token_wuzapi("owner-b"), "")

    def test_sem_owner_usa_token_global_caminho_dev(self):
        db = _FakeDb()
        with mock.patch.dict(os.environ, {"WUZAPI_TOKEN": "token-global"}, clear=False):
            with mock.patch("services.lembrete_service.executar", side_effect=db.executar):
                self.assertEqual(_resolver_token_wuzapi(""), "token-global")

    def test_owner_sem_instancia_e_sem_env_retorna_vazio(self):
        db = _FakeDb()
        with mock.patch.dict(os.environ, {"WUZAPI_TOKEN": ""}, clear=False):
            with mock.patch("services.lembrete_service.executar", side_effect=db.executar):
                self.assertEqual(_resolver_token_wuzapi("owner-b"), "")


class TestContratoConcorrencia(unittest.TestCase):
    def setUp(self):
        self.db = _FakeDb()
        self.db.contratos["tok1"] = {
            "token": "tok1",
            "dados": "{}",
            "status": "pendente",
            "owner_id": "owner-a",
            "criado_em": "2026-09-06T00:00:00+00:00",
            "aceito_em": None,
            "nome_aceite": None,
        }
        self.patch = mock.patch("services.contrato_service.executar", side_effect=self.db.executar)
        self.patch.start()
        self.addCleanup(self.patch.stop)

    def test_primeira_submissao_aceita(self):
        result = registrar_aceite("tok1", "Paciente")
        self.assertIsNotNone(result)
        self.assertEqual(result["status"], "aceito")
        self.assertEqual(result["nome_aceite"], "Paciente")
        self.assertEqual(self.db.contratos["tok1"]["nome_aceite"], "Paciente")

    def test_submissao_concorrente_nao_sobrescreve_nome(self):
        registrar_aceite("tok1", "Primeiro")
        resultado = registrar_aceite("tok1", "Segundo")
        self.assertEqual(self.db.contratos["tok1"]["nome_aceite"], "Primeiro")
        self.assertEqual(resultado["nome_aceite"], "Primeiro")

    def test_token_expirado_ou_inexistente_retorna_none(self):
        self.assertIsNone(registrar_aceite("tok-inexistente", "Paciente"))

    def test_contrato_ja_aceito_e_retornado_sem_mudar_nome(self):
        registrar_aceite("tok1", "Original")
        resultado = registrar_aceite("tok1", "Outro")
        self.assertEqual(resultado["nome_aceite"], "Original")


if __name__ == "__main__":
    unittest.main()
