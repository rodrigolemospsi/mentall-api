"""CSP com nonce nas páginas públicas (contrato/anamnese).

Remove o `script-src 'unsafe-inline'` e passa a exigir um nonce por resposta,
injetado nas tags <script> inline. Também garante que não há handlers inline
(`onclick=`), que o CSP com nonce não executa.
"""
import re
import unittest

import httpx

import main
from services import anamnese_service, contrato_service, db


class CspNonceTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        db.executar("DELETE FROM anamneses").commit()
        db.executar("DELETE FROM contratos").commit()
        main._rate_limit_store.clear()
        self.anamnese_token = anamnese_service.criar_anamnese('{"secoes": []}', "owner-a")
        self.contrato_token = contrato_service.criar_contrato({
            "nome_paciente": "Maria",
            "nome_profissional": "Dr. Fulano",
            "registro_profissional": "06/12345",
            "termo_pessoa": "paciente",
            "tratamento": "masculino",
        }, "owner-a")
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=main.app), base_url="https://test.invalid")
        self.addAsyncCleanup(self.client.aclose)

    def _nonce(self, response):
        csp = response.headers.get("content-security-policy", "")
        m = re.search(r"'nonce-([^']+)'", csp)
        return csp, (m.group(1) if m else None)

    async def _assert_csp(self, path):
        r = await self.client.get(path)
        self.assertEqual(r.status_code, 200)
        csp, nonce = self._nonce(r)
        self.assertIsNotNone(nonce, f"sem nonce no CSP de {path}: {csp}")
        self.assertIn("script-src 'self' 'nonce-", csp)
        self.assertNotIn("script-src 'self' 'unsafe-inline'", csp)
        # O <script> inline precisa carregar exatamente o nonce do header.
        self.assertIn(f'<script nonce="{nonce}">', r.text)
        self.assertNotIn("<script>", r.text)
        # Nenhum handler inline (não executaria sob o CSP com nonce).
        self.assertNotIn("onclick=", r.text)
        return r

    async def test_anamnese_csp_nonce(self):
        await self._assert_csp(f"/anamneses/{self.anamnese_token}")

    async def test_contrato_csp_nonce(self):
        await self._assert_csp(f"/contratos/{self.contrato_token}")


if __name__ == "__main__":
    unittest.main()
