import json
import logging
import secrets
from datetime import datetime, timezone

from services.db import executar

log = logging.getLogger("mentall.anamneses")


def criar_anamnese(template_json: str, owner_id: str, dados_extra: dict | None = None) -> str:
    token = secrets.token_urlsafe(32)
    cur = executar(
        "INSERT INTO anamneses (token, template_json, owner_id, status, criado_em, dados_extra) "
        "VALUES (?, ?, ?, 'pendente', ?, ?)",
        (
            token,
            template_json,
            owner_id,
            datetime.now(timezone.utc).isoformat(),
            json.dumps(dados_extra or {}, ensure_ascii=False),
        ),
    )
    cur.commit()
    log.info("Anamnese criada: token=%s", token[:8])
    return token


def obter_anamnese(token: str) -> dict | None:
    cur = executar("SELECT * FROM anamneses WHERE token = ?", (token,))
    row = cur.fetchone()
    if row is None:
        return None
    return {
        "token": row["token"],
        "template_json": row["template_json"],
        "owner_id": row["owner_id"],
        "status": row["status"],
        "respostas": row["respostas"],
        "criado_em": row["criado_em"],
        "respondido_em": row["respondido_em"],
        "dados_extra": json.loads(row["dados_extra"]) if row["dados_extra"] else {},
    }


def registrar_resposta(token: str, respostas_json: str) -> dict | None:
    cur = executar("SELECT * FROM anamneses WHERE token = ?", (token,))
    row = cur.fetchone()
    if row is None:
        return None
    if row["status"] == "respondido":
        return {
            "token": row["token"],
            "template_json": row["template_json"],
            "owner_id": row["owner_id"],
            "status": row["status"],
            "respostas": row["respostas"],
            "criado_em": row["criado_em"],
            "respondido_em": row["respondido_em"],
            "dados_extra": json.loads(row["dados_extra"]) if row["dados_extra"] else {},
        }
    agora = datetime.now(timezone.utc).isoformat()
    executar(
        "UPDATE anamneses SET status = 'respondido', respostas = ?, respondido_em = ? WHERE token = ?",
        (respostas_json, agora, token),
    ).commit()
    log.info("Anamnese respondida: token=%s", token[:8])
    return obter_anamnese(token)


def listar_por_owner(owner_id: str) -> list:
    cur = executar("SELECT * FROM anamneses WHERE owner_id = ?", (owner_id,))
    return cur.fetchall()
