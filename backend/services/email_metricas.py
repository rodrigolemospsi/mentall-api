"""Métricas das caixas de e-mail via IMAP (somente leitura) — Fase 5M.

Regras de segurança/privacidade:
- só contadores e tempos são retornados (nenhum assunto/corpo/remetente é exposto);
- SELECT é sempre `readonly=True` e os headers são lidos com BODY.PEEK (nunca
  marcam mensagens como lidas);
- credenciais vêm do secret `MAIL_METRICAS_CAIXAS` (JSON: [{email, senha, rotulo}]).

As métricas são: total, não lidas, recebidas hoje/7d/30d, enviadas 30d, tempo
médio de resposta, respondidas 30d, sem resposta há +24h e última entrada.
"""
import email
import imaplib
import json
import logging
import os
import re
import threading
import time
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime

log = logging.getLogger("mentall.email_metricas")

SERVIDOR = os.getenv("MAIL_IMAP_HOST", "mail.mentallpro.com.br")
PORTA = int(os.getenv("MAIL_IMAP_PORT", "993"))
TIMEOUT = float(os.getenv("MAIL_IMAP_TIMEOUT", "20"))
CACHE_TTL = int(os.getenv("MAIL_METRICAS_CACHE_SEGUNDOS", "300"))
DIAS = int(os.getenv("MAIL_METRICAS_DIAS", "30"))
LIMITE = int(os.getenv("MAIL_METRICAS_LIMITE_MENSAGENS", "120"))
DOMINIO_PROPRIO = os.getenv("MAIL_DOMINIO", "mentallpro.com.br").lower()
ENDERECOS = tuple(
    e.strip().lower()
    for e in os.getenv("MAIL_METRICAS_ENDERECOS", "contato@,suporte@,financeiro@").split(",")
    if e.strip()
)

_CAMPOS = (
    "(BODY.PEEK[HEADER.FIELDS (FROM TO CC DATE MESSAGE-ID IN-REPLY-TO REFERENCES)])"
)

_cache = {"expira_em": 0.0, "dados": None}
_cache_lock = threading.Lock()


# ---------------------------------------------------------------------------
# Configuração
# ---------------------------------------------------------------------------

def caixas_configuradas() -> list[dict]:
    bruto = (os.getenv("MAIL_METRICAS_CAIXAS") or "").strip()
    if not bruto:
        return []
    try:
        dados = json.loads(bruto)
    except ValueError:
        log.error("MAIL_METRICAS_CAIXAS não é um JSON válido")
        return []
    caixas = []
    for item in dados if isinstance(dados, list) else []:
        if not isinstance(item, dict):
            continue
        endereco = str(item.get("email") or "").strip().lower()
        senha = str(item.get("senha") or "")
        if not endereco or not senha:
            continue
        caixas.append({
            "email": endereco,
            "senha": senha,
            "rotulo": str(item.get("rotulo") or endereco),
        })
    return caixas


def configurado() -> bool:
    return bool(caixas_configuradas())


# ---------------------------------------------------------------------------
# Helpers de parsing (puros — testáveis sem rede)
# ---------------------------------------------------------------------------

def _parse_data(valor) -> datetime | None:
    try:
        dt = parsedate_to_datetime(str(valor))
    except (TypeError, ValueError):
        return None
    if dt is None:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _normalizar_message_id(valor) -> str:
    texto = str(valor or "").strip()
    if not texto:
        return ""
    texto = texto.split()[0]
    return texto if texto.startswith("<") else f"<{texto}>"


def _referencias(msg) -> set:
    refs = set()
    for campo in ("In-Reply-To", "References"):
        for parte in str(msg.get(campo) or "").split():
            ref = _normalizar_message_id(parte)
            if ref:
                refs.add(ref)
    return refs


def _iso(valor: datetime | None) -> str:
    return valor.isoformat() if valor else ""


def _buscar_ids(conexao, desde: datetime) -> list:
    criterio = f'(SINCE {desde.strftime("%d-%b-%Y")})'
    try:
        tip, dados = conexao.search(None, criterio)
    except Exception:
        return []
    if tip != "OK" or not dados or not dados[0]:
        return []
    return dados[0].split()


def _cabecalhos(conexao, ids: list) -> list[dict]:
    resultado = []
    for mid in ids:
        try:
            tip, dados = conexao.fetch(mid, _CAMPOS)
        except Exception:
            continue
        if tip != "OK" or not dados:
            continue
        bruto = next((p[1] for p in dados if isinstance(p, tuple)), b"")
        if not bruto:
            continue
        msg = email.message_from_bytes(bruto)
        resultado.append({
            "data": _parse_data(msg.get("Date")),
            "message_id": _normalizar_message_id(msg.get("Message-ID")),
            "refs": _referencias(msg),
            "para": f"{msg.get('To') or ''} {msg.get('Cc') or ''}".lower(),
            "de": f"{msg.get('From') or ''}".lower(),
        })
    return resultado


def _metricas_por_endereco(inicio_7d: datetime, headers_in: list[dict]) -> dict:
    contagem = {}
    for endereco in ENDERECOS:
        com_7d = [
            h for h in headers_in
            if h["data"] and h["data"] >= inicio_7d and endereco in h["para"]
        ]
        com_30d = [h for h in headers_in if endereco in h["para"]]
        contagem[endereco] = {
            "recebidas_7d": len(com_7d),
            "recebidas_30d": len(com_30d),
        }
    return contagem


# ---------------------------------------------------------------------------
# Coleta
# ---------------------------------------------------------------------------

def _coletar_caixa(caixa: dict, agora: datetime) -> dict:
    inicio_30d = agora - timedelta(days=DIAS)
    inicio_7d = agora - timedelta(days=7)
    inicio_hoje = agora.replace(hour=0, minute=0, second=0, microsecond=0)

    resultado = {
        "email": caixa["email"],
        "rotulo": caixa["rotulo"],
        "total": 0,
        "nao_lidas": 0,
        "recebidas_hoje": 0,
        "recebidas_7d": 0,
        "recebidas_30d": 0,
        "enviadas_30d": 0,
        "respondidas_30d": 0,
        "tempo_medio_resposta_min": None,
        "sem_resposta_24h": 0,
        "ultima_entrada": "",
        "por_endereco": {},
        "erro": "",
    }
    conexao = None
    try:
        conexao = imaplib.IMAP4_SSL(SERVIDOR, PORTA, timeout=TIMEOUT)
        conexao.login(caixa["email"], caixa["senha"])

        tip, dados = conexao.status("INBOX", "(MESSAGES UNSEEN)")
        texto = dados[0].decode(errors="ignore") if dados else ""
        mensagens = re.search(r"MESSAGES (\d+)", texto)
        nao_lidas = re.search(r"UNSEEN (\d+)", texto)
        resultado["total"] = int(mensagens.group(1)) if mensagens else 0
        resultado["nao_lidas"] = int(nao_lidas.group(1)) if nao_lidas else 0

        conexao.select("INBOX", readonly=True)
        ids_30 = _buscar_ids(conexao, inicio_30d)
        resultado["recebidas_30d"] = len(ids_30)
        resultado["recebidas_7d"] = len(_buscar_ids(conexao, inicio_7d))
        resultado["recebidas_hoje"] = len(_buscar_ids(conexao, inicio_hoje))
        headers_in = _cabecalhos(conexao, ids_30[-LIMITE:])

        datas = [h["data"] for h in headers_in if h["data"]]
        if datas:
            resultado["ultima_entrada"] = _iso(max(datas))
        resultado["por_endereco"] = _metricas_por_endereco(inicio_7d, headers_in)

        # Respostas: pareia In-Reply-To/References do Sent com Message-ID do INBOX.
        ids_sent = []
        try:
            conexao.select("Sent", readonly=True)
            ids_sent = _buscar_ids(conexao, inicio_30d)
        except Exception:
            ids_sent = []
        resultado["enviadas_30d"] = len(ids_sent)
        headers_out = _cabecalhos(conexao, ids_sent[-LIMITE:])

        mapa_entrada = {
            h["message_id"]: h["data"]
            for h in headers_in
            if h["message_id"] and h["data"]
        }
        tempos = []
        respondidas = set()
        for h in headers_out:
            if not h["data"]:
                continue
            for ref in h["refs"]:
                if ref in mapa_entrada:
                    delta = (h["data"] - mapa_entrada[ref]).total_seconds()
                    if 0 <= delta <= DIAS * 86400:
                        tempos.append(delta / 60)
                        respondidas.add(ref)
                    break
        resultado["respondidas_30d"] = len(respondidas)
        resultado["tempo_medio_resposta_min"] = (
            round(sum(tempos) / len(tempos), 1) if tempos else None
        )

        limite_24h = agora - timedelta(hours=24)
        pendentes = 0
        for h in headers_in:
            if not h["data"] or h["data"] > limite_24h:
                continue
            if h["message_id"] in respondidas:
                continue
            if DOMINIO_PROPRIO in h["de"]:
                continue  # e-mails internos não contam como pendência
            pendentes += 1
        resultado["sem_resposta_24h"] = pendentes

    except Exception as exc:  # credencial errada, timeout, servidor fora…
        resultado["erro"] = f"{type(exc).__name__}: {exc}"[:160]
        log.warning("Falha ao coletar métricas de %s: %s", caixa["email"], exc)
    finally:
        try:
            if conexao is not None:
                conexao.logout()
        except Exception:
            pass
    return resultado


def _agregar(caixas: list[dict]) -> dict:
    total_30d = sum(c["recebidas_30d"] for c in caixas)
    nao_lidas = sum(c["nao_lidas"] for c in caixas)
    pendentes = sum(c["sem_resposta_24h"] for c in caixas)
    tempos = [
        (c["tempo_medio_resposta_min"], c["respondidas_30d"])
        for c in caixas
        if c["tempo_medio_resposta_min"] is not None and c["respondidas_30d"]
    ]
    tempo_medio = round(
        sum(t * n for t, n in tempos) / sum(n for _, n in tempos), 1
    ) if tempos else None
    return {
        "recebidas_30d": total_30d,
        "nao_lidas": nao_lidas,
        "sem_resposta_24h": pendentes,
        "tempo_medio_resposta_min": tempo_medio,
        "caixas": len(caixas),
    }


def coletar(force: bool = False) -> dict:
    """Coleta (com cache em memória) as métricas das caixas configuradas."""
    caixas = caixas_configuradas()
    if not caixas:
        return {
            "configurado": False,
            "gerado_em": "",
            "totais": {},
            "caixas": [],
            "por_endereco": [],
        }

    agora_epoch = time.time()
    with _cache_lock:
        if (
            not force
            and _cache["dados"] is not None
            and _cache["expira_em"] > agora_epoch
        ):
            return _cache["dados"]

    agora = datetime.now(timezone.utc)
    resultados = [_coletar_caixa(caixa, agora) for caixa in caixas]

    por_endereco = []
    for endereco in ENDERECOS:
        item = {"endereco": endereco, "recebidas_7d": 0, "recebidas_30d": 0}
        for caixa in resultados:
            dados = (caixa.get("por_endereco") or {}).get(endereco) or {}
            item["recebidas_7d"] += int(dados.get("recebidas_7d") or 0)
            item["recebidas_30d"] += int(dados.get("recebidas_30d") or 0)
        por_endereco.append(item)

    dados = {
        "configurado": True,
        "gerado_em": agora.isoformat(),
        "totais": _agregar(resultados),
        "caixas": resultados,
        "por_endereco": por_endereco,
    }
    with _cache_lock:
        _cache["dados"] = dados
        _cache["expira_em"] = time.time() + CACHE_TTL
    return dados


def limpar_cache() -> None:
    with _cache_lock:
        _cache["dados"] = None
        _cache["expira_em"] = 0.0
