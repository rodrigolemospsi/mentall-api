# Data mapping e Registro das Operações de Tratamento (ROPA)

**Versão:** 1.0 (rascunho) · **Data:** 09/10/2026 · **Próxima revisão obrigatória:** trimestral ou a cada mudança de fluxo
**Elaborado por:** MentAll PRO (operador) — preenchido a partir do código-fonte, não de declaração de intenção
**Base legal art. 37 da LGPD** — este registro é do **controlador**; o MentAll mantém este documento
como **modelo preenchido** para o psicólogo e como registro próprio das operações em que é controlador.

⚖️ **As colunas "base legal" e "prazo de retenção" são propostas técnicas e precisam de validação
jurídica** antes de serem tratadas como definitivas.

---

## 1. Papéis por operação

| Operação | Controlador | Operador |
|---|---|---|
| O1 a O11 (prontuário, áudio, IA, anamnese, contrato, lembretes) | Psicólogo | MentAll PRO |
| O12 a O15 (conta, telemetria, segurança, painel) | **MentAll PRO** | Subprocessadores de infraestrutura |
| O16 (auditoria local) | Psicólogo | MentAll PRO (ferramenta) |

---

## 2. Operações de tratamento

### O1 — Cadastro e gestão de pessoas atendidas

| Campo | Conteúdo |
|---|---|
| Finalidade | Identificar a pessoa atendida no prontuário e permitir o registro clínico |
| Titulares | Pacientes (pessoas atendidas) |
| Dados | Nome, data de nascimento, contato, e-mail, observações, status de arquivamento |
| Categoria LGPD | Dado pessoal (art. 5º, I); pode conter dado sensível em "observações" |
| Onde fica | **Somente no aparelho do profissional** (Hive, campos cifrados) |
| Destinatários | Nenhum |
| Transferência internacional | Não |
| Retenção | Enquanto durar o tratamento + guarda legal do prontuário ⚖️ (ver documento 10) |
| Base legal proposta | Tutela da saúde (art. 11, II, "f") para o prontuário ⚖️ |
| Segurança | AES-GCM, chave em Keystore/Keychain, PIN/biometria, `allowBackup=false` |
| Evidência | `politica_privacidade_page.dart:30-49`; `encryption_service.dart:43-47,89-90`; `AndroidManifest.xml:13` |

### O2 — Registro de sessão, relato e apontamentos clínicos

| Campo | Conteúdo |
|---|---|
| Finalidade | Documentação clínica do atendimento (prontuário) |
| Titulares | Pacientes |
| Dados | Relato da sessão, data, número da sessão, apontamentos, hipóteses, plano |
| Categoria LGPD | **Dado sensível de saúde (art. 11)** |
| Onde fica | Somente no aparelho, cifrado |
| Destinatários | Nenhum (a menos que o profissional exporte) |
| Transferência internacional | Não |
| Retenção | Guarda legal do prontuário ⚖️ |
| Base legal proposta | Tutela da saúde (art. 11, II, "f") ⚖️ |
| Evidência | `politica_privacidade_page.dart:44-49`; `AGENTS.md` (seção LGPD/Privacidade) |

### O3 — Gravação do relato pós-sessão em áudio

| Campo | Conteúdo |
|---|---|
| Finalidade | Permitir que o profissional dite o relato em vez de digitar |
| Titulares | Profissional (voz) — e a pessoa atendida, se o áudio a captar |
| Dados | Áudio (dado pessoal; voz) com conteúdo clínico |
| Categoria LGPD | Dado sensível de saúde; voz = dado pessoal |
| Onde fica | No aparelho, enquanto o profissional mantiver |
| Destinatários | Provedor de transcrição (Groq/OpenAI) |
| Transferência internacional | **Sim — EUA** |
| Retenção | **[A CONFIRMAR]** depende da opção de reter/descartar áudio no app |
| Base legal proposta | Tutela da saúde para o prontuário; consentimento específico do titular para o envio a terceiro ⚖️ |
| Evidência | `transcricao.py:13-20,64-65`; `AGENTS.md` (limite de 5 min, exclusão `unawaited`) |

### O4 — Transcrição automática de áudio

| Campo | Conteúdo |
|---|---|
| Finalidade | Converter o relato em texto para o prontuário |
| Titulares | Pacientes (conteúdo clínico) + profissional (voz) |
| Dados | Áudio + transcrição resultante |
| Categoria LGPD | Dado sensível de saúde |
| Subprocessador | **Groq, Inc. (EUA)** — default; **OpenAI (EUA)** — alternativa |
| Transferência internacional | **Sim — EUA** |
| Retenção no provedor | Não declarada no contrato/documento; **verificar termos de retenção e uso** ⚖️ |
| Base legal proposta | Consentimento específico do titular + tutela da saúde ⚖️ |
| Evidência | `transcricao.py:13-20,64-65,85-99`; `backend/.env` (`TRANSCRICAO_PROVIDER=groq`) |

### O5 — Síntese clínica e evolução (IA)

| Campo | Conteúdo |
|---|---|
| Finalidade | Apoio documental: organizar o relato em síntese estruturada |
| Titulares | Pacientes |
| Dados | **Nome da pessoa atendida** + relato clínico integral + abordagem terapêutica |
| Categoria LGPD | Dado sensível de saúde |
| Subprocessadores | **OpenAI (EUA)** — primeiro; **DeepSeek (China)** — fallback automático; **Google Gemini (EUA)** — no código, fora da ordem padrão |
| Transferência internacional | **Sim — EUA e China** |
| Retenção no provedor | **Sem configuração de retenção zero** (`store:false` ausente); verificar política de cada provedor ⚖️ |
| Base legal proposta | Consentimento específico e destacado (art. 11, I), por envolver transferência e terceiro; decisão do titular sobre qual provedor ⚖️ |
| Medidas | Revisão humana obrigatória antes de salvar (gate de produto); IA não emite diagnóstico |
| Evidência | `ia_clinica.py:438-454,594-690` (endpoint DeepSeek `:648`); `main.py:890-893`; `AGENTS.md:191` |

### O6 — Indicação de artigos científicos (OpenAlex)

| Campo | Conteúdo |
|---|---|
| Finalidade | Sugerir literatura a partir do tema clínico |
| Titulares | Pacientes (indiretamente, se o tema permitir reidentificação) |
| Dados | Descritores/tema clínico; **não** deve conter nome |
| Categoria LGPD | Dado sensível (pela natureza do tema) |
| Destinatário | OpenAlex (base pública internacional) |
| Transferência internacional | Sim, mas de dado agregado/descritor |
| Risco | Baixo, se nunca incluir identificadores diretos |
| Evidência | `OPENALEX_API_KEY`/`OPENALEX_MAILTO` em `backend/.env`; `AGENTS.md` (seções de artigos) |

### O7 — Anamnese (formulário enviado à pessoa atendida)

| Campo | Conteúdo |
|---|---|
| Finalidade | Coletar histórico inicial antes/durante o atendimento |
| Titulares | Pacientes |
| Dados | Respostas do formulário (`anamneses.respostas`), template, vínculo com `owner_id` |
| Categoria LGPD | **Dado sensível de saúde** |
| Onde fica | **Banco Turso — `aws-us-west-2.turso.io` (EUA)**, **sem cifra** |
| Retenção | Indefinida no código — **[A CONFIRMAR]** |
| Base legal proposta | Tutela da saúde / consentimento ⚖️ |
| Evidência | `db.py:189-198`; `anamnese_service.py`; `.env` (`TURSO_DATABASE_URL`) |

### O8 — Contrato terapêutico com aceite eletrônico

| Campo | Conteúdo |
|---|---|
| Finalidade | Formalizar o acordo terapêutico e registrar o aceite |
| Titulares | Pacientes (e/ou responsáveis legais) |
| Dados | `contratos.dados` (JSON), `nome_aceite`, data do aceite, `owner_id` |
| Categoria LGPD | Dado pessoal + potencialmente sensível |
| Onde fica | **Turso (EUA), sem cifra** |
| Retenção | Indefinida — **[A CONFIRMAR]** |
| Base legal proposta | Execução de contrato (art. 7º, V) para o contrato; tutela da saúde para o vínculo clínico ⚖️ |
| Evidência | `db.py:180-188`; `contrato_service.py:14-15` |

### O9 — Lembretes de sessão por WhatsApp

| Campo | Conteúdo |
|---|---|
| Finalidade | Reduzir faltas, lembrando a sessão agendada |
| Titulares | Pacientes (e/ou responsáveis) |
| Dados | **Telefone, nome da pessoa, nome do profissional, data/hora da sessão** (`lembretes.telefone`, `lembretes.mensagem`) |
| Categoria LGPD | **Dado sensível** — revela que a pessoa faz psicoterapia |
| Onde fica | **Turso (EUA), sem cifra**; e no aparelho |
| Destinatário | **wuzapi (gateway não oficial do WhatsApp)** ⚖️ |
| Transferência internacional | Depende da hospedagem do wuzapi **[A CONFIRMAR]**; o transporte é da Meta |
| Base legal proposta | Consentimento específico do titular para contato por WhatsApp ⚖️ |
| Evidência | `lembrete_service.py:92-114,199-213` (schema); `compromisso.dart:159-171` |

### O10 — Telemetria de uso e presença (dispositivo)

| Campo | Conteúdo |
|---|---|
| Finalidade | Saber se o app está sendo usado, versão e plataforma; suporte e produto |
| Titulares | Profissionais |
| Dados | `owner_id`, `device_id` (UUID), plataforma, versão, **tipo** do evento (allowlist) |
| Categoria LGPD | Dado pessoal do profissional (não clínico) |
| Onde fica | Turso (EUA) — tabelas `dispositivos`, `eventos` |
| Transferência internacional | Sim (EUA) |
| Risco | Baixo — desenho explícito sem PII clínica (`telemetria.py:1-8`) |
| Base legal proposta | Legítimo interesse (art. 7º, IX) com teste documentado ⚖️ |
| Evidência | `telemetria.py:1-26` |

### O11 — Backup, exportação em PDF e compartilhamento

| Campo | Conteúdo |
|---|---|
| Finalidade | Portabilidade operacional e entrega de documentos clínicos |
| Titulares | Pacientes |
| Dados | Prontuário completo, conforme o formato escolhido (6 opções de exportação) |
| Categoria LGPD | Dado sensível |
| Destino | **Fora do controle do MentAll** (compartilhamento do sistema, e-mail, mensageiros) |
| Risco | **Alto** — uma vez exportado, o MentAll não consegue garantir cifra nem rastrear destino |
| Medidas necessárias | Cifra opcional do arquivo, aviso de dados sensíveis, marca d'água de origem, registro em auditoria |
| Situação verificada | O PDF sai **em claro, sem senha e sem evento de auditoria**, pelo compartilhamento do sistema (`pdf_export_service.dart:1544-1552`; `paciente_detail_page.dart:573-648`); o backup é incompleto e não pede confirmação no import (`backup_service.dart:33-154,166-180`) |
| Evidência | `politica_privacidade_page.dart:52`; `AGENTS.md` (6 opções / 7 geradores) |

### O12 — Conta do profissional

| Campo | Conteúdo |
|---|---|
| Finalidade | Autenticar o profissional e vincular seus dados |
| Titulares | Profissionais |
| Dados | E-mail, nome, senha (**hash**), plano, status, tokens de verificação/reset |
| Categoria LGPD | Dado pessoal |
| Onde fica | Turso (EUA) — `usuarios`, `recuperacoes`, `resets_senha` |
| Retenção | Enquanto a conta existir + prazo legal/fiscal ⚖️ |
| Base legal proposta | Execução de contrato (art. 7º, V) |
| Evidência | `db.py` (tabelas); `usuarios.py:18-95`; `main.py:703-739` |

### O13 — Auditoria de eventos no aparelho

| Campo | Conteúdo |
|---|---|
| Finalidade | Demonstrar rastreabilidade das ações que tocam o prontuário |
| Titulares | Pacientes (indiretamente) e profissional |
| Dados | Tipo do evento, descrição cifrada, data/hora, `pacienteId` |
| Categoria LGPD | Dado pessoal/sensível (descrição cifrada) |
| Onde fica | Somente no aparelho, cifrado (**apenas a `descricao`**; `tipoEvento`, `pacienteId` e `dataHora` ficam em claro) |
| Limitação conhecida | **Máximo de 1000 registros, com expurgo dos mais antigos**; descrição é decifrada no próprio objeto (`:110,123`) |
| Eventos ausentes | exportação, exclusão, remoção/regravação de áudio, acesso/consulta, import/export de backup (`:31,70-126`) |
| Evidência | `auditoria_service.dart:10,70-126` |

### O14 — Segurança, prevenção a fraude e logs técnicos

| Campo | Conteúdo |
|---|---|
| Finalidade | Proteger a conta e o serviço (rate limit, bloqueio, diagnóstico) |
| Titulares | Profissionais |
| Dados | IP, tentativas de login, e-mail mascarado, logs de erro |
| Categoria LGPD | Dado pessoal |
| Risco identificado | Erro de provedor de IA pode levar **eco de conteúdo clínico** ao log (`ia_clinica.py:673-676`) — corrigir |
| Base legal proposta | Legítimo interesse / cumprimento de obrigação de segurança (art. 7º, II e IX) ⚖️ |
| Evidência | `main.py` (`_rate_limit_check`, logs); `ia_clinica.py:673-676` |

### O15 — Painel administrativo interno

| Campo | Conteúdo |
|---|---|
| Finalidade | Operar o serviço e dar suporte |
| Titulares | Profissionais (e, se houver acesso a dados de pacientes, também eles) |
| Dados | **[A CONFIRMAR]** `backend/admin_ui.py` |
| Risco | Acesso interno a dados pessoais exige controle de acesso, trilha e minimização |

### O16 — Solicitações de titulares (art. 18)

| Campo | Conteúdo |
|---|---|
| Finalidade | Atender pedidos de acesso, correção, eliminação, portabilidade, informação |
| Situação atual | **Procedimento e canal inexistentes** |
| Dados gerados | Protocolo, resposta, decisão, prazo |
| Ação | Implementar conforme documento 13 |

---

## 3. Inventário de subprocessadores e terceiros

| Terceiro | Serviço | Dado recebido | País | Instrumento necessário |
|---|---|---|---|---|
| Turso (libSQL) / AWS | Banco de dados | Contrato, anamnese, telefone, lembrete, conta, telemetria | **EUA (us-west-2)** | Contrato + salvaguarda de transferência ⚖️ |
| Fly.io | Hospedagem do backend | Trânsito de todos os dados da API | Brasil (`gru`) / matriz EUA conforme contrato | Contrato de operador |
| **Google Calendar** (opcional) | Agenda | Resumo do evento, data/hora, sala; **sem nome de paciente por padrão** | Internacional (Google) | Contrato + salvaguarda ⚖️ |
| Groq | Transcrição | **Áudio clínico** | EUA | Contrato + salvaguarda ⚖️ |
| OpenAI | Síntese/progresso | **Nome + relato clínico** | EUA | Contrato + salvaguarda + verificação de retenção ⚖️ |
| DeepSeek | Síntese (fallback) | **Nome + relato clínico** | **China** | Contrato + salvaguarda + decisão de risco ⚖️ |
| Google (Gemini) | Síntese (inativo no padrão) | Nome + relato clínico, se usado | EUA | idem |
| OpenAlex | Literatura | Descritores clínicos **+ e-mail pessoal do profissional como `mailto`** (`ia_clinica.py:56-63,83-91`) | Internacional |
| **Sentry** (opt-in, desligado por padrão) | Relatório de erros | Stack trace, plataforma, versão — sem PII, sem corpo de requisição e sem breadcrumbs (`main.dart:73-105`) | EUA |
| **Gmail SMTP** | E-mails de verificação/reset | E-mail do profissional, código/token (`main.py:1709-1713`) | EUA |
| **CFP (`cn-api.cfp.org.br`)** | Verificação de CRP | CRP informado; devolve nome oficial (`crp_service.py:10,30-34`) | **Brasil** |
| **wuzapi** (gateway não oficial) | WhatsApp | Telefone, nome, mensagem; token de sessão do profissional guardado em `wuzapi_instancias` | **[A CONFIRMAR]** ⚖️ |
| `[provedor do wuzapi]` | Hospedagem do gateway | Telefone, nome, mensagem | **[A CONFIRMAR]** |
| Google Play / Apple | Distribuição | Dados de conta de desenvolvedor; Data Safety | EUA | Ver documento 15 |

---

## 4. Fluxo resumido por titular

**Pessoa atendida (paciente):**
` profissional digita (aparelho) → cifra local → [anamnese/contrato] Turso EUA → áudio → Groq EUA →
texto → OpenAI EUA (ou DeepSeek China) → síntese volta ao aparelho → PDF exportado → destino fora do
controle → lembrete por WhatsApp via wuzapi `

**Profissional:**
` cadastro → e-mail de verificação (SMTP) → conta no Turso EUA → login JWT → telemetria (sem PII) → logs técnicos `

---

## 5. Itens pendentes de confirmação

Situação após as auditorias independentes de cliente e servidor:

| Item | Situação | Evidência |
|---|---|---|
| Retenção/uso dos dados pelos provedores de IA (termos e contratos) | **EM ABERTO** — nenhuma configuração de retenção zero (`store:false`) foi encontrada; condições a documentar por provedor | `ia_clinica.py:594-690`; `transcricao.py` |
| Se o app oferece "não manter áudio" e por quanto tempo o áudio fica | **PARCIALMENTE ESCLARECIDO** — existe a opção, mas a exclusão no caminho "não manter" é `unawaited`, e o arquivo fica **em claro durante a gravação** | `audio_relato_service.dart:92` vs `:171`; `AGENTS.md` |
| Região real do gateway WhatsApp (wuzapi) e provedor de SMTP em produção | **EM ABERTO** | `backend/.env` (dev aponta para `localhost:8080`) |
| Conteúdo e proteção do painel administrativo | **PARCIALMENTE ESCLARECIDO** — mostra nome/e-mail/plano do profissional sem máscara para o dono; protegido por senha própria | `admin_ui.py:104-120` |
| Rota de exclusão de conta e o que ela apaga | **RESOLVIDO: NÃO EXISTE** — nenhum endpoint no backend e nenhuma tela no app | varredura de `main.py`; `conta_page.dart` |
| Aceite de termos/DPA no cadastro | **RESOLVIDO: NÃO EXISTE** — há um checkbox de perfil **sem persistência** de data/versão; `onboarding_page.dart` é código morto | `perfil_profissional_form_page.dart:918-922`; `onboarding_page.dart:9-21` |
| IDOR (acesso a dados de outro profissional) | **RESOLVIDO: NÃO ENCONTRADO** — isolamento por `owner_id` correto nos endpoints auditados, com testes dedicados | `tests/test_status_idor.py`, `test_recuperacao_idor.py`, `test_lembrete_idor.py` |
| Cifra em repouso no servidor | **RESOLVIDO: NÃO EXISTE** — `json.dumps` gravado direto | `contrato_service.py:14-15`; `db.py:180-213` |
| Retenção/expurgo automático no servidor | **RESOLVIDO: NÃO EXISTE** — nenhuma coluna de expiração, nenhum job | `db.py:179-314` |

> Enquanto a primeira e a terceira linha estiverem abertas, o ROPA deve ser tratado como **rascunho** e
> não pode ser apresentado à ANPD como registro definitivo.
