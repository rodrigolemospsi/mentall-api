import hashlib
import json
import logging
import os
import secrets
import time
from datetime import datetime, timezone
from pathlib import Path

log = logging.getLogger("mentall.contratos")

_CONTRATOS: dict[str, dict] = {}
_ARQUIVO = Path(os.path.dirname(os.path.abspath(__file__))) / ".." / "data" / "contratos.json"


def _carregar() -> None:
    global _CONTRATOS
    if not _ARQUIVO.exists():
        return
    try:
        with open(_ARQUIVO, "r", encoding="utf-8") as f:
            _CONTRATOS = json.load(f)
        log.info("Contratos carregados: %d", len(_CONTRATOS))
    except Exception:
        _CONTRATOS = {}


def _persistir() -> None:
    _ARQUIVO.parent.mkdir(parents=True, exist_ok=True)
    try:
        with open(_ARQUIVO, "w", encoding="utf-8") as f:
            json.dump(_CONTRATOS, f, ensure_ascii=False, indent=2)
    except Exception as e:
        log.error("Erro ao persistir contratos: %s", e)


def criar_contrato(dados: dict) -> str:
    token = secrets.token_urlsafe(32)
    _CONTRATOS[token] = {
        "token": token,
        "dados": dados,
        "status": "pendente",
        "criado_em": datetime.now(timezone.utc).isoformat(),
        "aceito_em": None,
        "nome_aceite": None,
    }
    _persistir()
    log.info("Contrato criado: token=%s", token[:8])
    return token


def obter_contrato(token: str) -> dict | None:
    return _CONTRATOS.get(token)


def registrar_aceite(token: str, nome: str) -> dict | None:
    contrato = _CONTRATOS.get(token)
    if contrato is None:
        return None
    if contrato["status"] == "aceito":
        return contrato
    contrato["status"] = "aceito"
    contrato["aceito_em"] = datetime.now(timezone.utc).isoformat()
    contrato["nome_aceite"] = nome.strip()
    _persistir()
    log.info("Contrato aceito: token=%s nome=%s", token[:8], nome[:20])
    return contrato


_carregar()
