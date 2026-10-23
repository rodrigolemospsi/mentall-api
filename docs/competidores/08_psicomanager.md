# PsicoManager — funcionalidades

**Data do levantamento:** 19–20/10/2026 · **Fonte:** páginas públicas + bundles públicos + probe local com REA + conta trial.
**Perfil:** plataforma **web** (app em Next.js; API principal em **Phalcon/PHP**). Site de marketing em
**React/Vite (Lovable)**. Planos: **Individual Pró R$ 89/mês** e **Plus R$ 119/mês**, **7 dias grátis,
sem cartão**; página de planos promete **75+ funcionalidades em 9 categorias**. Fontes:
`psicomanager.com.br`, `/planos`, `/ecossistema`, `/seguranca`, `/lgpd`, `app2.psicomanager.com`,
`room.psicomanager.com`, `salavirtual.psicomanager.com`, `apip.psicomanager.com`.

> **Natureza:** leitura de **fonte pública**, análise de **assets públicos** e **captura autenticada**
> em conta **trial própria** (20/10/2026), com paciente **sintético** e sem PII. Nenhum documento
> fiscal foi emitido. Todas as afirmações abaixo indicam a evidência: `LI` (li linhas), `MEDI`
> (executei e medi) ou `INFERI` (conclusão a partir de padrão).

## 1. Produto e planos

| Aspecto | Achado | Evidência |
|---|---|---|
| Posicionamento | "O maior e mais utilizado sistema para psicólogos do Brasil"; +40 mil psicólogos, 11 anos, +20 mi sessões/ano | home (`LI`) |
| Planos individuais | **Pró R$ 89/mês** e **Plus R$ 119/mês**; 7 dias grátis sem cartão | `/planos` (`LI`) |
| Plus inclui | IA ilimitada, Human Track ilimitado, 30 cobranças Pix grátis, **NF-e ilimitada**, **Receita Saúde ilimitada** | `/planos` (`LI`) |
| Ecossistema | Agenda, Sala Virtual, IA Clínica, Human Track, App do Paciente, Financeiro + PsicoBank, Receita Saúde + NFS-e, Prontuário | `/ecossistema` (`LI`) |
| Rotas do app | **160 rotas** públicas no `_buildManifest.js` (clientes, agenda, financeiro, fiscal, relatórios, marketing, configurações) | `_buildManifest.js` sha256 `e9c80053…` (`MEDI`) |

## 2. Financeiro / cobrança

| Aspecto | Achado | Evidência |
|---|---|---|
| Recebimento | **Pix, boleto e cartão de crédito**; link de pagamento; cobrança avulsa e por cliente | `/planos` + bundle (`LI`) |
| Gateway | **Asaas** — enum de gateway e formulário de subconta | `_app` sha256 `7d1c16d6…` (`LI`) |
| Carteira própria | **PsicoBank**: subconta, KYC, dados comerciais, chave Pix para saque, extrato e histórico | rotas `/financeiro/psicobank/*` + endpoints `/sistema/psico-bank/*` (`LI`) |
| Taxas PsicoBank | Cartão **3,09%** à vista / **3,49%** parcelado (até 6x); **Pix R$ 2,59**; **boleto R$ 2,59**; **saque R$ 3,00** | `_app` (`LI`) |
| Prazos | Cartão a partir de **30 dias**; Pix **1 dia útil**; boleto **3 dias úteis** | `_app` (`LI`) |
| Fiscal | **NFSe** (painel, configuração, numeração) e **Receita Saúde** (listagem e integração) | rotas + `/planos` (`LI`) |
| Repasses | Repasses de convênio, ao profissional e alocação de salas | rotas `/financeiro/repasses/*` (`LI`) |

**Leitura:** o financeiro do PsicoManager é um **produto completo**: gateway (**Asaas**) + **carteira
própria** (PsicoBank) + **fiscal** (NFSe/Receita Saúde) + **repasse de clínica**. Não é "registro de
recebimento": é **meio de pagamento e conta digital**.

## 3. Mensagens profissional → paciente

| Aspecto | Achado | Evidência |
|---|---|---|
| Canais | **WhatsApp**, **SMS**, e-mail e push; "notificações por WhatsApp" e "envios ilimitados por e-mail/push" | `/planos` (`LI`) |
| Lembretes | Lembrete de sessão por WhatsApp antes do horário; template de e-mail de lembrete de cobrança | bundle (`LI`) |
| Créditos | WhatsApp e SMS são **créditos** (Plus inclui créditos "limitados"/"grátis") | `/planos` + bundle (`LI`) |
| App do paciente | Agendamento/remarcação, diário de emoções, tarefas, anamnese, recibos e **pagamento de sessões** | `/planos` (`LI`) |
| Provedor do WhatsApp | **não observado no cliente**: o app chama apenas a própria API (`/psico/config/enviar-wpp-teste`); o fornecedor roda no servidor | `NÃO ENCONTREI` no bundle (`LI`) |

**Leitura:** o diferencial é o **canal + automação + portal do paciente**. O provedor de WhatsApp
(oficial × não oficial) só se confirma com captura autenticada ou documentação — **não** pelo bundle.

## 4. Teleconsulta

| Aspecto | Achado | Evidência |
|---|---|---|
| Sala própria | **LiveKit** — `VITE_LIVEKIT_URL=https://api-live-kit.psicomanager.com` no bundle público da sala | `room` sha256 `ec24c3d2…` (`LI`) |
| Front da sala | React/Vite em `room.psicomanager.com` (e `room-psico.psicomanager.com`); cliente LiveKit + Socket.IO | bundle (`LI`) |
| API da sala | **NestJS** em `api-room.psicomanager.com` (`Cannot GET /` em JSON) | `MEDI` |
| Legado/white-label | `salavirtual.psicomanager.com` é uma sala **Angular da Neft** (`api.neft.com.br/organizations/*`), multi-tenant, com iugu, Pagar.me, Wootric, ProfitWell, Bugsnag e Minhas Métricas | probe REA `ev_022138b4…` (`LI`/`MEDI`) |
| Alternativa | **Google Meet** como preferência de sala (`google_meet`) | bundle (`LI`) |
| Health da sala | `https://api-live-kit.psicomanager.com/` → **200 "OK"** | `MEDI` |

**Leitura:** há **duas gerações** de teleconsulta: a sala **Neft** (white-label, Angular, aparenta ser
legado/parceiro) e a sala **própria em LiveKit** (React + NestJS). A LiveKit é a mesma escolha
recomendada em `docs/custos_teleconsulta.md`.

## 5. IA e prontuário

| Aspecto | Achado | Evidência |
|---|---|---|
| IA | "Resumo e Transcrição pela **IA PsicoManager**"; insights por paciente; evolução com prompt personalizado; digitalização de documentos | `/planos` + bundle (`LI`) |
| Transcrição | Serviço separado em **NestJS**: `transcrition-psi.psicomanager.com/sistema/util/timeline-sessao` (exige `time_unix` e `cod_empresa`) | `MEDI` |
| Provedor do modelo | **não observado** no cliente; nenhuma string de OpenAI/Gemini/Groq/DeepSeek no bundle público analisado | `NÃO ENCONTREI` (`LI`) |
| Prontuário | Rotas de clientes, anamnese, anotações, documentos, formulários por abordagem, recursos terapêuticos, Human Track | `_buildManifest.js` (`LI`) |

## 6. Stack e arquitetura observada

| Camada | Stack | Evidência |
|---|---|---|
| Marketing | **React + Vite**, artefato **Lovable** (`__l5e`, `~flock.js`), **Supabase** (`/rest/v1/site_visibility`) | `analyze-web-bundle` `ev_857621a0…` (`LI`) |
| App | **Next.js Pages Router** (`_next/static`, `__NEXT_DATA__`) | `MEDI` |
| API principal | **Phalcon/PHP** — `VITE_PHALCON_API_URL=https://apip.psicomanager.com/v1/1003` | bundle da sala (`LI`) |
| Sala | **LiveKit** + **NestJS** (`api-room`) | bundle + `MEDI` |
| Transcrição | **NestJS** (`transcrition-psi`) | `MEDI` |
| Infra | **Cloudflare** (headers), **AWS S3** (assets da Neft), fontes Adobe/Typekit | headers + bundles (`LI`/`MEDI`) |
| Analytics | **Tinybird** (`api.tinybird.co`) no site de marketing (`flock.js`) + trackers de marketing | bundle (`LI`) |

## 7. LGPD e terceiros observados nas páginas públicas

O **cadastro** (`app2/cadastro-novo`) carrega, antes de qualquer login: **Google Analytics (3 IDs)**,
**Google Ads**, **Meta Pixel (2 IDs)**, **HubSpot (portal 50664664)**, **Microsoft Clarity**, **VWO**,
**LTRCK** (Brasil), **Bing** e **Pipz** (`loader.pipz.io`). O **login** carrega o subconjunto
GA/Ads/Meta/Clarity/VWO/Bing. O site de marketing ainda usa **Supabase** e um snippet próprio de
tracking (`core.psicomanager.com/api/v1/track/hit`). Evidência: capturas `ev_c1d02095…` e
`ev_8e471db7…` (`MEDI`). O SDK do **Smooch/Zendesk** não apareceu nas páginas públicas, mas na
**área logada** a captura confirmou `cdn.smooch.io`/`media.smooch.io` (`ev_06fb3eba…`).

> **Cuidado:** a página `/seguranca` afirma **"criptografia ponta a ponta"**. A arquitetura observada
> (Next.js → API PHP → serviços) é compatível com **TLS em trânsito** e criptografia em repouso, mas
> **não** prova E2E. A afirmação é **marketing**, não uma verificação técnica (`INFERI`).
> O bundle da sala expõe um `VITE_KEY_SALT_AES_256` fixo. **Salt não é chave**; sem saber como é usado,
> não se pode afirmar vulnerabilidade — fica como **ponto a verificar** (`INFERI`).

## 8. Mapa de módulos (rotas públicas do app)

- **Clínico:** `/clientes/*` (cadastro, dashboard, anamnese, anotações, documentos, sessões,
  preferências, recursos/Human Track), `/clientes/grupos/*`, `/recursos-terapeuticos`.
- **Agenda:** `/agenda`, `/agendamentos-online`, `/config/agenda/agenda-e-salas`.
- **Financeiro:** `/financeiro/transacoes/*`, `/financeiro/cobrancas/*`, `/financeiro/notafiscal/*`,
  `/financeiro/receita-saude/*`, `/financeiro/psicobank/*`, `/financeiro/repasses/*`.
- **Marketing:** `/marketing/*` (agendamento online, página, serviços), `/novolead`.
- **Clínica/plano:** `/minha-clinica/*` (plano, assinaturas, benefícios, PsicoClub, logs, NF,
  exportar/importar registros).
- **Relatórios:** `/relatorios/*` (sessões, anotações, financeiro, dashboards, recibo anual,
  sala virtual).

## 9. Achados do probe REA (19/10/2026)

- `www`: bundle `ev_857621a0…` — **React/Vite**, rotas do site, 1 endpoint (`/api/publico/politicas`);
  página `ev_90cb6e18…`; cenário `ev_d0ca109b…` — Supabase `site_visibility` e tracking para `core`.
- `app2/login`: cenário `ev_8e471db7…`; `app2/cadastro-novo`: cenário `ev_c1d02095…` — Next.js e
  trackers listados em §7.
- `room`: cenário `ev_8c61c76b…`; bundle `ec24c3d2…` — LiveKit e config da sala.
- `salavirtual`: cenário `ev_022138b4…` — Neft/iugu/Pagar.me/Wootric/ProfitWell.
- Bundles: `www/index` `1849cddd…`, `www/client` `9c3d09e4…`, `app2/_app` `7d1c16d6…`,
  `app2/_buildManifest` `e9c80053…`, `salavirtual/main` `002b724d…`.

## 10. Documentos do paciente (captura autenticada)

> Captura de **20/10/2026** em conta **trial própria**, com paciente **sintético** (“Paciente Teste
> MentAll”) e sem PII. **Nenhum documento fiscal foi emitido.** Rotas observadas:
> `/clientes/gerenciar/documentos/…`, `/config/modelos/documentos`, `/config/modelos/anamnese`,
> `/config/modelos/formularios-sessao`, `/config/modelos/recursos-terapeuticos`,
> `/minha-clinica/registros-clinica/exportar-registros`, `/minha-clinica/logs/logs-sistema` e
> `/config/usuarios/permissoes`.

### 10.1 Tipos de documento (16)

`Atestado`, `Declaração`, `Contrato`, `Recibo de Pagamento`, `Recibo Anual IRPF`,
`Testes Psicológicos`, `Arquivos Gerais Sessão`, `Anamnese`, `Prontuários Gerais`, `Laudo`,
`Relatórios Psicológicos`, `Parecer`, `Arquivos Gerais Convênio`, `Comprovante Sessões Realizadas`,
`Recurso Intervenção`, `Outros`.

### 10.2 Modelos pré-definidos (13)

| Tipo | Modelo |
|---|---|
| Atestado | Res. CFP nº 06/2019 — modelos 1 e 2 |
| Declaração | Res. CFP nº 06/2019 — modelos 1 e 2 |
| Contrato | **Contrato Terapêutico** |
| Contrato | Autorização para acompanhamento psicoterapêutico de crianças e adolescentes |
| Contrato | Termo de autorização para menores em atendimento psicológico **online** |
| Laudo | Laudo Psicológico |
| Parecer | Parecer Psicológico |
| Relatório | Relatório Psicológico (Res. CFP nº 06/2019) |
| Recibo | Recibo |
| Recibo | Recibo anual IRPF |
| Comprovante | Comprovante de Sessões Realizadas |

**Criação:** título + tipo + modelo (opcional) + **upload** (`.doc/.docx/.pdf/.ppt/.xls/.csv/.jpg/.png/.odt`,
1 arquivo, até 25 MB) **ou** editor de texto rico com marcadores dinâmicos. A lista do paciente tem
colunas **Assinado?** e **Disponível no App do Paciente?**.

### 10.3 App do paciente, assinatura e fiscal

- **App do Paciente:** a aba “Preferências” do paciente permite habilitar módulos como pagamentos,
  anamnese, agendamento/reagendamento, **Diário das Emoções** e tarefas; há 4 modelos de diário.
- **Assinatura Digital:** a tela responde **“Você não tem acesso a Assinatura Digital! Assine o
  psicomanager para liberar”** na conta trial — é módulo pago.
- **NFSe:** a tela “Configurações NFSe” pede certificado e login da prefeitura; não emiti.
- **Receita Saúde:** tela de integração com o **gov.br** (procuração e autorização); não emiti.
- **Exportação/LGPD:** prontuários em `.xls`, **documentos de todos os clientes em `.zip`** e backup
  de anotações de sessão em `.xls` (últimos **90 dias**).
- **Auditoria:** “Logs do sistema” e “Logs de notificações”; **permissões por módulo** (financeiro,
  clientes etc.) para profissionais/atendentes.

**Evidência:** `ev_6110d02c…` (modelos/LGPD), `ev_258c6ac6…` (paciente/termos), `ev_b6d48bdc…`
(criação do paciente), `ev_71690812…` (documentos por paciente), `ev_5621ca50…` (modal), `ev_6424f1fc…`
(tipos), `ev_ae7d651f…` (editor), `ev_d9f0a38d…` (modelos pré-definidos), `ev_3ce41914…` (documento
de teste criado).

## 11. LGPD: documentos e controles

### 11.1 Inventário público

| Documento | Situação em 20/10/2026 | Evidência |
|---|---|---|
| **Termos de Uso** | **Existe** — v1, vigente 20/07/2026, `/termos-de-uso` 200 | `MEDI` + `ev_258c6ac6…` |
| **Política de Privacidade** | **Não publicada** — `/privacidade` 404, `/politica-de-privacidade` 404 e a API de detalhe 404 | `MEDI` |
| Lista de políticas (API) | Retorna **apenas `termos-de-uso`**; não há item de privacidade | `MEDI` |
| Página **LGPD** | Existe, com FAQ; os links para `/privacidade` e `/termos` estão **quebrados** | `ev_d637d171…` |
| Página **Segurança** | Existe; afirma “criptografia ponta a ponta”, backups e LGPD/CFP | `ev_6110d02c…` |

**Contradição documental:** os Termos §10.1 dizem que a **Política de Privacidade** “integra
inseparavelmente” o contrato, e a FAQ da LGPD remete a ela; o documento **não está publicado**.

### 11.2 O que os Termos de Uso dizem (v1)

- Empresa: **PSICO GESTOR TECNOLOGIA LTDA**, CNPJ **29.983.313/0001-99** (Uberlândia/MG).
- §5.5: pagamentos por **Asaas** — confirma o gateway também no texto público, não só no bundle.
- §6.2.5–6.2.6: o profissional responde pelo tratamento dos dados sensíveis; a **guarda** pela
  PsicoManager ocorre **enquanto o contrato estiver ativo e os pagamentos em dia**.
- §5.6.1 e §7.1.8: após **1 ano** de inadimplência, os dados do Usuário são **removidos
  permanentemente**.
- §10.1: a Política de Privacidade integra os Termos (documento ausente).
- §14: contato `contato@psicomanager.com.br` / telefone.

### 11.3 FAQ da LGPD (respostas)

- **Dados sensíveis:** definição legal + “registros de atendimento clínico se enquadram como dados
  sensíveis”.
- **Compartilhamento:** “**Não**. … Não vendemos, compartilhamos ou repassamos seus dados ou os dados
  de seus pacientes a qualquer terceiro…”. ⚠️ A página pública e a área logada carregam **trackers de
  terceiros** (GA, Google Ads, Meta, HubSpot, Clarity, VWO, LTRCK, Pipz, Smooch/Zendesk) — isso **não
  prova** envio de dado clínico, mas **contradiz a literalidade** da resposta e exige verificação.
- **Cancelamento:** “garantimos a guarda dos registros de pacientes por até **5 anos**, em conformidade
  com a **Resolução CFP nº 01/2009**”; backup por e-mail em até 10 dias úteis. ⚠️ Conflita com os
  Termos (guarda condicionada a pagamento; exclusão após 1 ano de inadimplência) e a referência
  **01/2009** deve ser conferida frente à **Res. CFP 09/2024**.
- **Direitos:** canal `privacy@psicomanager.com.br`, resposta “no prazo previsto pela LGPD”.
- **Tratamento:** “apenas para as finalidades previstas nos Termos de Uso e na Política de Privacidade”
  — de novo, a política citada não está publicada.

### 11.4 Controles observados no app

- **Exportação** de prontuários/documentos/anotações (§10.3) e **logs** de sistema/notificações.
- **Permissões por módulo** para profissionais e atendentes.
- **Não encontrei**, nas rotas visitadas, tela de **consentimento do paciente**, **DPO/encarregado**
  nomeado, **lista de subprocessadores** ou **prazo de retenção configurável** (`NÃO ENCONTREI`
  nesta busca).

**Evidência:** `ev_d637d171…` (FAQ), `ev_258c6ac6…` (Termos), `ev_6110d02c…` (exportação/logs/
permissões) e as respostas `MEDI` da API pública de políticas.

## 12. Pendências

O que a captura autenticada **confirmou**: documentos/tipos/modelos, exportação, logs, permissões,
trackers na área logada, NFSe/Receita Saúde (UI), assinatura digital paga e app do paciente.

### 12.1 Confirmações da captura ativa (20/10/2026)

| Fluxo | Achado | Evidência |
|---|---|---|
| **LiveKit** | Sessão sintética agendada (21:00–21:30), sala aberta em `/room/<uuid>` e **`POST https://api-room.psicomanager.com/livekit/token`**; UI “Só você está aqui”; dispositivos fake; **sem gravação** e sem segundo participante | `ev_4e0c042d…`, `ev_4ae960df…` |
| **Cobrança** | “Nova cobrança” → **Cobranças Avulsas** → R$ 1,00 → `POST /v1/1003/psico/financeiro/verificar-antes-gerar-cobranca` + **`POST /v1/1003/psico/financeiro/gerar-cobranca`** → “lembrete de cobrança gerado” | `ev_81b53206…`, `ev_92048851…` |
| **Gateway** | **Asaas não aparece no cliente** — a cobrança é criada pela API própria; o Asaas é server-side e está nos **Termos §5.5** | `ev_92048851…` + Termos |

> **Não paguei e não enviei** a cobrança de teste. O fluxo de **split/repasse/webhook** do Asaas não
> foi exercitado (exigiria pagamento real). A cobrança avulsa não apareceu na aba “Cobranças
> PsicoBank” — o que é consistente com uma cobrança sem conta PsicoBank configurada; não investiguei
> mais para não gerar efeito financeiro.

O que **continua em aberto**:
1. **WhatsApp:** provedor oficial × não oficial — o app chama só a própria API; o fornecedor é
   server-side (`NÃO ENCONTREI` no cliente).
2. **IA:** modelo/provedor por trás de `transcrition-psi` e do resumo — não observado no cliente.
3. **Pagamento real:** a **geração** da cobrança foi confirmada (§12.1), mas **não paguei**; o fluxo
   ponta a ponta do **Asaas** (split, repasse, webhook, conciliação) não foi exercitado.
4. **Sala real:** o **LiveKit** foi confirmado pelo `POST /api-room/livekit/token`; não houve segundo
   participante nem gravação. Falta avaliar mídia real/qualidade e o fluxo do paciente entrando.
5. **Fiscal:** não emiti NFSe nem Receita Saúde (só inspeção de UI — exige dados fiscais reais).
6. **LGPD:** confirmar com o fornecedor por que a **Política de Privacidade** não está publicada e
   reconciliar Termos × FAQ (retenção/pagamento) e a referência à Res. CFP 01/2009.
7. **Dados sintéticos:** a conta trial contém o paciente “Paciente Teste MentAll”, um documento de
   teste, uma sessão às 21:00 e uma **cobrança de R$ 1,00 não paga**; remover manualmente.

**Fora do escopo:** APK do app do paciente (exige aval jurídico — ToS + Lei 9.609/98).

## 13. Implicações para o MentAll

- **Financeiro:** o PsicoManager transformou financeiro em **meio de pagamento + conta digital**
  (Asaas + PsicoBank + NFSe/Receita Saúde). Nosso gap é maior do que "gerar Pix": inclui **carteira,
  repasses e fiscal**.
- **Mensagens:** canal + **créditos** + **app do paciente**. O ponto crítico continua sendo **canal
  oficial** (nosso `wuzapi` é não oficial).
- **Teleconsulta:** a escolha de mercado é **LiveKit** (igual ao nosso plano), com **Google Meet**
  como fallback e uma sala white-label legada. Não precisamos inventar stack.
- **IA:** eles empacotam como "IA PsicoManager" e escondem o provedor. Isso é **posicionamento**, não
  tecnologia — e reforça a importância de **transparência de provedor** no nosso diferencial LGPD.
- **Documentos:** o PsicoManager tem **16 tipos**, **13 modelos** (incl. CFP 06/2019), upload,
  editor com marcadores, assinatura (paga) e coluna **“Disponível no App do Paciente?”**. O MentAll
  gera PDFs, mas **não** tem biblioteca de modelos, upload por paciente nem disponibilização no portal.
- **LGPD documental:** os Termos existem e são versionados; a **Política de Privacidade não está
  publicada** e a página LGPD tem links quebrados. Nosso pacote `docs/lgpd/` é mais completo — isso é
  **argumento verificável** de Due Diligence, não só marketing.
- **Retenção:** a tensão “guarda só com pagamento em dia” × “5 anos após cancelamento” é um ponto
  para **não copiar**; nosso `docs/lgpd/10` precisa deixar a regra explícita e compatível com o CFP.
- **Privacidade:** a página pública de cadastro carrega **muitos trackers** antes do consentimento
  explícito. É um contraste com o nosso **local-first** e um argumento de venda verificável.

> Cruzar com `docs/lgpd/18_comparativo_concorrentes.md`, `docs/lgpd/10_politica_de_retencao_e_descarte.md`,
> `docs/custos_teleconsulta.md` e `07_sintese.md`. Nada aqui é decisão fechada.
