"""Instância de WhatsApp dedicada aos avisos de e-mail (remetente 19 -> destino 75).

A instância principal do app continua sendo a do profissional (lembretes).
Esta instância separada é criada no WuzAPI, pareada com o número de avisos
(19) e usada apenas para enviar as notificações do `contato@`.

O token da instância de avisos fica em `email_alertas_estado`
(chave `alerta:wuzapi_token`) ou em `ALERTA_WUZAPI_TOKEN`. Nunca aparece em log.
"""
from __future__ import annotations

import json
import logging
import os
import secrets
import time

import requests

from services.db import executar
from services.lembrete_service import _normalizar_numero_whatsapp

log = logging.getLogger("mentall.wuzapi_alertas")

NOME_INSTANCIA = "mentall-alertas-email"
CHAVE_TOKEN = "alerta:wuzapi_token"
CHAVE_USER_ID = "alerta:wuzapi_user_id"


def _base() -> str:
    return (os.getenv("WUZAPI_BASE_URL") or "").strip().rstrip("/")


def _admin_token() -> str:
    return (os.getenv("WUZAPI_ADMIN_TOKEN") or "").strip()


def _ler_estado(chave: str) -> str:
    try:
        linhas = executar(
            "SELECT valor FROM email_alertas_estado WHERE chave = ?", (chave,)
        ).fetchall()
        return str(linhas[0].get("valor") or "") if linhas else ""
    except Exception:
        return ""


def _salvar_estado(chave: str, valor: str) -> None:
    from datetime import datetime, timezone

    try:
        executar(
            "INSERT OR REPLACE INTO email_alertas_estado (chave, valor, atualizado_em) VALUES (?, ?, ?)",
            (chave, valor, datetime.now(timezone.utc).isoformat()),
        ).commit()
    except Exception:
        log.exception("Falha ao salvar estado da instância de avisos")


def token() -> str:
    return (os.getenv("ALERTA_WUZAPI_TOKEN") or _ler_estado(CHAVE_TOKEN)).strip()


def configurado() -> bool:
    return bool(token() and _base())


def garantir_instancia() -> str:
    """Garante a instância de avisos no WuzAPI e devolve o token."""
    existente = token()
    if existente:
        return existente
    base, admin = _base(), _admin_token()
    if not base or not admin:
        return ""
    novo_token = secrets.token_urlsafe(24)
    try:
        resposta = requests.post(
            f"{base}/admin/users",
            headers={"Authorization": admin, "Content-Type": "application/json"},
            json={
                "name": NOME_INSTANCIA,
                "token": novo_token,
                "webhook": "",
                "events": [],
            },
            timeout=20,
        )
        if resposta.status_code not in (200, 201):
            log.error("Falha ao criar instância de avisos (%s): %s", resposta.status_code, resposta.text[:200])
            return ""
        dados = resposta.json() or {}
        user_id = dados.get("id") or (dados.get("data") or {}).get("id") or ""
        _salvar_estado(CHAVE_TOKEN, novo_token)
        _salvar_estado(CHAVE_USER_ID, str(user_id))
        log.info("Instância de avisos criada no WuzAPI (user_id=%s)", user_id)
        return novo_token
    except Exception:
        log.exception("Erro ao criar instância de avisos")
        return ""


def _desconectar_sessao(instancia_token: str) -> None:
    try:
        requests.post(
            f"{_base()}/session/disconnect",
            headers={"token": instancia_token},
            timeout=15,
        )
    except Exception:
        pass


def _conectar(instancia_token: str) -> None:
    try:
        requests.post(
            f"{_base()}/session/connect",
            headers={"token": instancia_token, "Content-Type": "application/json"},
            json={"Subscribe": [], "Immediate": False},
            timeout=15,
        )
    except Exception:
        log.exception("Falha ao pedir conexão da instância de avisos")


def status() -> dict:
    instancia_token = token()
    if not instancia_token or not _base():
        return {"configurado": False, "conectado": False, "numero": ""}
    _conectar(instancia_token)
    try:
        resposta = requests.get(
            f"{_base()}/session/status",
            headers={"token": instancia_token},
            timeout=15,
        )
        dados = (resposta.json() or {}).get("data") or {}
        conectado = dados.get("connected")
        if conectado is None:
            conectado = dados.get("Connected")
        logado = dados.get("loggedIn")
        if logado is None:
            logado = dados.get("LoggedIn")
        jid = str(dados.get("jid") or dados.get("Jid") or "")
        return {
            "configurado": True,
            "conectado": bool(conectado) and bool(logado) and bool(jid),
            "logado": bool(logado),
            "numero": jid,
        }
    except Exception:
        log.exception("Falha ao consultar status da instância de avisos")
        return {"configurado": True, "conectado": False, "numero": ""}


_QR_CACHE: dict = {"qr": "", "ts": 0.0}


def numero_remetente() -> str:
    return (os.getenv("EMAIL_ALERTA_REMETENTE_NUMERO") or "5519981887176").strip()


def _buscar_codigo(instancia_token: str) -> str:
    try:
        resposta = requests.post(
            f"{_base()}/session/pairphone",
            headers={"token": instancia_token, "Content-Type": "application/json"},
            json={"Phone": _normalizar_numero_whatsapp(numero_remetente())},
            timeout=20,
        )
        dados = (resposta.json() or {}).get("data") or {}
        return str(dados.get("LinkingCode") or "")
    except Exception:
        log.exception("Falha ao gerar código de pareamento do número de avisos")
        return ""


def codigo_pareamento() -> str:
    """Gera um código de 8 dígitos para parear o número 19 sem QR."""
    instancia_token = garantir_instancia()
    if not instancia_token or not _base():
        return ""
    _conectar(instancia_token)
    codigo = _buscar_codigo(instancia_token)
    if not codigo:
        _desconectar_sessao(instancia_token)
        _conectar(instancia_token)
        codigo = _buscar_codigo(instancia_token)
    if codigo:
        log.info("Código de pareamento do número de avisos gerado.")
    return codigo


def _buscar_qr(instancia_token: str) -> str:
    try:
        resposta = requests.get(
            f"{_base()}/session/qr",
            headers={"token": instancia_token},
            timeout=15,
        )
        dados = (resposta.json() or {}).get("data") or {}
        return str(dados.get("QRCode") or "")
    except Exception:
        log.exception("Falha ao obter QR da instância de avisos")
        return ""


def qr_code() -> str:
    """Solicita conexão e devolve o QR Code (data URI) para parear o número 19."""
    if _QR_CACHE["qr"] and time.time() - float(_QR_CACHE["ts"]) < 5:
        return str(_QR_CACHE["qr"])
    instancia_token = garantir_instancia()
    if not instancia_token or not _base():
        return ""
    _conectar(instancia_token)
    qr = _buscar_qr(instancia_token)
    if not qr:
        # sessão pode ter ficado em modo "código de pareamento"; reseta e tenta o QR de novo
        _desconectar_sessao(instancia_token)
        _conectar(instancia_token)
        qr = _buscar_qr(instancia_token)
    if qr:
        _QR_CACHE["qr"] = qr
        _QR_CACHE["ts"] = time.time()
    return qr


def enviar(destino: str, mensagem: str) -> bool:
    """Envia pelo número 19 (instância de avisos). False se não configurada/falhar."""
    instancia_token = token()
    base = _base()
    if not instancia_token or not base:
        return False
    numero = _normalizar_numero_whatsapp(destino)
    for alvo in _variantes(numero):
        try:
            resposta = requests.post(
                f"{base}/chat/send/text",
                headers={"token": instancia_token, "Content-Type": "application/json"},
                json={"Phone": alvo, "Body": mensagem},
                timeout=20,
            )
            if resposta.status_code == 200 and (resposta.json() or {}).get("success"):
                log.info("Aviso enviado pelo número de avisos (19): %s", alvo[:4] + "****" + alvo[-2:])
                return True
            log.warning(
                "Falha no envio pelo número de avisos (%s): %s",
                resposta.status_code,
                resposta.text[:160],
            )
        except Exception:
            log.exception("Erro ao enviar pelo número de avisos")
    return False


def _variantes(numero: str) -> list[str]:
    digitos = "".join(ch for ch in numero if ch.isdigit())
    variantes = [digitos]
    if len(digitos) == 13 and digitos.startswith("55"):
        variantes.append(digitos[:4] + digitos[5:])
    elif len(digitos) == 12 and digitos.startswith("55"):
        variantes.append(digitos[:4] + "9" + digitos[4:])
    return variantes
