"""Aviso imediato de novo e-mail nas caixas monitoradas (Fase 1 dos avisos).

Antes o painel só avisava e-mail FORA DO SLA (4h/24h). Este módulo verifica as
caixas via IMAP a cada N segundos e, quando chega mensagem nova, dispara:

  1. Web Push no PWA do painel (funciona com o painel fechado);
  2. WhatsApp para EMAIL_ALERTA_WHATSAPP (se configurado);
  3. E-mail de aviso para EMAIL_NOVO_ALERTA_EMAIL (opcional).

LGPD: só metadados (remetente, assunto, data). O corpo da mensagem nunca é lido
nem enviado — o fetch usa BODY.PEEK[HEADER.FIELDS ...] somente.

Estado por caixa em `email_alertas_estado` (UIDVALIDITY + último UID), o que
evita repetir aviso e não notifica o histórico na primeira execução.
"""
from __future__ import annotations

import asyncio
import email
import email.header
import imaplib
import json
import logging
import os
import smtplib
from datetime import datetime, timezone
from email.mime.text import MIMEText

from services import email_metricas, push, wuzapi_alertas
from services.db import executar
from services.lembrete_service import _enviar_whatsapp_via_wuzapi, _normalizar_numero_whatsapp

log = logging.getLogger("mentall.email_novos")

INTERVALO_SEGUNDOS = max(30, int(os.getenv("EMAIL_NOVO_INTERVALO_SEGUNDOS", "90")))
MAX_DETALHES = 5

_TAREFA: asyncio.Task | None = None


# ---------------------------------------------------------------------------
# Estado simples (tabela que já existe)
# ---------------------------------------------------------------------------

def _ler_estado(chave: str) -> str:
    try:
        linhas = executar(
            "SELECT valor FROM email_alertas_estado WHERE chave = ?", (chave,)
        ).fetchall()
        return str(linhas[0].get("valor") or "") if linhas else ""
    except Exception:
        return ""


def _salvar_estado(chave: str, valor: str) -> None:
    agora = datetime.now(timezone.utc).isoformat()
    try:
        executar(
            "INSERT OR REPLACE INTO email_alertas_estado (chave, valor, atualizado_em) VALUES (?, ?, ?)",
            (chave, valor, agora),
        ).commit()
    except Exception:
        log.exception("Falha ao salvar estado do aviso de e-mail")


# ---------------------------------------------------------------------------
# Canais de aviso
# ---------------------------------------------------------------------------

def _owner_wuzapi() -> str:
    try:
        linha = executar("SELECT owner_id FROM wuzapi_instancias LIMIT 1").fetchone()
        return str(linha["owner_id"]) if linha else ""
    except Exception:
        return ""


def _destino_whatsapp() -> str:
    return (os.getenv("EMAIL_ALERTA_WHATSAPP") or "").strip()


def _caixas_com_alerta() -> set[str]:
    """Só estas caixas geram aviso (padrão: contato@mentallpro.com.br)."""
    bruto = (os.getenv("EMAIL_ALERTA_SOMENTE_CAIXAS") or "contato@mentallpro.com.br").strip()
    return {parte.strip().lower() for parte in bruto.split(",") if parte.strip()}


def _destinos_por_caixa() -> dict[str, str]:
    """Roteamento opcional: {"caixa@dominio": "55..."} em EMAIL_ALERTA_WHATSAPP_POR_CAIXA."""
    bruto = (os.getenv("EMAIL_ALERTA_WHATSAPP_POR_CAIXA") or "").strip()
    if not bruto:
        return {}
    try:
        dados = json.loads(bruto)
    except ValueError:
        log.error("EMAIL_ALERTA_WHATSAPP_POR_CAIXA não é um JSON válido")
        return {}
    saida: dict[str, str] = {}
    if isinstance(dados, dict):
        for caixa, numero in dados.items():
            caixa_norm = str(caixa or "").strip().lower()
            numero_norm = _normalizar_numero_whatsapp(str(numero or ""))
            if caixa_norm and numero_norm:
                saida[caixa_norm] = numero_norm
    return saida


def _variante_sem_nono(numero: str) -> str:
    """Alguns JIDs brasileiros resolvem sem o 9º dígito (formato antigo)."""
    digitos = "".join(ch for ch in str(numero or "") if ch.isdigit())
    if len(digitos) == 13 and digitos.startswith("55"):
        return digitos[:4] + digitos[5:]
    if len(digitos) == 12 and digitos.startswith("55"):
        return digitos[:4] + "9" + digitos[4:]
    return ""


def _enviar_alerta_whatsapp(destino: str, mensagem: str) -> bool:
    """Envia para o destino e, se o JID não resolver, tenta a variante com/sem 9."""
    numero = _normalizar_numero_whatsapp(destino)
    sucesso, _ = _enviar_whatsapp_via_wuzapi(_owner_wuzapi(), numero, mensagem)
    if sucesso:
        return True
    variante = _variante_sem_nono(numero)
    if variante:
        sucesso, _ = _enviar_whatsapp_via_wuzapi(_owner_wuzapi(), variante, mensagem)
    return bool(sucesso)


def _link_email() -> str:
    """Link para a caixa de e-mail (webmail), configurável por env."""
    return (os.getenv("MAIL_WEBMAIL_URL") or "https://mail.mentallpro.com.br/webmail/").strip()


def _mascarar_numero(numero: str) -> str:
    digitos = "".join(ch for ch in str(numero or "") if ch.isdigit())
    if len(digitos) <= 6:
        return "***"
    return digitos[:4] + "****" + digitos[-2:]


def _destino_email() -> str:
    return (os.getenv("EMAIL_NOVO_ALERTA_EMAIL") or "").strip()


def _whatsapp_ativo() -> bool:
    return bool(_owner_wuzapi() and _destino_whatsapp())


def _enviar_email_sync(destinatario: str, assunto: str, corpo: str) -> bool:
    host = (os.getenv("SMTP_HOST") or "").strip()
    if not host:
        return False
    porta = int(os.getenv("SMTP_PORT", "587") or 587)
    usuario = (os.getenv("SMTP_USER") or "").strip()
    senha = os.getenv("SMTP_PASS") or ""
    remetente = (os.getenv("SMTP_FROM") or usuario or "").strip()
    if not remetente:
        return False
    msg = MIMEText(corpo, "plain", "utf-8")
    msg["Subject"] = assunto
    msg["From"] = remetente
    msg["To"] = destinatario
    try:
        with smtplib.SMTP(host, porta, timeout=20) as servidor:
            servidor.ehlo()
            try:
                servidor.starttls()
                servidor.ehlo()
            except Exception:
                pass
            if usuario and senha:
                servidor.login(usuario, senha)
            servidor.sendmail(remetente, [destinatario], msg.as_string())
        return True
    except Exception:
        log.exception("Falha ao enviar e-mail de aviso")
        return False


def _formatar_detalhes(novos: list[dict]) -> str:
    linhas = []
    for item in novos[:MAX_DETALHES]:
        linhas.append(
            f"{item.get('caixa')}: {item.get('de')} — {item.get('assunto')} ({item.get('data')})"
        )
    if len(novos) > MAX_DETALHES:
        linhas.append(f"e mais {len(novos) - MAX_DETALHES} mensagem(ns)")
    return "\n".join(linhas)


def enviar_alertas(novos: list[dict]) -> dict:
    """Dispara todos os canais configurados. Nunca levanta exceção."""
    if not novos:
        return {"enviado": False, "motivo": "sem novidades"}
    permitidas = _caixas_com_alerta()
    novos = [item for item in novos if str(item.get("email") or "").strip().lower() in permitidas]
    if not novos:
        return {"enviado": False, "motivo": "nenhuma caixa com alerta ativo"}
    total = len(novos)
    caixas = sorted({str(item.get("caixa") or "") for item in novos})
    titulo = "Novo e-mail" + (f" em {caixas[0]}" if len(caixas) == 1 else f" ({total})")
    canais: dict[str, bool] = {}

    # 1) push no PWA (global; todos os avisos chegam em todos dispositivos inscritos)
    if push.configurado():
        resultado = push.enviar(titulo, _formatar_detalhes(novos)[:800], _link_email())
        canais["push"] = bool(resultado.get("enviados"))
    else:
        canais["push"] = False

    # 2) WhatsApp: sai pelo número 19 (instância de avisos) para o destino 75
    if wuzapi_alertas.configurado() or _whatsapp_ativo():
        por_destino = _destinos_por_caixa()
        destino_padrao = _normalizar_numero_whatsapp(_destino_whatsapp())
        grupos: dict[str, list[dict]] = {}
        for item in novos:
            email = str(item.get("email") or "").strip().lower()
            destino = por_destino.get(email) or destino_padrao
            grupos.setdefault(destino, []).append(item)
        enviados = 0
        for destino, itens in grupos.items():
            mensagem = (
                "📬 Novo e-mail no MentAll PRO:\n"
                + _formatar_detalhes(itens)
                + f"\n\nAbrir a caixa de e-mail: {_link_email()}"
            )
            sucesso = wuzapi_alertas.enviar(destino, mensagem) or _enviar_alerta_whatsapp(
                destino, mensagem
            )
            if not sucesso and destino != destino_padrao:
                log.warning(
                    "WhatsApp da caixa falhou para %s; repetindo no destino padrão.",
                    _mascarar_numero(destino),
                )
                sucesso = wuzapi_alertas.enviar(destino_padrao, mensagem) or _enviar_alerta_whatsapp(
                    destino_padrao, mensagem
                )
            enviados += 1 if sucesso else 0
        canais["whatsapp"] = enviados > 0
    else:
        canais["whatsapp"] = False

    # 3) e-mail de aviso (opcional)
    if _destino_email():
        canais["email"] = _enviar_email_sync(
            _destino_email(),
            f"[MentAll PRO] {titulo}",
            "Novo e-mail recebido:\n\n" + resumo + f"\n\nAbrir a caixa de e-mail: {_link_email()}",
        )
    else:
        canais["email"] = False

    if any(canais.values()):
        _salvar_estado("novo:ultimo_envio", datetime.now(timezone.utc).isoformat())
        log.info("Aviso de novo e-mail enviado (%s): %s", total, canais)
        return {"enviado": True, "total": total, "canais": canais}
    log.warning(
        "Chegou e-mail novo (%s), mas nenhum canal de aviso está ativo. "
        "Ative as notificações no painel ou configure EMAIL_ALERTA_WHATSAPP/EMAIL_NOVO_ALERTA_EMAIL.",
        total,
    )
    return {"enviado": False, "total": total, "canais": canais, "motivo": "sem canal ativo"}


def testar_aviso() -> dict:
    """Envia uma mensagem de teste pelos canais configurados (respeita o roteamento)."""
    agora = datetime.now().strftime("%d/%m %H:%M")
    exemplo: list[dict] = [{
        "caixa": "contato@mentallpro.com.br",
        "email": "contato@mentallpro.com.br",
        "de": "Teste de aviso",
        "assunto": "Teste do aviso do contato@ (enviado pelo número 19)",
        "data": agora,
    }]
    return enviar_alertas(exemplo)


# ---------------------------------------------------------------------------
# Verificação IMAP
# ---------------------------------------------------------------------------

def _decodificar(valor) -> str:
    if valor is None:
        return ""
    try:
        partes = email.header.decode_header(str(valor))
        saida = []
        for texto, codificacao in partes:
            if isinstance(texto, bytes):
                saida.append(texto.decode(codificacao or "utf-8", "replace"))
            else:
                saida.append(texto)
        return " ".join(saida).strip()
    except Exception:
        return str(valor).strip()


def _cabecalho(conexao, uid: str) -> dict:
    tip, dados = conexao.uid(
        "fetch", uid, "(BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE)])"
    )
    if not dados or not isinstance(dados[0], tuple):
        return {"de": "(remetente desconhecido)", "assunto": "(sem assunto)", "data": ""}
    mensagem = email.message_from_bytes(dados[0][1])
    return {
        "de": _decodificar(mensagem.get("From")) or "(remetente desconhecido)",
        "assunto": _decodificar(mensagem.get("Subject")) or "(sem assunto)",
        "data": _decodificar(mensagem.get("Date")),
    }


def _verificar_caixa(caixa: dict) -> list[dict]:
    """Retorna as mensagens novas da caixa (atualiza o estado)."""
    host = (os.getenv("MAIL_IMAP_HOST") or "mail.mentallpro.com.br").strip()
    porta = int(os.getenv("MAIL_IMAP_PORT", "993") or 993)
    timeout = float(os.getenv("MAIL_IMAP_TIMEOUT", "20") or 20)
    chave = f"novo:{caixa['email']}"
    conexao = None
    try:
        conexao = imaplib.IMAP4_SSL(host, porta, timeout=timeout)
        conexao.login(caixa["email"], caixa["senha"])
        conexao.select("INBOX", readonly=True)

        tip, dados = conexao.response("UIDVALIDITY")
        uidvalidity = dados[0].decode("utf-8", "ignore") if dados and dados[0] else ""
        tip, dados = conexao.uid("search", None, "ALL")
        lista = dados[0].split() if dados and dados[0] else []
        uids = []
        for valor in lista:
            if isinstance(valor, bytes):
                valor = valor.decode("ascii", "ignore")
            if str(valor).isdigit():
                uids.append(int(valor))
        maior_uid = max(uids) if uids else 0

        estado = {}
        bruto = _ler_estado(chave)
        if bruto:
            try:
                estado = json.loads(bruto)
            except ValueError:
                estado = {}

        baseline = (not estado) or str(estado.get("uidvalidity") or "") != uidvalidity
        novos: list[dict] = []
        if not baseline:
            ultimo = int(estado.get("uid") or 0)
            for uid in sorted(u for u in uids if u > ultimo)[:MAX_DETALHES]:
                detalhe = _cabecalho(conexao, str(uid))
                novos.append({"caixa": caixa["rotulo"], "email": caixa["email"], **detalhe, "uid": uid})

        _salvar_estado(chave, json.dumps({"uidvalidity": uidvalidity, "uid": maior_uid}))
        if baseline:
            log.info("Aviso de novo e-mail: baseline de %s (uid=%s).", caixa["email"], maior_uid)
        return novos
    finally:
        if conexao is not None:
            try:
                conexao.logout()
            except Exception:
                pass


def verificar_caixas(notificar: bool = True) -> dict:
    """Verifica todas as caixas configuradas e avisa se houver mensagem nova."""
    caixas = email_metricas.caixas_configuradas()
    resultado = {
        "ok": True,
        "caixas": len(caixas),
        "novos": 0,
        "enviado": False,
        "erros": [],
        "notificar": bool(notificar),
    }
    if not caixas:
        resultado.update(ok=False, motivo="Nenhuma caixa em MAIL_METRICAS_CAIXAS.")
        return resultado

    novos: list[dict] = []
    for caixa in caixas:
        try:
            novos.extend(_verificar_caixa(caixa))
        except Exception as erro:
            log.exception("Falha ao verificar a caixa %s", caixa.get("email"))
            resultado["erros"].append(f"{caixa.get('email')}: {type(erro).__name__}")

    resultado["novos"] = len(novos)
    _salvar_estado("novo:ultima_verificacao", datetime.now(timezone.utc).isoformat())
    if novos and notificar:
        resultado["alerta"] = enviar_alertas(novos)
        resultado["enviado"] = bool(resultado["alerta"].get("enviado"))
    return resultado


# ---------------------------------------------------------------------------
# Estado para a tela e loop de background
# ---------------------------------------------------------------------------

def estado(ator: str | None = None) -> dict:
    caixas = email_metricas.caixas_configuradas()
    return {
        "ativo": bool(caixas),
        "caixas": [caixa.get("email") for caixa in caixas],
        "intervalo_s": INTERVALO_SEGUNDOS,
        "ultima_verificacao": _ler_estado("novo:ultima_verificacao"),
        "ultimo_envio": _ler_estado("novo:ultimo_envio"),
        "push_configurado": push.configurado(),
        "push_inscricoes": push.contar(ator) if ator else push.contar(),
        "whatsapp_configurado": _whatsapp_ativo() or wuzapi_alertas.configurado(),
        "remetente_configurado": wuzapi_alertas.configurado(),
        "remetente": wuzapi_alertas.status(),
        "somente_caixas": sorted(_caixas_com_alerta()),
        "whatsapp_destino_padrao": _mascarar_numero(_destino_whatsapp()),
        "whatsapp_por_caixa": [
            {"caixa": caixa, "destino": _mascarar_numero(numero)}
            for caixa, numero in _destinos_por_caixa().items()
        ],
        "email_aviso_configurado": bool(_destino_email()),
    }


async def _loop() -> None:
    await asyncio.sleep(20)
    avisou_sem_config = False
    while True:
        try:
            if not email_metricas.configurado():
                if not avisou_sem_config:
                    log.info(
                        "Avisos de novo e-mail desligados: MAIL_METRICAS_CAIXAS não configurado."
                    )
                    avisou_sem_config = True
            else:
                avisou_sem_config = False
                await asyncio.to_thread(verificar_caixas, True)
        except Exception:
            log.exception("Erro no loop de aviso de novo e-mail")
        await asyncio.sleep(INTERVALO_SEGUNDOS)


def iniciar_avisos_email() -> None:
    global _TAREFA
    if _TAREFA is None or _TAREFA.done():
        _TAREFA = asyncio.create_task(_loop())


async def parar_avisos_email() -> None:
    global _TAREFA
    if _TAREFA and not _TAREFA.done():
        _TAREFA.cancel()
        try:
            await _TAREFA
        except asyncio.CancelledError:
            pass
