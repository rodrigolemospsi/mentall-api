"""Registro de reportes de saída de IA (item 3.4 do checklist de publicação).

O Google Play exige um caminho in-app para reportar conteúdo gerado por IA.
Este módulo guarda só o motivo e a observação opcional — o relato clínico e a
síntese NÃO são enviados nem armazenados por este fluxo (LGPD: minimização).
"""
import logging
import uuid
from datetime import datetime, timedelta, timezone

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


# Rotulos de apresentacao (painel). A chave e o valor aceito pelo backend.
MOTIVO_LABELS = {
    "conteudo_incorreto": "Conteudo incorreto/inventado",
    "tom_inadequado": "Tom/linguagem inadequada",
    "dado_sensivel": "Exposicao de dado sensivel",
    "conteudo_ofensivo": "Conteudo ofensivo/discriminatorio",
    "outro": "Outro problema",
}


def resumo_reportes() -> dict:
    """Contagens para os cards do painel: total, ultimos 7 dias e por motivo."""
    corte_7d = (datetime.now(timezone.utc) - timedelta(days=7)).isoformat()
    linha = executar(
        "SELECT COUNT(*) AS n FROM reportes_ia WHERE criado_em >= ?", (corte_7d,)
    ).fetchone()
    por_motivo = {
        str(item["motivo"]): int(item["n"] or 0)
        for item in executar(
            "SELECT motivo, COUNT(*) AS n FROM reportes_ia GROUP BY motivo"
        ).fetchall()
    }
    return {
        "total": contar_reportes(),
        "ultimos_7d": int(linha["n"] or 0) if linha else 0,
        "por_motivo": por_motivo,
    }


def listar_reportes(motivo: str = "", limite: int = 100) -> list:
    """Reportes para o painel - so metadados (sem relato/sintese)."""
    motivo = (motivo or "").strip().lower()
    if motivo not in MOTIVOS_REPORTE_IA:
        motivo = ""
    limite = max(1, min(200, int(limite)))
    sql = (
        "SELECT r.id, r.owner_id, r.sessao_id, r.motivo, r.detalhe, r.provedor, "
        "r.criado_em, u.email AS dono_email, u.nome AS dono_nome "
        "FROM reportes_ia r LEFT JOIN usuarios u ON u.id = r.owner_id "
    )
    params: tuple = ()
    if motivo:
        sql += "WHERE r.motivo = ? "
        params = (motivo,)
    sql += "ORDER BY r.criado_em DESC LIMIT ?"
    return executar(sql, params + (limite,)).fetchall()
