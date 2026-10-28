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
    modelo: str = "",
    prompt_versao: str = "",
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
        "(id, owner_id, sessao_id, motivo, detalhe, provedor, modelo, "
        "prompt_versao, criado_em) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (
            protocolo,
            (owner_id or "").strip()[:100],
            (sessao_id or "").strip()[:100],
            motivo_normalizado,
            (detalhe or "").strip()[:TAMANHO_MAX_DETALHE],
            (provedor or "").strip()[:30],
            (modelo or "").strip()[:60],
            (prompt_versao or "").strip()[:24],
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

# Templates de devolutiva para agilizar o atendimento (texto editavel no painel).
TEMPLATES_DEVOLUTIVA = {
    "conteudo_incorreto": (
        "Ola! Revisamos o relato sobre a sintese gerada pela IA. Ajustamos as "
        "instrucoes do modelo para reduzir conteudo incorreto ou inventado. "
        "Obrigado pelo retorno - ele ajuda a melhorar o sistema."
    ),
    "tom_inadequado": (
        "Ola! Revisamos o tom da sintese e ajustamos as instrucoes da IA para "
        "manter linguagem clinica, respeitosa e adequada. Obrigado pelo retorno."
    ),
    "dado_sensivel": (
        "Ola! Tratamos com prioridade o relato sobre dado sensivel. Reforcamos "
        "as instrucoes da IA para nao expor informacoes pessoais no texto gerado. "
        "Obrigado pelo retorno."
    ),
    "conteudo_ofensivo": (
        "Ola! Revisamos o relato sobre conteudo ofensivo e ajustamos as "
        "instrucoes da IA. Casos assim sao tratados com prioridade. Obrigado "
        "por sinalizar."
    ),
    "outro": (
        "Ola! Revisamos o relato enviado sobre a sintese gerada pela IA e "
        "registramos o retorno para melhoria continua do sistema. Obrigado."
    ),
}

# Workflow de resolucao (painel do dono)
STATUS_REPORTE = ("aberto", "em_analise", "resolvido", "descartado")
STATUS_LABELS = {
    "aberto": "Aberto",
    "em_analise": "Em analise",
    "resolvido": "Resolvido",
    "descartado": "Descartado",
}
STATUS_EM_ABERTO = ("aberto", "em_analise")
STATUS_FINAIS = ("resolvido", "descartado")
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
DIAS_AGING = 7


def _corte(dias: int) -> str:
    return (datetime.now(timezone.utc) - timedelta(days=dias)).isoformat()


def resumo_reportes() -> dict:
    """Contagens para os cards: total, janelas, motivo, status e aging."""
    corte_7d = _corte(7)
    linha = executar(
        "SELECT "
        "(SELECT COUNT(*) FROM reportes_ia) AS total, "
        "(SELECT COUNT(*) FROM reportes_ia WHERE criado_em >= ?) AS ultimos_7d, "
        "(SELECT COUNT(*) FROM reportes_ia WHERE status IN ('aberto','em_analise')) AS abertos, "
        "(SELECT COUNT(*) FROM reportes_ia WHERE status IN ('aberto','em_analise') "
        " AND criado_em < ?) AS abertos_7d, "
        "(SELECT COUNT(*) FROM reportes_ia WHERE status IN ('resolvido','descartado') "
        " AND resolvido_em >= ?) AS resolvidos_7d",
        (corte_7d, corte_7d, corte_7d),
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
    tempo_medio = _tempo_medio_resolucao_horas()
    return {
        "total": int(linha["total"] or 0) if linha else 0,
        "ultimos_7d": int(linha["ultimos_7d"] or 0) if linha else 0,
        "abertos": int(linha["abertos"] or 0) if linha else 0,
        "abertos_7d": int(linha["abertos_7d"] or 0) if linha else 0,
        "resolvidos_7d": int(linha["resolvidos_7d"] or 0) if linha else 0,
        "tempo_medio_resolucao_horas": tempo_medio,
        "por_motivo": por_motivo,
        "por_status": por_status,
    }


def _tempo_medio_resolucao_horas() -> float | None:
    linhas = executar(
        "SELECT criado_em, resolvido_em FROM reportes_ia "
        "WHERE resolvido_em != '' AND status IN ('resolvido','descartado')"
    ).fetchall()
    duracoes = []
    for linha in linhas:
        try:
            inicio = datetime.fromisoformat(str(linha["criado_em"]))
            fim = datetime.fromisoformat(str(linha["resolvido_em"]))
        except ValueError:
            continue
        if inicio.tzinfo is None:
            inicio = inicio.replace(tzinfo=timezone.utc)
        if fim.tzinfo is None:
            fim = fim.replace(tzinfo=timezone.utc)
        horas = (fim - inicio).total_seconds() / 3600
        if horas >= 0:
            duracoes.append(horas)
    if not duracoes:
        return None
    return round(sum(duracoes) / len(duracoes), 1)


def listar_reportes(
    motivo: str = "",
    status: str = "",
    periodo_dias: int = 0,
    atrasados: bool = False,
    limite: int = 100,
) -> list:
    """Reportes para o painel - so metadados (sem relato/sintese)."""
    motivo = (motivo or "").strip().lower()
    if motivo not in MOTIVOS_REPORTE_IA:
        motivo = ""
    status = (status or "").strip().lower()
    if status not in STATUS_REPORTE:
        status = ""
    limite = max(1, min(200, int(limite)))
    clausulas, params = [], []
    if motivo:
        clausulas.append("r.motivo = ?")
        params.append(motivo)
    if status:
        clausulas.append("r.status = ?")
        params.append(status)
    try:
        periodo_dias = int(periodo_dias)
    except (TypeError, ValueError):
        periodo_dias = 0
    if periodo_dias in (7, 30, 90):
        clausulas.append("r.criado_em >= ?")
        params.append(_corte(periodo_dias))
    if atrasados:
        clausulas.append("r.status IN ('aberto','em_analise')")
        clausulas.append("r.criado_em < ?")
        params.append(_corte(DIAS_AGING))
    sql = (
        "SELECT r.id, r.owner_id, r.sessao_id, r.motivo, r.detalhe, r.provedor, "
        "r.modelo, r.prompt_versao, r.criado_em, r.status, r.severidade, "
        "r.resolvido_em, r.resolvido_por, r.devolutiva_enviada_em, r.atualizado_em, "
        "u.email AS dono_email, u.nome AS dono_nome "
        "FROM reportes_ia r LEFT JOIN usuarios u ON u.id = r.owner_id "
    )
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
    finalizado = status in STATUS_FINAIS
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


def marcar_em_analise(reporte_id: str, por: str = "") -> bool:
    """Move um reporte 'aberto' para 'em análise' quando o admin o abre."""
    agora = datetime.now(timezone.utc).isoformat()
    cursor = executar(
        "UPDATE reportes_ia SET status = 'em_analise', atualizado_em = ? "
        "WHERE id = ? AND status = 'aberto'",
        (agora, reporte_id),
    )
    alterado = cursor.rowcount
    cursor.commit()
    if alterado:
        log.info(
            "Reporte de IA %s movido para em_analise ao abrir (por=%s)",
            reporte_id[:8],
            (por or "-")[:40],
        )
    return alterado > 0


def registrar_envio_devolutiva(reporte_id: str, enviado: bool, erro: str = "") -> None:
    """Guarda o resultado do envio da devolutiva por e-mail ao profissional."""
    agora = datetime.now(timezone.utc).isoformat()
    executar(
        "UPDATE reportes_ia SET devolutiva_enviada_em = ?, devolutiva_envio_erro = ? "
        "WHERE id = ?",
        (agora if enviado else "", "" if enviado else (erro or "")[:300], reporte_id),
    ).commit()


def atualizar_status_lote(ids: list, status: str, por: str = "") -> int:
    """Muda o status de varios reportes de uma vez (acoes em lote do painel)."""
    status = (status or "").strip().lower()
    if status not in ("aberto", "em_analise", "descartado"):
        raise ValueError(
            "acao em lote invalida: use aberto, em_analise ou descartado"
        )
    ids = [str(i).strip() for i in (ids or []) if str(i).strip()][:200]
    if not ids:
        return 0
    agora = datetime.now(timezone.utc).isoformat()
    finalizado = status == "descartado"
    marcadores = ",".join("?" for _ in ids)
    cursor = executar(
        "UPDATE reportes_ia SET status = ?, resolvido_por = ?, resolvido_em = ?, "
        f"atualizado_em = ? WHERE id IN ({marcadores})",
        (
            status,
            (por or "").strip()[:200] if finalizado else "",
            agora if finalizado else "",
            agora,
            *ids,
        ),
    )
    alteradas = cursor.rowcount
    cursor.commit()
    log.warning("Reportes de IA em lote: status=%s em %d registro(s)", status, alteradas)
    return alteradas


def metricas_dashboard() -> dict:
    """Métricas de qualidade da IA para o dashboard (reportes por semana/modelo)."""
    resumo = resumo_reportes()
    corte_56d = _corte(56)
    linhas = executar(
        "SELECT criado_em, status FROM reportes_ia WHERE criado_em >= ?", (corte_56d,)
    ).fetchall()
    semanas = []
    agora = datetime.now(timezone.utc)
    for indice in range(7, -1, -1):
        inicio = agora - timedelta(days=7 * (indice + 1))
        fim = agora - timedelta(days=7 * indice)
        total = 0
        resolvidos = 0
        for linha in linhas:
            try:
                criado = datetime.fromisoformat(str(linha["criado_em"]))
            except ValueError:
                continue
            if criado.tzinfo is None:
                criado = criado.replace(tzinfo=timezone.utc)
            if inicio <= criado < fim:
                total += 1
                if str(linha["status"]) in STATUS_FINAIS:
                    resolvidos += 1
        semanas.append((f"{inicio.strftime('%d/%m')}", total, resolvidos))
    por_modelo = [
        (str(item["modelo"] or "nao informado"), int(item["n"] or 0))
        for item in executar(
            "SELECT modelo, COUNT(*) AS n FROM reportes_ia "
            "GROUP BY modelo ORDER BY n DESC LIMIT 6"
        ).fetchall()
    ]
    por_causa = [
        (CAUSAS_RAIZ.get(str(item["causa_raiz"]), str(item["causa_raiz"])), int(item["n"] or 0))
        for item in executar(
            "SELECT causa_raiz, COUNT(*) AS n FROM reportes_ia "
            "WHERE causa_raiz != '' GROUP BY causa_raiz ORDER BY n DESC LIMIT 6"
        ).fetchall()
    ]
    return {
        "resumo": resumo,
        "serie_semanas": semanas,
        "por_modelo": por_modelo,
        "por_causa": por_causa,
    }
