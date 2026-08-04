import json
import logging
import os
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FutureTimeoutError
from urllib.parse import quote_plus

import requests
from google import genai
from google.genai import types
from openai import OpenAI

from prompts.abordagens import PROMPT_UNIVERSAL, PROMPT_PROGRESSO, obter_prompt_abordagem

log = logging.getLogger("mentall.ia_clinica")

BASES_PESQUISA = [
    ("SciELO", "https://search.scielo.org/?q={consulta}&lang=pt"),
    ("Periódicos CAPES", "https://www.periodicos.capes.gov.br/index.php/acervo/buscador.html?q={consulta}"),
    ("Oasisbr", "https://oasisbr.ibict.br/vufind/Search/Results?lookfor={consulta}&type=AllFields"),
]

MAX_ARTIGOS_TOTAL = 3
MAX_CANDIDATOS_POR_TEMA = 5
MAX_PROMPT_CHARS = 50000
INJECAO_PADROES = [
    r"(?i)ignore\s+all\s+(previous|prior)\s+instructions",
    r"(?i)disregard\s+(all\s+)?(previous|prior)\s+instructions",
    r"(?i)system\s*prompt\s*:",
    r"(?i)you\s+are\s+now\s+(a\s+)?\w+\s*(assistant|bot|ai)",
    r"(?i)new\s+instructions?\s*:",
]
OPENALEX_FILTROS_BASE = "language:pt,type:article,from_publication_date:2010-01-01"
OPENALEX_FILTRO_PSICOLOGIA = "primary_topic.field.id:fields/32"


def _sanitizar_prompt(texto: str) -> str:
    if not texto:
        return ""
    import re
    for padrao in INJECAO_PADROES:
        texto = re.sub(padrao, "[removido]", texto)
    return texto[:MAX_PROMPT_CHARS]


def _openalex_params(params: dict) -> dict:
    api_key = os.getenv("OPENALEX_API_KEY", "").strip()
    if api_key:
        params["api_key"] = api_key
    mailto = os.getenv("OPENALEX_MAILTO", "").strip()
    if mailto:
        params["mailto"] = mailto
    return params


def _reconstruir_resumo_openalex(inverted_index: dict) -> str:
    if not inverted_index:
        return ""
    posicoes = []
    for palavra, indices in inverted_index.items():
        for i in indices:
            posicoes.append((i, palavra))
    posicoes.sort()
    return " ".join(palavra for _, palavra in posicoes)[:400]


def _buscar_candidatos_openalex(consulta: str) -> list:
    consulta_limpa = consulta.replace(",", " ").replace(":", " ").strip()
    filtros = (
        f"title_and_abstract.search:{consulta_limpa},{OPENALEX_FILTROS_BASE},{OPENALEX_FILTRO_PSICOLOGIA}",
        f"title_and_abstract.search:{consulta_limpa},{OPENALEX_FILTROS_BASE}",
    )

    for filtro in filtros:
        try:
            resp = requests.get(
                "https://api.openalex.org/works",
                params=_openalex_params({
                    "filter": filtro,
                    "sort": "relevance_score:desc",
                    "per-page": MAX_CANDIDATOS_POR_TEMA,
                }),
                timeout=10,
            )
            if resp.status_code != 200:
                continue

            candidatos = []
            for work in resp.json().get("results", []):
                titulo = (work.get("title") or "").strip()
                link = (work.get("doi") or work.get("id") or "").strip()
                if not titulo or not link:
                    continue

                nomes = [
                    a.get("author", {}).get("display_name", "").strip()
                    for a in work.get("authorships", [])
                ]
                nomes = [n for n in nomes if n]
                autores = "; ".join(nomes[:3]) + (" et al." if len(nomes) > 3 else "")

                candidatos.append({
                    "id": work.get("id", ""),
                    "titulo": titulo,
                    "autores": autores,
                    "link": link,
                    "ano": work.get("publication_year"),
                    "citacoes": work.get("cited_by_count"),
                    "resumo": _reconstruir_resumo_openalex(
                        work.get("abstract_inverted_index")
                    ),
                })

            if candidatos:
                return candidatos

        except Exception as e:
            log.warning("OpenAlex falhou para filtro: %s", e)
            continue

    return []


def _normalizar_temas(temas_pesquisa: list) -> list:
    temas = []
    for item in (temas_pesquisa or [])[:2]:
        if isinstance(item, dict):
            especifico = str(item.get("especifico", "")).strip()
            amplo = str(item.get("amplo", "")).strip()
        else:
            especifico = str(item).strip()
            amplo = ""
        if especifico or amplo:
            temas.append((especifico, amplo))
    return temas


def _buscar_candidatos_tema(especifico: str, amplo: str) -> list:
    consultas = [c for c in dict.fromkeys([especifico, amplo]) if c]
    candidatos = []
    chaves = set()
    for consulta in consultas:
        achados = _buscar_candidatos_openalex(consulta)
        for c in achados:
            chave = c.get("id") or c["link"]
            if chave in chaves:
                continue
            chaves.add(chave)
            candidatos.append(c)
    return candidatos[:MAX_CANDIDATOS_POR_TEMA + 1]


def _rerankear_artigos(candidatos: list, contexto_clinico: str) -> list:
    sem_justificativa = [
        {**c, "justificativa": ""} for c in candidatos[:MAX_ARTIGOS_TOTAL]
    ]
    if not contexto_clinico.strip() or len(candidatos) <= 1:
        return sem_justificativa

    linhas = []
    for i, c in enumerate(candidatos, 1):
        cabecalho = f"{i}. {c['titulo']}"
        if c.get("ano"):
            cabecalho += f" ({c['ano']})"
        if c.get("autores"):
            cabecalho += f" - {c['autores']}"
        linhas.append(cabecalho)
        if c.get("resumo"):
            linhas.append(f"   Resumo: {c['resumo'][:350]}")

    prompt = f"""Você é um assistente de pesquisa clínica em psicologia.

CONTEXTO CLÍNICO DA SESSÃO:
{contexto_clinico[:1500]}

ARTIGOS CANDIDATOS:
{chr(10).join(linhas)}

Selecione até {MAX_ARTIGOS_TOTAL} artigos MAIS RELEVANTES para o contexto clínico acima.
Critérios: relação direta com o problema clínico central da sessão, com as intervenções realizadas ou com a evolução do caso; utilidade prática para o profissional.
Descarte artigos genéricos ou apenas tangenciais - é melhor indicar menos artigos do que artigos fora do tema.

Responda apenas com JSON puro (sem markdown):
{{"selecionados": [{{"indice": 1, "justificativa": "1 frase curta explicando a relevância clínica para esta sessão"}}]}}
Se nenhum candidato for relevante, retorne {{"selecionados": []}}."""

    resultado = _chamar_llm_json(_get_provider(), prompt, temperature=0.1)
    if not isinstance(resultado, dict) or "selecionados" not in resultado:
        return sem_justificativa

    selecionados = []
    for sel in resultado.get("selecionados", [])[:MAX_ARTIGOS_TOTAL]:
        if not isinstance(sel, dict):
            continue
        try:
            idx = int(sel.get("indice", 0))
        except (TypeError, ValueError):
            continue
        if 1 <= idx <= len(candidatos):
            selecionados.append({
                **candidatos[idx - 1],
                "justificativa": str(sel.get("justificativa", "")).strip(),
            })
    return selecionados


def _formatar_artigos(artigos: list) -> str:
    linhas = []
    for i, art in enumerate(artigos[:MAX_ARTIGOS_TOTAL], 1):
        extras = []
        if art.get("ano"):
            extras.append(str(art["ano"]))
        if art.get("citacoes"):
            extras.append(f"{art['citacoes']} citações")
        sufixo = f" ({', '.join(extras)})" if extras else ""

        linha = f"{i}. {art['titulo']}{sufixo}"
        if art.get("autores"):
            linha += f" - {art['autores']}"
        linhas.append(linha)
        if art.get("justificativa"):
            linhas.append(f"   Relevância: {art['justificativa']}")
        linhas.append(f"   {art['link']}")
    return "\n".join(linhas)


def _montar_artigos(temas_pesquisa: list, contexto_clinico: str = "") -> str:
    temas = _normalizar_temas(temas_pesquisa)
    if not temas:
        return ""

    candidatos = []
    chaves_vistas = set()
    for especifico, amplo in temas:
        for c in _buscar_candidatos_tema(especifico, amplo):
            chave = c.get("id") or c["link"]
            if chave in chaves_vistas:
                continue
            chaves_vistas.add(chave)
            candidatos.append(c)

    temas_fallback = [especifico or amplo for especifico, amplo in temas]
    if not candidatos:
        return _montar_artigos_sugeridos(temas_fallback)

    selecionados = _rerankear_artigos(candidatos, contexto_clinico)
    if not selecionados:
        return _montar_artigos_sugeridos(temas_fallback)

    return _formatar_artigos(selecionados)


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
        return os.getenv("IA_MODEL", "gpt-4o-mini")
    if provider == "deepseek":
        return "deepseek-v4-flash"
    return os.getenv("IA_MODEL", "gemini-2.0-flash")


def _gemini_client():
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        return None
    return genai.Client(
        api_key=api_key,
        http_options=types.HttpOptions(timeout=120000),
    )


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
    nome = _sanitizar_prompt(nome_pessoa_atendida or "não informado")
    tema = _sanitizar_prompt(tema_principal or "não informado")
    material = _sanitizar_prompt(material_base)

    return f"""
{PROMPT_UNIVERSAL}

{prompt_abordagem}

--- DADOS DA SESSÃO ---
Número da sessão: {numero_sessao}
{termo.capitalize()}: {nome}
Tema principal informado: {tema}

--- MATERIAL CLÍNICO ---
{material}

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
    "temas_pesquisa": [
        {{"especifico": "expressão de busca específica", "amplo": "expressão de busca ampla"}},
        {{"especifico": "expressão de busca específica", "amplo": "expressão de busca ampla"}}
    ]
}} 

TEMAS DE PESQUISA CIENTÍFICA:
No campo "temas_pesquisa", extraia exatamente 2 temas de busca científica a partir do conteúdo clínico da sessão. Para cada tema, forneça duas versões:
- "especifico": expressão de busca específica (4 a 6 palavras) combinando o problema clínico central com contexto, população ou intervenção. Ex: "terapia cognitiva ansiedade social adultos".
- "amplo": versão reduzida da mesma busca (2 a 3 palavras), para uso como alternativa caso a específica não retorne resultados. Ex: "ansiedade social".
Critérios:
1. O primeiro tema deve focar no problema clínico central da sessão; o segundo pode combinar outro tema relevante da sessão com a abordagem {abordagem_clinica}.
2. Use termos consagrados na literatura científica em português, como seriam digitados em uma base de dados científica.
3. NÃO inclua o nome do {termo} nem qualquer dado que identifique a pessoa atendida.
4. NÃO invente títulos de artigos nem links - apenas expressões de busca.
5. Se o material clínico for insuficiente, retorne lista vazia.

IMPORTANTE:
- Use o termo "{termo}" para se referir à pessoa atendida
- Todo o texto deve estar em português
- Seja específico(a) com base no material clínico fornecIDo, não genérico(a)
- Campos vazios devem vir como string vazia ""
"""


def _parse_resultado_sucesso(resultado_raw: dict) -> dict:
    contexto_clinico = " ".join(
        texto
        for texto in [
            resultado_raw.get("relato_clinico_organizado", ""),
            resultado_raw.get("eventos_importantes", ""),
        ]
        if texto
    )
    temas_pesquisa = resultado_raw.get("temas_pesquisa", [])
    artigos_sugeridos = ""

    if temas_pesquisa:
        try:
            with ThreadPoolExecutor(max_workers=1) as executor:
                future = executor.submit(_montar_artigos, temas_pesquisa, contexto_clinico)
                artigos_sugeridos = future.result(timeout=8)
        except FutureTimeoutError:
            log.warning("Busca de artigos excedeu timeout (8s) - retornando sem artigos")
        except Exception as e:
            log.warning("Falha ao buscar artigos (nao-critico): %s", e)

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
        "artigos_sugeridos": artigos_sugeridos,
        "erro": "",
    }


def _chamar_provider_sintese(provider_name: str, prompt: str) -> dict:
    log.info("Sintese via provider: %s", provider_name)
    if provider_name == "openai":
        return _gerar_sintese_openai(prompt)
    elif provider_name == "deepseek":
        return _gerar_sintese_deepseek(prompt)
    elif provider_name == "gemini":
        return _gerar_sintese_gemini(prompt)
    else:
        return {"sucesso": False, "erro": f"Provedor desconhecido: {provider_name}. Use 'openai', 'deepseek' ou 'gemini'."}


def _gerar_sintese_gemini(prompt: str) -> dict:
    client = _gemini_client()
    if not client:
        log.warning("Gemini nao configurado para sintese")
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

        log.info("Gemini sintese concluida com sucesso")
        resultado = json.loads(conteudo)
        return _parse_resultado_sucesso(resultado)

    except json.JSONDecodeError as e:
        log.warning("Gemini sintese JSON invalido: %s", e)
        return {"sucesso": False, "erro": "Resposta da IA não pôde ser interpretada. Tente novamente."}
    except Exception as e:
        log.error("Gemini erro na sintese: %s", e)
        return {"sucesso": False, "erro": f"Erro ao gerar síntese clínica: {str(e)}"}


def _gerar_sintese_openai(prompt: str) -> dict:
    client = _openai_client()
    if not client:
        log.warning("OpenAI nao configurado para sintese")
        return {"sucesso": False, "erro": "OPENAI_API_KEY não configurada."}
    return _gerar_sintese_openai_compat(client, prompt)


def _gerar_sintese_deepseek(prompt: str) -> dict:
    api_key = os.getenv("DEEPSEEK_API_KEY")
    if not api_key:
        log.warning("DeepSeek nao configurado para sintese")
        return {"sucesso": False, "erro": "DEEPSEEK_API_KEY não configurada."}

    model = _get_model_name()

    if len(prompt) > 200000:
        return {"sucesso": False, "erro": "Material clínico muito extenso para o provedor DeepSeek (limite ~64K tokens). Tente com OpenAI ou reduza o relato."}

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
                        "content": "Você é um assistente clínico especializado em psicologia. IMPORTANTE: Responda APENAS com JSON puro e válido, sem markdown, sem texto antes ou depois das chaves. Nenhum outro formato é aceito.",
                    },
                    {"role": "user", "content": prompt},
                ],
                "temperature": 0.3,
            },
            timeout=120,
        )

        if resp.status_code != 200:
            log.error("DeepSeek sintese retornou %d: %s", resp.status_code, resp.text[:500])
            return {
                "sucesso": False,
                "erro": f"DeepSeek retornou {resp.status_code}: {resp.text[:500]}",
            }

        data = resp.json()
        conteudo = data["choices"][0]["message"]["content"]

        if not conteudo:
            return {"sucesso": False, "erro": "Resposta vazia da IA."}

        log.info("DeepSeek sintese concluida com sucesso")
        resultado = json.loads(conteudo)
        return _parse_resultado_sucesso(resultado)

    except json.JSONDecodeError as e:
        log.warning("DeepSeek sintese JSON invalido: %s", e)
        return {"sucesso": False, "erro": "Resposta da IA não pôde ser interpretada. Tente novamente."}
    except Exception as e:
        log.error("DeepSeek erro na sintese: %s", e)
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
            timeout=60,
        )

        conteudo = response.choices[0].message.content
        if not conteudo:
            return {"sucesso": False, "erro": "Resposta vazia da IA."}

        log.info("OpenAI sintese concluida com sucesso")
        resultado = json.loads(conteudo)
        return _parse_resultado_sucesso(resultado)

    except json.JSONDecodeError as e:
        log.warning("OpenAI sintese JSON invalido: %s", e)
        return {"sucesso": False, "erro": "Resposta da IA não pôde ser interpretada. Tente novamente."}
    except Exception as e:
        log.error("OpenAI erro na sintese: %s", e)
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
            log.warning("Sintese abortada: sem material clinico")
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
        log.info(
            "Gerando sintese - provider=%s modelo=%s sessao=%d",
            provider,
            _get_model_name(),
            numero_sessao,
        )
        return _chamar_provider_sintese(provider, prompt)

    except Exception as e:
        log.exception("Erro inesperado ao gerar sintese: %s", e)
        return {"sucesso": False, "erro": f"Erro ao gerar síntese clínica: {str(e)}"}


def gerar_progresso(
    paciente_id: str,
    numero_sessao: int,
    sessoes_anteriores: list,
    sessao_atual: dict,
    objetivos_terapeuticos: str = "",
    queixa_principal: str = "",
    escalas: list = None,
) -> dict:
    if escalas is None:
        escalas = []

    historico = ""
    for s in sessoes_anteriores:
        historico += f"Sessão {s.get('numero')} ({s.get('data', '')}):\n{s.get('sintese', '')}\n\n"

    dados_escalas = ""
    if escalas:
        for e in escalas:
            nome = e.get("nome", "")
            dados_escalas += f"- {nome}:\n"
            for d in e.get("datas", []):
                dados_escalas += f"  {d.get('data', '')}: {d.get('pontuacao', '?')} pontos ({d.get('interpretacao', '')})\n"

    prompt = f"""{PROMPT_PROGRESSO}

DADOS DO PACIENTE:
Queixa principal: {queixa_principal or 'Nao informada'}
Objetivos terapeuticos: {objetivos_terapeuticos or 'Nao informados'}

{"QUESTIONARIOS APLICADOS:" if escalas else ""}
{dados_escalas}

SESSOES ANTERIORES:
{historico}

SESSAO ATUAL (numero {numero_sessao}, {sessao_atual.get('data', '')}):
{sessao_atual.get('sintese', '')}
Relato: {sessao_atual.get('relato', '')}
Intervencoes: {sessao_atual.get('intervencoes', '')}

Retorne um JSON com o seguinte formato:
{{
    "sintomas": [
        {{"nome": "...", "intensidade": 7, "tendencia": "piora", "evidencia": "..."}}
    ],
    "metas": [
        {{"descricao": "...", "progresso": 0.3, "status": "inicio"}}
    ],
    "avaliacao_geral": "...",
    "tendencia": "mista",
    "recomendacoes": "..."
}}"""

    try:
        provider = _get_provider()
        log.info("gerar_progresso: provider=%s sessao=%d", provider, numero_sessao)
        return _chamar_llm_json(provider, prompt, temperature=0.3)
    except Exception as e:
        log.exception("Erro ao gerar progresso: %s", e)
        return {"sucesso": False, "erro": f"Erro ao gerar progresso: {str(e)}"}


def _chamar_llm_json(provider: str, prompt: str, temperature: float = 0.3) -> dict:
    if provider == "openai":
        return _chamar_llm_json_openai(prompt, temperature)
    elif provider == "deepseek":
        return _chamar_llm_json_deepseek(prompt, temperature)
    elif provider == "gemini":
        return _chamar_llm_json_gemini(prompt, temperature)
    return {"sucesso": False, "erro": f"Provedor desconhecido: {provider}"}


def _chamar_llm_json_openai(prompt: str, temperature: float) -> dict:
    client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
    try:
        response = client.chat.completions.create(
            model=_get_model_name(),
            messages=[{"role": "user", "content": prompt}],
            response_format={"type": "json_object"},
            timeout=120,
            temperature=temperature,
        )
        return json.loads(response.choices[0].message.content)
    except Exception as e:
        log.exception("OpenAI JSON error: %s", e)
        return {"sucesso": False, "erro": str(e)}


def _chamar_llm_json_deepseek(prompt: str, temperature: float) -> dict:
    client = OpenAI(
        api_key=os.getenv("DEEPSEEK_API_KEY"),
        base_url="https://api.deepseek.com/v1",
    )
    try:
        response = client.chat.completions.create(
            model="deepseek-v4-flash",
            messages=[{"role": "user", "content": prompt}],
            timeout=120,
            temperature=temperature,
        )
        content = response.choices[0].message.content.strip()
        if content.startswith("```json"):
            content = content[7:]
        if content.endswith("```"):
            content = content[:-3]
        return json.loads(content)
    except Exception as e:
        log.exception("DeepSeek JSON error: %s", e)
        return {"sucesso": False, "erro": str(e)}


def _chamar_llm_json_gemini(prompt: str, temperature: float) -> dict:
    client = genai.Client(
        api_key=os.getenv("GEMINI_API_KEY"),
        http_options=types.HttpOptions(timeout=120000),
    )
    try:
        response = client.models.generate_content(
            model="gemini-2.0-flash",
            contents=prompt,
            config=types.GenerateContentConfig(
                temperature=temperature,
                response_mime_type="application/json",
            ),
        )
        return json.loads(response.text)
    except Exception as e:
        log.exception("Gemini JSON error: %s", e)
        return {"sucesso": False, "erro": str(e)}

