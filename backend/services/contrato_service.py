import json
import logging
import secrets
from datetime import datetime, timezone

from services.db import executar

log = logging.getLogger("mentall.contratos")


def criar_contrato(dados: dict, owner_id: str = "") -> str:
    token = secrets.token_urlsafe(32)
    cur = executar(
        "INSERT INTO contratos (token, dados, status, owner_id, criado_em) VALUES (?, ?, 'pendente', ?, ?)",
        (token, json.dumps(dados, ensure_ascii=False), owner_id, datetime.now(timezone.utc).isoformat()),
    )
    cur.commit()
    log.info("Contrato criado: token=%s", token[:8])
    return token


def listar_contratos_por_owner(owner_id: str) -> list:
    cur = executar("SELECT * FROM contratos WHERE owner_id = ?", (owner_id,))
    return cur.fetchall()


def obter_contrato(token: str) -> dict | None:
    cur = executar("SELECT * FROM contratos WHERE token = ?", (token,))
    row = cur.fetchone()
    if row is None:
        return None
    return {
        "token": row["token"],
        "dados": json.loads(row["dados"]) if row["dados"] else {},
        "status": row["status"],
        "owner_id": row["owner_id"],
        "criado_em": row["criado_em"],
        "aceito_em": row["aceito_em"],
        "nome_aceite": row["nome_aceite"],
    }


def registrar_aceite(token: str, nome: str) -> dict | None:
    cur = executar("SELECT * FROM contratos WHERE token = ?", (token,))
    row = cur.fetchone()
    if row is None:
        return None
    if row["status"] == "aceito":
        return {
            "token": row["token"],
            "dados": json.loads(row["dados"]) if row["dados"] else {},
            "status": row["status"],
            "owner_id": row["owner_id"],
            "criado_em": row["criado_em"],
            "aceito_em": row["aceito_em"],
            "nome_aceite": row["nome_aceite"],
        }
    agora = datetime.now(timezone.utc).isoformat()
    executar(
        "UPDATE contratos SET status = 'aceito', aceito_em = ?, nome_aceite = ? WHERE token = ?",
        (agora, nome.strip(), token),
    ).commit()
    log.info("Contrato aceito: token=%s nome=%s", token[:8], nome[:20])
    return obter_contrato(token)
