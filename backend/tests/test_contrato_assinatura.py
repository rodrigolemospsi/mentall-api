"""Assinatura eletrônica simples do contrato: evidências, código e verificação."""
import json
import unittest

import httpx
import main
from services import contrato_service as service, db

DADOS = {
    "nome_paciente": "Maria Teste Silva",
    "nome_profissional": "Rodrigo Lemos",
    "registro_profissional": "06/123456",
    "termo_pessoa": "paciente",
    "template_contrato": "",
    "tratamento": "masculino",
    "crp_verificado": True,
    "cpf_profissional": "11144477735",
    "cnpj_profissional": "11222333000181",
}

CPF_VALIDO = "11144477735"


class ContratoAssinaturaTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        db.executar("DELETE FROM contratos").commit()
        main._rate_limit_store.clear()
        self.owner = "owner-contrato"
        self.jwt = main._criar_token_jwt("contrato@example.invalid", self.owner)
        self.headers = {"Authorization": f"Bearer {self.jwt}"}
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=main.app),
            base_url="https://test.invalid",
            headers={"user-agent": "MentAll-Test/1.0"},
        )
        self.addAsyncCleanup(self.client.aclose)
        self.token = service.criar_contrato(dict(DADOS), self.owner)

    async def assinar(self, **payload):
        corpo = {"nome": "Maria Teste Silva", "cpf": CPF_VALIDO, "aceite": True}
        corpo.update(payload)
        return await self.client.post(f"/contratos/{self.token}/aceitar", json=corpo)

    # -- evidências --------------------------------------------------------
    async def test_assinatura_registra_evidencias_completas(self):
        response = await self.assinar()
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertTrue(body["sucesso"])
        self.assertEqual(body["status"], "aceito")
        self.assertRegex(body["aceite_codigo"], r"^[A-Z0-9]{5}-[A-Z0-9]{5}$")
        self.assertRegex(body["aceite_hash"], r"^[0-9a-f]{64}$")
        self.assertEqual(body["aceite_versao"], "contrato-v1")
        self.assertEqual(body["aceite_cpf_mascarado"], "***.***.777-**")
        self.assertIn(body["aceite_codigo"], body["verificacao_url"])

        salvo = service.obter_contrato(self.token)
        self.assertEqual(salvo["status"], "aceito")
        self.assertEqual(salvo["aceite_cpf"], CPF_VALIDO)
        self.assertTrue(salvo["aceite_ip"])
        self.assertEqual(salvo["aceite_user_agent"], "MentAll-Test/1.0")
        # Hash reprodutível a partir do conteúdo canônico.
        self.assertEqual(salvo["aceite_hash"], service.hash_documento_contrato(DADOS))
        self.assertIn("ACORDO TERAPÊUTICO", service.texto_documento_contrato(DADOS))
        self.assertIn("Maria Teste Silva", service.texto_documento_contrato(DADOS))

    async def test_reassinatura_nao_sobrescreve_evidencias(self):
        primeira = await self.assinar()
        segunda = await self.assinar(nome="Outra Pessoa", cpf="")
        self.assertEqual(segunda.status_code, 200)
        self.assertEqual(segunda.json()["aceite_codigo"], primeira.json()["aceite_codigo"])
        salvo = service.obter_contrato(self.token)
        self.assertEqual(salvo["nome_aceite"], "Maria Teste Silva")
        self.assertEqual(salvo["aceite_cpf"], CPF_VALIDO)

    async def test_assinatura_sem_checkbox_ou_cpf_invalido_falha(self):
        sem_checkbox = await self.assinar(aceite=False)
        self.assertEqual(sem_checkbox.status_code, 400)
        cpf_invalido = await self.assinar(cpf="12345678900")
        self.assertEqual(cpf_invalido.status_code, 400)
        nome_curto = await self.assinar(nome="Ma")
        self.assertEqual(nome_curto.status_code, 422)
        self.assertEqual(service.obter_contrato(self.token)["status"], "pendente")

    async def test_assinatura_sem_cpf_e_sem_checkbox_legado_aceita(self):
        """Páginas antigas (cache) enviam só o nome; aceite tem default True."""
        response = await self.client.post(
            f"/contratos/{self.token}/aceitar", json={"nome": "Maria Teste Silva"})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "aceito")
        self.assertEqual(response.json()["aceite_cpf_mascarado"], "")

    # -- status e verificação ---------------------------------------------
    async def test_status_do_dono_expoe_comprovante_e_texto(self):
        await self.assinar()
        response = await self.client.get(
            f"/contratos/{self.token}/status", headers=self.headers)
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertTrue(body["sucesso"])
        self.assertEqual(
            body["aceite_codigo"],
            service.formatar_codigo(service.obter_contrato(self.token)["aceite_codigo"]),
        )
        self.assertIn("ACORDO TERAPÊUTICO", body["documento_texto"])
        self.assertEqual(body["cpf_profissional"], CPF_VALIDO)
        self.assertEqual(body["cnpj_profissional"], DADOS["cnpj_profissional"])

        outro = main._criar_token_jwt("outro@example.invalid", "owner-outro")
        negado = await self.client.get(
            f"/contratos/{self.token}/status",
            headers={"Authorization": f"Bearer {outro}"},
        )
        self.assertFalse(negado.json()["sucesso"])

    async def test_pagina_publica_verifica_codigo(self):
        await self.assinar()
        codigo = service.formatar_codigo(service.obter_contrato(self.token)["aceite_codigo"])
        pagina = await self.client.get(f"/verificar/{codigo}")
        self.assertEqual(pagina.status_code, 200)
        self.assertEqual(pagina.headers.get("cache-control"), "no-store")
        self.assertIn("Documento assinado eletronicamente", pagina.text)
        self.assertIn(codigo, pagina.text)
        self.assertIn("Rodrigo Lemos", pagina.text)
        self.assertIn("Maria ...", pagina.text)
        # Não expõe nome completo do paciente nem o CPF na página pública.
        self.assertNotIn("Maria Teste Silva", pagina.text)
        self.assertNotIn("111.444.777-35", pagina.text)

        nao_encontrado = await self.client.get("/verificar/ZZZZZ-ZZZZZ")
        self.assertEqual(nao_encontrado.status_code, 404)
        self.assertEqual(nao_encontrado.headers.get("cache-control"), "no-store")

    # -- páginas do contrato ----------------------------------------------
    async def test_pagina_pendente_tem_novo_fluxo_de_assinatura(self):
        pagina = await self.client.get(f"/contratos/{self.token}")
        self.assertEqual(pagina.status_code, 200)
        self.assertIn('id="aceite-check"', pagina.text)
        self.assertIn('id="cpf-confirmacao"', pagina.text)
        self.assertIn("Assinar documento", pagina.text)
        self.assertIn("111.444.777-35", pagina.text)  # linha fiscal do profissional

    async def test_pagina_aceita_mostra_comprovante(self):
        await self.assinar()
        codigo = service.formatar_codigo(service.obter_contrato(self.token)["aceite_codigo"])
        pagina = await self.client.get(f"/contratos/{self.token}")
        self.assertIn("Documento assinado eletronicamente", pagina.text)
        self.assertIn(codigo, pagina.text)
        self.assertIn(f"/verificar/{codigo}", pagina.text)
        self.assertIn("Hash SHA-256", pagina.text)

    async def test_template_personalizado_usa_novo_fluxo(self):
        dados = dict(DADOS)
        dados["template_contrato"] = "Meu acordo personalizado.\n\nSigilo profissional."
        token = service.criar_contrato(dados, self.owner)
        pagina = await self.client.get(f"/contratos/{token}")
        self.assertIn("Meu acordo personalizado.", pagina.text)
        self.assertIn('id="aceite-check"', pagina.text)
        response = await self.client.post(
            f"/contratos/{token}/aceitar",
            json={"nome": "Maria Teste Silva", "cpf": CPF_VALIDO, "aceite": True},
        )
        self.assertEqual(response.status_code, 200)
        pagina_aceita = await self.client.get(f"/contratos/{token}")
        self.assertIn("Documento assinado eletronicamente", pagina_aceita.text)

    # -- funções auxiliares -----------------------------------------------
    def test_cpf_e_texto_canonico(self):
        self.assertTrue(service.cpf_valido(CPF_VALIDO))
        self.assertFalse(service.cpf_valido("12345678900"))
        self.assertEqual(service.normalizar_cpf("111.444.777-35"), CPF_VALIDO)
        self.assertEqual(service.mascarar_cpf(CPF_VALIDO), "***.***.777-**")
        texto = service.texto_documento_contrato(DADOS)
        self.assertIn("CNPJ", texto)
        self.assertIn("CPF do profissional", texto)
        self.assertEqual(
            service.hash_documento_contrato(DADOS),
            service.hash_documento_contrato(dict(DADOS)),
        )


if __name__ == "__main__":
    unittest.main()
