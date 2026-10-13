# Mapa de Transferência Internacional de Dados e Salvaguardas — MentAll PRO

**Versão:** 1.0 (rascunho para revisão) · **Data:** 09/10/2026
**Produto:** MentAll PRO — prontuário clínico psicológico com IA
**Fundamento:** LGPD, Lei nº 13.709/2018, arts. 33 a 36; **Resolução CD/ANPD nº 19, de 23/08/2024**
(Regulamento de Transferência Internacional de Dados e cláusulas-padrão contratuais);
**Resolução CD/ANPD nº 32, de 26/01/2026** (adequação recíproca Brasil–União Europeia)
**Natureza:** documento técnico de mapeamento e decisão. **Não é parecer jurídico.** Pontos marcados
com ⚖️ dependem de validação por advogado. O MentAll PRO está **em adequação** — este documento não
declara conformidade nem substitui o RIPD (documento 08) ou o DPA (documento 04).

**Documentos oficiais consultados:**

- [Resolução CD/ANPD nº 19/2024 — texto integral (gov.br)](https://www.gov.br/anpd/pt-br/acesso-a-informacao/institucional/atos-normativos/regulamentacoes_anpd/resolucao-cd-anpd-no-19-de-23-de-agosto-de-2024)
- [Publicação no DOU de 23/08/2024 (in.gov.br)](https://www.in.gov.br/en/web/dou/-/resolucao-cd/anpd-n-19-de-23-de-agosto-de-2024-580095396)
- [Resolução CD/ANPD nº 32/2026 — adequação Brasil–UE (Biblioteca Digital MJ)](https://bibliotecadigital.mj.gov.br/handle/1/16638)
- [Resolução CD/ANPD nº 15/2024 — Regulamento de Comunicação de Incidente (in.gov.br)](https://www.in.gov.br/en/web/dou/-/resolucao-cd/anpd-n-15-de-24-de-abril-de-2024-556243024)
- [Canal oficial de Comunicação de Incidente de Segurança da ANPD](https://www.gov.br/anpd/pt-br/canais_atendimento/agente-de-tratamento/comunicado-de-incidente-de-seguranca-cis)

---

## 1. Enquadramento: quem transfere o quê

O MentAll PRO é **operador** do fluxo clínico e **controlador** da conta do profissional e da
telemetria. Na prática há **dois exportadores**:

| Exportador | O que transfere | Quem responde perante o titular |
|---|---|---|
| **Psicólogo (controlador)** — por meio do software MentAll | Prontuário, áudio, transcrição, síntese, anamnese, contrato, lembretes | Pelo mérito clínico e pelas decisões sobre os dados |
| **MentAll PRO (controlador)** | Conta do profissional, telemetria, logs de segurança | Pelas finalidades próprias |

O MentAll, **como operador**, deve prestar auxílio ao controlador com as informações de que dispõe
para que este verifique e comprove a licitude da transferência (Res. 19/2024, art. 4º, §1º). Isso
significa: **este documento é o instrumento de apoio que o MentAll entrega ao psicólogo** e, ao mesmo
tempo, o registro próprio do MentAll para as transferências em que é controlador.

**Licitude em duas camadas (Res. 19/2024, art. 9º):** toda transferência exige, cumulativamente,
(i) **hipótese legal** do art. 7º ou art. 11 da LGPD **e** (ii) **mecanismo válido** de transferência
(adequação, cláusulas-padrão, cláusulas específicas, normas corporativas globais ou as hipóteses dos
incisos II, "d", e III a IX do art. 33). Não basta um dos dois.

**Minimização (Res. 19/2024, art. 9º, parágrafo único):** a transferência deve se limitar ao **mínimo
necessário**. É exatamente aqui que o desenho atual do produto falha — ver §2 e §5.

---

## 2. Mapa de transferências

### 2.1 Tabela principal

| # | Dado | Subprocessador / destinatário | País | Finalidade | Hipótese legal proposta ⚖️ (LGPD) | Mecanismo do art. 33 ⚖️ | Evidência |
|---|---|---|---|---|---|---|---|
| **T1** | Contrato terapêutico (JSON), `nome_aceite`, data | **Turso / AWS** (`aws-us-west-2`) | **EUA** (Oregon) | Formalizar o acordo terapêutico e o aceite eletrônico | Execução de contrato (art. 7º, V); tutela da saúde no vínculo clínico (art. 11, II, "f") | Cláusulas-padrão contratuais — art. 33, II, "b" | `backend/.env:40`; `db.py:180-188`; `contrato_service.py:14-15` |
| **T2** | Respostas de anamnese (dado sensível) | **Turso / AWS** | **EUA** | Coletar histórico inicial | Tutela da saúde (art. 11, II, "f") | Cláusulas-padrão contratuais | `db.py:189-198`; `backend/.env:40` |
| **T3** | Telefone, nome, mensagem de lembrete, data/hora | **Turso / AWS** | **EUA** | Agendar e disparar lembretes; reduzir faltas | Consentimento específico (art. 7º, I / art. 11, I) | Cláusulas-padrão contratuais | `db.py:199-215`; `lembrete_service.py` |
| **T4** | **Áudio do relato clínico** (base64) | **Groq, Inc.** (default) | **EUA** | Transcrever o relato ditado | Consentimento específico e destacado (art. 11, I) | Cláusulas-padrão contratuais | `transcricao.py:13-20,64-65`; `backend/.env:7` |
| **T5** | **Áudio do relato clínico** | **OpenAI** (`gpt-4o-mini-transcribe`) | **EUA** | Transcrição (alternativa) | idem T4 | idem T4 | `transcricao.py:17-20,96-99` |
| **T6** | **Nome (pseudonimizado) + relato clínico integral** | **OpenAI** | **EUA** | Gerar síntese/evolução de apoio documental | Consentimento específico e destacado (art. 11, I) | Cláusulas-padrão contratuais | `ia_clinica.py:438-454,627-632`; `main.py:890-893` |
| **T7** | **Nome (pseudonimizado) + relato clínico integral** | **DeepSeek** (`api.deepseek.com`) | **China** | Síntese — **fallback automático** quando a OpenAI falha | Consentimento específico e destacado (art. 11, I) **+ RIPD específico** | Cláusulas-padrão contratuais **+ salvaguardas adicionais** (Cláusula 11) ⚖️ | `ia_clinica.py:296` (`ORDEM_PROVEDORES_PADRAO = "openai,deepseek"`), `:648`, `:656-668`; `AGENTS.md:191` |
| **T8** | `paciente_id`, sessões anteriores, queixa principal, escalas | **OpenAI / DeepSeek** | **EUA / China** | Gerar progresso/evolução | Consentimento específico (art. 11, I) | idem T6/T7 | `ia_clinica_service.dart:313-323` |
| **T9** | Descritores clínicos (ex.: "depressão maior") **+ e-mail pessoal do profissional como `mailto`** | **OpenAlex** | Internacional (base pública) | Sugerir literatura científica | Legítimo interesse (art. 7º, IX) ⚖️ | Garantias específicas / cláusulas específicas ⚖️ | `ia_clinica.py:56-63,83-91`; `backend/.env:34,36` |
| **T10** | Telemetria: `owner_id`, `device_id`, plataforma, versão, tipo do evento | **Turso / AWS** | **EUA** | Produto, suporte e presença | Legítimo interesse (art. 7º, IX) ⚖️ | Cláusulas-padrão contratuais | `telemetria.py:1-26` |
| **T11** | Conta do profissional: e-mail, nome, hash de senha, plano, tokens | **Turso / AWS** | **EUA** | Autenticar e licenciar | Execução de contrato (art. 7º, V) | Cláusulas-padrão contratuais | `db.py` (tabelas `usuarios`, `recuperacoes`, `resets_senha`); `main.py:703-739` |
| **T12** | E-mail do profissional, código/token de verificação | **Gmail SMTP (Google)** | **EUA** | Verificação de conta e recuperação de senha | Execução de contrato (art. 7º, V) | Cláusulas-padrão contratuais | `main.py:1709-1713` |
| **T13** | Stack trace, plataforma, versão (**sem PII**, opt-in) | **Sentry** | **EUA** | Diagnóstico de erro | Legítimo interesse (art. 7º, IX) ⚖️ | Cláusulas-padrão contratuais | `main.dart:73-105` (desligado por padrão) |
| **T14** | Relato clínico, síntese (conforme uso) | **Google (Gemini)** — **inativo** na ordem padrão | **EUA** | Síntese (só se reativado) | idem T6 | idem T6 | `ia_clinica.py:594-625`; `ia_clinica.py:299-311` (Gemini saiu da cascata em 07/10/2026) |
| **T15** | Telefone, nome, mensagem; **token de sessão do profissional** | **wuzapi** (gateway **não oficial** de WhatsApp) | **A CONFIRMAR** ⚖️ | Enviar lembretes | Consentimento específico (art. 7º, I / art. 11, I) | Cláusulas específicas ⚖️ | `lembrete_service.py:92-114`; `compromisso.dart:159-171`; `db.py:261-267` (`wuzapi_instancias.wuzapi_token`) |
| **T16** | Trânsito de todos os dados da API | **Fly.io** (backend) | **Brasil** (`gru`, São Paulo) — matriz EUA conforme contrato | Hospedar a API | — | Não é transferência se o tratamento ocorre em `gru`; **mas o contrato precisa confirmar** onde há acesso ⚖️ | `fly.toml:2-3` |
| **T17** | CRP informado; devolve nome oficial | **CFP** (`cn-api.cfp.org.br`) | **Brasil** | Verificar registro profissional | Cumprimento de obrigação regulatória (art. 7º, II) | Não há transferência internacional | `crp_service.py:10,30-34` |

### 2.2 Onde estão os números que importam

| Situação | Destinos |
|---|---|
| Com **decisão de adequação** da ANPD reconhecida | **Nenhum** destino do produto. A Resolução CD/ANPD nº 32/2026 reconhece a **União Europeia** (Estados-membros, países do EEE — Islândia, Liechtenstein e Noruega — e instituições da UE) ⚖️ |
| **Sem** decisão de adequação e com dado **sensível de saúde** | **EUA** (T1–T6, T8, T10–T14) e **China** (T7, T8) |
| **Sem** país sequer identificado | **wuzapi** (T15) |

**Consequência prática:** como nenhum destino é adequado, **toda** transferência do mapa depende de
mecanismo contratual (cláusulas-padrão, art. 33, II, "b") ou de salvaguarda específica. E há um caso
(T15) em que nem o país se sabe.

### 2.3 Divergência entre o que o produto promete e o que ele transfere

| Promessa no app | Onde | Realidade verificada |
|---|---|---|
| "Os dados são armazenados localmente no dispositivo do profissional" | `politica_privacidade_page.dart:57` | Contrato, anamnese, telefone e lembretes ficam nos **EUA** |
| "Serviços de IA (OpenAI ou Google Gemini)" | `politica_privacidade_page.dart:71-73` | **Omite Groq** (áudio, EUA) e **DeepSeek** (China); cita Gemini, que está fora da cascata |
| "Transcrição (via OpenAI Whisper)… síntese (via OpenAI GPT-4.1)" | `termos_uso_page.dart:35-36` | Produção: **Groq** + **OpenAI** + **DeepSeek** (fallback) |
| "Nenhum dado clínico é armazenado em servidores externos sem consentimento explícito" | `politica_privacidade_page.dart:63-64` | Não há mecanismo de consentimento implementado para isso |
| "não são armazenados pelos provedores de IA para treinamento" | `politica_privacidade_page.dart:105-108` | Não comprovado; não menciona Groq nem DeepSeek; **sem `store:false`** em nenhum payload |

Item **P0.1** do plano de ação corrige os textos; item **P0.6** remove a afirmação não comprovada.
Enquanto não corrigido, a transferência existe **sem informação adequada ao titular** — o que agrava
qualquer avaliação de risco.

### 2.4 Transparência ativa exigida pela Resolução 19/2024

O art. 17, §2º da Resolução CD/ANPD nº 19/2024 exige que o **controlador publique, na internet, em
português, linguagem simples, clara e acessível**, documento com, no mínimo:

1. forma, duração e finalidade específica da transferência internacional;
2. **país de destino** dos dados;
3. identificação e contatos do controlador;
4. uso compartilhado de dados e finalidade;
5. responsabilidades dos agentes e **medidas de segurança adotadas**;
6. direitos do titular e meios de exercício, incluindo canal de fácil acesso e o direito de
   peticionar contra o controlador perante a ANPD.

**Situação do MentAll PRO: não cumprido.** Não existe página de transferência internacional, e a
Política in-app não informa país de destino. Também não há canal do titular nem encarregado
(`politica_privacidade_page.dart:119-122`) — o que impede cumprir os itens 3 e 6.

Além disso, o art. 17, §1º fixa prazo de **15 (quinze) dias** para o controlador disponibilizar ao
titular, quando solicitado, a íntegra das cláusulas utilizadas, ressalvados segredos comercial e
industrial. Esse prazo precisa entrar no procedimento do canal (documento 13) e no material do
psicólogo (documento 14).

---

## 3. Análise específica: China (DeepSeek)

| Aspecto | Situação |
|---|---|
| **O que sai** | Prompt clínico completo: nome pseudonimizado (primeiro nome + iniciais) + relato clínico integral + abordagem terapêutica — `ia_clinica.py:438-454,656-668` |
| **Como sai** | **Fallback automático**: a ordem padrão é `openai,deepseek` (`ia_clinica.py:296`) e a mesma requisição é reenviada ao provedor seguinte quando o primeiro falha |
| **Quem decide** | O **MentAll**, por configuração de ambiente (`IA_PROVIDER_ORDER`). O profissional **não é avisado nem escolhe** |
| **Quando acontece** | De forma **imprevisível** — depende de indisponibilidade da OpenAI. Em 07/10/2026 o Gemini já havia sido retirado da cascata por falhas medidas (`ia_clinica.py:299-311`) |
| **Decisão de adequação** | **Não há** decisão de adequação da ANPD para a China nesta data ⚖️ |
| **Retenção zero** | **Não configurada** — não há `store: false` nem parâmetro equivalente no payload (`ia_clinica.py:656-668`) |
| **Fiscalização e cooperação internacional** | Não há acordo de cooperação regulatória documentado entre ANPD e autoridade chinesa ⚖️ |
| **Leis de acesso estatal a dados** | ⚖️ **Avaliação jurídica necessária.** A Cláusula 22 das cláusulas-padrão da ANPD (Anexo II da Res. 19/2024) exige que o **importador declare que não identificou leis ou práticas administrativas de seu país que o impeçam de cumprir as cláusulas** — e a Cláusula 19 trata de **notificação de solicitação de acesso por autoridade pública**. Este é o ponto crítico: sem essa declaração e sem garantia operacional de notificação, a cláusula-padrão **não se sustenta** para um país nessas condições. **NÃO CONFIRMADO — validar com advogado.** |
| **Salvaguarda adicional** | A Cláusula 11 das cláusulas-padrão exige **medidas de segurança específicas e proporcionais** para dado sensível. Não há `store:false`, cifra ponta a ponta no provedor nem anonimização efetiva |

**Ponto mais frágil do mapa.** Duas razões:

1. **É uma transferência que o titular não escolheu e o profissional não autorizou** — o consentimento,
   se for o mecanismo, precisa nomear o provedor **e o país**. Consentir "em IA" de forma genérica não
   cobre a China.
2. **A retenção é indefinida do lado do provedor**, porque o produto não impõe retenção zero.

Item **P0.2** do plano de ação trata exatamente disso: **remover da ordem de provedores** (2 horas) ou
**implementar consentimento específico e destacado por pessoa atendida + RIPD específico** (3 dias).
⚖️ A escolha entre as duas é do dono, mas a remoção é a medida tecnicamente mais barata e de maior
redução de risco.

---

## 4. Análise específica: Estados Unidos (Turso/AWS, Groq, OpenAI, Google, Sentry, SMTP)

| Destinatário | Dado | Ponto crítico |
|---|---|---|
| **Turso / AWS** (`aws-us-west-2`, Oregon) | Contrato, anamnese, telefone, lembretes, conta, telemetria, **tokens do wuzapi** | **Sem cifra em repouso** para conteúdo de dado pessoal (`db.py:180-215`; `contrato_service.py:14-15`). O backend está em `gru` (São Paulo), o **banco está nos EUA** — a divergência cria falsa sensação de "dados no Brasil" (`fly.toml:2-3` vs `backend/.env:40`). Também guarda `wuzapi_instancias.wuzapi_token` (`db.py:261-267`), segredo de sessão do profissional |
| **Groq** | **Áudio do relato clínico** | Áudio é o dado mais difícil de anonimizar: contém voz, nome, terceiros e conteúdo clínico. Sem retenção zero declarada no produto. Consta em `transcricao.py:13-20,64-65` e **não** na Política |
| **OpenAI** | Nome pseudonimizado + relato clínico; e-mails via SMTP não (SMTP é Gmail) | Sem `store:false`. É o **primeiro** provedor da cascata, portanto recebe o tráfego principal |
| **Google** | E-mail transacional (Gmail SMTP) e possível síntese (Gemini, inativo) | Gemini fora da cascata desde 07/10/2026, mas segue mencionado na Política — divergência material |
| **Sentry** | Stack trace, sem PII | **Desligado por padrão**, opt-in (`main.dart:73-105`) — risco baixo |
| **OpenAlex** | Descritores clínicos + **e-mail pessoal do profissional como `mailto`** | Não há decisão de adequação; o `mailto` é dado pessoal do profissional indo para base pública internacional (`ia_clinica.py:56-63,83-91`) |

**Sobre os EUA:** ⚖️ não há decisão de adequação da ANPD reconhecendo os EUA. **NÃO CONFIRMADO — validar
com advogado** se algum arcabouço setorial (por exemplo, acordos de cooperação ou certificações
específicas dos provedores) pode ser invocado; a via segura continua sendo **cláusulas-padrão
contratuais** da Res. 19/2024, com avaliação de transferência posterior (Cláusula 18) e de solicitação
de acesso por autoridade (Cláusula 19).

**Sobre a Resolução CD/ANPD nº 32/2026:** a adequação recíproca Brasil–UE **não cobre** nenhum destino
acima. Ela é relevante, porém, para dois cenários: (a) atendimento de titulares europeus pelo produto;
(b) eventual migração de infraestrutura para região europeia como **alternativa de mitigação** enquanto
uma região brasileira não estiver disponível — nesse caso o mecanismo do art. 33, I já estaria
satisfeito. ⚖️ Confirmar escopo exato e prazo de reavaliação (a Resolução prevê reavaliação em 4 anos).

---

## 5. Três cenários de decisão para o dono

> Cada cenário é avaliado por: o que muda, prós, contras, custo estimado e risco que permanece.
> Os custos são ordens de grandeza técnicas, não orçamento.

### Cenário A — Manter a arquitetura e documentar com cláusulas-padrão e garantias

**O que muda:** nada no fluxo. Assinatura das cláusulas-padrão da ANPD com Turso, Groq, OpenAI e
DeepSeek (ou adesão aos contratos-padrão dos provedores, se compatíveis); DPA com o psicólogo listando
os subprocessadores; página pública de transferência; consentimento específico do titular nomeando
provedor e país; registro de consentimento; `store:false` onde o provedor permitir.

| Prós | Contras |
|---|---|
| Menor custo e menor prazo até uma posição documentada | **Não reduz a exposição** — o dado sensível continua saindo, em claro do lado do servidor, para dois países sem adequação |
| Mantém a qualidade da síntese (OpenAI como principal) | O fallback para a China continua acontecendo **sem escolha informada**; cada falha da OpenAI é uma nova transferência |
| Aproveita a infraestrutura já estável (Fly `gru` + Turso) | Depende de o provedor **aceitar** cláusulas-padrão brasileiras e de retenção zero — ⚖️ vários provedores só oferecem contratos-padrão próprios; adaptar exige negociação |
| Caminho natural se o produto crescer e quiser manter performance de IA | Mantém o **dado em claro no Turso** (R1 do RIPD), que o DPA documenta mas não resolve |

**Custo:** baixo em engenharia (2–5 dias), médio em jurídico (revisão e negociação de cláusulas com
4+ fornecedores). **Risco residual: MÉDIO a ALTO.**

### Cenário B — Remover o DeepSeek da cascata e/ou fixar provedor

**O que muda:** `IA_PROVIDER_ORDER` deixa de incluir `deepseek`; a cascata passa a ser apenas
provedores em jurisdição única (ex.: `openai` isolado, com *retry* e mensagem honesta de indisponibilidade
em vez de troca de país). Opcionalmente, exibir ao profissional **qual provedor e país** processaram
cada síntese.

| Prós | Contras |
|---|---|
| **Elimina a China do mapa** — a redução de risco mais barata disponível | Não resolve o problema dos EUA (Turso, Groq, OpenAI continuam) |
| Remove a transferência **não escolhida**; torna o fluxo determinístico e explicável ao titular | Perde-se a redundância: se a OpenAI cair, a síntese falha (mitigável com *retry*, fila e mensagem clara) |
| Torna o consentimento **possível de redigir** (um provedor, um país, uma finalidade) | Se a decisão for manter o DeepSeek, o custo sobe muito: consentimento por titular + RIPD específico + salvaguardas adicionais (Cláusula 11) + auditoria contínua |
| Custo de implementação praticamente nulo | Qualidade/custo por token podem mudar; exige monitorar |

**Custo:** 2 horas para remover; 3 dias se a decisão for manter com consentimento e RIPD específico.
**Risco residual: MÉDIO** (a China sai; EUA permanece).

### Cenário C — Migrar o banco para região brasileira e/ou auto-hospedar o gateway de WhatsApp

**O que muda:**

- **C1:** Turso/libSQL em região brasileira (se disponível) ou migração para Postgres gerenciado em
  região São Paulo, **mantendo o backend em `gru`** — eliminando a incoerência `fly.toml:2-3` vs
  `backend/.env:40`.
- **C2:** hospedar o wuzapi em infraestrutura própria no Brasil, eliminando o destino
  **[A CONFIRMAR]** e o token de sessão em banco estrangeiro (`db.py:261-267`).
- **C3 (complementar):** cifra em repouso no servidor para contrato, anamnese e telefone — item P0.4,
  independente do cenário.

| Prós | Contras |
|---|---|
| **Resolve a maior exposição estrutural**: dado de saúde deixa de repousar em jurisdição sem adequação | Migração de banco tem risco operacional real, e o fallback SQLite (`db.py:15-17`) pode **perder dados durante a janela** — exige desligar o fallback antes (P1.12) |
| Elimina a transferência para a maioria dos fluxos (T1–T3, T10–T12), reduzindo o escopo do art. 33 | Não resolve áudio→Groq nem síntese→OpenAI/DeepSeek (a menos que se migre para IA em região nacional, o que é mais caro e pode reduzir qualidade) |
| Reduz drasticamente o RIPD e o DPA: sobra menos subprocessador para listar | Custo recorrente maior e possível perda de latência/características gerenciadas |
| Auto-hospedar o wuzapi resolve T15 e dá controle sobre um gateway **não oficial** | O gateway continua sendo **não oficial** — o risco de bloqueio pela Meta e de instabilidade permanece; ⚖️ a licitude do uso precisa de avaliação própria (P2.7) |
| Melhora a narrativa de privacidade de forma verificável (não apenas em texto) | Prazo maior: dias a semanas, com testes de migração e de restauração |

**Custo:** alto em engenharia (1–3 semanas somando C1+C2+C3) e recorrente em infraestrutura.
**Risco residual: BAIXO a MÉDIO** (dependendo do que se mantiver de IA externa).

---

## 6. Recomendação técnica

**Recomendação: combinação B + C3 agora, com C1/C2 em seguida.**

| Ordem | Ação | Prazo | Por quê |
|---|---|---|---|
| 1 | **Remover `deepseek` de `IA_PROVIDER_ORDER`** (Cenário B) e registrar a decisão no documento 17 | Imediato (2 h) | Elimina a transferência para a China, que é a de menor defensabilidade e a única que ocorre **por fallback**, sem escolha informada |
| 2 | **Cifrar em repouso no servidor** contrato, anamnese e telefone, ou parar de persistir (C3 / P0.4) | Semana 1–2 (2–3 d) | Reduz o impacto de qualquer incidente no banco estrangeiro; **independe** de onde o banco esteja |
| 3 | **Publicar a página de transferência internacional** (art. 17, §2º da Res. 19/2024) e o canal do titular | Semana 1 (1 d) | Exigência normativa direta; hoje há descumprimento |
| 4 | **Consentimento específico e destacado** por titular para áudio, transcrição, síntese por IA e WhatsApp, **nomeando provedor e país** | Semana 3 (P1.5) | É o que transforma "transferência existente" em "transferência informada" |
| 5 | **Cláusulas-padrão da ANPD** com Turso, Groq e OpenAI + DPA listando subprocessadores | Semanas 3–4 (P1.2) | Mecanismo do art. 33, II, "b"; ⚖️ negociação jurídica |
| 6 | **Migrar o banco para região brasileira** (C1) e, se viável, **auto-hospedar o wuzapi** (C2) | 90 dias | Resolve a exposição estrutural; exige desligar o fallback antes (P1.12) e testar restauração (P2.15) |
| 7 | **Retenção zero explícita** nos payloads de IA (`store:false` ou equivalente) + cláusula de não treinamento | Junto com o item 5 | Reduz o risco de retenção indefinida no provedor |

**Justificativa da ordem:** primeiro o que é **barato e elimina risco** (China, cifra, transparência),
depois o que é **exigência normativa** (consentimento, cláusulas, DPA), depois o que é **estrutural e
caro** (migração de região). O item 1 e o item 2 reduzem mais risco por real investido do que qualquer
outro.

⚖️ Enquanto as decisões 1 e 5 não estiverem tomadas, **não assinar o DPA com a lista definitiva de
subprocessadores** — o documento 04 já registra essa regra (Parte D).

---

## 7. Cláusulas mínimas a exigir de cada subprocessador

Aplicar a **todos** os subprocessadores do mapa (§2.1), sem exceção. Quando o provedor não aceitar
negociação, isso é **dado de decisão** para o documento 17 — e pode inviabilizar o cenário A.

| # | Cláusula | Redação-alvo (mínimo) |
|---|---|---|
| 1 | **Retenção zero / eliminação imediata** | O importador não retém os dados pessoais após o processamento da requisição; dados em memória são eliminados ao término; qualquer retenção residual é limitada a `[prazo]` e justificada, com eliminação certificável |
| 2 | **Não treinamento** | Vedado usar os dados para treinar, ajustar, avaliar, *fine-tune* ou melhorar modelos, produtos ou serviços; vedado uso para benchmark ou avaliação de qualidade fora do escopo |
| 3 | **Finalidade limitada** | Uso exclusivo para a finalidade declarada; vedado tratamento posterior incompatível (Cláusula 10.1, "a" das cláusulas-padrão) |
| 4 | **Localização** | Declarar todos os países onde ocorre tratamento, **inclusive subprocessadores e transferências posteriores** (Cláusula 18); vedada alteração sem aviso prévio de `[30]` dias e direito de oposição |
| 5 | **Subcontratação** | Somente com autorização prévia e por escrito; o subcontratado fica vinculado às mesmas obrigações; o importador responde por ele (Cláusula 18.2, "c") |
| 6 | **Notificação de incidente** | Notificação ao exportador **sem demora injustificada e em até `[24]` horas** da ciência, com natureza, dados, titulares, medidas e recomendação — compatível com o prazo regulatório brasileiro (documento 11) |
| 7 | **Auxílio aos direitos do titular** | Apoio no atendimento dos arts. 18 e 20, com prazo definido (Cláusulas 15.3 e 15.6: 15 dias) |
| 8 | **Segurança e cifra** | Cifra em trânsito e em repouso; medidas específicas para **dado sensível de saúde** e para **crianças e adolescentes** (Cláusulas 11 e 12 e Seção III das cláusulas-padrão) |
| 9 | **Não treinamento e não uso para publicidade** | Vedado uso para marketing, perfilização comercial ou venda |
| 10 | **Solicitação de acesso por autoridade** | Notificar o exportador sobre ordem de acesso, salvo vedação legal, e adotar medidas cabíveis para questioná-la (Cláusula 19) |
| 11 | **Declaração sobre a lei local** | Declarar que não identificou leis ou práticas administrativas que impeçam o cumprimento das cláusulas (Cláusula 22) — **crítico para a China** |
| 12 | **Auditoria e comprovação** | Direito de auditoria documental anual e de solicitar evidências; manutenção de registro das operações (Cláusula 10.1, "h") |
| 13 | **Término e devolução/eliminação** | Eliminação ou devolução ao término, com certificação (Cláusula 20) |
| 14 | **Responsabilidade e regresso** | Reparação de danos e direito de regresso (Cláusula 17) |
| 15 | **Lei e foro** | Legislação brasileira e jurisdição brasileira quando admissível (Cláusula 24) — nos contratos de adesão de provedores estrangeiros, ⚖️ prever alternativa (arbitragem no Brasil ou eleição de foro negocial) |

**Nota sobre forma:** as cláusulas-padrão da ANPD (Anexo II da Res. 19/2024) devem ser adotadas
**integralmente e sem alteração** (art. 16). As cláusulas acima são **adicionais** e não podem excluir,
modificar ou contrariar as cláusulas-padrão (art. 16, §2º). Elas também servem como **lista de
verificação** para o DPA com o psicólogo (Anexo II do documento 04).

---

## 8. O que **não** pode ser resolvido só com contrato

Esta seção existe para evitar a ilusão mais comum neste tipo de projeto: acreditar que assinar o DPA e
as cláusulas-padrão resolve o problema.

| # | Situação | Por que o contrato não resolve |
|---|---|---|
| 1 | **A exposição já ocorre** | Assinar cláusula **depois** de o dado já ter sido transferido não desfaz a transferência. Hoje há dado sensível nos EUA e possivelmente na China. O instrumento regulariza o **fluxo futuro**; o passado precisa de RIPD, decisão registrada e, se houver incidente, comunicação (documento 11) |
| 2 | **Dado em claro no banco estrangeiro** | Nenhuma cláusula cifra o que está gravado em texto puro (`contrato_service.py:14-15`; `db.py:180-215`). Isso é **código**, item **P0.4** |
| 3 | **Fallback automático para outro país** | A troca de provedor é uma **decisão de arquitetura** (`ia_clinica.py:296`). A cláusula pode proibir, mas o sistema continua trocando até o código mudar — item **P0.2** |
| 4 | **Retenção indefinida no provedor** | Sem `store:false` no payload, a cláusula depende da **execução** do provedor. O controle técnico é do produto |
| 5 | **PDF em claro na saída** | A cláusula não alcança o destino (e-mail, mensageiro, pendrive). Precisa de cifra, senha, aviso e auditoria (**P1.16**) |
| 6 | **Perda silenciosa de dados** | `ALLOW_SQLITE_FALLBACK` default `true` (`db.py:15-17`) é comportamento, não contrato. Item **P1.12** |
| 7 | **Segredo e PII em log** | **130.603 ocorrências** do token do webhook em `backend/backend.launchd.log` (`wuzapi_admin.py:47-49`). Rotação e expurgo são operação (**P1.13**) |
| 8 | **Ausência de canal do titular** | O art. 17, §1º e a Cláusula 15.3 fixam prazos que **ninguém consegue cumprir** sem procedimento e porta de entrada (**P1.8**, documento 13) |
| 9 | **Gateway de WhatsApp não oficial (wuzapi)** | O risco de **bloqueio pela Meta** e de instabilidade é de plataforma, não contratual; e a licitude do uso precisa de avaliação própria (**P2.7**) ⚖️ |
| 10 | **Dados de crianças e adolescentes** | Não há campo de responsável nem consentimento no produto (§5.3 do RIPD). Sem isso, a cláusula 12 das cláusulas-padrão não tem como ser cumprida (**P1.15**) |
| 11 | **Destino [A CONFIRMAR] do wuzapi** | Não se clausula o que não se sabe. É preciso **descobrir a região** antes de qualquer salvaguarda |

**Conclusão:** o contrato é **condição necessária, não suficiente**. A ordem correta é
**arquitetura → contrato → informação ao titular**.

---

## 9. Checklist de implementação

### 9.1 Decisão (dono do produto)

- [ ] Cenário escolhido (A, B ou C) registrado com data, responsável e justificativa (documento 17)
- [ ] Decisão sobre o **DeepSeek** tomada e refletida em `IA_PROVIDER_ORDER` (P0.2)
- [ ] Decisão sobre a **região do banco** tomada com cronograma de migração (P0.3)
- [ ] Decisão sobre o **wuzapi** (oficial, auto-hospedado ou descontinuado) tomada (P2.7)
- [ ] Orçamento e responsável nomeados para cada cenário

### 9.2 Descoberta e documentação

- [ ] **Região real do wuzapi em produção** confirmada por escrito `[A CONFIRMAR]`
- [ ] **Região e provedor do SMTP** confirmados
- [ ] **Retenção e uso** dos dados por Groq, OpenAI, DeepSeek, Google e Sentry obtidos **na fonte**
      (documento de política do provedor arquivado, com data de consulta)
- [ ] Mapa de transferência (§2.1) conferido **contra o código em produção**, não contra a memória
- [ ] Página pública de transferência internacional publicada em português (art. 17, §2º)
- [ ] ROPA (documento 03) atualizado com países e mecanismos

### 9.3 Mecanismo do art. 33

- [ ] Cláusulas-padrão da ANPD (Anexo II da Res. 19/2024) adotadas **integralmente e sem alteração**
- [ ] Instrumento firmado com **Turso/AWS**, **Groq**, **OpenAI** e (se mantido) **DeepSeek**
- [ ] Verificação de **transferências posteriores** (Cláusula 18) de cada provedor
- [ ] Cláusula 22 (declaração sobre lei local) obtida de cada importador — **crítica para a China**
- [ ] Cláusulas mínimas da §7 refletidas nos contratos
- [ ] Retenção zero e não treinamento solicitados **por escrito** e, quando possível, **por
      configuração de API**

### 9.4 Informação ao titular

- [ ] Consentimento específico e destacado nomeando **provedor e país** (documento 07)
- [ ] Registro de consentimento com data, versão e escopo no prontuário
- [ ] Aviso de que a **recusa** não impede o atendimento; caminho de prontuário 100% local descrito
- [ ] Textos in-app corrigidos: Groq, OpenAI e DeepSeek com o que cada um recebe (P0.1)
- [ ] Afirmação sobre treinamento removida ou comprovada por provedor (P0.6)
- [ ] Canal do titular e do encarregado publicados (P1.1, P1.8)
- [ ] Prazo de 15 dias para fornecer a íntegra das cláusulas incorporado ao procedimento (art. 17, §1º)

### 9.5 Técnico

- [ ] Cifra em repouso no servidor para contrato, anamnese e telefone — ou parar de persistir (P0.4)
- [ ] `deepseek` removido da cascata (ou consentimento + RIPD específico) (P0.2)
- [ ] `store:false` / retenção zero no payload de cada provedor que suportar
- [ ] **Registro de qual provedor e país** gerou cada síntese (medida nova do RIPD)
- [ ] Token do wuzapi fora da URL, rotacionado e log expurgado (P1.13)
- [ ] `ALLOW_SQLITE_FALLBACK` desligado em produção e `/health` honesto (P1.12)
- [ ] Links de anamnese/contrato com expiração e revogação, sem nome embutido (P1.11)
- [ ] Menores: campo de responsável legal e consentimento específico (P1.15)

### 9.6 Governança

- [ ] DPA assinado com o psicólogo, com o Anexo II preenchido com a lista **verdadeira** (P1.2)
- [ ] RIPD (documento 08) atualizado com o resultado das decisões e arquivado (P1.4)
- [ ] Revisão trimestral registrada, com gatilho obrigatório para novo provedor, país ou campo (P3.1)
- [ ] Revisão jurídica registrada (nome, OAB, data)

---

## Pendências de validação jurídica

1. ⚖️ **EUA:** confirmar que não há decisão de adequação aplicável e que a via é exclusivamente o
   art. 33, II, "b" (cláusulas-padrão) — **NÃO CONFIRMADO — validar com advogado**.
2. ⚖️ **China:** avaliar se as Cláusulas 19 e 22 da cláusula-padrão podem ser cumpridas de boa-fé em
   relação à DeepSeek; sem essa conclusão, a transferência não deve ser mantida sob o Cenário A.
3. ⚖️ **Aceitação de cláusulas-padrão brasileiras por provedores estrangeiros:** verificar, provedor a
   provedor, se o contrato de adesão admite aditivo com as cláusulas da ANPD; se não admitir, o Cenário
   A é inviável sem troca de fornecedor ou adoção do Cenário C.
4. ⚖️ **Resolução CD/ANPD nº 32/2026:** confirmar escopo (países do EEE e instituições da UE), efeitos
   práticos e prazo de reavaliação — e se há outras decisões de adequação em vigor nesta data.
5. ⚖️ **Natureza do dado de voz:** confirmar se o áudio do relato deve ser tratado como dado biométrico
   (art. 5º, II) além de dado sensível de saúde — a resposta muda o nível de salvaguarda exigido.
6. ⚖️ **OpenAlex:** confirmar se o envio de descritores clínicos + `mailto` caracteriza transferência
   internacional de dado pessoal e qual mecanismo se aplica.
7. ⚖️ **wuzapi:** licitude do uso de gateway não oficial do WhatsApp, exposição a bloqueio pela Meta e
   enquadramento contratual; **região de hospedagem ainda [A CONFIRMAR]**.
8. ⚖️ **Transferência posterior:** confirmar se Turso/AWS, Groq, OpenAI e DeepSeek realizam
   transferências posteriores (Cláusula 18) e se isso cria país adicional não mapeado neste documento.
9. ⚖️ **Prazo das cláusulas-padrão:** o art. 2º, parágrafo único da Res. 19/2024 fixou **12 meses**,
   contados da publicação (23/08/2024), para incorporar as cláusulas aos instrumentos contratuais.
   Confirmar a data-limite e a existência de período adicional de tolerância — **NÃO CONFIRMADO na
   leitura feita em 09/10/2026; validar com advogado**.
10. ⚖️ **Revisão jurídica do presente mapa** antes de anexá-lo ao DPA ou de publicá-lo em qualquer
    material ao titular.
