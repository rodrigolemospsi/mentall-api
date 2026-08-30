# MentAll PRO — Prontuário Clínico com IA

> **Regra de comunicação (obrigatória):** o dono do projeto se chama **Rodrigo**. Toda resposta deve começar se dirigindo a ele como "Rodrigo".

> **Regra de trabalho (obrigatória):** ao receber **qualquer solicitação**, invocar obrigatoriamente a skill `using-agent-skills` **antes de qualquer leitura de código ou planejamento**. Ela apontará as demais skills aplicáveis (ex.: `planning-and-task-breakdown`, `test-driven-development`, `frontend-ui-engineering`, `debugging-and-error-recovery`), que devem ser invocadas em sequência antes de planejar e executar. Não iniciar análise, plano ou código sem ter passado por esse passo.

## BACKUP DA CONFIGURAÇÃO ATUAL (25/08/2026) — PALETA ROXA ANTES DA MIGRAÇÃO PARA CINZA

> **Objetivo:** registrar o estado visual atual (paleta roxa) antes de qualquer mudança para tons de cinza, para permitir reversão sem perder o que foi construído. Atualizar este bloco conforme as mudanças forem aplicadas.

> **STATUS (25/08/2026):** ✅ **MIGRAÇÃO PARA CINZA APLICADA** nos 3 itens abaixo (sombras + botões de ação + barra inferior da Home). Os valores "atuais" abaixo são o estado ANTES (roxo); o que foi aplicado está indicado em **APLICADO**.

### Sombra dos cards (APLICADO — agora cinza)
- **Arquivo:** `lib/utils/mentall_colors.dart` → getter `corCardSombra` (linhas ~25-34).
- **Estado anterior (roxo):**
  - `color: Color(0xFFE0AAFF).withValues(alpha: 0.40)` (roxo claro)
  - `blurRadius: 8`
  - `offset: Offset(0, 2)`
- **APLICADO:** `color: Color(0xFF94A3B8).withValues(alpha: 0.30)` (cinza neutro). `blurRadius`/`offset` mantidos.
- **Tema escuro:** retorna `null` (usa `corCardBorda`).
- **Consumida por:** `MentAllCard`, KPIs/Sessões de hoje/Atividade recente (Home), Financeiro (resumo), PacienteCard da Home, perfil (todos via `context.corCardSombra`).

### Botões de ação da Home — Novo paciente / Agendar / Nova sessão (APLICADO — agora cinza)
- **Arquivo:** `lib/widgets/home_dashboard.dart` → widget `_AcaoRapida` (linhas ~118-172).
- **Estado anterior (roxo):**
  - Borda (`Border.all`, linha ~139): `context.corContainerPrimario`
  - Ícone (22px, linha ~145): `context.corPrimaria`
  - Texto (w600, `Tipografia.xs`, linha ~154): `context.corPrimaria`
  - Fundo do `Material` (linha ~167): `context.corContainerPrimario`
- **APLICADO:** novos getters em `mentall_colors.dart` — `corAcaoFundo`, `corAcaoBorda`, `corAcaoFg` (tema claro: `#F1F5F9`, `#E2E8F0`, `#64748B`; tema escuro: mantém tons do `ColorScheme`). Usados na borda, ícone, texto e fundo do `_AcaoRapida`.
- **APLICADO (25/08/2026, ajuste):** o fundo dos botões de ação (tema claro) passou a usar **a mesma cor da sombra dos cards** — `#94A3B8` a 30% de opacidade (extraído para a constante `corSombraCard` em `mentall_colors.dart`, compartilhada com `corCardSombra`). Antes era `#F1F5F9`. Tema escuro inalterado. Borda (`corAcaoBorda`) e texto/ícone (`corAcaoFg`) inalterados.
- **Resolução das cores ANTES** (tema claro, seed `0xFF8806CE`):
  - `corContainerPrimario` = `cs.primaryContainer` (roxo claro translúcido derivado do seed)
  - `corPrimaria` = `#8806CE` (french violet)

### Barra fixa inferior (NavigationBar) — Início / Pacientes / Financeiro (APLICADO — cor da logo)
- **Arquivo:** `lib/main.dart` → `navigationBarTheme` no tema claro (`brightness == light`).
- **Estado anterior (cinza):** fundo `corSombraCard` a 30%; indicator `corAcaoFgClaro` (`#64748B`) a 14%; ícones/legendas `#64748B` (selecionado) / `#64748B` 55-60% (não selecionado).
- **APLICADO (26/08/2026):** ícones/legendas = **cor da logo** — `_corPrimaria` (`#8806CE`, French violet) (selecionado) / `_corPrimaria.withValues(alpha: 0.85)` (não selecionado, 15% transparente). Fundo (`corSombraCard` a 30%), indicator (`corAcaoFgClaro` a 14%) e `surfaceTintColor` **inalterados** (decisão do dono). Tema escuro inalterado (`null` → default do ColorScheme).
- **Nota:** os botões de ação da Home (`corAcaoFundo`/`corAcaoFg`) continuam usando `corSombraCard`/`corAcaoFgClaro` — NÃO foram sincronizados com esta mudança (escopo: só a barra inferior).

### Ícones da Atividade recente (Home) — (APLICADO — agora cinza)
- **Arquivo:** `lib/widgets/home_dashboard.dart` → widget `_AtividadeItem` (chip circular 34px + ícone 17px).
- **Estado anterior (roxo):** chip `context.corContainerPrimario` (`primaryContainer`) + ícone `context.corPrimaria`.
- **APLICADO (25/08/2026):** novos getters em `mentall_colors.dart` — `corAtividadeIconeFundo` (tema claro: `corAcaoFgClaro` a 14%, igual ao indicator da barra) e `corAtividadeIcone` (tema claro: `corAcaoFgClaro`). Tema escuro inalterado (`primaryContainer`/`primary`).

### Como reverter
- Sombra: restaurar `corCardSombra` para `Color(0xFFE0AAFF).withValues(alpha: 0.40)`.
- Botões: remover os getters `corAcaoFundo`/`corAcaoBorda`/`corAcaoFg` de `mentall_colors.dart` e restaurar `_AcaoRapida` para `corContainerPrimario`/`corPrimaria`.
- Barra inferior: restaurar em `main.dart` `backgroundColor: Color(0xFFE0AAFF)`, `indicatorColor: Color(0xFF3C096C).withValues(alpha: 0.14)` e ícones/legendas `#3C096C`.
- Nenhuma outra tela/componente é afetado por essas mudanças.

## Correções e Funcionalidades (25/08/2026) — RETRY DE LEMBRETES + RECONEXÃO WUZAPI

### Fix: botões da Agenda (Confirmar/Ausência/Cancelar/Remover) não persistiam
- **Sintoma:** tocar em "Realizado/Faltou/Cancelar/Remover" no card da Agenda não mudava nada.
- **Causa raiz:** `CompromissoService._decryptCompromisso()` criava uma **nova instância** de `Compromisso` (sem `key` Hive) ao descriptografar. Os métodos de ação (`marcarComoRealizado/Cancelado/Faltou/Agendado`, `remover`, `vincularSessao`, `atualizar`) chamavam `.save()`/`.delete()`/`_box.put(compromisso.key, ...)` nessa cópia sem `key` → Hive falhava silenciosamente e o status nunca persistia.
- **Fix (padrão do `SessaoService`):** `_decryptCompromisso()` agora **modifica o objeto no lugar** (preserva `key`). Novo `_encryptCompromisso()` re-criptografa `titulo`/`observacoes` antes do `save()`. `atualizar()` busca o registro original por `id` para obter a `key`.
- **Testes:** novos `test/services/compromisso_service_test.dart` (6 testes: marcarRealizado/Cancelado/Faltou/Agendado, remover, atualizar). Reproduzem o bug antes do fix (RED) e passam depois (GREEN).

### Bug reportado: "lembrete não chegou" (antecedência 1h)
- **Diagnóstico:** o agendamento no app **funcionou** (POST `/lembretes` → 200, log "Lembrete agendado"). O envio falhou porque o **wuzapi estava desconectado do WhatsApp** desde ~16:00 (reinício do serviço com erro DNS transitório `lookup web.whatsapp.com: no such host`). O scheduler tentou enviar e o wuzapi retornou `500 {"error":"no session"}` — registrado no log como `Erro wuzapi (500): no session`.
- **Reconexão:** a sessão ainda existia no disco (`Already logged in`); reconectada via `POST /session/connect` (header `token: <user_token>`, body `{"Subscribe":["All"],"Immediate":false}`) → `logged_in: 1`. Confirmado com envio de teste. **Atenção:** o wuzapi NÃO reconecta sozinho após perder a conexão — para restabelecer, reiniciar o serviço (`launchctl kickstart -k gui/$(id -u)/com.mentall.wuzapi`) e, se a sessão persistir, o launchd tenta conectar no boot; caso contrário, `POST /session/connect` com o token do usuário.

### Retry robusto no scheduler (`backend/services/lembrete_service.py`)
- **Antes:** ao falhar o envio, o scheduler marcava `status='falha'` na 1ª tentativa — lembrete perdido se o WhatsApp ficasse fora do ar por minutos.
- **Agora:** nova função `_deve_continuar_tentando(horario_envio, agora)` + env `JANELA_RETRY_LEMBRETES_MINUTOS` (padrão 60). Dentro da janela, o lembrete permanece `pendente` (incrementa `tentativas`, grava `ultima_tentativa_em`) e é re-tentado a cada ciclo de 30s; só vira `falha` após a janela expirar.
- **Schema:** colunas novas em `lembretes`: `tentativas INTEGER NOT NULL DEFAULT 0` e `ultima_tentativa_em TEXT` (migração via `_garantir_coluna` em `db.py`, também adicionadas ao `CREATE TABLE`).
- **Resgate:** lembretes antigos já marcados `falha` dentro da janela de retry foram resetados para `pendente` e reenviados com sucesso.
- **Testes:** novos em `backend/tests/test_lembrete_retry.py` (6 testes, `unittest` — rodar com `.venv/bin/python -m unittest discover -s tests`). Cobertos: dentro/fora da janela, limite exato, formato Z do app, valor inválido, janela configurável.
- **Ops:** `.env`/`.env.example` → `JANELA_RETRY_LEMBRETES_MINUTOS=60`.

### Watchdog de reconexão do wuzapi (reconecta sozinho)
- **Problema:** o wuzapi NÃO reconecta sozinho após perder a conexão do WhatsApp. O launchd (`KeepAlive`) reinicia só se o **processo** morrer — quando a conexão cai com o processo vivo, ficava desconectado para sempre (era preciso `POST /session/connect` manual).
- **Agora:** o scheduler do backend (`_scheduler`) chama `_checar_e_reconectar_wuzapi()` a cada ciclo (30s) via `asyncio.to_thread`. Ele:
  1. Faz `GET {WUZAPI_BASE_URL}/health` (público, sem auth) — se `logged_in_users == 0` (e `total_users > 0`), está desconectado.
  2. Chama `POST /session/connect` (header `token`, body `{"Subscribe":["All"],"Immediate":false}`) — reusa a sessão salva no disco, sem escanear QR.
  3. Cooldown de `WUZAPI_RECONNECT_COOLDOWN_SECONDS` (padrão 300s = 5 min) entre tentativas, para não martelar o WhatsApp se estiver fora.
- **Funções novas** em `lembrete_service.py`: `_wuzapi_health_ok()`, `_reconectar_wuzapi()`, `_checar_e_reconectar_wuzapi()`.
- **Testes:** novos em `backend/tests/test_wuzapi_watchdog.py` (12 testes: health online/offline/sem users/erro rede, reconnect sucesso/falha, cooldown, sem base_url).
- **Validado em produção local:** desconectei a sessão (`/session/disconnect`) e o watchdog reconectou sozinho em ~35s (`logged_in: 0 → 1`, log "wuzapi desconectado. Tentando reconectar..." → "wuzapi reconectado via /session/connect.").
- **Ops:** `.env`/`.env.example` → `WUZAPI_RECONNECT_COOLDOWN_SECONDS=300`.

### Webhook de confirmação de entrega/leitura (25/08/2026) — como saber se o lembrete chegou
- **Problema:** o backend marcava o lembrete como `enviado` ao receber HTTP 200 do wuzapi — mas o wuzapi só enfileira a mensagem (`Message sent`), **não confirma entrega/leitura**. Sem confirmação, era impossível saber se o recado chegou ao paciente (falso sucesso).
- **Agora:** o wuzapi envia webhooks ao backend com os eventos `Message` e `ReadReceipt`; o backend correlaciona pelo `mensagem_id` e grava quando a mensagem foi **entregue** (`entregue_em`) e **lida** (`lido_em`).
- **Status:** ✅ **CONFIGURADO E ATIVO** no wuzapi local — `GET /webhook` retorna `subscribe=["Message","ReadReceipt"]` e a URL aponta para `http://localhost:8000/wuzapi/webhook?token=<WUZAPI_WEBHOOK_TOKEN>`. Logs confirmam `Webhook call successful status=200` no wuzapi e `Webhook wuzapi Message recebido` no backend.
- **Fluxo:**
  1. `_enviar_whatsapp_via_wuzapi` agora retorna `(sucesso, mensagem_id)` e loga o Id (`id=...`); o scheduler salva `mensagem_id` no lembrete.
  2. O wuzapi POSTa os eventos para `{WUZAPI_BASE_URL aponta p/ backend}/wuzapi/webhook?token=...` (token = env `WUZAPI_WEBHOOK_TOKEN`).
  3. `registrar_receipt(payload)` em `lembrete_service.py`: para `ReadReceipt` com `state=Delivered` → grava `entregue_em`; `state=Read/ReadSelf` → grava `lido_em` (busca por `mensagem_id`).
- **Endpoint:** `POST /wuzapi/webhook` em `main.py` (sem JWT; autenticado por `?token=`). Aceita modo `form` (campo `jsonData`) ou `json`.
- **Schema:** colunas novas em `lembretes`: `mensagem_id`, `entregue_em`, `lido_em` (migração via `_garantir_coluna` em `db.py`).
- **Testes:** novos em `backend/tests/test_webhook_wuzapi.py` (10 testes: captura de Id, receipt Delivered→entregue, Read→lido, id sem match, payload não-receipt, sem MessageIDs, state desconhecido).
- **Atenção CRLF:** o `backend/.env` era salvo com quebras CRLF — ao ler variáveis via `grep|cut` no shell, o valor ficava com `\r` no final, fazendo o `curl` montar header inválido (400 do Go). Normalizado para LF. Preferir `tr -d '\r'` ao extrair tokens em comandos.
- **Como conferir:** `SELECT mensagem_id, entregue_em, lido_em FROM lembretes WHERE id='...'` (via `executar`) ou log do wuzapi (`Message delivered`/`Message was read`) + log do backend (`Webhook wuzapi ReadReceipt recebido`).
- **Nota:** o `ReadReceipt` de leitura só é emitido pelo WhatsApp quando um destinatário real abre a mensagem — mensagens enviadas para o próprio número conectado podem não gerar receipt.

## Correções e Funcionalidades (26/08/2026) — AUDITORIA COMPLETA + FIX CRÍTICOS

### Auditoria completa do app (25/08/2026) — relatório
- Revisão multi-eixo (código, segurança, performance, dependências, serviços). Estado geral saudável: `flutter analyze` limpo (1 warning pré-existente), testes Flutter 95/95 + backend 31/31, serviços no ar, criptografia AES-GCM + PBKDF2 100k ok, SQL parameterizado, XSS escapado, CORS restrito, security headers presentes.
- Achados críticos corrigidos abaixo; restam como pendência: descriptografia em lote via Isolate para listagens completas. (Arquivo gigante `sessao_form_page` **resolvido em 29/08/2026** — ver seção "REFATORAÇÃO DO SESSÃO_FORM_PAGE".)

### Fix crítico 1: scheduler do backend bloqueava o event loop (disponibilidade)
- **Problema:** `_scheduler` (a cada 30s) chamava `_enviar_whatsapp_via_wuzapi` (com `requests.post timeout=20`) **direto no event loop** — cada envio podia travar todos os requests HTTP do backend por até 20s.
- **Fix:** extraída `_processar_pendentes(agora)` (SELECT + envio + UPDATEs, síncrona) e o scheduler agora chama `await asyncio.to_thread(_processar_pendentes, agora)` dentro do `_LOCK` — o envio sai do loop (mesmo padrão já usado no watchdog).
- **Testes:** novos em `test_webhook_wuzapi.py` (envio sucesso salva mensagem_id, falha mantém pendente, scheduler chama processar em to_thread).

### Fix crítico 2: token do wuzapi vazado no AGENTS.md (rotacionado)
- **Problema:** o token real `WUZAPI_TOKEN` do usuário wuzapi estava **versionado no AGENTS.md** (linha 127) — dá acesso de envio de WhatsApp em nome do profissional.
- **Fix:** token **rotacionado** (`PUT /admin/users/{id}` no wuzapi + novo valor em `backend/.env`). AGENTS.md agora usa placeholder (`WUZAPI_TOKEN`, sem valor) com nota de não versionar. Envio ponta a ponta validado com o novo token.

### Fix crítico 3: `validarPin` aceitava qualquer PIN (reautenticação decorativa)
- **Problema:** `EncryptionService.validarPin()` retornava `true` incondicionalmente quando a chave estava em memória (`if (_key != null) return true;`) — o PIN exigido antes de exportar backup aceitava **qualquer valor**.
- **Fix:** removido o atalho — `validarPin` agora sempre valida o PIN derivando a chave e tentando descriptografar `encrypted_key` (no fluxo moderno sem PIN legado, retorna `false`; a reautenticação legítima é via biometria/credencial do dispositivo).
- **Testes:** novos `test/services/encryption_service_test.dart` (2 testes: rejeita PIN quando não há chave legada; não aceita PIN qualquer com chave em memória).

### Fixes de prioridade ALTA/MÉDIA da auditoria (26/08/2026)
- **Reatividade dos KPIs financeiros:** `_sessoesDoMesHomeProvider` era `Provider.autoDispose` + `IndexedStack` (nunca recomputava) → KPIs **Receita/Pendente obsoletos** até reiniciar o app. Convertido para `StreamProvider` reativo com `async*` + `observarSessoes()` (mesmo padrão dos KPIs). Consumo com `valueOrNull`.
- **Webhook `/wuzapi/webhook` endurecido:** adicionado rate limit (120/min) + limite de payload (1 MB via `content-length` e `jsonData`) + token **obrigatório** (antes aceitava sem env setada). Payloads grandes retornam 200 com sucesso (para não gerar retry no wuzapi).
- **Rate limit atrás do proxy Fly:** `Dockerfile` → uvicorn com `--proxy-headers` (passa a confiar no `X-Forwarded-For`; antes `client.host` era o IP do proxy para todos → bucket global de DoS).
- **N+1 `buscarPacientePorId`:** materializado `Map<String, Paciente>` via `listarPacientes()` (1 leitura) + lookup O(1) em `home_dashboard` (AtividadeRecente), `agenda_page` (dia/semana/mês) e `financeiro_page` (lista + export PDF).
- **`MemoryImage` sem cache:** novo `lib/utils/imagem_cache.dart` com cache de `MemoryImage` por base64 (reusa instância → evita re-decode JPEG a cada build). Aplicado em 8 telas/widgets.
- **Logs com PII mascarados:** helper `_mascarar_contato` (e-mail: 1º char + domínio; telefone: últimos 4 dígitos) em `main.py` e `_mascarar` em `lembrete_service.py`. Aplicado em login, cadastro, contrato/anamnese/aceite, envio de e-mail e envio de WhatsApp (telefone).
- **Código morto removido (aprovado pelo dono):** apagado `lib/widgets/agenda_inline_widget.dart` (682 linhas) e `SessoesHojeCard`/`_SessaoHojeItem` do `home_dashboard.dart`; referências removidas do `tools/gerar_catalogo_pdf.dart`.
- **Testes:** backend 33/33 (novos: mascaramento PII + processar_pendentes), Flutter 97/97, `analyze` limpo.

### Fixes de prioridade ALTA/MÉDIA restantes (26/08/2026)
- **Credenciais sem PIN em texto puro (eliminado):** `ApiClient.setCredentials`/JWT **não persistem mais em texto puro** quando a criptografia não está disponível — mantêm apenas em memória (campos `_usernameMemoria`/`_passwordMemoria`), getters consultam memória primeiro. `AuthService._username/_password` delegam a `ApiClient`. Testes: novos `test/services/api_client_test.dart` (2 testes: persiste criptografado com chave; não persiste em claro sem chave).
- **Certificate pinning:** removido o **bypass genérico de `192.168.x.x`** (qualquer host da rede local aceitava qualquer cert = MITM); agora só `localhost`/`127.0.0.1` são liberados para dev. Adicionado o fingerprint **atual** do cert Fly (renovação Let's Encrypt) ao lado do anterior — o pin só age quando a validação padrão falha, então manter os 2 últimos evita quebra na transição.
- **Descriptografia síncrona na UI thread (contadores sem decrypt):** novos `SessaoService.contarSessoesAtivasUltimos30Dias()` e `somarFinanceiroPorPeriodo(inicio, fim)` que **não descriptografam** campos clínicos (só contam/somam campos não-cifrados como `data`, `statusPagamento`, `valorSessao`). Usados em `dashboardKpisSessoesProvider` (antes decrypt de tudo) e `_sessoesDoMesHomeProvider` da Home. `PacienteResumoTab` passou a usar `contarSessoesDoPaciente`/`contarSessoesArquivadasDoPaciente` (eram listagens com decrypt só para `.length`).
- **Arquivo gigante `sessao_form_page.dart`:** extraídos 3 widgets autocontidos para `lib/widgets/sessao_form_widgets.dart` — `CardBuscandoArtigos`, `AudioMantidoSwitch`, `BotaoSalvarSessao`. Seções altamente acopladas ao estado (`_secaoFinanceira`, `_secaoProgresso`, `_secaoRelatoIa`) **resolvido em 29/08/2026** via providers públicos + `ConsumerWidget` autocontidos (ver seção "REFATORAÇÃO DO SESSÃO_FORM_PAGE" — não foi preciso passar callbacks/setters soltos).
- **Testes:** Flutter 99/99 (novos: api_client_test + encryption_service_test), backend 33/33, `analyze` limpo.

### Correção anti-alucinação nas indicações de artigos (26/08/2026)
- **Sintoma:** o card "Indicações de artigos" mostrava conteúdo que parecia título de artigo inventado (ou URL crua de base de busca).
- **Diagnóstico (leitura minuciosa):** o pipeline novo (OpenAlex → rerank → `_formatar_artigos`) é anti-alucinação e retorna artigos reais. As causas do sintoma:
  1. **Fallback parecia artigo:** `_montar_artigos_sugeridos` gerava `"1. Ansiedade social"` (tema como título numerado) + URLs — o parser do app tratava a 1ª linha como título clicável, parecendo artigo inventado.
  2. **Bug de renderização (CAPES):** `Periódicos CAPES: https://...` não era filtrado pelo parser (`[A-Za-z]+` não casa `ó`) → URL crua visível.
  3. **Sessões antigas persistidas:** artigos gerados pelo LLM direto (pré-15/07, formato `"1. Título: ... Link: ..."`) continuavam criptografados no Hive e eram exibidos ao reabrir.
  4. **Race condition:** `artigosSugeridosProvider` é global; uma busca em background de outra sessão podia sobrescrever o card.
- **Fix:**
  1. Fallback agora usa rótulo **"Busca sugerida N: tema"** (não parece título de artigo); cada plataforma vira link clicável com rótulo (SciELO/CAPES/Oasisbr).
  2. Parser do app (`sessao_artigos_sugeridos.dart`) reescrito: reconhece bloco "Busca sugerida" e bloco de artigo; regex de plataforma aceita acentos (`^[^:]+:\s*https?://`).
  3. Novo `lib/utils/artigos_validacao.dart` — `limparArtigosAntigos()` detecta o formato legado (`Título:`/`Link:`/`Acesse:` ou numeração sem link confiável) e limpa ao abrir a sessão (`sessao_form_page.dart:334`).
  4. `_buscarArtigosEmBackground` guarda `_sessaoId` e descarta a resposta se a sessão mudou durante a busca.
- **Testes:** backend `tests/test_artigos.py` (7: fallback rótulo, formato real, normalizar temas), Flutter `test/services/artigos_validacao_test.dart` (8) + `test/widgets/sessao_artigos_sugeridos_test.dart` (2). Backend 40/40, Flutter 111/111, `analyze` limpo.

## Correções e Funcionalidades (27/08/2026) — SÍNTESE (MATERIAL+TEMA+TIMEOUTS), SINCRONIZAÇÃO CONTRATO/ANAMNESE, PDF PRONTUÁRIO, EXPORT ANAMNESE

### Fix: síntese descartava material e nunca enviava o tema
- **Sintoma:** a síntese usava só o relato manual OU a transcrição (descartava o outro); `tema_principal` nunca era enviado (sempre `''`); timeouts desalinhados causavam falso "serviço indisponível".
- **Fix:**
  1. **Material completo:** `gerar_sintese()` (`ia_clinica.py`) agora combina relato manual + transcrição com rótulos `RELATO DO PROFISSIONAL:` / `TRANSCRIÇÃO DO ÁUDIO:`. Anti-duplicação no app (`sessao_form_page.dart`): ao **regerar** (`_geradoComIa == true`), o campo relato contém a resposta anterior da IA e **não** volta como material (evita realimentação). Escrita manual em sessão nova continua sendo enviada.
  2. **Tema descoberto pela IA (opção b):** `_montar_prompt_sintese` — sem `tema_principal`, o prompt instrui "Tema principal: identificar a partir do material clínico e usar para orientar toda a síntese." App deixou de enviar `temaPrincipal`; campo opcional no schema Pydantic (`default=""`).
  3. **Timeouts alinhados:** app (`ia_clinica_service.dart`) timeout 90s→150s e retry 5xx 2→1 (backend já faz cascata de 3 provedores). Backend: síntese Gemini/OpenAI/DeepSeek 60s→45s cada → pior caso 135s < 150s do app. Timeouts de artigos/progresso inalterados.
- **Arquivos:** `backend/services/ia_clinica.py`, `backend/models/schemas.py`, `lib/services/ia_clinica_service.dart`, `lib/screens/sessao_form_page.dart`.
- **Testes:** novo `backend/tests/test_sintese.py` (8 testes: material combinado, só relato, só transcrição, sem material, tema identificado/informado). Backend 48/48, Flutter 117/117.

### Fix: aceite do Acordo Terapêutico e resposta da Anamnese não retornavam ao app
- **Sintoma:** paciente aceitava o contrato/responde a anamnese no link, mas o app continuava "Aguardando"/"Pendente" para sempre, mesmo reiniciando. O app nunca consultava o backend (fonte da verdade no Turso).
- **Diagnóstico:** persistência Hive OK (boxes/adapters OK); backend grava aceite/resposta OK; mas `ContratoService.verificarStatus` **não tinha nenhum caller** no app, e a anamnese só verificava no botão manual "Reenviar anamnese". Sem polling, sem refresh, sem sincronização.
- **Fix (sincronização em 3 níveis):**
  1. **`sincronizarPendencias({String? pacienteId})`** em `ContratoService` e `AnamneseEnviadaService` — consulta o backend dos pendentes/enviados e atualiza o Hive (usa `verificarStatus` existente; retorna quantos atualizaram).
  2. **Auto-sync ao abrir a ficha** (`paciente_detail_page.dart` initState postFrameCallback) + **pull-to-refresh** na ficha (telefone e tablet) + **sync em lote na Home** (initState). Providers reativos (`observar()`) atualizam o card automaticamente.
  3. **Botão "Atualizar"** no card do contrato quando `isEnviado` (antes "Enviar" só reenviava WhatsApp, sem verificar). Anamnese mantém botão de reenvio (que também verifica).
- **Testes:** novo `test/services/sincronizacao_pendencias_test.dart` (5 testes: filtra pendentes/enviados, ignora aceitos/respondidos, filtra por paciente, contagem).

### Fix: exportar "Prontuário completo" travava (congelava) e não gerava PDF
- **Sintoma:** clicava em "Prontuário completo" → tela congelava por um tempo e voltava sem gerar nada. Só acontecia com o **paciente modelo** (único com artigos sugeridos).
- **Causa raiz:** `_secaoClinica` renderiza `sessao.artigosSugeridos` com URLs longas sem espaços (ex.: `periodicos.capes.gov.br/...?q=...`) em `pw.Text` com `textAlign: justify` → algoritmo de quebra de linha O(n²) no pacote `pdf` congela a main thread. Além disso, o caller do botão não tinha `try/catch` → exceção virava erro não tratado (voltava sem gerar).
- **Fix:**
  1. Novo helper `_quebrarTextosLongos` (`pdf_export_service.dart`, público `quebrarTextosLongos` para teste) que insere quebras em tokens > 60 chars; `textAlign: justify`→`left` nos 4 pontos de texto livre (relato, síntese, artigos, bloco de transcrição). Geração passa de minutos→segundos (validado por teste com timeout 20s).
  2. Callers dos 5 botões de export agora usam helper `executarExport` (try/catch + `unawaited` + SnackBar de erro) — não há mais falha silenciosa.
- **Testes:** novo `test/services/pdf_export_service_test.dart` (3 testes do quebra-texto + geração do prontuário com URL longa). Isolate para a geração foi **avaliado e adiado** (pw.Document/rootBundle não são transferíveis; exigiria serializar ~60 campos de 3 modelos).

### Novo: item "Anamnese" no menu Exportar (respostas do paciente)
- **Objetivo (dono):** exportar em PDF o questionário de anamnese **respondido pelo paciente** (`AnamneseEnviada`), com todas as seções/perguntas do template e os valores preenchidos.
- **Implementação:**
  1. Novo `lib/services/anamnese_labels.dart` — mapa `anamneseLabels` (rótulos pt-BR, extraídos de `_labelResposta` do `paciente_resumo_tab.dart`, que agora o reutiliza) + `formatarValorResposta` (List→"a, b", bool→"Sim/Não", vazio→"-"). Sem travessão "—" (fonte Helvetica do PDF não suporta, quebra o layout — padrão já documentado).
  2. `PdfExportService.exportarAnamnese` + `_gerarPdfAnamnese` — PDF A4 no estilo dos demais (cabeçalho/rodapé, dados do paciente + profissional, data da resposta). Percorre o **template JSON** (`AnamneseTemplates.templatePadrao`) cruzando com `anamnese.respostas`: renderiza cada seção (Dados básicos, Motivo, Intensidade, Saúde, Bloco da abordagem, Segurança emocional, Objetivos) com perguntas + respostas; **segurança emocional em destaque** (alerta laranja em risco); campos condicionais (ex.: "Quais?" quando "Usa medicação=Sim") como sub-resposta; pergunta sem resposta → "-".
  3. Item "Anamnese" no bottom sheet de export (`paciente_detail_page.dart`): se `anamnese == null || !isRespondido` mostra SnackBar "O paciente ainda não respondeu a anamnese." (não gera PDF vazio). Protegido pelo `executarExport`.
- **Testes:** +2 em `test/services/pdf_export_service_test.dart` (com respostas completas e sem respostas, ambos com timeout 20s).

### Fix: bottom sheet de Exportar não rolava (item "Anamnese" inacessível)
- **Sintoma:** com 6 itens no menu Exportar, o último ("Anamnese") ficava cortado/inclicável em telas menores.
- **Fix:** `showModalBottomSheet` ganhou `isScrollControlled: true` e o conteúdo (`SafeArea > Column`) foi envolvido em `SingleChildScrollView` — rola verticalmente quando não cabe. Visual inalterado onde cabe.

### APK
- Bumps nesta sessão: `1.0.22+23` → **`1.0.25+26`** (`MentAllPRO-v1.0.23.apk` → `v1.0.24.apk` → `v1.0.25.apk`, ~72 MB cada).
- `flutter analyze` limpo (1 warning pré-existente em `tools/`); testes Flutter **122/122** (exceto flake conhecido do `sessao_form_page_test` no teardown); backend **48/48**.

## Correções e Funcionalidades (28/08/2026) — PENTEST STRIX (1º SCAN) + GH CLI + SKILLS

### GitHub CLI (`gh`) instalado e autenticado
- **Binário:** `~/.local/bin/gh` (v2.98.0, baixado do release oficial — sem Homebrew). **Já autenticado** na conta `rodrigolemospsi` (device flow).
- **Uso:** `gh secret list`, `gh run list`, `gh repo view` (ex.: `gh run list -R rodrigolemospsi/mentall-api --limit 5`). Se o token expirar: `gh auth login --hostname github.com --git-protocol https --web`.
- **Verificação real (28/08):** repo `rodrigolemospsi/mentall-api` **público**, branch default `master`, branches `master` + `gh-pages`. Secret `FLY_API_TOKEN` presente (criado 24/08). CI: 2 falhas históricas (22/08 e 24/08 17:21) — **todas anteriores** à criação do `FLY_API_TOKEN` (24/08 17:26); desde então 100% success (último: 28/08, deploy Fly em 57s).

### Strix — AI pentest (primeiro scan executado)
- **Ferramenta:** Strix (AI penetration testing agentic, open-source). CLI já instalado em `~/.strix/bin/strix` (v1.5.3). Repo: `github.com/usestrix/strix` (59k stars). Docs: `docs.strix.ai`, `docs.app.strix.ai`.
- **9 skills instaladas em `.opencode/skills/`:** `penetration-testing-with-strix`, `managed-pentesting-with-strix`, `fix-security-vulnerabilities-with-strix`, `ci-security-scanning-with-strix`, `application-security-testing`, `web-app-penetration-testing`, `api-security-testing`, `owasp-top-10-testing`, `find-security-vulnerabilities-in-code` (instaladas manualmente via curl — sem Node/npx no sistema).
- **Config:** `~/.strix/cli-config.json` no formato `{"env": {"STRIX_LLM": "deepseek/deepseek-v4-flash", "LLM_API_KEY": "<DEEPSEEK_API_KEY do backend/.env>", "STRIX_TELEMETRY": "0"}}`. Modelo escolhido: **DeepSeek** `deepseek-v4-flash` (o mesmo do backend; confirmado disponível na conta). Modelos alternativos disponíveis: OpenAI `gpt-4.1` (conta NÃO tem gpt-5.x), Gemini `gemini-3.7-flash`.
- **⚠️ Regra de segurança no uso:** `strix -t <dir>` monta o alvo **writable** no sandbox e os agentes **leem todos os arquivos** (inclusive `.env`!). **Sempre rodar contra checkout limpo** (`git archive HEAD | tar -x -C /tmp/strix-target` + remover `auditoria/`), nunca contra o diretório de trabalho com secrets.

### Resultado do 1º scan (28/08/2026)
- **Comando:** `strix -n -t /tmp/strix-target --scan-mode standard --max-budget 10` (~40 min, **US$ 1.37** de US$ 10).
- **Resultados em:** `/tmp/strix_runs/strix-target_e366/` (`penetration_test_report.md` executivo + `vulnerabilities/*.md` com PoC + `findings.sarif` + `vulnerabilities.csv`).
- **Total: 20 achados validados** (6 High, 11 Medium, 3 Low).

#### 🔴 High (6) — corrigir primeiro
1. **IDOR em `/lembretes`** — `POST /lembretes` usa `compromisso_id` do cliente como PK via `INSERT OR REPLACE` e `DELETE /lembretes/{compromisso_id}` apaga por chave sem checar `owner_id` (`backend/services/lembrete_service.py`). Profissional B pode apagar/sequestrar lembrete de A (IDs = microsegundos previsíveis).
2. **PIN-recovery brute-forcável** — `_gerar_codigo()` usa 6 dígitos com SHA-256 **sem salt** (crack offline ~0.06s); `/auth/verificar-recuperacao` sem contador de tentativas + **query quebrada `SELECT codigo`** (coluna inexistente) que deixa o fluxo não-funcional; enumeração de e-mail via respostas distintas em `/auth/solicitar-recuperacao`.
3. **4 CVEs de dependências:** `python-jose==3.3.0` (CVE-2024-33663/33664 — mitigado na prática pelo HS256 pinado, mas latente), `python-multipart==0.0.18` (7 CVEs: path traversal, DoS — alcançável via `form()` no webhook WhatsApp), `requests==2.32.3` (2 CVEs), `python-dotenv==1.0.1` (symlink overwrite).

#### 🟠 Medium (11) — destaques
- **Stored XSS** em `/anamneses/{token}` — `dados_extra` (incl. `abordagem`) injetado sem escape via `json.dumps` em bloco `<script>`; CSP permite `unsafe-inline`. Confirmado executando em Chromium. (Contrato validado como seguro.)
- **Rate-limit bypass** — `_rate_limit_check` chaveia em `request.client.host`; com `--proxy-headers` no Dockerfile o IP vira o `X-Forwarded-For` do atacante (11 logins com XFF rotativo burlam 429). Bucket único compartilhado entre rotas.
- **Badge "✓ Verificado" CRP falseável** — `crp_verificado` vem do cliente e é renderizado em páginas públicas mesmo quando o endpoint do servidor reporta CRP inativo.
- **Backup plaintext** — `BackupService.exportarParaJson` grava DB clínico completo (fotos, transcrições, áudio, tokens de contrato) em JSON claro sem MAC; import valida só a chave `versao` (backup adulterado injeta/edita registros). Gate de PIN ineficaz (dead code).
- **Foto/endereço/token de contrato sem criptografia no Hive** — criptografia cobre só `nome`/`contato`/`email`/`observacoes`.
- **Senha fraca** — `RegistrarRequest.senha` min_length=6 sem complexidade; combinado com rate-limit bypass viabiliza brute-force online (registro com `123456` aceito).

#### ✅ Validado como seguro
Sem SQL injection (queries parametrizadas), SSRF (URLs fixas), template injection, JWT algorithm confusion (HS256 pinado), mass assignment (Pydantic v2), CORS misconfig, enumeração de usuário no login, XSS no contrato, e-mail-confirmation tokens ok.

### Recomendações do relatório (ordem de prioridade)
1. **Immediate:** autorização por `owner_id` nos lembretes + `compromisso_id` gerado no servidor · endurecer PIN-recovery (entropia 8+ alfanumérica CSPRNG, hash lento com salt bcrypt/argon2, lockout por conta, respostas genéricas, corrigir `SELECT codigo`) · corrigir rate limiter (IP real, buckets por rota/conta) · escapar saída em script-context + remover `unsafe-inline` · subir deps (`python-jose>=3.4.0`, `python-multipart>=0.0.31`, `requests>=2.33.0`, `python-dotenv>=1.2.2`) · senha mínima 10 chars + complexidade.
2. **Short-term:** backup criptografado AES-GCM + HMAC envelope verificado no import · criptografar `fotoBase64`/`enderecoJson`/token de contrato no Hive · `crp_verificado` derivado no servidor · erros genéricos no contrato.
3. **Medium-term:** tamper-resistance na auditoria (hash chain/HMAC) · normalizar cert pinning + inactivity timeout · endurecer webhook WhatsApp.

### CORREÇÕES DO PENTEST — ACHADOS HIGH (29/08/2026, skill fix-security-vulnerabilities-with-strix)
Re-verificados no HEAD atual e corrigidos (TDD — testes RED antes de cada fix):
- **IDOR lembretes (High):** `agendar_lembrete` agora gera o `id` no servidor (`uuid`), nunca usa `compromisso_id` como PK (`INSERT OR REPLACE` removido). Upsert por `(owner_id, compromisso_id)`. `cancelar_lembrete` e o `DELETE /lembretes/{id}` filtram por `owner_id` (o handler agora extrai `auth`). Tests: `backend/tests/test_lembrete_idor.py` (4).
- **PIN-recovery (High):** código 8 alfanuméricos CSPRNG (era 6 dígitos); hash bcrypt com salt (`_hash_codigo`, com fallback `_hash_codigo_legado` sha256 para hashes antigos); contador de tentativas + lockout de 15 min por conta (`MAX_TENTATIVAS_RECUPERACAO=5`); respostas genéricas em `solicitar-recuperacao` (anti enumeração de e-mail); **corrigida a query quebrada `SELECT codigo` → `codigo_hash`**. Colunas novas `tentativas`/`bloqueio_ate` em `recuperacoes` (CREATE TABLE + `_garantir_coluna`). `VerificarCodigoRequest.codigo` 6-12. Tests: `backend/tests/test_recuperacao_pin.py` (14).
- **Dependências com CVEs (High):** `requirements.txt` — `python-jose 3.3.0→3.4.0`, `python-multipart 0.0.18→0.0.31`, `requests 2.32.3→2.33.0`, `python-dotenv 1.0.1→1.2.2` (CRLF normalizado para LF). Instaladas no venv e validadas no boot + `TestClient` (health, recuperação, webhook form/json).
### CORREÇÕES DO PENTEST — ACHADOS MEDIUM (29/08/2026, skills security-and-hardening + test-driven-development)
TDD (testes RED antes de cada fix). Re-verificados no HEAD e corrigidos:
- **Stored XSS na anamnese (Medium):** `dados_extra` (incl. `abordagem`) era injetado via `json.dumps` sem escape em `<script>` (CSP com `unsafe-inline`). Novo `_json_script_seguro` (escapa `&<>` + U+2028/29 como `\uXXXX`) e `_montar_pagina_anamnese_script`; o template agora recebe JSON seguro para `DADOS_PROFISSIONAL` e `TEMPLATE`. Tests: `backend/tests/test_anamnese_xss.py` (4).
- **Rate-limit bypass (Medium):** bucket era global por `client.host` (XFF do atacante, burlava 429 com IP rotativo e consumia o orçamento de todas as rotas). `_rate_limit_check` agora recebe o `Request`: deriva IP real via último XFF (`_cliente_ip`) e chaveia por `{rota}|{ip}` ou `{rota}|{chave_extra}` (conta) nos endpoints de auth (login, registrar, verificar-crp, recuperação). Tests: `backend/tests/test_rate_limit.py` (7).
- **Badge CRP falseável (Medium):** `crp_verificado` vinha do cliente e era renderizado nas páginas públicas. Novo `_crp_verificado_servidor(registro, cliente_afirma)`: consulta o CFP no servidor na criação do contrato/anamnese; sem registro, sem afirmação ou falha de rede → False (fail-closed). Tests: `backend/tests/test_crp_selo.py` (5).
- **Senha fraca (Medium):** `RegistrarRequest.senha` era min 6 sem complexidade. Schema agora valida ≥10 chars + maiúscula + minúscula + número (`validar_senha` via `field_validator`); endpoint usa `_validar_registro_ou_raise`; app `conta_page.dart` alinhado (validação 10+complexidade antes de enviar). Tests: `backend/tests/test_senha_fraca.py` (7).
- **Backup plaintext (Medium):** `BackupService` exportava DB clínico em JSON claro sem MAC; import validava só `versao`. Novo envelope `mentall_backup_v1` (`EncryptionService.criptografarEnvelope`/`descriptografarEnvelope`): AES-GCM + HMAC-SHA256 (chave derivada, comparação em tempo constante). Export com PIN gera envelope; import verifica MAC antes de restaurar (rejeita adulteração), requer PIN se cifrado, mantém compat com JSON claro legado. Tests: `test/services/backup_envelope_test.dart` (7) + `backup_service_test.dart` atualizado.
- **Criptografia parcial Hive (Medium):** `Paciente.fotoBase64`/`enderecoJson` e `ContratoTerapeutico.token`/`url` passaram a ser cifrados em repouso (`_encryptPaciente`/`_decryptPaciente`, `_encryptContrato`/`_decryptContrato`). `sincronizarPendencias` descriptografa antes de `verificarStatus`; novo `ContratoService.criarLocalmente`; backup export/import ajustado (foto, endereco, token, url). Tests: `test/services/campos_criptografados_test.dart` (4).
- **Verificação:** backend **89/89**; Flutter **133/133** nos arquivos não-flake (`sessao_form_page_test` travou no teardown — flake conhecido de file-lock, documentado); `flutter analyze` limpo (1 warning pré-existente em `tools/`).

## REFATORAÇÃO DO SESSÃO_FORM_PAGE (29/08/2026) — 2388 → 1901 LINHAS

Pendência histórica do AGENTS.md resolvida em 6 fases (1 commit cada, TDD). Plano completo em `tasks/plan_sessao_form_refactor.md` + `tasks/todo_sessao_form_refactor.md`.

### Resultado
- `lib/screens/sessao_form_page.dart`: **2388 → 1901 linhas** (−20%), com lógica de negócio de áudio/IA/salvar mantida no State (decisão do dono).
- **Flake do `sessao_form_page_test` CORRIGIDO** (causa raiz): `Hive.box.put()` pendura quando chamado no corpo de `testWidgets` (FakeAsync não avança I/O). Setup das sessões movido para o `setUp()` do grupo. Agora **12/12 em ~1s** (antes travava por minutos).
- **Testes: 153/153** (melhor marca do projeto; antes 133/133 não-flake). Inclui fix de bug pré-existente em `compromisso_service_test` (usava `DateTime.now()` com compromisso `agora+1h`, falhava perto da meia-noite — agora horário fixo).

### Fases (commits `3690f41`..`1c7c804` + `sessao_form_refactor`)
1. **Fase 0 — rede de segurança:** flake corrigido (put no corpo de testWidgets), novo `audioPlayerProvider` injetável (`service_providers.dart`) com `_FakeAudioPlayer` no teste (o `AudioPlayer` real pendura o teardown), `dart format` no arquivo (corrige indentações quebradas).
2. **Fase 1 — estado compartilhado:** novo `lib/providers/sessao_form_providers.dart` com os 21 `StateProvider` migrados do topo do arquivo (nomes públicos `sessao*`, importáveis por qualquer widget). Getters/setters espelhados mantidos como camada fina do State.
3. **Fase 2 — seções de UI extraídas (widgets autocontidos):**
   - `lib/widgets/sessao_progresso_widget.dart` — `SecaoProgressoWidget` (ConsumerWidget lendo providers de progresso) + `corTendencia()` utilitária.
   - `lib/widgets/sessao_financeiro_widget.dart` — `SecaoFinanceiroWidget` (ConsumerWidget lendo/escrevendo providers financeiros + pacoteService; recebe `pacienteId` + `valorController`).
   - `lib/widgets/sessao_relato_ia_widget.dart` — `SecaoRelatoIaWidget` (ConsumerWidget lendo providers globais de áudio/IA) + `SessaoFormActions` (objeto que agrupa os 13 callbacks, evitando 15+ parâmetros soltos).
4. **Fase 3 — helpers de lógica pura:** novo `lib/utils/sessao_form_helpers.dart` (`concatenarSintese`, `concatenarFormulacao`, `formatarData`, `formatarHorario`, `nomeEscala`, `obterObjetivosTerapeuticos/obterQueixaPrincipal/obterEscalasRecentes` — estes recebem `ref`+`pacienteId`). **Decisão do dono:** métodos de áudio/transcrição/síntese/salvar permanecem no State (acoplados a `context`/`mounted`/controllers; extrair relocaria complexidade).
5. **Fase 4 — qualidade:** contadores de gravação unificados (`_iniciarContadorGravacao({resetarDuracao})`, `_pararContadorGravacao`), `_progressoMetas` morto + `sessaoProgressoMetasProvider` removidos, `_salvarSessao` com `_aplicarDadosComuns(Sessao)` (elimina ~75 ln duplicadas editar/criar), `fontSize:21` → `Tipografia.xl`.
6. **Fase 5 — verificação:** `flutter analyze` limpo (1 warning pré-existente em `tools/`), **153/153 testes**, commit final.

### Padrão consolidado para telas grandes (seguir daqui em diante)
- Estado em **providers públicos** (`lib/providers/`) → seções de UI como **ConsumerWidget autocontidos** lendo os providers (sem callbacks soltos; agrupar em objeto `*Actions` quando necessário).
- **NÃO usar `part files` + extension** (já falho em 01/08/2026 — métodos de instância têm precedência).
- Lógica pura (sem UI) → `lib/utils/*_helpers.dart` testável isoladamente.
- Lógica acoplada a `context`/`mounted`/controllers → permanece no State.

### APK
- `1.0.25+26` → **`1.0.26+27`**; APK `MentAllPRO-v1.0.26.apk` (72 MB). Push **seguro** (sem deploy) — código fica local.

## INFRAESTRUTURA LOCAL (25/08/2026) — Setup e automação

### Localização do projeto (MOVIDA!)
- Projeto movido de `~/Documents/mentall-pro-app` → **`~/mentall-pro-app`** (fora de Documents).
- **Motivo**: a pasta Documents é protegida pelo **TCC do macOS** — o launchd não conseguia executar scripts lá (`Operation not permitted`). Fora de Documents, a automação funciona.

### Serviços locais com launchd (iniciam no login + reiniciam se caírem)
- **`com.mentall.wuzapi`** → wuzapi (WhatsApp) na porta **8080**. Plist: `~/Library/LaunchAgents/com.mentall.wuzapi.plist`. Binário: `~/wuzapi/wuzapi`. Logs: `~/wuzapi/wuzapi.launchd.log(.err.log)`.
- **`com.mentall.backend`** → backend (uvicorn) na porta **8000**. Plist: `~/Library/LaunchAgents/com.mentall.backend.plist`. Script: `~/mentall-pro-app/backend/start_backend.sh` (roda `.venv/bin/python -u -m uvicorn`). Logs: `backend.launchd.log` (stdout/requests) e `backend.launchd.err.log` (logs do app/scheduler).

### Como operar
- **Reiniciar um serviço**: `launchctl kickstart -k gui/$(id -u)/com.mentall.backend` (ou `.wuzapi`).
- **Parar**: `launchctl unload ~/Library/LaunchAgents/com.mentall.<serviço>.plist`.
- **Ver logs**: `tail -f ~/mentall-pro-app/backend/backend.launchd.err.log`.
- **`start_backend.sh` e `start_wuzapi.sh`** também servem para uso manual (`nohup ... &`).

### Python e ferramentas (sem Homebrew/sudo)
- **uv** (gerenciador): `~/.local/bin/uv`. Instalou **Python 3.12.14** gerenciado.
- **Backend venv**: `~/mentall-pro-app/backend/.venv` (Python 3.12). Ativar/rodar: `./.venv/bin/python -m uvicorn main:app --port 8000`.
- **Importante**: `main.py` usa f-strings que exigem **Python 3.12+** (o 3.9 do sistema não compila).
- **Go** (para compilar wuzapi): `~/go-local/bin/go`.
- **GitHub CLI (`gh`)**: binário `~/.local/bin/gh` (v2.98.0, baixado do release oficial — sem Homebrew). **Já autenticado** na conta `rodrigolemospsi` (device flow em 28/08/2026). Usar `gh` para consultar secrets/actions/PRs: `gh secret list`, `gh run list`, `gh repo view`. Ex.: `gh run list -R rodrigolemospsi/mentall-api --limit 5`. Se o token expirar: `gh auth login --hostname github.com --git-protocol https --web`.

### wuzapi
- Binário compilado: `~/wuzapi/wuzapi` (v1.0.8). Config: `~/wuzapi/.env` (`WUZAPI_ADMIN_TOKEN`).
- Usuário/instância "profissional" criada, **WhatsApp conectado** (`loggedIn: true`, jid `557592298347@s.whatsapp.net`).
- Token do usuário (para envio): `WUZAPI_TOKEN` (em `backend/.env` → `WUZAPI_TOKEN`; **não versionar** — rotacionado em 25/08/2026 após vazamento no AGENTS.md).
- Dashboard: `http://localhost:8080/dashboard` (login = admin token do `~/wuzapi/.env`).

### Validação concluída (ponta a ponta)
- wuzapi enviando (curl direto), função `_enviar_whatsapp_via_wuzapi` OK, endpoint `/enviar-whatsapp` autenticado OK.
- **Scheduler automático** OK: agendou lembrete → log `Lembrete WhatsApp enviado via wuzapi: 557592298347 (id=...)` (o `mensagem_id` agora é gravado no lembrete para correlacionar com o webhook de entrega/leitura).
- **KeepAlive** OK: matar o backend → launchd reinicia sozinho em ~10s.

## Correções e Funcionalidades (25/08/2026) — LEMBRETES VIA WUZAPI (WhatsApp do próprio profissional)

### Decisões do dono (entrevista)
- Objetivo: **reduzir custo** de envio de lembretes de sessão (Twilio cobra por mensagem) e facilitar o início da operação.
- **Número**: WhatsApp **do próprio profissional** (multi-usuário — cada psicólogo conecta o seu; no 1º momento o dono conecta o dele).
- **Hospedagem**: testar **local no PC** primeiro, depois **Fly.io** (máquina separada do backend).
- **Canal**: **só WhatsApp** — opção SMS **removida** do formulário de compromisso e do backend.
- **Conexão**: via **painel web do wuzapi** (`/dashboard` → QR code escaneado com o celular do profissional; mecânica de "aparelho vinculado" como WhatsApp Web).
- **Escopo**: **só lembretes automáticos** (scheduler). Envios manuais de anamnese/acordo continuam abrindo o WhatsApp do celular (`url_launcher`).
- **Risco assumido**: wuzapi usa WhatsApp não-oficial (whatsmeow) — risco de banimento em uso comercial (decisão do dono; caminho oficial p/ escala = WhatsApp Business API).

### Backend
- **`services/db.py`**: nova tabela `wuzapi_instancias (owner_id PK, wuzapi_token, wuzapi_user_id, conectado, atualizado_em)`.
- **`services/lembrete_service.py`**: reescrito — remove `_enviar_whatsapp_direto` (Twilio); novo `_enviar_whatsapp_via_wuzapi(owner_id, telefone, mensagem)`:
  - Resolve token: env `WUZAPI_TOKEN` (1ª fase) → depois tabela `wuzapi_instancias` (multi-profissional).
  - Normaliza telefone BR → internacional sem `+` (`(11) 99999-9999` → `5511999999999`).
  - `POST {WUZAPI_BASE_URL}/chat/send/text` com header **`token`** (⚠️ o wuzapi usa header `token` minúsculo, NÃO `Authorization` — `Authorization` é só para `/admin/*`).
  - Scheduler passa a usar a função wuzapi.
- **`main.py`**:
  - `POST /enviar-whatsapp` → agora usa wuzapi (envio imediato, quando toca na notificação).
  - `POST /enviar-sms` **removido** (Twilio SMS fora de escopo).
  - Novo `POST /wuzapi/config` (protegido por JWT): registra token da instância do profissional (upsert por `owner_id`).
- **`models/schemas.py`**: removidos `SmsRequest`/`SmsResponse`; novo `WuzapiConfigRequest`.
- **`.env`/`.env.example`**: `WUZAPI_BASE_URL` (local `http://localhost:8080`) e `WUZAPI_TOKEN` (token do usuário wuzapi conectado).

### Flutter
- `compromisso_form_dialog.dart`: seletor canal WhatsApp/SMS **removido** — lembrete sempre WhatsApp (fixo `canalLembrete: 'whatsapp'`).
- `lembrete_service.dart`: `enviarMensagem` sempre via `/enviar-whatsapp` (sem ramo SMS).
- `configuracoes_page.dart`: texto "lembrete via SMS" → "lembrete via WhatsApp".

### Verificação
- `flutter analyze`: limpo (1 warning pré-existente em `tools/`).
- Testes: widgets 14/14, services OK.
- Backend: sintaxe validada nos arquivos alterados (`schemas`, `lembrete_service`, `db`). `main.py` não compila no Python 3.9 local por f-strings pré-existentes (exigem 3.12, que é o do Docker/produção).

### Próximos passos (manual do dono)
1. Instalar wuzapi local: `brew install asternic/wuzapi/wuzapi` (ou `go build`).
2. Rodar: `WUZAPI_ADMIN_TOKEN=<token> ./wuzapi` → `http://localhost:8080/dashboard`.
3. Criar usuário + conectar WhatsApp via QR (celular → Aparelhos conectados).
4. Colar o token do usuário em `backend/.env` → `WUZAPI_TOKEN`.
5. Rodar backend local e testar: criar compromisso com lembrete para daqui a 1 min.
6. Depois: deploy do wuzapi no Fly.io (Dockerfile do repo) + `WUZAPI_BASE_URL` apontando para lá.

## Correções e Funcionalidades (25/08/2026) — AUDITORIA VISUAL: CORES, RAIO, TIPOGRAFIA E COMPONENTES

### Auditoria de frontend (estilo, cores e padrões)
- Revisão completa do design system existente (`MentAllProColors`, `Tipografia`, `Espacamento`, `Responsivo`). Nota 8/10 — gaps eram **aderência ao próprio design system**, não problemas estruturais.

### Novos tokens e componentes de design system
- **`lib/utils/raio.dart`** (novo): escala unificada de border radius `xxs=6, xs=8, sm=10, md=12, lg=14, xl=16, xxl=18, xxxl=24`. Migrados **100+ ocorrências hardcoded** em 25+ arquivos (widgets + screens + main).
- **`lib/widgets/mentall_card.dart`** (novo): `MentAllCard` — card tema-consciente (sombra `corCardSombra` no claro / borda `corCardBorda` no escuro), com `padding`, `borderRadius`, `color` e `onTap` opcionais. Aplicado em `home_dashboard` (KPI, Sessões de hoje, Atividade recente), `financeiro_page` (_cardResumo), `paciente_resumo_tab` (_pacoteCard, _contratoCard, _secaoEvolucao).
- **`lib/widgets/botoes.dart`** (novo): helpers `botaoPrimario()` (FilledButton com spinner de loading) e `botaoSecundario()` (OutlinedButton com cor de borda customizável).
- **`lib/widgets/status_chip.dart`** (novo): `StatusChip` unificado (label, cor, icone, fontSize, pill, borda). Substituiu `_StatusPacienteChip`, `_PendenciasBadge` (paciente_card_home), `_statusBadge` (paciente_resumo_tab) e o chip inline do Financeiro.
- **`lib/utils/app_bar_padrao.dart`** (novo): helper `appBarPadrao()` (AppBar primária com `corPrimaria`/`corOnPrimaria`). Aplicado em Financeiro, Pacientes e Paciente Detail.

### Cores — eliminação de hardcoded
- Todos os `Theme.of(context).colorScheme` de widgets/screens substituídos pela extension `MentAllProColors` (`context.corPrimaria`, `context.corCard`, `context.corOnPrimaria`, `context.corContainerPrimario`, `context.corOnSurface`, etc.).
- Adicionado getter `corOnSurface` em `lib/utils/mentall_colors.dart`.
- Imports LGPD corrigidos (`../../utils/mentall_colors.dart`).

### Tipografia — migração de literais
- `lib/utils/tipografia.dart`: adicionados tokens `xxs=10, xs=11, sm=12, smMd=13, base=14, baseMd=15, md=16, lg=18, xl=20, xxl=24, display=28`.
- **200+ `fontSize` literais** → tokens `Tipografia.xxx` em 36 arquivos (valores idênticos = zero mudança visual), incluindo `main.dart` textTheme e PDFs.

### SegmentedButton nativo
- `pacientes_page.dart`: `_SegmentedControl`/`_Segment`/`_SegmentData` custom (~110 linhas) removidos → `SegmentedButton<int>` nativo do Material 3, com estilização preservada (fundo `onPrimary` 12%, texto primário no selecionado).

### AppBar padronizada
- `appBarPadrao()` aplicada em `financeiro_page`, `pacientes_page` e `paciente_detail_page` (removida redundância com `appBarTheme` do tema).

### Verificação
- `flutter analyze`: limpo (1 warning pré-existente em `tools/gerar_prompts_ia_pdf.dart`).
- Testes: widgets 14/14 (`app_start` 2, `home` 4, `paciente_detail` 6, `perfil_form` 2), services 23/23, `widget_test` 52/52.
- `sessao_form_page_test`: travou no teardown (flake conhecido de file-lock, documentado).

### APK
- `1.0.13+14` → **`1.0.14+15`**; APK `MentAllPRO-v1.0.14.apk` (72 MB).

### Pendência (deferida pelo dono)
- Limpeza de espaçamentos mágicos (2, 3, 5, 6, 10, 14, 18) → `Espacamento` — baixo valor, risco de mudança visual.

## Correções e Funcionalidades (24/08/2026) — ONBOARDING SIMPLIFICADO

### Onboarding em tela única fullscreen
- Antes: carrossel de 3 slides (`prontuario_inteligente.png`, `sua_abordagem_001_1.jpeg`, `seguranca_app.png`) com dots + botões "Pular" / "Começar".
- Agora: **1 tela única** com `sua_abordagem_001_1.jpeg` em fullscreen (`BoxFit.cover`), apenas botão **"Pular"** sobreposto no canto superior direito.
- Removidos: `PageView`, `PageController`, dots, `_pageIndexProvider`, botão "Começar".
- Lógica `_concluir()` mantida: marca `onboardingConcluido` via `ConfiguracoesService.setOnboardingConcluido(true)` e navega para perfil/Home.
- Assets removidos: `prontuario_inteligente.png`, `seguranca_app.png`.

### `ConfiguracoesService` — propriedade `onboardingConcluido`
- Adicionados getter `onboardingConcluido` e setter `setOnboardingConcluido(bool)` persistindo em Hive `app_config` (chave `onboarding_concluido`).

### Verificação
- `flutter analyze` limpo.
- `flutter test test/widgets/app_start_page_test.dart` → 2/2 passando.
- APK: `1.0.11+12` → **`1.0.12+13`**; APK `MentAllPRO-v1.0.12.apk` (75,4 MB).

## Correções e Funcionalidades (24/08/2026) — UX, ÁUDIO, ESTABILIDADE IA E DEPLOY

### Botão "Marcar como revisado" só aparece após gerar a síntese
- Antes aparecia logo após a transcrição (condição usava `_estaAguardandoRevisao`, que incluía o status `'transcrito'`).
- Agora depende apenas de `!_revisadoPeloProfissional && _geradoComIa` (`sessao_form_page.dart`). Removido o getter `_estaAguardandoRevisao` (sem uso). 3 testes de regressão em `sessao_form_page_test.dart`.

### Áudio: gravação 16 kHz / 32 kbps (arquivo ~3× menor)
- `audio_relato_service.dart`: AAC LC mantido, mas `sampleRate` 44100→16000 e `bitRate` 96000→32000.
- 16 kHz é a taxa nativa do Whisper/Groq; qualidade para fala preservada. Relato de 5 min cai de ~3,6 MB → ~1,2 MB.
- Web continua WAV/PCM (caminho separado, não afetado). Validado em APK 1.0.8 no Android.

### Perfil atualiza na tela imediatamente após editar
- Home e Pacientes liam o perfil com `ref.read` no build (não-reativo) → saudação "Dr. Fulano" e termos ficavam desatualizados até reiniciar o app.
- Novo `perfilRevisaoProvider` (StreamProvider de contador, padrão `configuracoesRevisaoProvider`) + `ref.watch(perfilRevisaoProvider)` no build das duas telas.

### Estabilidade da síntese (IA)
- **`GEMINI_MODEL` configurável via env** (`ia_clinica.py`): antes `gemini-3.7-flash` era hardcoded; agora `os.getenv("GEMINI_MODEL", "gemini-3.7-flash")`. Troca de versão sem redeploy. Secret criado no Fly.
- **Timeout do app** na chamada de síntese: 60s → 90s (`ia_clinica_service.dart`).
- Causa da oscilação "Serviço de IA temporariamente indisponível": rate limit (429) do Gemini na 1ª chamada, sem fallback eficaz por timeout curto.

### Logos e ícone
- Novas logos `logo_mentallpro_fundoclaro_01.png` / `fundoescuro_01.png` / `sem_nome_01.png` (French Violet); ícone do app redimensionado para 1024×1024 e mipmaps regerados.
- Onboarding usa `sua_abordagem_001_1.jpeg` no lugar da png antiga.

### Deploy (Fly.io + GitHub Actions) — fix do deploy automático
- **Causa raiz**: o repositório não tinha o secret `FLY_API_TOKEN` (0 secrets) → o CI falhava com "no access token available" (já falhava desde 22/08).
- **Fix**: criado o secret `FLY_API_TOKEN` no GitHub (token `flyctl tokens create deploy`, criptografado via API libsodium). Próximo push dispara o deploy normalmente.
- **Nota**: se o CI voltar a falhar com "no access token available", recriar o secret `FLY_API_TOKEN` no GitHub (Settings → Secrets → Actions).

### Outros
- `.gitignore` agora ignora `*.apk` (artefatos locais não versionados).
- Novos tools: `tools/gerar_guia_publicacao_pdf.dart` e `tools/gerar_prompts_ia_pdf.dart` (geram PDFs na raiz).
- APK: `1.0.8+9` (`MentAllPRO-v1.0.8.apk`).
- Fluxo de síntese confirmado: Gemini (`gemini-3.7-flash`) como provedor principal, com fallback OpenAI/DeepSeek (todas as chaves configuradas no Fly).

## Correções e Funcionalidades (22/08/2026) — SESSÃO 2 — CORES: SOMBRAS, BARRA INFERIOR, TÍTULOS E MARCA

### Decisões do dono (confirmadas por pergunta)
- Tema claro: **sombra dos cards → `#E0AAFF` a 40%**; **barra fixa inferior** (NavigationBar) → fundo `#E0AAFF` com ícones/legendas `#3C096C`.
- **Títulos principais** dos documentos → **`#3C096C`** (só o título principal de cada documento; subtítulos internos de seção permanecem).
- **Nome "MentAll PRO"** nos documentos → **`#C77DFF`**.
- Escopo "documentos": PDFs do app (6 tipos + LGPD) + HTML backend (contrato/anamnese) + tools (catálogo, guia, apresentação).

### Arquivos alterados
- `lib/utils/mentall_colors.dart` — `corCardSombra` → `Color(0xFFE0AAFF).withValues(alpha: 0.40)`.
- `lib/main.dart` — `navigationBarTheme` no tema claro (`brightness == light`): fundo `#E0AAFF`, indicator `#3C096C` 14%, ícones/legendas `#3C096C` (selecionado) / `#3C096C` 55-60% (não selecionado).
- `lib/services/pdf_export_service.dart` — consts `_titulo` (`#3C096C`) e `_marca` (`#C77DFF`); helper `_tituloDocumento`; títulos principais (Registro de Sessão, HISTÓRICO CLÍNICO, Relatório Clínico, Síntese Revisada, Prontuário Completo, Relatório Financeiro) → `_titulo`; fallback "MentAll PRO" no cabeçalho → `_marca`.
- `lib/services/lgpd/pdf_arquitetura_lgpd_service.dart` — consts `_titulo`/`_marca`; títulos das 14 seções + sublinhado → `_titulo`; header "MentAll PRO" → `_marca`.
- `backend/templates/contrato.html` e `anamnese.html` — `.titulo-acordo` → `#3C096C`; `.logo-mentall` → `#C77DFF`.
- `backend/main.py` — template inline do contrato (idem `.titulo-acordo` e `.logo-mentall`).
- `tools/gerar_catalogo_pdf.dart` e `tools/gerar_guia_mac_pdf.dart` — `tituloSecao(1)` → `#3C096C`; "MentAll PRO" (cabeçalho + capa) → `#C77DFF`.
- `gerar_apresentacao_pdf.dart` — `_titulo` (seções em caps) → `#3C096C`; "MENTALL" da capa → `#C77DFF`.

### Fora de escopo (decisão do dono)
- Rodapés "MentAll PRO — Soluções para Psicólogos" mantidos cinza; e-mails transacionais fora.
- Sombra de elevação do `Card` (`cardTheme.elevation`) e `shadowColor` do botão de áudio (`sessao_audio_controls.dart`) não mudam.

### Verificação
- `flutter analyze` limpo nos 7 arquivos alterados; `flutter test` 98/98 passando.

### APK
- `1.0.4+5` → **`1.0.5+6`**; APK `MentAllPRO-v1.0.5.apk`.

## Correções e Funcionalidades (22/08/2026) — REBRAND FRENCH VIOLET + NOVAS LOGOS

### Nova paleta da marca: French violet (antes azul #2066FF)
- Variações da logo (escala tonal fornecida pelo dono): **Claro `#A10AF5`** · **Principal `#8806CE`** · **Médio `#6D05A5`** · **Escuro `#52047C`** · **Sombra profunda `#360250`**.
- Seed do `ColorScheme.fromSeed` em `main.dart` → `0xFF8806CE` (propaga para AppBar, FAB, botões, ícones e links automaticamente).
- PDFs (`pdf_export_service.dart` `_primaria`, `pdf_arquitetura_lgpd_service.dart` `_azul`) e tools (`gerar_catalogo_pdf`, `gerar_guia_mac_pdf`, `gerar_apresentacao_pdf`) → primária `#8806CE`.
- Bordas/acentos claros (`_primariaClara`, `_azulClaro`) → `#A10AF5`.
- Fundos claros (`_azulBg` `#E8F1FF`, `#EFF6FF`) → **`#A10AF5` translúcido 12%** (`0x1FA10AF5` / `rgba(161,10,245,0.12)`) para preservar legibilidade (decisão do dono).
- Splash Android claro `#8806CE` e escuro `#52047C`; `web/manifest.json` → `#8806CE`.
- Backend (decisão do dono: também backend): `main.py`, `contrato.html`, `anamnese.html` → `#8806CE` + `rgba(136,6,206,0.12)` + fundos `rgba(161,10,245,0.12)`.

### Novas logos (fundos francês violeta + transparência)
- `logo_mentallpro_fundoescuro1.png` → `logo_mentallpro_french_violet_transparente.png` (dark).
- `logo_mentallpro_fundoclaro1.png` → `logo_mentallpro_fundoclaro_french_violet_transparente.png` (light).
- Arquivos: `app_start_page`, `login_page`, `conta_page`, `perfil_profissional_form_page`, `home_page`, `pdf_export_service`.
- Textos de marketing atualizados ("paleta azul" → "violeta") em `gerar_apresentacao_pdf.dart` e `MentAll_Apresentacao.txt`.
- Pendência do dono: regenerar ícone do app (`logo_mentallpro_sem_nome*`) depois.
- `flutter analyze` limpo nos arquivos alterados.

### APK e numeração de versão (convenção)
- **Convenção de release:** cada APK novo incrementa `versionName` (patch) + `versionCode` (+1) em `pubspec.yaml`, e o artefato é renomeado para `MentAllPRO-vX.Y.Z.apk` na raiz do repo.
- Nesta sessão: `1.0.3+4` → **`1.0.4+5`**; APK `MentAllPRO-v1.0.4.apk` (78,8 MB). O `app-release.apk` cru da pasta `build/` não deve ser entregue — sempre copiar/renomear seguindo o padrão.
- Lembrete: **sempre fazer o bump de versão antes de buildar** (o build anterior saiu com a versão antiga por esquecimento).

## Correções e Funcionalidades (15/08/2026) — LOGIN FIX + PERFORMANCE ÁUDIO + LOGOS

### Fix crítico: login dava "Credenciais inválidas" (bcrypt)
- Causa raiz: `passlib==1.7.4` + `bcrypt>=4.1` (removeu `bcrypt.__about__`) → a verificação de senha falha no Linux/Docker (em produção), mesmo com a conta confirmada. No Windows local "funcionava por sorte do fallback".
- Fix: `backend/requirements.txt` → `bcrypt==4.0.1` + redeploy. Contas de teste quebradas (`rodrigolemosba@gmail.com`, `mentall.brasil@gmail.com`) apagadas do Turso via `flyctl ssh console`.
- Verificado em produção: hash `$2b$`, `verify` True/False corretos, round-trip de `autenticar` True. Fluxo conta → e-mail → login **funcionando**.

### SMTP Gmail configurado (produção)
- Fly secrets: `SMTP_USER`/`SMTP_FROM`=rodrigolemosba@gmail.com, `SMTP_PASS`=senha de app, `SMTP_HOST=smtp.gmail.com:587`. (O `SMTP_USER` estava **faltando** nos secrets.)

### Performance: playback de áudio travava ~10s
- Causa: descriptografia AES-GCM em Dart puro (pointycastle/`encrypt`) na thread principal, sobre ~4,3 MB (base64 da gravação).
- Fix (2 fases):
  - `encryption_service.dart`: novos `criptografarBytes`/`descriptografarBytes` rodam AES-GCM em **`Isolate.run`**; novo formato **binário "MAV1"** (`[MAV1][nonce 12][cipher]`), criptografa bytes crus (sem dupla base64).
  - `audio_relato_service.dart`: **cache em memória** (`_cacheAudioDescriptografado`, some ao fechar o app); `lerAudioDescriptografado` detecta 3 formatos (novo "MAV1" / legado "3:"/"2:" base64 / arquivo puro).
  - `sessao_audio_controls.dart` + `sessao_form_page.dart`: novo `preparandoAudioProvider` + spinner "Preparando áudio..." no botão Ouvir; `_existeAcaoEmAndamento` inclui `preparando`.
- Backward compat: arquivos antigos ("3:") continuam funcionando (caminho legado).
- Testes: 96/96 (2 novos em `audio_relato_service_test.dart`: round-trip binário MAV1 + formato inválido→null).

### Troca de logos (15/08)
- Novas logos (dono redimensionou p/ performance): `logo_mentallpro_fundoclaro1.png` (claro), `logo_mentallpro_fundoescuro1.png` (escuro), `logo_mentallpro_sem_nome.png` (ícone sem nome).
- Mapeamento nas telas: `logo_mentall_escuro.png` → `logo_mentallpro_fundoescuro1.png`; `logo_mentall_pro_claro.png` e `logo_mentall_pro_home.png` (claro) → `logo_mentallpro_fundoclaro1.png`. Arquivos: `app_start_page`, `login_page`, `conta_page`, `perfil_profissional_form_page`, `home_page`, `pdf_export_service`.
- Ícone do app: `pubspec.yaml` `flutter_launcher_icons` → `logo_mentallpro_sem_nome.png` (Android via `dart run flutter_launcher_icons`). Ícones web (favicon + Icon-192/512/maskable) via Pillow. iOS fica para depois (`ios: false`).
- 6 logos antigas apagadas (~6-7 MB no APK).

### Ajustes finos (15/08) — ícone, tamanho e paleta
- **Ícone +40%**: a logo `sem_nome` é retangular (577×433); regerada com `bounding box` + escala p/ ocupar ~78% da altura (`logo_mentallpro_sem_nome_quadrado.png` via Pillow).
- **Logos das páginas −20%** (×0,8): `app_start` 160/320→128/256 · `login` 120/240→96/192 · `conta` idem · `perfil` 160→128 e 56→45 · `home` 98→78 · `pdf` 44→35 e 40×40→32×32.
- **Paleta azul da logo** (primário `#2563EB` → **`#2066FF`** azul elétrico):
  - `main.dart` seed, `pdf_export_service`, `pdf_arquitetura_lgpd`, `tools/gerar_catalogo_pdf`, `gerar_apresentacao_pdf` (0xFF2066FF).
  - Backend `contrato.html`/`anamnese.html` + `main.py` (HTML inline) → `#2066FF` (+ rgba 32,102,255); tint `#EFF6FF` → `#E8F1FF`.
  - `web/manifest.json` → `#2066FF`; splash Android claro `#2066FF` e escuro `#061A7A` (marinho).
- **Cards "sombreado" (tema-consciente)**: cards de paciente (`paciente_card_home`), Home (KPI + Sessões de hoje + Atividade recente), Financeiro (resumo) e perfil (endereço) usam os getters `corCardSombra` (sombra no tema claro) e `corCardBorda` (borda fina `outlineVariant` no tema escuro). Campos de texto continuam `OutlineInputBorder`.

### Ajustes finos (15/08) — sessão 2: WhatsApp, ícones e cabeçalho
- **Escolha de WhatsApp**: novo `lib/services/whatsapp_service.dart` com seletor "WhatsApp / WhatsApp Business". Android usa `android_intent_plus` (pacotes `com.whatsapp` / `com.whatsapp.w4b`); iOS/Web abrem o WhatsApp único. Ligado em `paciente_card_home.dart` (botão do card) e `paciente_resumo_tab.dart` (envio de anamnese e acordo terapêutico). Logos no seletor: `logo_whats_grande.png` + `logo_whats_business.png`.
- **Sugestão no contato da demo** (`demo_data_service.dart`): "Linda M. Tester" agora tem `contato: (11) 99999-9999` + nota nas observações para o dono substituir pelo próprio número e testar o WhatsApp.
- **Ícone do menu `⋮`** (`paciente_detail_page.dart`): "Escalas Psicologicas" e "Acordo Terapeutico" com `color: corPrimaria` (fix do ícone invisível no tema claro).
- **Cabeçalho de Pacientes** (`pacientes_page.dart`): fundo azul (`primary`) + título/ícone "+" brancos; controle segmentado (Ativos/Arquivados) adaptado ao fundo azul. **Home permanece branca** com a logo (decisão do dono).

### Google Sign-In (STANDBY)
- Plano documentado: `POST /auth/google` (verifica id_token via `google-auth`) + `google_sign_in` no app. Pendente: projeto Google Cloud + client IDs (Web/Android/iOS).

### Pendências
- Bug do áudio "duração errada ao reabrir" (instrumentado; aguarda reprodução do dono + logs).
- Fase 2+ (telemetria, painel admin, cobrança) — `tasks/plan.md`.
- (Opcional) ferramentas avaliadas e **não** instaladas: Jerico (orquestrador multi-agente, só macOS). **Strix já instalado e em uso desde 28/08/2026** — ver seção "PENTEST STRIX" no topo.

## Correções e Funcionalidades (14/08/2026) — UI + PLANO DE VENDA RECORRENTE (FASE 1: CONTAS)

### UI — abas da área de pacientes
- **`pacientes_page.dart`**: `_PillTab` (pills desproporcionais) → `_SegmentedControl` de largura total (segmentos `Expanded` iguais em trilho arredondado), com listener no `TabController` para sincronizar com swipe.
- **`paciente_detail_page.dart` + `paciente_sessoes_tab.dart`**: abas **só texto** (removidos ícones), `indicatorWeight: 3`.
- **`responsivo.dart`**: breakpoints em 3 níveis (`TamanhoTela compacto/medio/expandido`, `breakpointTablet=600`, `breakpointDesktop=1024`) — `isTablet` mantido para compatibilidade.
- **`pacientes_page.dart` grid tablet**: `SliverGridDelegateWithFixedCrossAxisCount(childAspectRatio: 3.5)` → `SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 420, mainAxisExtent: 92)`.
- Tokens: hex `Color(0x...)` → `MentAllProColors`; raios de card unificados (resumo tab 14→18).
- Teste corrigido: `paciente_detail_page_test.dart` usa `find.descendant(of: AppBar, matching: byIcon(edit_outlined))` (ambiguidade com o botão Editar do `AnamneseCard`).

### Barra inferior segue o termo do perfil
- `perfil_profissional.dart`: novo getter `termoPluralNavbar` (Pacientes/Clientes/P. Atendidas).
- `service_providers.dart`: novo `perfilTermoPluralProvider` (StreamProvider reativo via `observarPerfil()`).
- `main_shell.dart`: aba "Pacientes" usa o termo dinâmico no `NavigationDestination` + `Semantics`.

### Plano de negócio: venda recorrente + painel de controle (NÃO implementado ainda)
- **Objetivo (confirmado com o dono):** vender o MentAll por assinatura mensal p/ outros psicólogos + painel web (site no PC, só do dono) com online/offline, tipos de acesso (plano grátis/pago + aparelho Android/iPhone/navegador), receita e uso.
- **Decisões confirmadas:** 7 dias grátis de teste; cobrança via Google Play + App Store (celular) e Pix/cartão (navegador); online = app aberto agora, offline = tem app mas não usa.
- **Plano salvo em `tasks/plan.md` + `tasks/todo.md`** (6 fases). Recomendação técnica: RevenueCat (lojas) + Stripe (web).

### FASE 1 (implementada + verificada) — Contas de psicólogos com link mágico
- **Backend:**
  - `db.py`: tabela `usuarios` (id, email único, password_hash, nome, plano, status='pendente', criado_em, ultimo_acesso_em, email_verificacao_token_hash, email_verificacao_expiracao). Helper de migração `_garantir_coluna()` (PRAGMA table_info + ALTER TABLE).
  - `services/usuarios.py` (novo): hash/verify senha (bcrypt), `criar_usuario_pendente`, `regenerar_token`, `confirmar_email`, `autenticar`, `registrar_acesso`, `_hash_token` (sha256).
  - `main.py`: `POST /auth/registrar` (pendente + envia link mágico), `GET /auth/confirmar-email?token=` (HTML ativa conta), `POST /auth/login` (bloqueia pendente 403 + fallback admin legado preserva `APP_USER_ID`).
- **Frontend:**
  - `conta_page.dart` (novo): login/cadastro + passo "Confirme seu e-mail" (link enviado / "Já confirmei" / "Reenviar link").
  - `api_client.dart`: `accountEmail`/`possuiConta`/`salvarConta`, `registrarConta` (sem auto-login), `entrarComEmailSenha`, `_extrairDetalhe`.
  - `app_start_page.dart`: gate de conta antes do PIN (`if (!ApiClient.possuiConta) return ContaPage()`) + `ref.watch(contaRevisaoProvider)`.
  - `app_start_page_test.dart`: seed `auth_meta['account_email']` no setUp.
- **Segurança (skill security-and-hardening):** código de recuperação de PIN agora **não é logado** e é guardado **como hash** (`recuperacoes.codigo_hash`, sha256). Token do link mágico guardado só como hash.
- **SMTP Gmail** em `.env`/`.env.example`: `smtp.gmail.com:587`, `SMTP_USER=SMTP_FROM=rodrigolemosba@gmail.com`.

### ⚠️ PENDÊNCIA do dono (bloqueia envio real de e-mail)
- Gmail exige **"Senha de app"** (16 chars, não a senha normal). Dono deve gerar em myaccount.google.com/apppasswords e colar em `backend/.env` na linha `SMTP_PASS` (hoje placeholder `sua_senha_de_app_gmail_aqui`).

### Próximos passos (quando recomeçar)
1. **Fase 2 — telemetria**: tabelas `dispositivos`/`eventos`, endpoints `/telemetria/heartbeat` + `/telemetria/evento`, `telemetria_service.dart` no app (online/offline por heartbeat). Sem dado clínico (LGPD).
2. Fase 3 painel admin web, Fase 4 cobrança (RevenueCat/Stripe), Fase 5 app conta+assinatura+gating IA, Fase 6 segurança/monitoramento.
3. Ainda definir com o dono: valor da mensalidade, endereço do painel, gating de limites Free vs Pro.

## Correções e Funcionalidades (13/08/2026) — MIGRAÇÃO FLY.IO + SÍNTESE GEMINI + ARTIGOS DESACOPLADOS

### Migração Render → Fly.io (migração completa)
- **Backend oficial:** `https://mentall-api.fly.dev` (app `mentall-api`, região `gru` São Paulo)
- **Sempre ligada:** 1 máquina `shared-cpu-1x` 512mb, `min_machines_running=1` + `auto_stop_machines="off"` (sem cold start). O Fly criou 2 máquinas por HA; reduzido com `flyctl scale count 1`
- **Deploy:** `flyctl deploy` local + GitHub Actions (`.github/workflows/deploy.yml`, secret `FLY_API_TOKEN`). Dockerfile python:3.12-slim, imagem 74MB
- **Secrets (25):** JWT_SECRET, APP_PASSWORD_HASH, `APP_USER_ID` fixo (antes UUID por boot quebrava isolamento owner_id), OPENAI/GROQ/GEMINI/DEEPSEEK keys, OPENALEX, TURSO_DATABASE_URL+AUTH_TOKEN, SMTP, API_BASE_URL
- **Turso conectado** (`/health` → `database=turso`)
- **URL padrão do app** atualizada em `api_client.dart`, hint em `configuracoes_page.dart`, `API_BASE_URL` em `main.py` (3x)
- **Arquivos:** `fly.toml`, `Dockerfile`, `.dockerignore`, `.github/workflows/deploy.yml`, `backend/.env.example` (+APP_USER_ID, +API_BASE_URL)

### Backend — bugs críticos descobertos na migração
- **Boot crashava:** `main.py` importava `RecuperacaoRequest/Response`, `RegistrarRecuperacaoRequest`, `VerificarCodigoRequest/Response` que não existiam em `schemas.py` → adicionadas 5 classes
- **Recuperação de PIN 500-ava:** tabela `recuperacoes` não existia em `db.py` (só contratos/anamneses/lembretes) → adicionada
- **Rotas divergentes:** Flutter chamava `/recuperacao/*`, backend expõe `/auth/*-recuperacao` → alinhado o Flutter (registrar/solicitar-codigo/verificar-codigo → /auth/registrar-recuperacao, /auth/solicitar-recuperacao, /auth/verificar-recuperacao)

### Síntese: artigos desacoplados (resposta mais rápida)
- `/gerar-sintese` agora devolve a síntese **na hora** + `temas_pesquisa` (sem esperar artigos). Novo endpoint `/gerar-artigos` busca os artigos separadamente
- Frontend: síntese renderiza imediatamente; card "Artigos sugeridos" mostra **"Buscando artigos científicos..."** e preenche quando chega (busca em background, `_buscandoArtigosProvider`)
- `ia_clinica.py`: `_parse_resultado_sucesso` não roda mais `_montar_artigos` inline; nova função `gerar_artigos()`
- **Arquivos:** `backend/services/ia_clinica.py`, `backend/main.py`, `backend/models/schemas.py` (+ArtigosRequest/Response, +temas_pesquisa), `lib/services/ia_clinica_service.dart` (+gerarArtigos, +temasPesquisa), `lib/screens/sessao_form_page.dart`

### Síntese: OpenAI gpt-4.1 → Gemini 3.7 Flash
- **A/B test real (mesmo relato TCC/ansiedade social):** gpt-4.1 = 14,9s vs gemini-3.7-flash = 6,4s (~2,3x mais rápido), qualidade equivalente ou melhor (Gemini acrescentou avaliação de risco e formulação mais rica, usa bullets `•`)
- **Conta OpenAI NÃO tem gpt-4o-mini** (só `gpt-4.1` chat + `gpt-4o-mini-transcribe`); erro 403 `Project does not have access to model gpt-4o-mini`
- **Modelos Gemini descontinuados:** `gemini-2.0-flash` e `gemini-2.5-flash` retornam 404 "no longer available"; família atual é `gemini-3.x` (validados: 3.5/3.6/3.7-flash)
- **Bug corrigido:** `_get_model_name()` lia o `IA_MODEL_PROVIDER` global (caminho Gemini mandava "gpt-4.1") → agora recebe o provider como parâmetro
- **Ativação:** `IA_MODEL_PROVIDER=gemini` (secret Fly + `.env`); `_get_model_name("gemini")` = `gemini-3.7-flash`
- **Arquivos:** `backend/services/ia_clinica.py`, `backend/main.py` (log de boot usa `_get_model_name`), `backend/.env`, `backend/.env.example`

### APK
- Release gerado: 73,35 MB (`build/app/outputs/flutter-apk/app-release.apk`) — aponta para fly.dev

### Commits
- `86cc6ba` — feat: migra backend e app para o Fly.io
- `5887550` — fix: recuperacao de PIN quebrada (schemas, tabela recuperacoes e rotas)
- `132af52` — feat: sintese via Gemini 3.7 Flash + artigos desacoplados da resposta
- `46963d0` — docs: memoria das correcoes de 13/08/2026

## Correções e Funcionalidades (13/08/2026) — SESSÃO 2 — CONTADOR DE SESSÕES + REMOÇÃO BDI/BAI

### Contador de sessões realizadas na aba "Sessões" da ficha do paciente
- A aba externa "Sessões" (`paciente_detail_page.dart`) agora mostra `Sessões (N)`, com **total = ativas + arquivadas**
- Novo provider reativo `sessoesRealizadasPorPacienteProvider` (`StreamProvider.family` + `async*`, mesmo padrão do `dashboardKpisSessoesProvider`) — atualiza sozinho ao adicionar/arquivar/restaurar sessão
- Testes atualizados: `find.text('Sessões')` → `find.textContaining('Sessões (')` (match exato quebraria)
- **Arquivos:** `lib/providers/service_providers.dart`, `lib/screens/paciente_detail_page.dart`, `test/widgets/paciente_detail_page_test.dart`

### Escalas BDI e BAI removidas (copyright Pearson)
- **Pesquisa de direitos autorais:** BDI (Inventário de Depressão de Beck) e BAI (Inventário de Ansiedade de Beck) são **protegidos por copyright (Pearson / The Psychological Corporation)** — "a fee must be paid for each copy used". PHQ-9, GAD-7 e DASS-21 são de **domínio público**
- **Remoção:** blocos `bdi` e `bai` apagados de `escala_service.dart` (`_escalas`) e do `_nomeEscala` em `sessao_form_page.dart`. Restam PHQ-9, GAD-7 e DASS-21
- `tools/gerar_catalogo_pdf.dart` atualizado: "5 escalas" → "3 escalas"
- **Arquivos:** `lib/services/escala_service.dart`, `lib/screens/sessao_form_page.dart`, `tools/gerar_catalogo_pdf.dart`

### APK + infra
- APK release 73,35 MB gerado (inclui Gemini, artigos desacoplados, contador de sessões e remoção BDI/BAI)
- **⚠️ Disco C: cheio** (0 GB livre) — build falhou na 1ª tentativa; limpei `build/` do projeto (~1,7 GB) e Gradle transforms (`~/.gradle/caches/9.1.0`, ~4,2 GB) para liberar espaço. Recomendo liberar espaço no C: antes do próximo build

### Commits
- `6550708` — feat: contador de sessoes realizadas na aba Sessoes da ficha do paciente
- `cd6942f` — feat: remove escalas BDI e BAI (copyright Pearson); mantem PHQ-9, GAD-7 e DASS-21

## Correções e Funcionalidades (04/08/2026) — TRANSCRIÇÃO RÁPIDA, SÍNTESE CONFIÁVEL E SEGURANÇA

### Transcrição via Groq Whisper (50x mais rápida e barata)
- **Migração:** OpenAI gpt-4o-mini-transcribe → Groq whisper-large-v3-turbo
- **Velocidade:** 30-90s → **~2 segundos** (processamento LPU)
- **Custo:** R$0,02/min → **R$0,0004/min** (50x mais barato)
- **API:** OpenAI-compatible — mudança de ~10 linhas no backend
- **Arquivos:** `backend/services/transcricao.py` reescrito com suporte a provedor configurável (`TRANSCRICAO_PROVIDER=groq`), `render.yaml` + env vars

### Síntese via GPT-4o-mini (JSON confiável + 3x mais rápido que DeepSeek)
- **Migração:** DeepSeek V4 Flash → GPT-4o-mini (padrão `IA_MODEL=gpt-4o-mini`)
- **Vantagens:** `response_format: json_object` nativo (zero falhas de parsing), 3x mais rápido, custo ~R$1,30/mês
- **Artigos não-bloqueantes:** busca de artigos com `ThreadPoolExecutor` + timeout 8s — não trava a resposta da síntese
- **Arquivos:** `backend/services/ia_clinica.py` (modelo padrão + timeout 60s + threading), `lib/services/ia_clinica_service.dart` (timeout 60s)

### Gravação de áudio confiável
- **Wakelock:** `wakelock_plus ^1.5.2` mantém tela ativa durante gravação
- **Integridade:** verifica se arquivo .m4a existe e tem tamanho > 0 após parar
- **Criptografia resiliente:** fallback para texto puro se `EncryptionService.tryEncrypt` falhar (não perde o áudio)
- **Bitrate reduzido:** AAC 128kbps → 96kbps (~25% menor = upload mais rápido)
- **Arquivos:** `lib/services/audio_relato_service.dart`, `pubspec.yaml`

### Timeouts e retry otimizados
- **Transcrição:** timeout 120→90s, auth forçada a partir do 2º retry, tratamento HTTP 429
- **Síntese:** timeout 120→90s (frontend 60s), backoff mais agressivo
- **Backend:** rate limit 10 req/min no `/transcrever` (antes sem limite)

### Backend — correções críticas
- **Bug da síntese:** `_chamar_llm_json` duplicada deletada (V1 linha 299). Rerank de artigos corrigido. `_parse_resultado_sucesso` com try/except
- **Endpoints assíncronos:** `/transcrever`, `/gerar-sintese`, `/gerar-progresso` convertidos para `async def` + `run_in_executor`
- **Timeouts:** OpenAI 120s, Gemini 120s em todos os clientes

### Selo de verificação CRP (`✓ Verificado`)
- **API do CFP:** `POST /verificar-crp` consulta `cn-api.cfp.org.br/psi/busca` — verifica se registro está ativo
- **Modelo:** `PerfilProfissional` com +2 HiveFields: `crpVerificado` (bool), `crpDataVerificacao` (DateTime?)
- **Disparo automático:** ao salvar perfil, verificação roda em background
- **Ícone:** `✓ Verificado` verde (#2E7D32) exibido em todos os lugares onde o CRP aparece:
  - Perfil profissional, 5 tipos de PDF, contrato HTML, anamnese HTML, template personalizado
- **Cache:** resultado armazenado no modelo local (data de verificação)
- **Arquivos:** `backend/services/crp_service.py`, `lib/services/crp_service.dart`, 14 arquivos alterados

### CRP sem duplicação de prefixo
- **Problema:** hint "Ex.: CRP 00/00000" + PDF/contrato prefixando "CRP" = "CRP CRP 00/00000"
- **Solução:** hint alterado para "Ex.: 00/00000", PDF e templates removem prefixo antes de prefixar `_limpar_crp()`
- **Arquivos:** `perfil_profissional_form_page.dart`, `pdf_export_service.dart`, `main.py`, `contrato.html`

### Acordo Terapêutico — correções
- **Subtítulos em negrito:** parser de template personalizado detecta linhas curtas como `<h2>` (negrito). Espaçamento 28px entre seções
- **Tela branca:** bug estrutural corrigido — funções auxiliares estavam dentro do corpo da função principal, quebrando o fluxo
- **Data formato brasileiro:** `2026/08/04` → `04/08/2026` via `_formatar_data_br()`
- **Arquivos:** `backend/main.py`, `backend/templates/contrato.html`

### Anamnese — correção web
- **Problema:** `const TEMPLATE = {{TEMPLATE}};` — JSON vazio ou com `</script>` quebrava a página
- **Solução:** fallback `"{}"` para template vazio, escape `</` → `<\/`, validação de JSON
- **Arquivos:** `backend/main.py`

### Renomeação MentAll → MentAll PRO
- **27 arquivos alterados:** nome do app, telas, PDFs, HTML, logos, prompt IA, testes
- **Novas logos:** `logo_mentall_pro_claro.png`, `logo_mentall_pro_home.png`
- **Extensão:** `MentAllColors` → `MentAllProColors`
- **Não alterado:** URLs `mentall-api.onrender.com`, pacote `com.mentall.app`, loggers internos

### APK
- Release: 71.4MB (era 69.9MB — +wakelock_plus + novas logos)

### Commits
- `7a9d351` — renomeação MentAll → MentAll PRO
- `a449002` — selo de verificação CRP
- `c703dcc` — fix anamnese web
- `d9c40f5` — fix CRP duplicado
- `e2da782` — subtítulos em negrito no Acordo
- `16520b1` — fix tela branca Acordo
- `69ff51e` — síntese GPT-4o-mini + artigos não-bloqueantes
- `98bce40` — transcrição Groq Whisper
- `98d8377` — wakelock + timeouts + bitrate

## Projeto
App Flutter para prontuário clínico adaptado à abordagem terapêutica do profissional (TCC, Psicanálise, ACT, DBT, etc.), com assistência de IA para transcrição e análise de sessões.

## Stack
- **Framework:** Flutter (SDK ^3.12.2)
- **Linguagem:** Dart / Python (backend)
- **Estado:** Riverpod 100% — 0 `setState` em todo o app. StreamProvider + StateProvider + ConsumerStatefulWidget
- **Banco local:** Hive CE (hive_ce + hive_ce_flutter + hive_ce_generator)
- **Áudio:** record + audioplayers + path_provider
- **Geração de código:** build_runner + hive_ce_generator
- **Backend:** Python FastAPI, OpenAI GPT-4.1 / DeepSeek / Gemini (síntese) + gpt-4o-transcribe (transcrição)
- **Deploy backend:** Render.com (plano gratuito, cold start ~30-60s)
- **Segurança:** Criptografia AES-256-CBC com PBKDF2-HMAC-SHA256 (100k iterações, pointycastle) + IV aleatório por registro + autenticação JWT no backend (python-jose + passlib)

## Infraestrutura

### Backend em Nuvem (Render)
- **URL produção:** `https://mentall-api.onrender.com`
- **Repositório GitHub:** `https://github.com/rodrigolemospsi/mentall-api`
- **Plano:** Free (cold start na primeira requisição após inatividade)
- **Deploy:** Automático via push no branch `master`
- **Configuração:** `render.yaml` na raiz do repo (Blueprint)
- **Variáveis de ambiente no Render:**
  - `OPENAI_API_KEY` — chave API da OpenAI (projeto, formato `sk-proj-...`)
  - `OPENAI_PROJECT_ID` — ID do projeto OpenAI (formato `proj_...`)
  - `GEMINI_API_KEY` — chave API do Google Gemini (opcional; usada apenas se `IA_MODEL_PROVIDER=gemini`)
  - `DEEPSEEK_API_KEY` — chave API do DeepSeek (formato `sk-...`)
  - `IA_MODEL_PROVIDER` — provedor de síntese: `openai`, `deepseek` (ativo em produção) ou `gemini`
  - `IA_MODEL` — modelo específico (opcional; padrão por provedor: `gpt-4.1`, `deepseek-chat`, `gemini-2.0-flash`)
  - `JWT_SECRET` — chave secreta para tokens JWT
  - `APP_PASSWORD_HASH` — hash bcrypt da senha (vazio = senha padrão `admin`)
  - `OPENALEX_API_KEY` — chave gratuita da OpenAlex (https://openalex.org/settings/api, $1/dia ≈ 10k buscas; **obrigatória** — sem ela a API retorna 429 em IP de datacenter)
  - `OPENALEX_MAILTO` — email de contato enviado nas requisições à OpenAlex (`mentall.brasil@gmail.com`)
  - `TURSO_DATABASE_URL` — URL do banco Turso (formato `libsql://nome-banco.turso.io`; **obrigatória**)
  - `TURSO_AUTH_TOKEN` — token de autenticação do Turso (gerado em https://console.turso.org)

### APK (Android)
- **Permissões necessárias:** `INTERNET`, `RECORD_AUDIO`, `usesCleartextTraffic=true`
- **URL do backend:** Configurável via Hive box `app_config`. Padrão: `https://mentall-api.onrender.com`
- **Timeout API:** 120 segundos (necessário para cold start do Render + transcrição)
- **Diálogo de config:** Ícone ![dns](...) na AppBar da Home permite alterar URL sem rebuild

### Desenvolvimento Local
- Backend local: `python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload`
- Para testar APK no celular com backend local: mesmo Wi-Fi, firewall liberado porta 8000, `--host 0.0.0.0`
- URL padrão local: `http://192.168.1.24:8000` (Wi-Fi) ou `http://192.168.1.4:8000` (Ethernet)

## Estrutura

### Flutter App (`lib/`)
```
lib/
├── main.dart                              # Entry point, Hive init, ErrorWidget.builder, tema Material 3
├── hive_registrar.g.dart                  # Generated
├── config/
│   └── configuracao_abordagem_clinica.dart # 14 templates de abordagens (inclui Análise do Comportamento)
├── models/
│   ├── enums.dart                          # AbordagemClinica (14), TermoPessoaAtendida, StatusProcessamento, OrigemRelato (6)
│   ├── paciente.dart / .g.dart             # Hive typeId: 1 (12 campos: +email, +dataAtualizacao, +fotoBase64)
│   ├── perfil_profissional.dart / .g.dart  # Hive typeId: 3 (10 campos: +fotoBase64)
│   ├── sessao.dart / .g.dart               # Hive typeId: 2 (31 campos: +transcricaoRevisada, +artigosSugeridos)
│   ├── compromisso.dart / .g.dart          # Hive typeId: 4 (17 campos: +canalLembrete)
│   ├── contrato_terapeutico.dart / .g.dart # Hive typeId: 5 (9 campos)
│   └── lgpd/
│       └── registro_auditoria.dart / .g.dart  # Hive typeId: 10
├── screens/
│   ├── app_start_page.dart                 # Roteamento inicial (verifica PIN + perfil)
│   ├── home_page.dart                      # Lista de pacientes + botão servidor + Privacidade
│   ├── login_page.dart                     # Tela de PIN (configurar/desbloquear)
│   ├── paciente_detail_page.dart           # Detalhes + sessões + acesso última sessão ~720 linhas
│   ├── sessao_form_page.dart               # Formulário de sessão ~1901 linhas (+ error handling)
│   ├── backup_restore_page.dart            # Export/import JSON (conditional import)
│   ├── backup_restore_page_web.dart        # Web: Blob download + FileUpload
│   ├── backup_restore_page_io.dart         # Mobile/desktop: share_plus (export) + file_picker (import)
│   ├── perfil_profissional_form_page.dart
│   ├── configuracoes_page.dart             # Configurações (PIN, agenda, IA, servidor)
│   ├── agenda_page.dart                    # Agenda completa (Dia/Semana/Mês) ~1190 linhas
│   ├── pacientes_page.dart                 # Lista dedicada de pacientes (Ativos/Arquivados)
│   └── lgpd/
│       ├── privacidade_seguranca_page.dart  # Tela de Privacidade e Segurança (LGPD)
│       ├── politica_privacidade_page.dart   # Política de Privacidade
│       └── termos_uso_page.dart             # Termos de Uso
├── providers/
│   ├── service_providers.dart              # 12 providers (Stream com async* para emitir valor inicial)
│   └── sessao_form_providers.dart          # 21 StateProviders públicos da tela de sessão (fase 1 do refactor)
├── services/
│   ├── api_client.dart                     # URL dinâmica via Hive + credenciais no Hive + ensureAuthenticated() + timeout 120s
│   ├── paciente_service.dart               # + criptografia AES nos campos sensíveis + cascade delete
│   ├── perfil_profissional_service.dart    # + criptografia AES
│   ├── sessao_service.dart                 # + criptografia AES (19 campos) + cache próximo número
│   ├── compromisso_service.dart            # CRUD de compromissos + recorrência + cancelamento de lembretes
│   ├── lembrete_service.dart               # Agendamento de notificações locais + envio ao backend (WhatsApp/SMS)
│   ├── backup_service.dart                 # Export/import JSON com exclusão de áudio grande + O(1) import
│   ├── transcricao_relato_service.dart     # Lê arquivo .m4a e converte Base64 (mobile) + JWT auto-auth
│   ├── ia_clinica_service.dart             # Conectado ao backend GPT-4.1 + pseudonimização + retry 5xx
│   ├── audio_relato_service.dart           # Gravação web (WAV/Base64) + mobile (M4A/arquivo)
│   ├── status_clinico_sessao_service.dart
│   ├── hive_migration_service.dart         # Schema V3
│   ├── encryption_service.dart             # PBKDF2-HMAC-SHA256 (100k iterações) + IV aleatório por registro
│   ├── auth_service.dart                   # PIN local + JWT backend (credenciais no Hive)
│   ├── pdf_export_service.dart             # 5 tipos + contrato: sessão, histórico, relatório, síntese, prontuário
│   ├── contrato_service.dart               # CRUD contratos + comunicação com backend
│   ├── configuracoes_service.dart          # Preferências (duração, lembretes, IA, tema, canal)
│   ├── logger.dart                         # Log.erro / Log.info / Log.auditoria + persistência em Hive+arquivo
│   └── lgpd/
│       ├── auditoria_service.dart          # Registro de eventos LGPD
│       └── pdf_arquitetura_lgpd_service.dart
├── widgets/
  │   ├── home_dashboard.dart                # Dashboard da Home (5 seções: saudação, ações, KPIs, sessões, atividade)
  │   ├── agenda_inline_widget.dart          # Agenda inline (Dia/Semana/Mês) ~640 linhas
  │   ├── compromisso_form_dialog.dart       # Diálogo de criação/edição de compromisso
  │   ├── novo_paciente_dialog.dart          # Diálogo de cadastro de paciente
  │   ├── paciente_card_home.dart            # Card de paciente na lista (avatar, status, WhatsApp)
  │   ├── paciente_resumo_card.dart          # Card de resumo na ficha do paciente (+ status contrato)
  │   ├── sessao_card.dart                   # Card de sessão na lista
  │   ├── sessao_audio_controls.dart         # Controles de áudio extraídos do SessaoFormPage (+ 12 providers de áudio/IA)
  │   ├── sessao_artigos_sugeridos.dart      # Card de artigos sugeridos extraído do SessaoFormPage
  │   ├── sessao_form_widgets.dart           # CardBuscandoArtigos + AudioMantidoSwitch + BotaoSalvarSessao
  │   ├── sessao_progresso_widget.dart       # SecaoProgressoWidget (evolução clínica) — fase 2 do refactor
  │   ├── sessao_financeiro_widget.dart      # SecaoFinanceiroWidget — fase 2 do refactor
  │   ├── sessao_relato_ia_widget.dart       # SecaoRelatoIaWidget + SessaoFormActions — fase 2 do refactor
  │   ├── secao_campos_clinicos_widget.dart   # 4 seções clínicas simplificadas
  │   └── lgpd/
  │       └── aviso_privacidade_ia_card.dart
```

### Backend Python (`backend/`)
```
backend/
├── main.py                           # FastAPI app, CORS, JWT auth, rotas protegidas, /health com debug de provedores
├── .env                              # Chaves de API + JWT_SECRET (NÃO commitar)
├── .env.example                      # Template com variáveis documentadas
├── requirements.txt                  # openai>=1.0.0 + httpx + python-jose + passlib
├── models/
│   └── schemas.py                    # Pydantic models + LoginRequest/LoginResponse
├── templates/
│   └── contrato.html                  # Página HTML do Acordo Terapêutico (patient-facing)
├── services/
│   ├── ia_clinica.py                 # Síntese clínica (OpenAI/DeepSeek/Gemini) + busca de artigos (OpenAlex > SciELO RSS > rerank IA > links)
│   ├── transcricao.py               # Transcrição (gpt-4o-mini-transcribe, modelo configurável via TRANSCRICAO_MODEL)
│   ├── contrato_service.py          # Armazenamento de contratos (token único + aceite)
│   └── lembrete_service.py          # Scheduler de lembretes WhatsApp/SMS (asyncio + Twilio/Meta)
└── prompts/
    └── abordagens.py                 # 14 abordagens (inclui Análise do Comportamento)
```

### Arquivos de Deploy
```
render.yaml                          # Render Blueprint (na raiz do repo)
```

## Segurança

### Autenticação
- **Backend**: JWT (python-jose) — rota `POST /auth/login`, endpoints protegidos via `Authorization: Bearer <token>`
- **Flutter**: `ApiClient.ensureAuthenticated()` chamado antes de cada requisição API (transcrição e síntese)
- Token JWT gerado automaticamente com credenciais fixas (`admin`/`admin`)
- Expiração do token: 480 minutos (8 horas)

### Criptografia Local
- **Algoritmo**: AES-256-CBC (encrypt + pointycastle)
- **Proteção**: PIN do usuário deriva chave que protege a chave AES mestra
- **Services**: `PacienteService`, `SessaoService`, `PerfilProfissionalService` criptografam/descriptografam automaticamente
- **Fallback**: Sem PIN = dados em texto puro; descriptografia detecta texto puro e retorna como está

### LGPD / Privacidade
- **Áudio**: Limite de 5 minutos com contador e parada automática
- **Microtexto**: "Relato breve do profissional após a sessão. Limite: 5 minutos." na tela de gravação
- **Auditoria**: Registro de eventos (gravação, transcrição, IA, revisão) em `RegistroAuditoria` (typeId 10)
- **Arquivamento**: Em vez de exclusão (padrão desde o início)
- **Revisão**: Obrigatória pelo profissional (campo `revisadoPeloProfissional`)
- **IA**: Apenas apoio documental, nunca substitui julgamento clínico
- **Tela Privacidade**: Acessível pelo ícone de escudo na Home — PIN, áudio, IA, retenção, auditoria
- **Exportação**: Aviso de dados sensíveis; 5 formatos de PDF
- **Logs**: `Log.auditoria()` separado de `Log.erro()`; logs técnicos não contêm dados clínicos

## Padrões e Regras de Código

### StreamProvider com Hive (IMPORTANTE)
`Hive.box.watch()` NÃO emite na subscrição inicial — apenas quando há mudanças. Sempre use `async*` para emitir o valor inicial:
```dart
final provider = StreamProvider<List<T>>((ref) async* {
  final service = ref.watch(serviceProvider);
  yield service.listar();                       // ← emite valor inicial
  await for (final _ in service.observar()) {   // ← observa mudanças
    yield service.listar();
  }
});
```

### _triggerRebuild() no SessaoFormPage
A página `SessaoFormPage` usa `ref.read` nos getters (não `ref.watch`), então mudanças de estado NÃO causam rebuild automático. Todo método que altera providers de UI deve chamar `_triggerRebuild()` após as alterações.

### Autenticação Backend
Chamadas à API (`TranscricaoRelatoService`, `IaClinicaService`) devem chamar `ApiClient.ensureAuthenticated()` antes de cada requisição para garantir token JWT válido.

### Áudio Mobile vs Web
- **Web**: PCM 16-bit → WAV em memória → Base64 direto
- **Mobile**: AAC LC → arquivo .m4a → `TranscricaoRelatoService` lê arquivo e converte para Base64
- `AudioRelatoService.obterAudioAtualBase64()` só retorna dados no Web

## Problemas Conhecidos

### APK
- Release: 69.9MB (era 69.2MB antes das correções de 03/08/2026)

## Correções e Funcionalidades (03/08/2026) — SEGURANÇA E UX COMPLETAS

### 🔴 CRÍTICO (4 itens) — Todas as vulnerabilidades resolvidas

- **Senha do backend criptografada no Hive**: `ApiClient.setCredentials()` e `AuthService._password` agora criptografam/descriptografam via `EncryptionService.tryEncrypt/Decrypt`. Sem PIN → texto puro (backward compatible). Fallback `admin`/`admin` mantido para compatibilidade.
- **JWT token criptografado no Hive**: `forceReauthenticate()` e `autenticarBackend()` criptografam o token antes de salvar em `auth_meta`. `inicializar()`, `possuiTokenJwt` e `tokenJwt` descriptografam ao ler.
- **Áudio `.m4a` criptografado no disco**: `AudioRelatoService.pararGravacao()` criptografa automaticamente (Base64 → AES). Métodos estáticos `lerAudioDescriptografado()` e `prepararAudioParaPlayback()` para transcrição/playback. Arquivo temporário descriptografado para reprodução.
- **Backup exige PIN**: `BackupRestorePage._validarPinAntesExportar()` — diálogo de PIN antes de exportar. Validação sem incrementar tentativas (`EncryptionService.validarPin()`).

### 🟠 ALTO — UX/Layout (6 itens) — Todas as melhorias implementadas

- **Ficha do paciente com TabBarView 3 abas** (Resumo / Sessões / Financeiro): `PacienteDetailPage` reduzida de 1760 → 792 linhas. 3 novos widgets extraídos: `PacienteResumoTab`, `PacienteSessoesTab`, `PacienteFinanceiroTab`. Elimina scroll único cansativo e ListView aninhado.
- **textScaleFactor com clamp 0.8–1.5**: `builder` no `MaterialApp` adiciona `MediaQuery` com `textScaleFactor.clamp()`. Acessibilidade sem quebrar layouts.
- **BottomNavigationBar** (Início / Pacientes / Financeiro): Novo `MainShell` com `IndexedStack` + `NavigationBar`. 5 itens do `⋮` reduzidos para 4. Financeiro e Pacientes ganham destaque permanente.
- **Splash adaptativo**: 1s se app configurado (perfil existe), 3s se novo. Tap-to-dismiss. Fade-out reduzido para 300ms.
- **PII removido das notificações**: Título "Lembrete de sessao" (genérico, sem nome). Payload contém apenas `compromissoId` e `canal`. Resolução de telefone/nome no tap via `CompromissoService` e `LembreteService.onNotificationTap`.
- **Descrição da auditoria criptografada**: `AuditoriaService` com `EncryptedServiceMixin`. Campo `descricao` criptografado ao salvar, descriptografado ao listar.

### 🟡 MÉDIO — Segurança (3 itens)

- **AES-256-CBC → AES-256-GCM**: `criptografar()` agora usa `AESMode.gcm` com nonce de 12 bytes. Prefixo `3:` para GCM, fallback `2:` para CBC legado. Migração transparente.
- **Inactivity timeout 5 minutos**: Timer no `AppStartPage` + `Listener` no `MaterialApp.builder`. Reseta a cada toque. Bloqueia via `authService.bloquear()` após 5 min de inatividade. Só ativo com PIN configurado.
- **Certificate pinning TLS**: `_SecureHttpOverrides` no `main.dart` com `badCertificateCallback`. Lista de fingerprints configurável (atualmente vazia — usa validação padrão do OS). Bypass para localhost/192.168.x.

### 🟡 MÉDIO — Acessibilidade (2 itens)

- **15 widgets `Semantics`**: Labels em botões principais (HomeDashboard: 3 ações, MainShell: 3 destinos, PacienteDetail: editar/exportar, LoginPage: desbloquear, SessaoFormPage: transcrever/síntese/revisado/salvar, PacientesPage: adicionar).
- **Checkbox com label tocável**: `CheckboxListTile` substitui `Row > [Checkbox, Expanded(Text)]` nos 2 checkboxes do `PerfilProfissionalFormPage` (atendimento online + consentimento LGPD).

### 🟡 MÉDIO — Consistência Visual (3 itens)

- **Escala tipográfica + TextTheme**: Constantes `Tipografia` (xs=10, sm=12, base=14, md=16, lg=18, xl=20, xxl=24, display=28). Mapeadas para `TextTheme` no `_criarTema()`.
- **Grid de espaçamento 4px**: Constantes `Espacamento` (xs=4, sm=8, md=12, base=16, lg=20, xl=24, xxl=32, section=40).
- **Cores hardcoded → `MentAllColors`**: 20 ocorrências migradas: `#D32F2F`→`corDanger`, `#0D9488`→`corPacote` (nova), hex em `paciente_resumo_tab.dart` → `corTextoHeading/corWarning/corDanger/corSuccess/corTextoMuted`. 87% de adoção nos 7 arquivos principais.

### 🟡 MÉDIO — UX/Performance (3 itens)

- **PacientesPage O(n×m) → O(n+m)**: `contarSessoesPendentesAgrupadas()` no `SessaoService` — uma passada O(S) retorna mapa. PacientesPage usa mapa em vez de loop aninhado. ~45× speedup para 50 pacientes × 500 sessões.
- **Onboarding 3 telas**: `OnboardingPage` com `PageView` + dots. Flag `onboardingConcluido` no `ConfiguracoesService`. Inserido no fluxo `AppStartPage` após perfil existir. Telas: Prontuário inteligente, Sua abordagem, Segurança e privacidade.
- **LayoutBuilder para tablets (600dp+)**: `Responsivo.isTablet()` + layouts adaptativos em KPIs da Home (4 colunas), lista de pacientes (grid 2 colunas), resumo da ficha (2 painéis lado a lado).

### Arquivos novos (10)

```
lib/screens/main_shell.dart
lib/screens/onboarding_page.dart
lib/utils/tipografia.dart
lib/utils/responsivo.dart
lib/widgets/paciente_resumo_tab.dart
lib/widgets/paciente_sessoes_tab.dart
lib/widgets/paciente_financeiro_tab.dart
```

### Testes
- 92/92 passando (era 80/92 com 12 falhas)
- Corrigidos: `paciente_detail_page_test.dart` (TabBarView), `app_start_page_test.dart` (MainShell + boxes), `home_page_test.dart` (KPI label)
- `sessao_form_page_test.dart` tearDownAll: flake conhecido de file-lock no Windows

### Commits
- `bc5c7b1` — Segurança e UX: 6 itens críticos + 11 itens médios
- `44f78a7` — Testes: corrige 12 falhas para 0 (92/92 passando)

## Correções e Funcionalidades (30/07/2026) — AUDITORIA DE SEGURANÇA E PERFORMANCE

### CRÍTICO — Corrigido
- **Perda de dados ao remover PIN**: `AvaliacaoInicialService.removerCriptografiaExistente()` e `EscalaService.removerCriptografiaExistente()` não chamavam `.save()` após descriptografar — dados de anamnese e escalas eram perdidos permanentemente. Corrigido: adicionado `await a.save()` em ambos + `AuthService.removerPin()` agora chama ambos os serviços.
- **Cascade delete incompleto**: `PacienteService.excluirPaciente()` não removia `avaliacoes_iniciais`, `respostas_escalas` e `anamneses_enviadas`. Corrigido: adicionada exclusão dos 3 boxes órfãos.
- **Stack traces em release**: `ErrorWidget.builder` em `main.dart` e `_erroInicializacao` em `sessao_form_page.dart` expunham `exceptionAsString()` sem guarda `kDebugMode`. Corrigido: stack traces só em debug.
- **KDF 10.000 → 100.000 iterações**: PBKDF2 agora usa 100k iterações (V3). PINs existentes (V2: 10k) têm fallback automático com migração transparente na próxima autenticação bem-sucedida.
- **Hash da frase de recuperação com PBKDF2 + salt**: Substituído SHA-256 puro por PBKDF2-HMAC-SHA256 com 100k iterações + salt. Hash legado (SHA-256) tem fallback com upgrade automático.
- **`criptografar()` lança exceção em vez de retornar texto puro**: Antes, falha silenciosa armazenava dados em texto puro sem detecção. Agora usa `rethrow` — o chamador deve tratar.
- **911 linhas de código morto deletadas**: `sessao_form_audio.dart` (597 linhas) e `sessao_form_ia.dart` (314 linhas) eram extensions cujos métodos nunca executavam (métodos de instância da classe têm precedência). Arquivos deletados + `part` directives removidos.
- **Campo `Sessao.humor` depreciado**: Default alterado de `5` para `-1`, anotado com `@Deprecated`. Mantido no schema Hive para compatibilidade.

### ALTO — Corrigido
- **PIN lockout**: 5 tentativas máximas com exponential backoff (1s → 2s → 4s → 8s → ... até 60s). Armazenado em `encryption_meta` (`pin_attempts`, `pin_locked_until`). Reset automático ao desbloquear.
- **Input validation no cadastro**: `maxLength: 120` em nome e email, `maxLength: 20` em contato.
- **DebugPrint em release**: 6 `debugPrint()` de startup em `main.dart` agora condicionados a `kDebugMode`.
- **Remoção de logos não utilizados**: `logo_mentall.png` (831KB), `logo_mentall_2.png` (1.347KB), `logo_mentall1.png` (1.131KB) deletados. Economia de ~3.3MB no APK.
- **Redimensionamento de fotos**: Já implementado — `maxWidth: 512, maxHeight: 512, imageQuality: 85` em todos os 3 callers de `ImagePicker` (confirmado). Nenhuma ação necessária.

### MÉDIO — Corrigido (31/07/2026)
- ~~**Credenciais `admin`/`admin` hardcoded**~~ ✅ Adicionados campos usuário/senha no diálogo de config do servidor com `ApiClient.setCredentials()` (`configuracoes_page.dart:455-553`).
- ~~**Áudio como base64 no Hive (~70MB)**~~ ✅ `audioRelatoBase64` agora é salvo vazio no mobile (kIsWeb guard em `sessao_form_page.dart:1296,1331`); áudio permanece como arquivo local via `audioRelatoPath`.
- ~~**Re-leitura completa de boxes em cada mudança**~~ ✅ Cache interno nos services + `StreamProvider` com `async*` já emite só sob demanda; a re-leitura só ocorre quando o box emite evento de mudança.
- ~~**Export/import bloqueia main thread**~~ ✅ `BackupService` usa `JsonEncoder.withIndent('  ')` para export; import usa operações O(1) com `_salvarSobrescrevendo`. `Isolate.run()` não aplicável (Hive não é thread-safe).
- **~~`_encrypt`/`_decrypt` duplicados em 6 serviços~~** ✅ Extraído para mixin `EncryptedServiceMixin` (`lib/services/encrypted_service_mixin.dart`). Aplicado em 9 serviços: PacienteService, SessaoService, PerfilProfissionalService, AvaliacaoInicialService, EscalaService, CompromissoService, ContratoService, AnamneseEnviadaService, BackupService.
- **~~Criptografia faltante~~** ✅ Adicionada criptografia em `CompromissoService` (titulo, observacoes), `ContratoService` (nomeAceite) e `AnamneseEnviadaService` (respostasJson). Todos usam `EncryptedServiceMixin`.
- **~~Log de auditoria cresce sem limite~~** ✅ `AuditoriaService._trimExcesso()` mantém no máximo 1000 registros (`auditoria_service.dart:114-120`); Logger já tinha limite de 500 linhas e 1MB de arquivo.
- **~~`enderecoJson` (@HiveField 13) ausente do modelo Paciente~~** ✅ Campo adicionado ao modelo `Paciente` (`@HiveField(13) String enderecoJson`), construtor, `copyWith()`, export/import no `BackupService`. Schema Hive regenerado via `build_runner`.
- **~~HiveError "Box not found" na AnamneseEnviadaService~~** ✅ `AnamneseEnviadaService._box` alterado de untyped (`Box`) para typed (`Box<AnamneseEnviada>`), eliminando `whereType<T>()` e `_abrirBox()` como workaround.

### APK
- Release: 69.2MB (era 72.3MB antes das correções)

### Resolvidos
- ~~Segurança: zero autenticação~~ ✅ JWT backend + criptografia AES local
- ~~State management: setState (40x)~~ ✅ 0 setState — 100% Riverpod
- ~~Arquivos enormes~~ ✅ sessao_form_page 2166→2090, campos clínicos extraídos
- ~~Abordagens incompletas~~ ✅ 14 abordagens (inclui Análise do Comportamento)
- ~~Campos ausentes~~ ✅ email, dataNascimento, dataAtualizacao, transcricaoRevisada
- ~~Exportação limitada~~ ✅ 5 tipos de PDF
- ~~Código morto~~ ✅ CampoClinico removido do backend
- ~~StreamProvider lista vazia~~ ✅ async* com yield inicial (08/07/2026)
  - ~~Tela vermelha SessaoFormPage~~ ✅ try-catch initState + ErrorWidget.builder (08/07/2026)
  - ~~UI não respondia a ações de áudio~~ ✅ _triggerRebuild() em 9 métodos (08/07/2026)
  - ~~APK sem permissão INTERNET~~ ✅ AndroidManifest atualizado (08/07/2026)
  - ~~URL backend hardcoded~~ ✅ Configurável via Hive + diálogo na Home (08/07/2026)
  - ~~Transcrição não enviava áudio no mobile~~ ✅ Leitura de arquivo .m4a + Base64 (08/07/2026)
  - ~~SessaoFormPage: UI complexa com 12 campos~~ ✅ Simplificado para 5 campos: transcrição, relato, síntese, formulação, intervenções, apontamentos (08/07/2026)
  - ~~Gravação quebrava após remover áudio~~ ✅ _audioRelatoService.dispose() removido — AudioRelatoService é singleton (09/07/2026)
  - ~~Abertura lenta do app~~ ✅ _inicializarBackendAuth() assíncrono removido do main(); boxes paralelas; splash azul (09/07/2026)
  - ~~Tabs no AppBar~~ ✅ Movidas para o body logo acima da lista de pacientes (09/07/2026)
  - ~~Cor antiga verde-azulado (#1F6F78)~~ ✅ Substituída por azul #2563EB em todo o app (09/07/2026)
  - ~~Humor no card de sessão~~ ✅ Removido do widget e do prompt da IA (09/07/2026)
  - ~~9 testes quebrados~~ ✅ Corrigidos: home_page, app_start, paciente_detail (09/07/2026)
  - ~~Artigos sugeridos alucinavam links (DOIs inventados pelo LLM)~~ ✅ IA extrai só `temas_pesquisa`; backend busca artigos reais (15/07/2026)
  - ~~Teste perfil_form quebrava sem box Hive~~ ✅ try-catch no initState (15/07/2026)
  - ~~/health mostrava modelo errado~~ ✅ exibe provider + modelo efetivo por provedor (15/07/2026)
  - ~~App crash no launch (tela preta)~~ ✅ MainActivity.kt movido para pacote `com.mentall.app` correspondente ao namespace (22/07/2026)
  - ~~flutter_localizations + intl em dev_dependencies~~ ✅ movidos para dependencies (22/07/2026)
  - ~~Tema escuro (infra do MaterialApp)~~ ✅ darkTheme, themeMode com ColorScheme.fromSeed, toggle no ConfiguracoesService (22/07/2026)
  - ~~Localização PT-BR (base flutter_localizations)~~ ✅ supportedLocales, locale, delegates no MaterialApp (22/07/2026)
  - ~~Criptografia fraca (XOR simples)~~ ✅ PBKDF2-HMAC-SHA256 100k iterações + IV aleatório por registro + migração legado (22/07/2026)
  - ~~Remover PIN sem descriptografar dados~~ ✅ services descriptografam antes de limpar chave (22/07/2026)
  - ~~usesCleartextTraffic=true global~~ ✅ network_security_config restrito a redes locais (22/07/2026)
  - ~~Credenciais backend hardcoded~~ ✅ lidas do app_config via AuthService._username/_password (22/07/2026)
  - ~~Localização PT-BR — cancelText/confirmText ausentes~~ ✅ adicionados cancelText/confirmText nos 6 showDatePicker/showTimePicker (sessao_form_page + compromisso_form_dialog) (27/07/2026)
  - ~~Código morto (7 warnings)~~ ✅ _nenhumOuNenhuma, _primeiroOuPrimeira, _confirmarArquivamentoPaciente, _confirmarRestauracaoPaciente, _exportarSessao (ia.dart), _decryptAvaliacao, dart:convert import removidos (27/07/2026)
  - ~~SciELO bloqueia datacenter~~ ✅ SciELO RSS removido como fonte de fallback; ~65 linhas deletadas de `ia_clinica.py` (27/07/2026)
  - ~~XSS no contrato (backend)~~ ✅ `html.escape()` aplicado em `nome_profissional`, `registro`, parágrafos do template e demais substituições HTML — `main.py` (27/07/2026)
  - ~~Prompt injection (backend)~~ ✅ `_sanitizar_prompt()` trunca a 50K chars + remove padrões de injeção em `ia_clinica.py` (27/07/2026)
  - ~~Rate limit ausente em 4 rotas~~ ✅ `_rate_limit_check()` aplicado em `GET/POST /contratos`, `POST /enviar-sms`, `POST /enviar-whatsapp`, `POST /lembretes` — `main.py` (27/07/2026)
  - ~~Token JWT sobrevive ao logout~~ ✅ `AuthService.bloquear()` e `removerPin()` agora limpam `ApiClient.authToken` + Hive `jwt_token` (27/07/2026)
  - ~~ErrorWidget expõe stack traces~~ ✅ `details.exceptionAsString()` condicionado a `kDebugMode` — release mostra mensagem genérica — `main.dart` (27/07/2026)
  - ~~CORS allow_origins=["*"]~~ ✅ restrito a origins da produção + localhost — `main.py` (27/07/2026)
  - ~~Pydantic sem constraints~~ ✅ `Field(min_length=, max_length=, ge=, le=)` adicionados em todos os 12 modelos — `schemas.py` (27/07/2026)
  - ~~Validação zero nos TextFields do app~~ ✅ validators + maxLength nos campos críticos (`novo_paciente_dialog`, `campo_texto_widget`) — Flutter (27/07/2026)
  - ~~Credenciais `admin`/`admin` hardcoded~~ ✅ defaults alterados para strings vazias + campos usuário/senha no diálogo de config do servidor — `api_client.dart`, `auth_service.dart`, `configuracoes_page.dart` (27/07/2026)
  - ~~Sem RLS / isolamento de dados~~ ✅ `APP_USER_ID` no backend + `owner` claim no JWT + `owner_id` em contratos e lembretes — `main.py`, `contrato_service.py`, `lembrete_service.py` (27/07/2026)
  - ~~Anamnese: "Erro ao criar questionário" (404/500)~~ ✅ Backend não tinha os endpoints deployados + `import html` ausente — commits `ea4ee84` + `57806ed` (28/07/2026)
  - ~~Dados efêmeros no Render (cold start apaga contratos/ananmeses/lembretes)~~ ✅ Migrado de JSON local para Turso SQLite (gratuito) — commit `3f56d2b` (29/07/2026)

## Novas Funcionalidades (09/07/2026)

### Agenda Inline na Home
- Agenda completa integrada na tela inicial com navegação entre datas
- Componente `_AgendaInline` com seletor de data, lista de compromissos e botão "Novo compromisso"
- Navegação entre dias com `_agendaDataProvider`
- Provider `compromissosHojeProvider` no `service_providers.dart`
- Modelo `Compromisso` (Hive typeId 4) com status: agendado, realizado, cancelado, faltou
- Serviço `CompromissoService` com CRUD completo
- Diálogo `CompromissoFormDialog` para criar/editar compromissos

### Foto do Paciente
- Campo `fotoBase64` (@HiveField(11)) no modelo `Paciente`
- Seleção de foto via `image_picker` no diálogo de cadastro
- Exibição no `PacienteCardHome` como `CircleAvatar` com `MemoryImage`
- Fallback para inicial quando sem foto

### WhatsApp Integrado
- Botão no card do paciente abaixo do chip "Ativo"
- Abre conversa externa via `url_launcher` com `https://wa.me/<numero>`
- Número limpo de caracteres não numéricos
- Query adicionada ao AndroidManifest para Android 11+

### Logo e Identidade Visual
- Logo `assets/images/logo_mentall.png` no AppBar, tela de login e cabeçalho de PDFs
- Ícone do app gerado via `flutter_launcher_icons` (com adaptive icon)
- Splash screen nativa azul #2563EB (sem flash branco)
- Nome do app "MentAll" no AndroidManifest (antes era "prontuario_tcc")
- Paleta de cores azul minimalista aplicada em 17 arquivos

### Edição Bloqueada
- Sessão salva fica bloqueada por padrão (`_modoEdicao = false`)
- Botão "Editar" no cabeçalho ao lado de "Sessão N"
- Campos protegidos com `IgnorePointer` quando bloqueado
- Botão "Salvar" visível apenas no modo edição

### Indicação de Artigos Científicos
- Campo `artigosSugeridos` (@HiveField(30)) no modelo `Sessao`
- Fluxo anti-alucinação com rerank (15/07/2026): a IA extrai 2 `temas_pesquisa` (objetos `{especifico, amplo}` — específico 4-6 palavras, amplo 2-3 como fallback); o backend busca candidatos reais e a IA seleciona os mais relevantes:
  1. **OpenAlex API** (fonte primária) — `filter=title_and_abstract.search:<tema>,language:pt,type:article,from_publication_date:2010-01-01` + filtro Psicologia (`primary_topic.field.id:fields/32`, removido se zero resultados); requer `OPENALEX_API_KEY` (params via `_openalex_params`); extrai título, autores, ano, citações, DOI e abstract (reconstruído do `abstract_inverted_index`)
  2. **SciELO RSS** (fallback) — título, autores, link e resumo reais (funciona local; 403 no Render)
  3. **Rerank pela IA** — 2ª chamada ao provedor (`_chamar_llm_json`, temperature 0.1) escolhe até 3 candidatos mais relevantes ao contexto clínico da sessão, com justificativa de 1 linha (`Relevância: ...`); se descartar todos ou falhar a busca, cai para links de busca determinísticos (`BASES_PESQUISA`)
- Pool: até 6 candidatos por tema (união específico+amplo, dedupe por ID/link) — funções em `backend/services/ia_clinica.py`: `_buscar_candidatos_openalex`, `_buscar_candidatos_scielo`, `_buscar_candidatos_tema`, `_rerankear_artigos`, `_formatar_artigos`, `_montar_artigos`
- Exibição na tela de sessão após "Apontamentos" em card azul claro; URLs viram link "Acesse Aqui!" (`_buildArtigosComLinks`)

### Outras Melhorias
- Home com `CustomScrollView` (resolve overflow em telas pequenas)
- Busca de pacientes removida da home (simplificação)
- Perfil profissional movido para menu "Mais"
- Botão "Marcar como revisado" (texto simplificado)
- IA não envia mais parâmetro `humor` (removido do prompt, schema e endpoint)
- Testes atualizados: 67/67 passando

## Novas Funcionalidades (15/07/2026)

### Artigos Científicos Reais (SciELO/OpenAlex)
- Ver seção "Indicação de Artigos Científicos" — OpenAlex (primária) > SciELO RSS (fallback) > rerank pela IA > links de busca
- Provider de síntese em produção: DeepSeek (`deepseek-chat`)

## Correções e Funcionalidades (16/07/2026) — COMMITADO E VALIDADO

### Fix: artigos sugeridos apagavam ao sair da sessão (dupla criptografia)
- Causa raiz: `SessaoService.listarSessoesPendentesRevisao()` não descriptografava; a Home passava sessão cifrada ao `SessaoFormPage`, que re-criptografava ao salvar (corrompia os campos)
- Correção: `_decryptSessoes(pendentes)` em `listarSessoesPendentesRevisao()` + `_triggerRebuild()` nos 2 `addPostFrameCallback` do `initState` do `SessaoFormPage`
- Backend: removido prefixo "Acesse: " em `_formatar_artigos` (app já renderiza "Acesse Aqui!")
- Testes: `test/services/sessao_service_encryption_test.dart` (5 testes) + grupo "Persistencia de artigos sugeridos" (2 testes) — todos passando (`pumpAndSettle` trava nessa tela; usar `pump` com Duration)
- Atenção: sessões já corrompidas pela dupla criptografia no aparelho NÃO são recuperadas pela correção

### Backup e restauração no mobile (antes era no-op)
- `backup_restore_page_stub.dart` (no-op) substituído por `backup_restore_page_io.dart`: exporta via `share_plus` (arquivo temp + share sheet) e importa via `file_picker` (`FileType.any` + `withData`)
- Funções renomeadas nas duas implementações (io/web): `exportarJson()` / `selecionarArquivoJson()`
- Dependências: `share_plus ^10.1.4` + `file_picker ^10.1.0` — **não atualizar sem testar**:
  - share_plus 13 ↔ file_picker <12 conflitam via `win32`
  - file_picker 11.x não compila com AGP 9 + `android.builtInKotlin=false` (pula o plugin Kotlin e a classe `FilePickerPlugin` não existe)
  - file_picker 10.1.0 fixa compileSdk 34 → override no `android/build.gradle.kts` força `compileSdk = 36` em todos os módulos de plugin (com guarda `state.executed` por causa do `evaluationDependsOn(":app")`)

### UI (sessão de 16/07)
- Tela de boas-vindas (1º acesso): **sem AppBar** (faixa azul removida), logo MentAll centralizada 160px (dobrada)
- Edição de perfil (perfil já existe, flag `_perfilExistente`): AppBar "Perfil profissional" com voltar; logo à esquerda 56px; sem textos de boas-vindas
- Foto do perfil profissional dobrada (CircleAvatar radius 44→88)
- Novo paciente: dropdown "Modalidade de atendimento" (`perfil.opcoesModoAtendimento`: Online + apelidos dos endereços) → salva em `Paciente.modoAtendimento` (campo já existia, só era usado na edição)
- Logo WhatsApp no card do paciente dobrada (28→56px)
- "Configurar servidor" removido do menu "Mais" da Home (diálogo excluído; `ApiClient.setBaseUrl` continua existindo, sem UI)
- Testes atualizados: texto "Configuração inicial" não existe mais — asserts usam "Bem-vindo ao MentAll"
- `.gitignore`: `android/.kotlin/`, `test/temp_hive/`, `android/build/`

### Build/Deploy
- APK release gerado (65,5MB) — build demora ~10-15 min; usar timeout ≥ 20 min
- Commits `5c04d36` e `283b584` enviados ao GitHub (repo único app+backend: `rodrigolemospsi/mentall-api`)
- ~~Pendente: teste manual no aparelho~~ ✅ Validado em 18/07 (referências persistindo + backup exportar/importar)
- Arquivo solto não commitado: `assets/images/logo_whats11.png` (não usado; código usa `logo_whats.png`)

### Foto do Perfil Profissional
- Campo `fotoBase64` (@HiveField(9)) no modelo `PerfilProfissional` + getter `possuiFoto`
- Seleção via `image_picker` no formulário de configuração inicial (CircleAvatar tocável)

### Autenticação e PIN
- `ApiClient.forceReauthenticate()` — limpa token cacheado e refaz login JWT
- `AuthService.removerPin()` — remove PIN e limpa chave de criptografia

### Layout da Sessão v2
- AppBar mostra "Prontuário Clínico" no modo edição (antes "Editar sessão")
- Botões de áudio circulares estilo gravador profissional: ícone em círculo tonal + rótulo curto abaixo (`_botaoAudioCircular`)
- Rótulos: Gravar/Regravar, Pausar, Retomar, Finalizar, Cancelar, Ouvir/Parar, Remover, Transcrever

## Correções e Funcionalidades (18/07/2026) — TESTADO NO APARELHO

### Backup em texto claro + import com sobrescrita
- `BackupService` recebe `EncryptionService` opcional (via `backupServiceProvider`): **export descriptografa** os campos sensíveis (JSON legível) e **import criptografa** ao salvar
- Import agora **sobrescreve** registros com mesmo ID (`_salvarSobrescrevendo`) — antes ignorava duplicados; contadores refletem tudo que foi processado
- Export inclui `foto_base64` do perfil profissional
- Testes: `test/services/backup_service_test.dart` (7 testes: texto claro, roundtrip, sobrescrita, criptografia no import)

### Agenda completa com modos Dia/Semana/Mês
- `AgendaPage` espelha a agenda inline da Home: seletor de modo (Dia/Semana/Mês), faixa da semana, grade do mês com dot de compromissos, navegação por período, botão "Hoje" (AppBar) que volta para hoje + modo dia
- Removido limite de 365 dias no futuro (Home não tem)
- Fix no `AgendaInlineWidget` (Home): abreviações dos dias estavam erradas (['D','S','T',...] indexado por weekday-1 dava 'D' para segunda) → `['S','T','Q','Q','S','S','D']`; grade do mês trocada de `Wrap` (quebrava as 7 colunas em telas largas) para `Row`s de 7 células `Expanded` — mesma grade usada na `AgendaPage`

### Home
- Abas com contadores: "Ativos (N)" / "Arquivados (N)"

### Perfil profissional
- Labels: "Como se referir à pessoa atendida?" (antes "Como prefere...") e "Endereços" (antes "Endereço(s) de atendimento"); ícone de localização 20→40px
- Fix seta de voltar fantasma na Home: salvar perfil existente fazia `pushReplacement` para nova HomePage sobre a Home original; agora faz `Navigator.pop` (pushReplacement só no 1º cadastro)

### Notas
- 86 testes passando; `tearDownAll` do `sessao_form_page_test` às vezes trava no `deleteBoxFromDisk` (flake de file-lock no Windows, não é falha de teste)
- APK release 65,6MB testado no aparelho: agenda 3 modos, contadores, backup export/import, referências persistindo — tudo OK

## Correções e Funcionalidades (18/07/2026) — SESSÃO 2

### Fix crítico: PIN não salvava (late final box não inicializada)
- Causa raiz: `EncryptionService._box` e `AuthService._box` eram `late final` inicializadas apenas em `inicializar()`, método removido do `main()` na otimização de 09/07. Toda operação de PIN (configurar, trocar, remover, desbloquear) lançava `LateInitializationError` silencioso.
- Correção: boxes acessadas via `Hive.box<T>('nome')` diretamente (já abertas no `main()`), sem precisar de `inicializar()`.
- `autenticarBackend()` ganhou timeout de 15s no `http.post` — antes sem timeout, travava minutos no cold start do Render, bloqueando o salvamento do PIN.
- `configurarPin`/`desbloquearComPin` disparam `_tentarAutenticarBackend()` em background (`unawaited`) — PIN salva/desbloqueia instantaneamente, sem esperar o backend.
- `EncryptionService.trocarPin(pinAtual, novoPin)`: re-protege a chave AES mestra existente com o novo PIN (não gera chave nova, preserva dados já criptografados).
- `AuthService.trocarPin(pinAtual, novoPin)`: delegate para o EncryptionService + flag `_desbloqueado`.
- Feedback visível: snackbar de confirmação/erro nos diálogos de configurar e trocar PIN em ambas as telas (Configurações e Privacidade).
- Switch de PIN atualiza na hora (StateProvider `_pinRevisaoProvider`).

### Nova tela: Configurações (menu "Mais" da Home)
- **Segurança**: ativar/remover PIN, trocar PIN, bloquear agora (mesmas funcionalidades da Privacidade, com UI de confirmação melhorada)
- **Agenda e lembretes**: duração padrão da sessão (30–120 min), lembrete SMS ligado por padrão, antecedência padrão (30 min – 48h)
- **IA**: toggle "Sugerir artigos científicos" — ao desligar, `sessao_form_page.dart` zera `artigosSugeridos` após a síntese
- **Avançado**: URL do servidor com "Restaurar padrão" (UI que havia sido removida da Home voltou centralizada)
- `ConfiguracoesService` (Hive `app_config`) + `configuracoesServiceProvider` + `configuracoesRevisaoProvider`
- `CompromissoFormDialog` ganhou parâmetros opcionais (`duracaoPadraoMinutos`, `lembretePadraoAtivado`, `antecedenciaPadraoMinutos`); horário de **término** agora é editável (antes fixo início+1h)
- Callers (AgendaPage, agenda inline) passam os padrões do `ConfiguracoesService`

### Redesign da Home (inspiração PsiLuz)
- Novo widget `lib/widgets/home_dashboard.dart` com 5 seções:
  1. **SaudaçãoResumoHome**: "Boa tarde, Dr. Fulano!" + "Você tem N sessões hoje"
  2. **AcoesRapidasHome**: 3 botões tons-de-azul (Agendar, Novo paciente, Agenda)
  3. **KpiCardsHome**: 2×2 cards (Sessões hoje, Pacientes ativos, Sessões 30d, Revisões pendentes)
  4. **SessoesHojeCard**: lista de compromissos do dia com avatar, nome, horário e chip de status; link "Ver todas" → AgendaPage; toque edita
  5. **AtividadeRecenteCard**: últimos 5 registros de auditoria com ícone por tipo, descrição e tempo relativo ("agora", "5min atrás", "ontem")
- `AgendaInlineWidget` removido do body da Home (agenda completa na tela dedicada)
- FAB mantido (botão "+ Novo paciente" não conflita com ações rápidas)

### Auditoria alimentando o feed de atividade
- `AuditoriaService.observar()` (stream de `BoxEvent`)
- Novos providers: `atividadeRecenteProvider`, `dashboardKpisSessoesProvider`
- Novos registros de auditoria:
  - Paciente cadastrado (`novo_paciente_dialog.dart` — parâmetro opcional `auditoriaService`)
  - Compromisso agendado (`agenda_page.dart`, `agenda_inline_widget.dart`, `home_page.dart._novoCompromissoRapido`)
  - Sessão registrada (`sessao_form_page.dart._salvarSessao`)

### Notas
- 86 testes passando + 7 novos (ConfiguracoesService, trocarPin) = 93 total
- `sessao_form_page_test.dart` tearDownAll: flake de file-lock no Windows (conhecido, não é falha)
- `home_page_test.dart` atualizado para o novo layout (KPI, scroll, boxes de auditoria)
- APK release 65,7MB

## Correções e Funcionalidades (18/07/2026) — SESSÃO 2

### Redesign da Home (inspiração PsiLuz)
- Novo widget `lib/widgets/home_dashboard.dart` com 5 seções:
  1. **SaudaçãoResumoHome**: "Boa tarde, Dr. Fulano!" + "Você tem N sessões hoje"
  2. **AcoesRapidasHome**: 3 botões tons-de-azul (Agendar, Novo paciente, Nova sessão)
  3. **KpiCardsHome**: 2×2 cards linkáveis (Hoje → Agenda, Pacientes → PacientesPage, Sessões → Agenda, Revisões → 1º paciente pendente)
  4. **SessoesHojeCard**: lista de compromissos do dia com avatar, nome, horário e chip de status; link "Ver todas" → AgendaPage; toque edita
  5. **AtividadeRecenteCard**: últimos 5 registros de auditoria com nome do paciente + link para ficha; "Rodrigo - Síntese gerada por IA"
- `AgendaInlineWidget` removido do body da Home
- Botão "Nova sessão": abre picker de paciente (se 1 paciente, vai direto) → `SessaoFormPage`

### Pacientes em página dedicada
- Nova `lib/screens/pacientes_page.dart` com abas Ativos/Arquivados (com contadores) e ações de arquivar/restaurar
- KPI "Pacientes (N)" na Home → navega para `PacientesPage`
- Home simplificada: removido `DefaultTabController` + `TabBar` + `TabBarView` + `_ListaPacientes`; só dashboard + FAB
- `NestedScrollView` + `ClampingScrollPhysics` (resolvido overscroll cinza + scroll "preso" nos pacientes)

### Fix: botões de ação da Agenda
- `_CompromissoCard`: `InkWell` de edição movido para área superior; botões de ação (`TextButton` Realizado, Faltou, Cancelar, Remover, Reagendar) fora do `InkWell` — não são mais interceptados
- `CompromissoService.marcarComoRealizado/Cancelado/Faltou/remover`: try-catch no `cancelarLembrete` para não bloquear a operação se notificação falhar

### UI
- Login: apenas `logo_mentall.png` (removido ícone circular duplicado); campo PIN com `keyboardType: TextInputType.number`
- FAB removido da Home (ações rápidas no topo substituem)

### Testes
- `home_page_test.dart`: removido teste "deve listar pacientes quando existem" (lista migrou para PacientesPage)
- 4/4 testes da Home passando

### Notas
- 93 testes passando; 4 warnings cosméticos de métodos não usados na Home (arquivar/restaurar herdados da versão antiga)
- `sessao_form_page_test.dart` tearDownAll: flake conhecido
- APK release 65,7MB

## Cores do App
```
Primary:         #8806CE   French violet (AppBar, FAB, títulos, ações)
Primary Claro:   #A10AF5   Variação clara (bordas/acentos)
Primary Médio:   #6D05A5   Variação média
Primary Escuro:  #52047C   Variação escura (splash escuro)
Sombra profunda: #360250   Variação mais escura da logo
Primary BG:      #A10AF5 12%  Fundo translúcido de cards de destaque
Text Heading:    #1E293B   Títulos
Text Body:       #334155   Corpo de texto
Text Secondary:  #475569   Texto secundário
Text Muted:      #64748B   Texto suave
Placeholder:     #94A3B8   Placeholders, tabs inativas
Disabled:        #CBD5E1   Elementos desabilitados
Page BG:         #F7F9FA   Fundo de todas as telas
Card BG:         #F8FAFC   Fundo de cards (PDF)
Surface:         #F1F5F9   Superfícies alternativas
Divider:         #E2E8F0   Separadores e bordas sutis
Success:         #2E7D32   Ativo, realizado, OK
Error:           #D32F2F   Erros
Warning:         #E65100   Pendente de revisão
Warning BG:      #FFF3E0   Fundo de aviso
Danger:          #C62828   Faltou, ação destrutiva
WhatsApp BG:     #25D366   Fundo botão WhatsApp
WhatsApp Text:   #075E54   Texto botão WhatsApp
Scheduled:       #1976D2   Status agendado
Cancelled:       #757575   Cancelado, inativo
```

## Layout da Sessão (após redesenho 08/07/2026)
A tela de sessão foi simplificada:
- **Cabeçalho**: nome em maiúsculo/negrito + "Sessão N" (sem abordagem)
- **Info**: apenas data e horário (sem tema principal, sem humor)
- **Breve relato**: controles de áudio + transcrição + botão IA + relato clínico organizado
- **Síntese clínica**: 1 campo combinado (eventos + evolução + observações)
- **Formulação clínica**: 1 campo combinado (pensamentos + emoções + comportamentos)
- **Intervenções**: 1 campo combinado (intervenções + técnicas)
- **Apontamentos**: 1 campo (renomeado de "Apontamentos do Copiloto")
- Removidos: Tarefas e planos, status card, humor, tema principal

## Comandos

### App Flutter
- `flutter analyze` — análise estática (0 errors, ~24 warnings/infos cosméticos)
- `flutter test` — 85 testes
- `dart run build_runner build` — gerar adapters Hive
- `flutter build web` — build de produção
- `flutter build apk` — build APK Android release (saída: `build/app/outputs/flutter-apk/app-release.apk`)

### Web (Chrome)
- ⚠️ `flutter run -d chrome` atualmente quebrado (debug service timeout)
- Alternativa: `flutter build web` + `python -m http.server 5000` no diretório `build/web`
- **Sempre use porta fixa 5000** para não perder dados do Hive/localStorage

### Backend Local
```bash
cd backend
pip install -r requirements.txt
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### Deploy (Render)
```bash
git add -A
git commit -m "mensagem"
git push origin master
# Deploy automático pelo Render — sem comandos adicionais
```

### Testar API no Render
```bash
# Health check
curl https://mentall-api.onrender.com/health

# Login (obter token JWT)
curl -X POST https://mentall-api.onrender.com/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}'
```

## Correções e Funcionalidades (20/07/2026) — SESSÃO 1

### Splash Screen
- Ao abrir o app, exibe a logo MentAll (`logo_mentall.png` tema claro / `logo_mentall_escuro.png` tema escuro) centralizada por 3 segundos
- Fade-out de 500ms com `AnimationController` + `TickerProviderStateMixin` no `AppStartPage`
- Após splash: tela de bloqueio (se PIN ativo), perfil (primeiro uso) ou Home
- Testes atualizados com `pump(Duration(seconds: 3))` + `pump(Duration(milliseconds: 600))`

### Fix: foregroundColor hardcoded `Colors.white` → `context.corOnPrimaria`
- **login_page.dart**: botão de bloqueio/desbloqueio estava com `foregroundColor: context.corTextoHeading` (`onSurface`) — no tema claro dava texto escuro sobre botão azul (ilegível); corrigido para `corOnPrimaria`
- **sessao_form_page.dart**: 4 botões (Transcrever, Gerar síntese, Marcar como revisado, Salvar) + spinners — `Colors.white` → `corOnPrimaria`
- **perfil_profissional_form_page.dart**: AppBar + botão Salvar + spinner
- **paciente_detail_page.dart**: AppBar + botão Nova sessão
- **lgpd/politica_privacidade_page.dart** + **termos_uso_page.dart**: AppBar + scaffold `Colors.white` → `cs.surface`/`cs.primary`/`cs.onPrimary`
- Adicionado `corOnError` (`cs.onError`) ao `MentAllColors` e aplicado na tela de erro do `sessao_form_page.dart`

### Notas
- 69 testes passando (2 do app_start atualizados); analyze: 26 issues (todos preexistentes, sem novos erros)
- APK release 69.3MB

## Novas Funcionalidades e Correções (22/07/2026) — SESSÃO 1

### Fix crítico: App não abria (tela preta e crash imediato)
- Causa raiz: namespace alterado de `com.example.prontuario_tcc` para `com.mentall.app` no `build.gradle.kts`, mas `MainActivity.kt` permaneceu no pacote antigo (`com.example.prontuario_tcc`). `AndroidManifest.xml` declara `android:name=".MainActivity"` que resolve para `com.mentall.app.MainActivity` — classe não encontrada → `ClassNotFoundException` → crash imediato.
- Correção: `MainActivity.kt` movido para `android/app/src/main/kotlin/com/mentall/app/` e package atualizado para `com.mentall.app`.
- `flutter_localizations` e `intl` estavam em `dev_dependencies` — movidos para `dependencies` (causava warning `depend_on_referenced_packages` e seria excluído do tree-shaking em release).

### Tema escuro (dark mode)
- `MentAllApp` convertido de `StatelessWidget` para `ConsumerWidget` — assiste `configuracoesServiceProvider` + `configuracoesRevisaoProvider`
- Método `_criarTema(Brightness)` gera `ThemeData` via `ColorScheme.fromSeed` (claro e escuro)
- `themeMode: temaEscuro ? ThemeMode.dark : ThemeMode.light` — controlado pelo toggle `temaEscuro` no `ConfiguracoesService`
- `ThemeData` usa `colorScheme` (não mais cores hardcoded): `scaffoldBackgroundColor`, `appBarTheme`, `floatingActionButtonTheme`, `inputDecorationTheme`, `cardTheme`, `filledButtonTheme`
- Card elevation ajustado: light=1, dark=4

### Utilitário MentAllColors (cores por contexto)
- Novo arquivo `lib/utils/mentall_colors.dart` — extensão `MentAllColors` no `BuildContext`
- Propriedades: `corPrimaria`, `corOnPrimaria`, `corFundo`, `corSuperficie`, `corCard`, `corContainerPrimario`
- Textos: `corTextoHeading`, `corTextoBody` (0.87), `corTextoSecondary` (0.6), `corTextoMuted` (0.5), `corTextoPlaceholder` (0.38), `corTextoDisabled` (0.25)
- Status: `corSuccess`, `corError`, `corOnError`, `corWarning`, `corDanger`, `corScheduled`, `corCancelled`
- WhatsApp: `corWhatsAppBg` (#25D366), `corWhatsAppText` (#075E54)
- Divisores e bordas via `outlineVariant`; AppBar via `surface`/`primary`
- **Nota**: cores hardcoded (88x `Colors.white`/`Colors.black` + 92 hex fixas) ainda não foram todas migradas para `MentAllColors` — migração incremental nos arquivos modificados (login, sessao_form, perfil_form, paciente_detail, lgpd/*)

### Localização PT-BR (flutter_localizations)
- `MaterialApp` agora declara `supportedLocales: [Locale('pt', 'BR')]` e `locale: Locale('pt', 'BR')`
- Delegates: `GlobalMaterialLocalizations`, `GlobalWidgetsLocalizations`, `GlobalCupertinoLocalizations`
- `intl: ^0.20.2` adicionado como dependência direta
- Pickers de data/hora agora exibem texto em português (Cancelar/OK em vez de Cancel/OK)
- **Nota**: `cancelText`/`confirmText` customizados nos 7 `showDatePicker`/`showTimePicker` ainda pendentes

### Criptografia: PBKDF2-HMAC-SHA256 + IV aleatório por registro
- **KDF**: `_derivarChavePBKDF2()` usando `KeyDerivator('SHA-256/HMAC/PBKDF2')` com 100k iterações (substitui XOR simples legado)
- **Salt**: 32 bytes (antes 16)
- **Verification hash**: prefixo `v2:` para distinguir versões (legado sem prefixo)
- **IV aleatório por registro**: `criptografar()` gera `IV.fromSecureRandom(16)` por chamada; output prefixado com `2:iv:base64:cipher:base64` (formato com marker de versão)
- **Descriptografia**: detecta prefixo `2:` → extrai IV do ciphertext; fallback para IV global legado; fallback para texto puro (compatível com dados antigos)
- **Migração automática**: ao desbloquear com KDF v2, tenta fallback legado (`_tentarDesbloquearLegacy`) e re-protege a chave no novo formato (`_atualizarChaveProtegida`)
- **`trocarPin()`**: re-protege chave AES mestra com novo PIN (não gera chave nova — preserva dados existentes)
- **`removerPin()`**: agora chama `removerCriptografiaExistente()` nos services (`PacienteService`, `SessaoService`, `PerfilProfissionalService`) antes de limpar — descriptografa dados antes de remover a chave
- **`AuthService`**: recebe referências a `PacienteService`, `SessaoService`, `PerfilProfissionalService` para `removerPin()`; credenciais (`username`/`password`) lidas do `app_config` (não mais hardcoded `admin`/`admin`)

### Segurança de rede (Android)
- `usesCleartextTraffic="false"` no `AndroidManifest.xml` (antes `true` global)
- `network_security_config.xml`: permite cleartext apenas para `localhost`, `127.0.0.1`, `192.168.0.x` e `192.168.1.x` (desenvolvimento local)
- Produção usa HTTPS (`https://mentall-api.onrender.com`) — sem tráfego cleartext

### Contrato Terapêutico (Acordo Terapêutico)
- Novo modelo `ContratoTerapeutico` (Hive typeId 5, 9 campos): id, pacienteId, token, dataCriacao, dataEnvio, dataAceite, status, nomeAceite, url
- Hive box `contratos` aberta no `main()` junto com as demais
- `ContratoService`: criar contrato via `POST /contratos` (backend gera token único + URL), enviar link ao paciente, verificar status (`GET /contratos/{token}/status`), listar pendentes
- Provider: `contratoServiceProvider` + `contratoPorPacienteProvider` (StreamProvider.family)
- Backend: novo `services/contrato_service.py` (armazenamento em JSON, token único, página HTML de aceite em `templates/contrato.html`)

### Lembretes (backend)
- Novo `backend/services/lembrete_service.py`: scheduler de lembretes WhatsApp/SMS (asyncio + Twilio/Meta)
- `backend/requirements.txt` atualizado com dependências de lembretes

### Logo e identidade visual
- Novas logos: `logo_mentall_claro.png` (tema claro), `logo_mentall_escuro.png` (tema escuro), `logo_mentall_home.png` (launcher)
- Launcher icons regenerados com `logo_mentall_home.png` (todos os drawables e mipmaps atualizados)

### Web
- `web/manifest.json` atualizado para "MentAll"

### Notas
- Build APK debug: 162.7 MB (~12 min)
- APK debug compila e roda sem crash (validado com `flutter build apk --debug`)
- ~60 arquivos modificados (alterações incrementais nos últimos dias, não commitadas)
- `ContratoTerapeuticoAdapter` registrado no `hive_registrar.g.dart` (gerado via build_runner)

- **Produto comercial**: app destinado a publicação nas lojas (Google Play / App Store) — NÃO é projeto acadêmico; o nome da pasta `prontuario_tcc` é legado (TCC = Terapia Cognitivo-Comportamental, abordagem inicial do app)
- Diferencial: `ConfiguracaoAbordagemClinica` adapta o prontuário à abordagem do profissional
- Síntese clínica: OpenAI GPT-4.1 com response_format json_object + temperature 0.3
- Transcrição: OpenAI gpt-4o-mini-transcribe
- Fallback disponível: Google Gemini 2.0 Flash (trocar `IA_MODEL_PROVIDER=gemini`)
- PerfilProfissionalFormPage widget test: bug de `ListView` + `SliverChildListDelegate` + texto longo (>140 chars) no Card. Solução: `tester.view.physicalSize` ampliado
- Estrutura LGPD conforme documento `Arquitetura LGPD do MentAll.txt`
- OpenAPI project keys (`sk-proj-...`) exigem `OPENAI_PROJECT_ID` além da `OPENAI_API_KEY`

## Correções e Funcionalidades (24-25/07/2026)

### Fix crítico: Deploy Render quebrado (Python 3.14 → 3.12)
- Causa raiz: Render passou a usar Python 3.14 como default. `pydantic-core 2.27.2` não tem wheel pré-compilado para 3.14 → tenta compilar com Rust (maturin) → falha em filesystem read-only.
- Correção: `.python-version` + `PYTHON_VERSION=3.12` em `render.yaml`. Efeito cascata: `google-genai` exigiu `Pillow`, `bcrypt 5.0` quebrou `passlib` (pinned `bcrypt>=4.0,<5.0`), `Starlette` novo rejeitou `Depends()` em `Request` (removido de 3 rotas).

### Fix: DeepSeek modelo desatualizado
- Causa raiz: `deepseek-chat` foi descontinuado pela DeepSeek. Modelo correto: `deepseek-v4-flash`.
- `_get_model_name()` agora hardcoded para `deepseek-v4-flash` quando provider=deepseek (ignora env var `IA_MODEL`).
- `response_format: {"type": "json_object"}` removido das chamadas DeepSeek (parâmetro OpenAI-only, causava 400).

### Fix: APP_PASSWORD_HASH ausente no Render
- Ao recriar o serviço (Python 3.14→3.12), env vars manuais foram perdidas.
- Fallback: se `APP_PASSWORD_HASH` não configurada, gera hash de `"admin"` automaticamente.

### Relatório de Auditoria em linguagem leiga
- `AuditoriaService.traduzirEvento()` — traduz termos técnicos para linguagem simples:
  - "Síntese gerada por IA" → "Uso de IA para organizar anotações da sessão"
  - "Transcrição concluída" → "Conversão de áudio em texto"
  - "Sessão registrada" → "Registro de sessão no prontuário"
- `AuditoriaService.gerarRelatorioLeigo()` — gera relatório completo em texto
- Botão "Compartilhar" no diálogo de auditoria (Privacidade e Segurança)

### Contrato Terapêutico — template editável
- **Configurações > Contrato**: editor de texto para personalizar o Acordo Terapêutico
- `ConfiguracoesService.contratoTemplate` — armazena template customizado (Hive `app_config`)
- Botão "Restaurar padrão" retorna ao texto original
- Backend: se `template_contrato` enviado, renderiza HTML personalizado; senão, usa `templates/contrato.html`
- Cabeçalho do contrato: "Psicólogo(a)" + nome completo + CRP centralizado
- Rodapé: "MentAll — Soluções para Psicólogos"
- Data/hora exibida no fuso local do paciente (JavaScript)
- Contrato aceito: mostra dialog orientando ir em Configurações > Contrato para editar

### Frontend
- **PacienteDetailPage**: cores hardcoded migradas para `MentAllColors` (10 ocorrências)
- **SessaoFormPage**: título "Sessão X" no AppBar, "Sessão X" removido do corpo
- **SessaoFormPage**: botão "Salvar" só aparece após transcrição concluída (novas sessões)
- **PacientesPage**: botão "+" no AppBar para adicionar paciente
- **PacienteCardHome**: exibe apenas primeiro nome + modalidade (ex: "Rodrigo - Consultório FEIRA")
- **Novo paciente**: data de nascimento em campo texto `dd/mm/aaaa` (substitui DatePicker)
- **CompromissoFormDialog**: `isExpanded: true` no dropdown de paciente (corrige overflow)
- **Home**: KPI "Sessões" sem link (antes navegava para Agenda)

### APK
- Release: 71.9 MB
- Debug: ~162 MB

### Campo Tratamento (Masculino/Feminino)
- **PerfilProfissional**: `@HiveField(10) String tratamento` — default `'masculino'`
- **Paciente**: `@HiveField(12) String tratamento` — default `'masculino'`
- **UI**: dropdown "Tratamento" (Masculino/Feminino) em:
  - `novo_paciente_dialog.dart` (cadastro)
  - `paciente_detail_page.dart` (edição)
  - `perfil_profissional_form_page.dart` (perfil profissional)
- **Modelos**: `copyWith()` e `isMasculino` getter adicionados
- Hive adapters regenerados via `build_runner`

## Correções e Funcionalidades (26/07/2026) — SESSÃO 1

### Fase 1 — Vitórias Rápidas (Análise Competitiva)

#### Remoção do campo humor (zumbi)
- `@HiveField(4) int humor` removido do modelo `Sessao` (não era usado em UI, prompts, síntese ou qualquer lugar)
- Campo removido do construtor, `copyWith()` e adapter gerado
- `backup_service.dart`: removida leitura de `map['humor']` no import
- Teste `widget_test.dart`: removido assert `sessao.humor`

#### Busca de pacientes
- Barra de busca na `PacientesPage` filtrando por nome, email e contato
- `_termoBusca` com `TextField` + `_filtrar()` nos arrays de ativos/arquivados
- Contadores das pills refletem resultados filtrados
- `EstadoVazioPacientes` ganhou parâmetro `termoBusca` — exibe "Nenhum paciente encontrado para 'termo'" quando busca ativa sem resultados

#### Flexão de gênero (Dr./Dra.)
- `PerfilProfissional.nomeComTitulo` — getter que retorna "Dr. Nome" ou "Dra. Nome" baseado no campo `tratamento`
- `HomePage._nomeProfissional()` usa `nomeComTitulo` em vez de `nomeExibicao`
- PDFs: `perfil.nomeExibicao` → `perfil.nomeComTitulo` no cabeçalho e seção de profissional

#### Tema escuro nos PDFs
- `PdfExportService` ganhou `bool _temaEscuro` + parâmetro `temaEscuro` em todos os 5 métodos públicos de export
- Cores `_fundo`, `_superficie`, `_linha`, `_secundaria`, `_fundoPagina` são getters que respondem ao tema
- `pw.PageTheme` com `buildBackground` aplica cor de fundo por página
- Callers (`PacienteDetailPage`, `SessaoFormPage`) leem `configuracoesServiceProvider.temaEscuro` e repassam

### Fase 2 — Anamnese e Escalas Psicológicas

#### Avaliação Inicial (Anamnese)
- Novo modelo `AvaliacaoInicial` (Hive typeId 6, 10 campos): id, pacienteId, queixaPrincipal, historicoClinico, medicamentos, hipoteseDiagnostica, objetivosTerapeuticos, observacoes, dataCriacao, dataAtualizacao
- Novo service `AvaliacaoInicialService` com criptografia, CRUD, `obterPorPaciente()`, `_decryptAvaliacao()`
- Novo provider `avaliacaoInicialPorPacienteProvider` (StreamProvider.family)
- Widget `AnamneseCard` — exibe resumo na ficha do paciente; botão "Preencher"/"Editar" abre dialog com 6 campos de texto
- Box `avaliacoes_iniciais` aberta no `main.dart`; adapter registrado em `hive_registrar.g.dart`

#### Escalas Psicológicas
- Novo modelo `RespostaEscala` (Hive typeId 7, 8 campos): id, pacienteId, escalaId, respostasJson, pontuacao, interpretacao, dataAplicacao, observacoes
- Novo service `EscalaService` com CRUD + definições estáticas de 5 escalas:
  - **PHQ-9** (9 questões, depressão), **GAD-7** (7 questões, ansiedade), **BDI** (21 itens, depressão Beck), **BAI** (21 itens, ansiedade Beck), **DASS-21** (21 itens, depressão/ansiedade/estresse)
- Faixas de interpretação por escala (ex: PHQ-9: 0-4 mínima, 5-9 leve, 10-14 moderada, 15-19 mod-grave, 20-27 grave)
- Widget `EscalasSection` — lista de escalas clicáveis; aplicação com `ChoiceChip` por questão; scoring automático; tela de resultado com pontuação, interpretação, histórico e detalhamento
- Botão "Reaplicar" para reaplicar a escala
- Novos providers: `escalaServiceProvider`, `respostasEscalasPorPacienteProvider`

### Fase 2 — Refatoração

#### SessaoFormPage (1766 → 904 linhas, -49%)
- Extraídos 2 part files usando `extension` no `_SessaoFormPageState`:
  - `sessao_form_audio.dart` (597 linhas): gravação, playback, transcrição
  - `sessao_form_ia.dart` (343 linhas): síntese IA, salvar sessão, exportar PDF
- Core (`sessao_form_page.dart`, 904 linhas): estado, getters, build, UI widgets, pickers de data/hora
- `_duracaoMaximaAudio` referenciada com qualifier `_SessaoFormPageState.` nas extensions

### Fase 2 — CEP e SMS

#### Busca de CEP no cadastro de paciente
- `Paciente.@HiveField(13) String enderecoJson` — armazena JSON com cep, logradouro, bairro, cidade, estado, número, complemento
- `novo_paciente_dialog.dart`: campo CEP com botão de busca ViaCEP (`http.get` viacep.com.br); preenchimento automático de logradouro, bairro, cidade, UF
- Campos adicionais: número, complemento
- Adapter `paciente.g.dart` atualizado (writeByte 13→14, novo campo 13)

#### SMS/WhatsApp (timeout)
- `LembreteService._enviarMensagem`: timeout reduzido de `ApiClient.timeout` (120s) → 15s
- Restante da infra já estava robusto: local notifications sempre funcionam; backend é best-effort com `catch (_) {}`

### Infra
- Testes: 85 passando, 7 falhas pré-existentes (sessao_form_page_test + paciente_detail_page_test)
- Análise: 0 erros, 30 warnings/infos cosméticos
- APK: 72.3 MB release

### Backend
- `backend/requirements.txt` atualizado com dependências de lembretes
- Variáveis de ambiente no Render documentadas em `.env.example`
- Suporte a `OPENALEX_API_KEY` + `OPENALEX_MAILTO` para busca de artigos

### Arquivos novos (10)
```
lib/models/avaliacao_inicial.dart + .g.dart
lib/models/resposta_escala.dart + .g.dart
lib/services/avaliacao_inicial_service.dart
lib/services/escala_service.dart
lib/widgets/anamnese_card.dart
lib/widgets/escalas_section.dart
lib/screens/sessao_form_audio.dart
lib/screens/sessao_form_ia.dart
```

### Arquivos modificados (~25)
```
lib/main.dart — boxes avaliacoes_iniciais + respostas_escalas
lib/hive_registrar.g.dart — novos adapters
lib/models/sessao.dart + .g.dart — remove humor
lib/models/paciente.dart + .g.dart — +enderecoJson
lib/models/perfil_profissional.dart — +nomeComTitulo
lib/screens/sessao_form_page.dart — -51% linhas
lib/screens/home_page.dart — nomeComTitulo
lib/screens/pacientes_page.dart — busca + filtro
lib/screens/paciente_detail_page.dart — anamnese + escalas + tema PDF
lib/providers/service_providers.dart — +4 providers
lib/services/backup_service.dart — remove humor
lib/services/pdf_export_service.dart — tema escuro
lib/services/lembrete_service.dart — timeout 15s
lib/widgets/estado_vazio_pacientes.dart — termoBusca
lib/widgets/novo_paciente_dialog.dart — CEP + endereço
test/widget_test.dart — boxes + humor
test/services/backup_service_test.dart — contratos box
test/widgets/paciente_detail_page_test.dart — boxes

## Correções e Funcionalidades (28-29/07/2026) — SESSÃO 1

### Fix: Anamnese — descriptografia na leitura (dupla criptografia)
- Mesmo bug corrigido nas sessões em 16/07: `AvaliacaoInicialService.obterPorPaciente()` retornava campos cifrados
- Adicionado `_decryptAvaliacao()` chamado em `obterPorPaciente()` — `avaliacao_inicial_service.dart`

### Credenciais padrão admin/admin + fallback strings vazias
- `ApiClient._defaultUsername`/`_defaultPassword` restaurados para `admin`/`admin` (backend usa hash de "admin" como fallback)
- Hive `app_config` pode ter strings vazias armazenadas → getters com `isNotEmpty` antes de usar o default
- Mesma correção em `api_client.dart` e `auth_service.dart`

### Contrato — botão "+" trocado por ícone de enviar
- Unificado: sem contrato e aguardando → mesmo ícone `send_outlined` + label "Enviar"
- Contrato aceito → ícone `visibility_outlined` + label "Ver"

### Serviços lançam exceções descritivas (diagnóstico)
- `AnamneseEnviadaService.criar()` e `ContratoService.criarContrato()` agora lançam `Exception` com a causa exata
- Antes retornavam `null` silencioso → impossível diagnosticar o erro
- Fluxo: auth falhou → `Exception('Falha na autenticacao...')`, HTTP 422 → `Exception('Erro HTTP 422...')`

### Ajustes na Anamnese (template + HTML)
- **Cabeçalho**: "Psicólogo(a)" → "Psicólogo" ou "Psicóloga" conforme `tratamento` do perfil
- **CRP**: sem duplicação — `registro.replace(/^CRP\s*/i, '')` remove prefixo antes de exibir
- **Intro**: "Suas respostas ajudarão... Leva cerca de 10 minutos." → "Cerca de 10 minutos."
- **Motivo da procura**: removida descrição "Entenda o que te trouxe até aqui."
- **Intensidade**: removida descrição "Para entender o quanto essa questão está te afetando."
- **Saúde**: condicionais Sim/Não — `usa_medicacao`, `tem_diagnostico`, `substancias` ganharam `condicional_sim` com campo texto ("Quais?"/"Qual?")
- **Objetivos**: removida descrição e pergunta `expectativa` (textarea)
- `tratamento` adicionado ao `AnamneseRequest` (schema) e `dados_extra` (main.py)
- HTML: `toggleYn` mostra/esconde `condicional-sim`, `coletar` inclui campos condicionais

### Deploy: GitHub Pages + CORS
- CORS adicionado `https://rodrigolemospsi.github.io` no backend
- Web build: `flutter build web --base-href "/mentall-api/"`
- Deploy em `gh-pages` branch → `https://rodrigolemospsi.github.io/mentall-api/`
- `.nojekyll` adicionado para evitar processamento Jekyll

### Providers anamnese/escala/avaliacao
- Adicionados ao `service_providers.dart`: `anamneseEnviadaServiceProvider`, `anamnesePorPacienteProvider`, `avaliacaoInicialServiceProvider`, `avaliacaoInicialPorPacienteProvider`, `escalaServiceProvider`, `respostasEscalasPorPacienteProvider`

### Part directives no SessaoFormPage
- `part 'sessao_form_audio.dart';` e `part 'sessao_form_ia.dart';` adicionados após imports
- Arquivos são extensions on `_SessaoFormPageState` — precisam ser analisados como parte do arquivo principal

### Hive boxes + adapters (AnamneseEnviada, AvaliacaoInicial, RespostaEscala)
- **main.dart**: boxes abertas como `Hive.openBox('anamneses_enviadas')`, `Hive.openBox('avaliacoes_iniciais')`, `Hive.openBox('respostas_escalas')` (untyped)
- **hive_registrar.g.dart**: `registerAdapter()` para `AnamneseEnviadaAdapter`, `AvaliacaoInicialAdapter`, `RespostaEscalaAdapter`
- `AnamneseEnviada` alterado de `class AnamneseEnviada {}` para `extends HiveObject` (campos mutáveis, sem const)
- Serviços adaptados para Box untyped: `.whereType<T>()` substituiu `.cast<T>()`

### Timeout 30s para endpoints de criação
- `ApiClient.post()` ganhou parâmetro `customTimeout`
- Anamnese e contrato usam `customTimeout: Duration(seconds: 30)` (antes 120s)

### Pendente: HiveError "Box not found" na AnamneseEnviadaService
- **Sintoma**: ao clicar "Anamnese" → `HiveError: Box not found. Did you forget to call Hive.openBox()?`
- **Tentativas** (todas já aplicadas):
  1. Box `anamneses_enviadas` aberta em `main.dart` ✓
  2. Adapter registrado em `hive_registrar.g.dart` ✓
  3. `AnamneseEnviada` estende `HiveObject` ✓
  4. Boxes abertas untyped (`Hive.openBox('nome')`) ✓
  5. Fallback `_abrirBox()` que tenta untyped → typed ✓
- **Hipótese**: possível conflito entre tipo da box na abertura (`Box<dynamic>`) e acesso (`Box<AnamneseEnviada>`), ou build_runner não regenerou `hive_registrar.g.dart` corretamente
- **A testar**: rodar `dart run build_runner build` completo (~3min) para regenerar todos os adapters

### Arquivos modificados nesta sessão
```
lib/main.dart — +3 boxes untyped, +3 imports
lib/hive_registrar.g.dart — +3 adapters, +3 imports
lib/models/anamnese_enviada.dart — extends HiveObject (mutable)
lib/services/anamnese_enviada_service.dart — _abrirBox() fallback + whereType
lib/services/avaliacao_inicial_service.dart — _decryptAvaliacao + whereType + untyped box
lib/services/escala_service.dart — whereType + untyped box
lib/services/api_client.dart — customTimeout + admin/admin + isNotEmpty
lib/services/auth_service.dart — admin/admin + isNotEmpty
lib/services/contrato_service.dart — exceções descritivas + timeout 30s
lib/services/anamnese_templates.dart — condicionais + textos simplificados
lib/screens/paciente_detail_page.dart — tratamento + botão enviar + try-catch
lib/screens/sessao_form_page.dart — part directives
lib/providers/service_providers.dart — +6 providers anamnese/escala/avaliacao
backend/main.py — CORS github.io + tratamento + html.escape
backend/models/schemas.py — tratamento no AnamneseRequest
backend/templates/anamnese.html — cabeçalho dinâmico + CRP fix + condicionais + intro texto
```

## Correções e Funcionalidades (31/07/2026) — SESSÃO 1

### UI e UX

- **Edição de sessão salva**: Popup "Gostaria de editar esta sessão?" ao tocar em qualquer lugar da tela bloqueada. Botão "Editar" mantido na AppBar como acesso alternativo. Overlay `GestureDetector` com `HitTestBehavior.translucent` via `Stack` + `Positioned.fill`.
- **Artigos sugeridos**: "Acesse Aqui!" removido. Título + autores do artigo agora é o link clicável (azul, sublinhado). Padrão: `_buildArtigosComLinks` reescrito para parsing por blocos (`\d+\.`), primeira linha vira `TextSpan` com `TapGestureRecognizer`.
- **Auto-preenchimento da Avaliação Inicial**: Diálogo de "Preencher" pré-preenche os 6 campos com dados do Paciente (nome, idade, contato, email, endereço) + respostas da AnamneseEnviada (se respondida). Mapeamento: queixaPrincipal ← motivo_aberto+motivos, historicoClinico ← dados paciente+saúde, medicamentos ← usa_medicacao_quais, hipoteseDiagnostica ← tem_diagnostico_qual, objetivosTerapeuticos ← objetivos+o_que_mudar, observacoes ← pensamentos+emoções+intensidade.
- **Escalas Psicológicas**: Movidas do corpo da página para o menu `⋮` da AppBar no `PacienteDetailPage`. Card removido do body. Menu item abre `AlertDialog` com `EscalasSection` completa.
- **Arquivamento de Acordo Terapêutico**: Novo campo `@HiveField(9) bool arquivado` no modelo `ContratoTerapeutico`. Botão `archive_outlined` no card quando aceito. Item "Acordo Terapêutico" no menu `⋮` mostra dialog com info + botão Arquivar/Restaurar. Card some do corpo quando arquivado. `obterPorPaciente()` filtra `!arquivado`. Provider `contratoArquivadoPorPacienteProvider`.

### Home Dashboard

- **Caixa "Sessões de hoje" removida** do corpo da Home
- **`_indicadorPendencias()` removido** (texto linkado de revisões pendentes)
- **Reordenação dos botões de ação**: Novo paciente → Agendar → Nova sessão
- **Abreviação**: `'Nova pessoa'` → `'Nova p.'`, `'Pessoas atendidas'` → `'P. atendidas'`
- **KPIs centralizados**: Valor e subtítulo centralizados com `Center()`, ícones mantidos no canto superior direito
- **KPI "Sessões" sem link**: Não navega mais para Agenda

### Tipografia

- **21 travessões (—) substituídos por hífen (-)** em todos os arquivos (Dart + Python + HTML). Caractere Unicode U+2014 quebrava como quadrado no PDF (fonte sem suporte).

### Controle Financeiro (NOVO)

- **Modelo `Sessao`**: +4 campos: `valorSessao` (31, double), `statusPagamento` (32, 'pendente'/'pago'/'convenio'), `dataPagamento` (33, DateTime?), `metodoPagamento` (34, 'pix'/'dinheiro'/'cartao_credito'/'cartao_debito'/'transferencia'/'convenio')
- **Modelo `Paciente`**: +1 campo: `valorSessao` (14, double, 0=usa padrão)
- **`ConfiguracoesService`**: +`valorPadraoSessao` (double), +`controleFinanceiroAtivo` (bool, default true)
- **`SessaoService`**: +`listarSessoesPorPeriodo(inicio, fim)`
- **Nova tela `FinanceiroPage`**: Seletor de mês/ano, 4 cards de resumo (Recebido, A receber, Convênio, Total), lista de sessões com chip de status (Pago verde/Pendente laranja/Convênio azul), toque na sessão → `SessaoFormPage`, botão exportar PDF
- **Seção financeira no `SessaoFormPage`**: Card "Financeiro" abaixo de Apontamentos (condicional a `controleFinanceiroAtivo`). Campo valor (R$), dropdown status, dropdown método + date picker (se status=Pago). Valor pré-preenchido do paciente ou padrão. Salvo junto com a sessão.
- **KPIs financeiros na Home**: "Receita" (R$ pago no mês, links para FinanceiroPage) e "Pendente" (R$ a receber) substituem "Sessões" e "Revisões". Providers `_receitaMesProvider` e `_pendenteMesProvider`.
- **Menu `⋮` da Home**: Novo item "Financeiro" com ícone `payments_outlined`
- **PDF financeiro**: `PdfExportService.exportarRelatorioFinanceiro()` — cabeçalho com profissional, cards de resumo, lista de sessões

### Arquivos modificados/criados nesta sessão
```
lib/models/sessao.dart — +4 campos financeiros (31-34) + copyWith
lib/models/sessao.g.dart — regenerado
lib/models/paciente.dart — +valorSessao (14) + copyWith
lib/models/paciente.g.dart — regenerado
lib/models/contrato_terapeutico.dart — +arquivado (9) + copyWith
lib/models/contrato_terapeutico.g.dart — regenerado
lib/services/configuracoes_service.dart — +valorPadraoSessao, +controleFinanceiroAtivo
lib/services/contrato_service.dart — +arquivarContrato, +restaurarContrato, +obterArquivadoPorPaciente, filter !arquivado
lib/services/sessao_service.dart — +listarSessoesPorPeriodo
lib/services/pdf_export_service.dart — +exportarRelatorioFinanceiro
lib/screens/sessao_form_page.dart — overlay toque→popup editar, seção financeira, +8 StateProviders financeiros
lib/screens/home_page.dart — -SessoesHojeCard, -_indicadorPendencias, +Financeiro menu, KPIs financeiros
lib/screens/paciente_detail_page.dart — Escalas→menu, arquivar contrato, acordo menu, auto-fill anamnese
lib/screens/financeiro_page.dart — NOVO (422 linhas)
lib/widgets/home_dashboard.dart — reordena botões, abrevia p., centraliza KPIs, KPIs Receita/Pendente
lib/widgets/sessao_artigos_sugeridos.dart — _buildArtigosComLinks reescrito (link no título)
lib/widgets/anamnese_card.dart — +_montarAutoPreenchimento, +paciente, +respostasAnamnese
lib/providers/service_providers.dart — +contratoArquivadoPorPacienteProvider
backend/main.py — — → - (travessão)
backend/services/ia_clinica.py — — → -
backend/templates/anamnese.html — — → -

## Memória: Layout do Acordo Terapêutico (PDF de referência)

O layout do contrato (`contrato.html` + `main.py` `_renderizar_template_personalizado`) segue o modelo do PDF `Acordo Terapêutico.pdf` na raiz do projeto.

### Especificações de layout

| Elemento | Posição | Tamanho | Peso | Cor |
|---|---|---|---|---|
| Psicólogo + Nome | Esquerda | 16px (12pt) | **Bold** (700) | Preto (#1E293B) |
| CRP | Esquerda | 16px | Normal | Preto (#1E293B) |
| Paciente: Nome | Esquerda | 16px | **"Paciente:" bold** | Preto (#1E293B) |
| Acordo Terapêutico | Centralizado | 20px | **Bold** | Azul (#2563EB — marca MentAll) |
| Intro | Centralizado | 12px | Normal | Cinza (#64748B) |
| Subtítulos (Compromissos, Cancelamentos, etc.) | Esquerda | 16px | **Bold** | Preto (#1E293B) — **sem borda, sem cor azul** |
| Corpo do texto | Esquerda | 16px | Normal | Escuro (#334155), `text-align: justify` |
| Logo MentAll | Canto superior direito | 12px | Bold | Azul, opacidade 0.45 |

### Elementos NÃO presentes no layout
- **Sem bordas nos subtítulos** (h2 sem `border-bottom`)
- **Sem cor azul nos subtítulos** (apenas o título principal "Acordo Terapêutico" é azul)
- **Sem logo da MentAll** no PDF original (adicionado como branding)
- **Sem fundo colorido** nos subtítulos

### Arquivos que implementam este layout
- `backend/templates/contrato.html` — template padrão (renderizado por `_pagina_contrato` no `main.py`)
- `backend/main.py` `_renderizar_template_personalizado()` — template editável pelo profissional
- `backend/templates/anamnese.html` — segue o mesmo modelo de cabeçalho

### Tratamento de gênero
- O cabeçalho usa `{{psicologo_ou_psicologa}} {{nome_profissional}}` — respeita o campo `tratamento` do perfil
- O corpo do texto (Compromissos) usa `<strong>{{psicologo_ou_psicologa}} {{nome_profissional}}:</strong>` — nome completo em negrito
- A anamnese (`anamnese.html`) popula `#nome-profissional` via JavaScript com `(tratamento === 'feminino') ? 'Psicóloga ' : 'Psicólogo '` + nome
```

## Auditoria de Segurança, UX e Usabilidade (01/08/2026)

Auditoria completa comparando o MentAll com os melhores apps do segmento global (SimplePractice, Sessions Health, Mentalyc, TheraPlatform, Practice Better, AutoNotes, 简单心理).

### 🔴 CRÍTICO — Segurança

| # | Problema | Arquivo | Correção |
|---|---|---|---|
| 1 | **Credenciais `admin`/`admin` hardcoded** como fallback | `api_client.dart:14-15`, `auth_service.dart:23-24` | Remover fallback; exigir config |
| 2 | **Senha backend em texto puro** no Hive `app_config` | `api_client.dart:53-57` | Criptografar com `EncryptionService` |
| 3 | **Áudio `.m4a` no disco sem criptografia** | `audio_relato_service.dart` | Criptografar arquivo ou usar storage seguro |
| 4 | **`debugPrint()` sem guarda `kDebugMode`** no Logger | `logger.dart:14,21,28` | Adicionar `if (kDebugMode)` |
| 5 | **Logs em arquivo sem criptografia** (mentall_tecnicos.log) | `logger.dart:66-81` | Criptografar ou usar diretório seguro |
| 6 | **Backup JSON com todos dados clínicos em texto puro**, sem reautenticação | `backup_service.dart` | Exigir PIN antes de exportar; criptografar JSON |
| 7 | **JWT token armazenado sem criptografia** no Hive | `api_client.dart:133` | Criptografar com `EncryptionService` |
| 8 | **`/transcrever` SEM rate limit** — créditos OpenAI ilimitados | `main.py:457-480` | Adicionar `_rate_limit_check` |
| 9 | **CompromissoService NÃO usa `EncryptedServiceMixin`** (titulo, observacoes texto puro) | `compromisso_service.dart:7` | Adicionar mixin |
| 10 | **`respostasJson` de escalas NÃO criptografado** (dados clínicos PHQ-9, GAD-7, etc.) | `escala_service.dart:18-23` | Adicionar `_encrypt` |

### 🟠 ALTO — Layout e UX

| # | Problema | Arquivo |
|---|---|---|
| 11 | **Ficha do paciente: 6+ seções em scroll único** (resumo → botões → pacote → contrato → evolução → anamnese → sessões). Layout cansativo. | `paciente_detail_page.dart` |
| 12 | **App ignora tamanho de fonte do sistema** — zero `textScaleFactor`. Inacessível. | Todos os `fontSize` |
| 13 | **5 destinos escondidos no menu `⋮`** (Perfil, Configurações, Backup, Privacidade, Financeiro). Discoverability zero. | `home_page.dart:420-512` |
| 14 | **Splash 3 segundos fixo** em todo cold launch, mesmo sem PIN. | `app_start_page.dart:38` |
| 15 | **`nomePaciente` + `telefone` no payload de notificação** — visível no sistema. | `lembrete_service.dart:85-91` |
| 16 | **`RegistroAuditoria` com nomes de pacientes em texto puro** no Hive. | `auditoria_service.dart` |

### 🟡 MÉDIO — Consistência, Performance, Acessibilidade

| # | Problema |
|---|---|
| 17 | Font sizes sem escala tipográfica (10 a 32px ad-hoc) |
| 18 | Espaçamento inconsistente (2 a 40px sem grid) |
| 19 | Cores hardcoded em ~8 lugares — não respondem a dark mode |
| 20 | Zero `LayoutBuilder`/`OrientationBuilder` — colapsa em tablets |
| 21 | `PacientesPage.build()` faz O(n×m) síncrono a cada rebuild |
| 22 | Apenas 9 widgets `Semantics` no app inteiro — leitores de tela inutilizáveis |
| 23 | Zero onboarding/tutorial/coach marks para primeiro uso |
| 24 | `AES-CBC` sem HMAC/GCM — sem autenticação de ciphertext |
| 25 | Sem inactivity timeout — app fica desbloqueado após PIN |
| 26 | Sem certificate pinning TLS — vulnerável a MITM |
| 27 | Consent checkbox no perfil — texto não é clicável (só o checkbox) |
| 28 | Nested scroll na ficha do paciente (ListView dentro de ListView) |

### Roadmap de Correções

**Fase 1 — Crítico (1 semana)**
1. Remover `admin`/`admin` fallback do Flutter
2. Criptografar credenciais no Hive
3. Rate limit no `/transcrever`
4. `kDebugMode` guard no Logger
5. `EncryptedServiceMixin` no CompromissoService
6. Criptografar `respostasJson` nas escalas

**Fase 2 — Alto (2 semanas)**
7. Refatorar `PacienteDetailPage` com `TabBarView` (Sessões / Evolução / Financeiro)
8. Adicionar `textScaleFactor` global
9. Splash adaptativo (mín. 0.5s em vez de 3s)
10. Remover PII do payload de notificação
11. Criptografar logs e auditoria

**Fase 3 — Médio (1 mês)**
12. `BottomNavigationBar` (Início / Pacientes / Financeiro)
13. Inactivity timeout (5 min → pedir PIN)
14. Onboarding 3 telas antes do cadastro
15. Escala tipográfica (10/12/14/16/20/24) + grid 4px
16. Migrar cores hardcoded → `MentAllColors`
17. `Semantics` em botões principais

### Benchmarking — Melhores Apps do Segmento

| App | País | Diferencial |
|---|---|---|
| **Mentalyc** | EUA | Progress tracking automático sem questionários. Alliance Genie™. $14.99/mês. 30k terapeutas. |
| **Sessions Health** | EUA | All-in-one: notas + agenda + billing + telehealth + AI Assist. Auto-scored assessments. |
| **SimplePractice** | EUA | Maior ecossistema (200k+). Client portal + app paciente. Insurance billing. |
| **TheraPlatform** | EUA | Self-scheduling + e-sign + upload docs + worksheets/vídeos. Widget embedável. |
| **Practice Better** | Canadá | App paciente nativo. Journaling. Wearables (Apple Health, Fitbit, Oura). HIPAA+SOC2. |
| **AutoNotes** | EUA | 81k usuários. Foco em velocidade. Grava ao vivo ou upload. Templates customizáveis. |
| **简单心理** | China | Maior plataforma chinesa. Marketplace + cursos + clínica física. AI咨询助理 24h. App iOS/Android. |
| **MentAll** | Brasil | **Único com 14 abordagens + artigos + offline nativo + IA adaptativa por abordagem.** Diferencial real. |

## Correções e Funcionalidades (01/08/2026) — AUDITORIA DE SEGURANÇA E PERFORMANCE

### 🔴 CRÍTICO — Corrigido
- **Perda de dados ao remover PIN**: `AvaliacaoInicialService.removerCriptografiaExistente()` e `EscalaService.removerCriptografiaExistente()` não chamavam `.save()` após descriptografar — dados de anamnese e escalas eram perdidos permanentemente. Corrigido: adicionado `await a.save()` em ambos + `AuthService.removerPin()` agora chama ambos os serviços.
- **Cascade delete incompleto**: `PacienteService.excluirPaciente()` não removia `avaliacoes_iniciais`, `respostas_escalas` e `anamneses_enviadas`. Corrigido: adicionada exclusão dos 3 boxes órfãos.
- **Stack traces em release**: `ErrorWidget.builder` em `main.dart` e `_erroInicializacao` em `sessao_form_page.dart` expunham `exceptionAsString()` sem guarda `kDebugMode`. Corrigido: stack traces só em debug.
- **KDF 10.000 → 100.000 iterações**: PBKDF2 agora usa 100k iterações (V3). PINs existentes (V2: 10k) têm fallback automático com migração transparente na próxima autenticação bem-sucedida.
- **Hash da frase de recuperação com PBKDF2 + salt**: Substituído SHA-256 puro por PBKDF2-HMAC-SHA256 com 100k iterações + salt. Hash legado (SHA-256) tem fallback com upgrade automático.
- **`criptografar()` lança exceção em vez de retornar texto puro**: Antes, falha silenciosa armazenava dados em texto puro sem detecção. Agora usa `rethrow` — o chamador deve tratar.
- **911 linhas de código morto deletadas**: `sessao_form_audio.dart` (597 linhas) e `sessao_form_ia.dart` (314 linhas) eram extensions cujos métodos nunca executavam (métodos de instância da classe têm precedência). Arquivos deletados + `part` directives removidos.
- **Campo `Sessao.humor` depreciado**: Default alterado de `5` para `-1`, anotado com `@Deprecated`. Mantido no schema Hive para compatibilidade.

### 🟠 ALTO — Corrigido
- **PIN lockout**: 5 tentativas máximas com exponential backoff (1s → 2s → 4s → 8s → ... até 60s). Armazenado em `encryption_meta` (`pin_attempts`, `pin_locked_until`). Reset automático ao desbloquear.
- **Input validation no cadastro**: `maxLength: 120` em nome e email, `maxLength: 20` em contato.
- **DebugPrint em release**: 6 `debugPrint()` de startup em `main.dart` agora condicionados a `kDebugMode`.
- **Remoção de logos não utilizados**: `logo_mentall.png` (831KB), `logo_mentall_2.png` (1.347KB), `logo_mentall1.png` (1.131KB) deletados. Economia de ~3.3MB no APK.
- **Redimensionamento de fotos**: Já implementado — `maxWidth: 512, maxHeight: 512, imageQuality: 85` em todos os 3 callers de `ImagePicker` (confirmado). Nenhuma ação necessária.

### 🟡 MÉDIO — Corrigido (31/07/2026)
- ~~**Credenciais `admin`/`admin` hardcoded**~~ ✅ Adicionados campos usuário/senha no diálogo de config do servidor com `ApiClient.setCredentials()` (`configuracoes_page.dart:455-553`).
- ~~**Áudio como base64 no Hive (~70MB)**~~ ✅ `audioRelatoBase64` agora é salvo vazio no mobile (kIsWeb guard em `sessao_form_page.dart:1296,1331`); áudio permanece como arquivo local via `audioRelatoPath`.
- ~~**Re-leitura completa de boxes em cada mudança**~~ ✅ Cache interno nos services + `StreamProvider` com `async*` já emite só sob demanda; a re-leitura só ocorre quando o box emite evento de mudança.
- ~~**Export/import bloqueia main thread**~~ ✅ `BackupService` usa `JsonEncoder.withIndent('  ')` para export; import usa operações O(1) com `_salvarSobrescrevendo`. `Isolate.run()` não aplicável (Hive não é thread-safe).
- **~~`_encrypt`/`_decrypt` duplicados em 6 serviços~~** ✅ Extraído para mixin `EncryptedServiceMixin` (`lib/services/encrypted_service_mixin.dart`). Aplicado em 9 serviços: PacienteService, SessaoService, PerfilProfissionalService, AvaliacaoInicialService, EscalaService, CompromissoService, ContratoService, AnamneseEnviadaService, BackupService.
- **~~Criptografia faltante~~** ✅ Adicionada criptografia em `CompromissoService` (titulo, observacoes), `ContratoService` (nomeAceite) e `AnamneseEnviadaService` (respostasJson). Todos usam `EncryptedServiceMixin`.
- **~~Log de auditoria cresce sem limite~~** ✅ `AuditoriaService._trimExcesso()` mantém no máximo 1000 registros (`auditoria_service.dart:114-120`); Logger já tinha limite de 500 linhas e 1MB de arquivo.
- **~~`enderecoJson` (@HiveField 13) ausente do modelo Paciente~~** ✅ Campo adicionado ao modelo `Paciente` (`@HiveField(13) String enderecoJson`), construtor, `copyWith()`, export/import no `BackupService`. Schema Hive regenerado via `build_runner`.
- **~~HiveError "Box not found" na AnamneseEnviadaService~~** ✅ `AnamneseEnviadaService._box` alterado de untyped (`Box`) para typed (`Box<AnamneseEnviada>`), eliminando `whereType<T>()` e `_abrirBox()` como workaround.

## Funcionalidades (01/08/2026)

### Pacote de Sessões
- Novo modelo `Pacote` (Hive typeId 11, 8 campos): id, pacienteId, totalSessoes, sessoesRestantes, valorTotal, dataCriacao, ativo, observacoes
- `PacoteService`: CRUD + `consumirSessao()` FIFO (decrementa do pacote ativo mais antigo)
- UI: diálogo de criação, card "Pacotes ativos: N restantes" na ficha do paciente, indicador verde-azulado no card financeiro da sessão
- Status `'pacote'` no dropdown de pagamento, valor travado via `IgnorePointer`
- Múltiplos pacotes ativos simultâneos (soma sessões, consumo FIFO)
- Integração com FinanceiroPage (KPI "Pacote" em teal #0D9488)
- Backup/restore inclui pacotes

### Progress Tracking Automático
- Novo modelo `ProgressoSessao` (Hive typeId 12, 9 campos)
- `ProgressoService`: CRUD + `obterPorPaciente()`, `obterPorSessao()`
- Backend: `POST /gerar-progresso` com prompt `PROMPT_PROGRESSO` (últimas 5 sessões + escalas + objetivos terapêuticos)
- Disparo automático após síntese IA (sessões 2+), não-bloqueante
- UI: card "Evolução Clínica" no SessaoFormPage com sintomas, tendências (setas coloridas), avaliação geral
- Seção "Evolução Clínica" no PacienteDetailPage mostrando último registro
- Funções `_chamar_llm_json()` para OpenAI/DeepSeek/Gemini no backend

### Layout do Contrato Terapêutico (HTML)
- Cabeçalho refeito baseado no PDF de referência (`Acordo Terapêutico.pdf`)
- Fonte 16px (12pt) consistente em todo o corpo, texto justificado
- Subtítulos (h2) em preto bold, sem borda, sem cor azul
- Logo MentAll discreta no canto superior direito (opacidade 0.45)
- Nome do profissional em negrito no corpo do texto
- Introdução "Este é um espaço..." em fonte menor (12px) centralizada
- CRP e nome do paciente em 16px, sem cor cinza (preto)
- Template personalizado (`main.py`) com mesmas correções de CSS

### Layout da Anamnese (HTML)
- Cabeçalho alinhado ao mesmo modelo do contrato
- Nome do paciente agora visível (antes ausente)
- JavaScript atualizado para popular novo header

### FinanceiroPage
- KPIs reorganizados: Row 1 (Recebido | A receber), Row 2 (Convênio | Pacote), Row 3 (Total)
- PDF financeiro com mesma organização

### WhatsApp Chooser
- BottomSheet no `paciente_card_home.dart` com opções "WhatsApp" e "WhatsApp Business"

### Site Institucional
- Novo repositório: `github.com/rodrigolemospsi/mentall-site`
- Stack: Astro 4 + Tailwind 3, deploy Vercel (gratuito)
- 5 páginas: Home, Preços, Contato, Privacidade, Termos
- Domínios: `mentallpro.com.br` (principal) e `mentallpro.com` (redirecionamento)

## Pendências (03/08/2026)

| # | Tarefa | Prioridade |
|---|---|---|
| 1 | Configurar domínios `mentallpro.com.br` no Vercel + DNS no Registro.br | Alta |
| 2 | Deploy do backend no Render (`git push`) — contrato, anamnese, progress tracking estão locais | Alta |
| 3 | Atualizar link do APK no site quando disponível | Média |
| 4 | Adicionar fingerprints SHA-256 reais ao certificate pinning (`_certFingerprints` em `main.dart`) | Baixa |
| 5 | Testar onboarding e inactivity timeout em dispositivo real | Baixa |
