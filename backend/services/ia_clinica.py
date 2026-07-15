import json
import os
import re
import xml.etree.ElementTree as ET
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

SCIELO_RSS_URL = "https://search.scielo.org/"
SCIELO_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
    "Accept": "application/rss+xml, application/xml, text/xml, */*",
    "Accept-Language": "pt-BR,pt;q=0.9",
}
MAX_ARTIGOS_TOTAL = 3
MAX_CANDIDATOS_POR_TEMA = 5
OPENALEX_FILTROS_BASE = "language:pt,type:article,from_publication_date:2010-01-01"
OPENALEX_FILTRO_PSICOLOGIA = "primary_topic.field.id:fields/32"


def _openalex_params(params: dict) -> dict:
    api_key = os.getenv("OPENALEX_API_KEY", "").strip()
    if api_key:
        params["api_key"] = api_key
    mailto = os.getenv("OPENALEX_MAILTO", "").strip()
    if mailto:
        params["mailto"] = mailto
    return params


def _extrair_pid_scielo(link: str) -> str:
    ultimo = link.rstrip("/").rsplit("/", 1)[-1]
    return ultimo.rsplit("-", 1)[0] if "-" in ultimo else ultimo


def _formatar_autores(autores_raw: str) -> str:
    autores = [a.strip() for a in (autores_raw or "").split(";") if a.strip()]
    if not autores:
        return ""
    if len(autores) > 3:
        return "; ".join(autores[:3]) + " et al."
    return "; ".join(autores)


def _limpar_html(texto: str) -> str:
    return re.sub(r"<[^>]+>", " ", texto or "").replace("\xa0", " ").strip()


def _reconstruir_resumo_openalex(inverted_index: dict) -> str:
    if not inverted_index:
        return ""
    posicoes = []
    for palavra, indices in inverted_index.items():
        for i in indices:
            posicoes.append((i, palavra))
    posicoes.sort()
    return " ".join(palavra for _, palavra in posicoes)[:400]


def _buscar_candidatos_scielo(consulta: str) -> list:
    try:
        resp = requests.get(
            SCIELO_RSS_URL,
            params={
                "q": consulta,
                "lang": "pt",
                "output": "rss",
                "count": 10,
                "sort": "RELEVANCE",
                "filter[la][]": "pt",
            },
            headers=SCIELO_HEADERS,
            timeout=10,
        )
        if resp.status_code != 200:
            return []

        root = ET.fromstring(resp.content)
        candidatos = []
        pids_vistos = set()
        for item in root.iter("item"):
            if len(candidatos) >= MAX_CANDIDATOS_POR_TEMA:
                break

            titulo = (item.findtext("title") or "").strip()
            link = (item.findtext("link") or "").strip()
            if not titulo or not link:
                continue

            pid = _extrair_pid_scielo(link)
            if pid in pids_vistos:
                continue
            pids_vistos.add(pid)

            candidatos.append({
                "id": pid,
                "titulo": titulo.split(" / ")[0].strip(),
                "autores": _formatar_autores(item.findtext("author") or ""),
                "link": link,
                "ano": None,
                "citacoes": None,
                "resumo": _limpar_html(item.findtext("description") or "")[:400],
            })
        return candidatos

    except Exception:
        return []


def diagnosticar_busca_artigos(especifico: str, amplo: str) -> dict:
    diagnostico = {"consultas": []}
    for consulta in [c for c in dict.fromkeys([especifico, amplo]) if c.strip()]:
        info = {"consulta": consulta, "openalex": [], "scielo": {}}
        consulta_limpa = consulta.replace(",", " ").replace(":", " ").strip()
        filtros = (
            f"title_and_abstract.search:{consulta_limpa},{OPENALEX_FILTROS_BASE},{OPENALEX_FILTRO_PSICOLOGIA}",
            f"title_and_abstract.search:{consulta_limpa},{OPENALEX_FILTROS_BASE}",
        )
        for filtro in filtros:
            tentativa = {"filtro": filtro}
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
                tentativa["status"] = resp.status_code
                if resp.status_code == 200:
                    data = resp.json()
                    tentativa["total"] = data.get("meta", {}).get("count")
                    tentativa["titulos"] = [
                        (w.get("title") or "")[:100] for w in data.get("results", [])
                    ]
                else:
                    tentativa["body"] = resp.text[:300]
            except Exception as e:
                tentativa["erro"] = f"{type(e).__name__}: {str(e)[:200]}"
            info["openalex"].append(tentativa)

        try:
            resp = requests.get(
                SCIELO_RSS_URL,
                params={
                    "q": consulta,
                    "lang": "pt",
                    "output": "rss",
                    "count": 10,
                    "sort": "RELEVANCE",
                    "filter[la][]": "pt",
                },
                headers=SCIELO_HEADERS,
                timeout=10,
            )
            info["scielo"]["status"] = resp.status_code
            if resp.status_code == 200:
                root = ET.fromstring(resp.content)
                info["scielo"]["titulos"] = [
                    (item.findtext("title") or "")[:100] for item in root.iter("item")
                ][:5]
            else:
                info["scielo"]["body"] = resp.text[:200]
        except Exception as e:
            info["scielo"]["erro"] = f"{type(e).__name__}: {str(e)[:200]}"

        diagnostico["consultas"].append(info)
    return diagnostico


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

        except Exception:
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
        if not achados:
            achados = _buscar_candidatos_scielo(consulta)
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
            cabecalho += f" — {c['autores']}"
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
Descarte artigos genéricos ou apenas tangenciais — é melhor indicar menos artigos do que artigos fora do tema.

Responda apenas com JSON puro (sem markdown):
{{"selecionados": [{{"indice": 1, "justificativa": "1 frase curta explicando a relevância clínica para esta sessão"}}]}}
Se nenhum candidato for relevante, retorne {{"selecionados": []}}."""

    resultado = _chamar_llm_json(prompt)
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
            linha += f" — {art['autores']}"
        linhas.append(linha)
        if art.get("justificativa"):
            linhas.append(f"   Relevância: {art['justificativa']}")
        linhas.append(f"   Acesse: {art['link']}")
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


def _chamar_llm_json(prompt: str) -> dict | None:
    system = "Você é um assistente de pesquisa clínica em psicologia. Gere JSON válido sem markdown."
    provider = _get_provider()
    try:
        if provider == "deepseek":
            api_key = os.getenv("DEEPSEEK_API_KEY")
            if not api_key:
                return None
            resp = requests.post(
                "https://api.deepseek.com/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": _get_model_name(),
                    "messages": [
                        {"role": "system", "content": system},
                        {"role": "user", "content": prompt},
                    ],
                    "response_format": {"type": "json_object"},
                    "temperature": 0.1,
                },
                timeout=60,
            )
            if resp.status_code != 200:
                return None
            return json.loads(resp.json()["choices"][0]["message"]["content"])

        if provider == "openai":
            client = _openai_client()
            if not client:
                return None
            response = client.chat.completions.create(
                model=_get_model_name(),
                messages=[
                    {"role": "system", "content": system},
                    {"role": "user", "content": prompt},
                ],
                response_format={"type": "json_object"},
                temperature=0.1,
            )
            return json.loads(response.choices[0].message.content or "")

        if provider == "gemini":
            client = _gemini_client()
            if not client:
                return None
            response = client.models.generate_content(
                model=_get_model_name(),
                contents=f"{system}\n\n{prompt}",
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                ),
            )
            return json.loads(response.text or "")

    except Exception:
        return None

    return None


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
4. NÃO invente títulos de artigos nem links — apenas expressões de busca.
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
        "artigos_sugeridos": _montar_artigos(
            resultado_raw.get("temas_pesquisa", []),
            contexto_clinico,
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
