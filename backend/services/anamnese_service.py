import json
import logging
import secrets
from datetime import datetime, timezone

from services.db import _obter_conexao

log = logging.getLogger("mentall.anamneses")


def _row_para_dict(row) -> dict:
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


def criar_anamnese(template_json: str, owner_id: str, dados_extra: dict | None = None) -> str:
    token = secrets.token_urlsafe(32)
    conn = _obter_conexao()
    conn.execute(
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
    conn.commit()
    log.info("Anamnese criada: token=%s", token[:8])
    return token


def obter_anamnese(token: str) -> dict | None:
    conn = _obter_conexao()
    row = conn.execute("SELECT * FROM anamneses WHERE token = ?", (token,)).fetchone()
    return _row_para_dict(row)


def registrar_resposta(token: str, respostas_json: str) -> dict | None:
    conn = _obter_conexao()
    row = conn.execute("SELECT * FROM anamneses WHERE token = ?", (token,)).fetchone()
    if row is None:
        return None
    if row["status"] == "respondido":
        return _row_para_dict(row)
    agora = datetime.now(timezone.utc).isoformat()
    conn.execute(
        "UPDATE anamneses SET status = 'respondido', respostas = ?, respondido_em = ? WHERE token = ?",
        (respostas_json, agora, token),
    )
    conn.commit()
    log.info("Anamnese respondida: token=%s", token[:8])
    return obter_anamnese(token)


def listar_por_owner(owner_id: str) -> list:
    conn = _obter_conexao()
    rows = conn.execute("SELECT * FROM anamneses WHERE owner_id = ?", (owner_id,)).fetchall()
    return [_row_para_dict(r) for r in rows]
