import os
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from models.schemas import (
    HealthResponse,
    SinteseRequest,
    SinteseResponse,
    TranscricaoRequest,
    TranscricaoResponse,
)
from services.ia_clinica import gerar_sintese
from services.transcricao import transcrever_audio

load_dotenv()


@asynccontextmanager
async def lifespan(app: FastAPI):
    provider = os.getenv("IA_MODEL_PROVIDER", "openai").strip().lower()

    if provider == "openai":
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key or api_key.startswith("sua_chave"):
            print("⚠️  OPENAI_API_KEY não configurada. Crie um arquivo .env baseado no .env.example")
    elif provider == "gemini":
        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key or api_key.startswith("sua_chave"):
            print("⚠️  GEMINI_API_KEY não configurada. Crie um arquivo .env baseado no .env.example")

    model = os.getenv("IA_MODEL", "gpt-4.1")
    print(f"🧠 Modelo de IA configurado: {provider}/{model}")
    yield


app = FastAPI(
    title="MentAll API",
    description="Backend de IA para o prontuário clínico MentAll",
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
    return HealthResponse(status="ok", versao="1.0.0")


@app.post("/transcrever", response_model=TranscricaoResponse, tags=["Transcrição"])
def transcrever(request: TranscricaoRequest):
    if not request.audio_base64:
        raise HTTPException(status_code=400, detail="Nenhum áudio informado.")

    resultado = transcrever_audio(request.audio_base64, request.formato)

    if not resultado["sucesso"]:
        return TranscricaoResponse(
            sucesso=False, transcricao="", erro=resultado["erro"]
        )

    return TranscricaoResponse(
        sucesso=True, transcricao=resultado["transcricao"], erro=""
    )


@app.post("/gerar-sintese", response_model=SinteseResponse, tags=["IA Clínica"])
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
        humor=request.humor,
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
