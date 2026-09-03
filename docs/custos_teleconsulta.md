# Custos de Teleconsulta do MentAll PRO

**Documento de apoio à decisão (para discussão com o sócio).**
Data: 02/09/2026 · Elaborado por: Rodrigo.

---

## 1. Objetivo

Estimar os custos mensais de **infraestrutura de vídeo (teleconsulta)** do MentAll PRO e comparar as alternativas de hospedagem, para decidir o caminho (dados no Brasil vs. SaaS) e o custo-alvo por profissional.

**Escopo decidido:** a teleconsulta **não grava nem transcreve** a sessão — a chamada fica separada do fluxo de IA (a mídia NÃO é enviada à IA). Isso também reduz custo e risco de conformidade.

---

## 2. Premissas do cenário avaliado

| Parâmetro | Valor |
|---|---|
| Profissionais na plataforma | 100 |
| Pacientes por profissional | 20 |
| Sessões por paciente / mês | 4 (aproximadamente semanal) |
| Sessões por profissional / mês | 20 × 4 = **80** |
| Duração média da sessão | 50 min |
| Participantes por sessão | 2 (profissional + paciente) |
| Minutos de vídeo (WebRTC) por sessão | 2 × 50 = **100 min** |
| **Minutos totais por mês (100 profissionais)** | **800.000 min** |
| **Pico de chamadas simultâneas** | ~35–60 (≈70–120 participantes) |

> Hipóteses conservadoras; os valores são ajustáveis para outros volumes (ver seção 7).

---

## 3. Por que a mídia vai para infra separada

O backend atual roda no **Fly.io**, que tem **suporte limitado a UDP/WebRTC** — não é uma boa base para vídeo ao vivo. Por isso, a mídia da chamada passa por um **servidor de mídia (SFU)** separado. O **código do app é o mesmo** em qualquer opção; muda apenas a **URL servidor**, configurada por variável de ambiente.

---

## 4. Opções de hospedagem

### 4A. LiveKit Cloud (SaaS, sem servidor próprio)

| Plano | Preço base | Minutos incluídos | Excedente | **Custo no cenário (800.000 min)** | Aprox. R$ |
|---|---|---|---|---|---|
| **Build** (grátis) | $0 | 5.000 | $0,0005/min | 795.000 × 0,0005 = **$397,50** | R$ ~1.990 |
| **Ship** | $50/mês | 150.000 | $0,0005/min | (650.000×0,0005) + 50 = **$375,00** | R$ ~1.875 |
| **Scale** | $500/mês | 1.500.000 | — | **$500,00** (flat) | R$ ~2.500 |

- **Build** tem limite de 100 conexões simultâneas (≈50 chamadas) e é indicado para validação; com 100 profissionais o uso real cai em **Ship**.
- **Scale** inclui **region pinning**, **HIPAA** e relatórios de segurança — relevante se o objetivo for vender para clínicas/corporativo.
- **Ressalva (LGPD):** mesmo no Scale **não há região no Brasil** — a mídia trafega em infraestrutura global (EUA/EU).

### 4B. Self-hosted LiveKit no DigitalOcean São Paulo (dados no Brasil)

| Item | Sem alta disponibilidade (1 servidor) | Com alta disponibilidade (cluster) |
|---|---|---|
| Droplet (8 vCPU / 16GB) | ~$48–96/mês | 2+ nós: ~$96–192/mês |
| Banda/egress (~12 TB/mês) | ~$60–80 de excedente | ~$60–120 |
| Redis + Load Balancer + TURN + monitoramento | — | ~$40–120/mês |
| **Total** | **~$110–175/mês** | **~$250–500/mês** |
| **Aprox. R$** | **~R$ 550–875/mês** | **~R$ 1.250–2.500/mês** |

Pontos de atenção:
- **1 servidor = ponto único de falha** (se cair, as chamadas caem).
- Com 100 profissionais, para **confiabilidade** o caminho é **cluster/HA** — e aí o custo **se aproxima do LiveKit Cloud**.
- **A "pegadinha" é a banda (egress)**, que cresce com os minutos. Estimativas de banda são aproximadas (taxa ≈ `$0,01/GiB` ≈ `$10/TB`).
- *(Alternativa Jitsi self-hosted: mesmo custo de VPS, porém o SDK Flutter está descontinuado — não recomendado.)*

---

## 5. Comparativo

| Critério | LiveKit Cloud (Ship) | Self-hosted BR (HA) |
|---|---|---|
| Custo no cenário | ~R$ 1.875/mês | ~R$ 1.250–2.500/mês |
| Complexidade de operação | Baixa (SaaS) | Alta (você mantém) |
| Escalabilidade / confiabilidade | Alta (rede global) | Depende do seu setup |
| **LGPD / dados no Brasil** | ❌ (EUA/EU) | ✅ (São Paulo) |
| HIPAA / SOC 2 p/ vender a clínicas | ✅ no Scale | você teria que certificar (caro) |

---

## 6. Leitura e recomendação

- Em **custo puro**, no cenário de 100 profissionais, **self-hosted BR (1 servidor ~R$ 550–875/mês)** é mais barato que o Cloud (~R$ 1.875/mês) **e** mantém os dados no Brasil.
- Em **operação/confiabilidade**, o **Cloud** é mais simples e escala sozinho; para 100 profissionais você provavelmente vai querer **HA** no self-host, que equipara o custo ao Cloud.
- **Recomendação:**
  1. **Agora (uso próprio / MVP):** VPS BR **pequena** (~R$ 60–120/mês) OU LiveKit **Cloud grátis** (~R$ 0–90). Código com env-configurável.
  2. **Ao escalar para 100 profissionais:**
     - Se o argumento de venda é **LGPD / dados no Brasil** → **self-hosted BR** (começar em 1 servidor ~R$ 550–875; migrar para cluster quando a confiabilidade exigir).
     - Se a prioridade é **zero-operação + HIPAA p/ clínicas** → **LiveKit Cloud Ship/Scale (~R$ 1.875–2.500)**.
  3. **Híbrido:** deixar a URL do servidor configurável para trocar entre Cloud e VPS sem retrabalho.

---

## 7. Decisões em aberto

1. **Posicionamento:** "dados no Brasil" é argumento central de venda? (Se sim → VPS BR; se não → Cloud é mais simples.)
2. **Custo mensal aceitável** para 100 profissionais: até R$ 875 (1 servidor BR), até R$ 1.875 (Cloud Ship), ou até R$ 2.500 (Cloud Scale + HIPAA)?
3. **Atender clínicas/corporativo?** (Aí HIPAA/relatórios do Scale valem o custo.)
4. **Horizonte da escala de 100 profissionais** (próximo ou visão de 1–2 anos?) — define se investimos em HA agora ou depois.

---

## 8. Escalabilidade (sensitivity)

Para outras premissas de volume, ajuste: `min_totais_mes = profissionais × pacientes × sessões_paciente_mes × 2 × 50`.

Exemplos (100 profissionais):
- 10 pacientes × 4 sessões/mês → **400.000 min** → VPS BR ~R$ 240–500 | Cloud Ship ~R$ 875.
- 20 pacientes × 4 sessões/mês → **800.000 min** → VPS BR ~R$ 550–875 | Cloud Ship ~R$ 1.875.
- 20 pacientes × 2 sessões/mês → **400.000 min** (mesmo do primeiro caso).

*Câmbio utilizado: US$ 1 ≈ R$ 5.*
