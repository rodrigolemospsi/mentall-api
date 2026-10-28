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

# Workflow de resolucao (painel do dono)
STATUS_REPORTE = ("aberto", "em_analise", "resolvido", "descartado")
STATUS_LABELS = {
    "aberto": "Aberto",
    "em_analise": "Em analise",
    "resolvido": "Resolvido",
    "descartado": "Descartado",
}
SEVERIDADES = ("baixa", "media", "alta")
SEVERIDADE_LABELS = {"baixa": "Baixa", "media": "Media", "alta": "Alta"}
CAUSAS_RAIZ = {
    "prompt": "Prompt/persona da IA",
    "modelo": "Modelo/provedor de IA",
    "entrada_profissional": "Entrada do profissional",
    "expectativa": "Expectativa do profissional",
    "outro": "Outro",
}
CONTATO_CANAIS = {
    "whatsapp": "WhatsApp",
    "email": "E-mail",
    "telefone": "Telefone",
    "presencial": "Presencial",
    "outro": "Outro",
}
MUDANCAS_APLICADAS = {
    "prompt_ajustado": "Prompt ajustado",
    "modelo_trocado": "Modelo/provedor trocado",
    "correcao_dado": "Correcao de dado",
    "sem_mudanca": "Sem mudanca necessaria",
    "outro": "Outro",
}


def resumo_reportes() -> dict:
    """Contagens para os cards: total, ultimos 7 dias, por motivo e por status."""
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
    por_status = {
        str(item["status"] or "aberto"): int(item["n"] or 0)
        for item in executar(
            "SELECT status, COUNT(*) AS n FROM reportes_ia GROUP BY status"
        ).fetchall()
    }
    return {
        "total": contar_reportes(),
        "ultimos_7d": int(linha["n"] or 0) if linha else 0,
        "por_motivo": por_motivo,
        "por_status": por_status,
    }


def listar_reportes(motivo: str = "", status: str = "", limite: int = 100) -> list:
    """Reportes para o painel - so metadados (sem relato/sintese)."""
    motivo = (motivo or "").strip().lower()
    if motivo not in MOTIVOS_REPORTE_IA:
        motivo = ""
    status = (status or "").strip().lower()
    if status not in STATUS_REPORTE:
        status = ""
    limite = max(1, min(200, int(limite)))
    sql = (
        "SELECT r.id, r.owner_id, r.sessao_id, r.motivo, r.detalhe, r.provedor, "
        "r.criado_em, r.status, r.severidade, r.resolvido_em, r.atualizado_em, "
        "u.email AS dono_email, u.nome AS dono_nome "
        "FROM reportes_ia r LEFT JOIN usuarios u ON u.id = r.owner_id "
    )
    clausulas, params = [], []
    if motivo:
        clausulas.append("r.motivo = ?")
        params.append(motivo)
    if status:
        clausulas.append("r.status = ?")
        params.append(status)
    if clausulas:
        sql += "WHERE " + " AND ".join(clausulas) + " "
    sql += "ORDER BY r.criado_em DESC LIMIT ?"
    return executar(sql, tuple(params) + (limite,)).fetchall()


def obter_reporte(reporte_id: str) -> dict | None:
    """Um reporte com todos os campos de metadados e de resolucao."""
    return executar(
        "SELECT r.*, u.email AS dono_email, u.nome AS dono_nome "
        "FROM reportes_ia r LEFT JOIN usuarios u ON u.id = r.owner_id "
        "WHERE r.id = ?",
        (reporte_id,),
    ).fetchone()


def atualizar_resolucao(
    *,
    reporte_id: str,
    status: str,
    severidade: str = "media",
    causa_raiz: str = "",
    contato_feito: bool = False,
    contato_canal: str = "",
    contato_em: str = "",
    contato_resumo: str = "",
    devolutiva: str = "",
    como_ficou: str = "",
    mudanca_aplicada: str = "",
    resolvido_por: str = "",
) -> bool:
    """Salva o tratamento do reporte. Devolve False se o reporte nao existir."""
    status = (status or "").strip().lower()
    severidade = (severidade or "media").strip().lower()
    causa_raiz = (causa_raiz or "").strip().lower()
    contato_canal = (contato_canal or "").strip().lower()
    mudanca_aplicada = (mudanca_aplicada or "").strip().lower()

    if status not in STATUS_REPORTE:
        raise ValueError("status invalido: " + ", ".join(STATUS_REPORTE))
    if severidade not in SEVERIDADES:
        raise ValueError("severidade invalida: " + ", ".join(SEVERIDADES))
    if causa_raiz and causa_raiz not in CAUSAS_RAIZ:
        raise ValueError("causa_raiz invalida: " + ", ".join(CAUSAS_RAIZ))
    if contato_canal and contato_canal not in CONTATO_CANAIS:
        raise ValueError("contato_canal invalido: " + ", ".join(CONTATO_CANAIS))
    if mudanca_aplicada and mudanca_aplicada not in MUDANCAS_APLICADAS:
        raise ValueError(
            "mudanca_aplicada invalida: " + ", ".join(MUDANCAS_APLICADAS)
        )

    agora = datetime.now(timezone.utc).isoformat()
    finalizado = status in ("resolvido", "descartado")
    resolvido_em = agora if finalizado else ""
    resolvido_por = (resolvido_por or "").strip()[:200] if finalizado else ""
    cursor = executar(
        "UPDATE reportes_ia SET status = ?, severidade = ?, causa_raiz = ?, "
        "contato_feito = ?, contato_canal = ?, contato_em = ?, contato_resumo = ?, "
        "devolutiva = ?, como_ficou = ?, mudanca_aplicada = ?, resolvido_por = ?, "
        "resolvido_em = ?, atualizado_em = ? WHERE id = ?",
        (
            status,
            severidade,
            causa_raiz,
            1 if contato_feito else 0,
            contato_canal,
            (contato_em or "").strip()[:20],
            (contato_resumo or "").strip()[:1000],
            (devolutiva or "").strip()[:2000],
            (como_ficou or "").strip()[:2000],
            mudanca_aplicada,
            resolvido_por,
            resolvido_em,
            agora,
            reporte_id,
        ),
    )
    alteradas = cursor.rowcount
    cursor.commit()
    log.warning(
        "Reporte de IA %s atualizado: status=%s severidade=%s por=%s",
        reporte_id[:8],
        status,
        severidade,
        resolvido_por or "-",
    )
    return alteradas > 0
