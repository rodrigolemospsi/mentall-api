import asyncio
import logging
import os
import time
from contextlib import asynccontextmanager
from datetime import datetime, timedelta, timezone

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, HTTPException, Request, status
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from models.schemas import (
    ContratoAceiteRequest,
    ContratoRequest,
    ContratoResponse,
    ContratoStatusResponse,
    HealthResponse,
    LembreteRequest,
    LembreteResponse,
    LoginRequest,
    LoginResponse,
    SinteseRequest,
    SinteseResponse,
    SmsRequest,
    SmsResponse,
    TranscricaoRequest,
    TranscricaoResponse,
    WhatsAppRequest,
    WhatsAppResponse,
)
from services.contrato_service import (
    criar_contrato,
    obter_contrato,
    registrar_aceite,
)
from services.ia_clinica import gerar_sintese
from services.lembrete_service import (
    agendar_lembrete,
    cancelar_lembrete,
    iniciar_scheduler,
    parar_scheduler,
)
from services.transcricao import transcrever_audio

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("mentall")

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


JWT_SECRET = os.getenv("JWT_SECRET", "desenvolvimento_segredo_temporario")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
JWT_EXPIRATION = int(os.getenv("JWT_EXPIRATION_MINUTES", "480"))
APP_USERNAME = os.getenv("APP_USERNAME", "admin")
APP_PASSWORD_HASH = os.getenv("APP_PASSWORD_HASH", "")

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security = HTTPBearer()


def _verificar_senha(senha: str) -> bool:
    if not APP_PASSWORD_HASH:
        return senha == "admin"
    try:
        return pwd_context.verify(senha, APP_PASSWORD_HASH)
    except Exception:
        return False


def _criar_token_jwt(username: str) -> str:
    expiracao = datetime.now(timezone.utc) + timedelta(minutes=JWT_EXPIRATION)
    payload = {"sub": username, "exp": expiracao}
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def _verificar_token(credentials: HTTPAuthorizationCredentials = Depends(security)) -> str:
    token = credentials.credentials
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        username: str | None = payload.get("sub")
        if username is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token invalido.",
            )
        return username
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
        print(f"ATENCAO: chave de API para {provider} nao configurada.")

    model = os.getenv("IA_MODEL", "gpt-4.1")
    print(f"Modelo de IA: {provider}/{model}")

    if JWT_SECRET == "desenvolvimento_segredo_temporario":
        print("ATENCAO: usando JWT_SECRET padrao. Configure no .env para producao.")
    if not APP_PASSWORD_HASH:
        print("ATENCAO: APP_PASSWORD_HASH nao configurado. Senha padrao: admin")

    yield
    await parar_scheduler()


app = FastAPI(
    title="MentAll API",
    description="Backend de IA para o prontuario clinico MentAll",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

iniciar_scheduler()


@app.get("/health", response_model=HealthResponse, tags=["Health"])
def health():
    openai_key = os.getenv("OPENAI_API_KEY")
    project_id = os.getenv("OPENAI_PROJECT_ID")
    gemini_key = os.getenv("GEMINI_API_KEY")
    deepseek_key = os.getenv("DEEPSEEK_API_KEY")
    provider = os.getenv("IA_MODEL_PROVIDER", "openai").strip().lower()
    modelos_padrao = {"openai": "gpt-4.1", "deepseek": "deepseek-chat", "gemini": "gemini-2.0-flash"}
    modelo_efetivo = os.getenv("IA_MODEL") or modelos_padrao.get(provider, "gpt-4.1")
    return HealthResponse(
        status="ok",
        versao="1.0.0",
        debug_info={
            "openai_key_configured": bool(openai_key),
            "openai_key_prefix": (openai_key[:20] + "...") if openai_key else "N/A",
            "openai_project_id_configured": bool(project_id),
            "openai_project_id": project_id or "N/A",
            "gemini_key_configured": bool(gemini_key),
            "deepseek_key_configured": bool(deepseek_key),
            "ia_model_provider": provider,
            "ia_model": modelo_efetivo,
        },
    )


@app.post("/auth/login", response_model=LoginResponse, tags=["Autenticacao"])
def login(request: LoginRequest, _req: Request = Depends()):
    ip = _req.client.host if _req.client else "unknown"
    _rate_limit_check(ip, max_requests=10)
    if not _verificar_senha(request.password):
        log.warning("Falha de autenticacao para usuario '%s' (IP: %s)", request.username, ip)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciais invalidas.",
        )
    log.info("Login bem-sucedido para usuario '%s' (IP: %s)", request.username, ip)
    token = _criar_token_jwt(request.username)
    return LoginResponse(access_token=token)


@app.post(
    "/transcrever",
    response_model=TranscricaoResponse,
    tags=["Transcricao"],
    dependencies=[Depends(_verificar_token)],
)
def transcrever(request: TranscricaoRequest, req: Request = Depends()):
    content_length = req.headers.get("content-length")
    max_body = 35 * 1024 * 1024  # 35MB (25MB audio + base64 overhead + JSON)
    if content_length and int(content_length) > max_body:
        raise HTTPException(status_code=413, detail="Arquivo de audio muito grande. Maximo: 25MB.")

    if not request.audio_base64:
        raise HTTPException(status_code=400, detail="Nenhum audio informado.")

    log.info("Solicitacao de transcricao recebida (formato: %s)", request.formato)
    resultado = transcrever_audio(request.audio_base64, request.formato)

    if not resultado["sucesso"]:
        log.error("Falha na transcricao: %s", resultado["erro"])
        return TranscricaoResponse(sucesso=False, transcricao="", erro=resultado["erro"])

    log.info("Transcricao concluida com sucesso (%d caracteres)", len(resultado["transcricao"]))
    return TranscricaoResponse(sucesso=True, transcricao=resultado["transcricao"], erro="")


@app.post(
    "/gerar-sintese",
    response_model=SinteseResponse,
    tags=["IA Clinica"],
    dependencies=[Depends(_verificar_token)],
)
def sintese(request: SinteseRequest, _req: Request = Depends()):
    ip = _req.client.host if _req.client else "unknown"
    _rate_limit_check(ip, max_requests=30)

    log.info(
        "Solicitacao de sintese - sessao_id=%s sessao=%d abordagem=%s",
        request.sessao_id[:8],
        request.numero_sessao,
        request.abordagem_clinica,
    )
    resultado = gerar_sintese(
        sessao_id=request.sessao_id,
        numero_sessao=request.numero_sessao,
        nome_pessoa_atendida=request.nome_pessoa_atendida,
        termo_pessoa_atendida=request.termo_pessoa_atendida,
        abordagem_clinica=request.abordagem_clinica,
        transcricao_relato=request.transcricao_relato,
        relato_manual=request.relato_manual,
        tema_principal=request.tema_principal,
    )

    if not resultado["sucesso"]:
        log.error("Falha na sintese: %s", resultado["erro"])
        return SinteseResponse(sucesso=False, erro=resultado["erro"])

    log.info("Sintese concluida com sucesso")
    return SinteseResponse(
        sucesso=True,
        relato_clinico_organizado=resultado["relato_clinico_organizado"],
        apontamentos_copiloto=resultado["apontamentos_copiloto"],
        eventos_importantes=resultado["eventos_importantes"],
        evolucao_clinica=resultado["evolucao_clinica"],
        observacoes=resultado["observacoes"],
        pensamentos_automaticos=resultado["pensamentos_automaticos"],
        emocoes=resultado["emocoes"],
        comportamentos=resultado["comportamentos"],
        intervencoes=resultado["intervencoes"],
        tecnicas=resultado["tecnicas"],
        tarefa_casa=resultado["tarefa_casa"],
        plano_proxima_sessao=resultado["plano_proxima_sessao"],
        artigos_sugeridos=resultado["artigos_sugeridos"],
        erro="",
    )


@app.post(
    "/enviar-sms",
    response_model=SmsResponse,
    tags=["Mensagens"],
    dependencies=[Depends(_verificar_token)],
)
def enviar_sms(request: SmsRequest):
    if not request.telefone.strip():
        raise HTTPException(status_code=400, detail="Telefone nao informado.")
    if not request.mensagem.strip():
        raise HTTPException(status_code=400, detail="Mensagem nao informada.")

    account_sid = os.getenv("TWILIO_ACCOUNT_SID", "")
    auth_token = os.getenv("TWILIO_AUTH_TOKEN", "")
    twilio_phone = os.getenv("TWILIO_PHONE_NUMBER", "")

    if not account_sid or not auth_token or not twilio_phone:
        return SmsResponse(
            sucesso=False,
            erro="Servico de SMS nao configurado. Configure TWILIO_ACCOUNT_SID, "
                 "TWILIO_AUTH_TOKEN e TWILIO_PHONE_NUMBER no ambiente.",
        )

    try:
        import requests

        telefone = request.telefone.strip()
        if not telefone.startswith("+"):
            if telefone.startswith("55") and len(telefone) >= 12:
                telefone = "+" + telefone
            else:
                telefone = "+55" + telefone

        url = f"https://api.twilio.com/2010-04-01/Accounts/{account_sid}/Messages.json"
        data = {
            "From": twilio_phone,
            "To": telefone,
            "Body": request.mensagem,
        }

        resp = requests.post(url, data=data, auth=(account_sid, auth_token), timeout=30)

        if resp.status_code in (200, 201):
            return SmsResponse(
                sucesso=True,
                mensagem=f"SMS enviado para {telefone}",
            )
        else:
            return SmsResponse(
                sucesso=False,
                erro=f"Erro Twilio ({resp.status_code}): {resp.text[:300]}",
            )
    except Exception as e:
        return SmsResponse(
            sucesso=False,
            erro=f"Erro ao enviar SMS: {str(e)}",
        )


@app.exception_handler(Exception)
async def _global_exception_handler(request: Request, exc: Exception):
    log.exception("Erro interno nao tratado: %s", exc)
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
def criar_contrato_endpoint(request: ContratoRequest):
    if not request.nome_paciente.strip():
        raise HTTPException(status_code=400, detail="Nome do paciente nao informado.")
    if not request.nome_profissional.strip():
        raise HTTPException(status_code=400, detail="Nome do profissional nao informado.")

    dados = {
        "nome_paciente": request.nome_paciente.strip(),
        "nome_profissional": request.nome_profissional.strip(),
        "registro_profissional": request.registro_profissional.strip(),
        "termo_pessoa": request.termo_pessoa.strip() or "paciente",
    }

    token = criar_contrato(dados)
    base_url = os.getenv("API_BASE_URL", "https://mentall-api.onrender.com")
    url = f"{base_url}/contratos/{token}"

    log.info("Contrato criado via API: token=%s paciente=%s", token[:8], request.nome_paciente[:20])
    return ContratoResponse(sucesso=True, token=token, url=url)


@app.get("/contratos/{token}", response_class=HTMLResponse, tags=["Contratos"])
def pagina_contrato(token: str):
    contrato = obter_contrato(token)
    if contrato is None:
        return HTMLResponse(
            content="<html><body style='font-family:sans-serif;text-align:center;padding:40px;'>"
            "<h2 style='color:#D32F2F;'>Contrato não encontrado</h2>"
            "<p>O link pode ter expirado ou ser inválido.</p></body></html>",
            status_code=404,
        )

    dados = contrato["dados"]
    termo = dados.get("termo_pessoa", "paciente")
    termo_capitalizado = termo[0].upper() + termo[1:] if termo else "Paciente"

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
    data_agora = __import__("datetime").datetime.now().strftime("%d/%m/%Y às %H:%M")
    base_url = os.getenv("API_BASE_URL", "https://mentall-api.onrender.com")

    template_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "templates", "contrato.html")
    try:
        with open(template_path, "r", encoding="utf-8") as f:
            html = f.read()
    except FileNotFoundError:
        html = "<html><body>Erro ao carregar template.</body></html>"

    substituicoes = {
        "{{nome_paciente}}": dados.get("nome_paciente", ""),
        "{{nome_profissional}}": dados.get("nome_profissional", ""),
        "{{registro_profissional}}": dados.get("registro_profissional", "Não informado"),
        "{{termo_pessoa}}": termo,
        "{{termo_pessoa_capitalizado}}": termo_capitalizado,
        "{{artigo_termo}}": artigo,
        "{{preposicao_termo}}": preposicao,
        "{{termo_profissional}}": "do psicólogo",
        "{{local_data}}": "",
        "{{data_agora}}": data_agora,
        "{{url_aceitar}}": f"{base_url}/contratos/{token}/aceitar",
        "{{data_aceite}}": contrato.get("aceito_em", "-")[:10] if contrato.get("aceito_em") else "-",
        "{{nome_aceite}}": contrato.get("nome_aceite", ""),
        "{% if not aceito %}": "" if aceito else "<!--",
        "{% endif %}": "<!--" if not aceito else "",
    }

    for chave, valor in substituicoes.items():
        html = html.replace(chave, str(valor))

    html = html.replace("<!--", "").replace("-->", "")

    return HTMLResponse(content=html)


@app.post("/contratos/{token}/aceitar", response_model=ContratoStatusResponse, tags=["Contratos"])
def aceitar_contrato(token: str, request: ContratoAceiteRequest):
    if not request.nome.strip() or len(request.nome.strip()) < 3:
        raise HTTPException(status_code=400, detail="Nome invalido. Digite seu nome completo.")

    contrato = registrar_aceite(token, request.nome.strip())
    if contrato is None:
        raise HTTPException(status_code=404, detail="Contrato nao encontrado.")

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
def status_contrato(token: str):
    contrato = obter_contrato(token)
    if contrato is None:
        return ContratoStatusResponse(sucesso=False, erro="Contrato nao encontrado.")

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
async def criar_lembrete(request: LembreteRequest):
    if not request.telefone.strip():
        raise HTTPException(status_code=400, detail="Telefone nao informado.")
    if not request.mensagem.strip():
        raise HTTPException(status_code=400, detail="Mensagem nao informada.")
    if not request.horario_envio.strip():
        raise HTTPException(status_code=400, detail="Horario de envio nao informado.")

    rid = await agendar_lembrete(
        compromisso_id=request.compromisso_id,
        telefone=request.telefone.strip(),
        mensagem=request.mensagem.strip(),
        horario_envio=request.horario_envio,
        canal=request.canal or "whatsapp",
    )
    return LembreteResponse(sucesso=True, id=rid)


@app.delete(
    "/lembretes/{compromisso_id}",
    response_model=LembreteResponse,
    tags=["Lembretes"],
    dependencies=[Depends(_verificar_token)],
)
async def remover_lembrete(compromisso_id: str):
    ok = await cancelar_lembrete(compromisso_id)
    if not ok:
        return LembreteResponse(sucesso=False, erro="Lembrete nao encontrado.")
    return LembreteResponse(sucesso=True, id=compromisso_id)


@app.post(
    "/enviar-whatsapp",
    response_model=WhatsAppResponse,
    tags=["Mensagens"],
    dependencies=[Depends(_verificar_token)],
)
def enviar_whatsapp(request: WhatsAppRequest):
    if not request.telefone.strip():
        raise HTTPException(status_code=400, detail="Telefone nao informado.")
    if not request.mensagem.strip():
        raise HTTPException(status_code=400, detail="Mensagem nao informada.")

    account_sid = os.getenv("TWILIO_ACCOUNT_SID", "")
    auth_token = os.getenv("TWILIO_AUTH_TOKEN", "")
    whatsapp_number = os.getenv("TWILIO_WHATSAPP_NUMBER", "")

    if not account_sid or not auth_token:
        return WhatsAppResponse(
            sucesso=False,
            erro="Servico de mensagens nao configurado. Configure TWILIO_ACCOUNT_SID "
                 "e TWILIO_AUTH_TOKEN no ambiente.",
        )

    sandbox = os.getenv("TWILIO_WHATSAPP_SANDBOX", "true").strip().lower() == "true"

    if sandbox:
        from_number = "whatsapp:+14155238886"
    elif whatsapp_number:
        from_number = f"whatsapp:{whatsapp_number}" if not whatsapp_number.startswith("whatsapp:") else whatsapp_number
    else:
        return WhatsAppResponse(
            sucesso=False,
            erro="Numero WhatsApp nao configurado. Defina TWILIO_WHATSAPP_NUMBER "
                 "ou ative TWILIO_WHATSAPP_SANDBOX=true.",
        )

    try:
        import requests

        telefone = request.telefone.strip()
        if not telefone.startswith("+"):
            if telefone.startswith("55") and len(telefone) >= 12:
                telefone = "+" + telefone
            else:
                telefone = "+55" + telefone

        to_number = f"whatsapp:{telefone}"

        url = f"https://api.twilio.com/2010-04-01/Accounts/{account_sid}/Messages.json"
        data = {
            "From": from_number,
            "To": to_number,
            "Body": request.mensagem,
        }

        log.info("Enviando WhatsApp: de=%s para=%s", from_number, to_number[:20])
        resp = requests.post(url, data=data, auth=(account_sid, auth_token), timeout=30)

        if resp.status_code in (200, 201):
            log.info("WhatsApp enviado com sucesso para %s", telefone)
            return WhatsAppResponse(
                sucesso=True,
                mensagem=f"WhatsApp enviado para {telefone}",
            )
        else:
            log.error("Erro Twilio WhatsApp (%s): %s", resp.status_code, resp.text[:300])
            return WhatsAppResponse(
                sucesso=False,
                erro=f"Erro Twilio ({resp.status_code}): {resp.text[:300]}",
            )
    except Exception as e:
        log.exception("Erro ao enviar WhatsApp")
        return WhatsAppResponse(
            sucesso=False,
            erro=f"Erro ao enviar WhatsApp: {str(e)}",
        )


if __name__ == "__main__":
    import uvicorn

    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8000"))
    uvicorn.run("main:app", host=host, port=port, reload=True)
