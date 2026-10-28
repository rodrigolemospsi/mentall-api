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
            "violacoes_sla": 1,
            "pendentes_sla": 1,
            "tempo_medio_resposta_min": 42.0,
            "caixas": 2,
        },
        "caixas": [
            {
                "email": "contato@mentallpro.com.br",
                "rotulo": "Contato",
                "recebidas_7d": 4, "recebidas_30d": 8, "nao_lidas": 2,
                "enviadas_30d": 5, "tempo_medio_resposta_min": 30.0,
                "sem_resposta_24h": 1, "violacoes_sla": 1, "pendentes_sla": 1,
                "ultima_entrada": _iso(dias=1),
                "por_endereco": {}, "erro": "",
            },
            {
                "email": "suporte@mentallpro.com.br",
                "rotulo": "Suporte",
                "recebidas_7d": 2, "recebidas_30d": 4, "nao_lidas": 1,
                "enviadas_30d": 2, "tempo_medio_resposta_min": 60.0,
                "sem_resposta_24h": 0, "violacoes_sla": 0, "pendentes_sla": 0,
                "ultima_entrada": _iso(dias=2),
                "por_endereco": {}, "erro": "",
            },
        ],
        "por_endereco": [
            {"endereco": "contato@", "recebidas_7d": 4, "recebidas_30d": 8,
             "respondidas_30d": 3, "tempo_medio_resposta_min": 20.0,
             "sla_horas": None, "pendentes_sla": 0, "violacoes_sla": 0},
            {"endereco": "suporte@", "recebidas_7d": 2, "recebidas_30d": 4,
             "respondidas_30d": 2, "tempo_medio_resposta_min": 60.0,
             "sla_horas": 4.0, "pendentes_sla": 1, "violacoes_sla": 1},
        ],
        "serie_dias": [("18/10", 1), ("24/10", 2)],
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
            contagem = email_metricas._metricas_por_endereco(
                agora - timedelta(days=7), headers, {}, agora,
                {"contato@": 4.0, "suporte@": 4.0})
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
                         "Sem resposta há +24h", "Atualizar agora", "Recebidas 7d / 30d",
                         "Entradas por dia", "Fora do SLA",
                         "Testar alerta no WhatsApp", "SLA 4h"):
            self.assertIn(marcador, html, marcador)

    def test_pagina_mostra_aviso_quando_nao_configurado(self):
        html = pagina_email([], [], dominio="x.com", metricas={"configurado": False})
        self.assertIn("Monitoramento ainda não configurado", html)


class SaudeEmailsTests(unittest.TestCase):
    def test_info_quando_nao_configurado(self):
        from services import saude
        with patch.object(email_metricas, "configurado", return_value=False):
            estado, detalhe = saude._emails()
        self.assertEqual(estado, "info")
        self.assertIn("não configurado", detalhe)

    def test_atencao_com_pendencia_de_resposta(self):
        from services import saude
        dados = {"configurado": True, "caixas": [],
                 "totais": {"sem_resposta_24h": 2, "recebidas_30d": 5}}
        with patch.object(email_metricas, "configurado", return_value=True), \
                patch.object(email_metricas, "coletar", return_value=dados):
            estado, detalhe = saude._emails()
        self.assertEqual(estado, "atencao")
        self.assertIn("2 e-mail", detalhe)

    def test_atencao_quando_caixa_com_erro(self):
        from services import saude
        dados = {"configurado": True,
                 "caixas": [{"email": "x@x.com", "erro": "timeout"}],
                 "totais": {"sem_resposta_24h": 0, "recebidas_30d": 0}}
        with patch.object(email_metricas, "configurado", return_value=True), \
                patch.object(email_metricas, "coletar", return_value=dados):
            estado, detalhe = saude._emails()
        self.assertEqual(estado, "atencao")
        self.assertIn("erro", detalhe)

    def test_atencao_quando_fora_do_sla(self):
        from services import saude
        dados = {"configurado": True, "caixas": [],
                 "totais": {"sem_resposta_24h": 0, "violacoes_sla": 3,
                            "recebidas_30d": 9}}
        with patch.object(email_metricas, "configurado", return_value=True), \
                patch.object(email_metricas, "coletar", return_value=dados):
            estado, detalhe = saude._emails()
        self.assertEqual(estado, "atencao")
        self.assertIn("fora do SLA", detalhe)

    def test_ok_quando_sem_pendencias(self):
        from services import saude
        dados = {"configurado": True, "caixas": [],
                 "totais": {"sem_resposta_24h": 0, "recebidas_30d": 7}}
        with patch.object(email_metricas, "configurado", return_value=True), \
                patch.object(email_metricas, "coletar", return_value=dados):
            estado, detalhe = saude._emails()
        self.assertEqual(estado, "ok")
        self.assertIn("7 recebidos", detalhe)


class SlaTests(unittest.TestCase):
    def test_slas_padrao_e_override_por_env(self):
        with patch.dict(os.environ, {"MAIL_SLA_HORAS": ""}, clear=False):
            self.assertEqual(email_metricas._slas()["contato@"], 24.0)
            self.assertEqual(email_metricas._slas()["suporte@"], 4.0)
            self.assertEqual(email_metricas._slas()["financeiro@"], 24.0)
        with patch.dict(os.environ, {"MAIL_SLA_HORAS": '{"financeiro@": 2}'}, clear=False):
            slas = email_metricas._slas()
        self.assertEqual(slas["financeiro@"], 2.0)
        self.assertEqual(slas["suporte@"], 4.0)

    def test_violacao_quando_resposta_demora_mais_que_sla(self):
        agora = datetime.now(timezone.utc)
        headers = [{"data": agora - timedelta(hours=10),
                    "message_id": "<a@x>", "para": "to: suporte@mentallpro.com.br"}]
        with patch.object(email_metricas, "ENDERECOS", ("suporte@",)):
            res = email_metricas._metricas_por_endereco(
                agora - timedelta(days=7), headers, {"<a@x>": 300.0}, agora,
                {"suporte@": 4.0})
        self.assertEqual(res["suporte@"]["violacoes_sla"], 1)
        self.assertEqual(res["suporte@"]["respondidas_30d"], 1)

    def test_pendente_fora_do_sla_sem_resposta(self):
        agora = datetime.now(timezone.utc)
        headers = [{"data": agora - timedelta(hours=30),
                    "message_id": "<b@x>", "para": "to: financeiro@mentallpro.com.br"}]
        # O SLA passou a contar minutos uteis (seg-sex 8-18, sab 8-13); fixa a
        # metrica para testar a regra de violacao de forma deterministica.
        with patch.object(email_metricas, "ENDERECOS", ("financeiro@",)), \
             patch.object(email_metricas, "_minutos_uteis", return_value=30 * 60):
            res = email_metricas._metricas_por_endereco(
                agora - timedelta(days=7), headers, {}, agora,
                {"financeiro@": 24.0})
        self.assertEqual(res["financeiro@"]["violacoes_sla"], 1)
        self.assertEqual(res["financeiro@"]["pendentes_sla"], 1)

    def test_dentro_do_sla_nao_viola(self):
        agora = datetime.now(timezone.utc)
        headers = [{"data": agora - timedelta(hours=2),
                    "message_id": "<c@x>", "para": "to: suporte@mentallpro.com.br"}]
        with patch.object(email_metricas, "ENDERECOS", ("suporte@",)):
            res = email_metricas._metricas_por_endereco(
                agora - timedelta(days=7), headers, {"<c@x>": 60.0}, agora,
                {"suporte@": 4.0})
        self.assertEqual(res["suporte@"]["violacoes_sla"], 0)


class AlertasTests(unittest.TestCase):
    def setUp(self):
        from services import email_alertas
        self.alertas = email_alertas

    def test_cooldown(self):
        agora = datetime.now(timezone.utc)
        self.assertTrue(self.alertas._cooldown_ok(agora, ""))
        self.assertFalse(self.alertas._cooldown_ok(
            agora, (agora - timedelta(hours=1)).isoformat()))
        self.assertTrue(self.alertas._cooldown_ok(
            agora, (agora - timedelta(hours=7)).isoformat()))

    def test_pendencias_so_com_violacao(self):
        metricas = {"por_endereco": [
            {"endereco": "suporte@", "violacoes_sla": 2, "pendentes_sla": 1,
             "sla_horas": 4.0},
            {"endereco": "contato@", "violacoes_sla": 0, "pendentes_sla": 0,
             "sla_horas": None},
        ]}
        itens = self.alertas.pendencias(metricas)
        self.assertEqual(len(itens), 1)
        self.assertEqual(itens[0]["endereco"], "suporte@")

    def test_mensagem_tem_endereco_e_sla(self):
        texto = self.alertas.formatar_mensagem([
            {"endereco": "suporte@", "violacoes_sla": 2, "pendentes_sla": 1,
             "sla_horas": 4.0},
        ])
        self.assertIn("suporte@", texto)
        self.assertIn("SLA 4h", texto)
        self.assertIn("Painel", texto)

    def test_notificar_envia_e_respeita_cooldown(self):
        from services import email_alertas as alertas
        metricas = {"por_endereco": [
            {"endereco": "suporte@", "violacoes_sla": 1, "pendentes_sla": 1,
             "sla_horas": 4.0},
        ]}
        enviados = []
        with patch.object(alertas, "pendencias", return_value=alertas.pendencias(metricas)), \
                patch.object(alertas, "_destino", return_value="5511999999999"), \
                patch.object(alertas, "_owner_id", return_value="owner-1"), \
                patch.object(alertas, "_ultimo_envio_iso", return_value=""), \
                patch.object(alertas, "_registrar_envio") as registrar, \
                patch.object(alertas, "_enviar_whatsapp_via_wuzapi",
                             side_effect=lambda o, d, m: (enviados.append(m), (True, "id"))[1]):
            resultado = alertas.notificar()
        self.assertTrue(resultado["enviado"])
        self.assertEqual(len(enviados), 1)
        registrar.assert_called_once()
        # agora com cooldown ativo (último envio recente) não reenvia
        with patch.object(alertas, "pendencias", return_value=alertas.pendencias(metricas)), \
                patch.object(alertas, "_ultimo_envio_iso",
                             return_value=datetime.now(timezone.utc).isoformat()), \
                patch.object(alertas, "_enviar_whatsapp_via_wuzapi") as enviar:
            resultado = alertas.notificar()
        self.assertFalse(resultado["enviado"])
        enviar.assert_not_called()


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

    async def test_admin_email_alertar_agora(self):
        login = await self.client.post(
            "/admin/login", data={"email": "dono@ex.com", "senha": SENHA}
        )
        cookie = login.headers["set-cookie"].split(";")[0]
        with patch.object(main.email_alertas, "notificar",
                          return_value={"enviado": True, "itens": 1}) as mock:
            resposta = await self.client.post(
                "/admin/email/alertar-agora", headers={"Cookie": cookie}
            )
        self.assertEqual(resposta.status_code, 303)
        mock.assert_called_once_with(force=True)

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
