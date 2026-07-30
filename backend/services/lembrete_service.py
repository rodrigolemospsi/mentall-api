import asyncio
import logging
import os
from datetime import datetime, timezone

import requests

from services.db import executar

log = logging.getLogger("mentall.lembretes")

_LOCK = asyncio.Lock()
_TAREFA: asyncio.Task | None = None


def _enviar_whatsapp_direto(telefone: str, mensagem: str) -> bool:
    account_sid = os.getenv("TWILIO_ACCOUNT_SID", "")
    auth_token = os.getenv("TWILIO_AUTH_TOKEN", "")
    whatsapp_number = os.getenv("TWILIO_WHATSAPP_NUMBER", "")
    sandbox = os.getenv("TWILIO_WHATSAPP_SANDBOX", "true").strip().lower() == "true"

    if not account_sid or not auth_token:
        log.error("Twilio nao configurado. Impossivel enviar WhatsApp.")
        return False

    if sandbox:
        from_number = "whatsapp:+14155238886"
    elif whatsapp_number:
        from_number = f"whatsapp:{whatsapp_number}" if not whatsapp_number.startswith("whatsapp:") else whatsapp_number
    else:
        log.error("Numero WhatsApp nao configurado.")
        return False

    telefone_limpo = telefone.strip()
    if not telefone_limpo.startswith("+"):
        if telefone_limpo.startswith("55") and len(telefone_limpo) >= 12:
            telefone_limpo = "+" + telefone_limpo
        else:
            telefone_limpo = "+55" + telefone_limpo

    to_number = f"whatsapp:{telefone_limpo}"
    url = f"https://api.twilio.com/2010-04-01/Accounts/{account_sid}/Messages.json"
    data = {"From": from_number, "To": to_number, "Body": mensagem}

    try:
        resp = requests.post(url, data=data, auth=(account_sid, auth_token), timeout=30)
        if resp.status_code in (200, 201):
            log.info("Lembrete WhatsApp enviado: %s", telefone_limpo)
            return True
        else:
            log.error("Erro Twilio (%s): %s", resp.status_code, resp.text[:200])
            return False
    except Exception as e:
        log.exception("Erro ao enviar lembrete WhatsApp")
        return False


async def _scheduler() -> None:
    log.info("Scheduler de lembretes iniciado.")
    while True:
        try:
            await asyncio.sleep(30)
            agora = datetime.now(timezone.utc)
            enviados: list[str] = []

            async with _LOCK:
                cur = executar(
                    "SELECT * FROM lembretes WHERE status = 'pendente' AND horario_envio <= ?",
                    (agora.isoformat(),),
                )
                pendentes = cur.fetchall()

                for r in pendentes:
                    try:
                        sucesso = _enviar_whatsapp_direto(r["telefone"], r["mensagem"])
                        if sucesso:
                            executar(
                                "UPDATE lembretes SET status = 'enviado', enviado_em = ? WHERE id = ?",
                                (agora.isoformat(), r["id"]),
                            )
                            enviados.append(r["id"])
                        else:
                            executar(
                                "UPDATE lembretes SET status = 'falha' WHERE id = ?",
                                (r["id"],),
                            )
                    except Exception as e:
                        log.error("Erro ao processar lembrete %s: %s", r["id"][:8], e)

                if enviados:
                    cur.commit()
        except Exception as e:
            log.exception("Erro no scheduler de lembretes: %s", e)


def iniciar_scheduler() -> None:
    global _TAREFA
    if _TAREFA is None or _TAREFA.done():
        _TAREFA = asyncio.create_task(_scheduler())


async def parar_scheduler() -> None:
    global _TAREFA
    if _TAREFA and not _TAREFA.done():
        _TAREFA.cancel()
        try:
            await _TAREFA
        except asyncio.CancelledError:
            pass


async def agendar_lembrete(compromisso_id: str, telefone: str, mensagem: str,
                           horario_envio: str, canal: str = "whatsapp",
                           owner_id: str = "") -> str:
    rid = compromisso_id
    async with _LOCK:
        executar(
            "INSERT OR REPLACE INTO lembretes (id, compromisso_id, telefone, mensagem, horario_envio, canal, status, owner_id, criado_em) "
            "VALUES (?, ?, ?, ?, ?, ?, 'pendente', ?, ?)",
            (rid, compromisso_id, telefone, mensagem, horario_envio, canal, owner_id, datetime.now(timezone.utc).isoformat()),
        ).commit()
    log.info("Lembrete agendado: %s para %s", rid[:8], horario_envio)
    return rid


async def cancelar_lembrete(compromisso_id: str) -> bool:
    async with _LOCK:
        cur = executar("DELETE FROM lembretes WHERE compromisso_id = ?", (compromisso_id,))
        cur.commit()
        deletado = cur.rowcount > 0
        if deletado:
            log.info("Lembrete cancelado: %s", compromisso_id[:8])
        return deletado


def listar_lembretes() -> list[dict]:
    cur = executar("SELECT * FROM lembretes")
    return cur.fetchall()
