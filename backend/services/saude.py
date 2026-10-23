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
    """Estado real do WhatsApp: consulta o wuzapi ao vivo e sincroniza o banco."""
    from services import wuzapi_admin

    configurado = bool(os.getenv("WUZAPI_BASE_URL", "").strip()) and bool(
        os.getenv("WUZAPI_ADMIN_TOKEN", "").strip()
    )
    linhas = executar(
        "SELECT owner_id, conectado FROM wuzapi_instancias ORDER BY atualizado_em DESC"
    ).fetchall()
    total = len(linhas)

    if not configurado:
        return ("atencao" if total else "info"), "serviço não configurado neste ambiente"
    if total == 0:
        return "ok", "configurado · nenhum WhatsApp conectado ainda"

    conectados = 0
    falhas_consulta = 0
    for linha in linhas[:5]:  # limite: mantém a Saúde rápida
        try:
            estado = wuzapi_admin.sincronizar_status(linha["owner_id"], timeout=3.0)
        except Exception:
            falhas_consulta += 1
            estado = {"conectado": bool(linha["conectado"])}
        if estado.get("conectado"):
            conectados += 1

    detalhe = f"{conectados} de {total} WhatsApp conectados"
    if conectados == total:
        return "ok", detalhe
    if falhas_consulta:
        detalhe += f" (consulta ao vivo falhou em {falhas_consulta})"
    return "atencao", detalhe


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
    """Atrasados e falhas recentes (7 dias); falhas antigas não poluem a Saúde."""
    agora = datetime.now(timezone.utc).isoformat()
    limite_7d = (datetime.now(timezone.utc) - timedelta(days=7)).isoformat()
    linha = executar(
        "SELECT "
        "(SELECT COUNT(*) FROM lembretes WHERE status = 'pendente' AND horario_envio < ?) AS atrasados, "
        "(SELECT COUNT(*) FROM lembretes WHERE status = 'falha' AND horario_envio >= ?) AS falhas_recentes, "
        "(SELECT COUNT(*) FROM lembretes WHERE status = 'falha' AND horario_envio < ?) AS falhas_antigas",
        (agora, limite_7d, limite_7d),
    ).fetchone()
    atrasados = int(linha["atrasados"] or 0)
    falhas_recentes = int(linha["falhas_recentes"] or 0)
    falhas_antigas = int(linha["falhas_antigas"] or 0)
    if atrasados:
        return "atencao", f"{atrasados} atrasado(s)"
    if falhas_recentes:
        return "atencao", f"{falhas_recentes} falha(s) nos últimos 7 dias"
    if falhas_antigas:
        return "ok", f"{falhas_antigas} falha(s) antigas (arquiváveis no painel)"
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
