"""Segurança do painel do dono (Fase 5B.1, 22/10/2026).

- TOTP (2FA) sem dependência externa (HMAC-SHA1 padrão RFC 6238, 6 dígitos, 30 s)
- Códigos de recuperação (backup) com hash
- Sessões administrativas com expiração por inatividade
- Revogação global ("sair de todos os dispositivos")

LGPD: aqui só existem segredos TOTP/hashes de códigos de sessão — nenhum dado
de paciente. Segredos nunca vão para log.
"""
import base64
import hashlib
import hmac
import json
import logging
import os
import secrets
import time
from datetime import datetime, timedelta, timezone
from urllib.parse import quote

from services.db import executar

log = logging.getLogger("mentall.admin.seguranca")

DIGITOS_TOTP = 6
PERIODO_TOTP = 30
JANELA_TOTP = 1  # aceita o passo anterior/próximo (relógio desalinhado)
BACKUP_CODES = 8
IDLE_MINUTOS_PADRAO = 60


def _agora() -> datetime:
    return datetime.now(timezone.utc)


def _iso() -> str:
    return _agora().isoformat()


# ---------------------------------------------------------------------------
# TOTP (RFC 6238)
# ---------------------------------------------------------------------------

def _segredo_normalizado(segredo: str) -> str:
    return (segredo or "").strip().upper().replace(" ", "").rstrip("=")


def _segredo_bytes(segredo: str) -> bytes:
    normalizado = _segredo_normalizado(segredo)
    preenchimento = "=" * ((8 - len(normalizado) % 8) % 8)
    return base64.b32decode(normalizado + preenchimento)


def _hotp(segredo: str, contador: int, digitos: int = DIGITOS_TOTP) -> str:
    resumo = hmac.new(
        _segredo_bytes(segredo), int(contador).to_bytes(8, "big"), hashlib.sha1
    ).digest()
    deslocamento = resumo[-1] & 0x0F
    valor = int.from_bytes(resumo[deslocamento:deslocamento + 4], "big") & 0x7FFFFFFF
    return str(valor % (10 ** digitos)).zfill(digitos)


def codigo_totp(segredo: str, quando: float | None = None, digitos: int = DIGITOS_TOTP) -> str:
    """Código TOTP para um instante (usado nos testes e na verificação)."""
    instante = quando if quando is not None else time.time()
    return _hotp(segredo, int(instante // PERIODO_TOTP), digitos)


def verificar_codigo_totp(segredo: str, codigo: str, janela: int = JANELA_TOTP) -> bool:
    codigo = (codigo or "").strip().replace(" ", "")
    if len(codigo) != DIGITOS_TOTP or not codigo.isdigit():
        return False
    contador = int(time.time() // PERIODO_TOTP)
    return any(
        hmac.compare_digest(codigo, _hotp(segredo, contador + passo))
        for passo in range(-janela, janela + 1)
    )


def gerar_segredo() -> str:
    return base64.b32encode(secrets.token_bytes(20)).decode().rstrip("=")


def uri_otpauth(segredo: str, ator: str, emissor: str = "MentAll PRO") -> str:
    rotulo = quote(f"{emissor}:{ator}", safe="")
    return (
        f"otpauth://totp/{rotulo}?secret={_segredo_normalizado(segredo)}"
        f"&issuer={quote(emissor, safe='')}&algorithm=SHA1&digits={DIGITOS_TOTP}"
        f"&period={PERIODO_TOTP}"
    )


# ---------------------------------------------------------------------------
# Estado por administrador
# ---------------------------------------------------------------------------

def _linha(ator: str):
    return executar(
        "SELECT totp_secret, totp_ativo, backup_hashes, atualizado_em "
        "FROM admin_seguranca WHERE ator = ?",
        (ator,),
    ).fetchone()


def estado(ator: str) -> dict:
    linha = _linha(ator)
    if not linha:
        return {"ativo": False, "pendente": False, "atualizado_em": "", "backup_restantes": 0}
    hashes = _hashes_backup(linha["backup_hashes"])
    return {
        "ativo": bool(linha["totp_ativo"]),
        "pendente": bool(linha["totp_secret"]) and not bool(linha["totp_ativo"]),
        "atualizado_em": linha["atualizado_em"] or "",
        "backup_restantes": len(hashes),
    }


def totp_ativo(ator: str) -> bool:
    return estado(ator)["ativo"]


def iniciar_ativacao(ator: str) -> dict:
    """Cria um segredo pendente e devolve segredo + URI para o app autenticador."""
    segredo = gerar_segredo()
    executar(
        "INSERT INTO admin_seguranca (ator, totp_secret, totp_ativo, backup_hashes, atualizado_em) "
        "VALUES (?, ?, 0, '', ?) ON CONFLICT(ator) DO UPDATE SET "
        "totp_secret = excluded.totp_secret, totp_ativo = 0, backup_hashes = '', "
        "atualizado_em = excluded.atualizado_em",
        (ator, segredo, _iso()),
    ).commit()
    return {"segredo": segredo, "uri": uri_otpauth(segredo, ator)}


def _hashes_backup(bruto: str) -> list:
    try:
        dados = json.loads(bruto or "[]")
        return dados if isinstance(dados, list) else []
    except (TypeError, ValueError):
        return []


def _hash_codigo(codigo: str) -> str:
    return hashlib.sha256((codigo or "").strip().upper().replace(" ", "").encode()).hexdigest()


def confirmar_ativacao(ator: str, codigo: str) -> list[str] | None:
    """Confirma o código do app e ativa; devolve os códigos de recuperação (1×)."""
    linha = _linha(ator)
    if not linha or not linha["totp_secret"]:
        return None
    if not verificar_codigo_totp(linha["totp_secret"], codigo):
        return None
    codigos = [secrets.token_hex(4).upper() for _ in range(BACKUP_CODES)]
    hashes = [_hash_codigo(c) for c in codigos]
    executar(
        "UPDATE admin_seguranca SET totp_ativo = 1, backup_hashes = ?, atualizado_em = ? "
        "WHERE ator = ?",
        (json.dumps(hashes), _iso(), ator),
    ).commit()
    log.info("2FA ativado para administrador.")
    return codigos


def desativar(ator: str) -> None:
    executar("DELETE FROM admin_seguranca WHERE ator = ?", (ator,)).commit()
    log.info("2FA desativado para administrador.")


def validar_codigo(ator: str, codigo: str) -> bool:
    """Aceita código TOTP ou consome um código de recuperação."""
    linha = _linha(ator)
    if not linha or not linha["totp_ativo"]:
        return False
    codigo = (codigo or "").strip().upper().replace(" ", "")
    if verificar_codigo_totp(linha["totp_secret"], codigo):
        return True
    hashes = _hashes_backup(linha["backup_hashes"])
    alvo = _hash_codigo(codigo)
    if alvo in hashes:
        hashes.remove(alvo)
        executar(
            "UPDATE admin_seguranca SET backup_hashes = ?, atualizado_em = ? WHERE ator = ?",
            (json.dumps(hashes), _iso(), ator),
        ).commit()
        return True
    return False


def obrigatorio() -> bool:
    return os.getenv("ADMIN_2FA_OBRIGATORIO", "false").strip().lower() in ("1", "true", "yes", "on")


# ---------------------------------------------------------------------------
# Sessões administrativas (expiração por inatividade + revogação global)
# ---------------------------------------------------------------------------

def idle_minutos() -> int:
    try:
        return max(5, int(os.getenv("ADMIN_IDLE_MINUTOS", str(IDLE_MINUTOS_PADRAO))))
    except (TypeError, ValueError):
        return IDLE_MINUTOS_PADRAO


def registrar_sessao(jti: str, ator: str) -> None:
    if not jti:
        return
    agora = _iso()
    executar(
        "INSERT INTO admin_sessoes (jti, ator, criado_em, ultimo_visto_em) VALUES (?, ?, ?, ?) "
        "ON CONFLICT(jti) DO UPDATE SET ultimo_visto_em = excluded.ultimo_visto_em",
        (jti, ator, agora, agora),
    ).commit()


def sessao_valida(jti: str, ator: str) -> bool:
    """False se a sessão não existe/diverge ou ficou ociosa além do limite."""
    if not jti:
        return False
    linha = executar(
        "SELECT ator, ultimo_visto_em FROM admin_sessoes WHERE jti = ?", (jti,)
    ).fetchone()
    if linha is None:
        # Cookie emitido antes desta versão (ou por teste): cria a sessão agora.
        registrar_sessao(jti, ator)
        return True
    if (linha["ator"] or "") != ator:
        return False
    try:
        visto = datetime.fromisoformat(linha["ultimo_visto_em"])
    except (TypeError, ValueError):
        return False
    agora = _agora()
    if agora - visto > timedelta(minutes=idle_minutos()):
        return False
    if agora - visto > timedelta(seconds=60):
        executar(
            "UPDATE admin_sessoes SET ultimo_visto_em = ? WHERE jti = ?", (_iso(), jti)
        ).commit()
    return True


def encerrar_sessao(jti: str) -> None:
    if not jti:
        return
    executar("DELETE FROM admin_sessoes WHERE jti = ?", (jti,)).commit()


def revogar_todas_sessoes(ator: str) -> int:
    """Revoga todos os cookies do admin (inclusive este) e encerra as sessões."""
    linhas = executar("SELECT jti FROM admin_sessoes WHERE ator = ?", (ator,)).fetchall()
    agora = _iso()
    for linha in linhas:
        executar(
            "INSERT OR REPLACE INTO tokens_revogados (jti, exp, criado_em) VALUES (?, '', ?)",
            (linha["jti"], agora),
        ).commit()
    executar("DELETE FROM admin_sessoes WHERE ator = ?", (ator,)).commit()
    return len(linhas)
