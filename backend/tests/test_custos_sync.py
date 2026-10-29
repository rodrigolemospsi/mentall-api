"""Sync da Magalu Cloud: dia atual, idempotência e atualização ao abrir o painel."""

import json
import os
import unittest
from datetime import datetime, timedelta
from unittest.mock import patch
from zoneinfo import ZoneInfo

from fastapi.testclient import TestClient

import admin_ui
import main
from services import custos, db
from services.usuarios import hash_senha

FUSO = ZoneInfo("America/Sao_Paulo")
SENHA = "SenhaForte123"


def _hoje_brt():
    return datetime.now(FUSO).date()


def _limpar():
    for tabela in ("usuarios", "admin_sessoes", "admin_seguranca", "tokens_revogados"):
        db.executar(f"DELETE FROM {tabela}").commit()
    db.executar("DELETE FROM custos_uso WHERE provedor = 'magalu'").commit()
    main._rate_limit_store.clear()


class _RespostaFake:
    def __init__(self, payload):
        self._dados = json.dumps(payload).encode("utf-8")

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def read(self, *args):
        return self._dados


def _payload_hoje():
    hoje = _hoje_brt()
    ontem = hoje - timedelta(days=1)
    return {
        "results": [
            {
                "ChargePeriodStart": f"{ontem.isoformat()}T00:00:00-03:00",
                "ServiceName": "Virtual Machines",
                "BilledCost": "1.80",
                "ConsumedQuantity": "86400",
                "BillingCurrency": "BRL",
                "SkuId": "vm-1",
            },
            {
                "ChargePeriodStart": f"{hoje.isoformat()}T00:00:00-03:00",
                "ServiceName": "Virtual Machines",
                "BilledCost": "0.75",
                "ConsumedQuantity": "36000",
                "BillingCurrency": "BRL",
                "SkuId": "vm-1",
            },
        ]
    }


class SyncMagaluTests(unittest.TestCase):
    def setUp(self):
        _limpar()

    def test_inclui_hoje_e_nao_duplica(self):
        hoje = _hoje_brt()
        ontem = hoje - timedelta(days=1)
        with (
            patch.dict(os.environ, {"MAGALU_CONSUMPTION_API_KEY": "teste"}),
            patch.object(
                custos.urllib.request, "urlopen", lambda *a, **k: _RespostaFake(_payload_hoje())
            ),
        ):
            primeiro = custos.sincronizar_magalu(dias=2)
            segundo = custos.sincronizar_magalu(dias=2)
        self.assertTrue(primeiro["ok"])
        self.assertEqual(primeiro["registros"], 2)
        self.assertTrue(segundo["ok"])
        linhas = db.executar(
            "SELECT referencia, custo_brl FROM custos_uso WHERE provedor = 'magalu' "
            "AND referencia IN (?, ?) ORDER BY referencia",
            (ontem.isoformat(), hoje.isoformat()),
        ).fetchall()
        self.assertEqual(len(linhas), 2)  # idempotente: 2 dias, sem duplicar
        self.assertEqual(
            {linha["referencia"] for linha in linhas},
            {ontem.isoformat(), hoje.isoformat()},
        )
        custo_hoje = next(
            float(linha["custo_brl"])
            for linha in linhas
            if linha["referencia"] == hoje.isoformat()
        )
        self.assertAlmostEqual(custo_hoje, 0.75, places=4)

    def test_intervalo_padrao_e_env(self):
        ambiente = dict(os.environ)
        ambiente.pop("MAGALU_SYNC_MINUTOS", None)
        with patch.dict(os.environ, ambiente, clear=True):
            self.assertEqual(custos.intervalo_sync_minutos(), 5)
        with patch.dict(os.environ, {"MAGALU_SYNC_MINUTOS": "2"}):
            self.assertEqual(custos.intervalo_sync_minutos(), 2)

    def test_sincroniza_se_necessario(self):
        with (
            patch.object(custos, "magalu_configurada", return_value=True),
            patch.object(custos, "_ultima_sync_dt", return_value=None),
            patch.object(custos, "sincronizar_magalu", return_value={"ok": True}) as mock_sync,
        ):
            self.assertEqual(custos.sincronizar_se_necessario(), {"ok": True})
            mock_sync.assert_called_once_with(dias=7)
        with (
            patch.object(custos, "magalu_configurada", return_value=True),
            patch.object(
                custos,
                "_ultima_sync_dt",
                return_value=datetime.now(FUSO) - timedelta(seconds=10),
            ),
            patch.object(custos, "sincronizar_magalu") as mock_sync,
        ):
            self.assertIsNone(custos.sincronizar_se_necessario())
            mock_sync.assert_not_called()


class PainelCustosHttpTests(unittest.TestCase):
    def setUp(self):
        _limpar()
        db.executar(
            "INSERT INTO usuarios (id, email, password_hash, nome, plano, status, role, criado_em) "
            "VALUES ('admin-1', 'dono@ex.com', ?, 'Nome', 'pro', 'ativo', 'admin', ?)",
            (hash_senha(SENHA), datetime.now(FUSO).isoformat()),
        ).commit()
        self.client = TestClient(main.app, follow_redirects=False)

    def test_painel_atualiza_magalu_ao_abrir(self):
        login = self.client.post(
            "/admin/login", data={"email": "dono@ex.com", "senha": SENHA}
        )
        self.assertEqual(login.status_code, 303)
        cookie = login.headers["set-cookie"].split(";")[0]
        with patch.object(custos, "sincronizar_se_necessario", return_value=None) as mock_sync:
            resposta = self.client.get("/admin/custos", headers={"Cookie": cookie})
        self.assertEqual(resposta.status_code, 200)
        mock_sync.assert_called_once()
        self.assertIn("atualização automática a cada", resposta.text)
        self.assertIn('http-equiv="refresh"', resposta.text)



class CustoPorProfissionalTests(unittest.TestCase):
    def setUp(self):
        _limpar()
        db.executar("DELETE FROM custos_uso").commit()
        for uid, email in (("u-1", "ana@ex.com"), ("u-2", "bruno@ex.com")):
            db.executar(
                "INSERT INTO usuarios (id, email, password_hash, nome, plano, status, role, criado_em) "
                "VALUES (?, ?, ?, 'Nome', 'pro', 'ativo', 'user', ?)",
                (uid, email, hash_senha(SENHA), datetime.now(FUSO).isoformat()),
            ).commit()

    def _linha(self, uid, provedor, operacao, custo, tokens_in=0, tokens_out=0, segundos=0.0):
        hoje = _hoje_brt().isoformat()
        db.executar(
            "INSERT INTO custos_uso (id, owner_id, provedor, modelo, operacao, fonte, referencia, "
            "unidades, tokens_in, tokens_out, segundos, custo_brl, cambio_usd_brl, detalhe, criado_em) "
            "VALUES (?, ?, ?, 'modelo', ?, 'medido', ?, 0, ?, ?, ?, ?, 5.4, '{}', ?)",
            (
                f"teste-{uid}-{provedor}",
                uid,
                provedor,
                operacao,
                hoje,
                tokens_in,
                tokens_out,
                segundos,
                custo,
                datetime.now(FUSO).isoformat(),
            ),
        ).commit()

    def test_agrega_por_profissional_e_ignora_infra(self):
        self._linha("u-1", "openai", "sintese", 0.02, tokens_in=1000, tokens_out=500)
        self._linha("u-2", "groq", "transcricao", 0.01, segundos=60)
        # infra Magalu nao entra no custo por profissional
        self._linha("", "magalu", "infra", 1.50)
        linhas = custos.custo_por_profissional()
        self.assertEqual(len(linhas), 2)
        primeiro = linhas[0]
        self.assertEqual(primeiro["profissional"], "ana@ex.com")
        self.assertAlmostEqual(primeiro["custo_brl"], 0.02, places=4)
        self.assertEqual(primeiro["sinteses"], 1)
        self.assertEqual(primeiro["tokens"], 1500)
        self.assertAlmostEqual(
            primeiro["margem_brl"], custos.preco_mensal_brl() - 0.02, places=2
        )
        segundo = linhas[1]
        self.assertEqual(segundo["profissional"], "bruno@ex.com")
        self.assertEqual(segundo["transcricoes"], 1)

    def test_pagina_mostra_tabela_por_profissional(self):
        self._linha("u-1", "openai", "sintese", 0.02, tokens_in=1000, tokens_out=500)
        html = admin_ui.pagina_custos(custos.painel())
        self.assertIn("Custo de IA por profissional", html)
        self.assertIn("ana@ex.com", html)
        self.assertIn("Margem (plano − IA)", html)
