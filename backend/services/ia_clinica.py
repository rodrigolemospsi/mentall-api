import json
import logging
import os
import re
import threading
import time
from urllib.parse import quote_plus

import requests
from google import genai
from google.genai import types
from openai import OpenAI

from prompts.abordagens import PROMPTS_ABORDAGEM, PROMPT_UNIVERSAL, PROMPT_PROGRESSO, obter_prompt_abordagem

log = logging.getLogger("mentall.ia_clinica")

TERMOS_PESSOA_ATENDIDA = {"paciente", "cliente", "pessoa atendida"}

BASES_PESQUISA = [
    ("SciELO", "https://search.scielo.org/?q={consulta}&lang=pt"),
    ("Periódicos CAPES", "https://www.periodicos.capes.gov.br/index.php/acervo/buscador.html?q={consulta}"),
    ("Oasisbr", "https://oasisbr.ibict.br/vufind/Search/Results?lookfor={consulta}&type=AllFields"),
]

MAX_ARTIGOS_TOTAL = 3
MAX_CANDIDATOS_POR_TEMA = 5
MAX_PROMPT_CHARS = 50000
INJECAO_PADROES = [
    r"(?i)ignore\s+(?:all|the|any|these|those)?\s*(?:previous|prior|above|earlier|other|given)?\s*instructions?",
    r"(?i)forget\s+(?:all|the|any)?\s*(?:previous|prior|above|earlier|other)?\s*instructions?",
    r"(?i)ignore\s+everything\s+(above|before|previously|you\s+sent)",
    r"(?i)disregard\s+(all\s+)?(previous|prior|above|earlier)?\s*instructions?",
    r"(?i)(ignore|disregard|forget)\s+(?:the|your|my)?\s*system\s*prompt",
    r"(?i)(output|reveal|print|show|repeat|return|display)\s+(?:the|your|my)?\s*(?:full\s+)?system\s*prompt",
    r"(?i)(answer|respond|act|behave|reply)\s+as\s+(an?\s+|the\s+)?(unrestricted|generic|general|powerful|regular|new|different)\s+(assistant|bot|ai|chatbot|model)",
    r"(?i)you\s+are\s+now\s+[^.\n]*(assistant|bot|ai|chatbot|model)",
    r"(?i)system\s*prompt\s*:",
    r"(?i)new\s+instructions?\s*:",
    r"(?i)override\s+(your|the)\s+(system\s+)?prompt",
]
OPENALEX_FILTROS_BASE = "language:pt,type:article,from_publication_date:2010-01-01"
OPENALEX_FILTRO_PSICOLOGIA = "primary_topic.field.id:fields/32"
OPENALEX_FILTRO_PERIODICO = "primary_location.source.type:journal"


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


def _buscar_candidatos_openalex(consulta: str) -> list:
    consulta_limpa = consulta.replace(",", " ").replace(":", " ").strip()
    # Cascata, do mais restrito ao mais amplo: periodico de psicologia ->
    # psicologia -> qualquer area. O filtro de periodico tira repositorio e
    # agregador, que dominavam o topo (medido em 06/10/2026); se ele zerar a
    # consulta, caimos para o proximo em vez de nao devolver nada.
    filtros = (
        (
            f"title_and_abstract.search:{consulta_limpa},{OPENALEX_FILTROS_BASE},"
            f"{OPENALEX_FILTRO_PSICOLOGIA},{OPENALEX_FILTRO_PERIODICO}"
        ),
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
                    # Metadado ATRIBUÍDO pela base (descritores indexados). Já vem
                    # no payload — não custa chamada extra — e é o que permite
                    # separar artigo de TRATAMENTO de artigo de INSTRUMENTO.
                    "keywords": [
                        (k or {}).get("display_name", "")
                        for k in (work.get("keywords") or [])
                    ],
                    "palavras_resumo": " ".join(
                        (work.get("abstract_inverted_index") or {}).keys()
                    ),
                })

            if candidatos:
                return candidatos

        except Exception as e:
            log.warning("OpenAlex falhou para filtro: %s", e)
            continue

    return []


MAX_DESCRITORES = 3

# Siglas que são homônimos na literatura brasileira. "TCC", sozinho, traz
# majoritariamente "Trabalho de Conclusão de Curso" (medido: 644 resultados, o
# primeiro sobre serious games). Ver AGENTS.md (07/10/2026).
_EXPANSOES_SIGLAS = {
    "tcc": "terapia cognitivo-comportamental",
    "act": "terapia de aceitação e compromisso",
    "dbt": "terapia comportamental dialética",
}

SINAL_TRATAMENTO_PADRAO = (
    "therapy,therapist,treatment,intervention,interventions,psychotherapy,efficacy,"
    "effectiveness,randomized,randomised,clinical trial,outcome,cbt,cognitive behavioral,"
    "cognitive behavioural,mindfulness,counseling,counselling,rehabilitation,management,care"
)


def _marcas_tratamento() -> tuple:
    """Termos que indicam artigo de TRATAMENTO (e não de instrumento/psicometria).

    Configurável por `IA_ARTIGOS_SINAL_TRATAMENTO` (lista separada por vírgula),
    para o dono ajustar o vocabulário sem depender de deploy.
    """
    bruto = os.getenv("IA_ARTIGOS_SINAL_TRATAMENTO", SINAL_TRATAMENTO_PADRAO)
    marcas = tuple(m.strip().lower() for m in bruto.split(",") if m.strip())
    if marcas:
        return marcas
    return tuple(m.strip().lower() for m in SINAL_TRATAMENTO_PADRAO.split(",") if m.strip())


def _tem_sinal_tratamento(candidato: dict) -> bool:
    """True se o metadado ATRIBUÍDO ao artigo indica tratamento/intervenção.

    Olha as `keywords` (descritores indexados pela base) e, quando não houver,
    as palavras do resumo — os dois já vêm no payload, sem custo extra.
    """
    texto = " ; ".join(
        [str(k).lower() for k in (candidato.get("keywords") or [])]
        + [str(candidato.get("palavras_resumo") or "").lower()]
    )
    return any(m in texto for m in _marcas_tratamento())


def _normalizar_temas(temas_pesquisa: list) -> list:
    """Descritores de busca, na ordem devolvida pelo modelo — UM conceito cada.

    Ordem esperada: 1) abordagem clínica, 2) tema central da sessão,
    3) contexto da pessoa atendida (quando houver). Siglas homônimas são
    expandidas (ver `_EXPANSOES_SIGLAS`).
    """
    descritores = []
    for item in (temas_pesquisa or [])[:MAX_DESCRITORES]:
        if isinstance(item, dict):
            valor = str(item.get("especifico", "")).strip() or str(item.get("amplo", "")).strip()
        else:
            valor = str(item).strip()
        valor = _EXPANSOES_SIGLAS.get(valor.lower(), valor)
        if valor:
            descritores.append(valor)
    return descritores


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
        linhas.append(f"   {art['link']}")
    return "\n".join(linhas)


def _montar_artigos(temas_pesquisa: list) -> str:
    """Busca por PARES de descritores e filtra pelo metadado indexado.

    Três medições de 07/10/2026 moldam este desenho (ver AGENTS.md):
    - combinar 3+ conceitos numa consulta retorna ZERO (a base faz "E" entre
      as palavras) — por isso os descritores têm um conceito cada e a busca usa
      pares;
    - um "OU" global faz o descritor mais genérico dominar o resultado (99% dos
      artigos vinham só dele) — por isso não há OU, e sim pontuação por par;
    - o termo amplo traz homônimos ("Inventário de Depressão Maior") — por isso o
      crivo por metadado antes de apresentar.
    """
    descritores = _normalizar_temas(temas_pesquisa)
    if not descritores:
        return ""

    pares = [(descritores[0], descritores[1] if len(descritores) > 1 else "")]
    if len(descritores) >= 3:
        pares.append((descritores[0], descritores[2]))
        pares.append((descritores[1], descritores[2]))

    pontuados = {}
    for posicao, (a, b) in enumerate(pares):
        consulta = " ".join(p for p in (a, b) if p).strip()
        if not consulta:
            continue
        for c in _buscar_candidatos_openalex(consulta):
            chave = c.get("id") or c["link"]
            registro = pontuados.setdefault(chave, {"cand": c, "pares": 0, "peso": 0.0})
            registro["pares"] += 1
            registro["peso"] += 1.0 / (posicao + 1)

    if not pontuados:
        return _montar_artigos_sugeridos(descritores)

    aprovados = [r for r in pontuados.values() if _tem_sinal_tratamento(r["cand"])]
    if not aprovados:
        log.info(
            "Artigos: %d candidatos, nenhum com sinal de tratamento; "
            "mostrando buscas sugeridas em vez de artigo fora do tema.",
            len(pontuados),
        )
        return _montar_artigos_sugeridos(descritores)

    # Quem casa mais descritores primeiro; o peso desempata (o par
    # abordagem+tema vale mais que os pares com o contexto).
    aprovados.sort(key=lambda r: (-r["pares"], -r["peso"]))
    return _formatar_artigos([r["cand"] for r in aprovados])


def _montar_artigos_sugeridos(temas_pesquisa: list) -> str:
    """Fallback determinístico: links de busca reais por tema (sem inventar artigos).

    Usa rótulo 'Busca sugerida:' (e não um título numerado) para deixar claro ao
    profissional que são buscas, não artigos — evita parecer artigo inventado."""
    temas_validos = [
        str(t).strip() for t in (temas_pesquisa or []) if str(t).strip()
    ][:MAX_DESCRITORES]
    if not temas_validos:
        return ""

    blocos = []
    for i, tema in enumerate(temas_validos, 1):
        consulta = quote_plus(tema)
        linhas = [f"Busca sugerida {i}: {tema.capitalize()}"]
        for nome_base, url_template in BASES_PESQUISA:
            linhas.append(f"   {nome_base}: {url_template.format(consulta=consulta)}")
        blocos.append("\n".join(linhas))

    return "\n".join(blocos)


def _get_provider() -> str:
    return os.getenv("IA_MODEL_PROVIDER", "openai").strip().lower()


PROVEDORES_DISPONIVEIS = ("openai", "deepseek")
ORDEM_PROVEDORES_PADRAO = "openai,deepseek"


def _ordem_providers() -> list[str]:
    """Ordem de tentativa dos provedores de texto, do primeiro ao último.

    O **Gemini saiu da cascata em 07/10/2026**: a API devolvia 503 em toda a
    familia Flash (medido, de duas redes diferentes) e o unico modelo que
    respondia (3.1-flash-lite) falhou 1 de 2 vezes e entregou o menor conteudo.
    Ver AGENTS.md (secao 07/10/2026).

    Configuravel por `IA_PROVIDER_ORDER` (ex.: "deepseek,openai") — a ordem muda
    por secret, sem deploy. Nomes desconhecidos sao descartados: assim o Gemini
    nao volta por engano ao mexer no secret.
    """
    bruto = os.getenv("IA_PROVIDER_ORDER", ORDEM_PROVEDORES_PADRAO)
    ordem = [p.strip().lower() for p in bruto.split(",") if p.strip()]
    validos = [p for p in ordem if p in PROVEDORES_DISPONIVEIS]
    if not validos:
        log.warning(
            "IA_PROVIDER_ORDER invalido (%r); usando o padrao %r",
            bruto, ORDEM_PROVEDORES_PADRAO,
        )
        return list(PROVEDORES_DISPONIVEIS)
    return validos


# ── Circuito por provedor ───────────────────────────────────────────────────
# Um provedor que acabou de falhar nao deve ser tentado de novo na chamada
# seguinte. Em 07/10/2026 a cascata tentava o Gemini a cada sintese, pagando o
# 503 de novo, porque nao lembrava da falha anterior (ver AGENTS.md).
#
# Estado NA MEMORIA DO PROCESSO: correto enquanto houver uma maquina so. Se um
# dia houver mais de uma instancia, cada uma teria seu proprio circuito.
CIRCUITO_HARD_SEGUNDOS = 1200   # cota, chave invalida, modelo inexistente
CIRCUITO_SOFT_SEGUNDOS = 180    # 503, timeout, instabilidade momentanea
CIRCUITO_SOFT_FALHAS = 2        # quantas falhas transitorias abrem o circuito

_estado_provedores: dict[str, dict] = {}
_lock_provedores = threading.Lock()

_MARCADORES_FALHA_DURA = (
    "insufficient_quota", "credit_balance", "no credits",
    "invalid_api_key", "incorrect api key", "authentication",
    "model_not_found", "does not have access", "permission",
)


def _falha_dura(erro: str) -> bool:
    """Falha que nao melhora repetindo: cota, chave, modelo ou permissao."""
    texto = (erro or "").lower()
    return any(m in texto for m in _MARCADORES_FALHA_DURA)


def _registrar_falha(provider: str, erro: str) -> None:
    dura = _falha_dura(erro)
    with _lock_provedores:
        anterior = _estado_provedores.get(provider, {})
        _estado_provedores[provider] = {
            "falhas": int(anterior.get("falhas", 0)) + 1,
            "quando": time.time(),
            "dura": dura,
        }
    log.warning(
        "Circuito: %s falhou (%s); nao sera tentado pelos proximos %ds.",
        provider,
        "falha dura" if dura else "falha transitoria",
        CIRCUITO_HARD_SEGUNDOS if dura else CIRCUITO_SOFT_SEGUNDOS,
    )


def _registrar_sucesso(provider: str) -> None:
    with _lock_provedores:
        _estado_provedores.pop(provider, None)


def _provedor_disponivel(provider: str) -> bool:
    with _lock_provedores:
        estado = _estado_provedores.get(provider)
    if not estado:
        return True
    desde = time.time() - estado["quando"]
    if estado.get("dura"):
        return desde > CIRCUITO_HARD_SEGUNDOS
    if int(estado.get("falhas", 0)) < CIRCUITO_SOFT_FALHAS:
        return True
    return desde > CIRCUITO_SOFT_SEGUNDOS


def _provedores_a_tentar() -> list[str]:
    """Ordem configurada, pulando os provedores com o circuito aberto."""
    ordem = _ordem_providers()
    disponiveis = [p for p in ordem if _provedor_disponivel(p)]
    pulados = [p for p in ordem if p not in disponiveis]
    if pulados:
        log.info("Circuito aberto: pulando %s", ", ".join(pulados))
    if not disponiveis:
        # Todos abertos: vale UMA tentativa no primeiro da ordem, para o estado
        # poder se recuperar em vez de falhar de imediato.
        return ordem[:1]
    return disponiveis


def _limpar_estado_provedores() -> None:
    """Zera o circuito (usado pelos testes)."""
    with _lock_provedores:
        _estado_provedores.clear()


def _get_model_name(provider: str | None = None) -> str:
    provider = (provider or _get_provider()).strip().lower()
    if provider == "openai":
        return os.getenv("IA_MODEL", "gpt-4o-mini")
    if provider == "deepseek":
        return "deepseek-v4-flash"
    return os.getenv("GEMINI_MODEL", "gemini-3.7-flash")


def _gemini_client():
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        return None
    return genai.Client(
        api_key=api_key,
        http_options=types.HttpOptions(timeout=45000),
    )


def _openai_client():
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        return None
    return OpenAI(
        api_key=api_key,
        project=os.getenv("OPENAI_PROJECT_ID"),
        timeout=120.0,
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
    termo = (termo_pessoa_atendida or "paciente").strip().lower()
    if termo not in TERMOS_PESSOA_ATENDIDA:
        termo = "paciente"
    if abordagem_clinica in PROMPTS_ABORDAGEM:
        abordagem = abordagem_clinica
    else:
        abordagem = "Integrativa"
    nome = _sanitizar_prompt(nome_pessoa_atendida or "não informado")
    material = _sanitizar_prompt(material_base)

    if tema_principal and tema_principal.strip():
        linha_tema = f"Tema principal informado: {_sanitizar_prompt(tema_principal)}"
    else:
        linha_tema = "Tema principal: identificar a partir do material clínico e usar para orientar toda a síntese."

    return f"""
{PROMPT_UNIVERSAL}

{prompt_abordagem}

--- DADOS DA SESSÃO ---
Número da sessão: {numero_sessao}
{termo.capitalize()}: {nome}
{linha_tema}

--- MATERIAL CLÍNICO ---
{material}

--- INSTRUÇÕES ---
Com base no material acima, gere um JSON válido com a seguinte estrutura (sem markdown, sem ```json, apenas o JSON puro):
{{
    "relato_clinico_organizado": "Síntese clínica organizada em texto corrido, com estilo profissional, pronta para compor o prontuário. Deve incluir: contexto trazido pelo {termo}, temas trabalhados, intervenções realizadas, evolução observada e encaminhamentos/foco. Escreva de forma coesa, como se fosse um relato clínico completo.",
    "apontamentos_copiloto": "Apontamentos do Copiloto para revisão profissional. Tópicos com observações clínicas, hipóteses a investigar, padrões identificados e sugestões de foco. Use marcas de atenção como 'Pode indicar...', 'Sugere-se investigar...', 'Hipótese clínica...'",
    "sintese_clinica": "Síntese clínica combinada: eventos ou conteúdos centrais trazidos na sessão, avaliação da evolução do {termo} em relação a sessões anteriores (se aplicável) e observações relevantes para o prontuário (dados contextuais, cuidados éticos, riscos, potencialidades).",
    "formulacao_clinica": "Formulação clínica combinada, compatível com a abordagem {abordagem}: pensamentos ou cognições, emoções ou afetos e comportamentos relevantes mencionados ou observados.",
    "intervencoes": "Intervenções realizadas pelo profissional e técnicas ou recursos clínicos utilizados, compatíveis com a abordagem {abordagem}.",
    "plano_proxima_sessao": "Foco, temas pendentes ou objetivos para a próxima sessão. Se não houver, deixe vazio.",
    "temas_pesquisa": [
        {{"especifico": "descritor 1 - a abordagem clínica do profissional", "amplo": ""}},
        {{"especifico": "descritor 2 - o tema central da sessão", "amplo": ""}},
        {{"especifico": "descritor 3 - o contexto da pessoa atendida, se houver", "amplo": ""}}
    ]
}} 

TEMAS DE PESQUISA CIENTÍFICA:
No campo "temas_pesquisa", devolva 3 DESCRITORES de busca para artigos científicos. Cada descritor é UM ÚNICO conceito, curto (2 a 4 palavras).

REGRA CRÍTICA: NUNCA junte dois assuntos no mesmo descritor. As bases fazem "E" entre as palavras, então um descritor com 3 ou mais conceitos (ex.: "terapia cognitiva ansiedade social adultos") retorna ZERO resultados. Escreva um conceito por descritor.

Descritor 1 - a abordagem clínica "{abordagem}", por extenso, como se digita numa base científica em português. Escreva "terapia cognitivo-comportamental", NUNCA "TCC" (a sigla significa Trabalho de Conclusão de Curso); "terapia de aceitação e compromisso", não "ACT"; "terapia comportamental dialética", não "DBT".
Descritor 2 - o tema central trabalhado na sessão, UM conceito (ex.: "depressão maior", "ansiedade social", "luto").
Descritor 3 - o contexto da pessoa atendida, SOMENTE se o material trouxer idade, momento de vida ou condição social E se isso for DISCRIMINANTE (ex.: "idoso", "adolescente", "mulher viúva", "estudante"). NÃO use termos que servem para quase qualquer pessoa, como "adulto" ou "paciente". Se não houver contexto discriminante, deixe "especifico" VAZIO.

Preencha apenas o campo "especifico" de cada item; deixe "amplo" sempre vazio.

Critérios:
1. Use termos consagrados na literatura científica em português.
2. NÃO inclua o nome do {termo} nem dado que identifique a pessoa atendida.
3. NÃO invente títulos nem links - apenas descritores de busca.
4. Se o material clínico for insuficiente, retorne lista vazia.

IMPORTANTE:
- Use o termo "{termo}" para se referir à pessoa atendida
- Todo o texto deve estar em português
- Seja específico(a) com base no material clínico fornecIDo, não genérico(a)
- Campos vazios devem vir como string vazia ""
"""


CAMPOS_CONTEUDO_SINTESE = (
    "relato_clinico_organizado",
    "apontamentos_copiloto",
    "sintese_clinica",
    "formulacao_clinica",
    "intervencoes",
    "plano_proxima_sessao",
)


def _parse_resultado_sucesso(resultado_raw: dict) -> dict:
    try:
        temas_pesquisa = resultado_raw.get("temas_pesquisa", []) or []
        conteudo = {
            campo: str(resultado_raw.get(campo) or "").strip()
            for campo in CAMPOS_CONTEUDO_SINTESE
        }

        # JSON sintaticamente valido mas fora do schema (ex.: {}, {"erro": ...},
        # recusa do modelo) NAO pode virar sucesso: sem esta guarda o app
        # sobrescrevia os campos clinicos com vazio e gravava prontuario em
        # branco, sem erro visivel (ver AGENTS.md, secao 06/10/2026).
        if not any(conteudo.values()):
            log.warning(
                "Sintese sem nenhum campo de conteudo. Chaves recebidas: %s",
                sorted(resultado_raw.keys()),
            )
            return {
                "sucesso": False,
                "erro": "A IA não retornou conteúdo clínico. Tente novamente.",
            }

        return {
            "sucesso": True,
            "relato_clinico_organizado": conteudo["relato_clinico_organizado"],
            "apontamentos_copiloto": conteudo["apontamentos_copiloto"],
            "sintese_clinica": conteudo["sintese_clinica"],
            "formulacao_clinica": conteudo["formulacao_clinica"],
            "intervencoes": conteudo["intervencoes"],
            "plano_proxima_sessao": conteudo["plano_proxima_sessao"],
            "temas_pesquisa": temas_pesquisa,
            "artigos_sugeridos": "",
            "erro": "",
        }
    except Exception as e:
        log.exception("Erro ao parsear resultado da síntese: %s", e)
        return {
            "sucesso": False,
            "erro": "Falha ao processar resultado da IA.",
        }


def gerar_artigos(temas_pesquisa: list) -> dict:
    """Busca e formata artigos cientificos a partir dos temas de pesquisa.

    Chamada em um segundo passo (apos a sintese ja ter sido retornada),
    para nao bloquear a resposta principal da sintese.
    """
    try:
        artigos = _montar_artigos(temas_pesquisa or [])
        return {"sucesso": True, "artigos_sugeridos": artigos, "erro": ""}
    except Exception as e:
        log.exception("Erro ao buscar artigos: %s", e)
        return {"sucesso": False, "artigos_sugeridos": "", "erro": str(e)}


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
        log.warning("Gemini não configurado para síntese")
        return {"sucesso": False, "erro": "GEMINI_API_KEY não configurada."}

    try:
        config = types.GenerateContentConfig(
            response_mime_type="application/json",
        )

        response = client.models.generate_content(
            model=_get_model_name("gemini"),
            contents=prompt,
            config=config,
        )

        conteudo = response.text
        if not conteudo:
            return {"sucesso": False, "erro": "Resposta vazia da IA."}

        log.info("Gemini síntese concluída com sucesso")
        resultado = json.loads(conteudo)
        return _parse_resultado_sucesso(resultado)

    except json.JSONDecodeError as e:
        log.warning("Gemini síntese JSON inválido: %s", e)
        return {"sucesso": False, "erro": "Resposta da IA não pôde ser interpretada. Tente novamente."}
    except Exception as e:
        log.error("Gemini erro na síntese: %s", e)
        return {"sucesso": False, "erro": f"Erro ao gerar síntese clínica: {str(e)}"}


def _gerar_sintese_openai(prompt: str) -> dict:
    client = _openai_client()
    if not client:
        log.warning("OpenAI não configurado para síntese")
        return {"sucesso": False, "erro": "OPENAI_API_KEY não configurada."}
    return _gerar_sintese_openai_compat(client, prompt)


def _gerar_sintese_deepseek(prompt: str) -> dict:
    api_key = os.getenv("DEEPSEEK_API_KEY")
    if not api_key:
        log.warning("DeepSeek não configurado para síntese")
        return {"sucesso": False, "erro": "DEEPSEEK_API_KEY não configurada."}

    model = _get_model_name("deepseek")

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
            timeout=45,
        )

        if resp.status_code != 200:
            log.error("DeepSeek síntese retornou %d: %s", resp.status_code, resp.text[:500])
            return {
                "sucesso": False,
                "erro": f"DeepSeek retornou {resp.status_code}: {resp.text[:500]}",
            }

        data = resp.json()
        conteudo = data["choices"][0]["message"]["content"]

        if not conteudo:
            return {"sucesso": False, "erro": "Resposta vazia da IA."}

        log.info("DeepSeek síntese concluída com sucesso")
        resultado = json.loads(conteudo)
        return _parse_resultado_sucesso(resultado)

    except json.JSONDecodeError as e:
        log.warning("DeepSeek síntese JSON inválido: %s", e)
        return {"sucesso": False, "erro": "Resposta da IA não pôde ser interpretada. Tente novamente."}
    except Exception as e:
        log.error("DeepSeek erro na síntese: %s", e)
        return {"sucesso": False, "erro": f"Erro ao gerar síntese: {type(e).__name__}: {str(e)}"}


def _gerar_sintese_openai_compat(client, prompt: str) -> dict:
    try:
        response = client.chat.completions.create(
            model=_get_model_name("openai"),
            messages=[
                {
                    "role": "system",
                    "content": "Você é um assistente clínico especializado em psicologia. Gere JSON válido sem markdown.",
                },
                {"role": "user", "content": prompt},
            ],
            response_format={"type": "json_object"},
            temperature=0.3,
            timeout=45,
        )

        conteudo = response.choices[0].message.content
        if not conteudo:
            return {"sucesso": False, "erro": "Resposta vazia da IA."}

        log.info("OpenAI síntese concluída com sucesso")
        resultado = json.loads(conteudo)
        return _parse_resultado_sucesso(resultado)

    except json.JSONDecodeError as e:
        log.warning("OpenAI síntese JSON inválido: %s", e)
        return {"sucesso": False, "erro": "Resposta da IA não pôde ser interpretada. Tente novamente."}
    except Exception as e:
        log.error("OpenAI erro na síntese: %s", e)
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

        partes_material = []
        if relato_manual.strip():
            partes_material.append("RELATO DO PROFISSIONAL:\n" + relato_manual.strip())
        if transcricao_relato.strip():
            partes_material.append("TRANSCRIÇÃO DO ÁUDIO:\n" + transcricao_relato.strip())
        material_base = "\n\n".join(partes_material)

        if not material_base.strip():
            log.warning("Síntese abortada: sem material clínico")
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

        ordem_providers = _ordem_providers()

        ultimo_erro = ""
        for prov in _provedores_a_tentar():
            log.info(
                "Gerando síntese - provider=%s modelo=%s sessão=%d",
                prov,
                _get_model_name(prov),
                numero_sessao,
            )
            resultado = _chamar_provider_sintese(prov, prompt)
            if resultado.get("sucesso"):
                _registrar_sucesso(prov)
                return resultado
            ultimo_erro = resultado.get("erro", "")
            _registrar_falha(prov, str(ultimo_erro))
            log.warning(
                "Provedor %s falhou na síntese (tentando próximo): %s",
                prov,
                ultimo_erro,
            )

        log.error(
            "Todos os provedores falharam na síntese. Último erro: %s",
            ultimo_erro,
        )
        return {
            "sucesso": False,
            "erro": "Serviço de IA temporariamente indisponível. Tente novamente em instantes.",
        }

    except Exception as e:
        log.exception("Erro inesperado ao gerar síntese: %s", e)
        return {
            "sucesso": False,
            "erro": "Serviço de IA temporariamente indisponível. Tente novamente em instantes.",
        }


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
    max_sessoes = 10
    for s in sessoes_anteriores[-max_sessoes:]:
        sintese = _sanitizar_prompt(str(s.get('sintese', '')))
        numero = _sanitizar_prompt(str(s.get('numero', '') or ''))
        data = _sanitizar_prompt(str(s.get('data', '') or ''))
        historico += f"Sessão {numero} ({data}):\n{sintese}\n\n"

    dados_escalas = ""
    if escalas:
        for e in escalas:
            nome = _sanitizar_prompt(str(e.get("nome", "")))
            dados_escalas += f"- {nome}:\n"
            for d in e.get("datas", []):
                interpretacao = _sanitizar_prompt(str(d.get('interpretacao', '')))
                data_escala = _sanitizar_prompt(str(d.get('data', '') or ''))
                pontuacao = _sanitizar_prompt(str(d.get('pontuacao', '?')))
                dados_escalas += f"  {data_escala}: {pontuacao} pontos ({interpretacao})\n"

    prompt = f"""{PROMPT_PROGRESSO}

DADOS DO PACIENTE:
Queixa principal: {_sanitizar_prompt(queixa_principal) or 'Nao informada'}
Objetivos terapeuticos: {_sanitizar_prompt(objetivos_terapeuticos) or 'Nao informados'}

{"QUESTIONARIOS APLICADOS:" if escalas else ""}
{dados_escalas}

SESSOES ANTERIORES:
{historico}

SESSAO ATUAL (numero {numero_sessao}, {_sanitizar_prompt(str(sessao_atual.get('data', '') or ''))}):
{_sanitizar_prompt(str(sessao_atual.get('sintese', '')))}
Relato: {_sanitizar_prompt(str(sessao_atual.get('relato', '')))}
Intervencoes: {_sanitizar_prompt(str(sessao_atual.get('intervencoes', '')))}

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
        # Antes usava um provedor so: com o Gemini em 503 gastava 32s e falhava
        # (visto em producao em 07/10/2026). Agora percorre a mesma ordem da
        # sintese, para que um provedor fora do ar nao derrube o progresso.
        ultimo_erro = ""
        for provider in _provedores_a_tentar():
            log.info("gerar_progresso: provider=%s sessao=%d", provider, numero_sessao)
            resultado = _chamar_llm_json(provider, prompt, temperature=0.3)
            # Sucesso = o JSON do modelo (que NAO tem a chave "sucesso").
            # Falha = os dicionarios de erro, que sempre trazem sucesso=False.
            if resultado.get("sucesso") is not False:
                _registrar_sucesso(provider)
                return resultado
            ultimo_erro = str(resultado.get("erro", ""))
            _registrar_falha(provider, ultimo_erro)
            log.warning(
                "Provedor %s falhou no progresso (tentando proximo): %s",
                provider, ultimo_erro,
            )
        return {"sucesso": False, "erro": ultimo_erro or "Nenhum provedor disponivel."}
    except Exception as e:
        log.exception("Erro ao gerar progresso: %s", e)
        return {"sucesso": False, "erro": f"Erro ao gerar progresso: {str(e)}"}


MAX_TENTATIVAS_LLM = 3
ATRASOS_RETRY_LLM = (2, 4)
STATUS_TRANSITORIOS_LLM = frozenset({408, 429, 500, 502, 503, 504})


def _erro_transitorio(e: Exception) -> bool:
    """True se a falha vale retentativa (429, 5xx, timeout, conexao).

    Erro de formato, autenticacao ou parametro nao melhora repetindo a chamada.
    """
    if isinstance(e, json.JSONDecodeError):
        return False
    for atributo in ("code", "status_code", "http_status", "status"):
        valor = getattr(e, atributo, None)
        if isinstance(valor, int):
            return valor in STATUS_TRANSITORIOS_LLM
    if isinstance(e, OSError):  # cobre TimeoutError e ConnectionError
        return True
    # SDKs costumam citar o status no texto (ex.: "503 UNAVAILABLE")
    return bool(re.search(r"\b(?:408|429|50[0-4])\b", str(e)))


def _executar_com_retry(rotulo: str, tentar):
    """Roda `tentar()` com retry e backoff para indisponibilidade do provedor.

    `tentar` deve devolver o dict ja parseado e levantar excecao ao falhar.
    Devolve sempre um dict: o do provedor, ou {"sucesso": False, "erro": ...}
    quando o erro nao e transitorio ou as tentativas se esgotam.
    """
    ultimo_erro: Exception | None = None
    for tentativa in range(MAX_TENTATIVAS_LLM):
        try:
            return tentar()
        except Exception as e:
            ultimo_erro = e
            if not _erro_transitorio(e):
                log.exception("%s: falha nao transitoria: %s", rotulo, e)
                break
            if tentativa == MAX_TENTATIVAS_LLM - 1:
                log.error("%s indisponivel apos %d tentativas: %s",
                          rotulo, MAX_TENTATIVAS_LLM, e)
                break
            atraso = ATRASOS_RETRY_LLM[min(tentativa, len(ATRASOS_RETRY_LLM) - 1)]
            log.warning("%s indisponivel (tentativa %d/%d), aguardando %ds: %s",
                        rotulo, tentativa + 1, MAX_TENTATIVAS_LLM, atraso, e)
            time.sleep(atraso)
    return {"sucesso": False, "erro": str(ultimo_erro)}


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

    def tentar() -> dict:
        response = client.chat.completions.create(
            model=_get_model_name("openai"),
            messages=[{"role": "user", "content": prompt}],
            response_format={"type": "json_object"},
            timeout=120,
            temperature=temperature,
        )
        return json.loads(response.choices[0].message.content)

    return _executar_com_retry("OpenAI", tentar)


def _chamar_llm_json_deepseek(prompt: str, temperature: float) -> dict:
    client = OpenAI(
        api_key=os.getenv("DEEPSEEK_API_KEY"),
        base_url="https://api.deepseek.com/v1",
    )
    def tentar() -> dict:
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

    return _executar_com_retry("DeepSeek", tentar)


def _chamar_llm_json_gemini(prompt: str, temperature: float) -> dict:
    client = genai.Client(
        api_key=os.getenv("GEMINI_API_KEY"),
        http_options=types.HttpOptions(timeout=120000),
    )
    def tentar() -> dict:
        response = client.models.generate_content(
            model="gemini-3.7-flash",
            contents=prompt,
            config=types.GenerateContentConfig(
                temperature=temperature,
                response_mime_type="application/json",
            ),
        )
        return json.loads(response.text)

    return _executar_com_retry("Gemini", tentar)

