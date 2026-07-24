from pydantic import BaseModel


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
    artigos_sugeridos: str = ""
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


class ContratoRequest(BaseModel):
    nome_paciente: str
    nome_profissional: str
    registro_profissional: str
    termo_pessoa: str


class ContratoResponse(BaseModel):
    sucesso: bool
    token: str = ""
    url: str = ""
    erro: str = ""


class ContratoAceiteRequest(BaseModel):
    nome: str


class ContratoStatusResponse(BaseModel):
    sucesso: bool
    status: str = "pendente"
    aceito_em: str | None = None
    nome_aceite: str | None = None
    erro: str = ""


class WhatsAppRequest(BaseModel):
    telefone: str
    mensagem: str


class WhatsAppResponse(BaseModel):
    sucesso: bool
    mensagem: str = ""
    erro: str = ""


class LembreteRequest(BaseModel):
    compromisso_id: str
    telefone: str
    mensagem: str
    horario_envio: str
    canal: str = "whatsapp"


class LembreteResponse(BaseModel):
    sucesso: bool
    id: str = ""
    erro: str = ""
