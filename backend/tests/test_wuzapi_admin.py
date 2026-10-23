"""Testes do provisionamento/conexao de instancias wuzapi por profissional.

Cobrem o contrato usado pela tela de Configuracoes do app:
- criar instancia sob demanda (idempotente) via admin API do wuzapi;
- gerar codigo de pareamento (POST /session/pairphone);
- consultar status (GET /session/status);
- desconectar/logout;
- fail-closed sem WUZAPI_ADMIN_TOKEN;
- re-provisionar quando o owner ainda nao tem instancia (conta nova).
"""
import os
import unittest
from unittest import mock

os.environ.setdefault("JWT_SECRET", "teste-segredo")
os.environ.setdefault("APP_PASSWORD_HASH", "teste-hash")
os.environ.setdefault("SMTP_HOST", "")
os.environ.setdefault("WUZAPI_BASE_URL", "")

import services.wuzapi_admin as mod  # noqa: E402

OWNER = "owner-wuzapi-admin"


def _resposta(status_code=200, payload=None, texto=""):
    resp = mock.Mock()
    resp.status_code = status_code
    resp.json.return_value = payload or {}
    resp.text = texto
    return resp


class BaseWuzapi(unittest.TestCase):
    def setUp(self):
        os.environ["WUZAPI_BASE_URL"] = "http://localhost:8080"
        os.environ["WUZAPI_ADMIN_TOKEN"] = "admin-teste"
        os.environ["API_BASE_URL"] = "https://mentall-api.fly.dev"
        os.environ["WUZAPI_WEBHOOK_TOKEN"] = "webhook-teste"
        self._limpar(OWNER)
        self._limpar(OWNER + "-b")

    def tearDown(self):
        for k in ("WUZAPI_BASE_URL", "WUZAPI_ADMIN_TOKEN", "API_BASE_URL",
                  "WUZAPI_WEBHOOK_TOKEN"):
            os.environ.pop(k, None)
        self._limpar(OWNER)
        self._limpar(OWNER + "-b")

    def _limpar(self, owner):
        mod.executar("DELETE FROM wuzapi_instancias WHERE owner_id = ?", (owner,)).commit()


class TestGarantirInstancia(BaseWuzapi):
    def test_cria_instancia_e_persiste_token(self):
        with mock.patch("services.wuzapi_admin.requests.post",
                        return_value=_resposta(200, {"id": 7})) as post:
            token = mod.garantir_instancia(OWNER)

        self.assertTrue(token)
        row = mod.executar(
            "SELECT wuzapi_token, wuzapi_user_id FROM wuzapi_instancias WHERE owner_id = ?",
            (OWNER,),
        ).fetchone()
        self.assertIsNotNone(row)
        self.assertEqual(row["wuzapi_token"], token)
        self.assertEqual(row["wuzapi_user_id"], 7)

        args, kwargs = post.call_args
        self.assertEqual(args[0], "http://localhost:8080/admin/users")
        self.assertEqual(kwargs["headers"]["Authorization"], "admin-teste")
        self.assertEqual(kwargs["json"]["token"], token)
        self.assertEqual(kwargs["json"]["events"], "ReadReceipt")
        self.assertIn("/wuzapi/webhook?token=webhook-teste", kwargs["json"]["webhook"])

    def test_idempotente_nao_cria_de_novo(self):
        mod.salvar_instancia_wuzapi(OWNER, "token-existente")
        with mock.patch("services.wuzapi_admin.requests.post") as post:
            token = mod.garantir_instancia(OWNER)
        self.assertEqual(token, "token-existente")
        post.assert_not_called()

    def test_sem_admin_token_nao_cria(self):
        os.environ.pop("WUZAPI_ADMIN_TOKEN", None)
        with mock.patch("services.wuzapi_admin.requests.post") as post:
            token = mod.garantir_instancia(OWNER)
        self.assertEqual(token, "")
        post.assert_not_called()

    def test_reprovisiona_conta_nova(self):
        with mock.patch("services.wuzapi_admin.requests.post",
                        return_value=_resposta(200, {"id": 1})):
            token_a = mod.garantir_instancia(OWNER)
        with mock.patch("services.wuzapi_admin.requests.post",
                        return_value=_resposta(200, {"id": 2})):
            token_b = mod.garantir_instancia(OWNER + "-b")
        self.assertTrue(token_a)
        self.assertTrue(token_b)
        self.assertNotEqual(token_a, token_b)


class TestParear(BaseWuzapi):
    def test_parear_devolve_codigo(self):
        mod.salvar_instancia_wuzapi(OWNER, "token-u")
        conecta = _resposta(200, {"success": True, "data": {}})
        pareia = _resposta(200, {"success": True, "data": {"LinkingCode": "ABCD-EFGH"}})
        with mock.patch("services.wuzapi_admin.requests.post",
                        side_effect=[conecta, pareia]) as post:
            resultado = mod.parear(OWNER, "(75) 9229-8347")

        self.assertTrue(resultado["sucesso"])
        self.assertEqual(resultado["codigo"], "ABCD-EFGH")
        # 1a chamada: connect; 2a: pairphone com o numero normalizado.
        self.assertEqual(post.call_args_list[0].args[0], "http://localhost:8080/session/connect")
        self.assertEqual(post.call_args_list[1].args[0], "http://localhost:8080/session/pairphone")
        self.assertEqual(post.call_args_list[1].kwargs["json"]["Phone"], "557592298347")

    def test_parear_sem_instancia_e_sem_admin_falha(self):
        os.environ.pop("WUZAPI_ADMIN_TOKEN", None)
        resultado = mod.parear(OWNER, "(75) 9229-8347")
        self.assertFalse(resultado["sucesso"])
        self.assertTrue(resultado["erro"])


class TestStatus(BaseWuzapi):
    def test_status_conectado(self):
        mod.salvar_instancia_wuzapi(OWNER, "token-u")
        with mock.patch("services.wuzapi_admin.requests.get",
                        return_value=_resposta(200, {"success": True, "data": {
                            "connected": True, "loggedIn": True, "jid": "557592298347@s.whatsapp.net"}})):
            st = mod.status(OWNER)
        self.assertTrue(st["configurado"])
        self.assertTrue(st["conectado"])
        self.assertTrue(st["logado"])
        self.assertIn("557592298347", st["numero"])

    def test_status_formato_antigo_pascalcase(self):
        """Fallback: respostas antigas do wuzapi usavam chaves PascalCase."""
        mod.salvar_instancia_wuzapi(OWNER, "token-u")
        with mock.patch("services.wuzapi_admin.requests.get",
                        return_value=_resposta(200, {"success": True, "data": {
                            "Connected": True, "LoggedIn": True, "Jid": "557592298347@s.whatsapp.net"}})):
            st = mod.status(OWNER)
        self.assertTrue(st["conectado"])
        self.assertIn("557592298347", st["numero"])

    def test_status_sem_instancia(self):
        st = mod.status("owner-sem-instancia")
        self.assertFalse(st["configurado"])
        self.assertFalse(st["conectado"])


class TestDesconectar(BaseWuzapi):
    def test_desconectar(self):
        mod.salvar_instancia_wuzapi(OWNER, "token-u")
        with mock.patch("services.wuzapi_admin.requests.post",
                        return_value=_resposta(200, {"success": True})) as post:
            ok = mod.desconectar(OWNER, logout=False)
        self.assertTrue(ok)
        self.assertEqual(post.call_args.args[0], "http://localhost:8080/session/disconnect")

    def test_logout(self):
        mod.salvar_instancia_wuzapi(OWNER, "token-u")
        with mock.patch("services.wuzapi_admin.requests.post",
                        return_value=_resposta(200, {"success": True})) as post:
            ok = mod.desconectar(OWNER, logout=True)
        self.assertTrue(ok)
        self.assertEqual(post.call_args.args[0], "http://localhost:8080/session/logout")


class TestQr(BaseWuzapi):
    def test_qr_devolve_data_uri(self):
        mod.salvar_instancia_wuzapi(OWNER, "token-u")
        conecta = _resposta(200, {"success": True})
        qr = _resposta(200, {"success": True, "data": {"QRCode": "data:image/png;base64,AAA"}})
        with mock.patch("services.wuzapi_admin.requests.post", side_effect=[conecta]), \
                mock.patch("services.wuzapi_admin.requests.get", return_value=qr):
            resultado = mod.qr(OWNER)
        self.assertTrue(resultado["sucesso"])
        self.assertEqual(resultado["qr_code"], "data:image/png;base64,AAA")


class TestTestar(BaseWuzapi):
    def test_testar_delega_para_envio(self):
        mod.salvar_instancia_wuzapi(OWNER, "token-u")
        with mock.patch("services.wuzapi_admin._enviar_whatsapp_via_wuzapi",
                        return_value=(True, "MSG1")) as enviar:
            resultado = mod.testar(OWNER, "(75) 9229-8347", "teste")
        self.assertTrue(resultado["sucesso"])
        enviar.assert_called_once()
        self.assertEqual(enviar.call_args.args[0], OWNER)


if __name__ == "__main__":
    unittest.main()
