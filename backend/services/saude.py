"""Saúde operacional do sistema para o painel do dono (Fase 5A).

Cada verificação é isolada: uma falha não derruba o painel nem esconde as
demais. Nenhuma delas lê conteúdo clínico — só estado de serviço.

Estados possíveis:
  ok      → funcionando
  atencao → funcionando com ressalva (ex.: fallback de banco, WhatsApp caído)
  erro    → quebrado ou não configurado quando deveria estar
  info    → opcional/não configurado neste ambiente (não é problema)
"""
import logging
import os
import time
from datetime import datetime, timedelta, timezone

from services.db import executar

log = logging.getLogger("mentall.saude")

TIMEOUT_VERIFICACAO_EXTERNA = 4.0


def _resultado(nome: str, estado: str, detalhe: str, ms: int | None = None) -> dict:
    return {"nome": nome, "estado": estado, "detalhe": detalhe, "ms": ms}


def _cronometrado(nome: str, verificar) -> dict:
    inicio = time.perf_counter()
    try:
        estado, detalhe = verificar()
    except Exception as exc:  # noqa: BLE001 - saúde nunca deve levantar
        log.warning("Verificação de saúde '%s' falhou: %s", nome, exc)
        estado, detalhe = "erro", "falha ao verificar"
    ms = round((time.perf_counter() - inicio) * 1000)
    return _resultado(nome, estado, detalhe, ms)


# ---------------------------------------------------------------------------
# Verificações
# ---------------------------------------------------------------------------

def _banco():
    linha = executar("SELECT 1 AS ok").fetchone()
    if not linha:
        return "erro", "sem resposta do banco"
    from services.db import _usa_turso

    if _usa_turso:
        return "ok", "Turso (nuvem)"
    if os.getenv("SQLITE_PATH", "").strip():
        return "ok", "SQLite local (volume — persistente)"
    return "atencao", "SQLite local (fallback — persistência não garantida em produção)"


def _ia_sintese():
    """Cadeia de IA de texto (síntese, progresso, artigos)."""
    from services import ia_clinica

    provedor = os.getenv("IA_MODEL_PROVIDER", "openai").strip().lower()
    ordem = ia_clinica._ordem_providers()
    abertos = [p for p in ordem if not ia_clinica._provedor_disponivel(p)]
    if abertos:
        return "atencao", f"provedor base {provedor} · circuito aberto: {', '.join(abertos)}"
    if not ordem:
        return "erro", "nenhum provedor de IA configurado"
    return "ok", f"provedor base {provedor} · disponíveis: {', '.join(ordem)}"


# Compatibilidade: nome antigo (usado em versões anteriores do painel/testes).
_ia = _ia_sintese


def _transcricao():
    """Configuração e última falha da IA de transcrição (Groq/OpenAI Whisper)."""
    from services import transcricao

    provider = os.getenv("TRANSCRICAO_PROVIDER", "groq").strip().lower()
    modelo = transcricao._get_transcricao_model()
    chave = "GROQ_API_KEY" if provider == "groq" else "OPENAI_API_KEY"
    if not os.getenv(chave, "").strip():
        return "erro", f"{provider}/{modelo} · {chave} não configurada"
    falha = transcricao.ultima_falha()
    if falha:
        try:
            quando = datetime.fromisoformat(falha["quando"])
        except (TypeError, ValueError):
            quando = None
        if quando is not None:
            idade = datetime.now(timezone.utc) - quando
            if idade < timedelta(hours=24):
                horas = max(1, int(idade.total_seconds() // 3600))
                return "atencao", (
                    f"{provider}/{modelo} · última falha há {horas}h: "
                    f"{str(falha.get('mensagem') or '')[:80]}"
                )
    return "ok", f"{provider}/{modelo} · chave configurada"


def _wuzapi():
    total = executar("SELECT COUNT(*) AS n FROM wuzapi_instancias").fetchone()["n"]
    conectados = executar(
        "SELECT COUNT(*) AS n FROM wuzapi_instancias WHERE conectado = 1"
    ).fetchone()["n"]
    configurado = bool(os.getenv("WUZAPI_BASE_URL", "").strip()) and bool(
        os.getenv("WUZAPI_ADMIN_TOKEN", "").strip()
    )
    if not configurado:
        return ("atencao" if total else "info"), "serviço não configurado neste ambiente"
    if total == 0:
        return "ok", "configurado · nenhum WhatsApp conectado ainda"
    if conectados == 0:
        return "atencao", f"configurado · 0 de {total} WhatsApp conectados"
    return "ok", f"configurado · {conectados} de {total} WhatsApp conectados"


def _mailu():
    from services import email_admin

    if not email_admin.configurado():
        return "info", "integração não configurada"
    caixas = email_admin.listar_caixas(timeout=TIMEOUT_VERIFICACAO_EXTERNA)
    ativas = sum(1 for c in caixas if c.get("ativo"))
    return "ok", f"{len(caixas)} caixas ({ativas} ativas)"


def _smtp():
    host = os.getenv("SMTP_HOST", "").strip()
    if not host:
        return "erro", "SMTP não configurado (recuperação de senha/cadastro falham)"
    porta = os.getenv("SMTP_PORT", "587")
    return "ok", f"{host}:{porta} configurado"


def _lembretes():
    agora = datetime.now(timezone.utc).isoformat()
    atrasados = executar(
        "SELECT COUNT(*) AS n FROM lembretes WHERE status = 'pendente' AND horario_envio < ?",
        (agora,),
    ).fetchone()["n"]
    falhas = executar(
        "SELECT COUNT(*) AS n FROM lembretes WHERE status = 'falha'"
    ).fetchone()["n"]
    if atrasados or falhas:
        partes = []
        if atrasados:
            partes.append(f"{atrasados} atrasado(s)")
        if falhas:
            partes.append(f"{falhas} com falha")
        return "atencao", " · ".join(partes)
    return "ok", "sem atrasos nem falhas"


_VERIFICACOES = (
    ("Banco de dados", _banco),
    ("IA de síntese", _ia_sintese),
    ("Transcrição", _transcricao),
    ("WhatsApp (Wuzapi)", _wuzapi),
    ("E-mail (Mailu)", _mailu),
    ("SMTP de cadastro", _smtp),
    ("Lembretes", _lembretes),
)


def coletar() -> list[dict]:
    """Executa todas as verificações e devolve o estado atual do sistema."""
    return [_cronometrado(nome, verificar) for nome, verificar in _VERIFICACOES]
