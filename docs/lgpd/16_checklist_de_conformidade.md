# 16 — Checklist de conformidade LGPD (operacional e verificável)

**Versão:** 1.0 · **Data:** 09/10/2026 · **Produto:** MentAll PRO (cliente Flutter `1.0.49` + backend FastAPI)
**Natureza:** instrumento de trabalho — **rascunho para revisão**. Não é certificação, não é parecer
jurídico e **não** atesta conformidade. ⚖️ = depende de validação jurídica.
**Base:** verificação direta no código em 09/10/2026, consolidada em `_base_factual.md`,
`01_diagnostico_lgpd.md`, `02_plano_de_acao.md`, `03_data_mapping_e_ropa.md` e
`04_papeis_e_contrato_controlador_operador.md`.

---

## Como usar

| Status | Significado |
|---|---|
| **Atende** | Comportamento ou instrumento existe e foi verificado |
| **Atende parcialmente** | Existe, mas tem furo relevante ou escopo menor do que o necessário |
| **Não atende** | Ausente ou contrário ao exigido |
| **Não verificado** | Não foi possível confirmar no código/ambiente nesta data — **não tratar como conforme** |

**Regra de evidência:** toda linha factual aponta `arquivo:linha` ou remete ao diagnóstico/documento.
Linha sem evidência não pode ser usada em documento público.

---

## 1. Governança e accountability

| # | Item | Status | Evidência | Ação | Referência |
|---|---|---|---|---|---|
| G1 | Encarregado (DPO) nomeado, com identidade e canal publicados | **Não atende** | Política diz apenas "fale com o desenvolvedor" (`lib/screens/lgpd/politica_privacidade_page.dart:119-122`); sem nome, sem e-mail, sem canal | Nomear e publicar | **P1.1**; doc. 13 |
| G2 | Registro das operações de tratamento (ROPA, art. 37) | **Atende parcialmente** | `03_data_mapping_e_ropa.md` existe como **rascunho**, com 7 itens pendentes de confirmação (seção 5 do doc. 03) | Fechar as confirmações e nomear responsável | **P1.3**; doc. 03 §5 |
| G3 | RIPD (art. 38) do tratamento com IA | **Não atende** | Inexistente; caso tipicamente exigível (dado sensível + IA + transferência internacional) | Produzir e aprovar | **P1.4**; doc. 08 |
| G4 | Contrato controlador-operador (DPA, art. 39) | **Não atende** | O próprio PDF de arquitetura marca "Acordo de Tratamento de Dados" como ausente (`lib/services/lgpd/pdf_arquitetura_lgpd_service.dart:354`) | Assinar com cada psicólogo | **P1.2**; doc. 04 |
| G5 | Lista de subprocessadores publicada e anexa ao DPA | **Atende parcialmente** | Existe inventário técnico (`03_data_mapping_e_ropa.md` §3), mas sem contrato e sem versão pública | Publicar após decisões D1/D2 | **P1.2**; doc. 04 Anexo II |
| G6 | Registro de decisões (documento vivo) | **Atende** | `17_registro_de_decisoes_e_revisoes.md` (este pacote) | Manter atualizado a cada decisão | doc. 17 |
| G7 | Aceite versionado dos termos/DPA no onboarding do profissional | **Não atende** | Checkbox de perfil **sem persistência de data/versão** (`lib/screens/perfil_profissional_form_page.dart:918-922`); `lib/screens/onboarding_page.dart:9-21` é **código morto** | Implementar aceite auditável | **P2.18** |
| G8 | Trilha de auditoria de eventos relevantes | **Atende parcialmente** | Existe (`lib/services/lgpd/auditoria_service.dart`), mas com **limite de 1000 registros e expurgo dos mais antigos** (`:10,94-102`), faltam eventos de eliminação, acesso, exportação, backup e áudio (`:19-34`), e `_registrarAuditoria` **não é `await`ado** (projeto registra o furo) | Sem perda silenciosa; `await` | **P2.1**, **P2.2**, **P2.3** |
| G9 | Governança de IA (registro de modelo, provedor, versão e finalidade por operação) | **Não atende** | Provedores trocam em fallback automático (`backend/services/ia_clinica.py:761-781`; `AGENTS.md:191`), sem registro por operação | Registrar provedor/versão por síntese | **P0.2**; doc. 08 |
| G10 | Atribuição formal de responsabilidades internas (quem responde por LGPD) | **Não verificado** | Não há documento de papéis internos no pacote | Formalizar | **P1.3** |

---

## 2. Transparência

| # | Item | Status | Evidência | Ação | Referência |
|---|---|---|---|---|---|
| T1 | Política de Privacidade em URL pública, ativa e não-PDF | **Não atende** | Só página in-app (`lib/screens/lgpd/politica_privacidade_page.dart`); site irmão tem apenas `index.html` (`tasks/lojas_app.md:32-34`) | Publicar e linkar | **P0.5** |
| T2 | Termos de Uso em URL pública | **Não atende** | Idem (`lib/screens/lgpd/termos_uso_page.dart`) | Publicar | **P0.5** |
| T3 | Política lista **todos** os terceiros reais, com país e finalidade | **Não atende** | Cita "OpenAI ou Google Gemini" (`politica_privacidade_page.dart:71-73`) e omite **Groq** (EUA) e **DeepSeek** (China) | Corrigir | **P0.1** |
| T4 | Termos descrevem a tecnologia realmente em uso | **Não atende** | "OpenAI Whisper" e "OpenAI GPT-4.1" (`termos_uso_page.dart:35-36`); produção usa Groq + OpenAI + DeepSeek | Corrigir | **P0.1** |
| T5 | Aviso de IA ao profissional (o que sai, para onde, o que volta) | **Não atende** | O card só fala de revisão humana (`lib/widgets/lgpd/aviso_privacidade_ia_card.dart`) | Reescrever com provedores, país e finalidade | **P0.1**; doc. 08 |
| T6 | Informação sobre decisão automatizada e revisão humana (art. 20) | **Atende parcialmente** | Gate de revisão humana existe (`01_diagnostico_lgpd.md` §4.4), mas não está escrito na política | Escrever na política | doc. 05 |
| T7 | Canal de atendimento ao titular (art. 18), com prazo declarado | **Não atende** | A política empurra o dever inteiro ao psicólogo sem procedimento (`politica_privacidade_page.dart:89-98`) | Criar canal e procedimento | **P1.8**; doc. 13 |
| T8 | Versão e data de última atualização corretas | **Não atende** | "Julho de 2026" (`politica_privacidade_page.dart:122`; `termos_uso_page.dart:101`), anteriores às mudanças de código | Versionar | **P0.1** |
| T9 | Aviso de privacidade ao titular (pessoa atendida), que não é usuária do app | **Não atende** | Módulo de consentimentos marcado como não implementado no próprio PDF (`pdf_arquitetura_lgpd_service.dart:241`) | Entregar material | **P1.5**; doc. 07 |
| T10 | Transparência sobre telemetria e forma de desligar | **Não atende** | Telemetria **sempre ativa**, sem opt-out (`lib/services/telemetria_service.dart:16-40,72-90`) | Implementar opt-out e aviso | **P1.14** |
| T11 | Explicação do que é cifrado e do que **não** é | **Não atende** | Política afirma "AES-256 em repouso" (`politica_privacidade_page.dart:59`) sem escopo; há campos sensíveis em claro (C6) | Declarar o escopo real | **P2.12**; doc. 05 |
| T12 | Compromisso de proteção equivalente por terceiros (exigido pela Apple 5.1.1(i)) | **Não atende** | Sem DPA com subprocessadores | Contratar e declarar | **P1.2** |

---

## 3. Base legal e consentimento

| # | Item | Status | Evidência | Ação | Referência |
|---|---|---|---|---|---|
| B1 | Base legal identificada por finalidade (art. 7º / art. 11) | **Atende parcialmente** | Proposta técnica por operação (`03_data_mapping_e_ropa.md`, coluna "base legal proposta"), marcada como ⚖️ | Validar juridicamente | doc. 03; doc. 08 |
| B2 | Enquadramento da tutela da saúde (art. 11, II, "f") para o prontuário | **Atende parcialmente** | Proposto, com ressalva expressa de que a IA **não** se enquadra automaticamente (`01_diagnostico_lgpd.md` §3) | Validar ⚖️ | doc. 08 |
| B3 | Registro de consentimento do titular (pessoa atendida) | **Não atende** | "Consentimentos" marcado como não implementado (`pdf_arquitetura_lgpd_service.dart:241`) | Implementar registro com data/hora/versão | **P1.5** |
| B4 | Consentimento específico e destacado para IA e transferência internacional | **Não atende** | Não existe; o profissional não escolhe provedor nem é avisado do fallback (`01_diagnostico_lgpd.md` §4.1) | Implementar por pessoa atendida ou remover o provedor | **P0.2**; doc. 08 |
| B5 | Consentimento para contato por WhatsApp | **Não atende** | Nada no app pede consentimento específico (`01_diagnostico_lgpd.md` §4.9) | Coletar e registrar | **P2.7** |
| B6 | Base legal para telemetria (legítimo interesse) com teste documentado | **Não atende** | Telemetria sem opt-out e sem teste de balanceamento (`telemetria.py:1-26`; `telemetria_service.dart:16-40`) | Fazer o teste e publicar aviso | **P1.14**; doc. 08 |
| B7 | Revogação de consentimento fácil e documentada (art. 8º, §5) | **Não atende** | Não há mecanismo | Implementar | **P1.5**, **P1.14** |
| B8 | Minimização: coletar só o necessário | **Atende parcialmente** | Telemetria por allowlist sem PII é ponto forte (`telemetria.py:1-26`); por outro lado, o prompt de síntese envia **nome + relato integral** (`ia_clinica.py:438-454`) | Reduzir identificadores no prompt | **P0.2** |

---

## 4. Direitos do titular (art. 18)

| # | Item | Status | Evidência | Ação | Referência |
|---|---|---|---|---|---|
| D1 | Confirmação de tratamento e acesso | **Não atende** | Sem canal nem procedimento (`politica_privacidade_page.dart:89-98`) | Criar procedimento | **P1.8** |
| D2 | Correção de dados | **Atende parcialmente** | O profissional corrige no app; a pessoa atendida **não** tem caminho direto (`01_diagnostico_lgpd.md` §4.4) | Criar caminho via profissional + registro | **P1.8**, **P2.10** |
| D3 | Anonimização, bloqueio ou eliminação (art. 18, IV) | **Não atende** | Não existe no backend: contratos, anamneses, lembretes, contas e telemetria **nunca são apagados** (`01_diagnostico_lgpd.md` §4.13) | Implementar | **P1.9**; doc. 10 |
| D4 | Portabilidade | **Atende parcialmente** | Há 6 formatos de exportação em PDF para uso clínico, não como mecanismo do titular (`01_diagnostico_lgpd.md` §4.4) | Definir formato de portabilidade | doc. 10 |
| D5 | Eliminação de dados pessoais (art. 18, VI) | **Não atende** | Não existe exclusão de conta; `excluirPaciente` é hard delete **sem chamador** (`lib/services/paciente_service.dart:113-166`) | Implementar | **P1.9** |
| D6 | Informação sobre compartilhamento (art. 18, VII) | **Não atende** | Política omite Groq e DeepSeek | Corrigir | **P0.1** |
| D7 | Revisão de decisão automatizada (art. 20) | **Atende parcialmente** | Revisão humana obrigatória existe; informação ao titular não | Escrever e informar | doc. 05, doc. 08 |
| D8 | Prazos e registro de solicitações | **Não atende** | Inexistentes | Definir e registrar | **P1.8**; doc. 13 |
| D9 | Exclusão de conta no app e URL externa (lojas) | **Não atende** | Zero ocorrências de exclusão de conta em `lib/` e no backend | Implementar | **P1.9** |
| D10 | Porta de entrada acessível à pessoa atendida (que não usa o app) | **Não atende** | Só existe contato com o profissional | Publicar canal do encarregado | **P1.1**, **P1.8** |

---

## 5. Retenção e descarte

| # | Item | Status | Evidência | Ação | Referência |
|---|---|---|---|---|---|
| R1 | Política de retenção e descarte documentada | **Não atende** | Inexistente; a regra declarada é apenas "arquivar, não excluir" (`politica_privacidade_page.dart:82-84`) | Publicar | **P1.6**; doc. 10 |
| R2 | Prazo de guarda do prontuário justificado (guarda legal) | **Não atende** | Nenhum prazo definido em lugar nenhum | Definir com base profissional ⚖️ | **P1.6** |
| R3 | Retenção específica do **áudio** (prazo, exclusão após transcrição, falha de exclusão) | **Não atende** | Projeto registra exclusão `unawaited` do áudio (`AGENTS.md`) | Definir e implementar | **P2.5** |
| R4 | Expurgo automático no servidor | **Não atende** | Não há coluna de expiração, job de expurgo nem retenção (`01_diagnostico_lgpd.md` §4.13) | Implementar | **P1.9**; doc. 10 |
| R5 | Descarte seguro da cópia local em texto claro com dados reais | **Não atende** | `backend/data/mentall.db` com 3 contratos e 1 anamnese em claro (`01_diagnostico_lgpd.md` §4.13) | Eliminar e definir descarte | **P0.11** |
| R6 | Retenção de logs técnicos com segredos/PII, com expurgo | **Não atende** | Token do webhook na query string aparece 130.593 vezes em `backend.launchd.log` (`01_diagnostico_lgpd.md` §4.13); sem `RotatingFileHandler` | Rotacionar segredo, expurgar log, mascarar | **P1.13** |
| R7 | Retenção de dados de conta após encerramento | **Não atende** | Não há fluxo de encerramento | Definir | **P1.9**, **P1.6** |
| R8 | Links públicos (anamnese/contrato) com expiração e revogação | **Não atende** | Links válidos enquanto a linha existir; sem coluna de expiração (`db.py:180-198`); página pública embute o nome da pessoa atendida (`main.py:1468,1530,1650-1658`) | Expiração + revogação + remover nome | **P1.11** |
| R9 | Descarte de dados de demonstração separado do prontuário real | **Não atende** | Seed "Linda M. Tester" em instalação nova (`lib/services/demo_data_service.dart:35-78`; `main.dart:192`) | Isolar | **P2.17** |

---

## 6. Segurança da informação (art. 46)

### 6.1 Controles existentes (preservar)

| # | Controle | Status | Evidência |
|---|---|---|---|
| S1 | Cifra **por campo** AES-GCM no aparelho, chave no Android Keystore / iOS Keychain, derivação PBKDF2 | **Atende** | `lib/services/encryption_service.dart:13-18,43-47,89-90,502-523` |
| S2 | Fail-closed: `encrypt` lança `StateError` sem proteção, bloqueando uso | **Atende** | `lib/services/encrypted_service_mixin.dart:6-16`; `lib/screens/app_start_page.dart:83-85` |
| S3 | `android:allowBackup="false"` e `usesCleartextTraffic="false"` | **Atende** | `android/app/src/main/AndroidManifest.xml:13-14` |
| S4 | Envelope de backup AES-GCM + HMAC-SHA256 | **Atende** | `lib/services/encryption_service.dart:525,588` |
| S5 | Telemetria por allowlist, sem conteúdo clínico | **Atende** | `backend/services/telemetria.py:1-26` |
| S6 | Sentry desligado por padrão e configurado sem PII | **Atende** | `lib/main.dart:73-105` |
| S7 | Log técnico cifrado/redigido (sem conteúdo clínico) | **Atende** | `lib/services/logger.dart:115-124` |
| S8 | Isolamento por `owner_id` com testes dedicados de IDOR | **Atende** | `backend/tests/test_status_idor.py`, `test_recuperacao_idor.py`, `test_lembrete_idor.py` (`01_diagnostico_lgpd.md` §4.13) |
| S9 | Cabeçalho CSP com nonce, sem `unsafe-inline` | **Atende** | `backend/main.py:675-677`; `backend/tests/test_csp.py`; `tasks/lojas_app.md:18-19` |
| S10 | `.env` fora do versionamento; histórico sem chaves | **Atende** | `.gitignore:2-3` (`01_diagnostico_lgpd.md` §4.13) |
| S11 | Permissões proporcionais à função | **Atende parcialmente** | `AndroidManifest.xml:2-8` — conferir justificativa de `SCHEDULE_EXACT_ALARM` |

### 6.2 Controles ausentes ou frágeis

| # | Achado | Status | Evidência | Ação | Referência |
|---|---|---|---|---|---|
| S12 | Áudio clínico gravado **em claro** e cifrado só depois do `stop()`; sem varredura de órfãos | **Não atende** | `lib/services/audio_relato_service.dart:92` vs `:171`, `:416-437`, `:509-512` | Gravar em contêiner cifrado | **P0.8** |
| S13 | Desbloqueio **fail-open** em lockout de biometria / erro de hardware / ausência de credencial | **Não atende** | `lib/services/auth_service.dart:203-215,237-250`; `lib/screens/login_page.dart:56-66` | Exigir autenticação bem-sucedida | **P0.7** |
| S14 | PIN inexistente em instalação nova; reautenticação para exportar backup não funciona | **Não atende** | `lib/services/encryption_service.dart:399-406`; `lib/screens/backup_restore_page.dart:24-35` | Implementar | **P0.7** |
| S15 | Certificate pinning inefetivo (`badCertificateCallback`) | **Não atende** | `lib/main.dart:45-68`; contradiz `SECURITY_CHANGELOG.md` (SEC-05) | Implementar ou corrigir a afirmação | **P0.10** |
| S16 | Bloqueio apenas visual: chave permanece na memória, sem `FLAG_SECURE`, sem detecção de root | **Não atende** | `lib/services/encryption_service.dart:656-663` (sem chamador); `lib/widgets/app_lock_gate.dart:95-113` | Limpar chave, `FLAG_SECURE` | **P0.9** |
| S17 | Campos sensíveis em claro no Hive (data de nascimento, tipo/modo de atendimento, valores/status/forma de pagamento, data da sessão, flags) | **Não atende** | `lib/models/paciente.dart:13-14,19-20,49-50`; `lib/models/sessao.dart:20,119-120,158-168`; `lib/services/sessao_service.dart:80` | Cifrar | **P2.12** |
| S18 | **Sem cifra em repouso no servidor** | **Não atende** | `backend/services/contrato_service.py:14-15` (`json.dumps` direto); nenhum serviço cifra antes de persistir | Cifrar ou parar de persistir | **P0.4** |
| S19 | Erro de provedor de IA gravado em log, com risco de eco de conteúdo clínico | **Não atende** | `backend/services/ia_clinica.py:673-676` (`resp.text[:500]`) | Nunca logar corpo de resposta | **P2.8** |
| S20 | Perda silenciosa de dados: `ALLOW_SQLITE_FALLBACK` default `true` e `/health` responde `ok` em fallback | **Não atende** | `backend/services/db.py:15-17`; `backend/main.py:688-700` | Desligar em produção e reprovar no `/health` | **P1.12**, **P2.4** |
| S21 | `APP_USER_ID` ausente → UUID novo a cada boot; dados órfãos a cada restart | **Não atende** | `backend/main.py:241` | Fixar a variável | **P1.12** |
| S22 | Conta legada compartilhada (`APP_USERNAME`/`APP_PASSWORD_HASH`): usuários compartilham o mesmo `owner_id` | **Não atende** | `backend/main.py:236-240,710-719` | Eliminar o caminho legado | **P1.12** |
| S23 | JWT de 8 h sem revogação, sem `jti`, sem logout no servidor | **Não atende** | `backend/main.py:234-235` | Implementar revogação/logout | **P2.14** |
| S24 | Trilha de auditoria **só no aparelho** — servidor sem trilha de acesso a dado clínico | **Não atende** | `lib/services/lgpd/auditoria_service.dart:1,17` | Criar trilha de servidor | **P2.2** |
| S25 | Chave mestra sem vínculo com a autenticação; sem rekey/recuperação; perda do Keystore é irreversível | **Não atende** | `lib/services/encryption_service.dart:70,252-264`; `lib/services/backup_service.dart:191-194` | Definir recuperação | **P2.13** |
| S26 | Backup incompleto (não inclui compromissos, anamnese, escalas, avaliação inicial nem auditoria) e com sobrescrita silenciosa | **Não atende** | `lib/services/backup_service.dart:33-154,166-180` | Completar e pedir confirmação | **P2.15** |
| S27 | PDF de prontuário em claro, sem senha, sem aviso e sem evento de auditoria | **Não atende** | `lib/services/pdf_export_service.dart:1544-1552`; `lib/screens/paciente_detail_page.dart:573-648` | Proteger e rastrear | **P1.16** |
| S28 | Código morto capaz de reverter proteção (`removerCriptografiaExistente` em 11 serviços; `excluirPaciente`; `onboarding_page.dart`; `migrarParaGcm`) | **Não atende** | `lib/services/paciente_service.dart:168`; `lib/services/sessao_service.dart:252`; `lib/services/configuracoes_service.dart:178`; `AGENTS.md:1698-1706` | Remover ou cercar com teste | **P2.14** |
| S29 | CORS de produção com origens de desenvolvimento e `allow_credentials=True` | **Não atende** | `backend/main.py:647-664` | Restringir a origens de produção | **P2.11** |
| S30 | Rate limit em memória por processo | **Atende parcialmente** | `backend/main.py:202-228` | Mover para armazenamento compartilhado | **P2.4** |
| S31 | Logs sem rotação (21 MB locais) | **Não atende** | `01_diagnostico_lgpd.md` §4.13 | `RotatingFileHandler` + expurgo | **P1.13** |
| S32 | Exclusão de backup do prontuário no iOS não verificada (Apple 5.1.3(ii): não armazenar dado de saúde no iCloud) | **Não verificado** | Nenhum uso de `NSURLIsExcludedFromBackupKey` em `lib/` ou `ios/` (busca sem resultados) | Verificar e excluir o diretório do prontuário | doc. 15 §3.4 |
| S33 | Ausência de `NSFaceIDUsageDescription` e `ITSAppUsesNonExemptEncryption` | **Não atende** | `ios/Runner/Info.plist` — nenhuma ocorrência de `FaceID` ou `Encryption` | Adicionar as chaves | **P2.16** |
| S34 | Re-scan de segurança (Strix) posterior às mudanças de 06/10 | **Não verificado** | Último scan em 30/08 (`tasks/lojas_app.md:20-23`) | Reexecutar | `tasks/lojas_app.md` §1 |
| S35 | Testes automatizados cobrindo os fluxos de privacidade | **Atende parcialmente** | Suítes com Flutter 276/276 e backend 246/246 (`tasks/lojas_app.md:56-59`), mas **sem teste** de que a chave não é carregada sem autenticação nem de que o áudio nunca existe em claro | Criar testes (critério de pronto de P0.7 e P0.8) | **P0.7**, **P0.8** |

---

## 7. Terceiros e transferência internacional

| # | Item | Status | Evidência | Ação | Referência |
|---|---|---|---|---|---|
| X1 | Mapa de transferência internacional completo e atualizado | **Atende parcialmente** | `03_data_mapping_e_ropa.md` §3 tem o inventário; itens ainda **[A CONFIRMAR]** (região do wuzapi, SMTP, painel admin) | Fechar as confirmações | **P1.3** |
| X2 | Mecanismo do art. 33 escolhido e documentado | **Não atende** | Sem salvaguarda documentada para EUA e China (`01_diagnostico_lgpd.md` §4.1) | Escolher e documentar ⚖️ | **P0.3**; doc. 09 |
| X3 | Banco de dados em região coerente com o discurso "dados no Brasil" | **Não atende** | Banco em `aws-us-west-2.turso.io` (EUA) enquanto o backend está em `gru` (`backend/.env`; `fly.toml:2-3`) | Migrar ou documentar | **P0.3** |
| X4 | Dado sensível legível no banco estrangeiro | **Não atende** | `db.py:180-213`; `contrato_service.py:14-15` (sem cifra) | Cifrar ou parar de persistir | **P0.4** |
| X5 | Fallback automático que muda o **país** do processamento na mesma operação | **Não atende** | `ia_clinica.py:648,761-781`; `AGENTS.md:191` | Remover ou exigir consentimento | **P0.2** |
| X6 | Contrato com cada subprocessador (Groq, OpenAI, DeepSeek, Google, Turso, Sentry, SMTP, wuzapi) | **Não atende** | Sem instrumentos; sem exclusão de "compartilhamento" no Data Safety | Contratar | **P1.2**, **P1.10** |
| X7 | Retenção/uso do dado pelos provedores de IA verificado por contrato | **Não atende** | Sem `store:false` nem retenção zero nos payloads (`01_diagnostico_lgpd.md` §4.1) | Configurar ou comprovar | **P0.6** |
| X8 | Gateway de WhatsApp não oficial avaliado (risco de terceiro sem contrato e de regras da Meta) | **Não atende** | `backend/services/wuzapi_admin.py`; `backend/services/lembrete_service.py:92-114` | Decidir (D4) | **P2.7**; doc. 17 |
| X9 | Segredos de sessão do profissional guardados em banco estrangeiro | **Não atende** | `wuzapi_instancias.wuzapi_token` (`db.py:261-267`) | Rever arquitetura | **P1.13** |
| X10 | Envio de descritores clínicos e e-mail pessoal a base pública internacional (OpenAlex) | **Atende parcialmente** | `backend/services/ia_clinica.py:56-63,83-91` | Remover o e-mail pessoal e confirmar que não há identificador | doc. 09 |

---

## 8. Incidentes

| # | Item | Status | Evidência | Ação | Referência |
|---|---|---|---|---|---|
| I1 | Plano de resposta a incidentes documentado | **Não atende** | Inexistente (`_base_factual.md` §8, item 7) | Produzir | **P1.7**; doc. 11 |
| I2 | Critérios de classificação (o que é "risco ou dano relevante") | **Não atende** | Inexistente | Definir | **P1.7** |
| I3 | Prazo e formulário de comunicação à ANPD e ao titular | **Não atende** | Inexistente; prazo regulatório **não confirmado neste pacote** | Confirmar o prazo na norma/regulamentação vigente e documentar | **P1.7**; doc. 11 |
| I4 | Compromisso contratual de aviso ao controlador (psicólogo) | **Não atende** | Minuta prevê `[24]` horas, com campo em aberto (`04_papeis_e_contrato_controlador_operador.md`, cláusula 8) | Fechar o prazo com o advogado | **P1.2**, **P1.7** |
| I5 | Registro de incidentes | **Não atende** | Inexistente | Criar planilha/registro | **P1.7** |
| I6 | Simulado de incidente executado | **Não atende** | Nunca executado | Executar anualmente | **P3.3**; doc. 17 §5 |
| I7 | Detecção: alertas de falha de cifra, de fallback de banco e de vazamento de segredo em log | **Não atende** | `/health` sempre `ok` (`backend/main.py:688-700`); segredo em log por meses (130.593 ocorrências) | Criar alertas | **P2.4**, **P1.13** |

---

## 9. Menores de idade (art. 14)

| # | Item | Status | Evidência | Ação | Referência |
|---|---|---|---|---|---|
| M1 | Campo de responsável legal | **Não atende** | Nenhum campo encontrado em `lib/models/paciente.dart` | Implementar | **P1.15** |
| M2 | Autorização/consentimento específico para atendimento de criança ou adolescente | **Não atende** | Nenhum fluxo | Implementar | **P1.15** |
| M3 | Menção a menores na Política de Privacidade | **Não atende** | Política não trata do tema (`lib/screens/lgpd/politica_privacidade_page.dart`) | Escrever seção | **P1.15** |
| M4 | Melhor interesse da criança avaliado e registrado | **Não atende** | Inexistente | Registrar no RIPD | **P1.4**, **P1.15** |
| M5 | Idade calculada a partir da data de nascimento, que hoje fica **em claro** no Hive | **Atende parcialmente** | `lib/models/paciente.dart:13-14` | Cifrar | **P2.12** |
| M6 | Faixa etária declarada nas lojas com tratamento de dado de menor | **Não atende** | Não declarada (`tasks/lojas_app.md:31`) | Declarar com cuidado | doc. 15 §2.5 |

---

## 10. Lojas (detalhamento em `15_lojas_google_play_e_app_store.md`)

| # | Item | Status | Evidência | Ação | Referência |
|---|---|---|---|---|---|
| L1 | Política e Termos em URL pública | **Não atende** | `tasks/lojas_app.md:32-34` | Publicar | **P0.5** |
| L2 | Exclusão de conta no app + URL de exclusão | **Não atende** | Sem código de exclusão de conta | Implementar | **P1.9** |
| L3 | Play Data Safety preenchido | **Não atende** | Não produzido | Preencher e conferir | **P1.10** |
| L4 | Play — declaração de apps de saúde | **Não atende** | Não preenchida | Preencher | **P1.10** |
| L5 | Apple App Privacy (nutrition labels) | **Não atende** | Não produzido | Preencher | **P1.10** |
| L6 | `ITSAppUsesNonExemptEncryption` e `NSFaceIDUsageDescription` | **Não atende** | `ios/Runner/Info.plist` (ausentes) | Adicionar | **P2.16** |
| L7 | Classificação de conteúdo (Play/IARC) e faixa etária (Apple) | **Não atende** | Não preenchidas | Preencher | doc. 15 §2.6, §3.6 |
| L8 | Divulgação de compartilhamento com IA e permissão explícita (Apple 5.1.2(i)) | **Não atende** | `lib/widgets/lgpd/aviso_privacidade_ia_card.dart` | Corrigir e implementar permissão | **P0.1**, **P1.5** |
| L9 | Contas de desenvolvedor (Play US$ 25 única; Apple US$ 99/ano) | **Não atende** | `tasks/lojas_app.md:40` | Contratar | doc. 15 §1 R15 |
| L10 | Keystore de produção | **Não atende** | `tasks/lojas_app.md:35-36` | Gerar e guardar fora do repositório | doc. 15 §1 R17 |
| L11 | Conta de demonstração para revisão (Apple) | **Não atende** | `tasks/lojas_app.md:42-43` | Preparar | doc. 15 §3.3 |
| L12 | Textos de loja sem alegação não sustentada | **Atende parcialmente** | Lista de bloqueio editorial em doc. 15 §5.4 | Aplicar antes do envio | **P0.1** |

---

## 11. Treinamento e material de apoio

| # | Item | Status | Evidência | Ação | Referência |
|---|---|---|---|---|---|
| TR1 | Guia LGPD do psicólogo (o que perguntar à pessoa atendida, o que avisar) | **Não atende** | Material inexistente (`_base_factual.md` §8, item 8) | Produzir | **P1.5**; doc. 14 |
| TR2 | Material de repasse ao titular (aviso + consentimento) | **Não atende** | Módulo não implementado (`pdf_arquitetura_lgpd_service.dart:241`) | Produzir e entregar | **P1.5**; doc. 07 |
| TR3 | Treinamento interno sobre canal do titular e resposta a incidentes | **Não verificado** | Sem registro | Executar e registrar | **P1.7**, **P1.8** |
| TR4 | Orientação ao profissional sobre guarda legal e limites do direito de eliminação | **Não atende** | Nada no app | Incluir no guia | **P1.6**, doc. 14 |
| TR5 | Orientação sobre uso de IA (o que não inserir, o que revisar) | **Atende parcialmente** | Existe card de revisão humana (`aviso_privacidade_ia_card.dart`), sem provedores nem país | Ampliar | **P0.1** |
| TR6 | Onboarding explicando o enquadramento controlador/operador | **Não atende** | Enquadramento declarado só na política (`politica_privacidade_page.dart:76-77`); onboarding é código morto (`onboarding_page.dart:9-21`) | Implementar | **P2.18** |

---

## 12. Semáforo executivo

### O que **dá** para afirmar hoje (com evidência)

1. **No aparelho, o desenho de proteção é sólido quando funciona:** cifra por campo AES-GCM com chave
   em Keystore/Keychain, `allowBackup=false`, backup com envelope AES-GCM + HMAC, telemetria sem
   conteúdo clínico por allowlist, Sentry desligado por padrão e sem PII, log técnico redigido,
   isolamento por `owner_id` com testes de IDOR, e gate de revisão humana antes de salvar
   (`01_diagnostico_lgpd.md` §1 e §4.14; `11` de §6.1 deste documento).
2. **O produto reconhece as próprias lacunas:** existe PDF de arquitetura LGPD com 14 seções que
   marca os módulos ausentes (`lib/services/lgpd/pdf_arquitetura_lgpd_service.dart:351-354`).
3. **O enquadramento de papéis está declarado pelo próprio app:** psicólogo = controlador;
   MentAll = operador quanto ao prontuário (`politica_privacidade_page.dart:76-77`).
4. **A base documental de governança está iniciada:** ROPA em rascunho, DPA em minuta, diagnóstico,
   plano de ação e este checklist (`03`, `04`, `01`, `02`, `16`).
5. **A rastreabilidade de ações existe** (ainda com furos) e a minimização de telemetria é real.

### O que **não** dá para afirmar hoje

1. **Que o prontuário fica no Brasil** — o banco está em `aws-us-west-2` (EUA) (`backend/.env`).
2. **Que o dado sensível está cifrado em repouso** — não há cifra no servidor
   (`contrato_service.py:14-15`) nem nos campos sensíveis do Hive (C6).
3. **Que os terceiros de IA são apenas "OpenAI ou Google Gemini"** — há Groq e DeepSeek em uso.
4. **Que a pessoa atendida pode pedir e obter eliminação** — não existe caminho nem expurgo.
5. **Que o titular tem canal** — não há DPO, e-mail nem procedimento (art. 41 e art. 18).
6. **Que existe contrato de tratamento com o psicólogo** — o DPA está em minuta e não é assinado.
7. **Que há RIPD** — não existe, apesar de ser caso tipicamente exigível (art. 38).
8. **Que o app está pronto para as lojas** — faltam política em URL, exclusão de conta, Data Safety,
   App Privacy e as chaves do iOS.
9. **Que existe resposta a incidente** — não há plano, prazo definido nem registro.
10. **Que há tratamento de menores conforme o art. 14** — não há campo de responsável legal nem
    consentimento específico.
11. **Que o bloqueio por PIN/biometria é garantido** — há desbloqueio fail-open.
12. **Que a exclusão do áudio é confiável** — a exclusão é `unawaited` e o arquivo nasce em claro.

> **Leitura executiva:** a conformidade **documentada** está perto de zero; a conformidade
> **técnica no aparelho** está razoável; a **arquitetura de dados** (banco no exterior, sem cifra,
> sem ciclo de vida) é o problema estrutural. Nenhuma frase de "estamos em conformidade" é
> sustentável hoje.

---

## 13. Os 10 itens que mais reduzem risco por esforço

| Ordem | Item | Por que rende muito | Esforço | P0/P1 |
|---|---|---|---|---|
| 1 | Publicar Política de Privacidade e Termos em URL pública, corrigidos (`P0.1` + `P0.5`) | Destrava as lojas **e** remove a informação enganosa ao titular | 1 dia + 4 h | **P0.1**, **P0.5** |
| 2 | Remover o DeepSeek da ordem de provedores (`P0.2`) | Elimina a transferência para a China e o fallback automático de país; custo quase zero | 2 h | **P0.2** |
| 3 | Implementar exclusão de conta no app + URL de exclusão (`P1.9`) | Remove a **reprovação automática** nas duas lojas e atende o art. 18, VI | 2 dias | **P1.9** |
| 4 | Cifrar o conteúdo persistido no servidor (`P0.4`) | Tira o dado de saúde legível do banco no exterior — o achado mais grave | 2–3 dias | **P0.4** |
| 5 | Fechar o desbloqueio fail-open (`P0.7`) | Elimina o acesso ao prontuário sem autenticação; a promessa "PIN/biometria" passa a ser verdadeira | 1 dia | **P0.7** |
| 6 | Nunca gravar áudio em claro (`P0.8`) | Elimina a persistência de relato clínico sem cifra após queda/kill | 2 dias | **P0.8** |
| 7 | Nomear encarregado e abrir canal do titular (`P1.1` + `P1.8`) | Cumpre o art. 41 e cria a porta do art. 18; habilita a nota de LGPD do console | 1–2 dias | **P1.1**, **P1.8** |
| 8 | Retirar a cópia local em texto claro e os segredos de log (`P0.11` + `P1.13`) | Remove dado real e credencial expostos fora de controle | 1 dia | **P0.11**, **P1.13** |
| 9 | Fixar `APP_USER_ID`, desligar o fallback SQLite e reprovar no `/health` (`P1.12`) | Elimina perda silenciosa de dado de titular e dados órfãos a cada restart | 4 h | **P1.12** |
| 10 | Corrigir as afirmações não comprovadas (treinamento de modelos, pinning, AES-256 sem escopo) (`P0.6`, `P0.10`, `P2.12`) | Cada frase falsa é um risco jurídico e de loja maior que a própria falha técnica | 1–2 dias | **P0.6**, **P0.10**, **P2.12** |

---

## 14. Regra de manutenção deste checklist

- Revisão **trimestral**, junto com ROPA e RIPD (ver `17_registro_de_decisoes_e_revisoes.md` §4).
- **Toda** linha que mudar de status recebe registro no histórico de revisões do documento 17, com
  data, evidência nova e responsável.
- Linha **Não verificado** não pode ser lida como conforme: ou vira evidência verificada, ou
  permanece aberta com prazo.
- Este checklist **não** substitui o RIPD (art. 38) nem o ROPA (art. 37); ele mede o estado deles.
