"""Web Push no painel do dono (PWA).

Permite avisar o administrador mesmo com o painel fechado, sem depender de
WhatsApp ou de e-mail. As inscrições são por navegador/dispositivo e ficam na
tabela `push_subscriptions`; a chave privada VAPID vem de variável de ambiente.
"""
from __future__ import annotations

import base64
import json
import logging
import os
import tempfile

from services.db import executar

log = logging.getLogger("mentall.push")

CLAIMS_PADRAO = {"sub": os.getenv("VAPID_SUBJECT", "mailto:dpo@mentallpro.com.br")}


def configurado() -> bool:
    return bool(os.getenv("VAPID_PRIVATE_KEY_B64", "").strip()) and bool(
        os.getenv("VAPID_PUBLIC_KEY", "").strip()
    )


def public_key() -> str:
    return os.getenv("VAPID_PUBLIC_KEY", "").strip()


def _private_key_path() -> str:
    bruto = os.getenv("VAPID_PRIVATE_KEY_B64", "").strip()
    if not bruto:
        return ""
    caminho = os.path.join(tempfile.gettempdir(), "mentall-vapid-private.pem")
    if not os.path.exists(caminho):
        try:
            with open(caminho, "wb") as arquivo:
                arquivo.write(base64.b64decode(bruto))
            os.chmod(caminho, 0o600)
        except Exception:
            log.exception("Falha ao preparar chave VAPID")
            return ""
    return caminho


def salvar_inscricao(ator: str, dados: dict) -> bool:
    endpoint = str((dados or {}).get("endpoint") or "").strip()
    chaves = (dados or {}).get("keys") or {}
    p256dh = str(chaves.get("p256dh") or "").strip()
    auth = str(chaves.get("auth") or "").strip()
    if not endpoint or not p256dh or not auth:
        return False
    try:
        executar(
            "INSERT INTO push_subscriptions (id, ator, endpoint, p256dh, auth, criado_em, atualizado_em) "
            "VALUES (?, ?, ?, ?, ?, ?, ?) "
            "ON CONFLICT(endpoint) DO UPDATE SET ator = excluded.ator, p256dh = excluded.p256dh, "
            "auth = excluded.auth, atualizado_em = excluded.atualizado_em",
            (
                "push:" + base64.urlsafe_b64encode(os.urandom(9)).decode(),
                ator or "",
                endpoint,
                p256dh,
                auth,
                __import__("datetime").datetime.now(__import__("datetime").timezone.utc).isoformat(),
                __import__("datetime").datetime.now(__import__("datetime").timezone.utc).isoformat(),
            ),
        ).commit()
        return True
    except Exception:
        log.exception("Falha ao salvar inscrição push")
        return False


def remover_inscricao(endpoint: str) -> bool:
    try:
        cur = executar("DELETE FROM push_subscriptions WHERE endpoint = ?", (endpoint,))
        cur.commit()
        return cur.rowcount > 0
    except Exception:
        log.exception("Falha ao remover inscrição push")
        return False


def listar(ator: str | None = None) -> list[dict]:
    try:
        if ator:
            return executar(
                "SELECT * FROM push_subscriptions WHERE ator = ?", (ator,)
            ).fetchall()
        return executar("SELECT * FROM push_subscriptions").fetchall()
    except Exception:
        log.exception("Falha ao listar inscrições push")
        return []


def contar(ator: str | None = None) -> int:
    return len(listar(ator))


def enviar(titulo: str, corpo: str, url: str = "/admin/email", ator: str | None = None) -> dict:
    """Envia push para todas as inscrições (ou só de um ator)."""
    resultado = {"enviados": 0, "falhas": 0, "removidos": 0, "configurado": configurado()}
    if not configurado():
        resultado["erro"] = "VAPID não configurado"
        return resultado
    chave = _private_key_path()
    if not chave:
        resultado["erro"] = "chave VAPID indisponível"
        return resultado
    try:
        from pywebpush import WebPushException, webpush
    except Exception:
        resultado["erro"] = "pywebpush não instalado"
        log.exception("pywebpush não instalado; push indisponível")
        return resultado

    payload = json.dumps({"title": titulo, "body": corpo, "url": url})
    for inscricao in listar(ator):
        endpoint = str(inscricao.get("endpoint") or "")
        try:
            webpush(
                subscription_info={
                    "endpoint": endpoint,
                    "keys": {"p256dh": inscricao.get("p256dh"), "auth": inscricao.get("auth")},
                },
                data=payload,
                vapid_private_key=chave,
                vapid_claims=dict(CLAIMS_PADRAO),
                timeout=15,
            )
            resultado["enviados"] += 1
        except WebPushException as erro:
            status = getattr(getattr(erro, "response", None), "status_code", None)
            if status in (404, 410):
                remover_inscricao(endpoint)
                resultado["removidos"] += 1
            else:
                resultado["falhas"] += 1
                log.warning("Falha no push (%s): %s", status, str(erro)[:160])
        except Exception:
            resultado["falhas"] += 1
            log.exception("Falha ao enviar push")
    return resultado
