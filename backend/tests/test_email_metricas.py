"""Fase 5M: métricas de caixas de e-mail (IMAP read-only) no painel."""
import os
import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

import httpx

import main
from admin_ui import pagina_email
from services import db, email_metricas
from services.usuarios import hash_senha

SENHA = "SenhaForte123"
TABELAS = ("usuarios", "admin_auditoria", "admin_sessoes", "tokens_revogados")


def _iso(dias=0, minutos=0):
    return (datetime.now(timezone.utc) - timedelta(days=dias, minutes=minutos)).isoformat()


def _fake_metricas():
    return {
        "configurado": True,
        "gerado_em": _iso(),
        "totais": {
            "recebidas_30d": 12,
            "nao_lidas": 3,
            "sem_resposta_24h": 1,
            "tempo_medio_resposta_min": 42.0,
            "caixas": 2,
        },
        "caixas": [
            {
                "email": "contato@mentallpro.com.br",
                "rotulo": "Contato",
                "recebidas_7d": 4, "recebidas_30d": 8, "nao_lidas": 2,
                "enviadas_30d": 5, "tempo_medio_resposta_min": 30.0,
                "sem_resposta_24h": 1, "ultima_entrada": _iso(dias=1),
                "por_endereco": {}, "erro": "",
            },
            {
                "email": "suporte@mentallpro.com.br",
                "rotulo": "Suporte",
                "recebidas_7d": 2, "recebidas_30d": 4, "nao_lidas": 1,
                "enviadas_30d": 2, "tempo_medio_resposta_min": 60.0,
                "sem_resposta_24h": 0, "ultima_entrada": _iso(dias=2),
                "por_endereco": {}, "erro": "",
            },
        ],
        "por_endereco": [
            {"endereco": "contato@", "recebidas_7d": 4, "recebidas_30d": 8},
            {"endereco": "suporte@", "recebidas_7d": 2, "recebidas_30d": 4},
        ],
    }


class ParsingTests(unittest.TestCase):
    def test_normaliza_message_id(self):
        self.assertEqual(email_metricas._normalizar_message_id("<a@b>"), "<a@b>")
        self.assertEqual(email_metricas._normalizar_message_id(" a@b "), "<a@b>")
        self.assertEqual(email_metricas._normalizar_message_id(None), "")

    def test_parse_data_com_e_sem_timezone(self):
        self.assertIsNotNone(email_metricas._parse_data("Fri, 23 Oct 2026 12:30:00 +0000"))
        self.assertIsNotNone(email_metricas._parse_data("Fri, 23 Oct 2026 12:30:00 -0300"))
        self.assertIsNone(email_metricas._parse_data("data inválida"))

    def test_referencias_de_resposta(self):
        class Falsa:
            def get(self, campo):
                return {"In-Reply-To": "<a@b>", "References": "<a@b> <c@d>"}.get(campo)

        self.assertEqual(email_metricas._referencias(Falsa()), {"<a@b>", "<c@d>"})

    def test_contagem_por_endereco(self):
        agora = datetime.now(timezone.utc)
        headers = [
            {"data": agora - timedelta(days=1), "para": "to: contato@mentallpro.com.br"},
            {"data": agora - timedelta(days=2), "para": "to: suporte@mentallpro.com.br"},
            {"data": agora - timedelta(days=20), "para": "to: contato@mentallpro.com.br"},
        ]
        with patch.object(email_metricas, "ENDERECOS", ("contato@", "suporte@")):
            contagem = email_metricas._metricas_por_endereco(agora - timedelta(days=7), headers)
        self.assertEqual(contagem["contato@"]["recebidas_7d"], 1)
        self.assertEqual(contagem["contato@"]["recebidas_30d"], 2)
        self.assertEqual(contagem["suporte@"]["recebidas_7d"], 1)


class ColetaTests(unittest.TestCase):
    def setUp(self):
        email_metricas.limpar_cache()

    def test_sem_configuracao_retorna_nao_configurado(self):
        with patch.dict(os.environ, {"MAIL_METRICAS_CAIXAS": ""}, clear=False):
            self.assertFalse(email_metricas.configurado())
            dados = email_metricas.coletar(force=True)
        self.assertFalse(dados["configurado"])

    def test_agrega_totais_e_cache(self):
        configuracao = (
            '[{"email": "contato@mentallpro.com.br", "senha": "x"},'
            ' {"email": "suporte@mentallpro.com.br", "senha": "y"}]'
        )

        def fake_coletar(caixa, agora):
            return {
                "email": caixa["email"], "rotulo": caixa["rotulo"],
                "total": 10, "nao_lidas": 2, "recebidas_hoje": 1,
                "recebidas_7d": 3, "recebidas_30d": 6, "enviadas_30d": 4,
                "respondidas_30d": 2, "tempo_medio_resposta_min": 30.0,
                "sem_resposta_24h": 1, "ultima_entrada": _iso(dias=1),
                "por_endereco": {
                    "contato@": {"recebidas_7d": 2, "recebidas_30d": 3},
                    "suporte@": {"recebidas_7d": 1, "recebidas_30d": 2},
                    "financeiro@": {"recebidas_7d": 0, "recebidas_30d": 1},
                },
                "erro": "",
            }

        with patch.dict(os.environ, {"MAIL_METRICAS_CAIXAS": configuracao}, clear=False), \
                patch.object(email_metricas, "_coletar_caixa", side_effect=fake_coletar) as mock:
            dados = email_metricas.coletar(force=True)
            self.assertEqual(mock.call_count, 2)
            self.assertEqual(dados["totais"]["recebidas_30d"], 12)
            self.assertEqual(dados["totais"]["nao_lidas"], 4)
            self.assertEqual(dados["totais"]["sem_resposta_24h"], 2)
            self.assertAlmostEqual(dados["totais"]["tempo_medio_resposta_min"], 30.0)
            por_endereco = {i["endereco"]: i for i in dados["por_endereco"]}
            self.assertEqual(por_endereco["contato@"]["recebidas_30d"], 6)

            # segunda chamada usa cache (não reabre IMAP)
            email_metricas.coletar(force=False)
            self.assertEqual(mock.call_count, 2)


class PaginaTests(unittest.TestCase):
    def test_pagina_mostra_secao_de_metricas(self):
        html = pagina_email(
            [{"email": "contato@x.com", "nome": "Contato", "cota_gb": 3,
              "ativo": True, "admin": False}],
            [],
            dominio="x.com",
            metricas=_fake_metricas(),
        )
        for marcador in ("Métricas das caixas de e-mail", "Tempo médio de resposta",
                         "Sem resposta há +24h", "Atualizar agora", "Recebidas 7d / 30d"):
            self.assertIn(marcador, html, marcador)

    def test_pagina_mostra_aviso_quando_nao_configurado(self):
        html = pagina_email([], [], dominio="x.com", metricas={"configurado": False})
        self.assertIn("Monitoramento ainda não configurado", html)


class RotaTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        for tabela in TABELAS:
            db.executar(f"DELETE FROM {tabela}").commit()
        db.executar(
            "INSERT INTO usuarios (id, email, password_hash, nome, plano, status, role, criado_em) "
            "VALUES ('adm', 'dono@ex.com', ?, 'Nome', 'gratis', 'ativo', 'admin', ?)",
            (hash_senha(SENHA), _iso(10)),
        ).commit()
        main._rate_limit_store.clear()
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=main.app, client=("203.0.113.97", 55000)),
            base_url="https://test.invalid",
            follow_redirects=False,
        )
        self.addAsyncCleanup(self.client.aclose)

    async def test_admin_email_exibe_metricas(self):
        login = await self.client.post(
            "/admin/login", data={"email": "dono@ex.com", "senha": SENHA}
        )
        cookie = login.headers["set-cookie"].split(";")[0]
        with patch.object(main.email_metricas, "coletar", return_value=_fake_metricas()):
            resposta = await self.client.get(
                "/admin/email", headers={"Cookie": cookie}
            )
        self.assertEqual(resposta.status_code, 200)
        self.assertIn("Métricas das caixas de e-mail", resposta.text)
        self.assertIn("Tempo médio de resposta", resposta.text)


if __name__ == "__main__":
    unittest.main()
