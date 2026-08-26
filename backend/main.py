import asyncio
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
from contextlib import asynccontextmanager
from datetime import datetime, timedelta, timezone
from email.mime.text import MIMEText

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, HTTPException, Request, status
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from passlib.context import CryptContext

load_dotenv(os.path.join(os.path.dirname(os.path.abspath(__file__)), '.env'))

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("mentall")

from models.schemas import (
    AnamneseRequest,
    AnamneseResponse,
    AnamneseStatusResponse,
    ArtigosRequest,
    ArtigosResponse,
    ContratoAceiteRequest,
    ContratoRequest,
    ContratoResponse,
    ContratoStatusResponse,
    HealthResponse,
    LembreteRequest,
    LembreteResponse,
    LoginRequest,
    LoginResponse,
    ProgressoRequest,
    ProgressoResponse,
    RecuperacaoRequest,
    RecuperacaoResponse,
    RegistrarRecuperacaoRequest,
    RegistrarRequest,
    RegistrarResponse,
    ResponderAnamneseRequest,
    SinteseRequest,
    SinteseResponse,
    TranscricaoRequest,
    TranscricaoResponse,
    VerificarCodigoRequest,
    VerificarCodigoResponse,
    VerificarCrpRequest,
    VerificarCrpResponse,
    WhatsAppRequest,
    WhatsAppResponse,
    WuzapiConfigRequest,
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
    iniciar_scheduler,
    parar_scheduler,
    registrar_receipt,
    salvar_instancia_wuzapi,
)
from services.transcricao import transcrever_audio

_rate_limit_store: dict[str, list[float]] = {}


def _limpar_rate_limits(agora: float) -> None:
    for ip in list(_rate_limit_store.keys()):
        _rate_limit_store[ip] = [t for t in _rate_limit_store[ip] if agora - t < 60.0]
        if not _rate_limit_store[ip]:
            del _rate_limit_store[ip]


def _rate_limit_check(ip: str, max_requests: int) -> None:
    agora = time.time()
    _limpar_rate_limits(agora)
    timestamps = _rate_limit_store.get(ip, [])
    if len(timestamps) >= max_requests:
        raise HTTPException(status_code=429, detail="Muitas requisicoes. Aguarde um momento.")
    timestamps.append(agora)
    _rate_limit_store[ip] = timestamps


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


def _renderizar_template_personalizado(
    token: str,
    dados: dict,
    aceito: bool,
    aceito_em: str,
    base_url: str,
    nome_aceite: str = "",
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
    var resp = await fetch('{base_url}/contratos/{token}/aceitar', {{ method: 'POST', headers: {{'Content-Type': 'application/json'}}, body: JSON.stringify({{nome: nome}}) }});
    if (resp.ok) {{ document.getElementById('secao-aceite').style.display = 'none'; document.getElementById('sucesso-msg').style.display = 'block'; }}
    else {{ var d = await resp.json(); erroEl.textContent = d.erro || d.detail || 'Erro ao registrar.'; erroEl.style.display = 'block'; btn.disabled = false; btn.textContent = 'Li e aceito'; }}
  }} catch(e) {{ erroEl.textContent = 'Erro de conex\\u00e3o.'; erroEl.style.display = 'block'; btn.disabled = false; btn.textContent = 'Li e aceito'; }}
}}
</script>
</body>
</html>"""
    return HTMLResponse(content=page_html)


def _verificar_senha(senha: str) -> bool:
    if not APP_PASSWORD_HASH:
        return False
    try:
        return pwd_context.verify(senha, APP_PASSWORD_HASH)
    except Exception:
        return False


def _criar_token_jwt(username: str, owner_id: str) -> str:
    expiracao = datetime.now(timezone.utc) + timedelta(minutes=JWT_EXPIRATION)
    payload = {"sub": username, "exp": expiracao, "owner": owner_id}
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


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
    yield
    await parar_scheduler()


app = FastAPI(
    title="MentAll PRO API",
    description="Backend de IA para o prontuário clínico MentAll PRO",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://mentall-api.onrender.com",
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
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
    if "text/html" in (response.headers.get("content-type") or ""):
        response.headers["Content-Security-Policy"] = (
            "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; "
            "frame-ancestors 'none'; base-uri 'self'"
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
    ip = _req.client.host if _req.client else "unknown"
    _rate_limit_check(ip, max_requests=10)

    username = request.username.strip()

    # 1) Admin legado (owner fixo, preserva dados existentes)
    if username == APP_USERNAME and _verificar_senha(request.password):
        token = _criar_token_jwt(username, APP_USER_ID)
        log.info("Login admin legado bem-sucedido (IP: %s)", ip)
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
        log.warning("Falha de autenticação para usuário '%s' (IP: %s)", _mascarar_contato(username), ip)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciais inválidas.",
        )

    if usuario["status"] == "pendente":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Conta não confirmada. Verifique seu e-mail.",
        )

    registrar_acesso(usuario["id"])
    token = _criar_token_jwt(usuario["email"], usuario["id"])
    log.info("Login bem-sucedido para usuário '%s' (IP: %s)", _mascarar_contato(usuario["email"]), ip)
    return LoginResponse(
        access_token=token,
        usuario_id=usuario["id"],
        email=usuario["email"],
        nome=usuario["nome"],
        plano=usuario["plano"],
    )


@app.post("/auth/registrar", response_model=RegistrarResponse, tags=["Autenticação"])
async def registrar(request: RegistrarRequest, _req: Request):
    ip = _req.client.host if _req.client else "unknown"
    _rate_limit_check(ip, max_requests=5)

    email = request.email.strip().lower()
    if "@" not in email or "." not in email.split("@")[-1]:
        raise HTTPException(status_code=400, detail="Email invalido.")

    from services.usuarios import criar_usuario_pendente, obter_por_email, regenerar_token

    existente = obter_por_email(email)
    if existente is not None and existente["status"] == "ativo":
        raise HTTPException(status_code=409, detail="E-mail já cadastrado.")

    token = (
        regenerar_token(email)
        if existente is not None
        else criar_usuario_pendente(email, request.senha, request.nome)
    )

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
    ip = _req.client.host if _req.client else "unknown"
    _rate_limit_check(ip, max_requests=30)

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
<p style="color:#64748B;">Sua conta foi ativada. Volte ao app e toque em "Ja confirmei" para entrar.</p>
</body></html>""",
    )


@app.post(
    "/verificar-crp",
    response_model=VerificarCrpResponse,
    tags=["CRP"],
    dependencies=[Depends(_verificar_token)],
)
def verificar_crp(request: VerificarCrpRequest, _req: Request):
    ip = _req.client.host if _req.client else "unknown"
    _rate_limit_check(ip, max_requests=5)

    log.info("Verificacao de CRP solicitada: %s", request.registro[:8])
    resultado = verificar_crp_online(request.registro)

    return VerificarCrpResponse(
        sucesso=True,
        ativo=resultado["ativo"],
        nome_oficial=resultado.get("nome_oficial", ""),
        data_inscricao=resultado.get("data_inscricao", ""),
        erro=resultado.get("erro", ""),
    )


@app.post(
    "/transcrever",
    response_model=TranscricaoResponse,
    tags=["Transcricao"],
    dependencies=[Depends(_verificar_token)],
)
async def transcrever(request: TranscricaoRequest, req: Request):
    ip = req.client.host if req.client else "unknown"
    _rate_limit_check(ip, max_requests=10)

    content_length = req.headers.get("content-length")
    max_body = 35 * 1024 * 1024  # 35MB (25MB audio + base64 overhead + JSON)
    if content_length and int(content_length) > max_body:
        raise HTTPException(status_code=413, detail="Arquivo de audio muito grande. Maximo: 25MB.")

    if not request.audio_base64:
        raise HTTPException(status_code=400, detail="Nenhum audio informado.")

    log.info("Solicitação de transcrição recebida (formato: %s)", request.formato)
    loop = asyncio.get_running_loop()
    resultado = await loop.run_in_executor(
        None, transcrever_audio, request.audio_base64, request.formato,
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
    ip = _req.client.host if _req.client else "unknown"
    _rate_limit_check(ip, max_requests=30)

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
    )


@app.post(
    "/gerar-artigos",
    response_model=ArtigosResponse,
    tags=["IA Clinica"],
    dependencies=[Depends(_verificar_token)],
)
async def artigos(request: ArtigosRequest, _req: Request):
    ip = _req.client.host if _req.client else "unknown"
    _rate_limit_check(ip, max_requests=30)

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
        request.contexto_clinico,
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
    ip = _req.client.host if _req.client else "unknown"
    _rate_limit_check(ip, max_requests=30)

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
    ip = _req.client.host if _req.client else "unknown"
    _rate_limit_check(ip, max_requests=10)
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
    ip = _req.client.host if _req.client else "unknown"
    _rate_limit_check(ip, max_requests=10)
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


@app.post("/wuzapi/webhook", tags=["Mensagens"])
async def webhook_wuzapi(request: Request):
    """Recebe os webhooks do wuzapi (ReadReceipt/Message).

    O wuzapi POSTa eventos assinados (Message, ReadReceipt) para a URL
    configurada. Aqui processamos apenas os ReadReceipt que confirmam a
    entrega/leitura das mensagens de lembrete, correlacionando pelo
    ``mensagem_id`` gravado no envio.

    A URL do webhook deve incluir ``?token=...`` (env WUZAPI_WEBHOOK_TOKEN)
    para autenticacao. Em modo form (padrao), o payload chega no campo
    ``jsonData``; em modo json, no corpo.
    """
    ip = request.client.host if request.client else "unknown"
    _rate_limit_check(ip, max_requests=120)

    esperado = os.getenv("WUZAPI_WEBHOOK_TOKEN", "").strip()
    recebido = request.query_params.get("token", "")
    if not esperado or recebido != esperado:
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
    ip = _req.client.host if _req.client else "unknown"
    _rate_limit_check(ip, max_requests=10)
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
        "crp_verificado": request.crp_verificado,
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
    ip = _req.client.host if _req.client else "unknown"
    _rate_limit_check(ip, max_requests=30)
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
        "{{url_aceitar}}": f"{base_url}/contratos/{token}/aceitar",
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

    return HTMLResponse(content=page_html)


@app.post("/contratos/{token}/aceitar", response_model=ContratoStatusResponse, tags=["Contratos"])
def aceitar_contrato(token: str, request: ContratoAceiteRequest, _req: Request):
    ip = _req.client.host if _req.client else "unknown"
    _rate_limit_check(ip, max_requests=10)
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
    dependencies=[Depends(_verificar_token)],
)
def status_contrato(token: str, _req: Request):
    ip = _req.client.host if _req.client else "unknown"
    _rate_limit_check(ip, max_requests=30)
    contrato = obter_contrato(token)
    if contrato is None:
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
    ip = _req.client.host if _req.client else "unknown"
    _rate_limit_check(ip, max_requests=10)
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
async def remover_lembrete(compromisso_id: str, _req: Request):
    ip = _req.client.host if _req.client else "unknown"
    _rate_limit_check(ip, max_requests=10)
    log.info("Remocao de lembrete: %s", compromisso_id[:20])
    ok = await cancelar_lembrete(compromisso_id)
    if not ok:
        return LembreteResponse(sucesso=False, erro="Lembrete não encontrado.")
    return LembreteResponse(sucesso=True, id=compromisso_id)


@app.post(
    "/anamneses",
    response_model=AnamneseResponse,
    tags=["Anamnese"],
    dependencies=[Depends(_verificar_token)],
)
def criar_anamnese_endpoint(request: AnamneseRequest, _req: Request, auth: tuple = Depends(_verificar_token)):
    ip = _req.client.host if _req.client else "unknown"
    _rate_limit_check(ip, max_requests=10)
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
        "crp_verificado": request.crp_verificado,
    }

    token = criar_anamnese(request.template_json, owner_id, dados_extra)
    base_url = os.getenv("API_BASE_URL", "https://mentall-api.fly.dev")
    url = f"{base_url}/anamneses/{token}"

    log.info("Anamnese criada via API: token=%s paciente=%s abordagem=%s",
             token[:8], _mascarar_contato(request.nome_paciente[:20]), request.abordagem)
    return AnamneseResponse(sucesso=True, token=token, url=url)


@app.get("/anamneses/{token}", response_class=HTMLResponse, tags=["Anamnese"])
def pagina_anamnese(token: str, _req: Request):
    ip = _req.client.host if _req.client else "unknown"
    _rate_limit_check(ip, max_requests=30)
    anamnese = obter_anamnese(token)
    if anamnese is None:
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
    html = html.replace("{{DADOS_PROFISSIONAL}}", json.dumps(dados, ensure_ascii=False))
    template_json = (anamnese.get("template_json") or "{}").strip()
    if not template_json or not template_json.startswith("{"):
        template_json = "{}"
    template_json = template_json.replace("</", "<\\/")
    html = html.replace("{{TEMPLATE}}", template_json)

    return HTMLResponse(content=html)


@app.post(
    "/anamneses/{token}/responder",
    response_model=AnamneseStatusResponse,
    tags=["Anamnese"],
)
def responder_anamnese(token: str, request: ResponderAnamneseRequest, _req: Request):
    ip = _req.client.host if _req.client else "unknown"
    _rate_limit_check(ip, max_requests=10)
    log.info("Resposta de anamnese %s", token[:12])
    if not request.respostas.strip():
        raise HTTPException(status_code=400, detail="Respostas não informadas.")

    anamnese = registrar_resposta(token, request.respostas)
    if anamnese is None:
        raise HTTPException(status_code=404, detail="Anamnese não encontrada.")

    return AnamneseStatusResponse(
        sucesso=True,
        status=anamnese["status"],
        data_resposta=anamnese.get("respondido_em"),
        respostas_json=anamnese.get("respostas", ""),
    )


@app.get(
    "/anamneses/{token}/status",
    response_model=AnamneseStatusResponse,
    tags=["Anamnese"],
    dependencies=[Depends(_verificar_token)],
)
def status_anamnese(token: str, _req: Request):
    ip = _req.client.host if _req.client else "unknown"
    _rate_limit_check(ip, max_requests=30)
    anamnese = obter_anamnese(token)
    if anamnese is None:
        return AnamneseStatusResponse(sucesso=False, erro="Anamnese não encontrada.")

    return AnamneseStatusResponse(
        sucesso=True,
        status=anamnese["status"],
        data_resposta=anamnese.get("respondido_em"),
        respostas_json=anamnese.get("respostas", "") or "",
    )


def _gerar_codigo() -> str:
    return ''.join(secrets.choice(string.digits) for _ in range(6))


def _hash_email(email: str) -> str:
    return hashlib.sha256(email.lower().strip().encode()).hexdigest()


def _hash_codigo(codigo: str) -> str:
    return hashlib.sha256(codigo.encode()).hexdigest()


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
    ip = _req.client.host if _req.client else "unknown"
    _rate_limit_check(ip, max_requests=3)

    email = request.email.strip().lower()
    email_hash = _hash_email(email)
    codigo = _gerar_codigo()
    agora = datetime.now(timezone.utc).isoformat()

    from services.db import executar
    existente = executar(
        "SELECT recovery_token FROM recuperacoes WHERE email_hash = ?",
        (email_hash,),
    ).fetchone()

    if existente:
        executar(
            "UPDATE recuperacoes SET codigo_hash = ?, codigo_expiracao = ? WHERE email_hash = ?",
            (_hash_codigo(codigo), (datetime.now(timezone.utc) + timedelta(minutes=10)).isoformat(), email_hash),
        ).commit()
    else:
        return RecuperacaoResponse(
            sucesso=False,
            erro="Nenhum registro de recuperação encontrado para este e-mail. Configure o PIN primeiro.",
        )

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
    ip = _req.client.host if _req.client else "unknown"
    _rate_limit_check(ip, max_requests=5)

    email = request.email.strip().lower()
    email_hash = _hash_email(email)
    codigo = request.codigo.strip()

    from services.db import executar
    registro = executar(
        "SELECT codigo, codigo_expiracao, recovery_token FROM recuperacoes WHERE email_hash = ?",
        (email_hash,),
    ).fetchone()

    if not registro:
        return VerificarCodigoResponse(sucesso=False, erro="Nenhuma solicitação de recuperação encontrada.")

    codigo_armazenado = registro.get("codigo_hash", "")
    expiracao_str = registro.get("codigo_expiracao", "")

    if _hash_codigo(codigo) != codigo_armazenado:
        return VerificarCodigoResponse(sucesso=False, erro="Codigo invalido.")

    if expiracao_str:
        try:
            expiracao = datetime.fromisoformat(expiracao_str)
            if datetime.now(timezone.utc) > expiracao:
                return VerificarCodigoResponse(sucesso=False, erro="Codigo expirado. Solicite um novo.")
        except Exception:
            pass

    executar(
        "UPDATE recuperacoes SET codigo_hash = NULL, codigo_expiracao = NULL WHERE email_hash = ?",
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
    dependencies=[Depends(_verificar_token)],
)
def registrar_recuperacao(request: RegistrarRecuperacaoRequest, _req: Request):
    ip = _req.client.host if _req.client else "unknown"
    _rate_limit_check(ip, max_requests=5)

    email = request.email.strip().lower()
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


if __name__ == "__main__":
    import uvicorn

    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8000"))
    uvicorn.run("main:app", host=host, port=port, reload=True)
