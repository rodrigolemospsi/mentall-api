"""Custos e uso (Fase 1 do painel de custos do MentAll PRO).

O que este módulo faz:
- mede o custo por uso de IA e transcrição (tokens/segundos x tabela de preços);
- sincroniza o consumo diário da Magalu Cloud (Consumption API, formato FOCUS);
- mantém custos fixos cadastráveis (VPS, domínio, assinaturas);
- agrega por mês para o painel: total, por provedor, unit economics e orçamento.

LGPD: só números (owner_id pseudônimo, provedor, modelo, unidades e custo).
Nunca conteúdo clínico.
"""
from __future__ import annotations

import json
import logging
import os
import urllib.error
import urllib.request
import uuid
import threading
from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from services.db import executar

log = logging.getLogger("mentall.custos")

FUSO_BRASILIA = ZoneInfo("America/Sao_Paulo")
PROVEDORES_IA = ("deepseek", "gemini", "openai", "groq")
CAMBIO_DEFAULT = 5.40
PRECO_MENSAL_DEFAULT = 79.90
ORCAMENTO_DEFAULT = 300.00

# Preços de referência em USD (estimativas para o painel; a fatura real manda).
# token: USD por 1M de tokens | minuto: USD por minuto de áudio.
_SEED_PRECOS = [
    ("deepseek", "*", "sintese", "token", 0.27, 1.10, "deepseek-chat: 1M entrada/saída"),
    ("openai", "*", "sintese", "token", 0.15, 0.60, "gpt-4o-mini: 1M entrada/saída"),
    ("gemini", "*", "sintese", "token", 0.10, 0.40, "estimativa (ajustar com a fatura)"),
    ("groq", "*", "transcricao", "minuto", 0.040 / 60.0, 0.0, "whisper-large-v3-turbo: US$ 0,04/hora"),
    ("openai", "*", "transcricao", "minuto", 0.006, 0.0, "estimativa gpt-4o-mini-transcribe"),
]


def _agora_brt() -> datetime:
    return datetime.now(FUSO_BRASILIA)


def _hoje_brt() -> str:
    return _agora_brt().date().isoformat()


def _mes_brt() -> str:
    return _agora_brt().strftime("%Y-%m")


def _novo_id(prefixo: str) -> str:
    return f"{prefixo}:{uuid.uuid4().hex}"


def _env_float(nome: str, padrao: float) -> float:
    try:
        return float(os.getenv(nome, "").strip() or padrao)
    except (TypeError, ValueError):
        return padrao


def cambio_usd_brl() -> float:
    return _env_float("CUSTOS_CAMBIO_USD_BRL", CAMBIO_DEFAULT)


def orcamento_mensal_brl() -> float:
    return _env_float("CUSTOS_ORCAMENTO_MENSAL_BRL", ORCAMENTO_DEFAULT)


def preco_mensal_brl() -> float:
    return _env_float("CUSTOS_PRECO_MENSAL_BRL", PRECO_MENSAL_DEFAULT)


# ---------------------------------------------------------------------------
# Tabela de preços
# ---------------------------------------------------------------------------

def semear_precos() -> None:
    """Insere a tabela de referência uma única vez (idempotente)."""
    agora = _agora_brt().isoformat()
    for provedor, modelo, operacao, unidade, usd, usd_saida, obs in _SEED_PRECOS:
        preco_id = f"preco:{provedor}:{modelo}:{operacao}"
        try:
            executar(
                "INSERT OR IGNORE INTO precos_provedor "
                "(id, provedor, modelo, operacao, unidade, preco_usd, preco_usd_saida, ativo, observacao, criado_em) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?)",
                (preco_id, provedor, modelo, operacao, unidade, usd, usd_saida, obs, agora),
            ).commit()
        except Exception:
            log.exception("Falha ao semear preço %s", preco_id)


def buscar_preco(provedor: str, operacao: str, modelo: str = "") -> dict | None:
    semear_precos()
    try:
        linhas = executar(
            "SELECT * FROM precos_provedor WHERE provedor = ? AND operacao = ? AND ativo = 1 "
            "ORDER BY (modelo = ?) DESC, (modelo = '*') DESC",
            (provedor, operacao, modelo or ""),
        ).fetchall()
        return linhas[0] if linhas else None
    except Exception:
        log.exception("Falha ao buscar preço de %s/%s", provedor, operacao)
        return None


def _custo_brl(provedor: str, operacao: str, modelo: str, tokens_in: int, tokens_out: int, segundos: float) -> float:
    preco = buscar_preco(provedor, operacao, modelo)
    if not preco:
        log.warning("Sem preço cadastrado para %s/%s (%s); custo fica 0 até ajustar.", provedor, operacao, modelo)
        return 0.0
    if (preco.get("unidade") or "token") == "minuto":
        usd = (float(segundos or 0) / 60.0) * float(preco.get("preco_usd") or 0)
    else:
        usd = (float(tokens_in or 0) / 1_000_000.0) * float(preco.get("preco_usd") or 0)
        usd += (float(tokens_out or 0) / 1_000_000.0) * float(preco.get("preco_usd_saida") or 0)
    return round(usd * cambio_usd_brl(), 6)


# ---------------------------------------------------------------------------
# Registro de uso (chamado pelos serviços de IA e transcrição)
# ---------------------------------------------------------------------------

def registrar_uso_ia(
    owner_id: str,
    provedor: str,
    modelo: str,
    tokens_in: int = 0,
    tokens_out: int = 0,
    operacao: str = "sintese",
) -> float:
    provedor = (provedor or "").strip().lower()
    if provedor not in PROVEDORES_IA:
        return 0.0
    custo = _custo_brl(provedor, operacao, modelo, tokens_in, tokens_out, 0)
    detalhe = json.dumps({"modelo": modelo, "tokens_in": int(tokens_in or 0), "tokens_out": int(tokens_out or 0)})
    try:
        executar(
            "INSERT INTO custos_uso (id, owner_id, provedor, modelo, operacao, fonte, referencia, "
            "unidades, tokens_in, tokens_out, segundos, custo_brl, cambio_usd_brl, detalhe, criado_em) "
            "VALUES (?, ?, ?, ?, ?, 'medido', ?, ?, ?, ?, 0, ?, ?, ?, ?)",
            (
                _novo_id("ia"), owner_id or "", provedor, modelo or "", operacao,
                _hoje_brt(), float(int(tokens_in or 0) + int(tokens_out or 0)),
                int(tokens_in or 0), int(tokens_out or 0), custo, cambio_usd_brl(), detalhe,
                _agora_brt().isoformat(),
            ),
        ).commit()
    except Exception:
        log.exception("Falha ao registrar custo de IA")
    return custo


def registrar_transcricao(
    owner_id: str,
    provedor: str,
    modelo: str,
    segundos: float,
    bytes_audio: int = 0,
    estimado: bool = False,
) -> float:
    provedor = (provedor or "").strip().lower()
    custo = _custo_brl(provedor, "transcricao", modelo, 0, 0, segundos)
    detalhe = json.dumps({"modelo": modelo, "estimado": bool(estimado), "bytes": int(bytes_audio or 0)})
    try:
        executar(
            "INSERT INTO custos_uso (id, owner_id, provedor, modelo, operacao, fonte, referencia, "
            "unidades, tokens_in, tokens_out, segundos, custo_brl, cambio_usd_brl, detalhe, criado_em) "
            "VALUES (?, ?, ?, ?, 'transcricao', 'medido', ?, ?, 0, 0, ?, ?, ?, ?, ?)",
            (
                _novo_id("tr"), owner_id or "", provedor, modelo or "",
                _hoje_brt(), float(segundos or 0), float(segundos or 0),
                custo, cambio_usd_brl(), detalhe, _agora_brt().isoformat(),
            ),
        ).commit()
    except Exception:
        log.exception("Falha ao registrar custo de transcrição")
    return custo


# ---------------------------------------------------------------------------
# Custos fixos
# ---------------------------------------------------------------------------

def magalu_configurada() -> bool:
    return bool(os.getenv("MAGALU_CONSUMPTION_API_KEY", "").strip())


def listar_precos() -> list[dict]:
    semear_precos()
    try:
        return executar(
            "SELECT provedor, modelo, operacao, unidade, preco_usd, preco_usd_saida, observacao "
            "FROM precos_provedor WHERE ativo = 1 ORDER BY provedor, operacao"
        ).fetchall()
    except Exception:
        log.exception("Falha ao listar preços")
        return []


def listar_custos_fixos() -> list[dict]:
    try:
        return executar(
            "SELECT * FROM custos_fixos WHERE ativo = 1 ORDER BY valor_brl DESC, descricao"
        ).fetchall()
    except Exception:
        log.exception("Falha ao listar custos fixos")
        return []


def registrar_custo_fixo(
    descricao: str,
    fornecedor: str = "",
    valor_brl: float = 0.0,
    dia_cobranca: int = 1,
    periodicidade: str = "mensal",
) -> str:
    custo_id = _novo_id("fixo")
    period = "anual" if (periodicidade or "").strip().lower() == "anual" else "mensal"
    try:
        executar(
            "INSERT INTO custos_fixos (id, descricao, fornecedor, valor_brl, dia_cobranca, periodicidade, ativo, criado_em) "
            "VALUES (?, ?, ?, ?, ?, ?, 1, ?)",
            (
                custo_id, (descricao or "").strip()[:160], (fornecedor or "").strip()[:120],
                round(float(valor_brl or 0), 2), max(1, min(28, int(dia_cobranca or 1))), period,
                _agora_brt().isoformat(),
            ),
        ).commit()
    except Exception:
        log.exception("Falha ao registrar custo fixo")
    return custo_id


def remover_custo_fixo(custo_id: str) -> bool:
    try:
        cur = executar("UPDATE custos_fixos SET ativo = 0 WHERE id = ?", (custo_id,))
        cur.commit()
        return cur.rowcount > 0
    except Exception:
        log.exception("Falha ao remover custo fixo")
        return False


def _fixos_mensais_brl() -> tuple[float, list[dict]]:
    total = 0.0
    itens = listar_custos_fixos()
    for item in itens:
        valor = float(item.get("valor_brl") or 0)
        total += valor / 12.0 if (item.get("periodicidade") or "mensal") == "anual" else valor
    return round(total, 2), itens


# ---------------------------------------------------------------------------
# Magalu Cloud (Consumption API, formato FOCUS)
# ---------------------------------------------------------------------------

def _sync_estado(chave: str) -> str:
    try:
        linhas = executar("SELECT valor FROM custos_sync_estado WHERE chave = ?", (chave,)).fetchall()
        return str(linhas[0].get("valor") or "") if linhas else ""
    except Exception:
        return ""


def _salvar_sync_estado(chave: str, valor: str) -> None:
    try:
        executar(
            "INSERT OR REPLACE INTO custos_sync_estado (chave, valor, atualizado_em) VALUES (?, ?, ?)",
            (chave, valor, _agora_brt().isoformat()),
        ).commit()
    except Exception:
        log.exception("Falha ao salvar estado de sync")


def ultima_sync_magalu() -> str:
    return _sync_estado("magalu:ultima_sync")


def _ultima_sync_dt() -> datetime | None:
    valor = ultima_sync_magalu()
    if not valor:
        return None
    try:
        momento = datetime.fromisoformat(valor)
    except ValueError:
        return None
    if momento.tzinfo is None:
        momento = momento.replace(tzinfo=FUSO_BRASILIA)
    return momento


def sincronizar_se_necessario(min_intervalo_segundos: int = 120) -> dict | None:
    """Atualiza a Magalu se a última sync estiver velha (ao abrir o painel)."""
    if not magalu_configurada():
        return None
    ultima = _ultima_sync_dt()
    agora = _agora_brt()
    if ultima is not None:
        idade = (agora - ultima).total_seconds()
        if idade < max(30, int(min_intervalo_segundos)):
            return None
    try:
        return sincronizar_magalu(dias=7)
    except Exception:
        log.exception("Falha no sync sob demanda da Magalu")
        return None


_SYNC_PARAR = threading.Event()
_SYNC_THREAD: threading.Thread | None = None


def intervalo_sync_minutos() -> int:
    """Intervalo do sync automático da Magalu (MAGALU_SYNC_MINUTOS, padrão 5 min)."""
    try:
        valor = int(os.getenv("MAGALU_SYNC_MINUTOS", "5").strip() or 5)
    except ValueError:
        valor = 5
    return max(1, valor)


def iniciar_sync_automatico(intervalo_minutos: int | None = None) -> None:
    """Sincroniza a Magalu em background (start + a cada N minutos)."""
    global _SYNC_THREAD
    if _SYNC_THREAD is not None and _SYNC_THREAD.is_alive():
        return
    if not magalu_configurada():
        log.info("Sync automático da Magalu desligado: chave não configurada.")
        return

    minutos = max(1, int(intervalo_minutos or intervalo_sync_minutos()))

    def _laco() -> None:
        while not _SYNC_PARAR.is_set():
            try:
                resultado = sincronizar_magalu(dias=7)
                log.info("Sync automático Magalu: %s", resultado)
            except Exception:
                log.exception("Falha no sync automático da Magalu")
            _SYNC_PARAR.wait(minutos * 60)

    _SYNC_PARAR.clear()
    _SYNC_THREAD = threading.Thread(target=_laco, name="custos-magalu", daemon=True)
    _SYNC_THREAD.start()


def parar_sync_automatico() -> None:
    _SYNC_PARAR.set()
    global _SYNC_THREAD
    _SYNC_THREAD = None


def sincronizar_magalu(dias: int = 7) -> dict:
    """Puxa o consumo diário da Magalu Cloud e grava em custos_uso (idempotente)."""
    chave = os.getenv("MAGALU_CONSUMPTION_API_KEY", "").strip()
    resultado = {"ok": False, "registros": 0, "total_brl": 0.0, "erro": "", "periodo": ""}
    if not chave:
        resultado["erro"] = "MAGALU_CONSUMPTION_API_KEY não configurada."
        return resultado
    try:
        fim = _agora_brt().date()  # inclui hoje (parcial) para o painel quase em tempo real
        inicio = fim - timedelta(days=max(1, int(dias)) - 1)
        url = (
            "https://api.magalu.cloud/consumption/usage"
            f"?start_date={inicio.isoformat()}&end_date={fim.isoformat()}"
        )
        req = urllib.request.Request(url, headers={"x-api-key": chave})
        with urllib.request.urlopen(req, timeout=40) as resposta:
            payload = json.load(resposta)
        linhas = payload.get("results") if isinstance(payload, dict) else payload
        if not isinstance(linhas, list):
            resultado["erro"] = "Resposta inesperada da Magalu (sem lista de resultados)."
            return resultado

        agregado: dict[tuple[str, str], dict] = {}
        for item in linhas:
            if not isinstance(item, dict):
                continue
            quando = str(
                item.get("ChargePeriodStart")
                or item.get("BillingPeriodStart")
                or inicio.isoformat()
            )[:10]
            if not quando or quando < inicio.isoformat() or quando > fim.isoformat():
                continue
            servico = str(item.get("ServiceName") or "Magalu Cloud")
            custo = float(item.get("BilledCost") or item.get("EffectiveCost") or item.get("ListCost") or 0)
            chave_agregada = (quando, servico)
            atual = agregado.setdefault(
                chave_agregada,
                {"custo": 0.0, "unidades": 0.0, "skus": set(), "moeda": item.get("BillingCurrency") or "BRL"},
            )
            atual["custo"] += custo
            atual["unidades"] += float(item.get("ConsumedQuantity") or 0)
            atual["skus"].add(str(item.get("SkuId") or ""))

        # Idempotência: apaga o que veio da API no período antes de regravar.
        try:
            cur = executar(
                "DELETE FROM custos_uso WHERE provedor = 'magalu' AND fonte = 'api' AND referencia BETWEEN ? AND ?",
                (inicio.isoformat(), fim.isoformat()),
            )
            cur.commit()
        except Exception:
            log.exception("Falha ao limpar consumo Magalu do período")

        agora = _agora_brt().isoformat()
        total = 0.0
        registros = 0
        for (quando, servico), dados in sorted(agregado.items()):
            custo = round(dados["custo"], 6)
            total += custo
            detalhe = json.dumps({"servico": servico, "skus": sorted(dados["skus"]), "moeda": dados["moeda"]})
            executar(
                "INSERT INTO custos_uso (id, owner_id, provedor, modelo, operacao, fonte, referencia, "
                "unidades, tokens_in, tokens_out, segundos, custo_brl, cambio_usd_brl, detalhe, criado_em) "
                "VALUES (?, '', 'magalu', ?, 'infra', 'api', ?, ?, 0, 0, 0, ?, 1.0, ?, ?)",
                (
                    _novo_id("magalu"), servico[:120], quando, round(dados["unidades"], 2),
                    custo, detalhe, agora,
                ),
            ).commit()
            registros += 1

        _salvar_sync_estado("magalu:ultima_sync", agora)
        resultado.update(
            ok=True,
            registros=registros,
            total_brl=round(total, 4),
            periodo=f"{inicio.isoformat()} a {fim.isoformat()}",
        )
        return resultado
    except urllib.error.HTTPError as erro:
        detalhe = erro.read().decode("utf-8", "ignore")[:200]
        resultado["erro"] = f"HTTP {erro.code}: {detalhe}"
    except Exception as erro:
        log.exception("Falha ao sincronizar Magalu")
        resultado["erro"] = f"{type(erro).__name__}: {str(erro)[:200]}"
    return resultado


# ---------------------------------------------------------------------------
# Agregação para o painel
# ---------------------------------------------------------------------------

def _linhas_mes(mes: str) -> list[dict]:
    try:
        return executar(
            "SELECT provedor, operacao, fonte, referencia, unidades, tokens_in, tokens_out, segundos, custo_brl "
            "FROM custos_uso WHERE referencia LIKE ? ORDER BY referencia",
            (f"{mes}-%",),
        ).fetchall()
    except Exception:
        log.exception("Falha ao consultar custos do mês")
        return []


def _contar_eventos_mes(tipo: str, mes: str) -> int:
    try:
        linhas = executar(
            "SELECT COUNT(*) AS total FROM eventos WHERE tipo = ? AND criado_em LIKE ?",
            (tipo, f"{mes}-%"),
        ).fetchall()
        return int((linhas[0] if linhas else {}).get("total") or 0)
    except Exception:
        return 0


def _profissionais_ativos() -> int:
    try:
        linhas = executar(
            "SELECT COUNT(DISTINCT owner_id) AS total FROM eventos "
            "WHERE criado_em >= ? AND owner_id <> ''",
            ((_agora_brt() - timedelta(days=30)).isoformat(),),
        ).fetchall()
        total = int((linhas[0] if linhas else {}).get("total") or 0)
        if total:
            return total
    except Exception:
        pass
    try:
        linhas = executar("SELECT COUNT(*) AS total FROM usuarios WHERE status = 'ativo'").fetchall()
        return int((linhas[0] if linhas else {}).get("total") or 0)
    except Exception:
        return 0


def painel(mes: str | None = None) -> dict:
    mes = (mes or "").strip() or _mes_brt()
    linhas = _linhas_mes(mes)
    cambio = cambio_usd_brl()
    orcamento = orcamento_mensal_brl()
    preco = preco_mensal_brl()

    por_provedor: dict[str, dict] = {}
    por_operacao: dict[str, float] = {}
    por_dia: dict[str, float] = {}
    total = 0.0
    total_ia = 0.0
    total_infra = 0.0
    for linha in linhas:
        provedor = str(linha.get("provedor") or "outro")
        custo = float(linha.get("custo_brl") or 0)
        operacao = str(linha.get("operacao") or "")
        total += custo
        por_operacao[operacao] = round(por_operacao.get(operacao, 0.0) + custo, 4)
        if provedor == "magalu":
            total_infra += custo
        elif provedor in PROVEDORES_IA:
            total_ia += custo
        item = por_provedor.setdefault(
            provedor, {"provedor": provedor, "custo_brl": 0.0, "origem": set(), "unidades": 0.0}
        )
        item["custo_brl"] += custo
        item["origem"].add(str(linha.get("fonte") or "medido"))
        item["unidades"] += float(linha.get("unidades") or linha.get("segundos") or 0)
        dia = str(linha.get("referencia") or "")[:10]
        if dia:
            por_dia[dia] = round(por_dia.get(dia, 0.0) + custo, 4)

    fixos_total, fixos = _fixos_mensais_brl()
    total += fixos_total

    ativos = _profissionais_ativos()
    sessoes = _contar_eventos_mes("transcricao", mes)
    sinteses = _contar_eventos_mes("sintese", mes)
    custo_por_prof = round(total / ativos, 2) if ativos else 0.0
    custo_por_sessao = round(total_ia / sessoes, 6) if sessoes else 0.0

    dias_serie = []
    hoje = _agora_brt().date()
    for deslocamento in range(13, -1, -1):
        dia = hoje - timedelta(days=deslocamento)
        dias_serie.append((dia.strftime("%d/%m"), round(por_dia.get(dia.isoformat(), 0.0), 2)))

    provedores = []
    for item in sorted(por_provedor.values(), key=lambda i: i["custo_brl"], reverse=True):
        provedores.append(
            {
                "provedor": item["provedor"],
                "custo_brl": round(item["custo_brl"], 4),
                "origem": " + ".join(sorted(item["origem"])),
                "unidades": round(item["unidades"], 2),
            }
        )

    alertas = []
    pct_orcamento = round((total / orcamento) * 100, 1) if orcamento else 0.0
    if orcamento and total >= orcamento:
        alertas.append(f"Orçamento do mês estourado: R$ {total:.2f} de R$ {orcamento:.2f}.")
    elif orcamento and total >= orcamento * 0.8:
        alertas.append(f"Já foram usados {pct_orcamento:.0f}% do orçamento do mês.")

    return {
        "mes": mes,
        "periodo_label": datetime.strptime(mes + "-01", "%Y-%m-%d").strftime("%m/%Y"),
        "total_brl": round(total, 2),
        "ia_brl": round(total_ia, 4),
        "infra_brl": round(total_infra, 4),
        "fixos_brl": fixos_total,
        "outros_brl": round(total - total_ia - total_infra - fixos_total, 2),
        "orcamento_brl": orcamento,
        "preco_mensal_brl": preco,
        "pct_orcamento": pct_orcamento,
        "restante_brl": round(max(0.0, orcamento - total), 2),
        "por_provedor": provedores,
        "por_operacao": {k: round(v, 2) for k, v in sorted(por_operacao.items(), key=lambda i: -i[1])},
        "dias": dias_serie,
        "fixos": fixos,
        "profissionais_ativos": ativos,
        "sessoes_transcritas": sessoes,
        "sinteses": sinteses,
        "custo_por_profissional_brl": custo_por_prof,
        "custo_por_sessao_brl": custo_por_sessao,
        "margem_por_profissional_brl": round(preco - custo_por_prof, 2),
        "cambio_usd_brl": cambio,
        "ultima_sync_magalu": ultima_sync_magalu(),
        "magalu_configurada": magalu_configurada(),
        "precos": listar_precos(),
        "alertas": alertas,
        "tem_medicao_ia": total_ia > 0 or sessoes > 0 or sinteses > 0,
    }
