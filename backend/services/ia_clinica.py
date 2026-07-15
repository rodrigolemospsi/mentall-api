import json
import os

import requests
from google import genai
from google.genai import types
from openai import OpenAI

from prompts.abordagens import PROMPT_UNIVERSAL, obter_prompt_abordagem


def _get_provider() -> str:
    return os.getenv("IA_MODEL_PROVIDER", "openai").strip().lower()


def _get_model_name() -> str:
    provider = _get_provider()
    if provider == "openai":
        return os.getenv("IA_MODEL", "gpt-4.1")
    if provider == "deepseek":
        return os.getenv("IA_MODEL", "deepseek-chat")
    return os.getenv("IA_MODEL", "gemini-2.0-flash")


def _gemini_client():
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        return None
    return genai.Client(api_key=api_key)


def _openai_client():
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        return None
    return OpenAI(
        api_key=api_key,
        project=os.getenv("OPENAI_PROJECT_ID"),
    )


def _montar_prompt_sintese(
    numero_sessao: int,
    nome_pessoa_atendida: str,
    termo_pessoa_atendida: str,
    abordagem_clinica: str,
    material_base: str,
    tema_principal: str,
    prompt_abordagem: str,
) -> str:
    termo = termo_pessoa_atendida or "paciente"
    nome = nome_pessoa_atendida or "não informado"
    tema = tema_principal or "não informado"

    return f"""
{PROMPT_UNIVERSAL}

{prompt_abordagem}

--- DADOS DA SESSÃO ---
Número da sessão: {numero_sessao}
{termo.capitalize()}: {nome}
Tema principal informado: {tema}

--- MATERIAL CLÍNICO ---
{material_base}

--- INSTRUÇÕES ---
Com base no material acima, gere um JSON válido com a seguinte estrutura (sem markdown, sem ```json, apenas o JSON puro):
{{
    "relato_clinico_organizado": "Síntese clínica organizada em texto corrido, com estilo profissional, pronta para compor o prontuário. Deve incluir: contexto trazido pelo {termo}, temas trabalhados, intervenções realizadas, evolução observada e encaminhamentos/foco. Escreva de forma coesa, como se fosse um relato clínico completo.",
    "apontamentos_copiloto": "Apontamentos do Copiloto para revisão profissional. Tópicos com observações clínicas, hipóteses a investigar, padrões identificados e sugestões de foco. Use marcas de atenção como 'Pode indicar...', 'Sugere-se investigar...', 'Hipótese clínica...'",
    "eventos_importantes": "Eventos, conteúdos ou temas centrais trazidos na sessão que merecem destaque clínico.",
    "evolucao_clinica": "Avaliação da evolução do {termo} em relação a sessões anteriores, se aplicável. Mudanças percebidas, continuidade de temas, respostas a intervenções.",
    "observacoes": "Observações relevantes para o prontuário: dados contextuais, cuidados éticos, riscos, potencialidades ou encaminhamentos.",
    "pensamentos_automaticos": "Conteúdo compatível com o campo específico da abordagem {abordagem_clinica}: pensamentos, significados, crenças, interpretações ou cognições relevantes.",
    "emocoes": "Emoções, afetos, sentimentos ou estados subjetivos relevantes mencionados ou observados.",
    "comportamentos": "Comportamentos, padrões de resposta, estratégias de enfrentamento, ações ou mudanças observadas.",
    "intervencoes": "Intervenções realizadas pelo profissional durante a sessão: perguntas, devolutivas, psicoeducação, validações, confrontações, exercícios, etc.",
    "tecnicas": "Técnicas ou recursos clínicos utilizados, compatíveis com a abordagem {abordagem_clinica}.",
    "tarefa_casa": "Tarefa, reflexão, exercício ou observação combinada com o {termo} para o período entre sessões. Se não houver, deixe vazio.",
    "plano_proxima_sessao": "Foco, temas pendentes ou objetivos para a próxima sessão.",
     "artigos_sugeridos": "Indicação de exatamente 2 artigos científicos em português, baseados no conteúdo da sessão. Use o formato: '1. Título: ... Link: ...\\n2. Título: ... Link: ...'. Priorize artigos reais das plataformas SciELO, Oasisbr, BDTD ou CAPES. Se não tiver certeza dos links exatos, indique o título e um link de busca no Google Scholar (ex: https://scholar.google.com/scholar?q=titulo+do+artigo). Não invente títulos — apenas sugira artigos cujo tema você reconhece da literatura."
}} 

ARTIGOS CIENTÍFICOS SUGERIDOS:
Com base em toda a sessão clínica analisada (relato, síntese clínica, temas emergentes, hipóteses compreensivas, demandas, intervenções e focos terapêuticos), indique exatamente 2 artigos científicos em português como sugestão de leitura complementar para o profissional. Critérios:
1. Apenas artigos científicos em português.
2. Diretamente relacionados ao conteúdo clínico da sessão.
3. Compatíveis com a síntese clínica, evitando sugestões genéricas.
4. Priorizar artigos reconhecidos, relevantes e entre os mais citados do tema.
5. Preferir artigos de: SciELO, Oasisbr, BDTD, Portal de Periódicos CAPES.
6. NÃO indicar livros, capítulos, dissertações, teses, blogs, sites, materiais didáticos, vídeos ou textos opinativos.
7. Se não souber o link exato, use um link de busca do Google Scholar como fallback.
8. Apenas deixe o campo vazio se não houver nenhum artigo relevante na literatura relacionado ao tema da sessão.

IMPORTANTE:
- Use o termo "{termo}" para se referir à pessoa atendida
- Todo o texto deve estar em português
- Seja específico(a) com base no material clínico fornecIDo, não genérico(a)
- Campos vazios devem vir como string vazia ""
"""


def _parse_resultado_sucesso(resultado_raw: dict) -> dict:
    return {
        "sucesso": True,
        "relato_clinico_organizado": resultado_raw.get("relato_clinico_organizado", ""),
        "apontamentos_copiloto": resultado_raw.get("apontamentos_copiloto", ""),
        "eventos_importantes": resultado_raw.get("eventos_importantes", ""),
        "evolucao_clinica": resultado_raw.get("evolucao_clinica", ""),
        "observacoes": resultado_raw.get("observacoes", ""),
        "pensamentos_automaticos": resultado_raw.get("pensamentos_automaticos", ""),
        "emocoes": resultado_raw.get("emocoes", ""),
        "comportamentos": resultado_raw.get("comportamentos", ""),
        "intervencoes": resultado_raw.get("intervencoes", ""),
        "tecnicas": resultado_raw.get("tecnicas", ""),
        "tarefa_casa": resultado_raw.get("tarefa_casa", ""),
        "plano_proxima_sessao": resultado_raw.get("plano_proxima_sessao", ""),
        "artigos_sugeridos": resultado_raw.get("artigos_sugeridos", ""),
        "erro": "",
    }


def _gerar_sintese_gemini(prompt: str) -> dict:
    client = _gemini_client()
    if not client:
        return {"sucesso": False, "erro": "GEMINI_API_KEY não configurada."}

    try:
        config = types.GenerateContentConfig(
            response_mime_type="application/json",
            tools=[types.Tool(google_search=types.GoogleSearch())],
        )

        response = client.models.generate_content(
            model=_get_model_name(),
            contents=prompt,
            config=config,
        )

        conteudo = response.text
        if not conteudo:
            return {"sucesso": False, "erro": "Resposta vazia da IA."}

        resultado = json.loads(conteudo)
        parsed = _parse_resultado_sucesso(resultado)

        parsed["artigos_sugeridos"] = _extrair_artigos_grounding(response, resultado)

        return parsed

    except json.JSONDecodeError:
        return {"sucesso": False, "erro": "Resposta da IA não pôde ser interpretada. Tente novamente."}
    except Exception as e:
        return {"sucesso": False, "erro": f"Erro ao gerar síntese clínica: {str(e)}"}


def _extrair_artigos_grounding(response, resultado: dict) -> str:
    fontes = []
    try:
        if response.candidates:
            candidate = response.candidates[0]
            gmeta = getattr(candidate, "grounding_metadata", None)
            if gmeta:
                chunks = getattr(gmeta, "grounding_chunks", None) or []
                for chunk in chunks:
                    web = getattr(chunk, "web", None)
                    if web:
                        uri = getattr(web, "uri", None)
                        title = getattr(web, "title", None)
                        if uri:
                            fontes.append((title or "Artigo", uri))
    except Exception:
        pass

    if fontes:
        linhas = []
        for i, (titulo, link) in enumerate(fontes[:2], 1):
            linhas.append(f"{i}. {titulo}: {link}")
        return "\n".join(linhas)

    return resultado.get("artigos_sugeridos", "")


def _gerar_sintese_openai(prompt: str) -> dict:
    client = _openai_client()
    if not client:
        return {"sucesso": False, "erro": "OPENAI_API_KEY não configurada."}
    return _gerar_sintese_openai_compat(client, prompt)


def _gerar_sintese_deepseek(prompt: str) -> dict:
    api_key = os.getenv("DEEPSEEK_API_KEY")
    if not api_key:
        return {"sucesso": False, "erro": "DEEPSEEK_API_KEY não configurada."}

    model = _get_model_name()

    try:
        resp = requests.post(
            "https://api.deepseek.com/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": model,
                "messages": [
                    {
                        "role": "system",
                        "content": "Você é um assistente clínico especializado em psicologia. Gere JSON válido sem markdown.",
                    },
                    {"role": "user", "content": prompt},
                ],
                "response_format": {"type": "json_object"},
                "temperature": 0.3,
            },
            timeout=120,
        )

        if resp.status_code != 200:
            return {
                "sucesso": False,
                "erro": f"DeepSeek retornou {resp.status_code}: {resp.text[:200]}",
            }

        data = resp.json()
        conteudo = data["choices"][0]["message"]["content"]

        if not conteudo:
            return {"sucesso": False, "erro": "Resposta vazia da IA."}

        resultado = json.loads(conteudo)
        return _parse_resultado_sucesso(resultado)

    except json.JSONDecodeError:
        return {"sucesso": False, "erro": "Resposta da IA não pôde ser interpretada. Tente novamente."}
    except Exception as e:
        return {"sucesso": False, "erro": f"Erro ao gerar síntese: {type(e).__name__}: {str(e)}"}


def _gerar_sintese_openai_compat(client, prompt: str) -> dict:
    try:
        response = client.chat.completions.create(
            model=_get_model_name(),
            messages=[
                {
                    "role": "system",
                    "content": "Você é um assistente clínico especializado em psicologia. Gere JSON válido sem markdown.",
                },
                {"role": "user", "content": prompt},
            ],
            response_format={"type": "json_object"},
            temperature=0.3,
        )

        conteudo = response.choices[0].message.content
        if not conteudo:
            return {"sucesso": False, "erro": "Resposta vazia da IA."}

        resultado = json.loads(conteudo)
        return _parse_resultado_sucesso(resultado)

    except json.JSONDecodeError:
        return {"sucesso": False, "erro": "Resposta da IA não pôde ser interpretada. Tente novamente."}
    except Exception as e:
        return {"sucesso": False, "erro": f"Erro ao gerar síntese clínica: {str(e)}"}


def _buscar_artigos_grounding(
    numero_sessao: int,
    nome_pessoa_atendida: str,
    termo_pessoa_atendida: str,
    abordagem_clinica: str,
    sintese_clinica: str,
) -> str:
    client = _gemini_client()
    if not client:
        return ""

    termo = termo_pessoa_atendida or "paciente"
    nome = nome_pessoa_atendida or "não informado"

    prompt = f"""
Busque exatamente 2 artigos científicos em português relacionados ao seguinte caso clínico.

Abordagem: {abordagem_clinica}
Sessão número: {numero_sessao}
{termo.capitalize()}: {nome}

Síntese clínica da sessão:
{sintese_clinica}

Responda APENAS com um JSON no formato:
{{"artigos": [{{"titulo": "...", "link": "..."}}, {{"titulo": "...", "link": "..."}}]}}

IMPORTANTE:
- Busque apenas em SciELO, BDTD, Oasisbr e Portal de Periódicos CAPES.
- Priorize artigos diretamente relacionados ao conteúdo da sessão e à abordagem {abordagem_clinica}.
- Se não encontrar artigos reais, retorne lista vazia.
"""

    try:
        config = types.GenerateContentConfig(
            response_mime_type="application/json",
            tools=[types.Tool(google_search=types.GoogleSearch())],
        )

        response = client.models.generate_content(
            model="gemini-2.0-flash",
            contents=prompt,
            config=config,
        )

        return _extrair_artigos_grounding(response, {})

    except Exception:
        return ""


def gerar_sintese(
    sessao_id: str,
    numero_sessao: int,
    nome_pessoa_atendida: str,
    termo_pessoa_atendida: str,
    abordagem_clinica: str,
    transcricao_relato: str,
    relato_manual: str,
    tema_principal: str,
) -> dict:
    try:
        prompt_abordagem = obter_prompt_abordagem(abordagem_clinica)

        material_base = relato_manual if relato_manual.strip() else transcricao_relato

        if not material_base.strip():
            return {
                "sucesso": False,
                "erro": "Não há relato ou transcrição suficiente para gerar síntese clínica.",
            }

        prompt = _montar_prompt_sintese(
            numero_sessao=numero_sessao,
            nome_pessoa_atendida=nome_pessoa_atendida,
            termo_pessoa_atendida=termo_pessoa_atendida,
            abordagem_clinica=abordagem_clinica,
            material_base=material_base,
            tema_principal=tema_principal,
            prompt_abordagem=prompt_abordagem,
        )

        provider = _get_provider()

        if provider == "openai":
            resultado = _gerar_sintese_openai(prompt)
        elif provider == "deepseek":
            resultado = _gerar_sintese_deepseek(prompt)
        elif provider == "gemini":
            resultado = _gerar_sintese_gemini(prompt)
        else:
            return {"sucesso": False, "erro": f"Provedor desconhecido: {provider}. Use 'openai', 'deepseek' ou 'gemini'."}

        if resultado.get("sucesso") and provider != "gemini":
            artigos_grounded = _buscar_artigos_grounding(
                numero_sessao=numero_sessao,
                nome_pessoa_atendida=nome_pessoa_atendida,
                termo_pessoa_atendida=termo_pessoa_atendida,
                abordagem_clinica=abordagem_clinica,
                sintese_clinica=resultado.get("relato_clinico_organizado", ""),
            )
            if artigos_grounded:
                resultado["artigos_sugeridos"] = artigos_grounded

        return resultado

    except Exception as e:
        return {"sucesso": False, "erro": f"Erro ao gerar síntese clínica: {str(e)}"}
