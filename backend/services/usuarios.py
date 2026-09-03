import hashlib
import logging
import secrets
import uuid
from datetime import datetime, timedelta, timezone

from passlib.context import CryptContext

from services.db import executar

log = logging.getLogger("mentall.usuarios")

_pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

CODIGO_EXPIRACAO_MINUTOS = 60


def hash_senha(senha: str) -> str:
    return _pwd_context.hash(senha)


def verificar_senha(senha: str, senha_hash: str) -> bool:
    try:
        return _pwd_context.verify(senha, senha_hash)
    except Exception:
        return False


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def _gerar_token() -> str:
    return secrets.token_urlsafe(32)


def criar_usuario_pendente(email: str, senha: str, nome: str = "", plano: str = "gratis") -> str:
    email = email.strip().lower()
    usuario_id = str(uuid.uuid4())
    agora = datetime.now(timezone.utc)
    token = _gerar_token()
    expiracao = (agora + timedelta(minutes=CODIGO_EXPIRACAO_MINUTOS)).isoformat()
    executar(
        "INSERT INTO usuarios (id, email, password_hash, nome, plano, status, criado_em, "
        "email_verificacao_token_hash, email_verificacao_expiracao) "
        "VALUES (?, ?, ?, ?, ?, 'pendente', ?, ?, ?)",
        (
            usuario_id,
            email,
            hash_senha(senha),
            nome.strip(),
            plano,
            agora.isoformat(),
            _hash_token(token),
            expiracao,
        ),
    ).commit()
    log.info("Usuario pendente criado: id=%s", usuario_id[:8])
    return token


def regenerar_token(email: str) -> str | None:
    email = email.strip().lower()
    usuario = obter_por_email(email)
    if usuario is None:
        return None
    agora = datetime.now(timezone.utc)
    token = _gerar_token()
    expiracao = (agora + timedelta(minutes=CODIGO_EXPIRACAO_MINUTOS)).isoformat()
    executar(
        "UPDATE usuarios SET email_verificacao_token_hash = ?, "
        "email_verificacao_expiracao = ? WHERE id = ?",
        (_hash_token(token), expiracao, usuario["id"]),
    ).commit()
    return token


def confirmar_email(token: str) -> dict | None:
    token_hash = _hash_token(token)
    cur = executar(
        "SELECT * FROM usuarios WHERE email_verificacao_token_hash = ?",
        (token_hash,),
    )
    usuario = cur.fetchone()
    if usuario is None:
        return None
    if usuario["email_verificacao_expiracao"]:
        try:
            expiracao = datetime.fromisoformat(usuario["email_verificacao_expiracao"])
            if datetime.now(timezone.utc) > expiracao:
                return None
        except Exception:
            return None
    # Idempotente: nao zera o token ao confirmar (ele fica valido ate a
    # expiracao). Assim, re-clique / scanner de email / duplo toque nao
    # exibem "Link invalido ou expirado" apos a conta ja estar ativa.
    if usuario["status"] != "ativo":
        executar(
            "UPDATE usuarios SET status = 'ativo' WHERE id = ?",
            (usuario["id"],),
        ).commit()
    log.info("Email confirmado (ou ja ativo): id=%s", usuario["id"][:8])
    return obter_por_id(usuario["id"])


def obter_por_email(email: str) -> dict | None:
    email = email.strip().lower()
    cur = executar("SELECT * FROM usuarios WHERE email = ?", (email,))
    return cur.fetchone()


def obter_por_id(usuario_id: str) -> dict | None:
    cur = executar("SELECT * FROM usuarios WHERE id = ?", (usuario_id,))
    return cur.fetchone()


def autenticar(email: str, senha: str) -> dict | None:
    usuario = obter_por_email(email)
    if usuario is None:
        return None
    if not verificar_senha(senha, usuario["password_hash"]):
        return None
    return usuario


def registrar_acesso(usuario_id: str) -> None:
    agora = datetime.now(timezone.utc).isoformat()
    executar(
        "UPDATE usuarios SET ultimo_acesso_em = ? WHERE id = ?",
        (agora, usuario_id),
    ).commit()
