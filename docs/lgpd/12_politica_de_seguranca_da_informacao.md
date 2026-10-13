# Política de Segurança da Informação — MentAll PRO

**Versão:** 1.0 (rascunho para revisão) · **Data:** 09/10/2026 · **Próxima revisão:** 09/10/2027
**Aplicação:** cliente Flutter (`1.0.49`), backend FastAPI, infraestrutura de deploy e fornecedores
**Natureza:** documento de trabalho. **Não é parecer jurídico.** Itens marcados ⚖️ dependem de
validação jurídica; a lista ao final consolida as pendências.
**Classificação do documento:** interno — contém descrição de controles e de lacunas de segurança;
não publicar integralmente.

> **Como ler.** A §5 é uma matriz de controles com o **estado verificado** em 09/10/2026, a
> **evidência** em `arquivo:linha`, a **lacuna** e a **ação** (com a prioridade do
> `02_plano_de_acao.md`: P0 = antes do próximo release; P1 = 30 dias; P2 = 90 dias). O MentAll PRO
> **não possui certificação nem garantia de segurança total**: está **em adequação**, e este documento serve para
> tornar visível o que ainda falta — inclusive para o titular, no resumo publicado (documento 05 §7).

---

## 1. Objetivo

Definir as medidas técnicas e administrativas de segurança da informação do MentAll PRO, de forma
compatível com o **art. 46 da LGPD** e demonstrável ao psicólogo controlador (art. 39) e à ANPD
(arts. 41 e 48).

A política responde a cinco perguntas:

1. **Quais ativos** precisam ser protegidos?
2. **Quais controles existem** hoje — e qual é a evidência?
3. **Quais controles não existem** — e quem faz o quê, até quando?
4. **Como** se gerencia acesso, segredo, vulnerabilidade, continuidade e incidente?
5. **Como** se demonstra que a política está viva (revisão, treinamento, indicador)?

---

## 2. Alcance

- **Ambientes:** aparelho do profissional (Android/iOS), backend em Fly.io (`primary_region = "gru"`,
  `fly.toml:2-3`), banco libSQL/Turso em **`aws-us-west-2` (EUA)** (`backend/.env`), repositório de
  código, estações de desenvolvimento e destinos de exportação (PDF/backup).
- **Pessoas:** administradores do MentAll, desenvolvedores, operação/suporte e o profissional usuário.
- **Dados:** dados pessoais sensíveis de saúde (art. 11) — prontuário, relato, áudio, transcrição,
  síntese, anamnese, contrato — e dados pessoais de conta e de telemetria (§4).
- **Fora do alcance:** a segurança do consultório presencial, a guarda física de documentos em papel
  e os aparelhos pessoais não usados no serviço. Esses pontos são orientados no
  `14_guia_lgpd_do_psicologo.md`.

---

## 3. Papéis e responsabilidades

| Papel | Quem | Responsabilidade |
|---|---|---|
| **Encarregado (DPO)** | A nomear — documento 13 | Canal do titular, orientação interna, interface com a ANPD, revisão desta política |
| **Responsável pela segurança** | A designar formalmente (hoje **não há designação documentada**) | Executar §6 a §10, manter evidências, conduzir a resposta a incidentes |
| **Desenvolvimento** | MentAll | Implementar os controles P0/P1/P2, testes de IDOR e de degradação, revisão de dependências |
| **Operação/infra** | MentAll | Deploy, segredos, logs, disponibilidade, expurgo de log e de banco |
| **Profissional (controlador)** | Psicólogo | Guarda do aparelho, uso de PIN/biometria, decisão sobre áudio/exportação, comunicação de suspeita de incidente |
| **Terceiros/subprocessadores** | Turso, Fly, Groq, OpenAI, DeepSeek, Google, Sentry, SMTP, wuzapi, OpenAlex, CFP | Obrigações equivalentes por contrato (documento 04, Anexo II) ⚖️ |

**Regra de segregação:** quem desenvolve não é, sozinho, quem aprova o release de segurança; a lista
de verificação de release (item 3 da §12) precisa de um segundo par de olhos.

---

## 4. Inventário de ativos

| # | Ativo | Onde fica | Conteúdo | Classificação | Proteção hoje |
|---|---|---|---|---|---|
| A1 | **Aparelho do profissional** (Hive) | Android/iOS | Prontuário e dados clínicos de cada **pessoa atendida**: sessões, transcrições, sínteses, anamnese importada | **Sensível (art. 11)** | Cifra **por campo** AES-GCM (`encryption_service.dart:502-523`); parte dos campos em claro (§5.2, C6) |
| A2 | **Hive cifrado por campo** | Aparelho | Mesmos dados de A1, em repouso | Sensível | Chave mestra no Keystore/Keychain (`encryption_service.dart:43-47`) |
| A3 | **Keystore (Android) / Keychain (iOS)** | Aparelho | Chave mestra (versão durável e versão com biometria) | **Crítico** | Cofre de hardware; **sem** vínculo com autenticação e sem recuperação (`:70,252-264`) |
| A4 | **Arquivos de áudio** (`.m4a`) | Aparelho | Relato clínico ditado (até 5 min) | Sensível | **Em claro durante a gravação** (`audio_relato_service.dart:92` vs `:171`); sem varredura de órfãos |
| A5 | **Backup do profissional** | Aparelho → destino escolhido | Prontuário (incompleto), podendo incluir áudio em base64 | Sensível | Envelope AES-GCM + HMAC-SHA256 (`encryption_service.dart:530-592`); só abre no mesmo aparelho (`backup_service.dart:191-194`) |
| A6 | **PDF de prontuário** | Fora do controle do MentAll | Prontuário completo | Sensível | **Em claro, sem senha, sem aviso no arquivo e sem evento de auditoria** (`pdf_export_service.dart:1544-1552`) |
| A7 | **Backend Fly (`gru`)** | São Paulo (Brasil) | Trânsito de toda a API | Crítico (processa sensível) | HSTS (`main.py:677`); rate limit em memória (`main.py:202-228`) |
| A8 | **Banco Turso/libSQL** | **AWS us-west-2 (EUA)** | `contratos.dados`, `anamneses.respostas`, `lembretes.telefone/mensagem`, tokens, conta, telemetria | **Sensível, em claro** | **Nenhuma cifra em repouso** (`contrato_service.py:14-15`; `db.py:180-213`) |
| A9 | **Conta e autenticação** | Turso (EUA) | E-mail, senha em hash, plano, tokens de verificação/reset | Pessoal | bcrypt; JWT de 8 h **sem `jti` nem revogação** (`main.py:234-235,236-240`) |
| A10 | **Chaves e segredos** (API de IA, SMTP, wuzapi, `APP_PASSWORD_HASH`, `TURSO_AUTH_TOKEN`) | Variáveis de ambiente/secrets do deploy | Credenciais de terceiros e do serviço | **Crítico** | Fora do repositório (`.env` no `.gitignore:2-3`); **sem cofre de segredos dedicado** |
| A11 | **Gateway WhatsApp (wuzapi)** | `[A CONFIRMAR]` | Telefone, nome, mensagem; token de sessão por profissional | Sensível | Token do profissional gravado no banco estrangeiro (`db.py:261-267`); **segredo do webhook na URL** e em log |
| A12 | **Logs** (app, backend, serviço, provedor) | Aparelho, máquina do backend, Fly | Eventos técnicos, erros, acesso | Pessoal | Log do app cifrado/redigido (`logger.dart:115-124`); **backend sem rotação e com segredo/PII** (§5.2, S4) |
| A13 | **Trilha de auditoria** | Aparelho (Hive) | Eventos LGPD com descrição cifrada | Pessoal/sensível | Cifra da descrição; **truncada em 1000 eventos** (`auditoria_service.dart:10,94-102`) |
| A14 | **Repositório e histórico Git** | GitHub | Código, changelog, documentação | Interno | `.env` nunca commitado (`.gitignore:2-3`); varredura do histórico não achou chave ⚖️ (reconfirmar) |
| A15 | **Cópia local de desenvolvimento** | `backend/data/` | `mentall.db` + `-wal` + `-shm` com **dados reais em claro** (09/10/2026) | **Sensível** | Nenhuma — item **P0.11** |

---

## 5. Matriz de controles

### 5.1 Controles que **existem** (não desfazer)

| Controle | Estado | Evidência (`arquivo:linha`) | Lacuna | Ação / prioridade |
|---|---|---|---|---|
| Cifra **por campo** AES-256-GCM no aparelho | EXISTE | `encryption_service.dart:502-523` (formato `3:nonce:cifrado`) | Campos de data de nascimento, tipo/modo de atendimento, valores/status/forma de pagamento, data da sessão e flags ficam **em claro** | Cifrar os campos restantes — **P2.12** |
| Chave mestra em Keystore/Keychain, com PBKDF2 | EXISTE | `encryption_service.dart:13-18,43-47,89-90` | Chave **não** vinculada à autenticação; sem rekey/recuperação | Vincular à autenticação e documentar recuperação — **P2.13** |
| Envelope de backup AES-GCM + HMAC-SHA256 | EXISTE | `encryption_service.dart:530-592` | Backup **incompleto**; import sobrescreve sem confirmação explícita; só abre no mesmo aparelho | Backup completo + confirmação + teste — **P1.16, P2.15, P3.3** |
| `allowBackup="false"` e `usesCleartextTraffic="false"` | EXISTE | `AndroidManifest.xml:13-14` | — | Manter e verificar a cada release |
| Permissões proporcionais à função | EXISTE | `AndroidManifest.xml:2-8` (microfone, internet, biometria, notificação, alarme) | — | Manter |
| Sentry **desligado por padrão** e **sem PII** | EXISTE | `main.dart:73-105` (DSN vazio = inativo; `sendDefaultPii=false`, sem corpo e sem breadcrumbs) | — | Manter; se ativar, registrar a decisão |
| Isolamento por `owner_id` no backend | EXISTE | Endpoints auditados; testes dedicados `tests/test_status_idor.py`, `tests/test_recuperacao_idor.py`, `tests/test_lembrete_idor.py` | Conta **legada compartilhada** (`APP_USERNAME`/`APP_PASSWORD_HASH`) dá o mesmo `owner_id` a todos (`main.py:236-240,710-719`) | Desativar o caminho legado ou segregar — **P1.12** |
| Rate limit por rota/conta | EXISTE | `main.py:202-228` (chave `{rota}|{conta}` ou `{rota}|{ip}`) | **Em memória, por processo** — não sobrevive a restart nem a múltiplas instâncias | Migrar para armazenamento compartilhado — **P2** |
| HSTS no backend | EXISTE | `main.py:677` (`max-age=31536000; includeSubDomains`) | CORS ainda aceita `localhost` em produção | Restringir origens — **P2.11** |
| Cifra/redação do log técnico do app | EXISTE | `logger.dart:115-124` | Trilha de auditoria sem eventos de acesso/exportação/exclusão | Ampliar eventos — **P2.2** |
| Trilha de auditoria de eventos LGPD | EXISTE | `auditoria_service.dart:70-126` | Truncada em 1000; descrição decifrada em memória ao listar (`:110,123`) | Exportar/arquivar antes de podar — **P2.1** |
| Gate de revisão humana antes de salvar conteúdo de IA | EXISTE | `models/sessao.dart:115-121` (`revisadoPeloProfissional`); fluxo de revisão no app | — | Manter (é o que sustenta o art. 20) |
| Telemetria por **allowlist**, sem PII clínica | EXISTE | `telemetria.py:1-26` (somente números e tipo de evento) | **Sem opt-out** e sem aviso destacado | Toggle + aviso no primeiro uso — **P1.14** |
| CRP verificado em fonte nacional | EXISTE | `crp_service.py:10,30-34` (`cn-api.cfp.org.br`) | — | Manter |
| Segredos fora do repositório | EXISTE | `.gitignore:2-3` (`.env`, `backend/.env`, `backend/data/`) | Sem cofre de segredos; sem rotação periódica | Cofre + calendário de rotação — **P1.13** |
| **Tentativa de** certificate pinning | **PARCIAL — inefetivo** | `main.dart:45-68` usa `badCertificateCallback`, que **só roda quando a validação padrão já falhou** | O `SECURITY_CHANGELOG.md:21` marca SEC-05 como "✅ Concluído" — **afirmação incorreta** | Implementar pinning real **ou** corrigir texto e changelog — **P0.10** |

### 5.2 Controles que **não existem** (ou existem em estado que não protege)

| # | Controle ausente | Estado | Evidência | Lacuna / consequência | Ação / prioridade |
|---|---|---|---|---|---|
| S1 | **Cifra em repouso no servidor** | **NÃO EXISTE** | `contrato_service.py:14-15` (`json.dumps` gravado direto); `db.py:180-213` | Contrato, anamnese, telefone e mensagem legíveis no banco **nos EUA** | Cifrar ou parar de persistir — **P0.4** |
| S2 | **Chave vinculada à autenticação do usuário** | **NÃO EXISTE** | `encryption_service.dart:70,252-264` | Perda do Keystore = perda irreversível do prontuário | Definir rekey/recuperação — **P2.13** |
| S3 | **Limpeza da chave ao bloquear** | **NÃO EXISTE** | `encryption_service.dart:656-663` (`limpar()` existe, **0 chamadores** verificados); `app_lock_gate.dart:95-113` (bloqueio é só overlay) | Dado decifrado continua acessível em memória durante o "bloqueio" | Chamar `limpar()` no bloqueio — **P0.9** |
| S4 | **`FLAG_SECURE` / bloqueio de captura de tela** | **NÃO EXISTE** | **0 ocorrências** de `FLAG_SECURE` em `lib/` e `android/`; sem desativação de pré-visualização de tarefas | Captura de tela e *app switcher* expõem o prontuário | Implementar — **P0.9** |
| S5 | **Detecção de root/jailbreak** | **NÃO EXISTE** | **0 ocorrências** de *root detection*/*jailbreak*/*frida* em `lib/` e `android/` | Aparelho comprometido não é sinalizado | Avaliar (baixa prioridade) — **P3** |
| S6 | **Expurgo e rotação de log** | **NÃO EXISTE** | **0 `RotatingFileHandler`** em `backend/`; `backend/backend.launchd.log` = **15,3 MB**; `backend/backend.launchd.err.log` = **8,9 MB** | Log cresce sem limite e **retém PII e segredo** | Rotação + expurgo + limpeza do log atual — **P1.13** |
| S7 | **Cofre de segredos** | **NÃO EXISTE** | Segredos em `.env`/secrets do deploy | Sem rotação, sem trilha de acesso ao segredo, sem separação por ambiente | Cofre + rotação — **P1.13** |
| S8 | **MFA / segundo fator** | **NÃO EXISTE** | Nenhum fluxo de segundo fator no código próprio (as únicas ocorrências de TOTP estão em `.venv`, biblioteca de terceiros); autenticação é e-mail+senha com JWT de 8 h (`main.py:234-235`) | Conta do profissional protegida só por senha | Avaliar MFA — **P2** ⚖️ |
| S9 | **Backup do banco de dados** | **NÃO EXISTE** | Nenhuma rotina de *dump*/backup no backend (0 ocorrências) | Sem recuperação após perda/corrupção; risco ao art. 46 (disponibilidade) | Definir e testar — **P2.15** |
| S10 | **Recuperação de chave** | **NÃO EXISTE** | `backup_service.dart:191-194` (backup só abre no mesmo aparelho); `encryption_service.dart:399-406` (PIN inexistente em instalação nova) | Perda do aparelho = perda do prontuário | Desenhar com o jurídico (afeta guarda legal) — **P2.13** ⚖️ |
| S11 | **PIN funcional em instalação nova / reautenticação para exportar** | **PARCIAL** | `encryption_service.dart:399-406`; `backup_restore_page.dart:24-35` | Promessa de "bloqueio por PIN" (`politica_privacidade_page.dart:60`) não se sustenta | Corrigir — **P2.13** |
| S12 | **Desbloqueio sem *fail-open*** | **FALHA ABERTA** | `auth_service.dart:203-215,237-250`: *lockout*, erro de hardware ou ausência de credencial **carregam a chave sem prompt** (fail-safe), com apenas um aviso | Terceiro com o aparelho desbloqueado abre o prontuário | **P0.7** — o item mais urgente de segurança do aparelho |
| S13 | **Áudio nunca em claro** | **FALHA** | `audio_relato_service.dart:92` (grava) vs `:171` (cifra após parar); sem varredura de órfãos | Relato clínico persistido em claro após queda/bateria/kill | **P0.8** |
| S14 | **PDF protegido e rastreado** | **NÃO EXISTE** | `pdf_export_service.dart:1544-1552` (`Printing.sharePdf`, sem senha, sem aviso, sem evento) | Saída não rastreável de dado sensível | **P1.16** |
| S15 | **Trilha de auditoria de acesso/exportação/exclusão** | **NÃO EXISTE** | `auditoria_service.dart:31,70-126`; `AGENTS.md` (falta evento de áudio) | Não se demonstra quem acessou o quê | **P2.2** |
| S16 | **`/health` que reflete a realidade** | **NÃO EXISTE** | `main.py:688-700` responde `status: "ok"` mesmo com banco em **fallback SQLite** | Monitoração dá falso positivo | **P2.4** |
| S17 | **Log de erro de IA sem conteúdo clínico** | **FALHA** | `ia_clinica.py:668` (`log.error(... resp.text[:500])`) e `:671` (mesmo trecho devolvido na resposta) | Eco de material clínico pode ir ao log | **P2.8** |
| S18 | **Mascaramento de PII em log de contrato** | **FALHA** | `contrato_service.py:66` (`nome=%s`, 20 caracteres) | Nome do titular no log | **P1.13** |
| S19 | **Segredo fora de URL** | **FALHA** | `wuzapi_admin.py:47-49` monta `/wuzapi/webhook?token=...`; **mais de 130 mil ocorrências** do segredo em `backend/backend.launchd.log` | Segredo de webhook vazado em log; repetição massiva | Mover para *header*, **rotacionar**, expurgar log — **P1.13** |
| S20 | **Segregação de conta legada** | **FALHA** | `main.py:236-240,710-719` | Vários usuários com o mesmo `owner_id` | **P1.12** |
| S21 | **CORS restrito** | **PARCIAL** | `main.py:647-664` inclui `http://localhost:5000/8000/3000` com `allow_credentials=True` | Origem de desenvolvimento aceita em produção | **P2.11** |
| S22 | **Código morto capaz de reverter proteção** | **RISCO** | `removerCriptografiaExistente` em **11 serviços, 0 chamadores** (`paciente_service.dart:168`; `sessao_service.dart:252`; `configuracoes_service.dart:178`, entre outros); `excluirPaciente` sem chamador (`paciente_service.dart:113`) | Uma chamada acidental desprotege o prontuário inteiro | Remover ou cercar com teste — **P2.14** |
| S23 | **iOS**: `NSFaceIDUsageDescription`, `ITSAppUsesNonExemptEncryption`, nome de exibição | **NÃO EXISTE / INCORRETO** | `ios/Runner/Info.plist:10` (`CFBundleDisplayName = "Prontuario Tcc"`); chaves ausentes | Reprovação/alegação incorreta na App Store | **P2.16** |
| S24 | **Isolamento de dados de demonstração** | **FALHA** | `demo_data_service.dart:35-78`; `main.dart:192` (seed "Linda M. Tester") | Dados fictícios indistinguíveis de reais | **P2.17** |
| S25 | **`APP_USER_ID` fixo em produção** | **FALHA** | `main.py:241` (UUID novo a cada boot se a variável faltar) | Dados órfãos a cada restart (art. 46 e art. 18, II) | **P1.12** |
| S26 | **Fallback de banco desligado em produção** | **FALHA** | `db.py:15-17` (`ALLOW_SQLITE_FALLBACK` default `true`) | Escrita confirmada em base volátil e perdida no restart | **P1.12 / P2.4** |
| S27 | **Aviso de incidente e plano de resposta** | **NÃO EXISTE** | `01_diagnostico_lgpd.md` §4.12 | Prazo regulatório de 3 dias úteis tende a ser perdido | Documento 11 — **P1.7** |
| S28 | **Designação formal de responsável pela segurança** | **NÃO EXISTE** | Nenhum registro | Sem dono, nenhum controle se sustenta | Nomear — **P1.1 / este documento** |

---

## 6. Gestão de acessos e segredos

### 6.1 Acessos

| Regra | Estado | Ação |
|---|---|---|
| Acesso ao dado clínico é do profissional, no próprio aparelho | Funciona por desenho (dados clínicos não vivem no servidor) | Manter e **escrever** isso ao titular |
| Isolamento por `owner_id` no backend | Existe, com testes de IDOR | Preservar os testes na esteira de CI |
| Conta legada compartilhada | Existe e mistura usuários | **Desativar** em produção — P1.12 |
| Menor privilégio no painel administrativo | Painel protegido por senha própria e restrito a `role == "admin"` (`main.py:2079,2084,2094,2117`); mostra e-mail, nome e plano do profissional sem máscara (`admin_ui.py:104-120`) | Definir **quem** acessa, com que finalidade, e criar registro de acesso; mascarar PII na tela |
| Revisão periódica de acessos | Não existe | Revisar semestralmente e registrar |
| Desligamento de pessoa com acesso | Não documentado | Revogar acessos e segredos em até 24 h, com checklist |

### 6.2 Segredos

1. **Inventário de segredos** (a manter atualizado): `TURSO_AUTH_TOKEN`, `GROQ_API_KEY`,
   `OPENAI_API_KEY`, `DEEPSEEK_API_KEY`, `GOOGLE_API_KEY`, `SMTP_*`, `APP_PASSWORD_HASH`,
   `WUZAPI_TOKEN`, `WUZAPI_ADMIN_TOKEN`, `WUZAPI_WEBHOOK_TOKEN`, `JWT_SECRET`, `OPENALEX_API_KEY`.
2. **Nunca em URL.** O segredo do webhook do WhatsApp está hoje na *query string*
   (`wuzapi_admin.py:47-49`). Corrigir para *header* e **rotacionar o segredo**, porque ele já está
   em log e em qualquer captura de URL — **P1.13**.
3. **Rotação.** Definir calendário (mínimo anual, e **imediato** em caso de suspeita): API de IA,
   SMTP, wuzapi, token do banco. Rotação do webhook é **urgente**.
4. **Expurgo do log com segredo/PII.** Truncar `backend/backend.launchd.log` e
   `backend/backend.launchd.err.log` **depois** de rotacionar o segredo; mascarar o nome em
   `contrato_service.py:66`; remover o eco de conteúdo clínico em `ia_clinica.py:668,671` — **P1.13**
   e **P2.8**.
5. **Cofre de segredos** com controle de acesso e trilha (hoje não existe) — **P1.13**.
6. **Segredo de terceiro de titular**: o `wuzapi_token` de cada profissional é gravado em claro no
   banco estrangeiro (`db.py:261-267`) — tratar como segredo de sessão e definir prazo de expurgo.

---

## 7. Gestão de vulnerabilidades e dependências

| Item | Estado | Ação |
|---|---|---|
| Atualização de dependências (Flutter/Dart e Python) | Não há ciclo documentado nesta política; o `02_plano_de_acao.md` (P3.4) registra que existe acompanhamento no projeto | Formalizar ciclo **mensal**, com registro de versão e decisão |
| Varredura de CVE com impacto em privacidade | Não documentada | Definir criticidade e prazo de correção (crítico: 7 dias; alto: 30; médio: 90) |
| Testes de segurança no código (IDOR, degradação, XSS de página pública) | **Existem** — `backend/tests/` inclui `test_*_idor.py`, `test_anamnese_xss.py`, `test_csp.py`, `test_fallback_db.py` | Manter na esteira; ampliar para áudio e exportação |
| Teste de invasão / revisão independente | Não realizado | Programar após os itens P0 |
| Revisão de segurança de release | Não formalizada | Criar lista de verificação (§12) |
| Varredura do histórico do repositório por segredos | Feita em 09/10/2026, sem achado ⚖️ | **Reconfirmar** e repetir a cada trimestre |

---

## 8. Segurança física e do dispositivo

1. **Aparelho do profissional:** é a fronteira principal do prontuário. Recomendações que passam a
   integrar o material do psicólogo (documento 14): usar bloqueio de tela **forte**, manter o sistema
   atualizado, não instalar o app em aparelho compartilhado, não usar *root*/jailbreak, não manter o
   app aberto em local público.
2. **Ausência de `FLAG_SECURE`** significa que qualquer app com permissão de captura ou o *app
   switcher* pode expor a tela — corrigir (**P0.9**).
3. **Bloqueio real:** ao bloquear, a chave deve sair da memória (**P0.9**); hoje o bloqueio é apenas
   visual (`app_lock_gate.dart:95-113`).
4. **Estações de desenvolvimento:** não manter cópia de banco com dados reais (`backend/data/` —
   **P0.11**); criptografar disco; não usar dados de produção em teste; o seed de demonstração
   ("Linda M. Tester", `demo_data_service.dart:35-78`) não pode se misturar a dado real (**P2.17**).
5. **Infraestrutura:** acesso ao painel do provedor restrito e com segundo fator quando disponível;
   chaves de deploy não compartilhadas por canais informais.
6. **Descarte de equipamento:** apagar dados com *wipe* do sistema operacional **e** revogar acessos
   e segredos antes de descartar.

---

## 9. Continuidade e integridade

| Risco | Estado | Impacto | Ação |
|---|---|---|---|
| **Fallback SQLite silencioso** | `ALLOW_SQLITE_FALLBACK` default `true` (`db.py:15-17`); `/health` sempre `ok` (`main.py:688-700`) | Gravação confirmada e **perdida no restart**; prontuário/documento sob guarda legal desaparece | **P1.12 / P2.4** |
| **`APP_USER_ID` efêmero** | `main.py:241` gera UUID novo a cada boot sem a variável | Dados órfãos a cada restart; quebra o acesso (art. 18, II) | **P1.12** |
| **Backup incompleto** | Não inclui compromissos, anamnese, escalas, avaliação inicial nem auditoria (`backup_service.dart:33-154`); import sobrescreve sem confirmação (`:166-180`) | Restauração parcial silenciosa — risco clínico | **P2.15, P1.16** |
| **Backup só abre no mesmo aparelho** | `backup_service.dart:191-194` | Perda do aparelho = perda do backup | **P2.13** ⚖️ (afeta a guarda legal) |
| **Sem backup do banco** | Nenhuma rotina (0 ocorrências) | Sem recuperação após corrupção/perda da Turso | **P2.15** |
| **Áudio em claro durante a gravação** | `audio_relato_service.dart:92` vs `:171` | Perda/sobra de dado sensível | **P0.8** |
| **Trilha truncada em 1000 eventos** | `auditoria_service.dart:10,94-102` | Perda de evidência de accountability | **P2.1** |

**Objetivo de continuidade:** nenhuma operação de escrita pode ser confirmada como sucesso sem
persistência durável; nenhuma perda de aparelho pode significar perda definitiva do prontuário sob
guarda legal — este segundo ponto depende de decisão jurídica sobre **como** recuperar sem quebrar o
sigilo (**P2.13** ⚖️).

---

## 10. Resposta a incidentes

O procedimento completo, os prazos e o formulário de registro estão no
**`11_plano_de_resposta_a_incidentes.md`**. No que toca à segurança da informação, esta política fixa
apenas:

- **Quem aciona:** qualquer pessoa que detecte o incidente comunica imediatamente o responsável pela
  segurança (§3, a designar) e o encarregado (documento 13).
- **O que é incidente relevante:** qualquer acesso não autorizado, perda, alteração ou exposição de
  dado pessoal — **presume-se relevante** quando envolver dado de saúde.
- **Prazos regulatórios:** **3 dias úteis** para comunicar à ANPD e ao titular, contados do
  conhecimento (Res. CD/ANPD nº 15/2024), **em dobro** para agente de pequeno porte ⚖️; conteúdo
  mínimo de **12 itens**; complementação em **20 dias úteis**; **registro guardado por 5 anos,
  inclusive dos incidentes não comunicados**.
- **Preservação de evidência:** antes de corrigir, preservar log (cópia íntegra, com *hash*) e
  registrar o ocorrido — mas **sem copiar dado clínico** para fora do ambiente controlado.
- **Envolvimento do controlador:** o MentAll comunica o psicólogo controlador em até
  `[24] horas` da ciência (cláusula 8 da minuta do documento 04).
- **Ponto cego atual:** não há plano, não há encarregado nomeado e o log do backend contém segredo e
  PII — o que **agrava** qualquer incidente. Corrigir os itens P1.7 e P1.13 é pré-requisito para que
  a resposta funcione.

---

## 11. Treinamento e conscientização

| Público | Conteúdo mínimo | Frequência | Estado |
|---|---|---|---|
| Desenvolvimento e operação | Sigilo, dado sensível, higiene de segredo, uso de log sem PII, resposta a incidente, revisão de dependência | Admissão + anual | **NÃO EXISTE** |
| Suporte/atendimento | Não pedir dado clínico por canal informal; encaminhar ao encarregado; nunca pedir senha | Anual | **NÃO EXISTE** |
| Profissional usuário | Material do documento 14: base legal, guarda, uso de IA, exportação, WhatsApp, incidente | Na adesão + quando mudar | **PARCIAL** (material em elaboração) |

---

## 12. Revisão, indicadores e lista de verificação de release

**Revisão:** anual (09/10/2027) ou a cada mudança relevante (novo provedor, novo campo, novo país,
incidente, alteração legal).

**Indicadores (propostos, a medir a partir da implementação):**

| Indicador | Meta |
|---|---|
| Itens P0 abertos | 0 |
| Controles da §5.2 com ação concluída | ≥ 80% em 90 dias |
| Tempo entre detecção e comunicação de incidente | ≤ 24 h para o controlador; ≤ 3 dias úteis para ANPD/titular |
| Logs com segredo/PII | 0 ocorrências |
| Dependências críticas desatualizadas | 0 acima de 7 dias |
| Testes de restauração de backup realizados | 1 por ano, com termo |
| Solicitações de titular respondidas no prazo | 100% |

**Lista de verificação de release (obrigatória antes de publicar):**

- [ ] Nenhuma afirmação de segurança no texto/in-app sem comportamento correspondente no código
- [ ] `SECURITY_CHANGELOG.md` conferido **contra** o código (a marcação "SEC-05 concluído" está
      incorreta hoje — `SECURITY_CHANGELOG.md:21` vs `main.dart:45-68`)
- [ ] Log sem segredo/PII no diff e no ambiente de destino
- [ ] Sem cópia de banco com dado real no repositório de trabalho
- [ ] Eventos de auditoria novos emitidos (se houver novo fluxo de dado)
- [ ] Data Safety (Play) e App Privacy (Apple) coerentes com o comportamento real
- [ ] Aprovação de um segundo responsável (segregação de função)

**Decisões que precisam ser registradas** no `17_registro_de_decisoes_e_revisoes.md`: (a) **quem** é o
responsável pela segurança e como se relaciona com o encarregado; (b) **como recuperar a chave** sem
quebrar o sigilo do prontuário; (c) adotar ou não **MFA**; (d) implementar **pinning efetivo** ou
corrigir a afirmação do `SECURITY_CHANGELOG.md:21`; (e) adotar **cofre de segredos** e a rotação do
segredo do webhook.

---

## Pendências de validação jurídica

| # | Pendência | Onde impacta | Situação |
|---|---|---|---|
| 1 | ⚖️ **Designação formal do responsável pela segurança** e sua relação com o encarregado (art. 41). | §3, §10 | A DEFINIR (documento 13) |
| 2 | ⚖️ **Recuperação de chave** compatível com a guarda legal do prontuário: é lícito manter cópia de recuperação? Onde e sob que custódia? | §9, S10 | NÃO CONFIRMADO |
| 3 | ⚖️ **Contratos com subprocessadores** (Turso/AWS, Fly, Groq, OpenAI, DeepSeek, Google, SMTP, wuzapi) com cláusulas de segurança, notificação de incidente e exclusão de réplica/backup. | §3, §10 | NÃO CONFIRMADO |
| 4 | ⚖️ **Incidente**: confirmar o prazo em dobro para agente de pequeno porte e o conteúdo mínimo de 12 itens (Res. CD/ANPD nº 15/2024). | §10 | A CONFIRMAR no documento 11 |
| 5 | ⚖️ **MFA**: avaliar se é exigível/razoável para dado sensível de saúde. | S8 | NÃO CONFIRMADO |
| 6 | ⚖️ **Retenção de log de acesso e de telemetria** para fins de segurança × minimização. | §6, §9 | NÃO CONFIRMADO (documento 10) |
| 7 | ⚖️ **Recertificação da varredura de segredos** no histórico Git (resultado de 09/10/2026 não é definitivo). | §7 | A RECONFIRMAR |
| 8 | ⚖️ **Transferência internacional** (Turso EUA; Groq/OpenAI EUA; DeepSeek China): o mecanismo do art. 33 é pré-requisito para declarar os controles de segurança em contrato. | §4 (A8), §9 | NÃO CONFIRMADO (documento 09) |

> Este documento **não é parecer jurídico**. As medidas aqui descritas são técnicas; a suficiência
> delas como "medidas de segurança apropriadas" (art. 46) depende de validação jurídica e de
> evidência de execução — não da existência do texto.
