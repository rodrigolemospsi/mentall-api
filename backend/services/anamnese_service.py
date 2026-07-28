import json
import logging
import os
import secrets
import time
from datetime import datetime, timezone
from pathlib import Path

log = logging.getLogger("mentall.anamneses")

_ANAMNESES: dict[str, dict] = {}
_ARQUIVO = Path(os.path.dirname(os.path.abspath(__file__))) / ".." / "data" / "anamneses.json"


def _carregar() -> None:
    global _ANAMNESES
    if not _ARQUIVO.exists():
        return
    try:
        with open(_ARQUIVO, "r", encoding="utf-8") as f:
            _ANAMNESES = json.load(f)
        log.info("Anamneses carregadas: %d", len(_ANAMNESES))
    except Exception:
        _ANAMNESES = {}


def _persistir() -> None:
    _ARQUIVO.parent.mkdir(parents=True, exist_ok=True)
    try:
        with open(_ARQUIVO, "w", encoding="utf-8") as f:
            json.dump(_ANAMNESES, f, ensure_ascii=False, indent=2)
    except Exception as e:
        log.error("Erro ao persistir anamneses: %s", e)


def criar_anamnese(template_json: str, owner_id: str, dados_extra: dict | None = None) -> str:
    token = secrets.token_urlsafe(32)
    _ANAMNESES[token] = {
        "token": token,
        "template_json": template_json,
        "owner_id": owner_id,
        "status": "pendente",
        "respostas": None,
        "criado_em": datetime.now(timezone.utc).isoformat(),
        "respondido_em": None,
        "dados_extra": dados_extra or {},
    }
    _persistir()
    log.info("Anamnese criada: token=%s", token[:8])
    return token


def obter_anamnese(token: str) -> dict | None:
    return _ANAMNESES.get(token)


def registrar_resposta(token: str, respostas_json: str) -> dict | None:
    anamnese = _ANAMNESES.get(token)
    if anamnese is None:
        return None
    if anamnese["status"] == "respondido":
        return anamnese
    anamnese["status"] = "respondido"
    anamnese["respostas"] = respostas_json
    anamnese["respondido_em"] = datetime.now(timezone.utc).isoformat()
    _persistir()
    log.info("Anamnese respondida: token=%s", token[:8])
    return anamnese


def listar_por_owner(owner_id: str) -> list:
    return [a for a in _ANAMNESES.values() if a.get("owner_id") == owner_id]


_carregar()
