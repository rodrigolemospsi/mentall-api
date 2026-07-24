import asyncio
import json
import logging
import os
from datetime import datetime, timezone
from pathlib import Path

import requests

log = logging.getLogger("mentall.lembretes")

_LEMBRETES: dict[str, dict] = {}
_LOCK = asyncio.Lock()
_TAREFA: asyncio.Task | None = None
_ARQUIVO = Path(os.path.dirname(os.path.abspath(__file__))) / ".." / "data" / "lembretes.json"


def _carregar() -> None:
    global _LEMBRETES
    if not _ARQUIVO.exists():
        return
    try:
        with open(_ARQUIVO, "r", encoding="utf-8") as f:
            _LEMBRETES = json.load(f)
        log.info("Lembretes carregados: %d", len(_LEMBRETES))
    except Exception:
        _LEMBRETES = {}


def _persistir() -> None:
    _ARQUIVO.parent.mkdir(parents=True, exist_ok=True)
    try:
        with open(_ARQUIVO, "w", encoding="utf-8") as f:
            json.dump(_LEMBRETES, f, ensure_ascii=False, indent=2)
    except Exception as e:
        log.error("Erro ao persistir lembretes: %s", e)


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
                for rid, r in list(_LEMBRETES.items()):
                    try:
                        horario = datetime.fromisoformat(r["horario_envio"])
                        if horario <= agora and r.get("status") == "pendente":
                            sucesso = _enviar_whatsapp_direto(
                                r["telefone"], r["mensagem"]
                            )
                            if sucesso:
                                r["status"] = "enviado"
                                r["enviado_em"] = agora.isoformat()
                                enviados.append(rid)
                            else:
                                r["status"] = "falha"
                    except Exception as e:
                        log.error("Erro ao processar lembrete %s: %s", rid[:8], e)

                if enviados:
                    _persistir()
        except Exception as e:
            log.exception("Erro no scheduler de lembretes: %s", e)


def iniciar_scheduler() -> None:
    global _TAREFA
    _carregar()
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
                           horario_envio: str, canal: str = "whatsapp") -> str:
    rid = compromisso_id
    async with _LOCK:
        _LEMBRETES[rid] = {
            "id": rid,
            "compromisso_id": compromisso_id,
            "telefone": telefone,
            "mensagem": mensagem,
            "horario_envio": horario_envio,
            "canal": canal,
            "status": "pendente",
            "criado_em": datetime.now(timezone.utc).isoformat(),
            "enviado_em": None,
        }
        _persistir()
    log.info("Lembrete agendado: %s para %s", rid[:8], horario_envio)
    return rid


async def cancelar_lembrete(compromisso_id: str) -> bool:
    async with _LOCK:
        if compromisso_id in _LEMBRETES:
            del _LEMBRETES[compromisso_id]
            _persistir()
            log.info("Lembrete cancelado: %s", compromisso_id[:8])
            return True
    return False


def listar_lembretes() -> list[dict]:
    return list(_LEMBRETES.values())


_carregar()
