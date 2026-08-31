from pydantic import BaseModel, Field, field_validator

from prompts.abordagens import PROMPTS_ABORDAGEM

TERMOS_PESSOA_ATENDIDA = {"paciente", "cliente", "pessoa atendida"}


def validar_senha(senha: str) -> str:
    """Senha forte: >= 10 chars com letra maiuscula, minuscula e numero."""
    if len(senha) < 10:
        raise ValueError("A senha deve ter pelo menos 10 caracteres.")
    if not any(c.isupper() for c in senha):
        raise ValueError("A senha deve conter pelo menos uma letra maiuscula.")
    if not any(c.islower() for c in senha):
        raise ValueError("A senha deve conter pelo menos uma letra minuscula.")
    if not any(c.isdigit() for c in senha):
        raise ValueError("A senha deve conter pelo menos um numero.")
    return senha


class TranscricaoRequest(BaseModel):
    audio_base64: str = Field(
        min_length=1,
        max_length=50_000_000,
        description="Arquivo de audio em base64",
    )
    formato: str = Field(default="wav", max_length=10)


class TranscricaoResponse(BaseModel):
    sucesso: bool
    transcricao: str = ""
    erro: str = ""


class SinteseRequest(BaseModel):
    sessao_id: str = Field(min_length=1, max_length=100)
    numero_sessao: int = Field(ge=1, le=10_000)
    nome_pessoa_atendida: str = Field(max_length=120)
    termo_pessoa_atendida: str = Field(max_length=50)
    abordagem_clinica: str = Field(max_length=100)
    transcricao_relato: str = Field(max_length=100_000)
    relato_manual: str = Field(max_length=100_000)
    tema_principal: str = Field(default="", max_length=200)

    @field_validator("termo_pessoa_atendida")
    @classmethod
    def _validar_termo_pessoa_atendida(cls, v: str) -> str:
        if v.strip().lower() not in TERMOS_PESSOA_ATENDIDA:
            raise ValueError(
                "termo_pessoa_atendida deve ser um dos termos permitidos: "
                + ", ".join(sorted(TERMOS_PESSOA_ATENDIDA))
            )
        return v.strip().lower()

    @field_validator("abordagem_clinica")
    @classmethod
    def _validar_abordagem_clinica(cls, v: str) -> str:
        if v.strip() not in PROMPTS_ABORDAGEM:
            raise ValueError(
                "abordagem_clinica deve ser uma abordagem suportada: "
                + ", ".join(sorted(PROMPTS_ABORDAGEM))
            )
        return v.strip()


class SinteseResponse(BaseModel):
    sucesso: bool
    relato_clinico_organizado: str = ""
    apontamentos_copiloto: str = ""
    sintese_clinica: str = ""
    formulacao_clinica: str = ""
    intervencoes: str = ""
    plano_proxima_sessao: str = ""
    temas_pesquisa: list = Field(default_factory=list)
    artigos_sugeridos: str = ""
    erro: str = ""


class ArtigosRequest(BaseModel):
    temas_pesquisa: list = Field(default_factory=list)
    contexto_clinico: str = Field(default="", max_length=100_000)


class ArtigosResponse(BaseModel):
    sucesso: bool
    artigos_sugeridos: str = ""
    erro: str = ""


class HealthResponse(BaseModel):
    status: str = "ok"
    versao: str = "1.0.0"
    debug_info: dict | None = None


class LoginRequest(BaseModel):
    username: str = Field(min_length=1, max_length=100)
    password: str = Field(min_length=1, max_length=200)


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    usuario_id: str = ""
    email: str = ""
    nome: str = ""
    plano: str = ""


class RegistrarRequest(BaseModel):
    email: str = Field(min_length=5, max_length=200)
    senha: str = Field(min_length=10, max_length=200)
    nome: str = Field(default="", max_length=120)

    _validar_senha = field_validator("senha")(validar_senha)


class RegistrarResponse(BaseModel):
    sucesso: bool
    usuario_id: str = ""
    mensagem: str = ""
    erro: str = ""


class ContratoRequest(BaseModel):
    nome_paciente: str = Field(min_length=1, max_length=120)
    nome_profissional: str = Field(min_length=1, max_length=120)
    registro_profissional: str = Field(max_length=30)
    termo_pessoa: str = Field(max_length=50)
    template_contrato: str = Field(default="", max_length=50_000)
    tratamento: str = Field(default="masculino", max_length=10)
    crp_verificado: bool = False


class ContratoResponse(BaseModel):
    sucesso: bool
    token: str = ""
    url: str = ""
    erro: str = ""


class ContratoAceiteRequest(BaseModel):
    nome: str = Field(min_length=3, max_length=120)


class ContratoStatusResponse(BaseModel):
    sucesso: bool
    status: str = "pendente"
    aceito_em: str | None = None
    nome_aceite: str | None = None
    erro: str = ""


class WhatsAppRequest(BaseModel):
    telefone: str = Field(min_length=8, max_length=30)
    mensagem: str = Field(min_length=1, max_length=1600)


class WhatsAppResponse(BaseModel):
    sucesso: bool
    mensagem: str = ""
    erro: str = ""


class WuzapiConfigRequest(BaseModel):
    wuzapi_token: str = Field(min_length=8, max_length=500)
    wuzapi_user_id: int = 0


class LembreteRequest(BaseModel):
    compromisso_id: str = Field(min_length=1, max_length=100)
    telefone: str = Field(min_length=8, max_length=30)
    mensagem: str = Field(min_length=1, max_length=1600)
    horario_envio: str = Field(min_length=10, max_length=30)
    canal: str = Field(default="whatsapp", max_length=20)


class LembreteResponse(BaseModel):
    sucesso: bool
    id: str = ""
    erro: str = ""


class AnamneseRequest(BaseModel):
    template_json: str = Field(min_length=10, max_length=50_000)
    abordagem: str = Field(max_length=100)
    nome_paciente: str = Field(min_length=1, max_length=120)
    nome_profissional: str = Field(min_length=1, max_length=120)
    registro: str = Field(default="", max_length=30)
    tratamento: str = Field(default="masculino", max_length=10)
    crp_verificado: bool = False


class AnamneseResponse(BaseModel):
    sucesso: bool
    token: str = ""
    url: str = ""


class ResponderAnamneseRequest(BaseModel):
    respostas: str = Field(min_length=2, max_length=100_000)


class AnamneseStatusResponse(BaseModel):
    sucesso: bool
    status: str = "pendente"
    data_resposta: str | None = None
    respostas_json: str = ""
    erro: str = ""


class ProgressoRequest(BaseModel):
    paciente_id: str = Field(min_length=1, max_length=50)
    numero_sessao: int = Field(ge=1)
    sessoes_anteriores: list = Field(default_factory=list)
    sessao_atual: dict = Field(default_factory=dict)
    objetivos_terapeuticos: str = Field(default="", max_length=10_000)
    queixa_principal: str = Field(default="", max_length=5_000)
    escalas: list = Field(default_factory=list)

    @field_validator("sessoes_anteriores")
    @classmethod
    def _validar_sessoes_anteriores(cls, v):
        if not v:
            return v
        if not isinstance(v, list):
            raise ValueError("sessoes_anteriores deve ser uma lista.")
        for item in v:
            if not isinstance(item, dict):
                raise ValueError("Cada sessão anterior deve ser um objeto.")
            numero = item.get("numero")
            if numero is not None:
                try:
                    int(numero)
                except (TypeError, ValueError):
                    raise ValueError("numero da sessão anterior deve ser numérico.")
            data = item.get("data")
            if data is not None and data != "":
                cls._validar_data_iso(data, "data da sessão anterior")
        return v

    @field_validator("sessao_atual")
    @classmethod
    def _validar_sessao_atual(cls, v):
        if not isinstance(v, dict):
            raise ValueError("sessao_atual deve ser um objeto.")
        data = v.get("data")
        if data is not None and data != "":
            cls._validar_data_iso(data, "data da sessão atual")
        return v

    @field_validator("escalas")
    @classmethod
    def _validar_escalas(cls, v):
        if not v:
            return v
        if not isinstance(v, list):
            raise ValueError("escalas deve ser uma lista.")
        for escala in v:
            if not isinstance(escala, dict):
                raise ValueError("Cada escala deve ser um objeto.")
            for d in escala.get("datas", []) or []:
                if not isinstance(d, dict):
                    raise ValueError("Cada aplicação de escala deve ser um objeto.")
                data = d.get("data")
                if data is not None and data != "":
                    cls._validar_data_iso(data, "data da escala")
                pontuacao = d.get("pontuacao")
                if pontuacao is not None and pontuacao != "":
                    try:
                        float(pontuacao)
                    except (TypeError, ValueError):
                        raise ValueError("pontuacao da escala deve ser numérica.")
        return v

    @staticmethod
    def _validar_data_iso(valor, campo: str) -> None:
        import datetime
        if isinstance(valor, datetime.date):
            return
        texto = str(valor).strip()
        try:
            datetime.date.fromisoformat(texto[:10])
        except ValueError:
            raise ValueError(f"{campo} deve ser uma data ISO (AAAA-MM-DD).")


class ProgressoResponse(BaseModel):
    sucesso: bool
    sintomas: list = Field(default_factory=list)
    metas: list = Field(default_factory=list)
    avaliacao_geral: str = ""
    tendencia: str = "estavel"
    recomendacoes: str = ""
    erro: str = ""


class VerificarCrpRequest(BaseModel):
    registro: str = Field(min_length=3, max_length=20)


class VerificarCrpResponse(BaseModel):
    sucesso: bool
    ativo: bool = False
    nome_oficial: str = ""
    data_inscricao: str = ""
    erro: str = ""


class RecuperacaoRequest(BaseModel):
    email: str = Field(min_length=5, max_length=200)


class RecuperacaoResponse(BaseModel):
    sucesso: bool
    mensagem: str = ""
    erro: str = ""


class RegistrarRecuperacaoRequest(BaseModel):
    email: str = Field(min_length=5, max_length=200)
    recovery_token: str = Field(min_length=8, max_length=500)


class VerificarCodigoRequest(BaseModel):
    email: str = Field(min_length=5, max_length=200)
    codigo: str = Field(min_length=6, max_length=12)


class VerificarCodigoResponse(BaseModel):
    sucesso: bool
    recovery_token: str = ""
    erro: str = ""
