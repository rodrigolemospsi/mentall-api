import base64
import io
import logging
import os

from openai import OpenAI

log = logging.getLogger("mentall.transcricao")
MAX_AUDIO_BYTES = 25 * 1024 * 1024


def _client():
    api_key = os.getenv("OPENAI_API_KEY")
    project_id = os.getenv("OPENAI_PROJECT_ID")
    if not api_key:
        raise Exception("OPENAI_API_KEY not set")
    kwargs = {"api_key": api_key}
    if project_id:
        kwargs["project"] = project_id
    return OpenAI(**kwargs)


def transcrever_audio(audio_base64: str, formato: str = "wav") -> dict:
    try:
        audio_bytes = base64.b64decode(audio_base64)

        if len(audio_bytes) > MAX_AUDIO_BYTES:
            log.warning("Arquivo de audio excede 25MB: %d bytes", len(audio_bytes))
            return {
                "sucesso": False,
                "transcricao": "",
                "erro": f"Arquivo de audio muito grande ({len(audio_bytes)} bytes). Maximo: 25MB.",
            }

        model = os.getenv("TRANSCRICAO_MODEL", "gpt-4o-mini-transcribe")
        log.info("Iniciando transcricao - modelo=%s formato=%s tamanho=%d bytes", model, formato, len(audio_bytes))

        audio_file = io.BytesIO(audio_bytes)
        audio_file.name = f"audio.{formato}"

        transcricao = _client().audio.transcriptions.create(
            model=model,
            file=audio_file,
            language="pt",
            response_format="text",
        )

        log.info("Transcricao concluida com sucesso (%d caracteres)", len(transcricao.strip()))
        return {
            "sucesso": True,
            "transcricao": transcricao.strip(),
            "erro": "",
        }

    except Exception as e:
        log.exception("Erro ao transcrever audio: %s", e)
        return {
            "sucesso": False,
            "transcricao": "",
            "erro": f"Erro ao transcrever áudio: {type(e).__name__}: {str(e)}",
        }
