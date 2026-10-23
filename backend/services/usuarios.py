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


def criar_usuario_pendente(email: str, senha: str, nome: str = "", plano: str = "gratis") -> str | None:
    email = email.strip().lower()
    usuario_id = str(uuid.uuid4())
    agora = datetime.now(timezone.utc)
    token = _gerar_token()
    expiracao = (agora + timedelta(minutes=CODIGO_EXPIRACAO_MINUTOS)).isoformat()
    # One statement binds each confirmation token to exactly one set of credentials.
    # A concurrent confirmation wins over this write once the account is active.
    cur = executar(
        "INSERT INTO usuarios (id, email, password_hash, nome, plano, status, criado_em, "
        "email_verificacao_token_hash, email_verificacao_expiracao) "
        "VALUES (?, ?, ?, ?, ?, 'pendente', ?, ?, ?) "
        "ON CONFLICT(email) DO UPDATE SET "
        "password_hash = excluded.password_hash, nome = excluded.nome, "
        "email_verificacao_token_hash = excluded.email_verificacao_token_hash, "
        "email_verificacao_expiracao = excluded.email_verificacao_expiracao "
        "WHERE usuarios.status = 'pendente'",
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
    )
    cur.commit()
    if cur.rowcount != 1:
        return None
    log.info("Tentativa de cadastro pendente registrada.")
    return token


def confirmar_email(token: str) -> dict | None:
    token_hash = _hash_token(token)
    cur = executar(
        "SELECT * FROM usuarios WHERE email_verificacao_token_hash = ?",
        (token_hash,),
    )
    usuario = cur.fetchone()
    if usuario is None or usuario["status"] not in ("pendente", "ativo"):
        return None
    try:
        expiracao = datetime.fromisoformat(usuario["email_verificacao_expiracao"])
        if datetime.now(timezone.utc) >= expiracao:
            return None
    except (TypeError, ValueError):
        return None
    # Idempotente: nao zera o token ao confirmar (ele fica valido ate a
    # expiracao). Assim, re-clique / scanner de email / duplo toque nao
    # exibem "Link invalido ou expirado" apos a conta ja estar ativa.
    if usuario["status"] == "pendente":
        executar(
            "UPDATE usuarios SET status = 'ativo' WHERE id = ? "
            "AND status = 'pendente' AND email_verificacao_token_hash = ? "
            "AND email_verificacao_expiracao = ? "
            "AND julianday(email_verificacao_expiracao) > julianday('now')",
            (usuario["id"], token_hash, usuario["email_verificacao_expiracao"]),
        ).commit()
    # Do not report success from a stale SELECT after a token rotation/suspension.
    atual = obter_por_id(usuario["id"])
    if (atual is None or atual["status"] != "ativo"
            or atual["email_verificacao_token_hash"] != token_hash
            or atual["email_verificacao_expiracao"] != usuario["email_verificacao_expiracao"]
            or datetime.now(timezone.utc) >= expiracao):
        return None
    log.info("Email confirmado (ou ja ativo): id=%s", usuario["id"][:8])
    return atual


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


def redefinir_senha(email: str, nova_senha: str) -> bool:
    """Troca o password_hash da conta. Retorna False se o e-mail nao existir."""
    email = email.strip().lower()
    cur = executar(
        "UPDATE usuarios SET password_hash = ? WHERE email = ?",
        (hash_senha(nova_senha), email),
    )
    cur.commit()
    return cur.rowcount == 1


def registrar_acesso(usuario_id: str) -> None:
    agora = datetime.now(timezone.utc).isoformat()
    executar(
        "UPDATE usuarios SET ultimo_acesso_em = ? WHERE id = ?",
        (agora, usuario_id),
    ).commit()


def renovar_token_confirmacao(email: str) -> str | None:
    """Gera um novo token de confirmação para uma conta pendente.

    Retorna None se o e-mail não existir ou a conta já estiver confirmada
    (o painel não deve reenviar confirmação para quem já está ativo).
    """
    email = email.strip().lower()
    token = _gerar_token()
    expiracao = (datetime.now(timezone.utc) + timedelta(minutes=CODIGO_EXPIRACAO_MINUTOS)).isoformat()
    cur = executar(
        "UPDATE usuarios SET email_verificacao_token_hash = ?, email_verificacao_expiracao = ? "
        "WHERE email = ? AND status = 'pendente'",
        (_hash_token(token), expiracao, email),
    )
    cur.commit()
    return token if cur.rowcount == 1 else None


def incrementar_token_version(usuario_id: str) -> int:
    """Invalida todos os JWT de app já emitidos para o usuário.

    O token carrega a versão atual (claim "tv"); quando ela muda, o token antigo
    deixa de valer — é o "sair de todos os dispositivos" do lado do app.
    """
    executar(
        "UPDATE usuarios SET token_version = COALESCE(token_version, 0) + 1 WHERE id = ?",
        (usuario_id,),
    ).commit()
    linha = executar("SELECT token_version FROM usuarios WHERE id = ?", (usuario_id,)).fetchone()
    return int(linha["token_version"]) if linha else 0
