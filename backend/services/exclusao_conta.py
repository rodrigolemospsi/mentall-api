"""Exclusão de conta — caminho B (item 2.4 do checklist v2).

Apaga a conta e os dados que vivem no SERVIDOR. O prontuário clínico cifrado
vive no aparelho do profissional e NÃO é apagado pelo servidor (o profissional
é o controlador desses dados). Ver ESPECIFICACAO_exclusao_de_conta.md.
"""
import hashlib
import json
import logging
import os
import uuid
from datetime import datetime, timezone

from services.db import executar

log = logging.getLogger("mentall.exclusao_conta")

CONFIRMACAO = "EXCLUIR"
TABELAS_POR_OWNER = ("contratos", "anamneses", "lembretes", "dispositivos",
                     "eventos", "wuzapi_instancias")
TABELAS_POR_EMAIL = ("recuperacoes", "resets_senha")
RETIDO = (
    "O prontuário clínico cifrado permanece no aparelho do profissional "
    "(ele é o controlador desses dados). O servidor não armazena conteúdo clínico."
)


def agora_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def hash_email(email: str) -> str:
    return hashlib.sha256(email.lower().strip().encode()).hexdigest()


def pode_excluir(owner_id: str) -> bool:
    """False para a conta administrativa legada (owner fixo compartilhado)."""
    admin = os.getenv("APP_USER_ID", "").strip()
    return bool(owner_id) and owner_id != admin


def _contar(sql, params) -> int:
    try:
        cur = executar(sql, params)
        row = cur.fetchone()
        if row is None:
            return 0
        return int(row["n"])
    except Exception:
        log.exception("Falha ao contar registros para exclusão")
        return 0


def _apagar(tabela: str, where: str, params) -> int:
    total = _contar(f"SELECT COUNT(*) AS n FROM {tabela} WHERE {where}", params)
    if total:
        executar(f"DELETE FROM {tabela} WHERE {where}", params).commit()
    return total


def excluir_conta(owner_id: str, email: str, jti: str = "", exp_token: str = "") -> dict:
    """Executa a exclusão. Levanta PermissionError para a conta admin."""
    if not pode_excluir(owner_id):
        raise PermissionError("Conta administrativa não pode ser excluída pelo aplicativo.")

    quando = agora_iso()
    eliminados: dict[str, int] = {}
    for tabela in TABELAS_POR_OWNER:
        eliminados[tabela] = _apagar(tabela, "owner_id = ?", (owner_id,))

    usuario = None
    try:
        usuario = executar("SELECT id, email FROM usuarios WHERE id = ?", (owner_id,)).fetchone()
    except Exception:
        log.exception("Falha ao localizar usuário na exclusão")

    email_db = ""
    if usuario is not None:
        email_db = (usuario["email"] if isinstance(usuario, dict) else usuario["email"]) or ""
        eliminados["usuarios"] = _apagar("usuarios", "id = ?", (owner_id,))
    else:
        eliminados["usuarios"] = 0
    if not email_db:
        email_db = email or ""

    email_hash = hash_email(email_db) if email_db else ""
    for tabela in TABELAS_POR_EMAIL:
        eliminados[tabela] = _apagar(tabela, "email_hash = ?", (email_hash,)) if email_hash else 0

    if jti:
        try:
            executar(
                "INSERT OR REPLACE INTO tokens_revogados (jti, exp, criado_em) VALUES (?, ?, ?)",
                (jti, exp_token, quando),
            ).commit()
        except Exception:
            log.exception("Falha ao revogar token da sessão")

    try:
        executar(
            "INSERT INTO auditoria_exclusoes (id, email_hash, criado_em, resumo, retido) "
            "VALUES (?, ?, ?, ?, ?)",
            (uuid.uuid4().hex, email_hash, quando, json.dumps(eliminados), RETIDO[:400]),
        ).commit()
    except Exception:
        log.exception("Falha ao registrar auditoria da exclusão")

    log.info("Conta excluída: owner=%s email_hash=%s eliminados=%s",
             owner_id[:8], email_hash[:12], eliminados)
    return {
        "sucesso": True,
        "quando": quando,
        "eliminado": eliminados,
        "retido": {"prontuario": RETIDO},
        "mensagem": ("Conta e dados do servidor eliminados. O prontuário cifrado "
                     "permanece no aparelho do profissional."),
    }


def token_revogado(jti: str) -> bool:
    if not jti:
        return False
    try:
        cur = executar("SELECT 1 FROM tokens_revogados WHERE jti = ?", (jti,))
        return cur.fetchone() is not None
    except Exception:
        log.exception("Falha ao checar revogação de token")
        return False
