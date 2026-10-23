"""Administração das caixas de e-mail (Mailu) pelo painel do dono.

A API do Mailu (https://mail.mentallpro.com.br/api/v1) fica atrás do Caddy e é
autenticada por um token de serviço (MAILU_API_TOKEN). O token NUNCA vai ao
navegador: o painel fala com o Mailu pelo backend.

Regras de segurança:
- toda operação recebe o endereço completo e só age dentro de MAILU_DOMINIO;
- caixas com papel global_admin não podem ser desativadas/excluídas pelo painel
  (evita trancar o acesso administrativo);
- erros são convertidos em mensagens curtas e sem detalhes internos.

LGPD: aqui só circulam endereços, nome de exibição e cota — nenhum dado clínico.
"""
import logging
import os
import re
import secrets
import string
from urllib.parse import quote as _quote

import httpx

log = logging.getLogger("mentall.admin.email")

# Configuração lida em tempo de chamada: o main.py importa os serviços antes do
# load_dotenv(), então constantes de módulo leriam o ambiente incompleto.
_URL_PADRAO = "https://mail.mentallpro.com.br/api/v1"
_DOMINIO_PADRAO = "mentallpro.com.br"

TIMEOUT_SEGUNDOS = 15.0
BYTES_POR_GB = 1024 ** 3
COTAS_GB = (1, 2, 3, 5)

_PREFIXO_VALIDO = re.compile(r"^[a-z0-9][a-z0-9._-]{0,29}$")
_EMAIL_VALIDO = re.compile(r"^[a-z0-9][a-z0-9._-]*@[a-z0-9.-]+$")


class EmailAdminErro(Exception):
    """Falha ao falar com o servidor de e-mail (mensagem pronta pro painel)."""


def api_url() -> str:
    return (os.getenv("MAILU_API_URL") or _URL_PADRAO).strip().rstrip("/")


def token() -> str:
    return (os.getenv("MAILU_API_TOKEN") or "").strip()


def dominio() -> str:
    return (os.getenv("MAILU_DOMINIO") or _DOMINIO_PADRAO).strip().lower()


def configurado() -> bool:
    return bool(token())


def _requisitar(metodo: str, caminho: str, timeout: float | None = None, **kwargs):
    """Chamada HTTP à API do Mailu, centralizando erros e timeout."""
    if not configurado():
        raise EmailAdminErro(
            "Integração de e-mail não configurada (MAILU_API_TOKEN ausente nos secrets)."
        )
    url = f"{api_url()}{caminho}"
    cabecalhos = {
        "Authorization": f"Bearer {token()}",
        "Accept": "application/json",
    }
    try:
        with httpx.Client(timeout=timeout or TIMEOUT_SEGUNDOS) as cliente:
            resposta = cliente.request(metodo, url, headers=cabecalhos, **kwargs)
    except httpx.HTTPError as exc:
        log.warning("Mailu inacessível (%s %s): %s", metodo, caminho, exc)
        raise EmailAdminErro("Servidor de e-mail inacessível no momento. Tente novamente.") from exc

    if resposta.status_code in (401, 403):
        log.warning("Mailu recusou a credencial (HTTP %s)", resposta.status_code)
        raise EmailAdminErro("Credencial da API do e-mail inválida ou sem permissão.")
    if resposta.status_code >= 400:
        detalhe = ""
        try:
            detalhe = (resposta.json() or {}).get("message") or ""
        except Exception:  # noqa: BLE001 - corpo não-JSON é possível
            detalhe = ""
        log.warning(
            "Mailu recusou %s %s (HTTP %s): %s", metodo, caminho, resposta.status_code, detalhe
        )
        raise EmailAdminErro(
            f"O servidor de e-mail recusou a operação{f': {detalhe}' if detalhe else '.'}"
        )
    if resposta.status_code == 204 or not resposta.content:
        return None
    try:
        return resposta.json()
    except ValueError:
        return None


# ---------------------------------------------------------------------------
# Leitura
# ---------------------------------------------------------------------------

def listar_caixas(timeout: float | None = None) -> list[dict]:
    """Caixas do domínio, ordenadas (admin primeiro, depois alfabético)."""
    dados = _requisitar("GET", "/user", timeout=timeout) or []
    caixas = []
    for item in dados:
        if not isinstance(item, dict):
            continue
        email = (item.get("email") or "").lower()
        if not email.endswith(f"@{dominio()}"):
            continue
        cota_bytes = int(item.get("quota_bytes") or 0)
        caixas.append(
            {
                "email": email,
                "nome": (item.get("displayed_name") or "").strip(),
                "cota_gb": round(cota_bytes / BYTES_POR_GB, 1) if cota_bytes > 0 else 0,
                "ativo": bool(item.get("enabled", True)),
                "admin": bool(item.get("global_admin", False)),
            }
        )
    caixas.sort(key=lambda c: (not c["admin"], c["email"]))
    return caixas


def listar_aliases(timeout: float | None = None) -> list[dict]:
    dados = _requisitar("GET", "/alias", timeout=timeout) or []
    aliases = []
    for item in dados:
        if not isinstance(item, dict):
            continue
        email = (item.get("email") or "").lower()
        destinos = item.get("destination") or []
        if not isinstance(destinos, list):
            continue
        aliases.append({"email": email, "destinos": [str(d).lower() for d in destinos]})
    aliases.sort(key=lambda a: a["email"])
    return aliases


# ---------------------------------------------------------------------------
# Escrita
# ---------------------------------------------------------------------------

def gerar_senha(tamanho: int = 14) -> str:
    alfabeto = string.ascii_letters + string.digits
    return "".join(secrets.choice(alfabeto) for _ in range(tamanho))


def validar_prefixo(prefixo: str) -> str:
    prefixo = (prefixo or "").strip().lower()
    if not _PREFIXO_VALIDO.match(prefixo):
        raise EmailAdminErro(
            "Endereço inválido. Use de 1 a 30 caracteres: letras minúsculas, números, ponto, hífen ou _."
        )
    return prefixo


def validar_email(email: str) -> str:
    email = (email or "").strip().lower()
    if not _EMAIL_VALIDO.match(email) or not email.endswith(f"@{dominio()}"):
        raise EmailAdminErro(f"Endereço de e-mail fora de @{dominio()}.")
    return email


def criar_caixa(prefixo: str, nome: str, cota_gb: int) -> tuple[str, str]:
    """Cria a caixa e devolve (endereço, senha temporária)."""
    prefixo = validar_prefixo(prefixo)
    try:
        cota_gb = int(cota_gb)
    except (TypeError, ValueError):
        cota_gb = 2
    cota_gb = min(max(cota_gb, 1), 10)
    email = f"{prefixo}@{dominio()}"
    senha = gerar_senha()
    _requisitar(
        "POST",
        "/user",
        json={
            "email": email,
            "raw_password": senha,
            "quota_bytes": cota_gb * BYTES_POR_GB,
            "displayed_name": (nome or "").strip()[:100],
            "global_admin": False,
            "enabled": True,
        },
    )
    log.info("Caixa criada pelo painel: %s (cota %s GB)", email, cota_gb)
    return email, senha


def gerar_senha_temporaria(email: str) -> str:
    """Redefine a senha da caixa e devolve a nova senha temporária."""
    email = validar_email(email)
    senha = gerar_senha()
    _requisitar("PATCH", f"/user/{_quote(email, safe='')}", json={"raw_password": senha})
    log.info("Senha redefinida pelo painel: %s", email)
    return senha


def definir_status(email: str, ativo: bool) -> None:
    email = validar_email(email)
    _requisitar("PATCH", f"/user/{_quote(email, safe='')}", json={"enabled": bool(ativo)})
    log.info("Caixa %s %s pelo painel", email, "ativada" if ativo else "desativada")


def excluir_caixa(email: str) -> None:
    email = validar_email(email)
    _requisitar("DELETE", f"/user/{_quote(email, safe='')}")
    log.info("Caixa excluída pelo painel: %s", email)


def criar_alias(prefixo: str, destino_email: str) -> str:
    prefixo = validar_prefixo(prefixo)
    destino_email = validar_email(destino_email)
    email = f"{prefixo}@{dominio()}"
    _requisitar("POST", "/alias", json={"email": email, "destination": [destino_email]})
    log.info("Alias criado pelo painel: %s -> %s", email, destino_email)
    return email


def excluir_alias(email: str) -> None:
    email = validar_email(email)
    _requisitar("DELETE", f"/alias/{_quote(email, safe='')}")
    log.info("Alias excluído pelo painel: %s", email)
