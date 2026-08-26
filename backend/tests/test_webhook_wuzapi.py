"""Testes do webhook de confirmação de entrega/leitura do wuzapi.

Cobrem:
1. `_enviar_whatsapp_via_wuzapi` captura o `Id` da mensagem retornado pelo
   wuzapi (para correlacionar o lembrete com os ReadReceipt).
2. `registrar_receipt` processa um webhook ReadReceipt e marca o lembrete
   como entregue/lido, usando o `mensagem_id` gravado no envio.
"""
import os
import unittest
from datetime import datetime, timezone
from unittest import mock

import services.lembrete_service as mod


class TestCapturaIdMensagem(unittest.TestCase):
    def setUp(self):
        os.environ["WUZAPI_BASE_URL"] = "http://localhost:8080"
        os.environ["WUZAPI_TOKEN"] = "token-teste"

    def tearDown(self):
        for k in ("WUZAPI_BASE_URL", "WUZAPI_TOKEN"):
            os.environ.pop(k, None)

    def test_envio_retorna_id_da_mensagem(self):
        with mock.patch("services.lembrete_service.requests.post") as post:
            post.return_value.status_code = 200
            post.return_value.json.return_value = {
                "success": True,
                "data": {"Id": "3EB06933D418053BFCEDA1", "Details": "Sent"},
            }
            sucesso, msgid = mod._enviar_whatsapp_via_wuzapi("owner1", "(75) 9229-8347", "oi")
            self.assertTrue(sucesso)
            self.assertEqual(msgid, "3EB06933D418053BFCEDA1")
            args, kwargs = post.call_args
            self.assertEqual(args[0], "http://localhost:8080/chat/send/text")
            self.assertEqual(kwargs["json"]["Phone"], "557592298347")

    def test_envio_sem_id_retorna_none(self):
        with mock.patch("services.lembrete_service.requests.post") as post:
            post.return_value.status_code = 200
            post.return_value.json.return_value = {"success": True, "data": {}}
            sucesso, msgid = mod._enviar_whatsapp_via_wuzapi("owner1", "(75) 9229-8347", "oi")
            self.assertTrue(sucesso)
            self.assertIsNone(msgid)

    def test_envio_falha_retorna_none(self):
        with mock.patch("services.lembrete_service.requests.post") as post:
            post.return_value.status_code = 500
            post.return_value.text = "no session"
            sucesso, msgid = mod._enviar_whatsapp_via_wuzapi("owner1", "(75) 9229-8347", "oi")
            self.assertFalse(sucesso)
            self.assertIsNone(msgid)

    def test_envio_sem_token_retorna_none(self):
        os.environ.pop("WUZAPI_TOKEN", None)
        sucesso, msgid = mod._enviar_whatsapp_via_wuzapi("owner1", "(75) 9229-8347", "oi")
        self.assertFalse(sucesso)
        self.assertIsNone(msgid)


class FakeCursor:
    def __init__(self, row=None, rowcount=0):
        self._row = row
        self._rowcount = rowcount

    @property
    def rowcount(self):
        return self._rowcount

    def fetchone(self):
        return self._row

    def commit(self):
        pass


class TestRegistrarReceipt(unittest.TestCase):
    def test_receipt_delivered_marca_entregue(self):
        with mock.patch("services.lembrete_service.executar") as executar:
            executar.return_value = FakeCursor(
                row={"id": "lembrete-123", "compromisso_id": "comp-1", "status": "enviado"},
                rowcount=1,
            )
            payload = {
                "type": "ReadReceipt",
                "state": "Delivered",
                "event": {"MessageIDs": ["3EB06933D418053BFCEDA1"]},
            }
            total = mod.registrar_receipt(payload)
            self.assertEqual(total, 1)
            # Primeira chamada: SELECT por mensagem_id
            select_args = executar.call_args_list[0][0]
            self.assertIn("SELECT id, compromisso_id, status", select_args[0])
            self.assertEqual(select_args[1], ("3EB06933D418053BFCEDA1",))
            # Segunda: UPDATE entregue_em
            update_args = executar.call_args_list[1][0]
            self.assertIn("entregue_em", update_args[0])

    def test_receipt_read_marca_lido(self):
        with mock.patch("services.lembrete_service.executar") as executar:
            executar.return_value = FakeCursor(
                row={"id": "lembrete-123", "compromisso_id": "comp-1", "status": "enviado"},
                rowcount=1,
            )
            payload = {
                "type": "ReadReceipt",
                "state": "Read",
                "event": {"MessageIDs": ["3EB06933D418053BFCEDA1"]},
            }
            total = mod.registrar_receipt(payload)
            self.assertEqual(total, 1)
            update_args = executar.call_args_list[1][0]
            self.assertIn("lido_em", update_args[0])

    def test_receipt_sem_id_correspondente_nao_atualiza(self):
        with mock.patch("services.lembrete_service.executar") as executar:
            executar.return_value = FakeCursor(row=None, rowcount=0)
            payload = {
                "type": "ReadReceipt",
                "state": "Delivered",
                "event": {"MessageIDs": ["nao-existe"]},
            }
            total = mod.registrar_receipt(payload)
            self.assertEqual(total, 0)
            executar.assert_called_once()

    def test_payload_nao_receipt_ignorado(self):
        with mock.patch("services.lembrete_service.executar") as executar:
            total = mod.registrar_receipt({"type": "Message", "event": {}})
            self.assertEqual(total, 0)
            executar.assert_not_called()

    def test_payload_sem_messageids_ignorado(self):
        with mock.patch("services.lembrete_service.executar") as executar:
            total = mod.registrar_receipt({"type": "ReadReceipt", "state": "Read", "event": {}})
            self.assertEqual(total, 0)
            executar.assert_not_called()

    def test_state_desconhecido_ignorado(self):
        with mock.patch("services.lembrete_service.executar") as executar:
            executar.return_value = FakeCursor(
                row={"id": "lembrete-123", "compromisso_id": "comp-1", "status": "enviado"},
                rowcount=1,
            )
            payload = {
                "type": "ReadReceipt",
                "state": "Composing",
                "event": {"MessageIDs": ["X"]},
            }
            total = mod.registrar_receipt(payload)
            self.assertEqual(total, 0)
            executar.assert_called_once()


class FakeFetchAllCursor:
    def __init__(self, rows):
        self._rows = rows
        self._commits = 0

    @property
    def commits(self):
        return self._commits

    def fetchall(self):
        return self._rows

    def commit(self):
        self._commits += 1


class TestProcessarPendentes(unittest.TestCase):
    def setUp(self):
        os.environ["WUZAPI_BASE_URL"] = "http://localhost:8080"
        os.environ["WUZAPI_TOKEN"] = "token-teste"

    def tearDown(self):
        for k in ("WUZAPI_BASE_URL", "WUZAPI_TOKEN"):
            os.environ.pop(k, None)

    def _row(self, rid="l1", telefone="(75) 9229-8347", horario="2026-08-25T18:00:00+00:00"):
        return {
            "id": rid,
            "owner_id": "owner1",
            "telefone": telefone,
            "mensagem": "teste",
            "horario_envio": horario,
            "tentativas": 0,
        }

    def test_envio_sucesso_salva_status_e_mensagem_id(self):
        cursor = FakeFetchAllCursor([self._row()])
        with mock.patch("services.lembrete_service.executar", return_value=cursor) as executar:
            with mock.patch("services.lembrete_service._enviar_whatsapp_via_wuzapi", return_value=(True, "MSG123")):
                alterados = mod._processar_pendentes(
                    datetime(2026, 8, 25, 18, 30, tzinfo=timezone.utc)
                )
        self.assertTrue(alterados)
        self.assertEqual(cursor.commits, 1)
        # 1a chamada: SELECT; 2a: UPDATE com mensagem_id
        update_args = executar.call_args_list[1][0]
        self.assertIn("status = 'enviado'", update_args[0])
        self.assertIn("mensagem_id = ?", update_args[0])
        self.assertEqual(update_args[1][1], "MSG123")

    def test_envio_falha_dentro_da_janela_mantem_pendente(self):
        cursor = FakeFetchAllCursor([self._row()])
        with mock.patch("services.lembrete_service.executar", return_value=cursor) as executar:
            with mock.patch("services.lembrete_service._enviar_whatsapp_via_wuzapi", return_value=(False, None)):
                mod._processar_pendentes(datetime(2026, 8, 25, 18, 30, tzinfo=timezone.utc))
        # UPDATE de tentativas (não marca falha)
        update_args = executar.call_args_list[1][0]
        self.assertIn("tentativas = ?", update_args[0])
        self.assertNotIn("status = 'falha'", update_args[0])

    def test_scheduler_chama_processar_pendentes_em_to_thread(self):
        import asyncio
        with mock.patch("services.lembrete_service._processar_pendentes") as proc:
            with mock.patch("services.lembrete_service._checar_e_reconectar_wuzapi", return_value=False):
                async def _uma_rodada():
                    original = asyncio.sleep
                    rodadas = {"n": 0}

                    async def fake_sleep(_s):
                        rodadas["n"] += 1
                        if rodadas["n"] > 1:
                            raise asyncio.CancelledError
                        await original(0)

                    with mock.patch("services.lembrete_service.asyncio.sleep", side_effect=fake_sleep):
                        try:
                            await mod._scheduler()
                        except asyncio.CancelledError:
                            pass
                asyncio.run(_uma_rodada())
        proc.assert_called()


class TestMascararPII(unittest.TestCase):
    def test_mascarar_telefone_mantem_ultimos_4(self):
        self.assertEqual(mod._mascarar("557592298347"), "********8347")
        self.assertNotIn("9229", mod._mascarar("557592298347"))

    def test_mascarar_valor_curto(self):
        self.assertEqual(mod._mascarar("12"), "****")


if __name__ == "__main__":
    unittest.main()
