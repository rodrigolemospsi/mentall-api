# Painel de custos e uso (Fase 1)

Aba **Custos** no painel do dono (`/admin/custos`), restrita aos papéis `admin` e `financeiro`.
Mostra, por mês: custo total, custo variável de IA, infra Magalu (via API), custos fixos,
orçamento, unit economics (custo por profissional ativo, custo por transcrição, margem
contra o preço do plano) e a evolução diária.

## O que é medido e como

| Fonte | Como entra | Natureza |
|---|---|---|
| DeepSeek, Gemini, OpenAI (síntese) | tokens de entrada/saída retornados pela própria API × tabela `precos_provedor` | medido (estimativa de preço) |
| Groq / OpenAI (transcrição) | duração do áudio (campo `duration` do verbose_json; fallback: header WAV ou estimativa por bytes) × preço por minuto | medido (estimativa de preço) |
| Magalu Cloud | Consumption API (`GET /consumption/usage`, FOCUS diário) com `MAGALU_CONSUMPTION_API_KEY` | fatura real via API |
| Custos fixos | cadastro manual na própria página (mensal ou anual, anual dividido por 12) | informado |
| OpenAlex | gratuito | ignorado |

- Sync da Magalu: automático no start e a cada **6 horas** (thread em background), idempotente por dia.
- Atribuição por profissional: o `owner_id` vem do JWT do app nos endpoints `/gerar-sintese` e `/transcrever`.
- LGPD: a tabela `custos_uso` guarda apenas números (provedor, modelo, tokens/segundos, custo, data).
  Nenhum conteúdo clínico, nome de paciente ou áudio.

## Variáveis de ambiente

```
MAGALU_CONSUMPTION_API_KEY=...        # Consumption API (escopo tally-consumption-api)
CUSTOS_ORCAMENTO_MENSAL_BRL=300       # orçamento para os alertas do painel
CUSTOS_PRECO_MENSAL_BRL=79.90         # preço do plano para calcular margem
CUSTOS_CAMBIO_USD_BRL=5.40            # câmbio usado nas estimativas em USD
```

## Preços de IA

A tabela `precos_provedor` começa com valores de referência (DeepSeek, Gemini, OpenAI, Groq)
marcados como estimativa. Para ajustar, edite as linhas no banco (Fase 2 terá edição pela tela).
A Magalu é sempre o valor faturado, não estimativa.

## Limitações conhecidas (próximas fases)

1. Alertas de orçamento ainda são visuais na página; Fase 3 envia e-mail (Mailu) e WhatsApp (WuzAPI).
2. Câmbio é fixo por env; Fase 2 busca PTAX diário.
3. Faturas de DeepSeek/Groq/Gemini (sem API de billing) podem ser importadas manualmente para conciliação.
4. OpenAI Costs API (custos reais da organização) pode complementar a estimativa local.
5. Custo de artigos (OpenAlex) e armazenamento não entram por serem gratuitos/irrelevantes hoje.

## Arquivos

- `services/custos.py` — medição, sync Magalu, custos fixos, agregação.
- `admin_ui.py` — `pagina_custos` + item de menu.
- `main.py` — rotas `/admin/custos*`, atribuição de `owner_id` nos endpoints de IA/transcrição.
- `services/ia_clinica.py` e `services/transcricao.py` — captura de tokens/duração.
- `services/db.py` — tabelas `custos_uso`, `precos_provedor`, `custos_fixos`, `custos_sync_estado`.

## Status em produção (26/10/2026)

- Deploy no Fly (`mentall-api`), banco SQLite persistente no volume `/data`.
- Página ativa em `/admin/custos` (papéis admin/financeiro).
- Sync automático da Magalu a cada 6 h; primeira execução em produção:
  7 registros, **R$ 12,57** no período 19–25/10.
- `MAGALU_CONSUMPTION_API_KEY` configurada nos secrets do Fly.
- Memória geral das mudanças: `MEMORIA_ALERTAS_EMAIL_E_CUSTOS.md`.
