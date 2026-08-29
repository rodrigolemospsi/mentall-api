"""Testes do fix de badge CRP falseavel (pentest Strix 28/08).

O `crp_verificado` era enviado pelo cliente e renderizado nas paginas publicas
mesmo quando o servidor (consulta ao CFP) reportava CRP inativo. Agora o flag
e derivado no servidor no momento da criacao: so vira True se a verificacao
real confirmar registro ativo. Falha de rede -> False (fail-closed).
"""
import os
import unittest
from unittest import mock

os.environ.setdefault("JWT_SECRET", "teste-segredo")
os.environ.setdefault("APP_PASSWORD_HASH", "teste-hash")
os.environ.setdefault("SMTP_HOST", "")
os.environ.setdefault("WUZAPI_BASE_URL", "")

import main  # noqa: E402


class TestCrpDerivadoNoServidor(unittest.TestCase):
    def test_cliente_falso_nao_gera_selo(self):
        # cliente afirma verificado, mas CFP diz inativo -> False
        with mock.patch("main.verificar_crp_online", return_value={"ativo": False, "erro": "CRP nao ativo"}) as v:
            self.assertFalse(main._crp_verificado_servidor("06/12345", cliente_afirma=True))
        v.assert_called_once()

    def test_crp_realmente_ativo_retorna_true(self):
        with mock.patch("main.verificar_crp_online", return_value={"ativo": True, "nome_oficial": "X"}):
            self.assertTrue(main._crp_verificado_servidor("06/12345", cliente_afirma=True))

    def test_sem_registro_nao_verifica(self):
        with mock.patch("main.verificar_crp_online") as v:
            self.assertFalse(main._crp_verificado_servidor("", cliente_afirma=True))
        v.assert_not_called()

    def test_sem_afirmacao_do_cliente_nao_verifica(self):
        with mock.patch("main.verificar_crp_online") as v:
            self.assertFalse(main._crp_verificado_servidor("06/12345", cliente_afirma=False))
        v.assert_not_called()

    def test_falha_de_rede_nao_gera_selo(self):
        # fail-closed: se a consulta ao CFP falhar, nao confia no cliente
        with mock.patch("main.verificar_crp_online", side_effect=Exception("timeout")):
            self.assertFalse(main._crp_verificado_servidor("06/12345", cliente_afirma=True))


if __name__ == "__main__":
    unittest.main()
