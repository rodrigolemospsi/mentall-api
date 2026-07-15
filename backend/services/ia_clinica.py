import json
import os
from urllib.parse import quote_plus

import requests
from google import genai
from google.genai import types
from openai import OpenAI

from prompts.abordagens import PROMPT_UNIVERSAL, obter_prompt_abordagem

BASES_PESQUISA = [
    ("SciELO", "https://search.scielo.org/?q={consulta}&lang=pt"),
    ("Periódicos CAPES", "https://www.periodicos.capes.gov.br/index.php/acervo/buscador.html?q={consulta}"),
    ("Oasisbr", "https://oasisbr.ibict.br/vufind/Search/Results?lookfor={consulta}&type=AllFields"),
]


def _montar_artigos_sugeridos(temas_pesquisa: list) -> str:
    temas_validos = [
        str(t).strip() for t in (temas_pesquisa or []) if str(t).strip()
    ][:2]
    if not temas_validos:
        return ""

    blocos = []
    for i, tema in enumerate(temas_validos, 1):
        consulta = quote_plus(tema)
        linhas = [f"{i}. {tema.capitalize()}"]
        for nome_base, url_template in BASES_PESQUISA:
            linhas.append(f"   {nome_base}: {url_template.format(consulta=consulta)}")
        blocos.append("\n".join(linhas))

    return "\n".join(blocos)


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
    "temas_pesquisa": ["tema de busca 1", "tema de busca 2"]
}} 

TEMAS DE PESQUISA CIENTÍFICA:
No campo "temas_pesquisa", extraia exatamente 2 temas de busca científica a partir do conteúdo clínico da sessão. Critérios:
1. Cada tema deve ser uma expressão de busca CURTA e ABRANGENTE (2 a 4 palavras), em português, como seria digitada em uma base de dados científica. Ex: "ansiedade trabalho", "terapia cognitiva insônia".
2. Evite expressões longas ou muito específicas — elas retornam zero resultados nas bases.
3. O primeiro tema deve focar no tema clínico central da sessão; o segundo pode combinar um tema da sessão com a abordagem {abordagem_clinica} de forma resumida.
4. NÃO inclua o nome do {termo} nem qualquer dado que identifique a pessoa atendida.
5. NÃO invente títulos de artigos nem links — apenas os temas de busca.
6. Se o material clínico for insuficiente, retorne lista vazia.

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
        "artigos_sugeridos": _montar_artigos_sugeridos(
            resultado_raw.get("temas_pesquisa", [])
        ),
        "erro": "",
    }


def _gerar_sintese_gemini(prompt: str) -> dict:
    client = _gemini_client()
    if not client:
        return {"sucesso": False, "erro": "GEMINI_API_KEY não configurada."}

    try:
        config = types.GenerateContentConfig(
            response_mime_type="application/json",
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
        return _parse_resultado_sucesso(resultado)

    except json.JSONDecodeError:
        return {"sucesso": False, "erro": "Resposta da IA não pôde ser interpretada. Tente novamente."}
    except Exception as e:
        return {"sucesso": False, "erro": f"Erro ao gerar síntese clínica: {str(e)}"}


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

        return resultado

    except Exception as e:
        return {"sucesso": False, "erro": f"Erro ao gerar síntese clínica: {str(e)}"}
