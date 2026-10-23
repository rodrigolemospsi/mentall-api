"""Provisionamento e conexao de instancias wuzapi por profissional.

Cada profissional tem uma instancia wuzapi propria, criada sob demanda via API
de admin do wuzapi. O token da instancia NUNCA vai para o app: o app fala com
o backend, e o backend fala com o wuzapi (regra fail-closed do
``_resolver_token_wuzapi`` em ``lembrete_service``).

Fluxo de conexao (evita o problema do QR no mesmo celular):
  1. ``garantir_instancia`` cria (ou reutiliza) a instancia do owner.
  2. ``parear`` conecta e pede um codigo em ``POST /session/pairphone``.
     O profissional digita o codigo no WhatsApp > Aparelhos conectados >
     Vincular com numero de telefone.
  3. ``status`` confirma a conexao; ``qr`` e a alternativa por QR Code.
"""
import logging
import os
import secrets

import requests

from services.db import executar
from services.lembrete_service import (
    _enviar_whatsapp_via_wuzapi,
    _mascarar,
    _normalizar_numero_whatsapp,
    _resolver_token_wuzapi,
    salvar_instancia_wuzapi,
)

log = logging.getLogger("mentall.wuzapi")

# O backend so precisa saber que a mensagem foi entregue/lida. Assinar "Message"
# traria o conteudo das conversas dos pacientes para o nosso webhook — fora do
# escopo e desnecessario (LGPD).
EVENTOS_WUZAPI = os.getenv("WUZAPI_EVENTS", "ReadReceipt")


def _base_url() -> str:
    return os.getenv("WUZAPI_BASE_URL", "").strip().rstrip("/")


def _admin_token() -> str:
    return os.getenv("WUZAPI_ADMIN_TOKEN", "").strip()


def _webhook_url() -> str:
    base = os.getenv("API_BASE_URL", "https://mentall-api.fly.dev").strip().rstrip("/")
    token = os.getenv("WUZAPI_WEBHOOK_TOKEN", "").strip()
    return f"{base}/wuzapi/webhook?token={token}"


def _headers_usuario(token: str) -> dict:
    # O wuzapi usa o header minusculo "token" para endpoints de usuario
    # ("Authorization" e so para /admin/*).
    return {"token": token, "Content-Type": "application/json"}


def _headers_admin() -> dict:
    return {"Authorization": _admin_token(), "Content-Type": "application/json"}


def garantir_instancia(owner_id: str) -> str:
    """Garante uma instancia wuzapi para o owner e devolve o token dela.

    Idempotente: reutiliza a instancia existente. Fail-closed: sem owner_id, ou
    sem ``WUZAPI_BASE_URL``/``WUZAPI_ADMIN_TOKEN`` para criar uma nova, devolve
    "" — um owner nunca usa a identidade WhatsApp de outro profissional.
    """
    if not owner_id:
        return ""

    existente = _resolver_token_wuzapi(owner_id)
    if existente:
        return existente

    base = _base_url()
    admin = _admin_token()
    if not base or not admin:
        log.error("Wuzapi admin nao configurado; impossivel criar instancia.")
        return ""

    token = secrets.token_urlsafe(24)
    try:
        resp = requests.post(
            f"{base}/admin/users",
            headers=_headers_admin(),
            json={
                "name": f"mentall-{owner_id[:8]}",
                "token": token,
                "webhook": _webhook_url(),
                "events": EVENTOS_WUZAPI,
            },
            timeout=20,
        )
    except Exception:
        log.exception("Erro ao criar instancia wuzapi")
        return ""

    if resp.status_code not in (200, 201):
        log.error("Falha ao criar instancia wuzapi (%s): %s", resp.status_code, resp.text[:200])
        return ""

    try:
        dados = resp.json()
    except Exception:
        dados = {}
    user_id = dados.get("id") or (dados.get("data") or {}).get("id") or 0
    salvar_instancia_wuzapi(owner_id, token, user_id=user_id, conectado=False)
    log.info("Instancia wuzapi criada para owner %s", owner_id[:8])
    return token


def status(owner_id: str) -> dict:
    """Estado da instancia do owner para a tela de configuracoes."""
    vazio = {"configurado": False, "conectado": False, "logado": False, "numero": ""}
    token = _resolver_token_wuzapi(owner_id)
    if not token:
        return vazio

    base = _base_url()
    if not base:
        return {**vazio, "configurado": True}

    try:
        resp = requests.get(
            f"{base}/session/status",
            headers=_headers_usuario(token),
            timeout=15,
        )
        dados = (resp.json() or {}).get("data") or {}
        # O wuzapi responde em camelCase (connected/loggedIn/jid). Mantemos o
        # fallback em PascalCase para compatibilidade com respostas antigas.
        conectado = dados.get("connected")
        if conectado is None:
            conectado = dados.get("Connected")
        logado = dados.get("loggedIn")
        if logado is None:
            logado = dados.get("LoggedIn")
        return {
            "configurado": True,
            "conectado": bool(conectado),
            "logado": bool(logado),
            "numero": dados.get("jid") or dados.get("Jid") or "",
        }
    except Exception:
        log.exception("Erro ao consultar status do wuzapi")
        return {**vazio, "configurado": True}


def parear(owner_id: str, telefone: str) -> dict:
    """Gera o codigo de pareamento (mesmo celular, sem QR)."""
    token = garantir_instancia(owner_id)
    if not token:
        return {"sucesso": False, "codigo": "", "erro": "WhatsApp nao configurado no servidor."}

    base = _base_url()
    numero = _normalizar_numero_whatsapp(telefone)
    try:
        requests.post(
            f"{base}/session/connect",
            headers=_headers_usuario(token),
            json={"Subscribe": [EVENTOS_WUZAPI], "Immediate": False},
            timeout=15,
        )
        resp = requests.post(
            f"{base}/session/pairphone",
            headers=_headers_usuario(token),
            json={"Phone": numero},
            timeout=20,
        )
    except Exception:
        log.exception("Erro ao solicitar codigo de pareamento")
        return {"sucesso": False, "codigo": "", "erro": "Falha ao falar com o WhatsApp."}

    payload = {}
    try:
        payload = resp.json() or {}
    except Exception:
        payload = {}
    if resp.status_code == 200 and payload.get("success"):
        codigo = (payload.get("data") or {}).get("LinkingCode") or ""
        if codigo:
            log.info("Codigo de pareamento gerado para %s", _mascarar(numero))
            return {"sucesso": True, "codigo": codigo, "erro": ""}

    log.error("Falha no pareamento (%s): %s", resp.status_code, resp.text[:200])
    return {"sucesso": False, "codigo": "", "erro": "Nao foi possivel gerar o codigo de pareamento."}


def qr(owner_id: str) -> dict:
    """QR Code (data URI) como alternativa ao codigo de pareamento."""
    token = garantir_instancia(owner_id)
    if not token:
        return {"sucesso": False, "qr_code": "", "erro": "WhatsApp nao configurado no servidor."}

    base = _base_url()
    try:
        requests.post(
            f"{base}/session/connect",
            headers=_headers_usuario(token),
            json={"Subscribe": [EVENTOS_WUZAPI], "Immediate": False},
            timeout=15,
        )
        resp = requests.get(
            f"{base}/session/qr",
            headers=_headers_usuario(token),
            timeout=15,
        )
    except Exception:
        log.exception("Erro ao obter QR Code")
        return {"sucesso": False, "qr_code": "", "erro": "Falha ao obter o QR Code."}

    payload = {}
    try:
        payload = resp.json() or {}
    except Exception:
        payload = {}
    codigo = (payload.get("data") or {}).get("QRCode") or ""
    if resp.status_code == 200 and codigo:
        return {"sucesso": True, "qr_code": codigo, "erro": ""}
    return {"sucesso": False, "qr_code": "", "erro": "QR Code indisponivel no momento."}


def desconectar(owner_id: str, logout: bool = False) -> bool:
    """Desconecta a sessao (logout=False) ou desvincula o aparelho (logout=True)."""
    token = _resolver_token_wuzapi(owner_id)
    base = _base_url()
    if not token or not base:
        return False
    endpoint = "/session/logout" if logout else "/session/disconnect"
    try:
        resp = requests.post(
            f"{base}{endpoint}",
            headers=_headers_usuario(token),
            timeout=15,
        )
        return resp.status_code == 200 and bool((resp.json() or {}).get("success"))
    except Exception:
        log.exception("Erro ao desconectar wuzapi")
        return False


def testar(owner_id: str, telefone: str, mensagem: str) -> dict:
    """Envia uma mensagem de teste pelo WhatsApp conectado do owner."""
    sucesso, _ = _enviar_whatsapp_via_wuzapi(owner_id, telefone, mensagem)
    if sucesso:
        return {"sucesso": True, "erro": ""}
    return {"sucesso": False, "erro": "Nao foi possivel enviar a mensagem de teste."}
