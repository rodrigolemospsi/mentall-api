# Data Safety (Google Play) e App Privacy (Apple) — rascunho preenchível

**Versão:** 1.0 · **Data:** 23/10/2026 · **Status:** rascunho técnico para preencher nos consoles.
**Escopo:** itens **3.1** (Data Safety), **3.2** (declaração de apps de saúde) e **3.3** (App Privacy)
do checklist de publicação. Apoio para **3.5** (permissões) no Anexo A.

> **Regra de honestidade:** as respostas abaixo foram levantadas do código e da arquitetura em
> 23/10/2026 (`backend/models/schemas.py`, `backend/services/*`, `lib/services/*`, manifestos e
> páginas legais). Nenhuma declaração deve afirmar comportamento que o produto não tem. Onde há
> dúvida jurídica/contratual (ex.: provedores como “service providers” × “terceiros”), a coluna
> indica o caminho conservador. **Revisar com o jurídico antes de enviar** (itens 1.6/1.7/1.8).

---

## 1. O que o app coleta e para onde vai (inventário)

### 1.1 Dados que saem do aparelho para o servidor do MentAll (Fly.io, região São Paulo)

| # | Dado | Onde fica no servidor | Finalidade | Vinculado à conta? |
|---|---|---|---|---|
| 1 | E-mail, nome e senha (hash) da conta do profissional | `usuarios` | Criar/conta, login, comunicações | Sim |
| 2 | Nome da pessoa atendida, nome/CRP do profissional, texto do contrato e aceite (nome/data) | `contratos` | Enviar e registrar o acordo terapêutico | Sim |
| 3 | Nome da pessoa atendida, nome/CRP do profissional, template e **respostas da anamnese** | `anamneses` | Enviar e registrar a anamnese | Sim |
| 4 | Telefone da pessoa atendida e **mensagem do lembrete** (inclui o nome no texto padrão) | `lembretes` | Enviar lembrete por WhatsApp | Sim |
| 5 | UUID aleatório do aparelho, plataforma, versão do app e horários de presença | `dispositivos` | Segurança, sessão, suporte | Sim |
| 6 | Tipo de evento de uso (allowlist: `sessao_salva`, `transcricao`, `sintese`, `paciente_criado`, `contrato_enviado`, `anamnese_enviada`) + `device_id` | `eventos` | Uso do produto (analytics) | Sim |
| 7 | Token de sessão do WhatsApp (wuzapi) do profissional | `wuzapi_instancias` | Enviar lembretes pelo WhatsApp do próprio profissional | Sim |
| 8 | Hash de e-mail + códigos de recuperação/redefinição de senha | `recuperacoes`, `resets_senha` | Recuperação de conta | Sim |
| 9 | Áudio do relato pós-sessão (base64) | **Trânsito apenas — não é persistido no servidor** | Transcrever via Groq | Sim (requisição autenticada) |
| 10 | Texto clínico do relato/transcrição (nome do paciente vai **vazio**) | **Trânsito apenas — não é persistido no servidor** | Gerar síntese via OpenAI | Sim |

> O prontuário completo (pacientes, sessões, histórico, financeiro, agenda local) **não sai do
> aparelho**. O servidor não armazena conteúdo clínico do prontuário — apenas os itens acima.

### 1.2 Dados que saem para terceiros (fora do MentAll)

| Terceiro | Recebe | Quando | País |
|---|---|---|---|
| **OpenAI** | Texto clínico (relato/transcrição), sem nome do paciente | Ao gerar síntese (ação do profissional) | EUA |
| **Groq** | Áudio do relato pós-sessão | Ao transcrever (ação do profissional) | EUA |
| **Google Calendar** | Resumo do evento (“Sessão” ou título), data/hora e sala; e-mail da conta Google fica no aparelho | Somente se o profissional conectar a conta (opcional, desligado por padrão) | Internacional |
| **WhatsApp / Meta** | Telefone e mensagem do lembrete | Ao enviar lembrete (wuzapi auto-hospedado do profissional) | Internacional |
| **Resend** | E-mail de confirmação/redefinição (endereço e conteúdo do e-mail) | Cadastro/recuperação de senha | EUA |
| **Cloudflare** | Metadados de conexão (DNS/proteção) | Todo acesso | EUA |
| **Fly.io / Magalu Cloud / Mailu** | Dados de hospedagem/banco/e-mail (operadores) | Operação do serviço | Brasil |

### 1.3 Dados que NÃO saem do aparelho (não declarar como “coletados”)

- Prontuário completo: pacientes, sessões, relatos, transcrições, sínteses, anamnese local, contratos (cópia local), evolução, financeiro e agenda local.
- PDFs exportados e backups (arquivos gerados a pedido do profissional; quando ele compartilha, é ação dele).
- Áudio do relato **depois** da transcrição (o app não envia o arquivo para armazenamento; o profissional pode optar por não manter áudio local).
- Senha em texto puro: nunca é armazenada (hash no servidor; credencial local cifrada no cofre do aparelho).

---

## 2. Google Play — Data Safety (item 3.1)

### 2.1 Respostas gerais (seção “Data collection and security”)

| Pergunta | Resposta |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (HTTPS/TLS em todas as APIs) |
| Do you provide a way for users to request that their data is deleted? | **Yes** — exclusão in-app (Configurações → Conta → Excluir minha conta) e página web https://mentallpro.com.br/exclusao/ |
| Do you have a privacy policy? | **Yes** — https://mentallpro.com.br/privacidade/ |
| Has your app been independently validated against a global security standard? | **No** |
| Do you commit to follow the Families Policy? | **No** (app para profissionais, não direcionado a crianças) |
| Is any collected data processed ephemerally? | **Não declarar** para OpenAI/Groq: os provedores podem reter por período de segurança/abuso. Só marcar após contrato de retenção zero (ver §6). |

### 2.2 Data types — linha a linha (o que marcar)

| Data type (Play) | Coletado? | Compartilhado com terceiros? | Vinculado ao usuário? | Finalidades a marcar | Opcional? |
|---|---|---|---|---|---|
| **Personal info → Name** | Sim | Sim (WhatsApp/Resend; OpenAI/Groq recebem texto que pode conter nome digitado) | Sim | App functionality; Account management; Developer communications | Não |
| **Personal info → Email address** | Sim | Sim (Resend; Google só se conectar Calendar) | Sim | App functionality; Account management; Developer communications | Não |
| **Personal info → Phone number** | Sim (telefone da pessoa atendida, inserido pelo profissional) | Sim (WhatsApp/Meta) | Sim | App functionality | Sim (só se o profissional cadastrar telefone/lembrete) |
| **Personal info → Other info** (CRP, nomes em contrato/anamnese) | Sim | Não (fica no servidor do MentAll; entram em contratos/anamnese) | Sim | App functionality | Sim |
| **Health and fitness → Health info** (relato/transcrição/síntese clínica) | Sim | Sim (OpenAI; Groq recebe áudio com conteúdo clínico) | Sim | App functionality | Sim (só ao usar IA) |
| **Audio → Voice or sound recordings** (relato pós-sessão) | Sim | Sim (Groq) | Sim | App functionality | Sim (só ao transcrever) |
| **Calendar → Calendar events** (opcional Google Calendar) | Sim, se a integração for ativada | Sim (Google) | Sim | App functionality | Sim (desligado por padrão) |
| **App activity → App interactions** (tipos de evento de uso) | Sim | Não | Sim | Analytics | Não |
| **Device or other IDs → Device or other IDs** (UUID aleatório) | Sim | Não | Sim | App functionality; Analytics; Fraud prevention, security and compliance | Não |
| **App info and performance → Crash logs / Diagnostics** | **Não** (Sentry desligado; app não envia crash logs) | — | — | — | — |
| **Financial info** | **Não** (valores de sessão ficam só no aparelho; contrato é template editável) | — | — | — | — |
| Location, Contacts, Photos/videos, Messages, Files/docs, Web browsing | **Não** | — | — | — | — |

> **Sobre “compartilhado”:** a regra do Google exclui da noção de “terceiros” os *service providers*
> que processam dados em nome do app, desde que haja contrato (DPA). Nesta versão o DPA está em
> elaboração (itens 1.6/1.7). **Postura conservadora:** marcar como compartilhado o que vai para
> OpenAI, Groq, Google Calendar, WhatsApp/Meta e Resend; manter Fly.io/Magalu/Cloudflare como
> service providers (não compartilhados) quando o DPA estiver assinado. Se o DPA não estiver
> assinado no envio, marcar também esses três como compartilhados (revisar com o jurídico).

### 2.3 Purposes (Play) — definições usadas

- **App functionality:** conta, contratos, anamnese, lembretes, transcrição, síntese, agenda.
- **Analytics:** tipos de evento de uso/telemetria (sem conteúdo clínico).
- **Account management:** criar/gerenciar conta, autenticação, recuperação de senha.
- **Developer communications:** e-mails operacionais (confirmação de cadastro, reset de senha).
- **Fraud prevention, security and compliance:** logs de acesso, dispositivos, limites de uso.
- **Advertising / marketing:** não usados.

### 2.4 Data deletion (responder no console)

| Pergunta | Resposta |
|---|---|
| Existe exclusão de conta? | Sim |
| URL de exclusão de conta | `https://mentallpro.com.br/exclusao/` |
| Como o usuário exclui? | In-app: Configurações → Conta → Excluir minha conta (3 passos, imediato). Web: pedido por e-mail com prazo de 15 dias. |
| O que é apagado? | Conta, login, contratos, anamnese, lembretes/telefones, dispositivos, telemetria e conexão WhatsApp do servidor. |
| O que permanece? | Prontuário cifrado no aparelho do profissional (guarda legal; o servidor não guarda conteúdo clínico), backups/PDFs exportados e eventos já criados no Google Calendar. |

---

## 3. Google Play — declaração de “Health apps” (item 3.2)

Preencher em **Play Console → App content → Health apps**.

| Pergunta (paráfrase) | Resposta proposta | Justificativa |
|---|---|---|
| O app é um app de saúde? | **Sim** | Trata dados de saúde (conteúdo clínico sensível) e apoia documentação clínica de profissionais habilitados. |
| O app fornece funcionalidades de saúde? | **Sim** | Prontuário, transcrição e síntese clínica de apoio documental. |
| Possui recursos de diagnóstico/tratamento ao consumidor? | **Não** | É software de apoio documental para o profissional; não emite diagnóstico nem substitui julgamento clínico. |
| É dispositivo médico? | **Não** | Não se trata de dispositivo médico; não há função de diagnóstico autônomo. |
| Usa permissões de saúde do Android (BODY_SENSORS etc.)? | **Não** | Só microfone, biometria, notificações e alarme exato (ver Anexo A). |
| Público-alvo | **Profissionais** (psicólogas/os com CRP), **18+** | Ficha nas lojas deve refletir isso. |

> Referência interna: `docs/lgpd/15_lojas_google_play_e_app_store.md` §2.6; a ficha do app deve
> declarar “ferramenta de documentação clínica para profissionais”, não app de saúde do consumidor.

---

## 4. Apple — App Privacy (item 3.3)

Preencher em **App Store Connect → App Privacy** (nutrition labels). O app **não usa dados para
rastreamento** (sem SDK de ads/analytics de terceiros). Portanto: **“Data Used to Track You” = nenhum**.

### 4.1 Data types a declarar

| Categoria Apple | Data type | Coletado? | Vinculado à identidade? | Finalidades | Observação |
|---|---|---|---|---|---|
| **Contact Info** | Name | Sim | Sim | App Functionality | Nome do profissional e nomes em contrato/anamnese/lembrete |
| **Contact Info** | Email Address | Sim | Sim | App Functionality | Conta + e-mails operacionais (Resend) |
| **Contact Info** | Phone Number | Sim | Sim | App Functionality | Telefone da pessoa atendida, para lembretes (opcional) |
| **Health & Fitness** | Health | Sim | Sim | App Functionality | Relato/transcrição/síntese clínica enviados à IA; contratos/anamnese no servidor |
| **User Content** | Audio Data | Sim | Sim | App Functionality | Áudio do relato pós-sessão enviado à Groq |
| **User Content** | Other User Content | Sim | Sim | App Functionality | Texto do contrato, respostas de anamnese, mensagem de lembrete |
| **Identifiers** | User ID | Sim | Sim | App Functionality | Conta do profissional (ID interno) |
| **Identifiers** | Device ID | Sim | Sim | App Functionality; Analytics | UUID aleatório do aparelho |
| **Usage Data** | Product Interaction | Sim | Sim | Analytics | Tipos de evento (sem conteúdo clínico) |
| **Other Data Types** (se necessário) | Calendar events (Google Calendar opcional) | Sim, se ativado | Sim | App Functionality | Apple não tem categoria própria de calendário; declarar como “Other Data Types” e explicar na política |
| Diagnostics (crash/performance) | — | **Não** | — | — | Sentry desligado |
| Financial Info | — | **Não** | — | — | Valores ficam no aparelho |
| Location / Contacts / Browsing / Search / Purchases | — | **Não** | — | — | — |

### 4.2 Respostas gerais da App Privacy

- **Data Used to Track You:** nenhum.
- **Data Linked to You:** as linhas da tabela marcadas “Sim” (praticamente todas, pois são vinculadas à conta).
- **Data Not Linked to You:** nenhuma.
- **Privacy Policy URL:** `https://mentallpro.com.br/privacidade/`
- **Account deletion:** já existe in-app (Apple 5.1.1(v)) e página web.
- **Purpose “Third-Party Advertising” / “Developer Advertising”:** não usados.

> **Definição de “coletar” da Apple:** transmissão para fora do aparelho que permita ao app (ou a
> terceiros) acessar os dados além do atendimento imediato. Por isso o áudio e o texto enviados a
> Groq/OpenAI são declarados como coletados, mesmo sem persistência no servidor do MentAll.

---

## 5. O que deve ser respondido como “não coletado” para não superdeclarar

- Conteúdo local do prontuário (sessões, evoluções, financeiro, agenda do aparelho).
- PDFs/backups gerados no aparelho; compartilhamento é ação do usuário.
- Localização, contatos, fotos, câmera, histórico de navegação, compras.
- Diagnósticos/crash logs (Sentry desligado; não há SDK de crash ativo).
- Publicidade/rastreamento (não há SDK de ads nem IDFA/GAID).

---

## 6. Pendências e decisões antes de enviar

1. **DPA com os provedores (itens 1.6/1.7):** com DPA assinado, Fly.io/Magalu/Cloudflare podem ser
   tratados como *service providers* (não “compartilhados”). Sem DPA, declarar como compartilhados.
2. **Google Calendar no 1º envio (decisão 0.8):** se a integração for escondida no build de loja,
   **não** declarar “Calendar events”; se for publicada, declarar (e concluir a verificação OAuth 0.9).
3. **Retenção OpenAI/Groq:** só marcar “processado de forma efêmera” se houver contrato/opção de
   retenção zero. Caso contrário, declaração conservadora (coletado/compartilhado) é a correta.
4. **Contrato com conteúdo financeiro:** se o profissional digitar valores no template do contrato,
   esse texto vai ao servidor. Avaliar se a declaração “Financial info: não” continua adequada ou se
   passa a “Other financial info” (conservador). A decisão de preço/cobrança (0.6) também define se
   haverá “Purchases” no futuro.
5. **WhatsApp/Meta:** o envio de lembrete leva telefone e mensagem pela rede do WhatsApp; manter
   declarado como compartilhamento com terceiro.
6. **DPO/canal do titular:** publicar o e-mail definitivo (hoje `contato@mentallpro.com.br`) na
   política e nos formulários das lojas (item 0.7).

---

## 7. Passo a passo para preencher

1. **Play Console:** App content → Data safety → seguir §2; Health apps → §3; depois revisar
   “Permissions” (Anexo A) e “Content rating” (item 3.6).
2. **App Store Connect:** App Privacy → seguir §4; preencher URL da política e o fluxo de exclusão.
3. Tirar **prints/PDF** das respostas enviadas e guardar em `docs/lojas/` (evidência para auditoria
   e para o checklist).
4. Repetir o preenchimento **somente depois** de fechar as pendências §6 (principalmente Calendar e
   DPA), para não gerar retrabalho na revisão das lojas.

---

## Anexo A — Permissões e justificativas (apoio ao item 3.5)

| Plataforma | Permissão | Uso | Justificativa para a loja |
|---|---|---|---|
| Android | `RECORD_AUDIO` | Gravar o relato pós-sessão (até 5 min) | Recurso central de transcrição; só grava após ação do profissional |
| Android | `POST_NOTIFICATIONS` | Avisos locais de lembrete/estado | Lembretes das sessões |
| Android | `USE_BIOMETRIC` | Desbloqueio do app | Proteção de dados clínicos |
| Android | `SCHEDULE_EXACT_ALARM` | Agendar notificações locais no horário | Lembretes no horário exato |
| Android | `RECEIVE_BOOT_COMPLETED` | Reagendar notificações após reiniciar | Continuidade dos lembretes |
| Android | `INTERNET` / `VIBRATE` | API e feedback | Operação normal |
| iOS | `NSMicrophoneUsageDescription` | Gravar relato | Idem |
| iOS | `NSFaceIDUsageDescription` | Biometria | **Pendente (item 4.6)** — sem ela, risco de rejeição |

> Nenhuma permissão de localização, contatos, câmera, fotos ou sensores de saúde é usada.

---

## Referências

- Inventário de dados e exclusão: `backend/models/schemas.py`, `backend/services/{exclusao_conta,telemetria,wuzapi_admin}.py`, `backend/services/db.py`.
- Cliente: `lib/services/{telemetria_service,ia_clinica_service,backup_service}.dart`, `lib/services/google_calendar_*.dart`, `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`.
- LGPD: `docs/lgpd/03_data_mapping_e_ropa.md`, `05_politica_de_privacidade.md`, `09_transferencia_internacional.md`, `10_politica_de_retencao_e_descarte.md`, `15_lojas_google_play_e_app_store.md`.
- Textos publicados: https://mentallpro.com.br/privacidade/ · https://mentallpro.com.br/termos/ · https://mentallpro.com.br/exclusao/
