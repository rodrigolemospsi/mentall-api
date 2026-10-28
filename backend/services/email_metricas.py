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
from datetime import time as hora_do_dia
from email.utils import parsedate_to_datetime
from zoneinfo import ZoneInfo

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

SLAS_PADRAO = {"contato@": 24.0, "suporte@": 4.0, "financeiro@": 24.0}

# Janela de atendimento (horário de Brasília). Fora dela, o relógio do SLA para.
FUSO_BRASILIA = ZoneInfo("America/Sao_Paulo")
HORA_INICIO = int(os.getenv("MAIL_SLA_INICIO_HORA", "8"))
HORA_FIM = int(os.getenv("MAIL_SLA_FIM_HORA", "18"))
# Sábado tem janela própria (padrão 8h-13h). Domingo fica fechado.
SABADO_INICIO = int(os.getenv("MAIL_SLA_SABADO_INICIO_HORA", "8"))
SABADO_FIM = int(os.getenv("MAIL_SLA_SABADO_FIM_HORA", "13"))


def _janela_do_dia(dia) -> tuple[int, int] | None:
    """Janela de atendimento do dia: seg-sex 8-18, sábado 8-13, domingo fechado."""
    if dia.weekday() <= 4:
        return HORA_INICIO, HORA_FIM
    if dia.weekday() == 5:
        return (SABADO_INICIO, SABADO_FIM) if SABADO_FIM > SABADO_INICIO else None
    return None


def _minutos_uteis(inicio: datetime | None, fim: datetime | None) -> float:
    """Minutos decorridos dentro da janela de atendimento (Brasília).

    Segunda a sexta: 8h-18h. Sábado: 8h-13h. Domingo: fechado.
    Fora da janela o relógio do SLA fica parado.
    """
    if not inicio or not fim:
        return 0.0
    ini = inicio.astimezone(FUSO_BRASILIA)
    final = fim.astimezone(FUSO_BRASILIA)
    if final <= ini:
        return 0.0
    total = 0.0
    dia = ini.date()
    while dia <= final.date():
        janela = _janela_do_dia(dia)
        if janela:
            abertura = datetime.combine(dia, hora_do_dia(janela[0]), tzinfo=FUSO_BRASILIA)
            fechamento = datetime.combine(dia, hora_do_dia(janela[1]), tzinfo=FUSO_BRASILIA)
            trecho_ini = max(ini, abertura)
            trecho_fim = min(final, fechamento)
            if trecho_fim > trecho_ini:
                total += (trecho_fim - trecho_ini).total_seconds()
        dia += timedelta(days=1)
    return total / 60.0


def _slas() -> dict:
    """SLA (horas de primeira resposta) por endereço; configurável by env."""
    bruto = (os.getenv("MAIL_SLA_HORAS") or "").strip()
    slas = dict(SLAS_PADRAO)
    if bruto:
        try:
            dados = json.loads(bruto)
        except ValueError:
            dados = {}
        if isinstance(dados, dict):
            for chave, valor in dados.items():
                try:
                    slas[str(chave).strip().lower()] = float(valor)
                except (TypeError, ValueError):
                    continue
    return {chave: valor for chave, valor in slas.items() if chave in ENDERECOS}


_CAMPOS = (
    "(BODY.PEEK[HEADER.FIELDS "
    "(FROM TO CC DATE MESSAGE-ID IN-REPLY-TO REFERENCES AUTO-SUBMITTED PRECEDENCE X-AUTORESPONDER)])"
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

_PADRAO_AUTOMATICO = re.compile(
    r"(?:^(?:noreply|no-reply|nao-?responda|postmaster|mailer-?daemon|bounce|"
    r"do-?not-?reply|automated)(?:[._+-]|$))|dmarc",
    re.IGNORECASE,
)


def _remetente_automatico(from_header: str, auto_submitted: str = "", precedencia: str = "") -> bool:
    """True para relatórios/notificações que não exigem resposta humana."""
    auto = (auto_submitted or "").strip().lower()
    if auto and auto != "no":
        return True
    if (precedencia or "").strip().lower() in ("bulk", "list", "junk"):
        return True
    endereco = ""
    try:
        from email.utils import parseaddr

        endereco = parseaddr(from_header or "")[1] or ""
    except Exception:
        endereco = ""
    local = endereco.split("@")[0].strip().lower() if "@" in endereco else ""
    return bool(local and _PADRAO_AUTOMATICO.search(local))


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
        from_header = f"{msg.get('From') or ''}"
        resultado.append({
            "data": _parse_data(msg.get("Date")),
            "message_id": _normalizar_message_id(msg.get("Message-ID")),
            "refs": _referencias(msg),
            "para": f"{msg.get('To') or ''} {msg.get('Cc') or ''}".lower(),
            "de": from_header.lower(),
            "automatico": _remetente_automatico(
                from_header, msg.get("Auto-Submitted") or "", msg.get("Precedence") or ""
            ),
        })
    return resultado


def _metricas_por_endereco(
    inicio_7d: datetime,
    headers_in: list[dict],
    resposta_por_mid: dict,
    agora: datetime,
    slas: dict,
) -> dict:
    """Métricas por endereço de destino, incluindo SLA de primeira resposta."""
    contagem = {}
    for endereco in ENDERECOS:
        sla = slas.get(endereco)
        com_7d = [
            h for h in headers_in
            if h.get("data")
            and h["data"] >= inicio_7d
            and endereco in (h.get("para") or "")
            and DOMINIO_PROPRIO not in (h.get("de") or "")
        ]
        com_30d = [
            h
            for h in headers_in
            if endereco in (h.get("para") or "")
            and DOMINIO_PROPRIO not in (h.get("de") or "")
        ]
        respondidas = 0
        tempos = []
        violacoes = 0
        pendentes_sla = 0
        for h in com_30d:
            if not h.get("data"):
                continue
            resposta = resposta_por_mid.get(h.get("message_id"))
            if resposta is not None:
                respondidas += 1
                tempos.append(resposta)
                if sla is not None and resposta > sla * 60:
                    violacoes += 1
            else:
                idade_horas = _minutos_uteis(h["data"], agora) / 60.0
                if sla is not None and idade_horas > sla:
                    violacoes += 1
                    pendentes_sla += 1
        contagem[endereco] = {
            "recebidas_7d": len(com_7d),
            "recebidas_30d": len(com_30d),
            "respondidas_30d": respondidas,
            "tempo_medio_resposta_min": round(sum(tempos) / len(tempos), 1) if tempos else None,
            "sla_horas": sla,
            "violacoes_sla": violacoes,
            "pendentes_sla": pendentes_sla,
        }
    return contagem


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
        "violacoes_sla": 0,
        "pendentes_sla": 0,
        "ignorados_automaticos": 0,
        "ultima_entrada": "",
        "por_endereco": {},
        "serie_dias": {},
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
        headers_in_todos = _cabecalhos(conexao, ids_30[-LIMITE:])
        headers_in = [h for h in headers_in_todos if not h.get("automatico")]
        resultado["ignorados_automaticos"] = len(headers_in_todos) - len(headers_in)

        datas = [h["data"] for h in headers_in if h["data"]]
        if datas:
            resultado["ultima_entrada"] = _iso(max(datas))
        serie = {}
        for h in headers_in:
            if h["data"]:
                dia = h["data"].date().isoformat()
                serie[dia] = serie.get(dia, 0) + 1
        resultado["serie_dias"] = serie

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
        resposta_por_mid = {}
        for h in headers_out:
            if not h["data"]:
                continue
            for ref in h["refs"]:
                if ref in mapa_entrada:
                    delta = (h["data"] - mapa_entrada[ref]).total_seconds()
                    if 0 <= delta <= DIAS * 86400:
                        minutos = _minutos_uteis(mapa_entrada[ref], h["data"])
                        tempos.append(minutos)
                        respondidas.add(ref)
                        anterior = resposta_por_mid.get(ref)
                        if anterior is None or minutos < anterior:
                            resposta_por_mid[ref] = minutos
                    break
        resultado["respondidas_30d"] = len(respondidas)
        resultado["tempo_medio_resposta_min"] = (
            round(sum(tempos) / len(tempos), 1) if tempos else None
        )

        slas = _slas()
        resultado["por_endereco"] = _metricas_por_endereco(
            inicio_7d, headers_in, resposta_por_mid, agora, slas
        )
        resultado["violacoes_sla"] = sum(
            int(item.get("violacoes_sla") or 0)
            for item in resultado["por_endereco"].values()
        )
        resultado["pendentes_sla"] = sum(
            int(item.get("pendentes_sla") or 0)
            for item in resultado["por_endereco"].values()
        )

        pendentes = 0
        for h in headers_in:
            if not h["data"]:
                continue
            if _minutos_uteis(h["data"], agora) <= 24 * 60:
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
        "violacoes_sla": sum(int(c.get("violacoes_sla") or 0) for c in caixas),
        "pendentes_sla": sum(int(c.get("pendentes_sla") or 0) for c in caixas),
        "ignorados_automaticos": sum(int(c.get("ignorados_automaticos") or 0) for c in caixas),
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

    slas = _slas()
    por_endereco = []
    for endereco in ENDERECOS:
        item = {
            "endereco": endereco,
            "sla_horas": slas.get(endereco),
            "recebidas_7d": 0,
            "recebidas_30d": 0,
            "respondidas_30d": 0,
            "tempo_medio_resposta_min": None,
            "violacoes_sla": 0,
            "pendentes_sla": 0,
        }
        somatempo = 0.0
        for caixa in resultados:
            dados = (caixa.get("por_endereco") or {}).get(endereco) or {}
            item["recebidas_7d"] += int(dados.get("recebidas_7d") or 0)
            item["recebidas_30d"] += int(dados.get("recebidas_30d") or 0)
            item["respondidas_30d"] += int(dados.get("respondidas_30d") or 0)
            item["violacoes_sla"] += int(dados.get("violacoes_sla") or 0)
            item["pendentes_sla"] += int(dados.get("pendentes_sla") or 0)
            tempo = dados.get("tempo_medio_resposta_min")
            if tempo is not None and int(dados.get("respondidas_30d") or 0):
                somatempo += float(tempo) * int(dados["respondidas_30d"])
        if item["respondidas_30d"]:
            item["tempo_medio_resposta_min"] = round(somatempo / item["respondidas_30d"], 1)
        por_endereco.append(item)

    serie_dias = []
    for i in range(13, -1, -1):
        dia = (agora - timedelta(days=i)).date()
        chave = dia.isoformat()
        total = sum(int((c.get("serie_dias") or {}).get(chave, 0)) for c in resultados)
        serie_dias.append((dia.strftime("%d/%m"), total))
    dados = {
        "configurado": True,
        "gerado_em": agora.isoformat(),
        "totais": _agregar(resultados),
        "caixas": resultados,
        "por_endereco": por_endereco,
        "serie_dias": serie_dias,
    }
    with _cache_lock:
        _cache["dados"] = dados
        _cache["expira_em"] = time.time() + CACHE_TTL
    return dados


def limpar_cache() -> None:
    with _cache_lock:
        _cache["dados"] = None
        _cache["expira_em"] = 0.0
