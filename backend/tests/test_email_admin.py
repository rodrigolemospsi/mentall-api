"""E-mail (Mailu) no painel do dono — serviço, UI e rotas (Fase 4, 22/10/2026)."""
import unittest
from unittest.mock import patch

import httpx

import admin_ui
import main
from services import db, email_admin
from services.usuarios import hash_senha

SENHA = "SenhaForte123"


def _criar_usuario(uid, email, role, status="ativo"):
    db.executar(
        "INSERT INTO usuarios (id, email, password_hash, nome, plano, status, role, criado_em) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        (uid, email, hash_senha(SENHA), "Nome", "gratis", status, role, "2026-01-01T00:00:00+00:00"),
    ).commit()


class EmailAdminNaoConfiguradoTests(unittest.TestCase):
    def test_sem_token_nao_esta_configurado(self):
        with patch.object(email_admin, "token", return_value=""):
            self.assertFalse(email_admin.configurado())
            with self.assertRaises(email_admin.EmailAdminErro):
                email_admin._requisitar("GET", "/user")

    def test_dominio_padrao_quando_env_ausente(self):
        with patch.dict("os.environ", {}, clear=True):
            self.assertEqual(email_admin.dominio(), "mentallpro.com.br")


class EmailAdminServiceTests(unittest.TestCase):
    def setUp(self):
        self.patcher = patch.object(email_admin, "_requisitar")
        self.req = self.patcher.start()
        self.addCleanup(self.patcher.stop)

    def test_listar_caixas_filtra_dominio_e_ordena_admin_primeiro(self):
        self.req.return_value = [
            {"email": "zeta@mentallpro.com.br", "displayed_name": "Zeta", "quota_bytes": 2 * 1024**3},
            {"email": "contato@mentallpro.com.br", "displayed_name": "Contato",
             "quota_bytes": 3 * 1024**3, "global_admin": True},
            {"email": "fora@outrodominio.com", "displayed_name": "Fora", "quota_bytes": 1024**3},
        ]
        caixas = email_admin.listar_caixas()
        self.assertEqual(
            [c["email"] for c in caixas],
            ["contato@mentallpro.com.br", "zeta@mentallpro.com.br"],
        )
        self.assertTrue(caixas[0]["admin"])
        self.assertEqual(caixas[0]["cota_gb"], 3)
        self.assertEqual(caixas[1]["cota_gb"], 2)

    def test_listar_aliases_normaliza_destinos(self):
        self.req.return_value = [
            {"email": "financeiro@mentallpro.com.br", "destination": ["Anderson@MentAllPro.com.br"]},
            "formato-invalido",
        ]
        aliases = email_admin.listar_aliases()
        self.assertEqual(len(aliases), 1)
        self.assertEqual(aliases[0]["destinos"], ["anderson@mentallpro.com.br"])

    def test_criar_caixa_normaliza_e_monta_payload(self):
        with patch.object(email_admin, "gerar_senha", return_value="SenhaTemp12345"):
            email, senha = email_admin.criar_caixa("Anderson", "  Anderson Lemos  ", 3)
        self.assertEqual(email, "anderson@mentallpro.com.br")
        self.assertEqual(senha, "SenhaTemp12345")
        metodo, caminho = self.req.call_args.args
        corpo = self.req.call_args.kwargs["json"]
        self.assertEqual((metodo, caminho), ("POST", "/user"))
        self.assertEqual(corpo["email"], "anderson@mentallpro.com.br")
        self.assertEqual(corpo["quota_bytes"], 3 * 1024**3)
        self.assertEqual(corpo["displayed_name"], "Anderson Lemos")
        self.assertFalse(corpo["global_admin"])
        self.assertTrue(corpo["enabled"])

    def test_criar_caixa_recusa_prefixo_invalido(self):
        with self.assertRaises(email_admin.EmailAdminErro):
            email_admin.criar_caixa("anderson@x", "x", 2)
        with self.assertRaises(email_admin.EmailAdminErro):
            email_admin.criar_caixa("Anders on", "x", 2)

    def test_cota_fora_da_faixa_e_limitada(self):
        with patch.object(email_admin, "gerar_senha", return_value="x" * 14):
            email_admin.criar_caixa("teste", "", 99)
        self.assertEqual(self.req.call_args.kwargs["json"]["quota_bytes"], 10 * 1024**3)

    def test_definir_status_e_exclusao_usam_metodos_corretos(self):
        email_admin.definir_status("anderson@mentallpro.com.br", False)
        self.assertEqual(self.req.call_args.args, ("PATCH", "/user/anderson%40mentallpro.com.br"))
        self.assertEqual(self.req.call_args.kwargs["json"], {"enabled": False})
        email_admin.excluir_caixa("anderson@mentallpro.com.br")
        self.assertEqual(self.req.call_args.args, ("DELETE", "/user/anderson%40mentallpro.com.br"))

    def test_gerar_senha_temporaria_redefine(self):
        with patch.object(email_admin, "gerar_senha", return_value="NovaSenha123456"):
            senha = email_admin.gerar_senha_temporaria("anderson@mentallpro.com.br")
        self.assertEqual(senha, "NovaSenha123456")
        self.assertEqual(self.req.call_args.args[0], "PATCH")
        self.assertEqual(self.req.call_args.kwargs["json"], {"raw_password": "NovaSenha123456"})

    def test_alias_recusa_destino_fora_do_dominio(self):
        with self.assertRaises(email_admin.EmailAdminErro):
            email_admin.criar_alias("financeiro", "pessoa@gmail.com")
        email_admin.criar_alias("financeiro", "anderson@mentallpro.com.br")
        corpo = self.req.call_args.kwargs["json"]
        self.assertEqual(corpo["email"], "financeiro@mentallpro.com.br")
        self.assertEqual(corpo["destination"], ["anderson@mentallpro.com.br"])


class EmailUiTests(unittest.TestCase):
    def test_lista_caixas_e_escapa_nome(self):
        html = admin_ui.pagina_email(
            [{"email": "anderson@mentallpro.com.br", "nome": "<script>alert(1)</script>",
              "cota_gb": 3, "ativo": True, "admin": False}],
            [{"email": "financeiro@mentallpro.com.br",
              "destinos": ["anderson@mentallpro.com.br"]}],
            dominio="mentallpro.com.br",
        )
        self.assertIn("anderson@mentallpro.com.br", html)
        self.assertIn("financeiro@mentallpro.com.br", html)
        self.assertNotIn("<script>alert(1)</script>", html)
        self.assertIn("&lt;script&gt;", html)

    def test_sem_configuracao_mostra_aviso(self):
        html = admin_ui.pagina_email([], [], "mentallpro.com.br", configurado=False)
        self.assertIn("Integração não configurada", html)

    def test_senha_gerada_aparece_uma_vez(self):
        html = admin_ui.pagina_email(
            [], [], "mentallpro.com.br",
            credenciais=("teste@mentallpro.com.br", "SenhaTemp12345"),
        )
        self.assertIn("SenhaTemp12345", html)
        self.assertIn("Guarde a senha agora", html)

    def test_caixa_admin_nao_oferece_desativar_excluir(self):
        html = admin_ui.pagina_email(
            [{"email": "contato@mentallpro.com.br", "nome": "Contato", "cota_gb": 3,
              "ativo": True, "admin": True}],
            [], "mentallpro.com.br",
        )
        self.assertIn("conta administrativa protegida", html)
        self.assertNotIn("/admin/email/excluir", html)

    def test_confirmacao_de_exclusao_exige_post(self):
        html = admin_ui.pagina_confirmar_exclusao(
            {"email": "teste@mentallpro.com.br", "nome": "Teste"})
        self.assertIn('name="confirmar" value="sim"', html)
        self.assertIn('method="post" action="/admin/email/excluir"', html)


class EmailHttpTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        db.executar("DELETE FROM usuarios").commit()
        db.executar("DELETE FROM dispositivos").commit()
        db.executar("DELETE FROM eventos").commit()
        main._rate_limit_store.clear()
        _criar_usuario("admin-1", "dono@ex.com", "admin")
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=main.app),
            base_url="https://test.invalid",
            follow_redirects=False,
        )
        self.addAsyncCleanup(self.client.aclose)

    async def _entrar(self) -> str:
        """Faz login no painel e devolve o cookie pronto para o header."""
        login = await self.client.post(
            "/admin/login", data={"email": "dono@ex.com", "senha": SENHA})
        self.client.cookies.clear()  # usa o cookie só via header, como o navegador faria
        return login.headers["set-cookie"].split(";")[0]

    async def test_sem_login_mostra_formulario(self):
        r = await self.client.get("/admin/email")
        self.assertEqual(r.status_code, 200)
        self.assertIn("Entrar", r.text)
        self.assertNotIn("Nova caixa", r.text)

    async def test_com_login_lista_caixas(self):
        cookie = await self._entrar()
        caixas = [{"email": "anderson@mentallpro.com.br", "nome": "Anderson",
                   "cota_gb": 3, "ativo": True, "admin": False}]
        with patch.object(email_admin, "listar_caixas", return_value=caixas), \
             patch.object(email_admin, "listar_aliases", return_value=[]):
            r = await self.client.get("/admin/email", headers={"Cookie": cookie})
        self.assertEqual(r.status_code, 200)
        self.assertIn("anderson@mentallpro.com.br", r.text)
        self.assertIn("Nova caixa", r.text)

    async def test_criar_caixa_exibe_senha_uma_vez(self):
        cookie = await self._entrar()
        with patch.object(email_admin, "listar_caixas", return_value=[]), \
             patch.object(email_admin, "listar_aliases", return_value=[]), \
             patch.object(
                 email_admin,
                 "criar_caixa",
                 return_value=("teste@mentallpro.com.br", "SenhaTemp12345"),
             ):
            r = await self.client.post(
                "/admin/email/criar",
                data={"prefixo": "teste", "nome": "Teste", "cota_gb": "2"},
                headers={"Cookie": cookie},
            )
        self.assertEqual(r.status_code, 200)
        self.assertIn("SenhaTemp12345", r.text)
        self.assertIn("criada", r.text)

    async def test_desativar_redireciona(self):
        cookie = await self._entrar()
        caixas = [{"email": "anderson@mentallpro.com.br", "nome": "Anderson",
                   "cota_gb": 3, "ativo": True, "admin": False}]
        with patch.object(email_admin, "listar_caixas", return_value=caixas), \
             patch.object(email_admin, "definir_status") as definir:
            r = await self.client.post(
                "/admin/email/status",
                data={"email": "anderson@mentallpro.com.br", "ativo": "0"},
                headers={"Cookie": cookie},
            )
        self.assertEqual(r.status_code, 303)
        self.assertIn("/admin/email?msg=", r.headers["location"])
        definir.assert_called_once_with("anderson@mentallpro.com.br", False)

    async def test_nao_desativa_caixa_administrativa(self):
        cookie = await self._entrar()
        caixas = [{"email": "contato@mentallpro.com.br", "nome": "Contato",
                   "cota_gb": 3, "ativo": True, "admin": True}]
        with patch.object(email_admin, "listar_caixas", return_value=caixas), \
             patch.object(email_admin, "definir_status") as definir:
            r = await self.client.post(
                "/admin/email/status",
                data={"email": "contato@mentallpro.com.br", "ativo": "0"},
                headers={"Cookie": cookie},
            )
        self.assertEqual(r.status_code, 200)
        self.assertIn("não pode ser desativada", r.text)
        definir.assert_not_called()

    async def test_alias_exige_destino_do_dominio(self):
        cookie = await self._entrar()
        r = await self.client.post(
            "/admin/email/alias/criar",
            data={"prefixo": "financeiro", "destino_email": "pessoa@gmail.com"},
            headers={"Cookie": cookie},
        )
        self.assertEqual(r.status_code, 200)
        self.assertIn("fora de @mentallpro.com.br", r.text)


if __name__ == "__main__":
    unittest.main()
