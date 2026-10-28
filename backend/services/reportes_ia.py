"""Registro de reportes de saída de IA (item 3.4 do checklist de publicação).

O Google Play exige um caminho in-app para reportar conteúdo gerado por IA.
Este módulo guarda só o motivo e a observação opcional — o relato clínico e a
síntese NÃO são enviados nem armazenados por este fluxo (LGPD: minimização).
"""
import logging
import uuid
from datetime import datetime, timezone

from models.schemas import MOTIVOS_REPORTE_IA
from services.db import executar

log = logging.getLogger("mentall.reportes_ia")

TAMANHO_MAX_DETALHE = 500


def registrar_reporte(
    *,
    owner_id: str,
    sessao_id: str,
    motivo: str,
    detalhe: str = "",
    provedor: str = "",
) -> str:
    """Grava o reporte e devolve o protocolo (id) para exibir ao profissional."""
    motivo_normalizado = (motivo or "").strip().lower()
    if motivo_normalizado not in MOTIVOS_REPORTE_IA:
        raise ValueError(
            "motivo deve ser um dos permitidos: " + ", ".join(MOTIVOS_REPORTE_IA)
        )
    protocolo = uuid.uuid4().hex
    criado_em = datetime.now(timezone.utc).isoformat()
    executar(
        "INSERT INTO reportes_ia "
        "(id, owner_id, sessao_id, motivo, detalhe, provedor, criado_em) "
        "VALUES (?, ?, ?, ?, ?, ?, ?)",
        (
            protocolo,
            (owner_id or "").strip()[:100],
            (sessao_id or "").strip()[:100],
            motivo_normalizado,
            (detalhe or "").strip()[:TAMANHO_MAX_DETALHE],
            (provedor or "").strip()[:30],
            criado_em,
        ),
    ).commit()
    log.warning(
        "Reporte de saída de IA registrado: motivo=%s sessao=%s protocolo=%s",
        motivo_normalizado,
        (sessao_id or "")[:8],
        protocolo,
    )
    return protocolo


def contar_reportes(owner_id: str = "") -> int:
    """Quantidade de reportes do profissional (ou total) — apoio a testes/painel."""
    if owner_id:
        row = executar(
            "SELECT COUNT(*) AS n FROM reportes_ia WHERE owner_id = ?", (owner_id,)
        ).fetchone()
    else:
        row = executar("SELECT COUNT(*) AS n FROM reportes_ia").fetchone()
    return int(row["n"]) if row else 0
