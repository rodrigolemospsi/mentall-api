"""Testes do watchdog de reconexao do wuzapi.

O problema original: quando a conexao do WhatsApp cai, o wuzapi permanece
com o processo vivo mas desconectado (logged_in_users=0), e nao reconecta
sozinho. O watchdog do backend verifica o /health periodicamente e, se
desconectado, chama /session/connect para restabelecer a sessao salva.
"""
import os
import time
import unittest
from unittest import mock

import services.lembrete_service as mod


class TestHealthWuzapi(unittest.TestCase):
    def setUp(self):
        os.environ["WUZAPI_BASE_URL"] = "http://localhost:8080"
        os.environ["WUZAPI_TOKEN"] = "token-teste"

    def tearDown(self):
        for k in ("WUZAPI_BASE_URL", "WUZAPI_TOKEN"):
            os.environ.pop(k, None)

    def test_health_ok_quando_logado(self):
        with mock.patch("services.lembrete_service.requests.get") as get:
            get.return_value.status_code = 200
            get.return_value.json.return_value = {"logged_in_users": 1, "total_users": 1}
            self.assertTrue(mod._wuzapi_health_ok("http://localhost:8080"))
            get.assert_called_once()

    def test_health_false_quando_deslogado(self):
        with mock.patch("services.lembrete_service.requests.get") as get:
            get.return_value.status_code = 200
            get.return_value.json.return_value = {"logged_in_users": 0, "total_users": 1}
            self.assertFalse(mod._wuzapi_health_ok("http://localhost:8080"))

    def test_health_false_sem_usuarios(self):
        with mock.patch("services.lembrete_service.requests.get") as get:
            get.return_value.status_code = 200
            get.return_value.json.return_value = {"logged_in_users": 0, "total_users": 0}
            self.assertTrue(mod._wuzapi_health_ok("http://localhost:8080"))

    def test_health_false_em_erro_de_rede(self):
        with mock.patch("services.lembrete_service.requests.get", side_effect=Exception("off")):
            self.assertFalse(mod._wuzapi_health_ok("http://localhost:8080"))

    def test_health_false_em_status_nao_200(self):
        with mock.patch("services.lembrete_service.requests.get") as get:
            get.return_value.status_code = 500
            self.assertFalse(mod._wuzapi_health_ok("http://localhost:8080"))


class TestReconectarWuzapi(unittest.TestCase):
    def test_reconecta_com_sucesso(self):
        with mock.patch("services.lembrete_service.requests.post") as post:
            post.return_value.status_code = 200
            post.return_value.json.return_value = {"success": True}
            self.assertTrue(mod._reconectar_wuzapi("http://localhost:8080", "tok"))
            args, kwargs = post.call_args
            self.assertEqual(args[0], "http://localhost:8080/session/connect")
            self.assertEqual(kwargs["headers"]["token"], "tok")
            self.assertEqual(kwargs["json"]["Subscribe"], ["All"])

    def test_reconecta_falha_em_500(self):
        with mock.patch("services.lembrete_service.requests.post") as post:
            post.return_value.status_code = 500
            self.assertFalse(mod._reconectar_wuzapi("http://localhost:8080", "tok"))

    def test_reconecta_falha_em_excecao(self):
        with mock.patch("services.lembrete_service.requests.post", side_effect=Exception("boom")):
            self.assertFalse(mod._reconectar_wuzapi("http://localhost:8080", "tok"))


class TestWatchdog(unittest.TestCase):
    def setUp(self):
        os.environ["WUZAPI_BASE_URL"] = "http://localhost:8080"
        os.environ["WUZAPI_TOKEN"] = "token-teste"
        self.original_cooldown = mod._WUZAPI_RECONNECT_COOLDOWN_SECONDS
        self.original_ultima = mod._ultima_reconexao_wuzapi
        mod._WUZAPI_RECONNECT_COOLDOWN_SECONDS = 300
        mod._ultima_reconexao_wuzapi = 0.0

    def tearDown(self):
        mod._WUZAPI_RECONNECT_COOLDOWN_SECONDS = self.original_cooldown
        mod._ultima_reconexao_wuzapi = self.original_ultima
        for k in ("WUZAPI_BASE_URL", "WUZAPI_TOKEN"):
            os.environ.pop(k, None)

    def test_nao_reconecta_quando_online(self):
        with mock.patch("services.lembrete_service._wuzapi_health_ok", return_value=True) as health:
            with mock.patch("services.lembrete_service._reconectar_wuzapi") as reconectar:
                self.assertFalse(mod._checar_e_reconectar_wuzapi())
                health.assert_called_once()
                reconectar.assert_not_called()

    def test_reconecta_quando_desconectado(self):
        with mock.patch("services.lembrete_service._wuzapi_health_ok", return_value=False):
            with mock.patch("services.lembrete_service._reconectar_wuzapi", return_value=True) as reconectar:
                self.assertTrue(mod._checar_e_reconectar_wuzapi())
                reconectar.assert_called_once()

    def test_respeita_cooldown_entre_tentativas(self):
        mod._ultima_reconexao_wuzapi = time.time()
        with mock.patch("services.lembrete_service._wuzapi_health_ok") as health:
            with mock.patch("services.lembrete_service._reconectar_wuzapi") as reconectar:
                self.assertFalse(mod._checar_e_reconectar_wuzapi())
                health.assert_not_called()
                reconectar.assert_not_called()

    def test_sem_base_url_nao_faz_nada(self):
        os.environ.pop("WUZAPI_BASE_URL", None)
        with mock.patch("services.lembrete_service._wuzapi_health_ok") as health:
            self.assertFalse(mod._checar_e_reconectar_wuzapi())
            health.assert_not_called()


if __name__ == "__main__":
    unittest.main()
