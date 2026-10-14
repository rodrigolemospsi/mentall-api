# 18 — Comparativo de LGPD com concorrentes brasileiros

**Versão:** 1.0 · **Data:** 13/10/2026 · **Próxima revisão:** 13/04/2027 ou a cada mudança relevante
**Natureza:** análise de mercado. **Não é parecer jurídico** — os pontos ⚖️ dependem de validação de
advogado especializado. Serve de **referência de redação** para os documentos 05, 06, 10 e 15 e de
**insumo** para as decisões do documento 17.
**Método:** leitura direta das políticas publicadas pelos concorrentes em 13/10/2026 (evidência: URL).

> **Regra de uso.** O que os concorrentes publicam **não** é obrigação legal nem prova de conformidade
> — dois deles citam a Resolução CFP nº 11/2018, que o nosso diagnóstico (`01_diagnostico_lgpd.md`)
> aponta como **revogada** pela Resolução CFP nº 9/2024 ⚖️. Este documento mostra **o padrão de
> mercado** para calibrar a redação do MentAll PRO; não define o que o MentAll deve afirmar.

---

## 1. Objetivo, método e limites

- **Objetivo:** ver o que apps brasileiros de prontuário/gestão para psicólogos colocam em seus
  documentos de LGPD, para (a) não publicar menos que o mercado e (b) não prometer mais que o produto.
- **Como foi feito:** leitura das páginas oficiais listadas no §2, comparação elemento a elemento
  (§3) e mapeamento de cada lacuna para o item do plano de ação (`02_plano_de_acao.md` e §5).
- **Fontes:** apenas páginas **públicas** dos concorrentes. **Não** foram analisados os produtos por
  dentro (sem auditoria de código/app alheio) nem consultados contratos comerciais.
- **Limites:** **Mently** e **Corpora** não foram localizados nesta busca (**não achei** — não é
  afirmação de que não existam) e ficaram fora. **ProntusCare** e **PsicoPront** publicam políticas
  mais enxutas; **PsiLuz**, **Zenklub** e **Copilloto** são as referências mais completas.

---

## 2. Fontes consultadas (lidas em 13/10/2026)

| # | Concorrente | Documento lido | URL |
|---|---|---|---|
| C1 | **PsiLuz** | Política de Privacidade + página "Conformidade LGPD" (/lgpd) | `psiluz.com.br/privacy`, `psiluz.com.br/lgpd` |
| C2 | **Zenklub** (grupo Conexa) | Aviso de Privacidade | `zenklub.com.br/privacidade` |
| C3 | **Copilloto** | Política de Privacidade (Versão 2026-05-27) | `copilloto.com.br/privacidade` |
| C4 | **ProntusCare** | Política de Privacidade (26/04/2026) | `prontuscare.com.br/privacidade.html` |
| C5 | **PsicoPront** | Política de Privacidade (Janeiro/2026) | `psicopront.com.br/privacidade` |

---

## 3. Matriz comparativa

**Legenda:** ✅ presente e detalhado · ~ presente de forma genérica/parcial · ❌ ausente ·
— não aplicável. A coluna **MentAll** reflete o **estado do texto** hoje (`05`, `06`, `10`), não o
desejado.

| Elemento | PsiLuz | Zenklub | Copilloto | ProntusCare | PsicoPront | **MentAll (texto atual)** |
|---|---|---|---|---|---|---|
| Controlador identificado (razão social + CNPJ) | ✅ AssemblySystems | ✅ Zenklub/Conexa | ✅ Copilloto Ltda | ❌ | ✅ CNPJ | ❌ (placeholder) |
| DPO nomeado + canal dedicado | ✅ `dpo@` (LGPD page) | ✅ nome + `dpo@` | ✅ `dpo@` | ✅ `privacidade@` | ❌ | ❌ (`[NOMEAR]`) |
| Base legal por categoria de dado | ✅ | ✅ (tabela por dado) | ✅ | ❌ | ~ | ✅ (§3, por finalidade) |
| Transferência internacional (art. 33) | ✅ | ✅ | ~ (diz Gemini no Brasil) | ❌ | ✅ (EUA/OpenAI) | ✅ (§5) |
| Retenção com prazo explícito | ~ ("conforme CFP") | ✅ 20 anos | ✅ 5 anos + outras | ~ ("conforme profissional") | ~ | ✅ mínimo 5 anos (§8) |
| Subprocessadores nomeados | ❌ (genérico) | ❌ (genérico) | ✅ 5 nomeados | ❌ (genérico) | ✅ OpenAI | ✅ (§4, lista própria) |
| IA sem treinamento / sem retenção, declarado | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ (§6, com ressalva ⚖️) |
| Direitos do titular + prazo de resposta | ✅ ("prazo legal") | ✅ 15 dias | ✅ 15 dias úteis | ✅ (sem prazo) | ✅ | ✅ lista; prazo placeholder (§9) |
| Notificação de incidente (art. 48) | ❌ | ✅ notifica ANPD | ~ (só canal ANPD) | ❌ | ❌ | ✅ (§7, "em adequação") |
| Menores (art. 14) | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (§10) |
| Política de Cookies separada | ✅ | ✅ | ✅ | ~ | ✅ | ❌ (só §13 site) |
| Termos de Uso separados + URL | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (doc 06; URL pendente) |
| Versionamento (nº de versão + data) | ✅ datas | ✅ data | ✅ versão + data | ✅ data | ✅ data | ~ (§14 cita histórico) |
| Tratamento de **menores** | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (único a prever) |
| **Local-first** (prontuário no aparelho) | ❌ cloud | ❌ cloud | ❌ cloud | ❌ cloud | ❌ cloud | ✅ **único** |

**Leitura da matriz:** o MentAll **já tem** boa parte do que os concorrentes têm (base legal, lista de
terceiros, art. 33, IA sem treinamento, menores) — o que falta é **materializar** o que está em
placeholder (DPO, CNPJ, prazo de resposta, URL) e **fechar as lacunas de comportamento** (P0), não
copiar texto.

---

## 4. Síntese por concorrente

### 4.1 PsiLuz — a melhor "vitrine" de conformidade
Publica **página /lgpd dedicada** ("Exercer meus direitos", "Falar com o DPO"), **/security**,
**/cookies** e **/terms**. Traz **base legal por finalidade** (consentimento, execução de contrato,
legítimo interesse, obrigação legal) e declara **AES-256**, "servidores Brasil" e "**100% conforme com
a LGPD**". Retenção genérica ("conforme exigências do CFP"); **sem seção de incidentes nem de menores**.
Padrão a imitar: **página de direitos + canal do DPO** e **base legal explícita**.

### 4.2 Zenklub (Conexa) — a mais completa em governança
**Aviso de Privacidade** longo, com **DPO nomeado** (Lucas Passos, `dpo@conexasaude.com.br`), **tabela
de base legal por dado**, **direitos com resposta em 15 dias**, **transferência (art. 33)**,
**notificação de incidente (art. 48, §1º)** e **retenção de 20 anos** para prontuários (Lei nº
13.787/2018 + Res. CFP nº 6/2019 + Res. CFM nº 1.821/2007). **Sem seção de menores**. Padrão a imitar:
**tabela de base legal por dado** e **art. 48**.

### 4.3 Copilloto — a mais moderna e transparente
Política curta, em linguagem simples, **operador** (psicólogo controlador). Nomeia **cada
subprocessador** (Brevo, Asaas, NFe.io, **Google/Gemini**, Apify) e declara **"Gemini no Brasil,
no-train, áudio deletado em 24h"**. **Retenção explícita** (prontuário 5 anos CFP 1/2009; financeiro 5
anos; conta cancelada 90 dias; logs 12 meses), **direitos em 15 dias úteis**, **link para a ANPD** e uma
**seção de cold outbound** com LIA e opt-out. Padrão a imitar: **nomear subprocessadores**, **prazos por
categoria** e **canal de reclamação ANPD**.

### 4.4 ProntusCare — política mínima
Curta, sem razão social/CNPJ, sem base legal por categoria, sem transferência internacional, sem
incidentes, sem menores. Traz **DPO por e-mail** e "**em total conformidade**". Serve de **piso** — o
MentAll deve publicar **mais**, não menos.

### 4.5 PsicoPront — enxuta, focada em segurança técnica
Declara **AES-256-GCM**, TLS 1.3, **senha clínica separada**, timeout e logs. **IA opcional via OpenAI
GPT-4o-mini**, com transferência aos EUA; joga no profissional a **responsabilidade pelo consentimento**.
Sem DPO nomeado, sem incidentes, sem menores. O destaque é a **clareza sobre a IA** ("apenas texto
enviado à OpenAI"), que dialoga com o nosso P0.1.

---

## 5. O que o mercado faz e o MentAll ainda não (gap → item do plano)

| Padrão de mercado observado | Quem publica | Item do `02_plano_de_acao.md` |
|---|---|---|
| DPO nomeado publicamente + e-mail dedicado | PsiLuz, Zenklub, Copilloto, ProntusCare | **P1.1** (e decisão **D9**) |
| Razão social + CNPJ do controlador | PsiLuz, Zenklub, Copilloto, PsicoPront | **P0.5** / **P1.1** |
| Base legal mapeada por categoria de dado | PsiLuz, Zenklub, Copilloto | **P1.3** |
| Transferência internacional sob art. 33 com mecanismo | PsiLuz, Zenklub, PsicoPront | **P0.3** (decisão **D2**) |
| Prazo de retenção explícito por categoria | Zenklub (20a), Copilloto (5a) | **P1.6** (decisão **D8**) |
| Subprocessadores nomeados (para responder "não compartilhado") | Copilloto | **P0.1**, **P1.10** (decisão **D9**) |
| Prazo de resposta ao titular (15 dias) | Zenklub, Copilloto | **P1.8** |
| Notificação de incidente à ANPD (art. 48) | Zenklub | **P1.7** |
| Política de Cookies + página de direitos | PsiLuz, Zenklub, Copilloto | **P0.5** |
| Declaração "IA sem treinamento" | PsiLuz, Copilloto, PsicoPront | **P0.6** (decisão **D1**) |

---

## 6. Onde o MentAll já está à frente (não copiar o mercado)

- **Local-first / prontuário cifrado no aparelho** — **nenhum** dos cinco concorrentes faz isso; todos
  são cloud. É o diferencial defensável, **desde que** o fail-open (P0.7) e o áudio em claro (P0.8)
  estejam fechados — senão o argumento é falso.
- **Gate de revisão humana obrigatório** antes de salvar conteúdo de IA — o MentAll é o único que
  **bloqueia** o salvamento sem revisão; os outros descrevem a revisão como recomendação/procedimento.
- **Seção de menores (art. 14)** — **nenhum** concorrente trata; o MentAll prevê campo de responsável
  legal (P1.15), o que também atende melhor ao ECA Digital.
- **Diagnóstico interno com evidência `arquivo:linha`** — o pacote `docs/lgpd/` é mais profundo que
  qualquer política de concorrente; serve como prova de accountability (art. 37).

---

## 7. Achados de posicionamento (usar com cautela ⚖️)

1. **Dois concorrentes citam a Resolução CFP nº 11/2018** (Zenklub, na cláusula de Regulamentação;
   Copilloto, no cabeçalho e no FAQ) — o nosso `01_diagnostico_lgpd.md` aponta que a **Res. CFP nº
   9/2024 a revogou expressamente**. **Confirmar com o jurídico** antes de qualquer afirmação pública
   comparativa; a bandeira é boa, mas só se a base estiver correta.
2. **Retenção dividida no mercado:** Copilloto adota **5 anos** (Res. CFP nº 1/2009); Zenklub adota
   **20 anos** (Lei nº 13.787/2018 + Res. CFP nº 6/2019 + Res. CFM nº 1.821/2007). O mercado **não é
   unânime** → reforça a decisão **D8** e a pendência ⚖️ nº 1 do documento 10.
3. **"Em adequação" × "100% conforme":** PsiLuz ("100% conforme", "total conformidade") e ProntusCare
   ("em total conformidade") usam linguagem de conformidade plena. O MentAll **mantém** "em adequação"
   (não existe certificação de LGPD) — decisão editorial já registrada no doc 15 §5.4.
4. **Responsabilidade da IA empurrada ao psicólogo:** PsiLuz, PsicoPront e Copilloto deixam o
   **consentimento do titular para IA** como dever do profissional. É padrão de mercado, mas **não**
   resolve o art. 11 — o MentAll deve **instrumentar** isso (P1.5), não apenas transferir.

---

## 8. Encaminhamentos

1. **Redação dos documentos públicos** (`05`, `06`): incorporar os padrões do §5 — controlador+CNPJ,
   DPO, base legal por categoria, art. 33, prazo de resposta, canal ANPD, versionamento e aviso de
   cookies. **Nada disso pode ir à URL pública antes dos P0** (regra do próprio pacote).
2. **Retenção** (`10`): registrar o benchmark 5 × 20 anos como insumo de **D8**.
3. **Lojas** (`15`): o precedente do Copilloto (subprocessadores nomeados + "não compartilhado" após
   contrato) sustenta a decisão **D9**; a declaração de "IA sem treinamento" é o que a Apple 5.1.2(i)
   espera.
4. **Decisões** (`17`): D1, D2, D3, D8 e D9 ganham, aqui, o contexto de mercado.
5. **Manutenção:** este comparativo é **revisado** a cada novo provedor/funcionalidade e, no mínimo,
   **semestralmente** — concorrentes mudam de política com frequência (ex.: Copilloto versiona por
   data). A revisão entra no calendário do documento 17.
6. **Funcionalidades (produto):** o comparativo de **como** os concorrentes implementam financeiro,
   mensagens e teleconsulta está em `docs/competidores/` (ferramenta: REA). É complementar a este
   documento — aqui interessa **transparência**, lá interessa **arquitetura de feature**.

---

## 9. O que este documento não é

- **Não é** parecer jurídico e **não** afirma que os concorrentes estejam conformes.
- **Não é** obrigação de copiar: o mercado serve de **régua de transparência**, não de fonte de
  promessa. A regra de ouro do pacote permanece: **nenhuma afirmação pública sem comportamento
  correspondente no código**.

---

**Documentos relacionados:** `01_diagnostico_lgpd.md` · `02_plano_de_acao.md` ·
`05_politica_de_privacidade.md` · `06_termos_de_uso.md` · `10_politica_de_retencao_e_descarte.md` ·
`15_lojas_google_play_e_app_store.md` · `17_registro_de_decisoes_e_revisoes.md`
