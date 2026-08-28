"""Testes da sintese clinica: combinacao de material e descoberta de tema.

Cobrem:
1. `gerar_sintese` combina relato manual E transcricao no material (sem descartar).
2. So relato manual ou so transcricao funcionam isoladamente.
3. Sem material -> erro.
4. Sem `tema_principal`, o prompt instrui a IA a identificar o tema do material.
5. Com `tema_principal`, o prompt usa o tema informado.
"""
import unittest
from unittest import mock

import services.ia_clinica as mod


def _sucesso():
    return {"sucesso": True, "erro": ""}


class TestSinteseMaterial(unittest.TestCase):
    def setUp(self):
        self.base = dict(
            sessao_id="s1",
            numero_sessao=2,
            nome_pessoa_atendida="Maria S.",
            termo_pessoa_atendida="paciente",
            abordagem_clinica="TCC",
            transcricao_relato="",
            relato_manual="",
            tema_principal="",
        )

    def _capturar_material(self, **kwargs):
        params = dict(self.base)
        params.update(kwargs)
        capturado = {}

        def fake_montar(**kw):
            capturado["material"] = kw.get("material_base", "")
            capturado["tema"] = kw.get("tema_principal", "")
            return "PROMPT"

        with mock.patch.object(mod, "_montar_prompt_sintese", side_effect=fake_montar), \
             mock.patch.object(mod, "_chamar_provider_sintese", return_value=_sucesso()):
            mod.gerar_sintese(**params)
        return capturado

    def test_combina_relato_e_transcricao(self):
        out = self._capturar_material(
            relato_manual="Cliente relatou ansiedade.",
            transcricao_relato="[transcricao do audio]",
        )
        self.assertIn("RELATO DO PROFISSIONAL:\nCliente relatou ansiedade.", out["material"])
        self.assertIn("TRANSCRIÇÃO DO ÁUDIO:\n[transcricao do audio]", out["material"])

    def test_so_relato_manual(self):
        out = self._capturar_material(relato_manual="Somente relato manual.")
        self.assertIn("RELATO DO PROFISSIONAL:", out["material"])
        self.assertNotIn("TRANSCRIÇÃO DO ÁUDIO:", out["material"])

    def test_so_transcricao(self):
        out = self._capturar_material(transcricao_relato="Somente transcrição.")
        self.assertIn("TRANSCRIÇÃO DO ÁUDIO:\nSomente transcrição.", out["material"])
        self.assertNotIn("RELATO DO PROFISSIONAL:", out["material"])

    def test_sem_material_retorna_erro(self):
        with mock.patch.object(mod, "_chamar_provider_sintese", return_value=_sucesso()):
            resultado = mod.gerar_sintese(**self.base)
        self.assertFalse(resultado["sucesso"])
        self.assertIn("não há relato ou transcrição", resultado["erro"].lower())

    def test_sem_tema_instrui_ia_a_identificar(self):
        out = self._capturar_material(
            relato_manual="Relato sobre ansiedade social.",
        )
        self.assertNotIn("Tema principal informado", out["tema"])

    def test_com_tema_usa_o_informado(self):
        out = self._capturar_material(
            relato_manual="Relato.",
            tema_principal="Ansiedade social",
        )
        self.assertEqual(out["tema"], "Ansiedade social")


class TestPromptTema(unittest.TestCase):
    def test_prompt_linha_tema_identificacao(self):
        from prompts.abordagens import PROMPT_UNIVERSAL

        prompt = mod._montar_prompt_sintese(
            numero_sessao=1,
            nome_pessoa_atendida="Maria S.",
            termo_pessoa_atendida="paciente",
            abordagem_clinica="TCC",
            material_base="Relato clínico.",
            tema_principal="",
            prompt_abordagem="",
        )
        self.assertIn("Tema principal: identificar a partir do material clínico", prompt)

    def test_prompt_linha_tema_informado(self):
        prompt = mod._montar_prompt_sintese(
            numero_sessao=1,
            nome_pessoa_atendida="Maria S.",
            termo_pessoa_atendida="paciente",
            abordagem_clinica="TCC",
            material_base="Relato clínico.",
            tema_principal="Luto",
            prompt_abordagem="",
        )
        self.assertIn("Tema principal informado: Luto", prompt)


if __name__ == "__main__":
    unittest.main()
