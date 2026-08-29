import asyncio
import logging
import os
import re
import time
import uuid
from datetime import datetime, timezone, timedelta

import requests

from services.db import executar

log = logging.getLogger("mentall.lembretes")

_LOCK = asyncio.Lock()
_TAREFA: asyncio.Task | None = None

JANELA_RETRY_MINUTOS = int(os.getenv("JANELA_RETRY_LEMBRETES_MINUTOS", "60"))

# Watchdog de reconexao do wuzapi: intervalo minimo entre tentativas
# de reconexao (segundos) para nao martelar o wuzapi/WhatsApp se ficar fora.
_WUZAPI_RECONNECT_COOLDOWN_SECONDS = int(
    os.getenv("WUZAPI_RECONNECT_COOLDOWN_SECONDS", "300")
)
_ultima_reconexao_wuzapi = 0.0


def _deve_continuar_tentando(horario_envio: str, agora: datetime) -> bool:
    """True se o lembrete ainda estiver dentro da janela de retry.

    Horario previsto + janela configurada. Apos a janela, marca como falha."""
    try:
        horario = datetime.fromisoformat(horario_envio.replace("Z", "+00:00"))
        limite = horario + timedelta(minutes=JANELA_RETRY_MINUTOS)
        return agora <= limite
    except (ValueError, TypeError):
        return False


def _mascarar(valor: str) -> str:
    """Mascara PII em logs: mantém apenas os últimos 4 caracteres (ex: *8347)."""
    valor = str(valor).strip()
    if len(valor) <= 4:
        return "****"
    return "*" * (len(valor) - 4) + valor[-4:]


def _normalizar_numero_whatsapp(telefone: str) -> str:
    """Converte um telefone brasileiro para o formato internacional sem '+'
    exigido pelo wuzapi (ex: '(11) 99999-9999' -> '5511999999999')."""
    digits = re.sub(r"\D", "", telefone)
    if digits.startswith("55"):
        return digits
    return "55" + digits


def _resolver_token_wuzapi(owner_id: str) -> str:
    """Retorna o token da instancia wuzapi do profissional. No primeiro momento,
    usa a env WUZAPI_TOKEN (instancia unica). Com varios profissionais, a tabela
    wuzapi_instancias (owner_id -> token) passa a ter precedencia."""
    token_env = os.getenv("WUZAPI_TOKEN", "").strip()
    if token_env:
        return token_env
    try:
        cur = executar(
            "SELECT wuzapi_token FROM wuzapi_instancias WHERE owner_id = ?",
            (owner_id,),
        )
        row = cur.fetchone()
        return (row["wuzapi_token"] or "") if row else ""
    except Exception:
        return ""


def salvar_instancia_wuzapi(owner_id: str, token: str, user_id: int = 0,
                            conectado: bool = True) -> None:
    executar(
        "INSERT OR REPLACE INTO wuzapi_instancias "
        "(owner_id, wuzapi_token, wuzapi_user_id, conectado, atualizado_em) "
        "VALUES (?, ?, ?, ?, ?)",
        (owner_id, token, user_id, 1 if conectado else 0,
         datetime.now(timezone.utc).isoformat()),
    ).commit()
    log.info("Instancia wuzapi salva para owner %s", owner_id[:8])


def _enviar_whatsapp_via_wuzapi(owner_id: str, telefone: str, mensagem: str) -> tuple[bool, str | None]:
    """Envia o WhatsApp via wuzapi.

    Retorna (sucesso, mensagem_id): mensagem_id e o Id da mensagem retornado
    pelo wuzapi (None se o envio falhar). O Id permite correlacionar os
    recebimentos (ReadReceipt) com o lembrete via webhook."""
    base_url = os.getenv("WUZAPI_BASE_URL", "").strip().rstrip("/")
    if not base_url:
        log.error("WUZAPI_BASE_URL nao configurado. Impossivel enviar WhatsApp.")
        return False, None

    token = _resolver_token_wuzapi(owner_id)
    if not token:
        log.error("Wuzapi não conectado para owner %s. Envio ignorado.", owner_id[:8])
        return False, None

    numero = _normalizar_numero_whatsapp(telefone)

    try:
        resp = requests.post(
            f"{base_url}/chat/send/text",
            headers={"token": token, "Content-Type": "application/json"},
            json={"Phone": numero, "Body": mensagem},
            timeout=20,
        )
        if resp.status_code == 200 and resp.json().get("success"):
            dados = resp.json().get("data") or {}
            msgid = dados.get("Id") or None
            log.info("Lembrete WhatsApp enviado via wuzapi: %s (id=%s)", _mascarar(numero), msgid)
            return True, msgid
        else:
            log.error("Erro wuzapi (%s): %s", resp.status_code, resp.text[:200])
            return False, None
    except Exception as e:
        log.exception("Erro ao enviar lembrete via wuzapi")
        return False, None


def _wuzapi_health_ok(base_url: str) -> bool:
    """True se o wuzapi tem pelo menos um usuario conectado ao WhatsApp.

    O endpoint /health e publico (sem auth). Se nao houver usuarios
    cadastrados, considera ok (nada para reconectar)."""
    try:
        resp = requests.get(f"{base_url}/health", timeout=10)
        if resp.status_code != 200:
            return False
        dados = resp.json()
        total = int(dados.get("total_users") or 0)
        logados = int(dados.get("logged_in_users") or 0)
        if total == 0:
            return True
        return logados > 0
    except Exception:
        return False


def _reconectar_wuzapi(base_url: str, token: str) -> bool:
    """Reconecta a sessão salva do WhatsApp (sem escanear QR)."""
    try:
        resp = requests.post(
            f"{base_url}/session/connect",
            headers={"token": token, "Content-Type": "application/json"},
            json={"Subscribe": ["All"], "Immediate": False},
            timeout=15,
        )
        if resp.status_code == 200 and resp.json().get("success"):
            log.info("wuzapi reconectado via /session/connect.")
            return True
        log.error("Falha ao reconectar wuzapi (%s): %s", resp.status_code, resp.text[:200])
        return False
    except Exception:
        log.exception("Erro ao tentar reconectar wuzapi")
        return False


def _checar_e_reconectar_wuzapi() -> bool:
    """Verifica a saude do wuzapi e reconecta se estiver desconectado.

    Respeita um cooldown minimo entre tentativas de reconexao. Retorna True
    se uma reconexao foi disparada."""
    global _ultima_reconexao_wuzapi

    base_url = os.getenv("WUZAPI_BASE_URL", "").strip().rstrip("/")
    if not base_url:
        return False

    agora = time.time()
    if agora - _ultima_reconexao_wuzapi < _WUZAPI_RECONNECT_COOLDOWN_SECONDS:
        return False

    if _wuzapi_health_ok(base_url):
        return False

    token = _resolver_token_wuzapi("")
    if not token:
        log.error("wuzapi desconectado e sem token para reconectar.")
        return False

    _ultima_reconexao_wuzapi = agora
    log.warning("wuzapi desconectado. Tentando reconectar...")
    return _reconectar_wuzapi(base_url, token)


def _processar_pendentes(agora: datetime) -> bool:
    """Processa lembretes pendentes (síncrono, roda em thread pool).

    Faz SELECT + envio WhatsApp + UPDATEs. É chamado via asyncio.to_thread
    para não bloquear o event loop com o requests.post (timeout 20s) do wuzapi.
    Retorna True se algum registro foi alterado (exige commit)."""
    cur = executar(
        "SELECT * FROM lembretes WHERE status = 'pendente' AND horario_envio <= ?",
        (agora.isoformat(),),
    )
    pendentes = cur.fetchall()
    alterados = False

    for r in pendentes:
        try:
            sucesso, msgid = _enviar_whatsapp_via_wuzapi(
                r["owner_id"], r["telefone"], r["mensagem"],
            )
            if sucesso:
                executar(
                    "UPDATE lembretes SET status = 'enviado', enviado_em = ?, mensagem_id = ? WHERE id = ?",
                    (agora.isoformat(), msgid, r["id"]),
                )
            else:
                tentativas = (r.get("tentativas") or 0) + 1
                if _deve_continuar_tentando(r["horario_envio"], agora):
                    executar(
                        "UPDATE lembretes SET tentativas = ?, ultima_tentativa_em = ? WHERE id = ?",
                        (tentativas, agora.isoformat(), r["id"]),
                    )
                    log.info(
                        "Envio falhou, dentro da janela de retry (%s/%s): %s",
                        tentativas, JANELA_RETRY_MINUTOS, r["id"][:8],
                    )
                else:
                    executar(
                        "UPDATE lembretes SET status = 'falha', tentativas = ?, ultima_tentativa_em = ? WHERE id = ?",
                        (tentativas, agora.isoformat(), r["id"]),
                    )
                    log.info(
                        "Envio falhou e janela de retry expirou (%s tentativas): %s",
                        tentativas, r["id"][:8],
                    )
            alterados = True
        except Exception as e:
            log.error("Erro ao processar lembrete %s: %s", r["id"][:8], e)

    if alterados:
        cur.commit()
    return alterados


async def _scheduler() -> None:
    log.info("Scheduler de lembretes iniciado.")
    while True:
        try:
            await asyncio.sleep(30)
            await asyncio.to_thread(_checar_e_reconectar_wuzapi)
            agora = datetime.now(timezone.utc)

            async with _LOCK:
                await asyncio.to_thread(_processar_pendentes, agora)
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
    """Agenda (ou re-agenda) um lembrete para o compromisso.

    O id do lembrete é gerado no servidor (uuid) — o `compromisso_id` enviado
    pelo cliente NUNCA é usado como chave primária (fix IDOR do pentest).
    Reagendar o mesmo (owner_id, compromisso_id) atualiza o registro existente
    em vez de duplicar; owners diferentes nunca se sobrescrevem."""
    async with _LOCK:
        cur = executar(
            "SELECT id FROM lembretes WHERE compromisso_id = ? AND owner_id = ?",
            (compromisso_id, owner_id),
        )
        linha = cur.fetchone()
        agora = datetime.now(timezone.utc).isoformat()

        if linha:
            rid = linha["id"]
            executar(
                "UPDATE lembretes SET telefone = ?, mensagem = ?, horario_envio = ?, "
                "canal = ?, status = 'pendente', criado_em = ? "
                "WHERE id = ? AND owner_id = ?",
                (telefone, mensagem, horario_envio, canal, agora, rid, owner_id),
            ).commit()
            log.info("Lembrete re-agendado: %s para %s", rid[:8], horario_envio)
            return rid

        rid = str(uuid.uuid4())
        executar(
            "INSERT INTO lembretes (id, compromisso_id, telefone, mensagem, horario_envio, canal, status, owner_id, criado_em) "
            "VALUES (?, ?, ?, ?, ?, ?, 'pendente', ?, ?)",
            (rid, compromisso_id, telefone, mensagem, horario_envio, canal, owner_id, agora),
        ).commit()
    log.info("Lembrete agendado: %s para %s", rid[:8], horario_envio)
    return rid


async def cancelar_lembrete(compromisso_id: str, owner_id: str = "") -> bool:
    async with _LOCK:
        cur = executar(
            "DELETE FROM lembretes WHERE compromisso_id = ? AND owner_id = ?",
            (compromisso_id, owner_id),
        )
        cur.commit()
        deletado = cur.rowcount > 0
        if deletado:
            log.info("Lembrete cancelado: %s", compromisso_id[:8])
        return deletado


def listar_lembretes() -> list[dict]:
    cur = executar("SELECT * FROM lembretes")
    return cur.fetchall()


def registrar_receipt(payload: dict) -> int:
    """Processa um webhook ReadReceipt do wuzapi e marca entrega/leitura.

    O wuzapi emite um webhook do tipo ``ReadReceipt`` quando a mensagem é
    entregue (``Delivered``) ou lida (``Read``/``ReadSelf``). O campo
    ``event.MessageIDs`` traz os IDs das mensagens (gerados pelo wuzapi e
    gravados em ``lembretes.mensagem_id``). Retorna quantos lembretes foram
    atualizados.
    """
    if not isinstance(payload, dict):
        return 0
    if payload.get("type") != "ReadReceipt":
        return 0

    state = payload.get("state")
    event = payload.get("event") or {}
    ids = event.get("MessageIDs") or event.get("MessageIds") or event.get("message_ids") or []
    if not isinstance(ids, list) or not ids:
        return 0

    agora = datetime.now(timezone.utc).isoformat()
    atualizados = 0
    for mid in ids:
        try:
            cur = executar(
                "SELECT id, compromisso_id, status FROM lembretes WHERE mensagem_id = ?",
                (mid,),
            )
            row = cur.fetchone()
            if row is None:
                continue

            if state in ("Delivered",):
                coluna, marcador = "entregue_em", "entregue"
            elif state in ("Read", "ReadSelf"):
                coluna, marcador = "lido_em", "lido"
            else:
                continue

            upd = executar(
                f"UPDATE lembretes SET {coluna} = ? WHERE id = ? AND {coluna} IS NULL",
                (agora, row["id"]),
            )
            upd.commit()
            if upd.rowcount and upd.rowcount > 0:
                atualizados += upd.rowcount
                log.info(
                    "Lembrete %s marcado como %s (id mensagem %s)",
                    row["id"][:8], marcador, mid,
                )
        except Exception as e:
            log.error("Erro ao processar receipt do lembrete %s: %s", mid[:20], e)
    return atualizados
