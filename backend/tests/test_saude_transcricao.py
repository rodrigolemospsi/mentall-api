"""Saúde: IA de síntese e transcrição separadas (Fase 5D)."""
import os
import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

from services import saude, transcricao


class SaudeIATests(unittest.TestCase):
    def setUp(self):
        transcricao.limpar_ultima_falha()

    def test_verificacoes_separadas(self):
        nomes = [nome for nome, _ in saude._VERIFICACOES]
        self.assertIn("IA de síntese", nomes)
        self.assertIn("Transcrição", nomes)
        self.assertNotIn("IA clínica", nomes)

    def test_transcricao_sem_chave_e_erro(self):
        with patch.dict(
            os.environ,
            {"TRANSCRICAO_PROVIDER": "groq", "GROQ_API_KEY": "", "TRANSCRICAO_MODEL": "whisper-large-v3-turbo"},
            clear=False,
        ):
            estado, detalhe = saude._transcricao()
        self.assertEqual(estado, "erro")
        self.assertIn("GROQ_API_KEY", detalhe)
        self.assertIn("groq/whisper-large-v3-turbo", detalhe)

    def test_transcricao_configurada_ok(self):
        with patch.dict(
            os.environ,
            {"TRANSCRICAO_PROVIDER": "groq", "GROQ_API_KEY": "x", "TRANSCRICAO_MODEL": "whisper-large-v3-turbo"},
            clear=False,
        ):
            estado, detalhe = saude._transcricao()
        self.assertEqual(estado, "ok")
        self.assertIn("groq/whisper-large-v3-turbo", detalhe)
        self.assertIn("chave configurada", detalhe)

    def test_falha_recente_gera_atencao(self):
        with patch.dict(
            os.environ,
            {"TRANSCRICAO_PROVIDER": "groq", "GROQ_API_KEY": "x", "TRANSCRICAO_MODEL": "whisper-large-v3-turbo"},
            clear=False,
        ):
            transcricao._registrar_falha("groq", RuntimeError("timeout na API"))
            estado, detalhe = saude._transcricao()
        self.assertEqual(estado, "atencao")
        self.assertIn("timeout", detalhe)

    def test_falha_antiga_nao_alerta(self):
        with patch.dict(
            os.environ,
            {"TRANSCRICAO_PROVIDER": "groq", "GROQ_API_KEY": "x", "TRANSCRICAO_MODEL": "whisper-large-v3-turbo"},
            clear=False,
        ):
            transcricao._registrar_falha("groq", RuntimeError("falha antiga"))
            transcricao._ULTIMA_FALHA["quando"] = (
                datetime.now(timezone.utc) - timedelta(hours=30)
            ).isoformat()
            estado, _ = saude._transcricao()
        self.assertEqual(estado, "ok")

    def test_provider_openai_usa_chave_openai(self):
        with patch.dict(
            os.environ,
            {"TRANSCRICAO_PROVIDER": "openai", "OPENAI_API_KEY": "", "GROQ_API_KEY": "x"},
            clear=False,
        ):
            estado, detalhe = saude._transcricao()
        self.assertEqual(estado, "erro")
        self.assertIn("OPENAI_API_KEY", detalhe)

    def test_ia_de_sintese_continua_funcionando(self):
        estado, detalhe = saude._ia_sintese()
        self.assertIn(estado, ("ok", "atencao", "erro"))
        self.assertTrue(detalhe)


class RegistroFalhaTests(unittest.TestCase):
    def setUp(self):
        transcricao.limpar_ultima_falha()

    def test_registrar_e_limpar(self):
        self.assertIsNone(transcricao.ultima_falha())
        transcricao._registrar_falha("groq", ValueError("x" * 500))
        falha = transcricao.ultima_falha()
        self.assertIsNotNone(falha)
        self.assertEqual(falha["provider"], "groq")
        self.assertLessEqual(len(falha["mensagem"]), 160)
        transcricao.limpar_ultima_falha()
        self.assertIsNone(transcricao.ultima_falha())


if __name__ == "__main__":
    unittest.main()
