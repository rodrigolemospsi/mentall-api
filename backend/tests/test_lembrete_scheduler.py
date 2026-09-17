"""Testes do scheduler de lembretes: nao enviar lembrete cancelado e limitar
o lote por ciclo. Roda com o runner isolado."""
import os
import unittest
from datetime import datetime, timezone
from unittest import mock

os.environ.setdefault("JWT_SECRET", "teste-segredo")
os.environ.setdefault("SMTP_HOST", "")
os.environ.setdefault("WUZAPI_BASE_URL", "")

import services.lembrete_service as mod  # noqa: E402


class _Cursor:
    def __init__(self, rows, status="pendente"):
        self._rows = rows
        self._status = status

    def fetchall(self):
        return self._rows

    def fetchone(self):
        return {"status": self._status}

    def commit(self):
        pass


def _row(rid="l1"):
    return {
        "id": rid,
        "owner_id": "owner1",
        "telefone": "(75) 9229-8347",
        "mensagem": "teste",
        "horario_envio": "2026-08-25T18:00:00+00:00",
        "tentativas": 0,
    }


class TestSchedulerCancelamento(unittest.TestCase):
    def test_nao_envia_lembrete_cancelado(self):
        cursor = _Cursor([_row()], status="cancelado")
        # A seleção retorna pendentes, mas o status real (re-verificado) é
        # cancelado -> não chama o envio.
        with mock.patch("services.lembrete_service.executar", return_value=cursor):
            with mock.patch("services.lembrete_service._enviar_whatsapp_via_wuzapi") as enviar:
                alterados = mod._processar_pendentes(
                    datetime(2026, 8, 25, 18, 30, tzinfo=timezone.utc)
                )
        self.assertFalse(alterados)
        enviar.assert_not_called()

    def test_envia_quando_ainda_pendente(self):
        cursor = _Cursor([_row()], status="pendente")
        with mock.patch("services.lembrete_service.executar", return_value=cursor) as executar:
            with mock.patch("services.lembrete_service._enviar_whatsapp_via_wuzapi", return_value=(True, "M1")):
                alterados = mod._processar_pendentes(
                    datetime(2026, 8, 25, 18, 30, tzinfo=timezone.utc)
                )
        self.assertTrue(alterados)
        update = executar.call_args_list[2][0]
        self.assertIn("status = 'enviado'", update[0])
        self.assertIn("AND status = 'pendente'", update[0])

    def test_consulta_usa_limit_do_lote(self):
        cursor = _Cursor([_row()])
        with mock.patch("services.lembrete_service.executar", return_value=cursor) as executar:
            with mock.patch("services.lembrete_service._enviar_whatsapp_via_wuzapi", return_value=(True, "M1")):
                mod._processar_pendentes(datetime(2026, 8, 25, 18, 30, tzinfo=timezone.utc))
        select = executar.call_args_list[0][0]
        self.assertIn("LIMIT ?", select[0])


class TestIndexPendentes(unittest.TestCase):
    def test_indice_de_pendentes_e_definido(self):
        from services import db
        any_idx = any("lembretes(status, horario_envio)" in i for i in db._indices)
        self.assertTrue(any_idx, "indice de lembretes por status/horario nao definido")


if __name__ == "__main__":
    unittest.main()
