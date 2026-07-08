import base64
import io
import os
import traceback

from openai import OpenAI


def _client():
    return OpenAI(api_key=os.getenv("OPENAI_API_KEY"))


def transcrever_audio(audio_base64: str, formato: str = "wav") -> dict:
    try:
        audio_bytes = base64.b64decode(audio_base64)
        audio_file = io.BytesIO(audio_bytes)
        audio_file.name = f"audio.{formato}"

        transcricao = _client().audio.transcriptions.create(
            model="gpt-4o-mini-transcribe",
            file=audio_file,
            language="pt",
            response_format="text",
        )

        return {
            "sucesso": True,
            "transcricao": transcricao.strip(),
            "erro": "",
        }

    except Exception as e:
        return {
            "sucesso": False,
            "transcricao": "",
            "erro": f"Erro ao transcrever áudio: {type(e).__name__}: {str(e)}",
        }
