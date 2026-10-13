# 15 — Lojas: Google Play e Apple App Store

**Versão:** 1.1 · **Data:** 13/10/2026
**Produto:** MentAll PRO (cliente Flutter `1.0.49`, backend FastAPI)
**Natureza:** documento de trabalho — **rascunho para revisão**. Não é parecer jurídico e **não** é
declaração final de loja. Contém textos prontos para colar no console **somente** quando o item de
bloqueio correspondente estiver resolvido. ⚖️ = depende de validação jurídica.
**Base:** `01_diagnostico_lgpd.md`, `02_plano_de_acao.md`, `03_data_mapping_e_ropa.md`,
`04_papeis_e_contrato_controlador_operador.md`, `_base_factual.md`, `tasks/lojas_app.md` do
repositório do app e verificação direta no código em 09/10/2026.

---

## 0. Regra de ouro deste documento

> **Nenhuma declaração de loja pode afirmar comportamento que o produto não tem.**
> Onde o comportamento ainda não existe, a linha diz **"NÃO DECLARAR AINDA — depende do item
> P0.x / P1.x"**. Declarar cedo para "destravar a publicação" transforma uma pendência técnica em
> infração de política de loja, com risco de remoção do app e de encerramento da conta de
> desenvolvedor — bem pior do que atrasar o lançamento.

**Consequência prática:** hoje o app **não está pronto para enviar declaração de loja**. O
impedimento não é o formulário: é a ausência de política/termos em URL pública, a ausência de
exclusão de conta e as divergências materiais entre o que os textos in-app dizem e o que o código
faz (`_base_factual.md` §5; `01_diagnostico_lgpd.md` §4.3 e §4.11).

---

## 1. Requisitos e onde estamos

| # | Requisito | Situação hoje (09/10/2026) | Bloqueio | Ação |
|---|---|---|---|---|
| R1 | **Política de Privacidade em URL pública** (link no Play Console, no App Store Connect e **dentro** do app) | **Não atende.** Só existe como página in-app (`lib/screens/lgpd/politica_privacidade_page.dart`); o site irmão `site-mentall-pro` tem apenas `index.html` (`tasks/lojas_app.md:32-34`) | **Sim — bloqueio total.** Play exige URL ativa, publicamente acessível e **sem PDF**; Apple exige o link no metadata **e** dentro do app | **P0.5** — publicar as duas URLs e linká-las no app |
| R2 | **Termos de Uso em URL pública** | **Não atende.** Mesmo caso (`lib/screens/lgpd/termos_uso_page.dart`) | Sim | **P0.5** |
| R3 | **Exclusão de conta no app** (Play e Apple) | **Não atende.** Nenhuma ocorrência de exclusão de conta em `lib/` nem no backend (busca por `excluir.*conta`, `excluirConta`, `delete.*account`: **zero resultados**); `excluirPaciente` é hard delete **sem chamador** (`lib/services/paciente_service.dart:113-166`) | **Sim — reprovação automática.** Play: quem permite criar conta **precisa** permitir exclusão; Apple 5.1.1(v): "you must also offer account deletion within the app" | **P1.9** — fluxo ponta a ponta |
| R4 | **URL externa de solicitação de exclusão de conta** (Play) | **Não atende.** Nenhuma página publicada | **Sim** | **P1.9** + **P0.5** (mesma entrega de site) |
| R5 | **Google Play — Data Safety** | **Não produzido** (`_base_factual.md` §8, item 10). Preenchimento proposto na §2 — hoje várias respostas seriam **incorretas** porque os textos in-app omitem Groq e DeepSeek | Sim | **P1.10**, condicionado a **P0.1** e **P0.2** |
| R6 | **Google Play — formulário de declaração de apps de saúde** | **Não preenchido.** Todos os desenvolvedores precisam preenchê-lo, inclusive para certificar que **não** oferecem recursos de saúde | Sim | Preencher declarando "Suporte à decisão clínica" (software de prontuário para profissional habilitado) — ver §2.6 |
| R7 | **Play — link da Política de Privacidade dentro do app** | **Atende parcialmente.** Existe tela in-app, mas o texto está desatualizado e divergente do código (`politica_privacidade_page.dart:71-73,105-108`) | Sim | **P0.1**, **P0.6** |
| R8 | **Apple — App Privacy (nutrition labels)** | **Não produzido.** Proposta na §3 | Sim | **P1.10** |
| R9 | **Apple — política de privacidade no metadata do App Store Connect e acessível no app** (5.1.1(i)) | **Não atende** (R1) | Sim | **P0.5** |
| R10 | **Apple — `ITSAppUsesNonExemptEncryption`** | **Não atende.** Chave **ausente** de `ios/Runner/Info.plist` (verificado: nenhuma ocorrência). Sem ela, o App Store Connect exige o questionário de conformidade de exportação a cada envio | Não bloqueia, mas atrasa cada submissão e pode gerar pendência | **P2.16** — declarar a chave (o app usa cifra AES-GCM própria e HTTPS; a classificação correta **depende de análise de export compliance**, não presumir `NO`) |
| R11 | **Apple — `NSFaceIDUsageDescription`** | **Não atende.** Chave **ausente** de `ios/Runner/Info.plist` (verificado: nenhuma ocorrência de `FaceID`). O app usa biometria (`auth_service.dart:203-215`) | **Sim, se a biometria estiver ativa no iOS** — a Apple exige a chave para APIs que acessam Face ID | **P2.16** |
| R12 | **Categoria de Saúde / Medicina** | **Não decidida.** `tasks/lojas_app.md:31` registra "declaração de Saúde" pendente | Sim | Decidir com R6 e §5.3 |
| R13 | **Permissões declaradas e justificadas** | **Atende parcialmente.** Manifesto Android traz `RECORD_AUDIO`, `INTERNET`, `USE_BIOMETRIC`, `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE` (`android/app/src/main/AndroidManifest.xml:2-8`) com `allowBackup="false"` e `usesCleartextTraffic="false"` (`:13-14`). iOS tem `NSMicrophoneUsageDescription` (`ios/Runner/Info.plist:25-26`) mas **não** tem Face ID | Parcial | **P2.16**; conferir no Console a justificativa de `SCHEDULE_EXACT_ALARM` (uso de alarme de sessão) |
| R14 | **Faixa etária / classificação de conteúdo** | **Não atende.** Play exige classificação IARC para todo app; Apple exige age rating no App Store Connect | Sim | Preencher os questionários (ver §2.6 e §3.6) |
| R15 | **Conta de desenvolvedor** | **Não atende.** `tasks/lojas_app.md:40` registra as duas contas como pendentes | Sim | Play: taxa única de **US$ 25,00** (https://support.google.com/googleplay/android-developer/answer/6112435?hl=pt-br). Apple: **US$ 99 por ano de associação** (https://developer.apple.com/programs/enroll/) |
| R16 | **Assinatura / cobrança (RevenueCat, Play Billing, StoreKit)** | **Não implementado** (`tasks/lojas_app.md:38-39`) | Não bloqueia o envio, mas bloqueia a monetização | Planejar; se o app passar a coletar mais dado (histórico de compras, plano), **refazer** Data Safety e App Privacy (§7 de `17_registro_de_decisoes_e_revisoes.md`) |
| R17 | **Keystore de produção (Android)** | **Não existe** — integração pronta (`android/app/build.gradle.kts:10-18,45-62`), keystore ausente (`tasks/lojas_app.md:35-36`) | **Sim** | Gerar e guardar fora do repositório |
| R18 | **Screenshots App Store** | **Não atende.** Play pronto (5 imagens); faltam 6.7", 6.5" e 5.5" (`tasks/lojas_app.md:29-30`) | Sim | Produzir |
| R19 | **Pré-lançamento em aparelho real** (login, PIN, biometria, áudio, IA, backup/restore, WhatsApp) | **Não registrado** (`tasks/lojas_app.md:42-43`) | Sim | Executar antes do envio |
| R20 | **Divulgação de compartilhamento com IA de terceiros e permissão explícita** (Apple 5.1.2(i)) | **Não atende.** O aviso de IA no app só fala de revisão humana (`lib/widgets/lgpd/aviso_privacidade_ia_card.dart`) e não menciona envio a terceiros (`_base_factual.md` §7) | **Sim** — a Apple exige divulgação clara de onde o dado é compartilhado, **inclusive com IA de terceiros**, e permissão explícita | **P0.1** + **P1.5** |
| R21 | **Honestidade de descrição técnica em relação aos provedores** | **Não atende.** Política cita "OpenAI ou Google Gemini" (`politica_privacidade_page.dart:71-73`); Termos citam "OpenAI Whisper"/"OpenAI GPT-4.1" (`termos_uso_page.dart:35-36`); produção usa **Groq** (áudio) + **OpenAI** + **DeepSeek** (fallback) | **Sim** | **P0.1**, **P0.2** |
| R22 | **Declaração de dispositivo médico regulamentado** (Apple) | **Não verificada.** Existe formulário próprio no App Store Connect ("Declare Regulated Medical Device Status" — https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/) | A confirmar | Responder "não é dispositivo médico regulamentado" **e garantir que o texto não sugira diagnóstico/tratamento** (ver §5.4) |
| R23 | **Revisão humana da saída de IA declarada** | **Atende.** Gate de revisão humana antes de salvar (`01_diagnostico_lgpd.md` §4.4) | Não | Manter e **declarar** — é o principal argumento de segurança do produto |
| R24 | **Demo seed "Linda M. Tester" em instalação nova** | **Risco aberto.** `demo_data_service.dart:35-78`; `main.dart:192` | Não bloqueia, mas confunde o revisor e mistura dado fictício com prontuário | **P2.17** |
| R25 | **Conta de demonstração para o revisor** (Apple) | **Não preparada** | A confirmar | A Apple exige demo account ou modo demo completo quando há login |

---

## 2. Google Play — Data Safety preenchido linha a linha

### 2.1 Como o Play define "coleta" e "compartilhamento" (é isso que decide as respostas)

Fonte: [Fornecer informações para a seção "Segurança dos dados" do Google Play](https://support.google.com/googleplay/android-developer/answer/10787469?hl=pt-br)

- **Coletar = transmitir informação do app para fora do dispositivo.** Dado que fica **só** no
  aparelho **não** é declarado. Dado pseudonimizado **é** declarado se puder ser razoavelmente
  reassociado a alguém (vale para a pseudonimização parcial de nome em `ia_clinica_service.dart:185-198`).
- **Compartilhar = transferir dado do usuário a terceiros.** **Não** precisa ser declarado como
  compartilhamento a transferência para um **"provedor de serviços"** que processa em nome e sob
  instruções do desenvolvedor.
- **Processamento efêmero**: entra na resposta do formulário, mas não é exibido, se o dado só existir
  em memória pelo tempo da requisição. **Nossos fluxos não se qualificam** (não há retenção zero
  configurada; `ia_clinica.py:627-690`; sem `store:false`).
- A declaração é de **coleta e compartilhamento**, e o Google declara que revisa o app contra o
  formulário; a Developer Programme Policy exige seção **clara e precisa** para todo app
  ([Developer Programme Policy](https://support.google.com/googleplay/android-developer/answer/16313518)).

⚠️ **Ponto decisivo para o nosso caso:** Groq, OpenAI, DeepSeek e Gemini **só podem ser tratados como
"provedores de serviços" se houver contrato de operador/DPA com cada um**. Hoje **não há** lista de
subprocessadores contratada (`04_papeis_e_contrato_controlador_operador.md`, Parte C e D). Portanto,
na data de hoje, a resposta honesta é **"Sim, compartilhado"** — ou se assina o DPA e se passa a
responder "Não compartilhado (provedor de serviços)". Essa escolha está registrada como decisão
pendente em `17_registro_de_decisoes_e_revisoes.md`.

**Precedente de mercado (`18_comparativo_concorrentes.md`):** a **Copilloto** nomeia cada
subprocessador (Brevo, Asaas, NFe.io, Google/Gemini, Apify) e declara contrato com cada um — é o
modelo que **sustenta** a resposta "não compartilhado (provedor de serviços)". É o caminho a seguir se
a decisão **D9** for contratar os DPAs.

### 2.2 Tabela de declaração (Data Safety)

Categorias e nomes conforme a lista oficial do Play. "Criptografia em trânsito" = Sim em todas as
linhas (todo o tráfego é HTTPS; `AndroidManifest.xml:14` com `usesCleartextTraffic="false"` e
`network_security_config`).

| Categoria (Play) | Tipo de dado | Coletado? | Compartilhado? | Finalidade | Obrigatório ou opcional | Evidência no produto |
|---|---|---|---|---|---|---|
| Informações pessoais | **Nome** | **Sim** | **Sim** — OpenAI, DeepSeek, Gemini (nome da pessoa atendida vai no prompt); Groq, se o áudio contiver o nome | Funcionalidade do app | Obrigatório (fluxo de prontuário/síntese) | `ia_clinica.py:438-454`; `main.py:890-893` |
| Informações pessoais | **Endereço de e-mail** | **Sim** | **Sim** — provedor SMTP (Gmail) para verificação/reset; hoje **não** contratado como provedor de serviços | Gerenciamento da conta | Obrigatório | `usuarios.py:18-95`; `main.py:703-739,1709-1713` |
| Informações pessoais | **IDs de usuários** (`owner_id`, `device_id`) | **Sim** | **Sim** — Turso/AWS | Funcionalidade do app; Análise | Obrigatório (telemetria **sem opt-out**) | `telemetria.py:1-26`; `telemetria_service.dart:16-40,72-90` |
| Informações pessoais | **Número de telefone** | **Sim** (telefone da pessoa atendida, digitado pelo profissional) | **Sim** — wuzapi (gateway não oficial de WhatsApp) e Turso/AWS | Funcionalidade do app | Obrigatório para o recurso de lembrete | `db.py:189-213`; `lembrete_service.py:92-114`; `compromisso.dart:159-171` |
| Informações pessoais | **Outras informações** (data de nascimento) | **Sim** | **Não** | Funcionalidade do app | Obrigatório | `models/paciente.dart:13-14` — **campo em claro no Hive** (C6) |
| Informações financeiras | **Outras informações financeiras** (valores, status e forma de pagamento da sessão) | **Sim** | **Não** | Funcionalidade do app | Opcional (o profissional pode não preencher) | `models/sessao.dart:158-168`; `sessao_service.dart:80` — **em claro no Hive** (C6) |
| Saúde e fitness | **Informações sobre saúde** | **Sim** | **Sim** — Groq, OpenAI, DeepSeek, Gemini; persistido **sem cifra** em Turso/AWS (EUA) | Funcionalidade do app | Obrigatório | `ia_clinica.py:438-454`; `transcricao.py:64-99`; `db.py:180-213`; `contrato_service.py:14-15` |
| Arquivos de áudio | **Gravações de voz ou som** | **Sim** | **Sim** — Groq (default) e OpenAI (alternativa) | Funcionalidade do app | Opcional (o profissional escolhe gravar ou digitar) | `transcricao.py:13-20,64-99`; `audio_relato_service.dart:92,171` (grava em claro e cifra depois — **P0.8**) |
| Arquivos e documentos | **Arquivos e documentos** | **Sim** | **Sim** — destinos escolhidos pelo profissional (compartilhamento do sistema) | Funcionalidade do app | Opcional | `pdf_export_service.dart:1544-1552` — PDF em claro, sem senha e sem evento de auditoria (C7) |
| Atividade em apps | **Interações no app** | **Sim** | **Sim** — Turso/AWS | Análise | Obrigatório | `telemetria.py:1-26` (allowlist de tipos de evento, sem PII clínica) |
| Informações e desempenho do app | **Registros de falhas / Diagnóstico** | **Sim, condicional** | **Sim** — Sentry, **desligado por padrão** e configurado sem PII | Análise | Opcional (opt-in) | `main.dart:73-105` |
| Identificadores do dispositivo e outros | **Identificadores do dispositivo e outros** (`device_id` persistente) | **Sim** | **Sim** — Turso/AWS | Funcionalidade do app; Análise | Obrigatório (sem opt-out) | `telemetria_service.dart:16-40,72-90`; `telemetria.py:1-26` |
| Local | — | **Não** | — | — | — | Nenhuma permissão de localização em `AndroidManifest.xml:2-8` |
| Mensagens | — | **Não** | — | — | — | O app **envia** lembrete por WhatsApp via wuzapi, mas **não** lê SMS/MMS nem caixa de e-mail |
| Fotos e vídeos / Contatos / Agenda / Navegação / Apps instalados | — | **Não** | — | — | — | Nenhuma permissão correspondente em `AndroidManifest.xml:2-8` (não há câmera, contatos nem localização) |

**Observação estrutural que o formulário do Play não pergunta e precisa estar resolvida na política:**
boa parte do dado de saúde é da **pessoa atendida**, que **não é usuária do app** e não tem conta. O
Play pergunta sobre "dados do usuário". Nas páginas oficiais consultadas **não há regra explícita**
sobre dado de terceiro digitado pelo usuário (**NÃO CONFIRMADO**). A conduta segura — e coerente com a
exigência de declaração "completa e precisa" — é **declarar mesmo assim** (o dado sai do aparelho e é
processado por terceiros) e explicar o papel de cada um na Política de Privacidade.

### 2.3 Bloco de dados de saúde (declaração e o que ela obriga)

| Pergunta do Play | Resposta proposta | Observação |
|---|---|---|
| O app coleta **Informações sobre saúde**? | **Sim** | Relato, transcrição, síntese, anamnese, contrato e apontamentos (art. 11 da LGPD) — `politica_privacidade_page.dart:44-49`; `db.py:180-213` |
| Coleta para quais finalidades? | **Funcionalidade do app** | Não é análise, não é publicidade, não é personalização |
| É compartilhado com terceiros? | **Sim, hoje** (Groq, OpenAI, DeepSeek, Gemini; Turso/AWS) — muda para "Não" **somente** após DPA com cada provedor | Ver §2.1 |
| É opcional? | **Não** para o prontuário; o **uso de IA e de áudio** deve ser tratado como escolha do profissional e informado ao titular | Hoje o profissional **não** escolhe o provedor nem é avisado do fallback (`01_diagnostico_lgpd.md` §4.1) |
| Criptografia em trânsito? | **Sim** | HTTPS + `usesCleartextTraffic="false"` (`AndroidManifest.xml:14`) |
| Criptografia em repouso (declarada como prática)? | **Não declarar ainda.** No aparelho a cifra é por campo e não cobre data de nascimento, pagamento e datas (C6); no servidor **não há cifra** (`contrato_service.py:14-15`) | **NÃO DECLARAR AINDA — depende dos itens P0.4 e P2.12** |
| Exclusão de dados disponível ao usuário? | **Não** | **NÃO DECLARAR AINDA — depende do item P1.9** (sem exclusão de conta e sem endpoint de eliminação no backend — `01_diagnostico_lgpd.md` §4.13) |

### 2.4 Respostas que **não** podem ser dadas hoje (e por quê)

| Afirmação pretendida | Por que **não** pode ir ao console hoje |
|---|---|
| "Os dados são excluídos quando o usuário pede" | Não existe exclusão de conta em `lib/` nem no backend; contratos, anamneses, lembretes, contas e telemetria **nunca são apagados** (`01_diagnostico_lgpd.md` §4.13) — **P1.9** |
| "Os dados ficam no Brasil" | O backend roda em `gru`, mas o banco está em `aws-us-west-2.turso.io` (**Oregon, EUA**) — `backend/.env`; `fly.toml:2-3` |
| "Dados sensíveis são cifrados em repouso" | Sem cifra no servidor (`contrato_service.py:14-15`) e campos sensíveis em claro no Hive (`models/paciente.dart:13-14`; `models/sessao.dart:158-168`) — **P0.4** / **P2.12** |
| "Nenhum dado é enviado a terceiros" | Áudio vai para a Groq (EUA) e relato + nome da pessoa atendida vão para OpenAI e DeepSeek (`transcricao.py:64-99`; `ia_clinica.py:648`) — **P0.1** |
| "Não usamos IA de terceiros" | Usa, e o fallback automático pode mudar o **país** do processamento na mesma operação (`01_diagnostico_lgpd.md` §4.1) |
| "Os dados não são usados para treinar modelos" | Afirmação do texto atual (`politica_privacidade_page.dart:105-108`) **não comprovada** por provedor — **P0.6** |
| "Gravações de áudio nunca ficam em claro" | O `.m4a` é gravado **em claro** e cifrado só após o `stop()` (`audio_relato_service.dart:92` vs `:171`) — **P0.8** |
| "O acesso é protegido por PIN/biometria sem exceção" | Há desbloqueio **fail-open** em lockout de biometria/erro de hardware (`auth_service.dart:203-215,237-250`) — **P0.7** |
| "Há exclusão de dados no app para o titular" | O módulo de consentimentos/solicitações está marcado como **não implementado** no próprio PDF de arquitetura (`pdf_arquitetura_lgpd_service.dart:241,245`) — **P2.10** |

> Todas as linhas acima são **"NÃO DECLARAR AINDA"**. Declarar antes de resolver geraria declaração
> incorreta — exatamente o que `tasks/lojas_app.md:41` aponta.

### 2.5 Outras seções obrigatórias do Play Console

| Seção | O que preencher | Situação |
|---|---|---|
| **Política de Privacidade** (campo de URL) | URL ativa, pública, sem PDF, não editável ([Health Content and Services](https://support.google.com/googleplay/android-developer/answer/16679511?hl=pt-br)) | **Pendente — P0.5** |
| **Exclusão de dados** (novas perguntas) | Caminho in-app **e** recurso web de solicitação ([Noções básicas sobre os requisitos de exclusão de contas](https://support.google.com/googleplay/android-developer/answer/13327111?hl=pt-br)) | **Pendente — P1.9** |
| **Declaração de apps de saúde** | Todos os desenvolvedores preenchem; selecionar "Suporte à decisão clínica" (ferramenta para profissional de saúde) ([Incluir informações no formulário de declaração de apps de saúde](https://support.google.com/googleplay/android-developer/answer/14738291?hl=pt-br)) | **Pendente — P1.10** |
| **Classificação de conteúdo (IARC)** | Questionário obrigatório para todo app ([Classificações de conteúdo](https://support.google.com/googleplay/android-developer/answer/9898843?hl=pt-br)) | **Pendente** |
| **Público-alvo e faixa etária** | Declarar público **adulto/profissional**; o app não é destinado a crianças, mas pode conter dado de criança/adolescente inserido pelo profissional — ver item de menores no `16_checklist_de_conformidade.md` | **Pendente** + **P1.15** |

---

## 3. Apple App Store — App Privacy (nutrition labels)

### 3.1 Categorias e finalidades a declarar

Categorias e definições conforme [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/).
Finalidades possíveis: Third-Party Advertising, Developer's Advertising or Marketing, Analytics,
Product Personalization, App Functionality, Other Purposes.

| Categoria Apple | Tipo de dado | Declarar? | Finalidade | Vinculado à pessoa? | Evidência |
|---|---|---|---|---|---|
| Health & Fitness | **Health** ("any other user provided health or medical data") | **Sim** | App Functionality | **Sim — vinculado** | Relato, transcrição, síntese, anamnese, contrato (`politica_privacidade_page.dart:44-49`; `db.py:180-213`) |
| Contact Info | **Name** | **Sim** | App Functionality | **Sim** | Nome do profissional e nome da pessoa atendida no prompt de IA (`ia_clinica.py:438-454`) |
| Contact Info | **Email Address** | **Sim** | App Functionality | **Sim** | Conta do profissional (`usuarios.py:18-95`) |
| Contact Info | **Phone Number** | **Sim** | App Functionality | **Sim** | Telefone da pessoa atendida (`db.py:189-213`) |
| Contact Info | **Other User Contact Info** | **Sim** | App Functionality | **Sim** | Contato da pessoa atendida (`politica_privacidade_page.dart:30-43`) |
| Financial Info | **Other Financial Info** | **Sim** | App Functionality | **Sim** | Valores/status/forma de pagamento da sessão (`models/sessao.dart:158-168`) |
| User Content | **Audio Data** | **Sim** | App Functionality | **Sim** | Áudio do relato (`audio_relato_service.dart`; `transcricao.py`) |
| User Content | **Other User Content** | **Sim** | App Functionality | **Sim** | Observações, apontamentos, respostas de anamnese, contrato |
| Sensitive Info | **Sensitive Info** | **Sim**, se o prontuário puder conter dado dessa natureza (origem racial/étnica, religião, orientação sexual, deficiência, dados genéticos, biometria) | App Functionality | **Sim** | Campos abertos do prontuário ("observações") — `models/paciente.dart:19-20` |
| Identifiers | **User ID** | **Sim** | App Functionality, Analytics | **Sim** | `owner_id`; `device_id` em `telemetria.py:1-26` |
| Identifiers | **Device ID** | **Sim** | Analytics | **Sim** | `device_id` persistente (`telemetria_service.dart:16-40`) |
| Usage Data | **Product Interaction** | **Sim** | Analytics | **Sim** | `telemetria.py:1-26` |
| Diagnostics | **Crash Data** / **Performance Data** / **Other Diagnostic Data** | **Sim, condicional** (Sentry **desligado por padrão**) | Analytics | **Sim**, se o opt-in for ligado | `main.dart:73-105` |

**Rastreamento (Tracking):** **Não.** Não há SDK de publicidade, atribuição ou data broker; a Apple
só exige ATT se houver rastreamento entre apps/sites de terceiros (não é o caso).

**Biometria:** o app usa Face ID/Touch ID **localmente** para liberar a chave; **não** há coleta nem
transmissão de dado biométrico. Não declarar como "Sensitive Info > biometric data" é defensável
**desde que** essa ausência de transmissão esteja escrita na política — hoje não está (a política fala
de "PIN e biometria", sem explicar que a biometria não sai do aparelho:
`politica_privacidade_page.dart:60`).

### 3.2 App Privacy e dados de terceiros que não são usuários

Como no Play (§2.2), boa parte do dado é da **pessoa atendida**. A Apple fala em "user data".
A leitura conservadora — e a única sustentável — é **declarar** os tipos acima listados, porque o app
os coleta, processa fora do dispositivo e compartilha com IA de terceiros.

### 3.3 Exigências de política e chaves do Info.plist

| Exigência | Texto oficial (Apple) | Situação | Ação |
|---|---|---|---|
| Política de Privacidade no metadata **e** dentro do app, acessível (5.1.1(i)) | "All apps must include a link to their privacy policy in the App Store Connect metadata field and within the app in an easily accessible manner." ([App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)) | **Não atende** — só página in-app | **P0.5** |
| Conteúdo mínimo da política (5.1.1(i)) | identificar dados coletados, como, todos os usos; confirmar que terceiros oferecem proteção equivalente; **explicar retenção/exclusão e como revogar consentimento/pedir exclusão** | **Não atende** — a política atual não tem retenção, DPO, canal nem lista de terceiros completa (`_base_factual.md` §5) | **P0.1**, **P0.6**, **P1.1**, **P1.6**, **P1.8** |
| Consentimento para coleta e forma de revogar (5.1.1(ii)) | "Apps that collect user or usage data must secure user consent… Apps must also provide the customer with an easily accessible and understandable way to withdraw consent." | **Não atende** — telemetria sem opt-out (C11) | **P1.14** |
| Divulgação de compartilhamento com IA de terceiros e permissão explícita (5.1.2(i)) | "You must clearly disclose where personal data will be shared with third parties, **including with third-party AI**, and obtain explicit permission before doing so." | **Não atende** — o card de IA só fala de revisão humana (`_base_factual.md` §7) | **P0.1** + **P1.5** |
| `ITSAppUsesNonExemptEncryption` | Chave booleana; **ausente** faz o App Store Connect pedir o questionário de exportação a cada envio ([doc oficial](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption); [Overview of export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/)) | **Ausente** — verificado em `ios/Runner/Info.plist` | **P2.16** — classificar corretamente (não presumir `NO`) |
| `NSFaceIDUsageDescription` | "This key is **required** if your app uses APIs that access Face ID." ([doc oficial](https://developer.apple.com/documentation/bundleresources/information-property-list/nsfaceidusagedescription)) | **Ausente** — verificado em `ios/Runner/Info.plist` | **P2.16** |
| Nome de exibição | Metadata deve ser completo e preciso | `CFBundleDisplayName` = **"Prontuario Tcc"** (`ios/Runner/Info.plist:9-10`) | **P2.16** — corrigir para "MentAll PRO" |
| Demo account para a revisão | "If your app includes account-based features, provide either an active demo account or fully-featured demo mode" ([App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)) | **Não preparado** | Preparar conta e dados de demonstração (**P2.17**) |

### 3.4 Regra para apps que tratam dados de saúde (Apple)

| Diretriz | Texto oficial (resumo fiel) | Impacto no MentAll |
|---|---|---|
| **5.1.1(i)** | A política deve identificar dados, usos, terceiros com proteção equivalente e **retenção/exclusão** | Reescrever a política (**P0.1**, **P1.6**) |
| **5.1.2(i)** | Compartilhamento com terceiros, **incluindo IA de terceiros**, exige divulgação clara e **permissão explícita**; "Apps that share user data without user consent or otherwise complying with data privacy laws may be removed from sale" | Ajustar o fluxo de IA para informar e obter permissão explícita do profissional, e o material do titular (**P0.1**, **P1.5**) |
| **5.1.3(i)** | Dados de saúde são "especially sensitive"; é proibido usar/divulgar dados do contexto de saúde (HealthKit, Clinical Health Records, pesquisa) para publicidade, marketing ou *data mining* — exceto para melhorar a gestão de saúde e **com permissão** | O MentAll **não** usa HealthKit. Ainda assim, a regra reforça: **nenhum** uso de dado clínico para métrica de produto, marketing ou treino de modelo — deve estar escrito no DPA (cláusula 4 de `04_papeis_e_contrato_controlador_operador.md`) |
| **5.1.3(ii)** | "may not store personal health information in iCloud" | **NÃO VERIFICADO** no iOS: não há uso de `NSURLIsExcludedFromBackupKey` / exclusão de backup no código (busca sem resultados). Confirmar se o backup do iCloud pode incluir arquivos do app e, se puder, excluir o diretório do prontuário |
| **5.1.3(iii)-(iv)** | Pesquisa com seres humanos exige consentimento e aprovação de comitê de ética | **Não aplicável** — o MentAll não faz pesquisa |
| **1.4.1** | "Medical apps that could provide inaccurate data or information, or that could be used for diagnosing or treating patients may be reviewed with greater scrutiny." Apps devem lembrar o usuário de consultar um médico; alegações de acurácia exigem metodologia; app com liberação regulatória deve enviar a documentação | **Atenção:** não prometer diagnóstico, tratamento, acurácia clínica ou "substitui o julgamento"; declarar que a IA é **apoio documental com revisão humana obrigatória**. Se o app não é dispositivo médico, declarar isso no App Store Connect |
| **5.1.1(v)** | "If your app supports account creation, you must also offer account deletion within the app." | **Não atende** — **P1.9** |

> **Referência de mercado (`18_comparativo_concorrentes.md`):** declarar "**IA sem treinamento**" é
> padrão entre os concorrentes que usam IA — **PsiLuz** ("veda retenção e treinamento"), **Copilloto**
> ("conteúdo nunca usado para treinar IA de terceiros") e **PsicoPront** ("apenas texto enviado à
> OpenAI"). É exatamente o que a **Apple 5.1.2(i)** espera ver divulgado; o texto do MentAll deve
> seguir o mesmo padrão — **mas só depois do P0.6** (hoje não há comprovação por provedor).

### 3.5 Outras exigências Apple já mapeadas

| Item | Onde se configura | Situação |
|---|---|---|
| App Privacy (nutrition labels) | App Store Connect → App Privacy ([Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)) | **Pendente — P1.10** |
| Declaração de status de dispositivo médico regulamentado | App Store Connect → App Information | **A confirmar** |
| Faixa etária | App Store Connect → Age Rating ([Set an app age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/)) | **Pendente** |
| Nome, subtítulo, palavras-chave, screenshots | App Store Connect | Ver §5 |
| Assinatura/StoreKit | App Store Connect + RevenueCat | **Não implementado** |

### 3.6 Faixa etária — definições oficiais relevantes

Fontes: [Age ratings values and definitions](https://developer.apple.com/help/app-store-connect/reference/age-ratings-values-and-definitions/) e [Set an app age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/)

- **17+** — inclui "Frequent or intense medical or treatment-focused content".
- **12+** — inclui "Medical or Wellness: Infrequent medical or treatment information".
- **9+** — inclui "Medical or Wellness: Health and wellness topics".

**Recomendação:** responder o questionário de forma **honesta e conservadora**; um app cujo conteúdo
principal é relato clínico e evolução de casos tende a cair em faixa média/alta. **A resposta exata
não pode ser presumida — deve ser preenchida no App Store Connect** com o texto final do produto em
mãos. Para o Play, a classificação vem do questionário IARC e é obrigatória.

---

## 4. Nota de LGPD para o console (texto pronto, curto, para colar)

> **Versão para colar somente após P0.1, P0.2, P0.5, P0.6 e P1.9 concluídos.** Enquanto isso:
> **NÃO PUBLICAR.**

```
O MentAll PRO é um software de prontuário para psicólogas e psicólogos com registro profissional
ativo no Brasil. O tratamento de dados pessoais segue a Lei nº 13.709/2018 (LGPD).

Papéis: o profissional de psicologia é o CONTROLADOR dos dados clínicos das pessoas atendidas;
o MentAll PRO atua como OPERADOR desses dados, tratando-os apenas conforme as instruções do
profissional e para operar as funcionalidades contratadas.

Dados tratados: (a) dados de conta do profissional (nome, e-mail, CRP, plano); (b) dados das
pessoas atendidas inseridos pelo profissional (nome, data de nascimento, contato, e-mail,
observações); (c) dados pessoais sensíveis de saúde (relato de sessão, áudio do relato,
transcrição, síntese gerada por IA e apontamentos clínicos); (d) dados técnicos de uso e
diagnóstico, sem conteúdo clínico.

Onde ficam e para onde vão: o prontuário é mantido cifrado no aparelho do profissional. Partes
do fluxo são processadas por subprocessadores no exterior — hospedagem e banco de dados, transcrição
de áudio e geração de síntese por IA — com transferência internacional conforme os arts. 33 a 36,
nos termos informados na Política de Privacidade. Lista atualizada de subprocessadores, finalidade e
país: [URL DA POLÍTICA].

Direitos do titular: solicitações de confirmação, acesso, correção, anonimização, portabilidade,
eliminação e informação sobre compartilhamento podem ser feitas pelo canal do encarregado:
[E-MAIL DO ENCARREGADO]. Solicitações sobre conteúdo clínico são encaminhadas ao profissional
controlador, com registro.

Retenção: o prontuário psicológico tem guarda legal obrigatória; por isso a eliminação é avaliada
caso a caso, observados os arts. 16 e 18 da LGPD e a legislação profissional aplicável.
[COMPLETAR COM O PRAZO DEFINIDO NO DOCUMENTO 10 — NÃO INVENTAR PRAZO]

Exclusão de conta: [CAMINHO NO APP] e [URL DE SOLICITAÇÃO NA WEB].

Encarregado (DPO): [NOME], [E-MAIL].

Este aplicativo não realiza diagnóstico, não prescreve tratamento e não substitui o julgamento
clínico do profissional. As saídas de IA são apoio documental e exigem revisão humana antes de
serem salvas no prontuário.

Última atualização: [DATA] — versão [X].
```

**Regras desta nota:** não escrever "LGPD compliant", "certificado", "100% seguro", "dados anônimos"
nem "dados nunca saem do aparelho".

---

## 5. Textos prontos (metadata)

### 5.1 Google Play

| Campo | Texto proposto | Limite |
|---|---|---|
| Nome do app | `MentAll PRO` | 30 caracteres |
| Descrição curta | `Prontuário psicológico: relato, transcrição e síntese com revisão` | 80 caracteres |
| Descrição completa | ver bloco abaixo | 4.000 caracteres |

```
MentAll PRO é o prontuário clínico feito para psicólogas e psicólogos com registro profissional
ativo no Brasil.

REGISTRO CLÍNICO ORGANIZADO
Cadastre pessoas atendidas, registre sessões, apontamentos, hipóteses e plano terapêutico. Anamnese
e contrato terapêutico podem ser enviados por link para preenchimento antes da sessão.

DITE O RELATO, EM VEZ DE DIGITAR
Grave o relato pós-sessão em áudio e receba a transcrição automática. O áudio é processado por
provedor de transcrição e depois convertido em texto para o seu prontuário.

SÍNTESE COM APOIO DE INTELIGÊNCIA ARTIFICIAL — SEMPRE COM SUA REVISÃO
A IA organiza o conteúdo em uma síntese estruturada. Nada é salvo no prontuário sem a sua revisão
e aprovação. A IA não emite diagnóstico e não decide nada por você.

PRIVACIDADE NO DESENHO
- Prontuário cifrado no aparelho, com chave protegida pelo cofre do sistema (Keystore/Keychain).
- Bloqueio por biometria ou PIN.
- Trilha de auditoria das ações que tocam o prontuário.
- Telemetria sem conteúdo clínico.
- Backup cifrado com verificação de integridade.

TRANSPARÊNCIA SOBRE TERCEIROS
Para funcionar, o MentAll PRO usa serviços de terceiros: hospedagem e banco de dados, transcrição de
áudio e geração de síntese por IA. Isso significa que parte dos dados é processada fora do aparelho,
inclusive no exterior. A lista completa de fornecedores, o que cada um recebe, a finalidade e o país
estão na Política de Privacidade, disponível em [URL]. Leia antes de usar.

PARA QUEM É
Destinado a profissionais de psicologia. Não é destinado ao público leigo e não substitui atendimento
presencial, avaliação ou decisão clínica. As informações do app são apoio à documentação clínica.

SOBRE SEUS DADOS
Você é o controlador dos dados clínicos das pessoas que atende. O MentAll PRO atua como operador
tecnológico. Você pode solicitar a exclusão da sua conta em [CAMINHO NO APP] ou em [URL].
Dúvidas e solicitações do titular: [E-MAIL DO ENCARREGADO].
```

> Os campos `[URL]`, `[CAMINHO NO APP]` e `[E-MAIL DO ENCARREGADO]` **só podem ser preenchidos quando
> P0.5, P1.1 e P1.9 estiverem concluídos**. Publicar a descrição com placeholder é reprovação certa.

### 5.2 Apple App Store

| Campo | Texto proposto | Limite |
|---|---|---|
| Nome | `MentAll PRO` | 30 |
| Subtítulo | `Prontuário clínico com IA` | 30 |
| Texto promocional | `Registre o relato em áudio, receba a transcrição e organize a síntese — sempre com a sua revisão antes de salvar.` | 170 |
| Palavras-chave | `prontuário,psicólogo,psicologia,registro clínico,anamnese,transcrição,sessão,evolução,CRP,relato` | 100 (sem espaços após vírgula) |
| Descrição | mesma da descrição completa do Play, **sem** usar a palavra "Grátis" de forma indevida e sem promessas de resultado clínico | 4.000 |

### 5.3 Categoria recomendada

| Loja | Categoria proposta | Por quê | Condição |
|---|---|---|---|
| Google Play | **Medicina** (com a declaração de apps de saúde preenchida como "Suporte à decisão clínica") | É onde o público procura ferramenta clínica; a loja exige o formulário de saúde e política detalhada ([Health Content and Services](https://support.google.com/googleplay/android-developer/answer/16679511?hl=pt-br)) | **Só depois** de P0.5 e P1.10 |
| Google Play (alternativa conservadora) | **Produtividade** | Reduz escrutínio de saúde, mas **não isenta** do formulário de declaração de apps de saúde — ele é obrigatório para todos os apps | Decisão a registrar no doc. 17 antes do envio |
| Apple App Store | **Medical** | Ferramenta de documentação clínica para profissional habilitado | Combina com a declaração de "não dispositivo médico" e com o texto da §5.1 |

### 5.4 O que **não** prometer (lista de bloqueio editorial)

| Proibido no texto | Por quê |
|---|---|
| "LGPD compliant", "em conformidade com a LGPD", "certificado", "aprovado pela ANPD" | Não existe certificação de conformidade na LGPD; seria alegação não comprovável |
| "100% seguro", "segurança absoluta", "à prova de vazamento" | Nenhum sistema é; o próprio diagnóstico registra controles ausentes (`01_diagnostico_lgpd.md` §4.14) |
| "Criptografia de ponta a ponta" (E2EE) | **Falso** para os fluxos de nuvem — o servidor lê o conteúdo (`contrato_service.py:14-15`) |
| "Dados nunca saem do aparelho" | **Falso** — Turso (EUA), Groq, OpenAI, DeepSeek (`01_diagnostico_lgpd.md` §4.1) |
| "Anônimo" / "anonimizado" | Há pseudonimização parcial de nome, mas o conteúdo clínico é identificável (`01_diagnostico_lgpd.md` §4.1) |
| "Os dados não são usados para treinar IA" | Sem comprovação por provedor (**P0.6**) |
| "Diagnóstico por IA", "tratamento", "prescrição", "substitui o psicólogo" | Dispara escrutínio da diretriz 1.4.1 e é falso |
| "Aumenta a adesão do paciente", "melhora resultados clínicos" | Alegação de resultado sem evidência |
| "Aprovado pelo CFP" / "recomendado pelo CFP" | **Falso** — não há aprovação declarada |
| "Exclusão total dos seus dados" (sem qualificar) | Não há exclusão implementada e há guarda legal do prontuário (**P1.9**, doc. 10) |
| "Seus dados ficam no Brasil" | O banco está em `aws-us-west-2` (EUA) |

> **Nota de posicionamento (`18_comparativo_concorrentes.md`):** alguns concorrentes usam **"100%
> conforme com a LGPD"** (PsiLuz) ou **"em total conformidade"** (ProntusCare). **NÃO copiar essa
> linguagem** — não existe certificação de conformidade na LGPD e a própria política do MentAll
> descreve medidas **em adequação**. Manter **"em adequação"**.

---

## 6. Plano de publicação (ordem das ações para desbloquear as lojas)

Ordem derivada do `02_plano_de_acao.md`. **Nada de loja antes do passo 6.**

| Passo | Ação | Depende de | Resultado que destrava |
|---|---|---|---|
| 1 | Corrigir os textos in-app e listar **todos** os terceiros reais (Groq, OpenAI, DeepSeek, Google, Turso/AWS, Sentry, SMTP, wuzapi), com país e finalidade | **P0.1** | Base verdadeira para qualquer declaração |
| 2 | **Decidir o DeepSeek** (remover do `IA_PROVIDER_ORDER` ou consentimento específico + RIPD) e revisar `IA_MODEL_PROVIDER` incoerente (`backend/.env`) | **P0.2** | Resposta estável na coluna "país" do Data Safety/App Privacy |
| 3 | Decidir a localização do banco e publicar o mecanismo do art. 33 | **P0.3** | Elimina a resposta "não sei onde fica" |
| 4 | Cifrar o conteúdo no servidor (ou parar de persistir) | **P0.4** | Permite descrever retenção e segurança com honestidade |
| 5 | Corrigir as promessas falsas (treinamento/retenção, PIN, pinning, áudio em claro) | **P0.6**, **P0.7**, **P0.8**, **P0.9**, **P0.10** | Remove as contradições entre texto e comportamento |
| 6 | **Publicar Política de Privacidade e Termos em URL pública** (não-PDF, ativa, acessível) e linkar no app | **P0.5** (textos finais dos docs. 05/06) | **Destrava R1, R2, R9** — o bloqueio mais concreto |
| 7 | Nomear encarregado, publicar canal do titular, criar procedimento do art. 18 | **P1.1**, **P1.8** | Preenche o `[E-MAIL DO ENCARREGADO]` da nota de LGPD |
| 8 | Definir política de retenção/descarte | **P1.6** | Permite responder retenção no Data Safety/App Privacy |
| 9 | **Implementar exclusão de conta + URL de exclusão** | **P1.9** | Destrava R3 e R4 (reprovação automática hoje) |
| 10 | Assinar DPA com cada subprocessador/psicólogo | **P1.2** + Parte C do doc. 04 | Permite responder "não compartilhado (provedor de serviços)" em vez de "compartilhado" |
| 11 | iOS: `NSFaceIDUsageDescription`, `ITSAppUsesNonExemptEncryption`, nome de exibição, exclusão de backup do prontuário | **P2.16** + verificação de iCloud | Remove risco de reprovação no iOS |
| 12 | Keystore de produção, conta de desenvolvedor, assinatura (RevenueCat), screenshots iOS, estúdio de pré-lançamento | **P1.10** + `tasks/lojas_app.md` §2 | Envio tecnicamente possível |
| 13 | **Preencher Data Safety e App Privacy** conferindo cada linha contra o código | **P1.10** | Envio |
| 14 | Revisão jurídica dos textos publicados | ⚖️ docs. 05/06/10 | Última barreira antes do envio |

---

## 7. Riscos de reprovação com o texto atual (verificado)

| # | Risco | Gravidade | Evidência | Mitigação |
|---|---|---|---|---|
| 1 | **Declaração incorreta no Data Safety / App Privacy** — os textos in-app omitem Groq e DeepSeek e citam Gemini, que está fora da ordem de produção | **Crítico** — política de dados do usuário; risco de remoção do app | `politica_privacidade_page.dart:71-73`; `termos_uso_page.dart:35-36`; `AGENTS.md:191` | **P0.1** |
| 2 | **Ausência de exclusão de conta** — exige caminho in-app nas duas lojas | **Crítico** — reprovação automática | Busca por exclusão de conta em `lib/` e backend: zero resultados; `lib/services/paciente_service.dart:113-166` sem chamador | **P1.9** |
| 3 | **Ausência de URL de política de privacidade** | **Crítico** | `tasks/lojas_app.md:32-34`; site irmão só com `index.html` | **P0.5** |
| 4 | **Afirmação não comprovada sobre treinamento de modelos** | **Alto** — "informações enganosas" | `politica_privacidade_page.dart:105-108` | **P0.6** |
| 5 | **Política diz que o dado fica no aparelho** enquanto contrato, anamnese e telefone estão em banco nos EUA | **Alto** | `politica_privacidade_page.dart:57` vs `db.py:180-213` | **P0.1**, **P0.3** |
| 6 | **Armazenamento de saúde em iCloud não verificado** (Apple 5.1.3(ii)) | **Alto** — se aplicável, viola diretriz | Nenhum uso de `NSURLIsExcludedFromBackupKey` no código | Verificar e excluir o diretório do prontuário do backup |
| 7 | **`NSFaceIDUsageDescription` ausente** com biometria em uso | **Alto** | `ios/Runner/Info.plist` (sem a chave); `auth_service.dart:203-215` | **P2.16** |
| 8 | **`ITSAppUsesNonExemptEncryption` ausente** | Médio — atraso/pendência a cada envio | `ios/Runner/Info.plist` | **P2.16** |
| 9 | **Nome de exibição iOS "Prontuario Tcc"** | Médio — incoerência de marca apontada pelo próprio projeto | `ios/Runner/Info.plist:9-10`; `tasks/lojas_app.md` | **P2.16** |
| 10 | **Alegações que disparam a diretriz 1.4.1** se o texto usar "diagnóstico", "tratamento" ou acurácia | **Alto** | Diretriz 1.4.1 (§3.4) | §5.4 (lista de bloqueio editorial) |
| 11 | **Divulgação de IA de terceiros e permissão explícita (5.1.2(i))** | **Alto** | `_base_factual.md` §7 (aviso de IA só fala de revisão humana) | **P0.1** + **P1.5** |
| 12 | **Telemetria sem opt-out** (5.1.1(ii), "way to withdraw consent"; e expectativa do Play) | Médio | `telemetria_service.dart:16-40,72-90` | **P1.14** |
| 13 | **Demo seed "Linda M. Tester"** visível em instalação nova confunde o revisor | Médio | `demo_data_service.dart:35-78`; `main.dart:192` | **P2.17** |
| 14 | **Sem conta de demonstração** para a Apple revisar funcionalidade com login | Médio | `tasks/lojas_app.md:42-43` | Preparar antes do envio |
| 15 | **Screenshots iOS e keystore ausentes** | Baixo/Médio — bloqueio operacional | `tasks/lojas_app.md:29-30,35-36` | Executar |
| 16 | **Gravação de áudio em claro** — contradiz qualquer afirmação de proteção do áudio | **Alto** | `audio_relato_service.dart:92` vs `:171` | **P0.8** |
| 17 | **Desbloqueio fail-open** — contradiz "bloqueio por PIN/biometria" | **Alto** | `auth_service.dart:203-215,237-250`; `politica_privacidade_page.dart:60` | **P0.7** |

---

## 8. Fontes oficiais consultadas em 09/10/2026

**Google Play**

- Fornecer informações para a seção "Segurança dos dados" (Data Safety) — https://support.google.com/googleplay/android-developer/answer/10787469?hl=pt-br
- Noções básicas sobre os requisitos de exclusão de contas de apps do Google Play — https://support.google.com/googleplay/android-developer/answer/13327111?hl=pt-br
- Política de Dados do usuário — https://support.google.com/googleplay/android-developer/answer/10144311?hl=pt-br
- Developer Programme Policy (Data safety claro e preciso) — https://support.google.com/googleplay/android-developer/answer/16313518
- Incluir informações no formulário de declaração de apps de saúde — https://support.google.com/googleplay/android-developer/answer/14738291?hl=pt-br
- Conteúdo e serviços relacionados à saúde — https://support.google.com/googleplay/android-developer/answer/16679511?hl=pt-br
- Classificações de conteúdo (IARC) — https://support.google.com/googleplay/android-developer/answer/9898843?hl=pt-br
- Taxa de inscrição de desenvolvedor (US$ 25, única) — https://support.google.com/googleplay/android-developer/answer/6112435?hl=pt-br

**Apple**

- App Review Guidelines (1.4.1, 5.1.1, 5.1.2, 5.1.3) — https://developer.apple.com/app-store/review/guidelines/
- App Privacy Details (lista de tipos de dado e finalidades) — https://developer.apple.com/app-store/app-privacy-details/
- `ITSAppUsesNonExemptEncryption` — https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption
- `NSFaceIDUsageDescription` — https://developer.apple.com/documentation/bundleresources/information-property-list/nsfaceidusagedescription
- Overview of export compliance — https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/
- Manage app privacy — https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
- Set an app age rating — https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/
- Age ratings values and definitions — https://developer.apple.com/help/app-store-connect/reference/age-ratings-values-and-definitions/
- Apple Developer Program (US$ 99/ano) — https://developer.apple.com/programs/enroll/

**Não confirmado nas fontes oficiais consultadas** (não usar como fato): tratamento específico do
Play/Apple para dado pessoal de **terceiro não usuário** digitado pelo usuário; resposta exata do
questionário de faixa etária para este produto; classificação correta de export compliance de
criptografia para este app; se o backup do iCloud inclui os arquivos do prontuário no iOS.

---

## 9. Checklist de envio (resumo operacional)

- [ ] R1, R2 — Política e Termos em URL pública, linkados no app **(P0.5)**
- [ ] R3, R4 — Exclusão de conta no app + URL de exclusão **(P1.9)**
- [ ] R5 — Data Safety preenchido linha a linha e conferido contra o código **(P1.10)**
- [ ] R6 — Declaração de apps de saúde preenchida
- [ ] R8 — App Privacy (nutrition labels) preenchida
- [ ] R10, R11 — `ITSAppUsesNonExemptEncryption` e `NSFaceIDUsageDescription` **(P2.16)**
- [ ] R14 — Classificação IARC (Play) e age rating (Apple)
- [ ] R15 — Contas de desenvolvedor pagas
- [ ] R17 — Keystore de produção gerado e guardado fora do repositório
- [ ] R18 — Screenshots iOS
- [ ] R19 — Pré-lançamento em aparelho real
- [ ] R20 — Divulgação de IA + permissão explícita **(P0.1, P1.5)**
- [ ] R25 — Conta de demonstração para o revisor
- [ ] Revisão jurídica dos textos públicos ⚖️
- [ ] Nenhuma frase da §5.4 presente nos textos finais
