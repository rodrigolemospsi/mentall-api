"""Testes da logica de retry de lembretes do scheduler.

Cobre a regra: um lembrete cujo envio falha deve continuar sendo tentado
durante uma janela de retry (ex: 60 min apos o horario previsto), e so deve
ser marcado como 'falha' depois que a janela expirar.
"""
import unittest
from datetime import datetime, timezone, timedelta

import services.lembrete_service as mod


class TestDecisaoRetry(unittest.TestCase):
    def setUp(self):
        self.original_janela = mod.JANELA_RETRY_MINUTOS
        mod.JANELA_RETRY_MINUTOS = 60

    def tearDown(self):
        mod.JANELA_RETRY_MINUTOS = self.original_janela

    def test_dentro_da_janela_deve_continuar_tentando(self):
        agora = datetime(2026, 8, 25, 18, 30, tzinfo=timezone.utc)
        horario_envio = "2026-08-25T18:00:00+00:00"
        self.assertTrue(mod._deve_continuar_tentando(horario_envio, agora))

    def test_depois_da_janela_deve_marcar_falha(self):
        agora = datetime(2026, 8, 25, 19, 10, tzinfo=timezone.utc)
        horario_envio = "2026-08-25T18:00:00+00:00"
        self.assertFalse(mod._deve_continuar_tentando(horario_envio, agora))

    def test_no_limite_exato_da_janela_ainda_tenta(self):
        agora = datetime(2026, 8, 25, 19, 0, tzinfo=timezone.utc)
        horario_envio = "2026-08-25T18:00:00+00:00"
        self.assertTrue(mod._deve_continuar_tentando(horario_envio, agora))

    def test_suporta_formato_com_zulu_do_app(self):
        agora = datetime(2026, 8, 25, 18, 30, tzinfo=timezone.utc)
        horario_envio = "2026-08-25T18:00:00.000Z"
        self.assertTrue(mod._deve_continuar_tentando(horario_envio, agora))

    def test_valor_invalido_nao_estoura(self):
        agora = datetime(2026, 8, 25, 18, 30, tzinfo=timezone.utc)
        self.assertFalse(mod._deve_continuar_tentando("formato-invalido", agora))

    def test_janela_usa_minutos_configuraveis(self):
        mod.JANELA_RETRY_MINUTOS = 15
        agora = datetime(2026, 8, 25, 18, 30, tzinfo=timezone.utc)
        horario_envio = "2026-08-25T18:00:00+00:00"
        self.assertFalse(mod._deve_continuar_tentando(horario_envio, agora))


if __name__ == "__main__":
    unittest.main()
