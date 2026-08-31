"""Testes do fix de IDOR em status de contrato/anamnese (pentest Strix 30/08).

Cobrem:
1. Um profissional autenticado NÃO pode ler o status/aceite de um contrato
   de outro profissional (antes: `GET /contratos/{token}/status` sem checar
   `owner_id`).
2. O mesmo vale para `GET /anamneses/{token}/status` (expõe as respostas
   clínicas completas do paciente).
3. O dono do recurso continua conseguindo ler o próprio status.
"""
import os
import unittest
from unittest import mock

os.environ.setdefault("JWT_SECRET", "teste-segredo")
os.environ.setdefault("APP_PASSWORD_HASH", "teste-hash")
os.environ.setdefault("SMTP_HOST", "")
os.environ.setdefault("WUZAPI_BASE_URL", "")

import main  # noqa: E402
from services.contrato_service import obter_contrato  # noqa: E402
from services.anamnese_service import obter_anamnese  # noqa: E402


class FakeCursor:
    def __init__(self, row=None):
        self._row = row

    def fetchone(self):
        return self._row


def _contrato_row(owner="ownerA"):
    return {
        "token": "tok-contrato-a",
        "dados": '{"nome_paciente": "Paciente X"}',
        "status": "aceito",
        "owner_id": owner,
        "criado_em": "2026-08-30T10:00:00+00:00",
        "aceito_em": "2026-08-30T11:00:00+00:00",
        "nome_aceite": "Paciente X",
    }


def _anamnese_row(owner="ownerA"):
    return {
        "token": "tok-anamnese-a",
        "template_json": "{}",
        "owner_id": owner,
        "status": "respondido",
        "respostas": '{"1":"pensamentos de auto-mutilacao frequentes"}',
        "criado_em": "2026-08-30T10:00:00+00:00",
        "respondido_em": "2026-08-30T11:00:00+00:00",
        "dados_extra": "{}",
    }


class TestStatusContratoIDOR(unittest.TestCase):
    def setUp(self):
        main._rate_limit_store.clear()

    def _fake_request(self, path):
        req = mock.Mock()
        req.client.host = "1.2.3.4"
        req.url.path = path
        return req

    def test_outro_profissional_nao_ve_status_de_contrato(self):
        with mock.patch("main.obter_contrato", return_value=_contrato_row(owner="ownerA")):
            resp = main.status_contrato(
                "tok-contrato-a",
                self._fake_request("/contratos/tok-contrato-a/status"),
                auth=("profB@exemplo.com", "ownerB"),
            )
        self.assertFalse(resp.sucesso)
        self.assertIn("não encontrado", resp.erro.lower())

    def test_dono_ve_status_do_proprio_contrato(self):
        with mock.patch("main.obter_contrato", return_value=_contrato_row(owner="ownerA")):
            resp = main.status_contrato(
                "tok-contrato-a",
                self._fake_request("/contratos/tok-contrato-a/status"),
                auth=("profA@exemplo.com", "ownerA"),
            )
        self.assertTrue(resp.sucesso)
        self.assertEqual(resp.status, "aceito")


class TestStatusAnamneseIDOR(unittest.TestCase):
    def setUp(self):
        main._rate_limit_store.clear()

    def _fake_request(self, path):
        req = mock.Mock()
        req.client.host = "1.2.3.4"
        req.url.path = path
        return req

    def test_outro_profissional_nao_le_respostas_de_anamnese(self):
        with mock.patch("main.obter_anamnese", return_value=_anamnese_row(owner="ownerA")):
            resp = main.status_anamnese(
                "tok-anamnese-a",
                self._fake_request("/anamneses/tok-anamnese-a/status"),
                auth=("profB@exemplo.com", "ownerB"),
            )
        self.assertFalse(resp.sucesso)
        self.assertIn("não encontrada", resp.erro.lower())
        self.assertEqual(resp.respostas_json, "")

    def test_dono_le_respostas_da_propria_anamnese(self):
        with mock.patch("main.obter_anamnese", return_value=_anamnese_row(owner="ownerA")):
            resp = main.status_anamnese(
                "tok-anamnese-a",
                self._fake_request("/anamneses/tok-anamnese-a/status"),
                auth=("profA@exemplo.com", "ownerA"),
            )
        self.assertTrue(resp.sucesso)
        self.assertIn("auto-mutilacao", resp.respostas_json)


if __name__ == "__main__":
    unittest.main()
