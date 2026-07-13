from pydantic import BaseModel
from typing import Optional


class TranscricaoRequest(BaseModel):
    audio_base64: str
    formato: str = "wav"


class TranscricaoResponse(BaseModel):
    sucesso: bool
    transcricao: str = ""
    erro: str = ""


class SinteseRequest(BaseModel):
    sessao_id: str
    numero_sessao: int
    nome_pessoa_atendida: str
    termo_pessoa_atendida: str
    abordagem_clinica: str
    transcricao_relato: str
    relato_manual: str
    tema_principal: str
    humor: int = 0


class SinteseResponse(BaseModel):
    sucesso: bool
    relato_clinico_organizado: str = ""
    apontamentos_copiloto: str = ""
    eventos_importantes: str = ""
    evolucao_clinica: str = ""
    observacoes: str = ""
    pensamentos_automaticos: str = ""
    emocoes: str = ""
    comportamentos: str = ""
    intervencoes: str = ""
    tecnicas: str = ""
    tarefa_casa: str = ""
    plano_proxima_sessao: str = ""
    erro: str = ""


class HealthResponse(BaseModel):
    status: str = "ok"
    versao: str = "1.0.0"
    debug_info: dict | None = None


class LoginRequest(BaseModel):
    username: str
    password: str


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class SmsRequest(BaseModel):
    telefone: str
    mensagem: str


class SmsResponse(BaseModel):
    sucesso: bool
    mensagem: str = ""
    erro: str = ""
