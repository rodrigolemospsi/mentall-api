"""Saúde: WhatsApp (Wuzapi) com status ao vivo + sincronização do banco (Fase 5F)."""
import os
import unittest
from datetime import datetime, timezone
from unittest.mock import patch

from services import db, saude, wuzapi_admin

ENV_WUZAPI = {"WUZAPI_BASE_URL": "https://wuzapi.exemplo", "WUZAPI_ADMIN_TOKEN": "x"}


def _iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _limpar() -> None:
    db.executar("DELETE FROM wuzapi_instancias").commit()


def _instancia(owner_id: str, conectado: int) -> None:
    db.executar(
        "INSERT INTO wuzapi_instancias (owner_id, conectado, atualizado_em) VALUES (?, ?, ?)",
        (owner_id, conectado, _iso()),
    ).commit()


def _conectado_db(owner_id: str) -> int:
    return db.executar(
        "SELECT conectado FROM wuzapi_instancias WHERE owner_id = ?", (owner_id,)
    ).fetchone()["conectado"]


class SaudeWuzapiLiveTests(unittest.TestCase):
    def setUp(self):
        _limpar()

    def test_conectado_ao_vivo_mostra_ok(self):
        _instancia("o1", 0)  # banco defasado
        with patch.dict(os.environ, ENV_WUZAPI, clear=False), patch.object(
            wuzapi_admin, "sincronizar_status", return_value={"conectado": True}
        ):
            estado, detalhe = saude._wuzapi()
        self.assertEqual(estado, "ok")
        self.assertIn("1 de 1", detalhe)

    def test_desconectado_ao_vivo_gera_atencao(self):
        _instancia("o1", 1)  # banco defasado ao contrário
        with patch.dict(os.environ, ENV_WUZAPI, clear=False), patch.object(
            wuzapi_admin, "sincronizar_status", return_value={"conectado": False}
        ):
            estado, detalhe = saude._wuzapi()
        self.assertEqual(estado, "atencao")
        self.assertIn("0 de 1", detalhe)

    def test_falha_ao_vivo_cai_para_banco(self):
        _instancia("o1", 0)
        with patch.dict(os.environ, ENV_WUZAPI, clear=False), patch.object(
            wuzapi_admin, "sincronizar_status", side_effect=RuntimeError("boom")
        ):
            estado, detalhe = saude._wuzapi()
        self.assertEqual(estado, "atencao")
        self.assertIn("consulta ao vivo falhou", detalhe)

    def test_sem_configuracao_continua_info(self):
        with patch.dict(os.environ, {}, clear=True):
            estado, _ = saude._wuzapi()
        self.assertEqual(estado, "info")


class SincronizarStatusTests(unittest.TestCase):
    def setUp(self):
        _limpar()

    def test_grava_conectado_no_banco(self):
        _instancia("o1", 0)
        with patch.object(
            wuzapi_admin, "_consultar_status", return_value=({"conectado": True}, False)
        ):
            estado = wuzapi_admin.sincronizar_status("o1")
        self.assertTrue(estado["conectado"])
        self.assertEqual(_conectado_db("o1"), 1)

    def test_grava_desconectado_no_banco(self):
        _instancia("o1", 1)
        with patch.object(
            wuzapi_admin, "_consultar_status", return_value=({"conectado": False}, False)
        ):
            wuzapi_admin.sincronizar_status("o1")
        self.assertEqual(_conectado_db("o1"), 0)

    def test_falha_de_rede_nao_derruba_flag(self):
        _instancia("o1", 1)
        with patch.object(
            wuzapi_admin, "_consultar_status", return_value=({"conectado": False}, True)
        ):
            wuzapi_admin.sincronizar_status("o1")
        self.assertEqual(_conectado_db("o1"), 1)


if __name__ == "__main__":
    unittest.main()
