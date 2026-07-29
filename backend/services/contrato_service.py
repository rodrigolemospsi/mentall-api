import json
import logging
import secrets
from datetime import datetime, timezone

from services.db import _obter_conexao

log = logging.getLogger("mentall.contratos")


def _row_para_dict(row) -> dict:
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


def criar_contrato(dados: dict, owner_id: str = "") -> str:
    token = secrets.token_urlsafe(32)
    conn = _obter_conexao()
    conn.execute(
        "INSERT INTO contratos (token, dados, status, owner_id, criado_em) VALUES (?, ?, 'pendente', ?, ?)",
        (token, json.dumps(dados, ensure_ascii=False), owner_id, datetime.now(timezone.utc).isoformat()),
    )
    conn.commit()
    log.info("Contrato criado: token=%s", token[:8])
    return token


def listar_contratos_por_owner(owner_id: str) -> list:
    conn = _obter_conexao()
    rows = conn.execute("SELECT * FROM contratos WHERE owner_id = ?", (owner_id,)).fetchall()
    return [_row_para_dict(r) for r in rows]


def obter_contrato(token: str) -> dict | None:
    conn = _obter_conexao()
    row = conn.execute("SELECT * FROM contratos WHERE token = ?", (token,)).fetchone()
    return _row_para_dict(row)


def registrar_aceite(token: str, nome: str) -> dict | None:
    conn = _obter_conexao()
    row = conn.execute("SELECT * FROM contratos WHERE token = ?", (token,)).fetchone()
    if row is None:
        return None
    if row["status"] == "aceito":
        return _row_para_dict(row)
    agora = datetime.now(timezone.utc).isoformat()
    conn.execute(
        "UPDATE contratos SET status = 'aceito', aceito_em = ?, nome_aceite = ? WHERE token = ?",
        (agora, nome.strip(), token),
    )
    conn.commit()
    log.info("Contrato aceito: token=%s nome=%s", token[:8], nome[:20])
    return obter_contrato(token)
