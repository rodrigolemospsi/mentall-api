import os
from contextlib import asynccontextmanager
from datetime import datetime, timedelta, timezone

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from models.schemas import (
    HealthResponse,
    LoginRequest,
    LoginResponse,
    SinteseRequest,
    SinteseResponse,
    TranscricaoRequest,
    TranscricaoResponse,
)
from services.ia_clinica import gerar_sintese
from services.transcricao import transcrever_audio

load_dotenv()

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


@app.get("/health", response_model=HealthResponse, tags=["Health"])
def health():
    openai_key = os.getenv("OPENAI_API_KEY")
    project_id = os.getenv("OPENAI_PROJECT_ID")
    return HealthResponse(
        status="ok",
        versao="1.0.0",
        debug_info={
            "openai_key_configured": bool(openai_key),
            "openai_key_prefix": (openai_key[:20] + "...") if openai_key else "N/A",
            "openai_project_id_configured": bool(project_id),
            "openai_project_id": project_id or "N/A",
        },
    )


@app.post("/auth/login", response_model=LoginResponse, tags=["Autenticacao"])
def login(request: LoginRequest):
    if not _verificar_senha(request.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciais invalidas.",
        )
    token = _criar_token_jwt(request.username)
    return LoginResponse(access_token=token)


@app.post(
    "/transcrever",
    response_model=TranscricaoResponse,
    tags=["Transcricao"],
    dependencies=[Depends(_verificar_token)],
)
def transcrever(request: TranscricaoRequest):
    if not request.audio_base64:
        raise HTTPException(status_code=400, detail="Nenhum audio informado.")

    resultado = transcrever_audio(request.audio_base64, request.formato)

    if not resultado["sucesso"]:
        return TranscricaoResponse(sucesso=False, transcricao="", erro=resultado["erro"])

    return TranscricaoResponse(sucesso=True, transcricao=resultado["transcricao"], erro="")


@app.post(
    "/gerar-sintese",
    response_model=SinteseResponse,
    tags=["IA Clinica"],
    dependencies=[Depends(_verificar_token)],
)
def sintese(request: SinteseRequest):
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
        return SinteseResponse(sucesso=False, erro=resultado["erro"])

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
        erro="",
    )


if __name__ == "__main__":
    import uvicorn

    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8000"))
    uvicorn.run("main:app", host=host, port=port, reload=True)
