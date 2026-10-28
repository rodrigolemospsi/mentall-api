import asyncio
import base64
import csv
import io
import hashlib
import html
import json
import logging
import os
import random
import secrets
import smtplib
import string
import time
import uuid
from urllib.parse import urlencode
from contextlib import asynccontextmanager
from datetime import datetime, timedelta, timezone
from email.mime.text import MIMEText

from dotenv import load_dotenv

# O .env precisa ser carregado ANTES de importar os serviços: módulos como
# services/db.py leem TURSO_DATABASE_URL/TURSO_AUTH_TOKEN no import. Se o
# dotenv rodar depois, o backend cai no SQLite efêmero sem tentar o Turso.
load_dotenv(os.path.join(os.path.dirname(os.path.abspath(__file__)), '.env'))

from fastapi import Depends, FastAPI, HTTPException, Request, status
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse, Response

import admin_ui
from services import admin as admin_service
from services import email_alertas
from services.email_alertas import iniciar_alertas_email, parar_alertas_email
from services import email_metricas
from services import email_admin
from services import custos
from services import email_novos
from services import push
from services import wuzapi_alertas
from services import reportes_ia
from services import saude as saude_service
from services import admin_seguranca as seguranca_admin
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
import jwt
from jwt.exceptions import InvalidTokenError as JWTError
from passlib.context import CryptContext

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("mentall")

from models.schemas import (
    AnamneseConfirmacaoResponse,
    AnamneseRequest,
    AnamneseResponse,
    AnamneseStatusResponse,
    ArtigosRequest,
    ArtigosResponse,
    ContratoAceiteRequest,
    ContratoRequest,
    ContratoResponse,
    ContratoStatusResponse,
    EventoRequest,
    HealthResponse,
    HeartbeatRequest,
    LembreteItem,
    LembreteRequest,
    LembreteResponse,
    LembretesCancelResponse,
    LembretesListResponse,
    LoginRequest,
    LoginResponse,
    ProgressoRequest,
    ProgressoResponse,
    RecuperacaoRequest,
    RecuperacaoResponse,
    RedefinirSenhaRequest,
    RegistrarRecuperacaoRequest,
    RegistrarRequest,
    RegistrarResponse,
    ResponderAnamneseRequest,
    SinteseRequest,
    SinteseResponse,
    TelemetriaResponse,
    TranscricaoRequest,
    TranscricaoResponse,
    VerificarCodigoRequest,
    VerificarCodigoResponse,
    VerificarCrpRequest,
    VerificarCrpResponse,
    WhatsAppRequest,
    WhatsAppResponse,
    WuzapiConfigRequest,
    WuzapiDesconectarRequest,
    WuzapiParearRequest,
    WuzapiParearResponse,
    WuzapiQrResponse,
    WuzapiStatusResponse,
    WuzapiTestarRequest,
)
from services.anamnese_service import (
    criar_anamnese,
    obter_anamnese,
    registrar_resposta,
)
from services.contrato_service import (
    criar_contrato,
    obter_contrato,
    registrar_aceite,
)
from services.crp_service import verificar_crp_online
from services.ia_clinica import _get_model_name, gerar_artigos, gerar_progresso, gerar_sintese
from services.lembrete_service import (
    _enviar_whatsapp_via_wuzapi,
    agendar_lembrete,
    cancelar_lembrete,
    cancelar_todos_lembretes,
    iniciar_scheduler,
    listar_lembretes,
    parar_scheduler,
    registrar_receipt,
    salvar_instancia_wuzapi,
)
from services.transcricao import transcrever_audio
from services.exclusao_conta import (
    excluir_conta as _excluir_conta_dados,
    pode_excluir as _pode_excluir_conta,
    token_revogado as _token_revogado,
)
from models.schemas import (
    ExcluirContaRequest,
    ReporteSinteseRequest,
    ReporteSinteseResponse,
)
from services import reportes_ia
from services import wuzapi_admin

_rate_limit_store: dict[str, list[float]] = {}

# IPs/CIDRs de proxies confiáveis que têm permissão de anexar o IP real do
# cliente ao final de X-Forwarded-For (ex.: edge do Fly). Separados por vírgula.
# Vazio = NUNCA confiar em X-Forwarded-For (usa o socket peer).
def _parse_trusted_proxies() -> set[str]:
    import ipaddress as _ip
    raw = os.getenv("TRUSTED_PROXIES", "").strip()
    if not raw:
        return set()
    resultado = set()
    for item in raw.split(","):
        item = item.strip()
        if not item:
            continue
        resultado.add(item)
        try:
            resultado.add(str(_ip.ip_address(item)))
        except ValueError:
            try:
                rede = _ip.ip_network(item, strict=False)
                resultado.add(str(rede))
            except ValueError:
                pass
    return resultado


TRUSTED_PROXIES = _parse_trusted_proxies()


def _ip_em_proxies(peer: str) -> bool:
    """True se `peer` está em TRUSTED_PROXIES (IP exato ou dentro de um CIDR)."""
    import ipaddress as _ip
    try:
        addr = _ip.ip_address(peer)
    except ValueError:
        return False
    for item in TRUSTED_PROXIES:
        try:
            if "/" in item:
                if addr in _ip.ip_network(item, strict=False):
                    return True
            elif addr == _ip.ip_address(item):
                return True
        except ValueError:
            continue
    return False


def _cliente_ip(request: Request) -> str:
    """Retorna o IP real do cliente para chaves de rate limit.

    Só confia em ``X-Forwarded-For`` quando o socket peer está em
    ``TRUSTED_PROXIES`` (proxy conhecido). Caso contrário usa o socket peer,
    que o atacante não controla — impede bypass por rotação do header.
    """
    peer = request.client.host if request.client else ""
    if not peer:
        return "unknown"

    import ipaddress as _ip

    if not _ip_em_proxies(peer) and not _peer_eh_proxy(peer):
        return peer

    try:
        xff = request.headers.get("x-forwarded-for", "")
        if xff:
            partes = [p.strip() for p in xff.split(",") if p.strip()]
            if partes:
                ultimo = partes[-1]
                _ip.ip_address(ultimo)  # valida formato; levanta ValueError se inválido
                return ultimo
    except Exception:
        pass
    return peer or "unknown"


def _peer_eh_proxy(peer: str) -> bool:
    """Considera IPs privados/link-local como possíveis proxies da rede interna
    (ex.: edge do Fly na rede 6PN) — um socket peer público nunca é proxy."""
    import ipaddress as _ip
    try:
        addr = _ip.ip_address(peer)
    except ValueError:
        return False
    return addr.is_private or addr.is_link_local or addr.is_loopback


def _limpar_rate_limits(agora: float) -> None:
    for chave in list(_rate_limit_store.keys()):
        _rate_limit_store[chave] = [t for t in _rate_limit_store[chave] if agora - t < 60.0]
        if not _rate_limit_store[chave]:
            del _rate_limit_store[chave]


def _rate_limit_check(request: Request, max_requests: int, chave_extra: str = "") -> None:
    """Rate limit por (rota, chave_extra) ou (rota, ip).

    Antes o bucket era global por `client.host` (XFF do atacante): um endpoint
    consumia o orçamento de todos e XFF rotativo burlava o 429. Agora a chave
    é `{rota}|{chave_extra}` (conta — rotacionar IP não ajuda) ou
    `{rota}|{ip}` (IP real = último valor do XFF adicionado pelo proxy)."""
    agora = time.time()
    _limpar_rate_limits(agora)
    rota = request.url.path or "unknown"
    if chave_extra:
        chave = f"{rota}|{chave_extra}"
    else:
        ip = _cliente_ip(request)
        chave = f"{rota}|{ip}"
    timestamps = _rate_limit_store.get(chave, [])
    if len(timestamps) >= max_requests:
        raise HTTPException(status_code=429, detail="Muitas requisicoes. Aguarde um momento.")
    timestamps.append(agora)
    _rate_limit_store[chave] = timestamps


JWT_SECRET = os.getenv("JWT_SECRET")
if not JWT_SECRET:
    raise RuntimeError("JWT_SECRET não configurado. Defina a variável de ambiente JWT_SECRET.")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
JWT_EXPIRATION = int(os.getenv("JWT_EXPIRATION_MINUTES", "480"))
APP_USERNAME = os.getenv("APP_USERNAME", "admin")
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
APP_PASSWORD_HASH = os.getenv("APP_PASSWORD_HASH", "").strip()
if not APP_PASSWORD_HASH:
    raise RuntimeError("APP_PASSWORD_HASH não configurado. Defina a variável de ambiente APP_PASSWORD_HASH.")
APP_USER_ID = os.getenv("APP_USER_ID", "").strip() or str(uuid.uuid4())
log.info("APP_USER_ID: %s", APP_USER_ID[:8])
SMTP_HOST = os.getenv("SMTP_HOST", "")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASS = os.getenv("SMTP_PASS", "")
SMTP_FROM = os.getenv("SMTP_FROM", "naoresponder@mentallpro.com.br")
security = HTTPBearer()


def _formatar_data_br(valor: str) -> str:
    """Converte data ISO para formato brasileiro dd/mm/aaaa."""
    try:
        dt = datetime.strptime(valor[:10], "%Y-%m-%d")
        return dt.strftime("%d/%m/%Y")
    except Exception:
        return valor[:10].replace("-", "/")


def _mascarar_contato(valor: str) -> str:
    """Mascara PII (e-mail/telefone) em logs: mantém só o primeiro char + domínio para e-mail,
    ou os últimos 4 dígitos para telefone."""
    texto = str(valor).strip()
    if "@" in texto:
        local, _, dominio = texto.partition("@")
        if not local:
            return "****@" + dominio
        mascara = local[0] + "*" * max(len(local) - 1, 1)
        return f"{mascara}@{dominio}"
    if len(texto) <= 4:
        return "****"
    return "*" * (len(texto) - 4) + texto[-4:]


def _limpar_crp(valor: str) -> str:
    """Remove prefixo 'CRP' ou 'crp' do registro profissional para evitar duplicacao."""
    import re
    return re.sub(r"^CRP\s*", "", valor.strip(), flags=re.IGNORECASE)


def _detectar_titulo(linha: str) -> bool:
    """Detecta se uma linha de texto eh um titulo de secao (subtitulo)."""
    texto = linha.strip()
    if len(texto) > 60:
        return False
    terminadores = ('.', '?', '!', ';', ',', ':')
    if texto.endswith(terminadores):
        return False
    return '\n' not in texto


def _renderizar_paragrafos_personalizados(texto_bruto: str) -> str:
    """Converte o texto bruto do template personalizado em HTML.
    Linhas curtas sem pontuacao final viram <h2> (subtitulos em negrito).
    Demais linhas viram <p> (corpo do texto)."""
    linhas = [l.strip() for l in texto_bruto.split("\n")]
    blocos = []
    for linha in linhas:
        if not linha:
            continue
        if _detectar_titulo(linha):
            blocos.append(f"<h2>{html.escape(linha)}</h2>")
        else:
            blocos.append(f"<p>{html.escape(linha)}</p>")
    return "".join(blocos)


def _com_nonce_script(html: str, nonce: str) -> str:
    """Adiciona o nonce do CSP às tags <script> inline do HTML."""
    if not nonce:
        return html
    return html.replace("<script>", f'<script nonce="{nonce}">')


def _renderizar_template_personalizado(
    token: str,
    dados: dict,
    aceito: bool,
    aceito_em: str,
    base_url: str,
    nome_aceite: str = "",
    nonce: str = "",
) -> HTMLResponse:
    nome_paciente = dados.get("nome_paciente", "")
    nome_profissional = dados.get("nome_profissional", "")
    registro = _limpar_crp(dados.get("registro_profissional", ""))
    texto = dados.get("template_contrato", "")
    termo = dados.get("termo_pessoa", "paciente")
    termo_cap = termo[0].upper() + termo[1:] if termo else "Paciente"
    psicologo_ou_psicologa = "Psic\u00f3loga" if dados.get("tratamento") == "feminino" else "Psic\u00f3logo"
    crp_verificado = dados.get("crp_verificado", False)
    selo_crp = ' <span style="color:#2E7D32; font-size:12px;">&#10003; Verificado</span>' if crp_verificado else ''
    aceito_msg = ""
    if aceito:
        data_fmt = _formatar_data_br(aceito_em) if aceito_em else ""
        nome_aceite_val = nome_aceite
        aceito_msg = f'<div class="ja-aceito">&#10003; Aceito por {html.escape(nome_aceite_val)} em {data_fmt}</div>'

    page_html = f"""<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Acordo Terap\u00eautico - MentAll PRO</title>
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: #F7F9FA;
    color: #1E293B;
    line-height: 1.7;
    padding: 24px 16px;
  }}
  .container {{
    max-width: 640px;
    margin: 0 auto;
    background: #fff;
    border-radius: 18px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.08);
    padding: 40px 28px;
    position: relative;
  }}
  .logo-mentall {{
    position: absolute;
    top: 20px;
    right: 28px;
    font-size: 12px;
    font-weight: 700;
    color: #C77DFF;
    opacity: 0.45;
    letter-spacing: 0.5px;
  }}
  .cabecalho-profissional {{
    margin-bottom: 6px;
  }}
  .cabecalho-profissional .profissional-nome {{
    font-size: 16px;
    font-weight: 700;
    color: #1E293B;
  }}
  .cabecalho-profissional .profissional-crp {{
    font-size: 16px;
    color: #1E293B;
    margin-top: 1px;
  }}
  .paciente-info {{
    font-size: 16px;
    color: #1E293B;
    margin-bottom: 28px;
    padding-bottom: 16px;
    border-bottom: 1px solid #E2E8F0;
  }}
  .paciente-info strong {{
    color: #1E293B;
  }}
  .titulo-acordo {{
    text-align: center;
    font-size: 20px;
    font-weight: 700;
    color: #3C096C;
    margin-bottom: 0;
    padding-bottom: 0;
    letter-spacing: 0.5px;
  }}
  h2 {{
    font-size: 16px;
    color: #1E293B;
    font-weight: 700;
    margin: 28px 0 12px;
  }}
  p {{ font-size: 16px; color: #334155; margin-bottom: 6px; text-align: justify; }}
  .assinatura {{
    margin-top: 36px;
    padding-top: 20px;
    border-top: 1px solid #E2E8F0;
  }}
  .assinatura p {{ margin: 14px 0; font-size: 14px; }}
  .linha {{
    display: inline-block;
    border-bottom: 1px solid #94A3B8;
    min-width: 200px;
    margin-left: 6px;
  }}
  .secao-aceite {{
    margin-top: 32px;
    padding: 24px;
    background: #F8FAFC;
    border-radius: 12px;
    border: 1px solid #E2E8F0;
  }}
  .secao-aceite label {{
    display: block;
    font-size: 14px;
    font-weight: 600;
    color: #1E293B;
    margin-bottom: 8px;
  }}
  .secao-aceite input[type="text"] {{
    width: 100%;
    padding: 12px;
    border: 1px solid #CBD5E1;
    border-radius: 10px;
    font-size: 16px;
    margin-bottom: 16px;
    outline: none;
  }}
  .secao-aceite input[type="text"]:focus {{
    border-color: #8806CE;
    box-shadow: 0 0 0 3px rgba(136,6,206,0.12);
  }}
  .btn-aceitar {{
    width: 100%;
    padding: 14px;
    background: #8806CE;
    color: #fff;
    font-size: 16px;
    font-weight: 600;
    border: none;
    border-radius: 12px;
    cursor: pointer;
  }}
  .btn-aceitar:disabled {{ background: #94A3B8; cursor: not-allowed; }}
  .sucesso {{
    background: #F0FDF4;
    border: 1px solid #BBF7D0;
    color: #166534;
    padding: 16px;
    border-radius: 10px;
    text-align: center;
    font-size: 15px;
    margin-top: 16px;
  }}
  .erro {{
    background: #FEF2F2;
    border: 1px solid #FECACA;
    color: #991B1B;
    padding: 12px;
    border-radius: 10px;
    text-align: center;
    font-size: 14px;
    margin-top: 12px;
  }}
  .ja-aceito {{
    background: #F0FDF4;
    border: 1px solid #BBF7D0;
    color: #166534;
    padding: 20px;
    border-radius: 10px;
    text-align: center;
    font-size: 15px;
  }}
  .confirmacao {{
    font-size: 13px;
    color: #64748B;
    text-align: center;
    margin-top: 12px;
  }}
  .footer {{
    text-align: center;
    margin-top: 28px;
    font-size: 12px;
    color: #94A3B8;
  }}
</style>
</head>
<body>
<div class="container">
  <div class="logo-mentall">MentAll PRO</div>

  <div class="cabecalho-profissional">
    <div class="profissional-nome">{html.escape(psicologo_ou_psicologa)} {html.escape(nome_profissional)}</div>
    <div class="profissional-crp">CRP {html.escape(registro)}{selo_crp}</div>
  </div>

  <div class="paciente-info">
    <strong>Paciente:</strong> {html.escape(nome_paciente)}
  </div>

  <div class="titulo-acordo">Acordo Terap\u00eautico</div>
  {_renderizar_paragrafos_personalizados(texto)}
  {aceito_msg}
  {"".join(f'''<div class="secao-aceite" id="secao-aceite">
    <label for="nome-confirmacao">Digite seu nome completo para confirmar:</label>
    <input type="text" id="nome-confirmacao" placeholder="Seu nome completo" autocomplete="off">
    <button class="btn-aceitar" id="btn-aceitar" onclick="aceitar()">Li e aceito</button>
    <div id="erro-msg" class="erro" style="display:none;"></div>
    <div class="confirmacao">Ao marcar "Li e aceito", {html.escape(termo)} declara que leu, compreendeu e concorda com os termos deste acordo.</div>
  </div>
  <div id="sucesso-msg" class="sucesso" style="display:none;">Obrigado! Seu aceite foi registrado. O profissional ser\u00e1 notificado.</div>''' if not aceito else "")}
  <div class="footer">MentAll PRO \u2014 Solu\u00e7\u00f5es para Psic\u00f3logos</div>
</div>
<script>
function formatarDataLocal(d) {{
  if (!d || isNaN(d.getTime())) return '';
  return String(d.getDate()).padStart(2,'0') + '/' + String(d.getMonth()+1).padStart(2,'0') + '/' + d.getFullYear() + ' \\u00e0s ' + String(d.getHours()).padStart(2,'0') + ':' + String(d.getMinutes()).padStart(2,'0');
}}
(function() {{
  var els = document.getElementsByClassName('js-data-local');
  for (var i = 0; i < els.length; i++) els[i].textContent = formatarDataLocal(new Date());
}})();
async function aceitar() {{
  var nome = document.getElementById('nome-confirmacao').value.trim();
  var erroEl = document.getElementById('erro-msg');
  if (!nome || nome.length < 3) {{ erroEl.textContent = 'Digite seu nome completo.'; erroEl.style.display = 'block'; return; }}
  var btn = document.getElementById('btn-aceitar');
  btn.disabled = true; btn.textContent = 'Enviando...'; erroEl.style.display = 'none';
  try {{
    var resp = await fetch('/contratos/{token}/aceitar', {{ method: 'POST', headers: {{'Content-Type': 'application/json'}}, body: JSON.stringify({{nome: nome}}) }});
    if (resp.ok) {{ document.getElementById('secao-aceite').style.display = 'none'; document.getElementById('sucesso-msg').style.display = 'block'; }}
    else {{ var d = await resp.json(); erroEl.textContent = d.erro || d.detail || 'Erro ao registrar.'; erroEl.style.display = 'block'; btn.disabled = false; btn.textContent = 'Li e aceito'; }}
  }} catch(e) {{ erroEl.textContent = 'Erro de conex\\u00e3o.'; erroEl.style.display = 'block'; btn.disabled = false; btn.textContent = 'Li e aceito'; }}
}}
</script>
</body>
</html>"""
    return HTMLResponse(content=_com_nonce_script(page_html, nonce))


def _verificar_senha(senha: str) -> bool:
    if not APP_PASSWORD_HASH:
        return False
    try:
        return pwd_context.verify(senha, APP_PASSWORD_HASH)
    except Exception:
        return False


def _senha_forte(senha: str) -> bool:
    """Senha forte: >= 10 chars com maiuscula, minuscula e numero."""
    if len(senha) < 10:
        return False
    if not any(c.isupper() for c in senha):
        return False
    if not any(c.islower() for c in senha):
        return False
    if not any(c.isdigit() for c in senha):
        return False
    return True


def _validar_registro_ou_raise(request) -> None:
    """Valida e-mail e senha do cadastro (fail-closed antes de persistir).

    Combate a senha fraca (ex: '123456') que, junto com o rate-limit
    burlavel, permitia brute-force online de contas."""
    email = request.email.strip().lower()
    if "@" not in email or "." not in email.split("@")[-1]:
        raise HTTPException(status_code=422, detail="Email invalido.")
    if not _senha_forte(request.senha):
        raise HTTPException(
            status_code=422,
            detail="A senha deve ter pelo menos 10 caracteres, com letras maiusculas, minusculas e numeros.",
        )
def _criar_token_jwt(username: str, owner_id: str, token_version: int | None = None) -> str:
    expiracao = datetime.now(timezone.utc) + timedelta(minutes=JWT_EXPIRATION)
    payload = {"sub": username, "exp": expiracao, "owner": owner_id, "jti": uuid.uuid4().hex}
    if token_version is not None:
        # "tv": versão da sessão do app. Sobe quando o admin encerra as sessões
        # do usuário (ou suspende a conta); token com tv antigo deixa de valer.
        payload["tv"] = int(token_version)
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def _revogar_token(jti: str, exp: str = "") -> None:
    """Marca um jti como revogado (logout do painel / exclusão de conta).

    O gate do painel consulta esta lista, então o cookie deixa de valer na hora —
    antes o "Sair" só apagava o cookie e o JWT continuava válido até expirar.
    """
    if not jti:
        return
    try:
        from services.db import executar as _executar

        _executar(
            "INSERT OR REPLACE INTO tokens_revogados (jti, exp, criado_em) VALUES (?, ?, ?)",
            (str(jti), str(exp or ""), datetime.now(timezone.utc).isoformat()),
        ).commit()
    except Exception:
        log.exception("Falha ao revogar token do painel")


_ESTADO_TOKEN_CACHE: dict[str, tuple[int, str, float]] = {}
_ESTADO_TOKEN_TTL_SEGUNDOS = 30.0


def _invalidar_cache_token(usuario_id: str) -> None:
    """Limpa o cache de estado do usuário (chamado pelas ações do painel)."""
    _ESTADO_TOKEN_CACHE.pop(str(usuario_id), None)


def _estado_token_usuario(usuario_id: str) -> tuple[int, str]:
    """(token_version, status) do dono do token, com cache de 30 s.

    O cache evita 1 leitura de banco por chamada autenticada do app; as ações do
    painel invalidam a chave na hora. Com mais de uma instância do backend, a
    revogação pode levar até 30 s para valer nas outras — trade-off documentado.
    """
    chave = str(usuario_id)
    agora = time.time()
    cache = _ESTADO_TOKEN_CACHE.get(chave)
    if cache and agora - cache[2] < _ESTADO_TOKEN_TTL_SEGUNDOS:
        return cache[0], cache[1]
    from services.usuarios import obter_por_id

    usuario = obter_por_id(chave)
    if usuario is None:
        estado = (-1, "inexistente")
    else:
        estado = (int(usuario.get("token_version") or 0), str(usuario.get("status") or ""))
    _ESTADO_TOKEN_CACHE[chave] = (estado[0], estado[1], agora)
    return estado


def _verificar_token(credentials: HTTPAuthorizationCredentials = Depends(security)) -> tuple[str, str]:
    token = credentials.credentials
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        username: str | None = payload.get("sub")
        owner_id: str | None = payload.get("owner")
        if username is None or owner_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token invalido.",
            )
        jti = payload.get("jti")
        if jti and _token_revogado(str(jti)):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Sessão encerrada. Faça login novamente.",
            )
        tv = payload.get("tv")
        if tv is not None and owner_id != APP_USER_ID:
            versao_atual, status_conta = _estado_token_usuario(owner_id)
            if status_conta != "ativo":
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Conta indisponível. Fale com o suporte.",
                )
            if int(tv) != versao_atual:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Sessão encerrada. Faça login novamente.",
                )
        return username, owner_id
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token invalido ou expirado.",
        )


@asynccontextmanager
async def lifespan(app: FastAPI):
    provider = os.getenv("IA_MODEL_PROVIDER", "openai").strip().lower()
    api_key = ""

    if provider == "openai":
        api_key = os.getenv("OPENAI_API_KEY", "")
    elif provider == "gemini":
        api_key = os.getenv("GEMINI_API_KEY", "")

    if not api_key or api_key.startswith("sua_chave"):
        print(f"ATENCAO: chave de API para {provider} não configurada.")

    model = _get_model_name(provider)
    print(f"Modelo de IA: {provider}/{model}")

    iniciar_scheduler()
    iniciar_alertas_email()
    email_novos.iniciar_avisos_email()
    custos.iniciar_sync_automatico()
    yield
    await parar_scheduler()
    await parar_alertas_email()
    await email_novos.parar_avisos_email()
    custos.parar_sync_automatico()


app = FastAPI(
    title="MentAll PRO API",
    description="Backend de IA para o prontuário clínico MentAll PRO",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        # NAO reintroduzir mentall-api.onrender.com: a plataforma foi
        # abandonada e o subdominio pode ser registrado por terceiros, que
        # passariam a ser origem confiavel desta API (com credentials).
        "https://rodrigolemospsi.github.io",
        "https://mentallpro.com.br",
        "https://www.mentallpro.com.br",
        "https://mentall-site.vercel.app",
        "http://localhost:5000",
        "http://localhost:8000",
        "http://localhost:3000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Security headers middleware
@app.middleware("http")
async def _security_headers(request: Request, call_next):
    # Nonce por resposta para o CSP: o <script> inline só executa com este nonce
    # (substitui o 'unsafe-inline' do script-src).
    request.state.csp_nonce = secrets.token_urlsafe(16)
    if request.method in ("POST", "PUT", "PATCH", "DELETE") and request.url.path.startswith("/admin"):
        if not _origem_permitida(request):
            return JSONResponse(
                {"detail": "Origem da requisição não permitida."}, status_code=403
            )
    response = await call_next(request)
    if request.url.path.startswith("/anamneses/"):
        response.headers["Cache-Control"] = "no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
    if "text/html" in (response.headers.get("content-type") or ""):
        nonce = getattr(request.state, "csp_nonce", "")
        response.headers["Content-Security-Policy"] = (
            f"default-src 'self'; script-src 'self' 'nonce-{nonce}'; "
            "style-src 'self' 'unsafe-inline'; frame-ancestors 'none'; base-uri 'self'"
        )
    return response

@app.get("/health", response_model=HealthResponse, tags=["Health"])
def health():
    db_info = "unknown"
    try:
        from services.db import _usa_turso
        db_info = "turso" if _usa_turso else "sqlite_local"
    except Exception:
        pass
    return HealthResponse(
        status="ok",
        versao="1.0.0",
        debug_info={"database": db_info},
    )


@app.post("/auth/login", response_model=LoginResponse, tags=["Autenticação"])
def login(request: LoginRequest, _req: Request):
    _rate_limit_check(_req, max_requests=10, chave_extra="conta:" + request.username.strip().lower())

    username = request.username.strip()

    # 1) Admin legado (owner fixo, preserva dados existentes)
    if username == APP_USERNAME and _verificar_senha(request.password):
        token = _criar_token_jwt(username, APP_USER_ID)
        log.info("Login admin legado bem-sucedido (IP: %s)", _cliente_ip(_req))
        return LoginResponse(
            access_token=token,
            usuario_id=APP_USER_ID,
            email=username,
            nome="",
            plano="pro",
        )

    # 2) Conta de psicologo cadastrada
    from services.usuarios import autenticar, registrar_acesso

    usuario = autenticar(username, request.password)
    if usuario is None:
        log.warning("Falha de autenticação para usuário '%s' (IP: %s)", _mascarar_contato(username), _cliente_ip(_req))
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciais inválidas.",
        )

    if usuario["status"] == "pendente":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Conta não confirmada. Verifique seu e-mail.",
        )


    if usuario["status"] != "ativo":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Conta suspensa. Fale com o suporte.",
        )

    registrar_acesso(usuario["id"])
    token = _criar_token_jwt(
        usuario["email"],
        usuario["id"],
        token_version=int(usuario.get("token_version") or 0),
    )
    log.info("Login bem-sucedido para usuário '%s' (IP: %s)", _mascarar_contato(usuario["email"]), _cliente_ip(_req))
    return LoginResponse(
        access_token=token,
        usuario_id=usuario["id"],
        email=usuario["email"],
        nome=usuario["nome"],
        plano=usuario["plano"],
    )


@app.post("/auth/registrar", response_model=RegistrarResponse, tags=["Autenticação"])
async def registrar(request: RegistrarRequest, _req: Request):
    _rate_limit_check(_req, max_requests=5, chave_extra="conta:" + request.email.strip().lower())

    _validar_registro_ou_raise(request)
    email = request.email.strip().lower()

    from services.usuarios import criar_usuario_pendente, obter_por_email

    existente = obter_por_email(email)
    if existente is not None and existente["status"] != "pendente":
        raise HTTPException(status_code=409, detail="E-mail já cadastrado.")

    token = criar_usuario_pendente(email, request.senha, request.nome)
    if token is None:
        raise HTTPException(status_code=409, detail="E-mail já cadastrado.")

    base_url = os.getenv("API_BASE_URL", "https://mentall-api.fly.dev")
    link = f"{base_url}/auth/confirmar-email?token={token}"
    corpo = f"""<html><body style="font-family:sans-serif;padding:20px;">
<h2>MentAll PRO - Confirme seu cadastro</h2>
<p>Obrigado por criar sua conta no MentAll PRO.</p>
<p>Para ativar sua conta, clique no link abaixo (valido por 60 minutos):</p>
<p><a href="{link}" style="display:inline-block;padding:12px 20px;background:#8806CE;color:#fff;
text-decoration:none;border-radius:8px;">Confirmar meu cadastro</a></p>
<p style="font-size:13px;color:#64748B;">Se você não criou esta conta, ignore este e-mail.</p>
</body></html>"""

    enviado = await _enviar_email(email, "MentAll PRO - Confirme seu cadastro", corpo)
    log.info("Cadastro solicitado para email %s (link enviado=%s)", _mascarar_contato(email), enviado)

    return RegistrarResponse(
        sucesso=True,
        mensagem="Link de confirmação enviado para o e-mail." if enviado
        else "Conta criada, mas o e-mail não está disponível no momento.",
    )


@app.get("/auth/confirmar-email", response_class=HTMLResponse, tags=["Autenticação"])
def confirmar_email(token: str, _req: Request):
    _rate_limit_check(_req, max_requests=30)

    from services.usuarios import confirmar_email as _confirmar

    usuario = _confirmar(token)
    if usuario is None:
        return HTMLResponse(
            content="""<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>MentAll PRO</title></head>
<body style="font-family:sans-serif;text-align:center;padding:40px;">
<h2 style="color:#D32F2F;">Link invalido ou expirado</h2>
<p>Este link de confirmação não é mais válido. Volte ao app e solicite um novo link.</p>
</body></html>""",
            status_code=400,
        )

    return HTMLResponse(
        content="""<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>MentAll PRO</title></head>
<body style="font-family:sans-serif;text-align:center;padding:40px;">
<div style="width:64px;height:64px;border-radius:50%;background:#E8F5E9;color:#2E7D32;
font-size:32px;display:flex;align-items:center;justify-content:center;margin:0 auto 20px;">&#10003;</div>
<h2 style="color:#1E293B;">Conta confirmada!</h2>
<p style="color:#64748B;">Sua conta está ativa. Volte ao app e toque em "Ja confirmei" para entrar.</p>
</body></html>""",
    )


@app.post(
    "/verificar-crp",
    response_model=VerificarCrpResponse,
    tags=["CRP"],
    dependencies=[Depends(_verificar_token)],
)
def verificar_crp(request: VerificarCrpRequest, _req: Request):
    _rate_limit_check(_req, max_requests=5, chave_extra="crp:" + request.registro.strip().lower())

    log.info("Verificacao de CRP solicitada: %s", request.registro[:8])
    resultado = verificar_crp_online(request.registro)

    return VerificarCrpResponse(
        sucesso=True,
        ativo=resultado["ativo"],
        nome_oficial=resultado.get("nome_oficial", ""),
        data_inscricao=resultado.get("data_inscricao", ""),
        erro=resultado.get("erro", ""),
    )


def _owner_do_request(req: Request) -> str:
    """owner_id do token do app, para atribuir custo ao profissional."""
    cabecalho = req.headers.get("authorization") or ""
    if not cabecalho.lower().startswith("bearer "):
        return ""
    try:
        payload = jwt.decode(
            cabecalho.split(" ", 1)[1].strip(), JWT_SECRET, algorithms=[JWT_ALGORITHM]
        )
        return str(payload.get("owner") or "")
    except Exception:
        return ""


@app.post(
    "/transcrever",
    response_model=TranscricaoResponse,
    tags=["Transcricao"],
    dependencies=[Depends(_verificar_token)],
)
async def transcrever(request: TranscricaoRequest, req: Request):
    _rate_limit_check(req, max_requests=10)

    content_length = req.headers.get("content-length")
    max_body = 35 * 1024 * 1024  # 35MB (25MB audio + base64 overhead + JSON)
    if content_length and int(content_length) > max_body:
        raise HTTPException(status_code=413, detail="Arquivo de audio muito grande. Maximo: 25MB.")

    if not request.audio_base64:
        raise HTTPException(status_code=400, detail="Nenhum audio informado.")

    log.info("Solicitação de transcrição recebida (formato: %s)", request.formato)
    loop = asyncio.get_running_loop()
    resultado = await loop.run_in_executor(
        None, transcrever_audio, request.audio_base64, request.formato, _owner_do_request(req),
    )

    if not resultado["sucesso"]:
        log.error("Falha na transcrição: %s", resultado["erro"])
        return TranscricaoResponse(sucesso=False, transcricao="", erro=resultado["erro"])

    log.info("Transcricao concluida com sucesso (%d caracteres)", len(resultado["transcricao"]))
    return TranscricaoResponse(sucesso=True, transcricao=resultado["transcricao"], erro="")


@app.post(
    "/gerar-sintese",
    response_model=SinteseResponse,
    tags=["IA Clinica"],
    dependencies=[Depends(_verificar_token)],
)
async def sintese(request: SinteseRequest, _req: Request):
    _rate_limit_check(_req, max_requests=30)

    log.info(
        "Solicitação de síntese - sessao_id=%s sessão=%d abordagem=%s",
        request.sessao_id[:8],
        request.numero_sessao,
        request.abordagem_clinica,
    )
    loop = asyncio.get_running_loop()
    resultado = await loop.run_in_executor(
        None,
        gerar_sintese,
        request.sessao_id,
        request.numero_sessao,
        request.nome_pessoa_atendida,
        request.termo_pessoa_atendida,
        request.abordagem_clinica,
        request.transcricao_relato,
        request.relato_manual,
        request.tema_principal,
        _owner_do_request(_req),
    )

    if not resultado["sucesso"]:
        log.error("Falha na síntese: %s", resultado["erro"])
        return SinteseResponse(sucesso=False, erro=resultado["erro"])

    log.info("Sintese concluida com sucesso")
    return SinteseResponse(
        sucesso=True,
        relato_clinico_organizado=resultado["relato_clinico_organizado"],
        apontamentos_copiloto=resultado["apontamentos_copiloto"],
        sintese_clinica=resultado["sintese_clinica"],
        formulacao_clinica=resultado["formulacao_clinica"],
        intervencoes=resultado["intervencoes"],
        plano_proxima_sessao=resultado["plano_proxima_sessao"],
        temas_pesquisa=resultado.get("temas_pesquisa", []),
        artigos_sugeridos=resultado.get("artigos_sugeridos", ""),
        erro="",
        provedor=resultado.get("provedor", ""),
    )


@app.post(
    "/reportar-sintese",
    response_model=ReporteSinteseResponse,
    tags=["IA Clinica"],
)
async def reportar_sintese(
    request: ReporteSinteseRequest,
    _req: Request,
    auth: tuple = Depends(_verificar_token),
):
    """Reporte in-app de saída de IA inadequada (requisito do Google Play, item 3.4).

    Recebe só metadados (motivo e observação opcional) — nenhum conteúdo
    clínico. O protocolo devolvido permite acompanhar o reporte no suporte.
    """
    _rate_limit_check(_req, max_requests=10)
    _, owner_id = auth
    try:
        protocolo = reportes_ia.registrar_reporte(
            owner_id=owner_id,
            sessao_id=request.sessao_id,
            motivo=request.motivo,
            detalhe=request.detalhe,
            provedor=request.provedor,
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    log.warning(
        "Reporte de saída de IA recebido (protocolo=%s, sessao=%s)",
        protocolo[:8],
        request.sessao_id[:8],
    )
    return ReporteSinteseResponse(sucesso=True, protocolo=protocolo)


@app.post(
    "/gerar-artigos",
    response_model=ArtigosResponse,
    tags=["IA Clinica"],
    dependencies=[Depends(_verificar_token)],
)
async def artigos(request: ArtigosRequest, _req: Request):
    _rate_limit_check(_req, max_requests=30)

    if not request.temas_pesquisa:
        return ArtigosResponse(
            sucesso=False,
            artigos_sugeridos="",
            erro="Nenhum tema de pesquisa informado.",
        )

    log.info("Solicitacao de artigos - temas=%d", len(request.temas_pesquisa))
    loop = asyncio.get_running_loop()
    resultado = await loop.run_in_executor(
        None,
        gerar_artigos,
        request.temas_pesquisa,
    )

    return ArtigosResponse(
        sucesso=resultado.get("sucesso", False),
        artigos_sugeridos=resultado.get("artigos_sugeridos", ""),
        erro=resultado.get("erro", ""),
    )


@app.post(
    "/gerar-progresso",
    response_model=ProgressoResponse,
    tags=["IA Clinica"],
    dependencies=[Depends(_verificar_token)],
)
async def progresso(request: ProgressoRequest, _req: Request):
    _rate_limit_check(_req, max_requests=30)

    log.info(
        "Solicitação de progresso - paciente=%s sessão=%d",
        request.paciente_id[:8],
        request.numero_sessao,
    )
    loop = asyncio.get_running_loop()
    resultado = await loop.run_in_executor(
        None,
        gerar_progresso,
        request.paciente_id,
        request.numero_sessao,
        request.sessoes_anteriores,
        request.sessao_atual,
        request.objetivos_terapeuticos,
        request.queixa_principal,
        request.escalas,
    )

    if not resultado.get("sintomas"):
        return ProgressoResponse(sucesso=False, erro=resultado.get("erro", "Erro ao gerar progresso"))

    log.info("Progresso concluído com sucesso")
    return ProgressoResponse(
        sucesso=True,
        sintomas=resultado.get("sintomas", []),
        metas=resultado.get("metas", []),
        avaliacao_geral=resultado.get("avaliacao_geral", ""),
        tendencia=resultado.get("tendencia", "estavel"),
        recomendacoes=resultado.get("recomendacoes", ""),
        erro="",
    )


@app.post(
    "/enviar-whatsapp",
    response_model=WhatsAppResponse,
    tags=["Mensagens"],
    dependencies=[Depends(_verificar_token)],
)
def enviar_whatsapp(request: WhatsAppRequest, _req: Request, auth: tuple = Depends(_verificar_token)):
    _rate_limit_check(_req, max_requests=10)
    if not request.telefone.strip():
        raise HTTPException(status_code=400, detail="Telefone não informado.")
    if not request.mensagem.strip():
        raise HTTPException(status_code=400, detail="Mensagem não informada.")

    _, owner_id = auth
    sucesso, _ = _enviar_whatsapp_via_wuzapi(owner_id, request.telefone, request.mensagem)
    if sucesso:
        return WhatsAppResponse(
            sucesso=True,
            mensagem=f"WhatsApp enviado para {request.telefone.strip()}",
        )
    return WhatsAppResponse(
        sucesso=False,
        erro="Não foi possível enviar o WhatsApp. Verifique se o wuzapi está conectado.",
    )


@app.post(
    "/wuzapi/config",
    response_model=WhatsAppResponse,
    tags=["Mensagens"],
    dependencies=[Depends(_verificar_token)],
)
def configurar_wuzapi(request: WuzapiConfigRequest, _req: Request, auth: tuple = Depends(_verificar_token)):
    _rate_limit_check(_req, max_requests=10)
    _, owner_id = auth

    if not request.wuzapi_token.strip():
        raise HTTPException(status_code=400, detail="Token do wuzapi não informado.")

    salvar_instancia_wuzapi(
        owner_id=owner_id,
        token=request.wuzapi_token.strip(),
        user_id=request.wuzapi_user_id,
        conectado=True,
    )
    return WhatsAppResponse(
        sucesso=True,
        mensagem="Instancia wuzapi configurada.",
    )


@app.get(
    "/wuzapi/status",
    response_model=WuzapiStatusResponse,
    tags=["Mensagens"],
    dependencies=[Depends(_verificar_token)],
)
def wuzapi_status(_req: Request, auth: tuple = Depends(_verificar_token)):
    """Estado da conexao do WhatsApp do profissional (para a tela de configuracoes)."""
    _rate_limit_check(_req, max_requests=60)
    _, owner_id = auth
    estado = wuzapi_admin.sincronizar_status(owner_id, timeout=10)
    return WuzapiStatusResponse(sucesso=True, **estado)


@app.post(
    "/wuzapi/parear",
    response_model=WuzapiParearResponse,
    tags=["Mensagens"],
    dependencies=[Depends(_verificar_token)],
)
def wuzapi_parear(request: WuzapiParearRequest, _req: Request,
                  auth: tuple = Depends(_verificar_token)):
    """Gera o codigo de pareamento (vincula o WhatsApp no mesmo celular, sem QR)."""
    _rate_limit_check(_req, max_requests=10)
    if not request.telefone.strip():
        raise HTTPException(status_code=400, detail="Telefone não informado.")
    _, owner_id = auth
    return WuzapiParearResponse(**wuzapi_admin.parear(owner_id, request.telefone))


@app.get(
    "/wuzapi/qr",
    response_model=WuzapiQrResponse,
    tags=["Mensagens"],
    dependencies=[Depends(_verificar_token)],
)
def wuzapi_qr(_req: Request, auth: tuple = Depends(_verificar_token)):
    """QR Code (data URI) como alternativa ao codigo de pareamento."""
    _rate_limit_check(_req, max_requests=30)
    _, owner_id = auth
    return WuzapiQrResponse(**wuzapi_admin.qr(owner_id))


@app.post(
    "/wuzapi/desconectar",
    response_model=WhatsAppResponse,
    tags=["Mensagens"],
    dependencies=[Depends(_verificar_token)],
)
def wuzapi_desconectar(request: WuzapiDesconectarRequest, _req: Request,
                       auth: tuple = Depends(_verificar_token)):
    """Desconecta a sessao (logout=False) ou desvincula o aparelho (logout=True)."""
    _rate_limit_check(_req, max_requests=10)
    _, owner_id = auth
    if wuzapi_admin.desconectar(owner_id, logout=request.logout):
        mensagem = "WhatsApp desconectado." if request.logout else "Conexão pausada."
        return WhatsAppResponse(sucesso=True, mensagem=mensagem)
    return WhatsAppResponse(sucesso=False, erro="Não foi possível desconectar o WhatsApp.")


@app.post(
    "/wuzapi/testar",
    response_model=WhatsAppResponse,
    tags=["Mensagens"],
    dependencies=[Depends(_verificar_token)],
)
def wuzapi_testar(request: WuzapiTestarRequest, _req: Request,
                  auth: tuple = Depends(_verificar_token)):
    """Envia uma mensagem de teste pelo WhatsApp conectado do profissional."""
    _rate_limit_check(_req, max_requests=10)
    if not request.telefone.strip():
        raise HTTPException(status_code=400, detail="Telefone não informado.")
    _, owner_id = auth
    mensagem_teste = (
        "MentAll PRO: este é um teste de conexão do WhatsApp. "
        "Se você recebeu esta mensagem, os lembretes automáticos estão funcionando."
    )
    resultado = wuzapi_admin.testar(owner_id, request.telefone, mensagem_teste)
    if resultado["sucesso"]:
        return WhatsAppResponse(sucesso=True, mensagem="Mensagem de teste enviada.")
    return WhatsAppResponse(sucesso=False, erro=resultado["erro"])


def _extrair_token_webhook(request: Request) -> str:
    """Extrai o token do webhook do wuzapi: header Authorization preferido,
    query string como fallback de transicao."""
    auth_header = request.headers.get("authorization", "")
    if auth_header.lower().startswith("bearer "):
        return auth_header[7:].strip()
    return request.query_params.get("token", "")


def _token_webhook_valido(recebido: str, esperado: str) -> bool:
    import secrets as _secrets
    if not esperado or not recebido:
        return False
    return _secrets.compare_digest(recebido, esperado)


@app.post("/wuzapi/webhook", tags=["Mensagens"])
async def webhook_wuzapi(request: Request):
    """Recebe os webhooks do wuzapi (ReadReceipt/Message).

    O wuzapi POSTa eventos assinados (Message, ReadReceipt) para a URL
    configurada. Aqui processamos apenas os ReadReceipt que confirmam a
    entrega/leitura das mensagens de lembrete, correlacionando pelo
    ``mensagem_id`` gravado no envio.

    Autenticacao via header ``Authorization: Bearer <token>`` (preferido,
    nao aparece em access logs). Por compatibilidade de transicao o token
    tambem e aceito em ``?token=...`` (query string), mas o uso do header e
    recomendado para nao vazar o segredo em logs.
    """
    _rate_limit_check(request, max_requests=120)

    esperado = os.getenv("WUZAPI_WEBHOOK_TOKEN", "").strip()
    recebido = _extrair_token_webhook(request)
    if not _token_webhook_valido(recebido, esperado):
        log.warning("Webhook wuzapi rejeitado: token invalido.")
        raise HTTPException(status_code=403, detail="Token invalido.")

    # Limite de tamanho do payload (1 MB) para evitar DoS por corpo gigante.
    content_length = request.headers.get("content-length")
    if content_length and content_length.isdigit() and int(content_length) > 1_000_000:
        log.warning("Webhook wuzapi rejeitado: payload muito grande (%s bytes).", content_length)
        return JSONResponse(status_code=200, content={"success": True})

    try:
        content_type = (request.headers.get("content-type") or "").lower()
        if "application/json" in content_type:
            payload = await request.json()
        else:
            form = await request.form()
            json_str = form.get("jsonData", "")
            if not json_str:
                log.warning("Webhook wuzapi sem jsonData.")
                return JSONResponse(status_code=200, content={"success": True})
            if len(json_str) > 1_000_000:
                log.warning("Webhook wuzapi rejeitado: jsonData muito grande.")
                return JSONResponse(status_code=200, content={"success": True})
            payload = json.loads(json_str)
    except Exception as e:
        log.error("Webhook wuzapi invalido: %s", e)
        return JSONResponse(status_code=200, content={"success": True})

    atualizados = registrar_receipt(payload)
    log.info(
        "Webhook wuzapi %s recebido (state=%s, lembretes atualizados=%s)",
        payload.get("type"), payload.get("state"), atualizados,
    )
    return JSONResponse(status_code=200, content={"success": True, "atualizados": atualizados})


@app.delete("/conta", tags=["Conta"])
def excluir_conta(request: ExcluirContaRequest, _req: Request,
                  auth: tuple = Depends(_verificar_token)):
    """Exclusão de conta do psicólogo (caminho B).

    Apaga conta e dados do servidor; o prontuário cifrado permanece no aparelho.
    Exige confirmação explícita e protege a conta administrativa legada.
    """
    _rate_limit_check(_req, max_requests=5)
    if (request.confirmacao or "").strip().upper() != "EXCLUIR":
        raise HTTPException(status_code=400, detail="Confirmação inválida. Envie 'EXCLUIR'.")

    username, owner_id = auth
    if not _pode_excluir_conta(owner_id):
        raise HTTPException(
            status_code=403,
            detail="A conta administrativa não pode ser excluída pelo aplicativo.",
        )

    from services.usuarios import obter_por_id
    usuario = obter_por_id(owner_id)
    email = (usuario or {}).get("email") or (username or "")

    jti, exp_token = "", ""
    try:
        raw = (_req.headers.get("authorization") or "").strip()
        if raw.lower().startswith("bearer "):
            payload = jwt.decode(raw[7:], JWT_SECRET, algorithms=[JWT_ALGORITHM])
            jti = str(payload.get("jti") or "")
            exp_token = str(payload.get("exp") or "")
    except Exception:
        pass

    try:
        recibo = _excluir_conta_dados(owner_id, email, jti=jti, exp_token=exp_token)
    except PermissionError as exc:
        raise HTTPException(status_code=403, detail=str(exc))

    if usuario is None:
        recibo["ja_excluida"] = True
    log.info("Exclusão de conta concluída: owner=%s", owner_id[:8])
    return JSONResponse(status_code=200, content=recibo)


@app.exception_handler(Exception)
async def _global_exception_handler(request: Request, exc: Exception):
    log.exception("Erro interno não tratado: %s", exc)
    return JSONResponse(
        status_code=500,
        content={"sucesso": False, "erro": "Erro interno do servidor"},
    )


@app.post(
    "/contratos",
    response_model=ContratoResponse,
    tags=["Contratos"],
    dependencies=[Depends(_verificar_token)],
)
def criar_contrato_endpoint(request: ContratoRequest, _req: Request, auth: tuple = Depends(_verificar_token)):
    _rate_limit_check(_req, max_requests=10)
    _, owner_id = auth
    if not request.nome_paciente.strip():
        raise HTTPException(status_code=400, detail="Nome do paciente não informado.")
    if not request.nome_profissional.strip():
        raise HTTPException(status_code=400, detail="Nome do profissional não informado.")

    dados = {
        "nome_paciente": request.nome_paciente.strip(),
        "nome_profissional": request.nome_profissional.strip(),
        "registro_profissional": request.registro_profissional.strip(),
        "termo_pessoa": request.termo_pessoa.strip() or "paciente",
        "template_contrato": request.template_contrato.strip(),
        "tratamento": request.tratamento.strip() or "masculino",
        "crp_verificado": _crp_verificado_servidor(request.registro_profissional, request.crp_verificado),
    }

    token = criar_contrato(dados, owner_id)
    base_url = os.getenv("API_BASE_URL", "https://mentall-api.fly.dev")
    url = f"{base_url}/contratos/{token}"

    log.info("Contrato criado via API: token=%s paciente=%s", token[:8], _mascarar_contato(request.nome_paciente[:20]))
    return ContratoResponse(sucesso=True, token=token, url=url)


@app.get("/contratos/{token}", response_class=HTMLResponse, tags=["Contratos"])
def pagina_contrato(token: str, _req: Request):
    try:
        return _pagina_contrato(token, _req)
    except Exception as e:
        log.exception("Erro ao renderizar contrato %s", token[:8])
        return HTMLResponse(
            content=f"<html><body style='font-family:sans-serif;text-align:center;padding:40px;'>"
            f"<h2 style='color:#D32F2F;'>Erro ao carregar contrato</h2>"
            f"<p>{html.escape(str(e))}</p></body></html>",
            status_code=500,
        )


def _pagina_contrato(token: str, _req: Request):
    _rate_limit_check(_req, max_requests=30)
    contrato = obter_contrato(token)
    if contrato is None:
        return HTMLResponse(
            content="<html><body style='font-family:sans-serif;text-align:center;padding:40px;'>"
            "<h2 style='color:#D32F2F;'>Contrato não encontrado</h2>"
            "<p>O link pode ter expirado ou ser inválido.</p></body></html>",
            status_code=404,
        )

    dados = contrato.get("dados", {})
    termo = dados.get("termo_pessoa", "paciente")
    termo_capitalizado = termo[0].upper() + termo[1:] if termo else "Paciente"
    psicologo_ou_psicologa = "Psic\u00f3loga" if dados.get("tratamento") == "feminino" else "Psic\u00f3logo"

    if termo == "pessoa atendida":
        artigo = "a"
        preposicao = "da"
    elif termo.endswith("a"):
        artigo = "a"
        preposicao = "da"
    else:
        artigo = "o"
        preposicao = "do"

    aceito = contrato["status"] == "aceito"
    base_url = os.getenv("API_BASE_URL", "https://mentall-api.fly.dev")
    aceito_em = contrato.get("aceito_em") or ""
    template_personalizado = dados.get("template_contrato", "")

    if template_personalizado:
        return _renderizar_template_personalizado(
            token=token,
            dados=dados,
            aceito=aceito,
            aceito_em=aceito_em,
            base_url=base_url,
            nome_aceite=contrato.get("nome_aceite") or "",
            nonce=getattr(_req.state, "csp_nonce", ""),
        )

    template_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "templates", "contrato.html")
    page_html = ""
    try:
        with open(template_path, "r", encoding="utf-8") as f:
            page_html = f.read()
    except Exception:
        page_html = "<html><body>Erro ao carregar template.</body></html>"

    substituicoes = {
        "{{nome_paciente}}": html.escape(dados.get("nome_paciente", "")),
        "{{nome_profissional}}": html.escape(dados.get("nome_profissional", "")),
        "{{registro_profissional}}": html.escape(_limpar_crp(dados.get("registro_profissional", "N\u00e3o informado"))),
        "{{termo_pessoa}}": html.escape(termo),
        "{{termo_pessoa_capitalizado}}": html.escape(termo_capitalizado),
        "{{artigo_termo}}": html.escape(artigo),
        "{{preposicao_termo}}": html.escape(preposicao),
        "{{termo_profissional}}": "do psic\u00f3logo",
        "{{psicologo_ou_psicologa}}": html.escape(psicologo_ou_psicologa),
        "{{local_data}}": "",
        "{{url_aceitar}}": f"/contratos/{token}/aceitar",
        "{{data_aceite}}": _formatar_data_br(aceito_em) if aceito_em else "-",
        "{{data_aceite_iso}}": aceito_em or "",
        "{{nome_aceite}}": html.escape(contrato.get("nome_aceite") or ""),
        "{{crp_selo}}": ' <span style="color:#2E7D32; font-size:12px;">&#10003; Verificado</span>' if dados.get("crp_verificado") else "",
        "{% if not aceito %}": "" if aceito else "<!--",
        "{% endif %}": "<!--" if not aceito else "",
    }

    for chave, valor in substituicoes.items():
        page_html = page_html.replace(chave, str(valor))

    page_html = page_html.replace("<!--", "").replace("-->", "")
    page_html = _com_nonce_script(page_html, getattr(_req.state, "csp_nonce", ""))

    return HTMLResponse(content=page_html)


@app.post("/contratos/{token}/aceitar", response_model=ContratoStatusResponse, tags=["Contratos"])
def aceitar_contrato(token: str, request: ContratoAceiteRequest, _req: Request):
    _rate_limit_check(_req, max_requests=10)
    log.info("Aceite de contrato %s por %s", token[:12], _mascarar_contato(request.nome[:30]))
    if not request.nome.strip() or len(request.nome.strip()) < 3:
        raise HTTPException(status_code=400, detail="Nome invalido. Digite seu nome completo.")

    contrato = registrar_aceite(token, request.nome.strip())
    if contrato is None:
        raise HTTPException(status_code=404, detail="Contrato não encontrado.")

    return ContratoStatusResponse(
        sucesso=True,
        status=contrato["status"],
        aceito_em=contrato.get("aceito_em"),
        nome_aceite=contrato.get("nome_aceite"),
    )


@app.get(
    "/contratos/{token}/status",
    response_model=ContratoStatusResponse,
    tags=["Contratos"],
)
def status_contrato(token: str, _req: Request, auth: tuple = Depends(_verificar_token)):
    _rate_limit_check(_req, max_requests=30)
    _, owner_id = auth
    contrato = obter_contrato(token)
    if contrato is None or contrato.get("owner_id") != owner_id:
        return ContratoStatusResponse(sucesso=False, erro="Contrato não encontrado.")

    return ContratoStatusResponse(
        sucesso=True,
        status=contrato["status"],
        aceito_em=contrato.get("aceito_em"),
        nome_aceite=contrato.get("nome_aceite"),
    )


@app.post(
    "/lembretes",
    response_model=LembreteResponse,
    tags=["Lembretes"],
    dependencies=[Depends(_verificar_token)],
)
async def criar_lembrete(request: LembreteRequest, _req: Request, auth: tuple = Depends(_verificar_token)):
    _, owner_id = auth
    _rate_limit_check(_req, max_requests=10)
    if not request.telefone.strip():
        raise HTTPException(status_code=400, detail="Telefone não informado.")
    if not request.mensagem.strip():
        raise HTTPException(status_code=400, detail="Mensagem não informada.")
    if not request.horario_envio.strip():
        raise HTTPException(status_code=400, detail="Horário de envio não informado.")

    rid = await agendar_lembrete(
        compromisso_id=request.compromisso_id,
        telefone=request.telefone.strip(),
        mensagem=request.mensagem.strip(),
        horario_envio=request.horario_envio,
        canal=request.canal or "whatsapp",
        owner_id=owner_id,
    )
    return LembreteResponse(sucesso=True, id=rid)


@app.delete(
    "/lembretes/{compromisso_id}",
    response_model=LembreteResponse,
    tags=["Lembretes"],
    dependencies=[Depends(_verificar_token)],
)
async def remover_lembrete(compromisso_id: str, _req: Request, auth: tuple = Depends(_verificar_token)):
    _rate_limit_check(_req, max_requests=10)
    _, owner_id = auth
    log.info("Remocao de lembrete: %s", compromisso_id[:20])
    ok = await cancelar_lembrete(compromisso_id, owner_id)
    if not ok:
        return LembreteResponse(sucesso=False, erro="Lembrete não encontrado.")
    return LembreteResponse(sucesso=True, id=compromisso_id)


@app.get(
    "/lembretes",
    response_model=LembretesListResponse,
    tags=["Lembretes"],
    dependencies=[Depends(_verificar_token)],
)
def listar_lembretes_endpoint(_req: Request, status: str | None = None, auth: tuple = Depends(_verificar_token)):
    _, owner_id = auth
    _rate_limit_check(_req, max_requests=30)
    linhas = listar_lembretes(owner_id, status)
    itens = [
        LembreteItem(
            id=r["id"],
            compromisso_id=r["compromisso_id"],
            telefone=r.get("telefone") or "",
            mensagem=r.get("mensagem") or "",
            horario_envio=r.get("horario_envio") or "",
            canal=r.get("canal") or "whatsapp",
            status=r.get("status") or "pendente",
            tentativas=r.get("tentativas") or 0,
        )
        for r in linhas
    ]
    return LembretesListResponse(lembretes=itens)


@app.delete(
    "/lembretes",
    response_model=LembretesCancelResponse,
    tags=["Lembretes"],
    dependencies=[Depends(_verificar_token)],
)
async def cancelar_todos_lembretes_endpoint(_req: Request, auth: tuple = Depends(_verificar_token)):
    _, owner_id = auth
    _rate_limit_check(_req, max_requests=5)
    total = await cancelar_todos_lembretes(owner_id)
    log.info("Cancelamento de lembretes em lote: owner=%s cancelados=%s", owner_id[:8], total)
    return LembretesCancelResponse(cancelados=total)


@app.post(
    "/anamneses",
    response_model=AnamneseResponse,
    tags=["Anamnese"],
    dependencies=[Depends(_verificar_token)],
)
def criar_anamnese_endpoint(request: AnamneseRequest, _req: Request, auth: tuple = Depends(_verificar_token)):
    _rate_limit_check(_req, max_requests=10)
    _, owner_id = auth
    if not request.template_json.strip():
        raise HTTPException(status_code=400, detail="Template não informado.")
    if not request.nome_paciente.strip():
        raise HTTPException(status_code=400, detail="Nome do paciente não informado.")

    dados_extra = {
        "nome_paciente": html.escape(request.nome_paciente.strip()),
        "nome_profissional": html.escape(request.nome_profissional.strip()),
        "registro": html.escape(request.registro.strip()),
        "abordagem": request.abordagem.strip(),
        "tratamento": request.tratamento.strip() or "masculino",
        "crp_verificado": _crp_verificado_servidor(request.registro, request.crp_verificado),
    }

    token = criar_anamnese(request.template_json, owner_id, dados_extra)
    base_url = os.getenv("API_BASE_URL", "https://mentall-api.fly.dev")
    url = f"{base_url}/anamneses/{token}"

    log.info("Anamnese criada via API: token=%s paciente=%s abordagem=%s",
             token[:8], _mascarar_contato(request.nome_paciente[:20]), request.abordagem)
    return AnamneseResponse(sucesso=True, token=token, url=url)


@app.get("/anamneses/{token}", response_class=HTMLResponse, tags=["Anamnese"])
def pagina_anamnese(token: str, _req: Request):
    _rate_limit_check(_req, max_requests=30)
    anamnese = obter_anamnese(token)
    if anamnese is None or anamnese["status"] not in ("pendente", "respondido"):
        return HTMLResponse(
            content="<html><body style='font-family:sans-serif;text-align:center;padding:40px;'>"
            "<h2 style='color:#D32F2F;'>Questionário não encontrado</h2>"
            "<p>O link pode ter expirado ou ser inválido.</p></body></html>",
            status_code=404,
        )

    if anamnese["status"] == "respondido":
        dados = anamnese.get("dados_extra", {})
        data_fmt = ""
        if anamnese.get("respondido_em"):
            try:
                dt = datetime.fromisoformat(anamnese["respondido_em"])
                data_fmt = dt.strftime("%d/%m/%Y às %H:%M")
            except Exception:
                pass
        return HTMLResponse(
            content=f"""<!DOCTYPE html>
<html lang="pt-BR">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Anamnese - MentAll PRO</title>
<style>
* {{ margin:0; padding:0; box-sizing:border-box; }}
body {{ font-family:-apple-system,sans-serif; background:#F0F4FF; color:#1E293B; }}
.container {{ max-width:640px; margin:0 auto; padding:48px 20px; text-align:center; }}
.icone {{ width:64px; height:64px; border-radius:50%; background:#E8F5E9; color:#2E7D32;
font-size:32px; display:flex; align-items:center; justify-content:center; margin:0 auto 20px; }}
h2 {{ font-size:20px; color:#1E293B; margin-bottom:8px; }}
p {{ color:#64748B; font-size:15px; }}
.footer {{ margin-top:32px; font-size:12px; color:#94A3B8; }}
</style></head>
<body><div class="container">
<div class="icone">&#10003;</div>
<h2>Questionário já respondido</h2>
<p>Você já enviou suas respostas em {data_fmt}.</p>
<p>O profissional {dados.get('nome_profissional', '')} já as recebeu.</p>
<div class="footer">MentAll PRO - Soluções para Psicólogos</div>
</div></body></html>""",
        )

    dados = anamnese.get("dados_extra", {})
    template_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "templates", "anamnese.html")
    html_base = ""
    try:
        with open(template_path, "r", encoding="utf-8") as f:
            html_base = f.read()
    except Exception:
        return HTMLResponse(
            content="<html><body>Erro ao carregar template.</body></html>",
            status_code=500,
        )

    html = html_base.replace("{{TOKEN}}", token)
    template_json = (anamnese.get("template_json") or "{}").strip()
    bloco_script = _montar_pagina_anamnese_script(dados, template_json)
    html = html.replace("const DADOS_PROFISSIONAL = {{DADOS_PROFISSIONAL}};",
                        bloco_script)
    html = html.replace("const TEMPLATE = {{TEMPLATE}};", "")
    html = _com_nonce_script(html, getattr(_req.state, "csp_nonce", ""))

    return HTMLResponse(content=html)


@app.post(
    "/anamneses/{token}/responder",
    response_model=AnamneseConfirmacaoResponse,
    tags=["Anamnese"],
)
def responder_anamnese(token: str, request: ResponderAnamneseRequest, _req: Request):
    _rate_limit_check(_req, max_requests=10)
    log.info("Resposta de anamnese %s", token[:12])
    if not request.respostas.strip():
        raise HTTPException(status_code=400, detail="Respostas não informadas.")

    try:
        anamnese = registrar_resposta(token, request.respostas)
    except ValueError:
        raise HTTPException(status_code=422, detail="Respostas inválidas. Confira os campos obrigatórios.") from None
    if anamnese is None:
        raise HTTPException(status_code=404, detail="Anamnese não encontrada.")

    return AnamneseConfirmacaoResponse(
        sucesso=True,
        status=anamnese["status"],
    )


@app.get(
    "/anamneses/{token}/status",
    response_model=AnamneseStatusResponse,
    tags=["Anamnese"],
)
def status_anamnese(token: str, _req: Request, auth: tuple = Depends(_verificar_token)):
    _rate_limit_check(_req, max_requests=30)
    _, owner_id = auth
    anamnese = obter_anamnese(token)
    if anamnese is None or anamnese.get("owner_id") != owner_id:
        return AnamneseStatusResponse(sucesso=False, erro="Anamnese não encontrada.")

    return AnamneseStatusResponse(
        sucesso=True,
        status=anamnese["status"],
        data_resposta=anamnese.get("respondido_em"),
        respostas_json=anamnese.get("respostas", "") or "",
    )


CODIGO_RECUPERACAO_COMPRIMENTO = 8
MAX_TENTATIVAS_RECUPERACAO = 5
BLOQUEIO_RECUPERACAO_MINUTOS = 15


def _gerar_codigo() -> str:
    """Gera um codigo de recuperacao com entropia alta (8+ alfanumericos CSPRNG).

    Antes eram 6 digitos (10^6 = brute-force viavel) com hash sha256 sem salt
    (crack offline ~0.06s). Agora: 36^8 (~2.8e12) + hash lento com salt (bcrypt)."""
    alfabeto = string.ascii_uppercase + string.digits
    return ''.join(secrets.choice(alfabeto) for _ in range(CODIGO_RECUPERACAO_COMPRIMENTO))


def _crp_verificado_servidor(registro: str, cliente_afirma: bool) -> bool:
    """Deriva o selo de CRP verificado no servidor (anti badge falseavel).

    O `crp_verificado` enviado pelo cliente nao e confiavel: antes era
    renderizado nas paginas publicas mesmo quando o CFP reportava CRP
    inativo. Agora so retorna True se a verificacao real (consulta ao CFP)
    confirmar registro ativo. Sem registro, sem afirmacao do cliente ou
    falha de rede -> False (fail-closed)."""
    registro = (registro or "").strip()
    if not registro or not cliente_afirma:
        return False
    try:
        resultado = verificar_crp_online(registro)
        return bool(resultado.get("ativo"))
    except Exception:
        log.warning("Falha ao verificar CRP no servidor; selo negado (fail-closed).")
        return False


def _json_script_seguro(obj) -> str:
    """Serializa para JSON seguro para ser embutido dentro de `<script>`.

    `json.dumps` escapa aspas, mas NÃO escapa `<`, `>` nem `&` — um valor com
    `</script>` quebraria o bloco e permitiria XSS. Este helper converte esses
    caracteres para escapes unicode (semanticamente idênticos em JS)."""
    s = json.dumps(obj, ensure_ascii=False)
    return (s
            .replace("&", "\\u0026")
            .replace("<", "\\u003c")
            .replace(">", "\\u003e")
            .replace("\u2028", "\\u2028")
            .replace("\u2029", "\\u2029"))


def _montar_pagina_anamnese_script(dados: dict, template_json: str = "") -> str:
    """Monta o bloco `<script>` da anamnese com JSON seguro (anti XSS).

    Retorna apenas o trecho do script com os placeholders substituidos,
    usando `_json_script_seguro` para `DADOS_PROFISSIONAL` e `TEMPLATE`."""
    dados_seguros = _json_script_seguro(dados)
    template = (template_json or "{}").strip()
    if not template.startswith("{"):
        template = "{}"
    template_obj = json.loads(template) if template.startswith("{") else {}
    template_seguro = _json_script_seguro(template_obj)
    return (
        "const DADOS_PROFISSIONAL = " + dados_seguros + ";\n"
        "const TEMPLATE = " + template_seguro + ";"
    )


def _hash_email(email: str) -> str:
    return hashlib.sha256(email.lower().strip().encode()).hexdigest()


def _hash_codigo(codigo: str) -> str:
    """Hash lento com salt (bcrypt) — resistente a brute-force offline."""
    return pwd_context.hash(codigo)


def _hash_codigo_legado(codigo: str) -> str:
    """Formato antigo (sha256 sem salt) mantido só para fallback de hashes
    já persistidos antes do endurecimento."""
    return hashlib.sha256(codigo.encode()).hexdigest()


def _verificar_codigo(codigo: str, codigo_hash: str | None) -> bool:
    if not codigo_hash:
        return False
    try:
        return pwd_context.verify(codigo, codigo_hash)
    except Exception:
        return _hash_codigo_legado(codigo) == codigo_hash


async def _enviar_email(destinatario: str, assunto: str, corpo: str) -> bool:
    if not SMTP_HOST:
        log.warning("SMTP_HOST não configurado. E-mail não enviado para %s", _mascarar_contato(destinatario))
        return False
    try:
        msg = MIMEText(corpo, "html", "utf-8")
        msg["Subject"] = assunto
        msg["From"] = SMTP_FROM
        msg["To"] = destinatario

        loop = asyncio.get_running_loop()
        await loop.run_in_executor(
            None,
            lambda: _enviar_email_sync(msg, destinatario),
        )
        log.info("Email enviado para %s", _mascarar_contato(destinatario))
        return True
    except Exception as e:
        log.error("Erro ao enviar email para %s: %s", _mascarar_contato(destinatario), e)
        return False


def _enviar_email_sync(msg, destinatario: str):
    with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=15) as server:
        server.starttls()
        if SMTP_USER and SMTP_PASS:
            server.login(SMTP_USER, SMTP_PASS)
        server.sendmail(SMTP_FROM, destinatario, msg.as_string())


@app.post(
    "/auth/solicitar-recuperacao",
    response_model=RecuperacaoResponse,
    tags=["Recuperacao"],
)
async def solicitar_recuperacao(request: RecuperacaoRequest, _req: Request):
    _rate_limit_check(_req, max_requests=3, chave_extra="conta:" + request.email.strip().lower())

    email = request.email.strip().lower()
    email_hash = _hash_email(email)

    from services.db import executar
    existente = executar(
        "SELECT recovery_token FROM recuperacoes WHERE email_hash = ?",
        (email_hash,),
    ).fetchone()

    # Resposta genérica idêntica para e-mail cadastrado ou não (anti enumeração).
    mensagem_generica = (
        "Se o e-mail estiver cadastrado, você receberá o código de recuperação."
    )

    if not existente:
        return RecuperacaoResponse(sucesso=True, mensagem=mensagem_generica)

    codigo = _gerar_codigo()
    expiracao = (datetime.now(timezone.utc) + timedelta(minutes=10)).isoformat()
    executar(
        "UPDATE recuperacoes SET codigo_hash = ?, codigo_expiracao = ?, "
        "tentativas = 0, bloqueio_ate = NULL WHERE email_hash = ?",
        (_hash_codigo(codigo), expiracao, email_hash),
    ).commit()

    corpo = f"""<html><body style="font-family:sans-serif;padding:20px;">
<h2>MentAll PRO - Recuperacao de PIN</h2>
<p>Seu codigo de verificacao: <strong style="font-size:24px;letter-spacing:4px;">{codigo}</strong></p>
<p>Este codigo expira em 10 minutos.</p>
<p>Se você não solicitou esta recuperação, ignore este e-mail.</p>
</body></html>"""

    enviado = await _enviar_email(email, "MentAll PRO - Codigo de Recuperacao", corpo)
    log.info("Código de recuperação gerado para e-mail %s (enviado=%s)", email_hash[:16], enviado)

    return RecuperacaoResponse(
        sucesso=True,
        mensagem="Codigo enviado para o email." if enviado else "Código gerado. E-mail não disponível no momento.",
    )


@app.post(
    "/auth/verificar-recuperacao",
    response_model=VerificarCodigoResponse,
    tags=["Recuperacao"],
)
def verificar_recuperacao(request: VerificarCodigoRequest, _req: Request):
    _rate_limit_check(_req, max_requests=5, chave_extra="conta:" + request.email.strip().lower())

    email = request.email.strip().lower()
    email_hash = _hash_email(email)
    codigo = request.codigo.strip()

    from services.db import executar
    registro = executar(
        "SELECT codigo_hash, codigo_expiracao, recovery_token, "
        "tentativas, bloqueio_ate FROM recuperacoes WHERE email_hash = ?",
        (email_hash,),
    ).fetchone()

    if not registro:
        # Resposta genérica para não revelar se o e-mail está cadastrado.
        return VerificarCodigoResponse(sucesso=False, erro="Codigo invalido.")

    bloqueio_ate = registro.get("bloqueio_ate") or ""
    if bloqueio_ate:
        try:
            if datetime.now(timezone.utc) < datetime.fromisoformat(bloqueio_ate):
                return VerificarCodigoResponse(
                    sucesso=False,
                    erro="Muitas tentativas. Aguarde alguns minutos.",
                )
        except Exception:
            pass

    codigo_armazenado = registro.get("codigo_hash", "") or ""
    if not _verificar_codigo(codigo, codigo_armazenado):
        tentativas = (registro.get("tentativas") or 0) + 1
        if tentativas >= MAX_TENTATIVAS_RECUPERACAO:
            bloqueio = (datetime.now(timezone.utc) + timedelta(minutes=BLOQUEIO_RECUPERACAO_MINUTOS)).isoformat()
            executar(
                "UPDATE recuperacoes SET tentativas = ?, bloqueio_ate = ? WHERE email_hash = ?",
                (tentativas, bloqueio, email_hash),
            ).commit()
        else:
            executar(
                "UPDATE recuperacoes SET tentativas = ? WHERE email_hash = ?",
                (tentativas, email_hash),
            ).commit()
        return VerificarCodigoResponse(sucesso=False, erro="Codigo invalido.")

    expiracao_str = registro.get("codigo_expiracao", "") or ""
    if expiracao_str:
        try:
            expiracao = datetime.fromisoformat(expiracao_str)
            if datetime.now(timezone.utc) > expiracao:
                return VerificarCodigoResponse(sucesso=False, erro="Codigo expirado. Solicite um novo.")
        except Exception:
            pass

    executar(
        "UPDATE recuperacoes SET codigo_hash = NULL, codigo_expiracao = NULL, "
        "tentativas = 0, bloqueio_ate = NULL WHERE email_hash = ?",
        (email_hash,),
    ).commit()

    return VerificarCodigoResponse(
        sucesso=True,
        recovery_token=registro.get("recovery_token", ""),
    )


@app.post(
    "/auth/registrar-recuperacao",
    response_model=RecuperacaoResponse,
    tags=["Recuperacao"],
)
def registrar_recuperacao(
    request: RegistrarRecuperacaoRequest,
    _req: Request,
    auth: tuple = Depends(_verificar_token),
):
    _rate_limit_check(_req, max_requests=5, chave_extra="conta:" + request.email.strip().lower())

    username, _owner_id = auth
    email = request.email.strip().lower()
    if email != username.strip().lower():
        raise HTTPException(
            status_code=403,
            detail="E-mail não pertence à conta autenticada.",
        )
    email_hash = _hash_email(email)
    agora = datetime.now(timezone.utc).isoformat()

    from services.db import executar
    existente = executar(
        "SELECT email_hash FROM recuperacoes WHERE email_hash = ?",
        (email_hash,),
    ).fetchone()

    if existente:
        executar(
            "UPDATE recuperacoes SET recovery_token = ?, criado_em = ? WHERE email_hash = ?",
            (request.recovery_token, agora, email_hash),
        ).commit()
    else:
        executar(
            "INSERT INTO recuperacoes (email_hash, recovery_token, criado_em) VALUES (?, ?, ?)",
            (email_hash, request.recovery_token, agora),
        ).commit()

    log.info("Recuperacao registrada para email hash %s", email_hash[:16])
    return RecuperacaoResponse(sucesso=True, mensagem="Recuperacao registrada com sucesso.")


RESET_SENHA_EXPIRACAO_MINUTOS = 10


@app.post(
    "/auth/solicitar-reset-senha",
    response_model=RecuperacaoResponse,
    tags=["Recuperacao"],
)
async def solicitar_reset_senha(request: RecuperacaoRequest, _req: Request):
    _rate_limit_check(_req, max_requests=3, chave_extra="conta:" + request.email.strip().lower())

    email = request.email.strip().lower()
    email_hash = _hash_email(email)

    # Resposta genérica idêntica para e-mail cadastrado ou não (anti enumeração).
    mensagem_generica = (
        "Se o e-mail estiver cadastrado, você receberá o código de recuperação."
    )

    from services.usuarios import obter_por_email

    if obter_por_email(email) is None:
        return RecuperacaoResponse(sucesso=True, mensagem=mensagem_generica)

    from services.db import executar

    codigo = _gerar_codigo()
    expiracao = (
        datetime.now(timezone.utc) + timedelta(minutes=RESET_SENHA_EXPIRACAO_MINUTOS)
    ).isoformat()
    agora = datetime.now(timezone.utc).isoformat()

    existente = executar(
        "SELECT email_hash FROM resets_senha WHERE email_hash = ?",
        (email_hash,),
    ).fetchone()
    if existente:
        executar(
            "UPDATE resets_senha SET codigo_hash = ?, codigo_expiracao = ?, "
            "tentativas = 0, bloqueio_ate = NULL WHERE email_hash = ?",
            (_hash_codigo(codigo), expiracao, email_hash),
        ).commit()
    else:
        executar(
            "INSERT INTO resets_senha (email_hash, codigo_hash, codigo_expiracao, "
            "tentativas, criado_em) VALUES (?, ?, ?, 0, ?)",
            (email_hash, _hash_codigo(codigo), expiracao, agora),
        ).commit()

    corpo = f"""<html><body style="font-family:sans-serif;padding:20px;">
<h2>MentAll PRO - Redefinicao de senha</h2>
<p>Seu codigo de verificacao: <strong style="font-size:24px;letter-spacing:4px;">{codigo}</strong></p>
<p>Este codigo expira em {RESET_SENHA_EXPIRACAO_MINUTOS} minutos.</p>
<p>Se você não solicitou a redefinicao, ignore este e-mail.</p>
</body></html>"""

    enviado = await _enviar_email(email, "MentAll PRO - Redefinicao de senha", corpo)
    log.info("Codigo de reset de senha gerado para e-mail %s (enviado=%s)", email_hash[:16], enviado)

    return RecuperacaoResponse(
        sucesso=True,
        mensagem="Codigo enviado para o email." if enviado
        else "Código gerado. E-mail não disponível no momento.",
    )


@app.post(
    "/auth/redefinir-senha",
    response_model=RecuperacaoResponse,
    tags=["Recuperacao"],
)
def redefinir_senha(request: RedefinirSenhaRequest, _req: Request):
    _rate_limit_check(_req, max_requests=5, chave_extra="conta:" + request.email.strip().lower())

    if not _senha_forte(request.nova_senha):
        raise HTTPException(
            status_code=422,
            detail="A senha deve ter pelo menos 10 caracteres, com letras maiusculas, minusculas e numeros.",
        )

    email = request.email.strip().lower()
    email_hash = _hash_email(email)
    codigo = request.codigo.strip()

    from services.db import executar

    registro = executar(
        "SELECT codigo_hash, codigo_expiracao, tentativas, bloqueio_ate "
        "FROM resets_senha WHERE email_hash = ?",
        (email_hash,),
    ).fetchone()

    if not registro:
        return RecuperacaoResponse(sucesso=False, erro="Codigo invalido.")

    bloqueio_ate = registro.get("bloqueio_ate") or ""
    if bloqueio_ate:
        try:
            if datetime.now(timezone.utc) < datetime.fromisoformat(bloqueio_ate):
                return RecuperacaoResponse(
                    sucesso=False, erro="Muitas tentativas. Aguarde alguns minutos."
                )
        except Exception:
            pass

    codigo_hash = registro.get("codigo_hash", "") or ""
    if not _verificar_codigo(codigo, codigo_hash):
        tentativas = (registro.get("tentativas") or 0) + 1
        if tentativas >= MAX_TENTATIVAS_RECUPERACAO:
            bloqueio = (
                datetime.now(timezone.utc) + timedelta(minutes=BLOQUEIO_RECUPERACAO_MINUTOS)
            ).isoformat()
            executar(
                "UPDATE resets_senha SET tentativas = ?, bloqueio_ate = ? WHERE email_hash = ?",
                (tentativas, bloqueio, email_hash),
            ).commit()
        else:
            executar(
                "UPDATE resets_senha SET tentativas = ? WHERE email_hash = ?",
                (tentativas, email_hash),
            ).commit()
        return RecuperacaoResponse(sucesso=False, erro="Codigo invalido.")

    expiracao_str = registro.get("codigo_expiracao", "") or ""
    if expiracao_str:
        try:
            if datetime.now(timezone.utc) > datetime.fromisoformat(expiracao_str):
                return RecuperacaoResponse(sucesso=False, erro="Codigo expirado. Solicite um novo.")
        except Exception:
            pass

    from services.usuarios import redefinir_senha as _redefinir_senha

    if not _redefinir_senha(email, request.nova_senha):
        return RecuperacaoResponse(sucesso=False, erro="Nao foi possivel redefinir a senha.")

    executar("DELETE FROM resets_senha WHERE email_hash = ?", (email_hash,)).commit()
    log.info("Senha redefinida para e-mail %s", email_hash[:16])
    return RecuperacaoResponse(sucesso=True, mensagem="Senha redefinida com sucesso.")


@app.post(
    "/telemetria/heartbeat",
    response_model=TelemetriaResponse,
    tags=["Telemetria"],
    dependencies=[Depends(_verificar_token)],
)
def telemetria_heartbeat(
    request: HeartbeatRequest, _req: Request, auth: tuple = Depends(_verificar_token)
):
    _rate_limit_check(_req, max_requests=60)
    _, owner_id = auth
    from services.telemetria import registrar_heartbeat

    registrar_heartbeat(owner_id, request.device_id, request.plataforma, request.versao_app)
    return TelemetriaResponse()


@app.post(
    "/telemetria/evento",
    response_model=TelemetriaResponse,
    tags=["Telemetria"],
    dependencies=[Depends(_verificar_token)],
)
def telemetria_evento(
    request: EventoRequest, _req: Request, auth: tuple = Depends(_verificar_token)
):
    _rate_limit_check(_req, max_requests=120)
    _, owner_id = auth
    from services.telemetria import registrar_evento

    if not registrar_evento(owner_id, request.device_id, request.tipo):
        raise HTTPException(status_code=422, detail="Tipo de evento nao permitido.")
    return TelemetriaResponse()


ADMIN_COOKIE = "mentall_admin"
ADMIN_2FA_COOKIE = "mentall_admin_2fa"


PAPEIS_PAINEL = ("admin", "financeiro", "suporte")


def _sessao_admin(request: Request) -> dict | None:
    """Valida a sessão do painel e devolve o payload (ou None).

    Checa assinatura/expiração do JWT, etapa "sessao", jti revogado, sessão
    registrada dentro do limite de inatividade e conta ativa com papel do painel.
    """
    token = request.cookies.get(ADMIN_COOKIE)
    if not token:
        return None
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except JWTError:
        return None
    if (payload.get("etapa") or "sessao") != "sessao":
        return None
    username = (payload.get("sub") or "").strip()
    if not username:
        return None
    jti = str(payload.get("jti") or "")
    if jti and _token_revogado(jti):
        return None
    if not seguranca_admin.sessao_valida(jti, username):
        return None
    if username == APP_USERNAME:
        payload["papel"] = "admin"
        return payload
    from services.usuarios import obter_por_email

    usuario = obter_por_email(username)
    if (
        usuario is None
        or (usuario.get("status") or "") != "ativo"
        or (usuario.get("role") or "") not in PAPEIS_PAINEL
    ):
        return None
    payload["papel"] = usuario.get("role") or "admin"
    return payload


def _usuario_admin_autenticado(request: Request) -> bool:
    return _sessao_admin(request) is not None


def _papel_admin(request: Request) -> str:
    sessao = _sessao_admin(request)
    return (sessao.get("papel") or "") if sessao else ""


def _exigir_papel(request: Request, papeis: tuple):
    """Sessão válida + papel autorizado; devolve a resposta de bloqueio ou None."""
    sessao = _sessao_admin(request)
    if sessao is None:
        return HTMLResponse(admin_ui.pagina_login())
    if (sessao.get("papel") or "") not in papeis:
        return HTMLResponse(admin_ui.pagina_sem_permissao(request.url.path), status_code=403)
    return None


def _origem_permitida(request: Request) -> bool:
    """Anti-CSRF (defesa em profundidade) para POSTs do painel.

    SameSite=Strict já impede o envio do cookie em requisições cross-site na
    maioria dos navegadores; validar Origin/Referer cobre navegadores antigos.
    Clientes não-browser (curl/testes) não enviam esses cabeçalhos e passam.
    """
    from urllib.parse import urlparse

    def host_ok(valor: str) -> bool:
        try:
            host = (urlparse(valor).hostname or "").lower()
        except ValueError:
            return False
        if not host:
            return False
        permitidos = {
            (request.url.hostname or "").lower(),
            "mentall-api.fly.dev",
            "admin.mentallpro.com.br",
            "localhost",
            "127.0.0.1",
        }
        return host in permitidos

    origem = request.headers.get("origin") or ""
    if origem:
        return host_ok(origem)
    referer = request.headers.get("referer") or ""
    if referer:
        return host_ok(referer)
    return True


# ---------------------------------------------------------------------------
# Detalhe do usuário e ações administrativas — Fase 5A.2 (22/10/2026)
#
# Toda ação do painel é auditada em admin_auditoria (quem, o quê, alvo, IP).
# LGPD: a tela de detalhe só mostra metadados (status/contagens/datas) — nunca
# conteúdo clínico (anamnese/síntese/contrato).
# ---------------------------------------------------------------------------

def _identidade_admin(request: Request) -> str:
    """E-mail do admin logado (para a auditoria das ações)."""
    sessao = _sessao_admin(request)
    return (sessao.get("sub") or "").strip() if sessao else ""


def _filtros_admin(request: Request) -> dict:
    """Filtros da listagem, normalizados (usados no painel e no CSV)."""
    parametros = request.query_params
    return {
        "busca": (parametros.get("busca") or "").strip()[:120],
        "status": (parametros.get("status") or "").strip().lower()[:20],
        "plano": (parametros.get("plano") or "").strip().lower()[:30],
        "online": (parametros.get("online") or "").strip()[:1],
        "versao": (parametros.get("versao") or "").strip()[:30],
        "ordenar": (parametros.get("ordenar") or "criado_desc").strip().lower()[:20],
        "tipo": (parametros.get("tipo") or "psicologos").strip().lower()[:20],
    }


def _bloqueio_admin(request: Request):
    """Login quando não há sessão; força 2FA obrigatório quando configurado."""
    sessao = _sessao_admin(request)
    if sessao is None:
        return HTMLResponse(admin_ui.pagina_login())
    if seguranca_admin.obrigatorio() and not seguranca_admin.totp_ativo(sessao["sub"]):
        caminho = request.url.path
        if not caminho.startswith("/admin/seguranca") and caminho not in (
            "/admin/logout",
            "/admin/logout-todos",
        ):
            return RedirectResponse("/admin/seguranca?msg=2FA+obrigatorio", status_code=303)
    return None

@app.get("/admin", response_class=HTMLResponse, tags=["Admin"])
def admin_painel(request: Request, pagina: int = 1):
    _rate_limit_check(request, max_requests=120)
    bloqueio = _bloqueio_admin(request)
    if bloqueio:
        return bloqueio
    filtros = _filtros_admin(request)
    papel = _papel_admin(request)
    kpis = admin_service.kpis()
    usuarios = admin_service.listar_usuarios(pagina=pagina, **filtros)
    extras = admin_service.kpis_operacionais()
    estatisticas = admin_service.estatisticas_dashboard()
    saude = saude_service.coletar()
    opcoes = admin_service.opcoes_filtros()
    auditoria = admin_service.listar_auditoria(limite=8) if papel == "admin" else []
    return HTMLResponse(
        admin_ui.pagina_dashboard(
            kpis,
            usuarios,
            filtros,
            extras=extras,
            saude=saude,
            opcoes=opcoes,
            auditoria=auditoria,
            estatisticas=estatisticas,
            pode_email=(papel == "admin"),
        )
    )


@app.post("/admin/login", tags=["Admin"])
async def admin_login(request: Request):
    # Fase 5A: antes o limite era um bucket GLOBAL (`chave_extra="admin"`): 10 erros
    # de qualquer IP bloqueavam o login de TODOS os admins por 1 min. Agora há teto
    # por IP (30/min) e teto por conta (5/min, válido entre IPs).
    _rate_limit_check(request, max_requests=30)
    form = await request.form()
    email = (form.get("email") or "").strip()
    senha = form.get("senha") or ""
    if email:
        _rate_limit_check(request, max_requests=5, chave_extra=f"conta:{email.lower()}")

    if email.lower() == APP_USERNAME.lower() and _verificar_senha(senha):
        usuario = {
            "email": APP_USERNAME,
            "id": APP_USER_ID,
            "role": "admin",
            "status": "ativo",
        }
    else:
        from services.usuarios import autenticar

        usuario = autenticar(email, senha)

    # Exige conta confirmada (ativo) + papel admin (mesmo portão do /auth/login,
    # que recusa 'pendente' com 403).
    if (
        usuario is None
        or (usuario.get("role") or "user") not in PAPEIS_PAINEL
        or (usuario.get("status") or "") != "ativo"
    ):
        return HTMLResponse(
            admin_ui.pagina_login("Credenciais inválidas ou sem permissão."),
            status_code=401,
        )

    if seguranca_admin.totp_ativo(usuario["email"]):
        # Senha correta, mas falta a 2ª etapa (código do app autenticador).
        resposta = RedirectResponse("/admin/2fa", status_code=303)
        resposta.set_cookie(
            ADMIN_2FA_COOKIE,
            _criar_token_2fa(usuario["email"], usuario["id"]),
            max_age=300,
            httponly=True,
            secure=True,
            samesite="strict",
            path="/admin",
        )
        return resposta
    return _emitir_cookie_admin(usuario)


@app.post("/admin/logout", tags=["Admin"])
def admin_logout(request: Request):
    token = request.cookies.get(ADMIN_COOKIE)
    if token:
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
            _revogar_token(str(payload.get("jti") or ""), str(payload.get("exp") or ""))
        except JWTError:
            pass
    resp = RedirectResponse("/admin", status_code=303)
    resp.delete_cookie(ADMIN_COOKIE, path="/admin")
    return resp


@app.get("/admin/usuarios.csv", tags=["Admin"])
def admin_usuarios_csv(request: Request):
    _rate_limit_check(request, max_requests=20)
    sessao = _sessao_admin(request)
    if sessao is None:
        return HTMLResponse(admin_ui.pagina_login(), status_code=401)
    if (sessao.get("papel") or "") not in ("admin", "financeiro"):
        return HTMLResponse(
            admin_ui.pagina_sem_permissao(request.url.path), status_code=403
        )
    filtros = _filtros_admin(request)
    linhas = admin_service.exportar_usuarios(**filtros)
    buffer = io.StringIO()
    buffer.write("\ufeff")  # BOM para o Excel abrir UTF-8 corretamente
    escritor = csv.writer(buffer, delimiter=";")
    escritor.writerow([
        "email", "nome", "plano", "papel", "psicologo", "status", "criado_em", "ultimo_acesso_em",
        "plataforma", "versao_app", "ultimo_heartbeat_em",
    ])
    for linha in linhas:
        escritor.writerow([
            linha.get("email") or "",
            linha.get("nome") or "",
            linha.get("plano") or "",
            linha.get("role") or "",
            "1" if linha.get("eh_psicologo") else "0",
            linha.get("status") or "",
            linha.get("criado_em") or "",
            linha.get("ultimo_acesso_em") or "",
            linha.get("plataforma") or "",
            linha.get("versao_app") or "",
            linha.get("ultimo_heartbeat_em") or "",
        ])
    resposta = Response(content=buffer.getvalue(), media_type="text/csv; charset=utf-8")
    resposta.headers["Content-Disposition"] = 'attachment; filename="usuarios.csv"'
    resposta.headers["Cache-Control"] = "no-store"
    return resposta


@app.get("/admin/usuarios/{usuario_id}", response_class=HTMLResponse, tags=["Admin"])
def admin_usuario_detalhe(request: Request, usuario_id: str, msg: str = "", erro: str = ""):
    _rate_limit_check(request, max_requests=120)
    bloqueio = _bloqueio_admin(request)
    if bloqueio:
        return bloqueio
    detalhe = admin_service.detalhar_usuario(usuario_id)
    if detalhe is None:
        return RedirectResponse("/admin", status_code=303)
    papel = _papel_admin(request)
    return HTMLResponse(
        admin_ui.pagina_usuario(
            detalhe,
            msg=msg,
            erro=erro,
            pode_acoes=(papel == "admin"),
            pode_email=(papel == "admin"),
        )
    )


@app.post("/admin/usuarios/{usuario_id}/acao", tags=["Admin"])
async def admin_usuario_acao(request: Request, usuario_id: str):
    _rate_limit_check(request, max_requests=20, chave_extra="admin-acao")
    bloqueio = _bloqueio_admin(request)
    if bloqueio:
        return bloqueio
    if _papel_admin(request) != "admin":
        return HTMLResponse(
            admin_ui.pagina_sem_permissao("Ações de usuário"), status_code=403
        )
    detalhe = admin_service.detalhar_usuario(usuario_id)
    if detalhe is None:
        return RedirectResponse("/admin", status_code=303)

    alvo = detalhe["usuario"]["email"]
    ator = _identidade_admin(request) or "desconhecido"
    ip = _cliente_ip(request)
    form = await request.form()
    acao = (form.get("acao") or "").strip()

    def redirecionar(msg: str = "", erro: str = "") -> RedirectResponse:
        parametros = {chave: valor for chave, valor in (("msg", msg), ("erro", erro)) if valor}
        destino = f"/admin/usuarios/{usuario_id}"
        if parametros:
            destino += "?" + urlencode(parametros)
        return RedirectResponse(destino, status_code=303)

    try:
        if acao in ("suspender", "reativar"):
            novo_status = "suspenso" if acao == "suspender" else "ativo"
            if not admin_service.definir_status_usuario(usuario_id, novo_status):
                raise ValueError("Usuário não encontrado.")
            versao = admin_service.revogar_sessoes_app(usuario_id)
            _invalidar_cache_token(usuario_id)
            admin_service.registrar_auditoria(
                ator,
                f"usuario.{acao}",
                alvo,
                f"status {detalhe['usuario']['status']} -> {novo_status}; sessões do app revogadas (v{versao})",
                ip,
            )
            return redirecionar(msg=f"Conta {alvo}: {novo_status} (sessões do app encerradas).")

        if acao == "plano":
            novo_plano = (form.get("plano") or "").strip().lower()
            anterior = detalhe["usuario"]["plano"]
            if not admin_service.definir_plano_usuario(usuario_id, novo_plano):
                raise ValueError("Usuário não encontrado.")
            admin_service.registrar_auditoria(
                ator, "usuario.plano", alvo, f"plano {anterior} -> {novo_plano}", ip
            )
            return redirecionar(msg=f"Plano de {alvo}: {novo_plano}.")

        if acao == "tipo":
            eh_psicologo = (form.get("eh_psicologo") or "").strip() in ("1", "sim", "true")
            if not admin_service.definir_eh_psicologo(usuario_id, eh_psicologo):
                raise ValueError("Usuário não encontrado.")
            admin_service.registrar_auditoria(
                ator,
                "usuario.tipo",
                alvo,
                f"psicologo {int(bool(detalhe['usuario'].get('eh_psicologo')))} -> {int(eh_psicologo)}",
                ip,
            )
            if eh_psicologo:
                return redirecionar(msg=f"Conta {alvo} marcada como psicóloga (usa o app).")
            return redirecionar(msg=f"Conta {alvo} marcada como equipe (não psicólogo).")

        if acao == "reenviar_confirmacao":
            from services.usuarios import renovar_token_confirmacao

            token = renovar_token_confirmacao(alvo)
            if token is None:
                raise ValueError("Só é possível reenviar confirmação para conta pendente.")
            base_url = os.getenv("API_BASE_URL", "https://mentall-api.fly.dev").strip().rstrip("/")
            link = f"{base_url}/auth/confirmar-email?token={token}"
            corpo = f"""<html><body style="font-family:sans-serif;padding:20px;">
<h2>MentAll PRO - Confirme seu cadastro</h2>
<p>Este é um novo link de confirmação para a sua conta.</p>
<p><a href="{link}" style="display:inline-block;padding:12px 20px;background:#8806CE;color:#fff;
text-decoration:none;border-radius:8px;">Confirmar meu cadastro</a></p>
<p style="font-size:13px;color:#64748B;">Se você não reconhece este cadastro, ignore este e-mail.</p>
</body></html>"""
            enviado = await _enviar_email(alvo, "MentAll PRO - Confirme seu cadastro", corpo)
            admin_service.registrar_auditoria(
                ator, "usuario.reenviar_confirmacao", alvo, f"email_enviado={enviado}", ip
            )
            if not enviado:
                return redirecionar(
                    erro="Link renovado, mas o SMTP não enviou o e-mail. Verifique a saúde do sistema."
                )
            return redirecionar(msg=f"Novo link de confirmação enviado para {alvo}.")

        if acao == "papel":
            novo_papel = (form.get("papel") or "").strip().lower()
            if alvo.casefold() == (ator or "").casefold() and novo_papel != "admin":
                raise ValueError("Você não pode remover seu próprio papel de administrador.")
            anterior = detalhe["usuario"]["role"] or "user"
            if not admin_service.definir_papel_usuario(usuario_id, novo_papel):
                raise ValueError("Usuário não encontrado.")
            _invalidar_cache_token(usuario_id)
            admin_service.registrar_auditoria(
                ator, "usuario.papel", alvo, f"papel {anterior} -> {novo_papel}", ip
            )
            return redirecionar(msg=f"Papel de {alvo}: {novo_papel}.")

        if acao == "encerrar_sessoes_app":
            versao = admin_service.revogar_sessoes_app(usuario_id)
            _invalidar_cache_token(usuario_id)
            admin_service.registrar_auditoria(
                ator,
                "usuario.encerrar_sessoes_app",
                alvo,
                f"token_version -> {versao}",
                ip,
            )
            return redirecionar(
                msg=f"Sessões do app de {alvo} encerradas (versão {versao})."
            )

        raise ValueError("Ação desconhecida.")
    except ValueError as exc:
        return redirecionar(erro=str(exc))


def _criar_token_2fa(username: str, owner_id: str) -> str:
    """Token curto (5 min) da 1ª etapa do login; só serve para /admin/2fa."""
    expiracao = datetime.now(timezone.utc) + timedelta(minutes=5)
    payload = {
        "sub": username,
        "owner": owner_id,
        "exp": expiracao,
        "jti": uuid.uuid4().hex,
        "etapa": "2fa",
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def _emitir_cookie_admin(usuario: dict) -> RedirectResponse:
    """Cria a sessão (registrada para expiração ociosa) e redireciona ao painel."""
    token = _criar_token_jwt(usuario["email"], usuario["id"])
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        seguranca_admin.registrar_sessao(str(payload.get("jti") or ""), usuario["email"])
    except JWTError:
        pass
    resposta = RedirectResponse("/admin", status_code=303)
    resposta.set_cookie(
        ADMIN_COOKIE,
        token,
        max_age=JWT_EXPIRATION * 60,
        httponly=True,
        secure=True,
        samesite="strict",
        path="/admin",
    )
    return resposta


def _pagina_2fa_ou_login(request: Request):
    """Valida o cookie de 2ª etapa; devolve (payload, None) ou (None, resposta)."""
    token = request.cookies.get(ADMIN_2FA_COOKIE)
    if not token:
        return None, RedirectResponse("/admin", status_code=303)
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except JWTError:
        return None, RedirectResponse("/admin", status_code=303)
    if (payload.get("etapa") or "") != "2fa" or not (payload.get("sub") or "").strip():
        return None, RedirectResponse("/admin", status_code=303)
    jti = str(payload.get("jti") or "")
    if jti and _token_revogado(jti):
        return None, RedirectResponse("/admin", status_code=303)
    return payload, None


def _ator_logado(request: Request) -> dict | None:
    sessao = _sessao_admin(request)
    if sessao is None:
        return None
    return {"email": sessao["sub"], "papel": sessao.get("papel") or "admin"}


# ---------------------------------------------------------------------------
# Segunda etapa do login (2FA)
# ---------------------------------------------------------------------------

@app.get("/admin/2fa", response_class=HTMLResponse, tags=["Admin"])
def admin_2fa_pagina(request: Request):
    _rate_limit_check(request, max_requests=60)
    payload, resposta = _pagina_2fa_ou_login(request)
    if resposta:
        return resposta
    return HTMLResponse(admin_ui.pagina_2fa_login())


@app.post("/admin/2fa", tags=["Admin"])
async def admin_2fa_verificar(request: Request):
    _rate_limit_check(request, max_requests=10)
    payload, resposta = _pagina_2fa_ou_login(request)
    if resposta:
        return resposta
    form = await request.form()
    codigo = (form.get("codigo") or "").strip()
    ator = (payload.get("sub") or "").strip()
    if not seguranca_admin.validar_codigo(ator, codigo):
        log.warning("Falha na 2ª etapa de login de admin '%s' (IP: %s)", ator, _cliente_ip(request))
        return HTMLResponse(admin_ui.pagina_2fa_login("Código inválido. Tente novamente."))
    from services.usuarios import obter_por_email

    usuario = obter_por_email(ator)
    if usuario is None:
        # admin legado (APP_USERNAME) não tem linha em usuarios
        if ator != APP_USERNAME:
            return RedirectResponse("/admin", status_code=303)
        usuario = {"email": ator, "id": APP_USER_ID}
    resposta = _emitir_cookie_admin(usuario)
    resposta.delete_cookie(ADMIN_2FA_COOKIE, path="/admin")
    log.info("2FA concluído para admin '%s' (IP: %s)", ator, _cliente_ip(request))
    return resposta


# ---------------------------------------------------------------------------
# Página de segurança (2FA + sessões)
# ---------------------------------------------------------------------------

def _render_seguranca(request: Request, msg: str = "", erro: str = ""):
    ator = _ator_logado(request)
    if ator is None:
        return HTMLResponse(admin_ui.pagina_login())
    seg_estado = seguranca_admin.estado(ator["email"])
    return HTMLResponse(
        admin_ui.pagina_seguranca(
            ator["email"], ator["papel"], seg_estado, seguranca_admin.idle_minutos(),
            msg=msg, erro=erro,
        )
    )


@app.get("/admin/seguranca", response_class=HTMLResponse, tags=["Admin"])
def admin_seguranca_pagina(request: Request, msg: str = "", erro: str = ""):
    _rate_limit_check(request, max_requests=60)
    return _render_seguranca(request, msg=msg, erro=erro)


@app.post("/admin/seguranca/ativar", tags=["Admin"])
def admin_seguranca_ativar(request: Request):
    _rate_limit_check(request, max_requests=10)
    ator = _ator_logado(request)
    if ator is None:
        return HTMLResponse(admin_ui.pagina_login())
    dados = seguranca_admin.iniciar_ativacao(ator["email"])
    return HTMLResponse(
        admin_ui.pagina_2fa_ativar(ator["email"], dados["segredo"], dados["uri"])
    )


@app.post("/admin/seguranca/confirmar", tags=["Admin"])
async def admin_seguranca_confirmar(request: Request):
    _rate_limit_check(request, max_requests=10)
    ator = _ator_logado(request)
    if ator is None:
        return HTMLResponse(admin_ui.pagina_login())
    form = await request.form()
    codigos = seguranca_admin.confirmar_ativacao(ator["email"], (form.get("codigo") or ""))
    if codigos is None:
        dados = seguranca_admin.iniciar_ativacao(ator["email"])
        return HTMLResponse(
            admin_ui.pagina_2fa_ativar(
                ator["email"], dados["segredo"], dados["uri"],
                erro="Código inválido. Confira o app autenticador e tente de novo.",
            )
        )
    return HTMLResponse(admin_ui.pagina_2fa_backup(codigos))


@app.post("/admin/seguranca/desativar", tags=["Admin"])
async def admin_seguranca_desativar(request: Request):
    _rate_limit_check(request, max_requests=10)
    ator = _ator_logado(request)
    if ator is None:
        return HTMLResponse(admin_ui.pagina_login())
    form = await request.form()
    codigo = (form.get("codigo") or "").strip()
    if not seguranca_admin.validar_codigo(ator["email"], codigo):
        return _render_seguranca(request, erro="Código inválido — o 2FA continua ativo.")
    seguranca_admin.desativar(ator["email"])
    return _render_seguranca(request, msg="Verificação em 2 etapas desativada.")


@app.post("/admin/logout-todos", tags=["Admin"])
def admin_logout_todos(request: Request):
    _rate_limit_check(request, max_requests=10)
    ator = _ator_logado(request)
    if ator is None:
        return RedirectResponse("/admin", status_code=303)
    revogadas = seguranca_admin.revogar_todas_sessoes(ator["email"])
    log.info("Logout global do painel: %s sessão(ões) revogada(s).", revogadas)
    resposta = RedirectResponse("/admin", status_code=303)
    resposta.delete_cookie(ADMIN_COOKIE, path="/admin")
    resposta.delete_cookie(ADMIN_2FA_COOKIE, path="/admin")
    return resposta


# ---------------------------------------------------------------------------
# PWA do painel — Fase 5E (23/10/2026)
#
# Manifest, service worker e ícones para "instalar" o painel no celular.
# Política: sem cache de dados — o service worker sempre busca da rede.
# ---------------------------------------------------------------------------

_STATIC_ADMIN = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static", "admin")


def _static_admin(nome: str, media_type: str, cache: str = "public, max-age=86400"):
    caminho = os.path.join(_STATIC_ADMIN, nome)
    try:
        with open(caminho, "rb") as arquivo:
            conteudo = arquivo.read()
    except FileNotFoundError:
        return Response(status_code=404)
    return Response(
        content=conteudo, media_type=media_type, headers={"Cache-Control": cache}
    )


@app.get("/admin/manifest.webmanifest", tags=["Admin"])
def admin_manifest():
    return JSONResponse(
        {
            "name": "MentAll PRO — Painel do dono",
            "short_name": "Painel MentAll",
            "description": "Painel operacional do MentAll PRO",
            "lang": "pt-BR",
            "start_url": "/admin",
            "scope": "/admin",
            "display": "standalone",
            "orientation": "portrait-primary",
            "background_color": "#F7F9FA",
            "theme_color": "#8806CE",
            "icons": [
                {
                    "src": "/admin/icon-192.png",
                    "sizes": "192x192",
                    "type": "image/png",
                    "purpose": "any",
                },
                {
                    "src": "/admin/icon-512.png",
                    "sizes": "512x512",
                    "type": "image/png",
                    "purpose": "any maskable",
                },
            ],
        },
        media_type="application/manifest+json",
        headers={"Cache-Control": "public, max-age=3600"},
    )


@app.get("/admin/sw.js", tags=["Admin"])
def admin_service_worker():
    resposta = _static_admin("sw.js", "application/javascript", "no-cache")
    if resposta.status_code == 200:
        resposta.headers["Service-Worker-Allowed"] = "/admin"
    return resposta


@app.get("/admin/painel.js", tags=["Admin"])
def admin_painel_js():
    return _static_admin("painel.js", "application/javascript", "no-cache")


@app.get("/admin/icon-192.png", tags=["Admin"])
def admin_icon_192():
    return _static_admin("icon-192.png", "image/png")


@app.get("/admin/icon-512.png", tags=["Admin"])
def admin_icon_512():
    return _static_admin("icon-512.png", "image/png")


@app.get("/admin/apple-touch-icon.png", tags=["Admin"])
def admin_apple_touch_icon():
    return _static_admin("apple-touch-icon.png", "image/png")


# ---------------------------------------------------------------------------
# Lembretes no painel — Fase 5H (24/10/2026)
#
# Diagnóstico/limpeza operacional dos lembretes do WhatsApp: o painel mostra
# metadados (nunca a mensagem — LGPD), permite reenviar falhos e arquivar
# falhas antigas. Toda ação é auditada em admin_auditoria.
# ---------------------------------------------------------------------------

def _redirect_lembretes(msg: str = "", erro: str = "") -> RedirectResponse:
    parametros = {chave: valor for chave, valor in (("msg", msg), ("erro", erro)) if valor}
    destino = "/admin/lembretes" + (("?" + urlencode(parametros)) if parametros else "")
    return RedirectResponse(destino, status_code=303)


@app.get("/admin/lembretes", response_class=HTMLResponse, tags=["Admin"])
def admin_lembretes(request: Request, status: str = "", msg: str = "", erro: str = ""):
    _rate_limit_check(request, max_requests=60)
    bloqueio = _exigir_papel(request, ("admin",))
    if bloqueio:
        return bloqueio
    resumo = admin_service.resumo_lembretes()
    lembretes = admin_service.listar_lembretes_painel(status=status, limite=100)
    return HTMLResponse(
        admin_ui.pagina_lembretes(resumo, lembretes, status, msg, erro)
    )


@app.get("/admin/reportes-ia", response_class=HTMLResponse, tags=["Admin"])
def admin_reportes_ia(request: Request, motivo: str = "", status: str = ""):
    """Reportes de saida de IA (item 3.4) — so metadados, sem conteudo clinico."""
    _rate_limit_check(request, max_requests=60)
    bloqueio = _exigir_papel(request, ("admin",))
    if bloqueio:
        return bloqueio
    papel = _papel_admin(request)
    motivo = (motivo or "").strip().lower()
    if motivo not in reportes_ia.MOTIVOS_REPORTE_IA:
        motivo = ""
    status = (status or "").strip().lower()
    if status not in reportes_ia.STATUS_REPORTE:
        status = ""
    resumo = reportes_ia.resumo_reportes()
    lista = reportes_ia.listar_reportes(motivo=motivo, status=status, limite=100)
    return HTMLResponse(
        admin_ui.pagina_reportes_ia(
            resumo,
            lista,
            motivo,
            status,
            pode_email=(papel == "admin"),
        )
    )


@app.get("/admin/reportes-ia/{reporte_id}", response_class=HTMLResponse, tags=["Admin"])
def admin_reporte_ia_detalhe(
    request: Request, reporte_id: str, msg: str = "", erro: str = ""
):
    """Detalhe e resolucao de um reporte de IA."""
    _rate_limit_check(request, max_requests=60)
    bloqueio = _exigir_papel(request, ("admin",))
    if bloqueio:
        return bloqueio
    item = reportes_ia.obter_reporte(reporte_id)
    if not item:
        return HTMLResponse(
            admin_ui.pagina_reportes_ia(
                reportes_ia.resumo_reportes(), [], erro="Reporte nao encontrado."
            ),
            status_code=404,
        )
    return HTMLResponse(admin_ui.pagina_reporte_ia_detalhe(item, msg=msg, erro=erro))


@app.post("/admin/reportes-ia/{reporte_id}/resolver", tags=["Admin"])
async def admin_reporte_ia_resolver(request: Request, reporte_id: str):
    """Grava contato/devolutiva/como ficou e muda o status do reporte (auditado)."""
    _rate_limit_check(request, max_requests=30, chave_extra="admin-reportes")
    bloqueio = _exigir_papel(request, ("admin",))
    if bloqueio:
        return bloqueio
    form = await request.form()
    ator = _identidade_admin(request) or "desconhecido"
    status = (form.get("status") or "").strip().lower()
    severidade = (form.get("severidade") or "media").strip().lower()
    try:
        atualizado = reportes_ia.atualizar_resolucao(
            reporte_id=reporte_id,
            status=status,
            severidade=severidade,
            causa_raiz=(form.get("causa_raiz") or "").strip().lower(),
            contato_feito=(form.get("contato_feito") or "") in ("1", "on", "true", "sim"),
            contato_canal=(form.get("contato_canal") or "").strip().lower(),
            contato_em=(form.get("contato_em") or "").strip(),
            contato_resumo=(form.get("contato_resumo") or "").strip(),
            devolutiva=(form.get("devolutiva") or "").strip(),
            como_ficou=(form.get("como_ficou") or "").strip(),
            mudanca_aplicada=(form.get("mudanca_aplicada") or "").strip().lower(),
            resolvido_por=ator,
        )
    except ValueError as exc:
        item = reportes_ia.obter_reporte(reporte_id) or {}
        return HTMLResponse(
            admin_ui.pagina_reporte_ia_detalhe(item, erro=str(exc)), status_code=400
        )
    if not atualizado:
        return RedirectResponse(
            "/admin/reportes-ia?erro=Reporte+nao+encontrado.", status_code=303
        )
    admin_service.registrar_auditoria(
        ator,
        "reporte_ia.resolver",
        reporte_id,
        f"status={status}; severidade={severidade}",
        _cliente_ip(request),
    )
    return RedirectResponse(
        f"/admin/reportes-ia/{reporte_id}?msg=Resolucao+salva.", status_code=303
    )


@app.post("/admin/lembretes/arquivar-antigas", tags=["Admin"])
def admin_lembretes_arquivar_antigas(request: Request):
    _rate_limit_check(request, max_requests=20, chave_extra="admin-lembretes")
    bloqueio = _exigir_papel(request, ("admin",))
    if bloqueio:
        return bloqueio
    total = admin_service.arquivar_falhas_antigas()
    admin_service.registrar_auditoria(
        _identidade_admin(request),
        "lembretes.arquivar_antigas",
        "",
        f"{total} arquivada(s)",
        _cliente_ip(request),
    )
    return _redirect_lembretes(msg=f"{total} falha(s) antiga(s) arquivada(s).")


@app.post("/admin/lembretes/{lembrete_id}/acao", tags=["Admin"])
async def admin_lembrete_acao(request: Request, lembrete_id: str):
    _rate_limit_check(request, max_requests=20, chave_extra="admin-lembretes")
    bloqueio = _exigir_papel(request, ("admin",))
    if bloqueio:
        return bloqueio
    form = await request.form()
    acao = (form.get("acao") or "").strip()
    ator = _identidade_admin(request) or "desconhecido"
    ip = _cliente_ip(request)

    if acao == "reenviar":
        if not admin_service.reenviar_lembrete(lembrete_id):
            return _redirect_lembretes(erro="Lembrete não está em falha/cancelado.")
        admin_service.registrar_auditoria(ator, "lembretes.reenviar", lembrete_id, "", ip)
        return _redirect_lembretes(msg="Lembrete reenviado — sai no próximo ciclo do scheduler.")

    if acao == "arquivar":
        if not admin_service.arquivar_lembrete(lembrete_id):
            return _redirect_lembretes(erro="Lembrete não encontrado ou já arquivado.")
        admin_service.registrar_auditoria(ator, "lembretes.arquivar", lembrete_id, "", ip)
        return _redirect_lembretes(msg="Lembrete arquivado (cancelado).")

    return _redirect_lembretes(erro="Ação desconhecida.")


# ---------------------------------------------------------------------------
# E-mail (Mailu) no painel do dono — Fase 4 (22/10/2026)
#
# O painel fala com a API do Mailu pelo backend (token em MAILU_API_TOKEN).
# Nenhuma credencial do servidor de e-mail chega ao navegador.
# ---------------------------------------------------------------------------

def _exigir_sessao_admin(request: Request):
    """E-mail (Fase 4): só papel admin gerencia caixas do Mailu."""
    return _exigir_papel(request, ("admin",))


def _pagina_email(msg: str = "", erro: str = "", credenciais=None, metricas=None, avisos=None) -> HTMLResponse:
    try:
        caixas = email_admin.listar_caixas()
        aliases = email_admin.listar_aliases()
    except email_admin.EmailAdminErro as exc:
        caixas, aliases = [], []
        erro = erro or str(exc)
    return HTMLResponse(
        admin_ui.pagina_email(
            caixas,
            aliases,
            dominio=email_admin.dominio(),
            configurado=email_admin.configurado(),
            msg=msg,
            erro=erro,
            credenciais=credenciais,
            metricas=metricas,
            avisos=avisos,
        )
    )


def _redirect_email(msg: str = "", erro: str = "") -> RedirectResponse:
    parametros = {chave: valor for chave, valor in (("msg", msg), ("erro", erro)) if valor}
    destino = "/admin/email" + (("?" + urlencode(parametros)) if parametros else "")
    return RedirectResponse(destino, status_code=303)


def _caixa_administrativa(email: str) -> bool:
    try:
        return any(c["email"] == email and c["admin"] for c in email_admin.listar_caixas())
    except email_admin.EmailAdminErro:
        return False


@app.get("/admin/email", response_class=HTMLResponse, tags=["Admin"])
def admin_email(request: Request, msg: str = "", erro: str = "", atualizar: str = ""):
    _rate_limit_check(request, max_requests=120)
    bloqueio = _exigir_sessao_admin(request)
    if bloqueio:
        return bloqueio
    metricas = None
    try:
        metricas = email_metricas.coletar(force=atualizar in ("1", "sim", "true"))
    except Exception:
        log.exception("Falha ao coletar métricas de e-mail")
    avisos = email_novos.estado(_identidade_admin(request))
    return _pagina_email(msg=msg, erro=erro, metricas=metricas, avisos=avisos)


@app.post("/admin/email/alertar-agora", tags=["Admin"])
def admin_email_alertar_agora(request: Request):
    _rate_limit_check(request, max_requests=10, chave_extra="admin-email-alerta")
    bloqueio = _exigir_sessao_admin(request)
    if bloqueio:
        return bloqueio
    try:
        resultado = email_alertas.notificar(force=True)
    except Exception:
        log.exception("Falha ao testar alerta de e-mail")
        return _redirect_email(erro="Falha ao testar o alerta no WhatsApp.")
    if resultado.get("enviado"):
        return _redirect_email(
            msg=f"Alerta enviado no WhatsApp ({resultado.get('itens', 0)} endereço(s) fora do SLA)."
        )
    motivo = resultado.get("motivo") or "sem pendências"
    return _redirect_email(msg=f"Alerta não enviado: {motivo}.")


@app.post("/admin/email/criar", tags=["Admin"])
async def admin_email_criar(request: Request):
    _rate_limit_check(request, max_requests=20, chave_extra="admin-email")
    bloqueio = _exigir_sessao_admin(request)
    if bloqueio:
        return bloqueio
    form = await request.form()
    try:
        email, senha = email_admin.criar_caixa(
            prefixo=str(form.get("prefixo") or ""),
            nome=str(form.get("nome") or ""),
            cota_gb=form.get("cota_gb") or 2,
        )
        return _pagina_email(msg=f"Caixa {email} criada.", credenciais=(email, senha))
    except email_admin.EmailAdminErro as exc:
        return _pagina_email(erro=str(exc))


@app.post("/admin/email/senha", tags=["Admin"])
async def admin_email_senha(request: Request):
    _rate_limit_check(request, max_requests=20, chave_extra="admin-email")
    bloqueio = _exigir_sessao_admin(request)
    if bloqueio:
        return bloqueio
    form = await request.form()
    try:
        email = email_admin.validar_email(str(form.get("email") or ""))
        senha = email_admin.gerar_senha_temporaria(email)
        aviso = " (caixa administrativa: use esta senha na próxima entrada)" if _caixa_administrativa(email) else ""
        return _pagina_email(msg=f"Nova senha gerada para {email}.{aviso}", credenciais=(email, senha))
    except email_admin.EmailAdminErro as exc:
        return _pagina_email(erro=str(exc))


@app.post("/admin/email/status", tags=["Admin"])
async def admin_email_status(request: Request):
    _rate_limit_check(request, max_requests=20, chave_extra="admin-email")
    bloqueio = _exigir_sessao_admin(request)
    if bloqueio:
        return bloqueio
    form = await request.form()
    try:
        email = email_admin.validar_email(str(form.get("email") or ""))
        ativo = str(form.get("ativo") or "") == "1"
        if _caixa_administrativa(email):
            return _pagina_email(erro="A caixa administrativa não pode ser desativada pelo painel.")
        email_admin.definir_status(email, ativo)
        return _redirect_email(msg=f"Caixa {email} {'ativada' if ativo else 'desativada'}.")
    except email_admin.EmailAdminErro as exc:
        return _pagina_email(erro=str(exc))


@app.get("/admin/email/excluir", response_class=HTMLResponse, tags=["Admin"])
def admin_email_confirmar_exclusao(request: Request, email: str = ""):
    _rate_limit_check(request, max_requests=60)
    bloqueio = _exigir_sessao_admin(request)
    if bloqueio:
        return bloqueio
    try:
        email = email_admin.validar_email(email)
        caixas = email_admin.listar_caixas()
    except email_admin.EmailAdminErro as exc:
        return _pagina_email(erro=str(exc))
    alvo = next((c for c in caixas if c["email"] == email), None)
    if alvo is None:
        return _pagina_email(erro="Caixa não encontrada.")
    if alvo.get("admin"):
        return _pagina_email(erro="A caixa administrativa não pode ser excluída pelo painel.")
    return HTMLResponse(admin_ui.pagina_confirmar_exclusao(alvo))


@app.post("/admin/email/excluir", tags=["Admin"])
async def admin_email_excluir(request: Request):
    _rate_limit_check(request, max_requests=20, chave_extra="admin-email")
    bloqueio = _exigir_sessao_admin(request)
    if bloqueio:
        return bloqueio
    form = await request.form()
    try:
        email = email_admin.validar_email(str(form.get("email") or ""))
        if str(form.get("confirmar") or "") != "sim":
            return _redirect_email(erro="Confirmação ausente — nada foi excluído.")
        if _caixa_administrativa(email):
            return _pagina_email(erro="A caixa administrativa não pode ser excluída pelo painel.")
        email_admin.excluir_caixa(email)
        return _redirect_email(msg=f"Caixa {email} excluída.")
    except email_admin.EmailAdminErro as exc:
        return _pagina_email(erro=str(exc))


@app.post("/admin/email/alias/criar", tags=["Admin"])
async def admin_email_alias_criar(request: Request):
    _rate_limit_check(request, max_requests=20, chave_extra="admin-email")
    bloqueio = _exigir_sessao_admin(request)
    if bloqueio:
        return bloqueio
    form = await request.form()
    try:
        email = email_admin.criar_alias(
            prefixo=str(form.get("prefixo") or ""),
            destino_email=str(form.get("destino_email") or ""),
        )
        return _redirect_email(msg=f"Endereço {email} criado.")
    except email_admin.EmailAdminErro as exc:
        return _pagina_email(erro=str(exc))


@app.post("/admin/email/alias/excluir", tags=["Admin"])
async def admin_email_alias_excluir(request: Request):
    _rate_limit_check(request, max_requests=20, chave_extra="admin-email")
    bloqueio = _exigir_sessao_admin(request)
    if bloqueio:
        return bloqueio
    form = await request.form()
    try:
        email = email_admin.validar_email(str(form.get("email") or ""))
        email_admin.excluir_alias(email)
        return _redirect_email(msg=f"Endereço {email} excluído.")
    except email_admin.EmailAdminErro as exc:
        return _pagina_email(erro=str(exc))


# ---------------------------------------------------------------------------
# Avisos de novo e-mail: Web Push no PWA + WhatsApp + e-mail opcional
# ---------------------------------------------------------------------------

@app.get("/admin/push/public-key", tags=["Admin"])
def admin_push_public_key(request: Request):
    if _sessao_admin(request) is None:
        return JSONResponse({"erro": "não autenticado"}, status_code=401)
    return JSONResponse({"key": push.public_key(), "configurado": push.configurado()})


def _json_sessao(request: Request):
    return _sessao_admin(request) is not None


@app.post("/admin/push/subscribe", tags=["Admin"])
async def admin_push_subscribe(request: Request):
    if not _json_sessao(request):
        return JSONResponse({"ok": False, "erro": "não autenticado"}, status_code=401)
    try:
        dados = await request.json()
    except Exception:
        return JSONResponse({"ok": False, "erro": "JSON inválido"}, status_code=400)
    ator = _identidade_admin(request)
    if not push.salvar_inscricao(ator, dados or {}):
        return JSONResponse({"ok": False, "erro": "inscrição inválida"}, status_code=400)
    admin_service.registrar_auditoria(ator, "push.inscrever", "", "", _cliente_ip(request))
    return JSONResponse({"ok": True, "inscricoes": push.contar(ator)})


@app.post("/admin/push/unsubscribe", tags=["Admin"])
async def admin_push_unsubscribe(request: Request):
    if not _json_sessao(request):
        return JSONResponse({"ok": False, "erro": "não autenticado"}, status_code=401)
    try:
        dados = await request.json()
    except Exception:
        dados = {}
    endpoint = str((dados or {}).get("endpoint") or "")
    return JSONResponse({"ok": push.remover_inscricao(endpoint)})


@app.post("/admin/email/avisos/testar", tags=["Admin"])
def admin_email_avisos_testar(request: Request):
    _rate_limit_check(request, max_requests=6, chave_extra="admin-avisos")
    bloqueio = _exigir_papel(request, ("admin",))
    if bloqueio:
        return bloqueio
    resultado = email_novos.testar_aviso()
    admin_service.registrar_auditoria(
        _identidade_admin(request), "email.avisos_testar", "", json.dumps(resultado)[:300], _cliente_ip(request)
    )
    if resultado.get("enviado"):
        canais = ", ".join(nome for nome, ok in (resultado.get("canais") or {}).items() if ok)
        return _redirect_email(msg=f"Teste enviado por: {canais or 'nenhum canal ativo'}.")
    return _redirect_email(
        erro="Nenhum canal de aviso ativo. Ative as notificações neste dispositivo ou configure WhatsApp/e-mail."
    )


@app.post("/admin/email/avisos/verificar", tags=["Admin"])
def admin_email_avisos_verificar(request: Request):
    _rate_limit_check(request, max_requests=10, chave_extra="admin-avisos")
    bloqueio = _exigir_papel(request, ("admin",))
    if bloqueio:
        return bloqueio
    resultado = email_novos.verificar_caixas(notificar=True)
    admin_service.registrar_auditoria(
        _identidade_admin(request), "email.avisos_verificar", "", json.dumps(resultado)[:300], _cliente_ip(request)
    )
    if not resultado.get("ok"):
        return _redirect_email(erro=str(resultado.get("motivo") or "falha ao verificar as caixas"))
    msg = f"{resultado.get('caixas')} caixa(s) verificada(s), {resultado.get('novos')} e-mail(s) novo(s)."
    if resultado.get("enviado"):
        msg += " Aviso enviado."
    elif resultado.get("novos"):
        msg += " Sem canal de aviso ativo."
    return _redirect_email(msg=msg)


@app.get("/admin/email/avisos/wpp19/qr.png", tags=["Admin"])
def admin_email_avisos_wpp19_qr(request: Request):
    """QR do remetente 19 servido como imagem (CSP permite apenas same-origin)."""
    bloqueio = _exigir_papel(request, ("admin",))
    if bloqueio:
        return Response(status_code=403)
    qr = wuzapi_alertas.qr_code()
    if not qr.startswith("data:image"):
        return Response(status_code=503)
    try:
        conteudo = base64.b64decode(qr.split(",", 1)[1])
    except Exception:
        return Response(status_code=503)
    return Response(
        content=conteudo,
        media_type="image/png",
        headers={"Cache-Control": "no-store"},
    )


@app.post("/admin/email/avisos/wpp19/codigo", response_class=HTMLResponse, tags=["Admin"])
def admin_email_avisos_wpp19_codigo(request: Request):
    _rate_limit_check(request, max_requests=20, chave_extra="admin-avisos-wpp")
    bloqueio = _exigir_papel(request, ("admin",))
    if bloqueio:
        return bloqueio
    codigo = wuzapi_alertas.codigo_pareamento()
    return HTMLResponse(
        admin_ui.pagina_conectar_avisos(
            "", wuzapi_alertas.status(), email_novos._destino_whatsapp(), codigo=codigo
        )
    )


@app.get("/admin/email/avisos/wpp19", response_class=HTMLResponse, tags=["Admin"])
def admin_email_avisos_wpp19(request: Request):
    _rate_limit_check(request, max_requests=60, chave_extra="admin-avisos-wpp")
    bloqueio = _exigir_papel(request, ("admin",))
    if bloqueio:
        return bloqueio
    estado = wuzapi_alertas.status()
    qr = "" if estado.get("conectado") else wuzapi_alertas.qr_code()
    return HTMLResponse(
        admin_ui.pagina_conectar_avisos(qr, estado, email_novos._destino_whatsapp())
    )


# ---------------------------------------------------------------------------
# Painel de custos (Fase 1): custo de IA, Magalu Cloud e custos fixos
# ---------------------------------------------------------------------------

def _redirect_custos(msg: str = "", erro: str = "") -> RedirectResponse:
    parametros = {}
    if msg:
        parametros["msg"] = msg
    if erro:
        parametros["erro"] = erro
    destino = "/admin/custos" + (("?" + urlencode(parametros)) if parametros else "")
    return RedirectResponse(destino, status_code=303)


@app.get("/admin/custos", response_class=HTMLResponse, tags=["Admin"])
def admin_custos(request: Request, msg: str = "", erro: str = ""):
    _rate_limit_check(request, max_requests=60)
    bloqueio = _exigir_papel(request, ("admin", "financeiro"))
    if bloqueio:
        return bloqueio
    dados = custos.painel()
    papel = _papel_admin(request)
    return HTMLResponse(
        admin_ui.pagina_custos(dados, msg=msg, erro=erro, pode_email=(papel == "admin"))
    )


@app.post("/admin/custos/sincronizar", tags=["Admin"])
def admin_custos_sincronizar(request: Request):
    _rate_limit_check(request, max_requests=10, chave_extra="admin-custos")
    bloqueio = _exigir_papel(request, ("admin",))
    if bloqueio:
        return bloqueio
    resultado = custos.sincronizar_magalu(dias=7)
    admin_service.registrar_auditoria(
        _identidade_admin(request),
        "custos.sincronizar_magalu",
        "",
        f"ok={resultado.get('ok')} registros={resultado.get('registros')}",
        _cliente_ip(request),
    )
    if not resultado.get("ok"):
        return _redirect_custos(erro=f"Magalu: {resultado.get('erro') or 'falha na sincronização'}")
    return _redirect_custos(
        msg=(
            f"Magalu sincronizada: {resultado.get('registros', 0)} registro(s), "
            f"R$ {float(resultado.get('total_brl') or 0):.2f} no período."
        )
    )


@app.post("/admin/custos/fixos", tags=["Admin"])
async def admin_custos_novo_fixo(request: Request):
    _rate_limit_check(request, max_requests=20, chave_extra="admin-custos")
    bloqueio = _exigir_papel(request, ("admin",))
    if bloqueio:
        return bloqueio
    form = await request.form()
    descricao = (form.get("descricao") or "").strip()
    fornecedor = (form.get("fornecedor") or "").strip()
    try:
        valor = float(str(form.get("valor_brl") or "0").replace(",", "."))
    except ValueError:
        valor = 0.0
    try:
        dia = int(str(form.get("dia_cobranca") or "1"))
    except ValueError:
        dia = 1
    periodicidade = (form.get("periodicidade") or "mensal").strip().lower()
    if not descricao:
        return _redirect_custos(erro="Informe a descrição do custo fixo.")
    if valor <= 0:
        return _redirect_custos(erro="Informe um valor maior que zero.")
    custo_id = custos.registrar_custo_fixo(descricao, fornecedor, valor, dia, periodicidade)
    admin_service.registrar_auditoria(
        _identidade_admin(request), "custos.fixo_criar", custo_id, descricao[:120], _cliente_ip(request)
    )
    return _redirect_custos(msg="Custo fixo cadastrado.")


@app.post("/admin/custos/fixos/{custo_id}/remover", tags=["Admin"])
def admin_custos_remover_fixo(request: Request, custo_id: str):
    _rate_limit_check(request, max_requests=20, chave_extra="admin-custos")
    bloqueio = _exigir_papel(request, ("admin",))
    if bloqueio:
        return bloqueio
    if not custos.remover_custo_fixo(custo_id):
        return _redirect_custos(erro="Custo fixo não encontrado ou já removido.")
    admin_service.registrar_auditoria(
        _identidade_admin(request), "custos.fixo_remover", custo_id, "", _cliente_ip(request)
    )
    return _redirect_custos(msg="Custo fixo removido.")


if __name__ == "__main__":
    import uvicorn

    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8000"))
    uvicorn.run("main:app", host=host, port=port, reload=True)
