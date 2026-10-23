"""Notificações por WhatsApp de e-mails fora do SLA — Fase 5N.

Roda em background a cada N minutos (padrão 30) e envia um resumo via Wuzapi
quando há e-mails fora do SLA (suporte 4h, financeiro 24h por padrão).
Anti-spam: no máximo 1 notificação a cada `EMAIL_ALERTAS_COOLDOWN_HORAS` (6h).
"""
import asyncio
import logging
import os
from datetime import datetime, timedelta, timezone

from services import email_metricas
from services.db import executar
from services.lembrete_service import _enviar_whatsapp_via_wuzapi

log = logging.getLogger("mentall.email_alertas")

INTERVALO_MINUTOS = int(os.getenv("EMAIL_ALERTAS_INTERVALO_MINUTOS", "30"))
COOLDOWN_HORAS = float(os.getenv("EMAIL_ALERTAS_COOLDOWN_HORAS", "6"))

_TAREFA: asyncio.Task | None = None


def _owner_id() -> str:
    """Owner da instância Wuzapi (hoje há uma instância, do dono)."""
    try:
        linha = executar("SELECT owner_id FROM wuzapi_instancias LIMIT 1").fetchone()
        return str(linha["owner_id"]) if linha else ""
    except Exception:
        return ""


def _destino() -> str:
    return (os.getenv("EMAIL_ALERTA_WHATSAPP") or "").strip()


def _ultimo_envio_iso() -> str:
    try:
        linha = executar(
            "SELECT valor FROM email_alertas_estado WHERE chave = 'ultimo_envio'"
        ).fetchone()
        return str(linha["valor"]) if linha else ""
    except Exception:
        return ""


def _cooldown_ok(agora: datetime, ultimo_iso: str) -> bool:
    if not ultimo_iso:
        return True
    try:
        ultimo = datetime.fromisoformat(ultimo_iso)
    except (TypeError, ValueError):
        return True
    if ultimo.tzinfo is None:
        ultimo = ultimo.replace(tzinfo=timezone.utc)
    return agora - ultimo >= timedelta(hours=COOLDOWN_HORAS)


def _registrar_envio(agora: datetime) -> None:
    try:
        executar(
            "INSERT INTO email_alertas_estado (chave, valor, atualizado_em) "
            "VALUES ('ultimo_envio', ?, ?) "
            "ON CONFLICT(chave) DO UPDATE SET valor = excluded.valor, "
            "atualizado_em = excluded.atualizado_em",
            (agora.isoformat(), agora.isoformat()),
        ).commit()
    except Exception:
        log.exception("Falha ao registrar último alerta de e-mail")


def pendencias(metricas: dict | None = None) -> list[dict]:
    metricas = metricas or email_metricas.coletar(force=True)
    itens = []
    for item in metricas.get("por_endereco") or []:
        violacoes = int(item.get("violacoes_sla") or 0)
        if violacoes <= 0:
            continue
        itens.append({
            "endereco": str(item.get("endereco") or ""),
            "sla_horas": item.get("sla_horas"),
            "violacoes_sla": violacoes,
            "pendentes_sla": int(item.get("pendentes_sla") or 0),
        })
    return itens


def formatar_mensagem(itens: list[dict]) -> str:
    linhas = ["MentAll PRO — e-mails fora do SLA:"]
    for item in itens:
        partes = [f"{item['endereco']}: {int(item['violacoes_sla'])} fora do SLA"]
        sla = item.get("sla_horas")
        if sla:
            partes.append(f"(SLA {int(float(sla))}h)")
        if item.get("pendentes_sla"):
            partes.append(f"{int(item['pendentes_sla'])} sem resposta")
        linhas.append("• " + " ".join(partes))
    linhas.append("Painel: https://admin.mentallpro.com.br/admin/email")
    return "\n".join(linhas)


def notificar(force: bool = False) -> dict:
    """Envia resumo via WhatsApp se houver pendências e o cooldown permitir."""
    agora = datetime.now(timezone.utc)
    if not force and not _cooldown_ok(agora, _ultimo_envio_iso()):
        return {"enviado": False, "motivo": "cooldown"}

    itens = pendencias()
    if not itens:
        return {"enviado": False, "motivo": "sem pendências"}

    destino = _destino()
    owner = _owner_id()
    if not destino or not owner:
        return {"enviado": False, "motivo": "destino/owner não configurado"}

    mensagem = formatar_mensagem(itens)
    sucesso, _ = _enviar_whatsapp_via_wuzapi(owner, destino, mensagem)
    if sucesso:
        _registrar_envio(agora)
        log.info("Alerta de e-mails enviado no WhatsApp (%s pendência(s))", len(itens))
    else:
        log.warning("Falha ao enviar alerta de e-mails no WhatsApp")
    return {
        "enviado": sucesso,
        "motivo": "" if sucesso else "falha no envio",
        "itens": len(itens),
        "mensagem": mensagem,
    }


async def _loop() -> None:
    await asyncio.sleep(60)
    while True:
        try:
            resultado = await asyncio.to_thread(notificar)
            if resultado.get("enviado"):
                log.info("Alerta de e-mail enviado: %s pendência(s)", resultado.get("itens"))
        except Exception:
            log.exception("Erro no loop de alertas de e-mail")
        await asyncio.sleep(max(60, INTERVALO_MINUTOS * 60))


def iniciar_alertas_email() -> None:
    global _TAREFA
    if _TAREFA is None or _TAREFA.done():
        _TAREFA = asyncio.create_task(_loop())


async def parar_alertas_email() -> None:
    global _TAREFA
    if _TAREFA and not _TAREFA.done():
        _TAREFA.cancel()
        try:
            await _TAREFA
        except asyncio.CancelledError:
            pass
