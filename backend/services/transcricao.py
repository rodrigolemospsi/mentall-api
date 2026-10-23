import base64
import io
import logging
import os
from datetime import datetime, timezone

from groq import Groq
from openai import OpenAI

log = logging.getLogger("mentall.transcricao")
MAX_AUDIO_BYTES = 25 * 1024 * 1024

# Última falha de transcrição nesta instância (some em restart/deploy).
# Guiada por clareza operacional: só provider + mensagem curta, nunca o áudio.
_ULTIMA_FALHA: dict | None = None


def _registrar_falha(provider: str, erro: Exception) -> None:
    global _ULTIMA_FALHA
    mensagem = str(erro).strip().replace("\n", " ")[:160]
    _ULTIMA_FALHA = {
        "quando": datetime.now(timezone.utc).isoformat(),
        "provider": provider,
        "mensagem": mensagem,
    }


def ultima_falha() -> dict | None:
    """Última falha registrada desde o último start do backend (ou None)."""
    return dict(_ULTIMA_FALHA) if _ULTIMA_FALHA else None


def limpar_ultima_falha() -> None:
    global _ULTIMA_FALHA
    _ULTIMA_FALHA = None


def _get_transcricao_provider():
    return os.getenv("TRANSCRICAO_PROVIDER", "groq").strip().lower()


def _get_transcricao_model():
    provider = _get_transcricao_provider()
    default_model = "whisper-large-v3-turbo" if provider == "groq" else "gpt-4o-mini-transcribe"
    return os.getenv("TRANSCRICAO_MODEL", default_model)


def _create_groq_client():
    api_key = os.getenv("GROQ_API_KEY")
    if not api_key:
        raise Exception("GROQ_API_KEY not set")
    return Groq(api_key=api_key)


def _create_openai_client():
    api_key = os.getenv("OPENAI_API_KEY")
    project_id = os.getenv("OPENAI_PROJECT_ID")
    if not api_key:
        raise Exception("OPENAI_API_KEY not set")
    kwargs = {"api_key": api_key, "timeout": 120.0}
    if project_id:
        kwargs["project"] = project_id
    return OpenAI(**kwargs)


def transcrever_audio(audio_base64: str, formato: str = "wav") -> dict:
    provider = _get_transcricao_provider()
    model = _get_transcricao_model()

    try:
        audio_bytes = base64.b64decode(audio_base64)

        if len(audio_bytes) > MAX_AUDIO_BYTES:
            log.warning("Arquivo de audio excede 25MB: %d bytes", len(audio_bytes))
            return {
                "sucesso": False,
                "transcricao": "",
                "erro": f"Arquivo de audio muito grande ({len(audio_bytes)} bytes). Maximo: 25MB.",
            }

        log.info(
            "Iniciando transcrição - provider=%s modelo=%s formato=%s tamanho=%d bytes",
            provider, model, formato, len(audio_bytes),
        )

        audio_file = io.BytesIO(audio_bytes)
        audio_file.name = f"audio.{formato}"

        if provider == "groq":
            transcricao = _transcrever_groq(audio_file, model)
        else:
            transcricao = _transcrever_openai(audio_file, model)

        log.info("Transcricao concluida com sucesso (%d caracteres)", len(transcricao.strip()))
        return {
            "sucesso": True,
            "transcricao": transcricao.strip(),
            "erro": "",
        }

    except Exception as e:
        _registrar_falha(provider, e)
        log.exception("Erro ao transcrever audio (provider=%s): %s", provider, e)
        return {
            "sucesso": False,
            "transcricao": "",
            "erro": f"Erro ao transcrever audio: {type(e).__name__}: {str(e)}",
        }


def _transcrever_groq(audio_file, model):
    client = _create_groq_client()
    response = client.audio.transcriptions.create(
        model=model,
        file=audio_file,
        language="pt",
        response_format="text",
    )
    return response if isinstance(response, str) else response.text


def _transcrever_openai(audio_file, model):
    client = _create_openai_client()
    response = client.audio.transcriptions.create(
        model=model,
        file=audio_file,
        language="pt",
        response_format="text",
    )
    return response
