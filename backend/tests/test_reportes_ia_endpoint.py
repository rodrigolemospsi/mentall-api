"""Testes HTTP do endpoint /reportar-sintese (item 3.4 do checklist).

Prova o ponto de imposição: sem token não grava; motivo inválido/campo extra
são recusados pelo schema (422); com token, grava e devolve o protocolo.
"""
import os
import unittest

os.environ.setdefault("JWT_SECRET", "teste-segredo")
os.environ.setdefault("APP_PASSWORD_HASH", "teste-hash")
os.environ.setdefault("SMTP_HOST", "")
os.environ.setdefault("WUZAPI_BASE_URL", "")
os.environ.setdefault("TURSO_DATABASE_URL", "")
os.environ.setdefault("TURSO_AUTH_TOKEN", "")

from fastapi.testclient import TestClient  # noqa: E402

import main  # noqa: E402
from services.db import executar  # noqa: E402

OWNER = "owner-http-reporte"


class TestEndpointReportarSintese(unittest.TestCase):
    def setUp(self):
        executar("DELETE FROM reportes_ia").commit()
        main._rate_limit_store.clear()
        self.client = TestClient(main.app)

    def tearDown(self):
        main.app.dependency_overrides.clear()

    def _autenticar(self):
        main.app.dependency_overrides[main._verificar_token] = (
            lambda: ("profissional", OWNER)
        )

    def test_sem_autenticacao_nao_grava(self):
        resposta = self.client.post(
            "/reportar-sintese",
            json={"sessao_id": "sessao-1", "motivo": "outro"},
        )
        self.assertIn(resposta.status_code, (401, 403))
        linha = executar("SELECT COUNT(*) AS n FROM reportes_ia").fetchone()
        self.assertEqual(int(linha["n"]), 0)

    def test_registra_com_token_e_devolve_protocolo(self):
        self._autenticar()
        resposta = self.client.post(
            "/reportar-sintese",
            json={
                "sessao_id": "sessao-1",
                "motivo": "conteudo_incorreto",
                "detalhe": "Trecho inventado na sintese",
                "provedor": "openai",
            },
        )
        self.assertEqual(resposta.status_code, 200)
        corpo = resposta.json()
        self.assertTrue(corpo["sucesso"])
        self.assertEqual(len(corpo["protocolo"]), 32)
        linha = executar(
            "SELECT * FROM reportes_ia WHERE id = ?", (corpo["protocolo"],)
        ).fetchone()
        self.assertEqual(linha["owner_id"], OWNER)
        self.assertEqual(linha["motivo"], "conteudo_incorreto")
        self.assertEqual(linha["provedor"], "openai")

    def test_motivo_invalido_retorna_422_sem_gravar(self):
        self._autenticar()
        resposta = self.client.post(
            "/reportar-sintese",
            json={"sessao_id": "sessao-1", "motivo": "nao_existe"},
        )
        self.assertEqual(resposta.status_code, 422)
        linha = executar("SELECT COUNT(*) AS n FROM reportes_ia").fetchone()
        self.assertEqual(int(linha["n"]), 0)

    def test_campo_clinico_extra_e_recusado(self):
        self._autenticar()
        resposta = self.client.post(
            "/reportar-sintese",
            json={
                "sessao_id": "sessao-1",
                "motivo": "outro",
                "relato_clinico": "conteudo que nao deve ser aceito",
            },
        )
        self.assertEqual(resposta.status_code, 422)


if __name__ == "__main__":
    unittest.main()
