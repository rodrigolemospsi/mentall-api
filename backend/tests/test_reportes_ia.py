"""Testes do reporte de saída de IA (item 3.4 do checklist de publicação).

Prova: o profissional consegue registrar um reporte com motivo válido; o
registro é gravado com owner/sessão/provedor; motivo fora da lista é recusado
(schema e serviço); o detalhe é limitado; campos extras são rejeitados.
Nenhum conteúdo clínico é recebido por este fluxo — só metadados.
"""
import os
import unittest

os.environ.setdefault("JWT_SECRET", "teste-segredo")
os.environ.setdefault("APP_PASSWORD_HASH", "teste-hash")
os.environ.setdefault("SMTP_HOST", "")
os.environ.setdefault("WUZAPI_BASE_URL", "")
os.environ.setdefault("TURSO_DATABASE_URL", "")
os.environ.setdefault("TURSO_AUTH_TOKEN", "")

from pydantic import ValidationError  # noqa: E402

from models.schemas import (  # noqa: E402
    MOTIVOS_REPORTE_IA,
    ReporteSinteseRequest,
)
from services import reportes_ia as mod  # noqa: E402
from services.db import executar  # noqa: E402

OWNER = "owner-reporte-teste"


class TestServicoReportesIa(unittest.TestCase):
    def setUp(self):
        executar("DELETE FROM reportes_ia").commit()

    def test_registra_e_devolve_protocolo(self):
        protocolo = mod.registrar_reporte(
            owner_id=OWNER,
            sessao_id="sessao-123",
            motivo="conteudo_incorreto",
            detalhe="Trecho inventado na sintese",
            provedor="openai",
        )
        self.assertEqual(len(protocolo), 32)
        linha = executar(
            "SELECT * FROM reportes_ia WHERE id = ?", (protocolo,)
        ).fetchone()
        self.assertEqual(linha["owner_id"], OWNER)
        self.assertEqual(linha["sessao_id"], "sessao-123")
        self.assertEqual(linha["motivo"], "conteudo_incorreto")
        self.assertEqual(linha["detalhe"], "Trecho inventado na sintese")
        self.assertEqual(linha["provedor"], "openai")
        self.assertTrue(linha["criado_em"])
        self.assertEqual(mod.contar_reportes(OWNER), 1)
        self.assertEqual(mod.contar_reportes(), 1)

    def test_normaliza_motivo_e_limita_detalhe(self):
        protocolo = mod.registrar_reporte(
            owner_id=OWNER,
            sessao_id="sessao-456",
            motivo="  CONTEUDO_OFENSIVO  ",
            detalhe="x" * (mod.TAMANHO_MAX_DETALHE + 200),
        )
        linha = executar(
            "SELECT motivo, detalhe FROM reportes_ia WHERE id = ?", (protocolo,)
        ).fetchone()
        self.assertEqual(linha["motivo"], "conteudo_ofensivo")
        self.assertEqual(len(linha["detalhe"]), mod.TAMANHO_MAX_DETALHE)

    def test_motivo_invalido_recusado_sem_gravar(self):
        with self.assertRaises(ValueError):
            mod.registrar_reporte(
                owner_id=OWNER, sessao_id="sessao-1", motivo="motivo_inventado"
            )
        self.assertEqual(mod.contar_reportes(), 0)

    def test_campos_de_texto_longo_sao_truncados_no_banco(self):
        protocolo = mod.registrar_reporte(
            owner_id="o" * 300,
            sessao_id="s" * 300,
            motivo="outro",
            provedor="p" * 60,
        )
        linha = executar(
            "SELECT owner_id, sessao_id, provedor FROM reportes_ia WHERE id = ?",
            (protocolo,),
        ).fetchone()
        self.assertEqual(len(linha["owner_id"]), 100)
        self.assertEqual(len(linha["sessao_id"]), 100)
        self.assertEqual(len(linha["provedor"]), 30)


class TestSchemaReporteSintese(unittest.TestCase):
    def test_aceita_motivo_permitido(self):
        req = ReporteSinteseRequest(
            sessao_id="sessao-1", motivo="tom_inadequado", detalhe="ok"
        )
        self.assertEqual(req.motivo, "tom_inadequado")

    def test_rejeita_motivo_desconhecido(self):
        with self.assertRaises(ValidationError):
            ReporteSinteseRequest(sessao_id="sessao-1", motivo="nao_existe")

    def test_rejeita_campo_extra(self):
        with self.assertRaises(ValidationError):
            ReporteSinteseRequest(
                sessao_id="sessao-1", motivo="outro", relato_clinico="PII"
            )

    def test_rejeita_detalhe_acima_do_limite(self):
        with self.assertRaises(ValidationError):
            ReporteSinteseRequest(
                sessao_id="sessao-1", motivo="outro", detalhe="x" * 501
            )

    def test_lista_de_motivos_estavel(self):
        self.assertEqual(len(MOTIVOS_REPORTE_IA), 5)


if __name__ == "__main__":
    unittest.main()
