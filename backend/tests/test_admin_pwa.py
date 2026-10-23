"""PWA do painel (Fase 5E): manifest, service worker, ícones e responsivo."""
import unittest
from datetime import datetime, timezone

import httpx

import main
from services import db
from services.usuarios import hash_senha

SENHA = "SenhaForte123"
TABELAS = ("usuarios", "admin_sessoes", "tokens_revogados")


def _iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _limpar() -> None:
    for tabela in TABELAS:
        db.executar(f"DELETE FROM {tabela}").commit()
    main._rate_limit_store.clear()


def _usuario(uid, email, role="admin"):
    db.executar(
        "INSERT INTO usuarios (id, email, password_hash, nome, plano, status, role, criado_em) "
        "VALUES (?, ?, ?, 'Nome', 'pro', 'ativo', ?, ?)",
        (uid, email, hash_senha(SENHA), role, _iso()),
    ).commit()


class PwaAssetsTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        _limpar()
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=main.app),
            base_url="https://test.invalid",
            follow_redirects=False,
        )
        self.addAsyncCleanup(self.client.aclose)

    async def test_manifest(self):
        resposta = await self.client.get("/admin/manifest.webmanifest")
        self.assertEqual(resposta.status_code, 200)
        self.assertIn("manifest", resposta.headers["content-type"])
        dados = resposta.json()
        self.assertEqual(dados["start_url"], "/admin")
        self.assertEqual(dados["scope"], "/admin")
        self.assertEqual(dados["display"], "standalone")
        self.assertEqual(dados["theme_color"], "#8806CE")
        self.assertGreaterEqual(len(dados["icons"]), 2)

    async def test_service_worker(self):
        resposta = await self.client.get("/admin/sw.js")
        self.assertEqual(resposta.status_code, 200)
        self.assertIn("javascript", resposta.headers["content-type"])
        self.assertEqual(resposta.headers.get("service-worker-allowed"), "/admin")
        self.assertIn("addEventListener", resposta.text)

    async def test_painel_js(self):
        resposta = await self.client.get("/admin/painel.js")
        self.assertEqual(resposta.status_code, 200)
        self.assertIn("serviceWorker", resposta.text)

    async def test_icones_png(self):
        for caminho in ("/admin/icon-192.png", "/admin/icon-512.png", "/admin/apple-touch-icon.png"):
            resposta = await self.client.get(caminho)
            self.assertEqual(resposta.status_code, 200, caminho)
            self.assertEqual(resposta.headers["content-type"], "image/png")
            self.assertTrue(resposta.content.startswith(b"\x89PNG"), caminho)

    async def test_pagina_de_login_tem_tags_pwa(self):
        resposta = await self.client.get("/admin")
        self.assertEqual(resposta.status_code, 200)
        html = resposta.text
        for trecho in (
            'rel="manifest"',
            'name="theme-color"',
            "/admin/painel.js",
            "apple-touch-icon",
            'name="viewport"',
            "@media (max-width: 760px)",
        ):
            self.assertIn(trecho, html)

    async def test_dashboard_autenticado_tem_tags_pwa(self):
        _usuario("admin-1", "dono@ex.com")
        login = await self.client.post(
            "/admin/login", data={"email": "dono@ex.com", "senha": SENHA}
        )
        self.assertEqual(login.status_code, 303)
        cookie = login.headers["set-cookie"].split(";")[0]
        painel = await self.client.get("/admin", headers={"Cookie": cookie})
        self.assertEqual(painel.status_code, 200)
        for trecho in ('rel="manifest"', "/admin/painel.js", "Saúde do sistema"):
            self.assertIn(trecho, painel.text)


if __name__ == "__main__":
    unittest.main()
