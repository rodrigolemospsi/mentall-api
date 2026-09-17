Rodrigo, acompanhamento das correcoes autorizadas em 06/09/2026.

**Lote 1**
- [x] Anamnese publica sem retorno de respostas clinicas anteriores (08).
- [x] Cadastro pendente vincula token e credenciais da mesma tentativa (09).
- [x] Anamnese nao preenche respostas clinicas sem interacao (15).
- [x] Backup agendado usa um envelope e importa duplo legado limitado (01).
- [x] Backup falha explicitamente se nao pode cifrar (parte de 07).
- [x] Parsing de todos os modelos, IDs e referencias antes de gravar backup (parte de 04).
- [x] Retirar orientacao destrutiva de erro (16).
- [x] Corrigir URL de progresso (17).
- [x] Corrigir ciclo de vida do player (18).
- [x] Corrigir nascimento parcial/invalido e estado de salvamento (20).
- [x] Revisao independente e verificacao integrada.

**Verificacao Do Lote**
- Flutter: `flutter test --no-pub --reporter expanded`, 200/200 (antes 177; +23).
- Backend: em `backend/`, `.venv/bin/python -B tests/run_isolated.py`, 163/163 (antes 137; +26). Ambiente limpo, dotenv neutralizado, SQLite em memoria e rede bloqueada.
- `flutter analyze --no-pub`: sem erros; warning preexistente `_todosBlocos` em `tools/gerar_prompts_ia_pdf.dart:36`.
- `flutter build web --no-pub`: aprovado. Nao e validacao visual nem deploy.
- `git diff --check`: sem erros de whitespace; avisos de normalizacao CRLF/LF nos arquivos que ja usavam CRLF.
- Teste de salvar sessao agora verifica texto realmente alterado, persistido apos reabrir Hive; tap perdido causa falha (parte de 34).
- Revisao independente: dois problemas de compatibilidade detectados e corrigidos com RED/GREEN. Aceita backup historico `1.0` e preserva progresso gerado antes de salvar sessao. Referencia a sessao conhecida de outro paciente continua rejeitada.

**Limites E Pendencias**
- 04: prevalidacao impede escrita parcial por arquivo malformado, mas nao implementa transacao duravel entre boxes, rollback de falha de disco, controle de escrita concorrente ou recuperacao de crash. Feedback tipado de importacao na UI permanece pendente.
- 07: export/import do backup exigem chave carregada e falha de envelope interrompe export; o restante do fail-closed nos servicos/boot e marcador de durabilidade nao foi alterado.
- 08: eliminada exposicao no POST e cache desabilitado; nao foi criada expiracao automatica nem interface de revogacao de links. Estados revogado/expirado ja sao recusados.
- 18: ownership do player corrigido e testado com fake; audio nativo ainda precisa de teste no aparelho.
- 15: JavaScript executado com DOM simulado via JXA no macOS. Layout, teclado e leitor de tela nao foram validados em navegador.
- 21: progresso antecipado sem sessao salva e um estado legado concreto. Backup preserva esse dado; o ciclo de rascunho/persistencia e as keys de progresso importado continuam pendentes.
- 02/03: recuperacao em outro aparelho, segredo independente e conjuntos ausentes do backup ainda NAO resolvidos. Nao reinstalar nem apagar dados/chaves para testar.
- Politica de biometria, retencao de audio, pacotes, Financeiro, WhatsApp e banco remoto permanecem para os proximos lotes.
- Nenhum commit, deploy, restart, alteracao de secrets, novo APK ou acesso a prontuario real.

**Lote 2 — Entrega + seguranca de acesso (06/09/2026)**
- [x] Navegacao de bloqueio persistente. Novo `lib/widgets/app_lock_gate.dart` vive no `MaterialApp.builder` (acima do Navigator) e observa pausa/inatividade; ao bloquear faz `pushAndRemoveUntil(LoginPage)` limpando TODAS as rotas clinicas (05). Antes o observer/timer vivia no `AppStartPage` e era destruido pela navegacao. Testes novos em `test/widgets/app_lock_gate_test.dart` (pausa limpa rotas, inatividade, sem autenticacao exigida).
- [x] Fail-closed real na persistencia (parte de 07). `EncryptedServiceMixin.encrypt` lanca se ha valor nao vazio sem chave; `decrypt` lanca se ha marcador de cifra sem chave, mas le texto plano legado. Testes em `test/services/encrypted_service_mixin_test.dart`. Testes existentes ajustados para criar chave em memoria (configuracoes, demo_data, widget_test, novo_paciente, sessao_form, backup).
- [x] CI com gates antes do deploy (34). `.github/workflows/deploy.yml` agora tem jobs `flutter-checks` (analyze + test) e `backend-checks` (testes isolados) e o job `deploy` so roda se ambos passarem. `backend/tests/run_isolated.py` isola dotenv/DB/rede.
- [x] Assinatura de release configuravel (35). `android/app/build.gradle.kts` passa a usar keystore de producao via `MENTALL_*` (Gradle properties/env) com fallback debug para dev. Requer keystore do dono para publicar.

**Verificacao Do Lote 2**
- Flutter: `flutter test --no-pub --reporter compact`, 207/207.
- Backend: `backend/`, `.venv/bin/python -B tests/run_isolated.py`, 163/163.
- `flutter analyze --no-pub`: sem erros; warning preexistente `_todosBlocos`.
- `flutter build web --no-pub`: aprovado.
- `git diff --check`: sem erros.
- Revisao independente: gate confirmado acima do Navigator + limpa rotas; CI sem vazamento de secrets; fail-closed nao regride legado. Achado de UX (gate repetia a Splash ao retornar) corrigido usando `LoginPage` como tela de bloqueio padrao.

**Pendencias Do Lote 2**
- Publicacao: gerar keystore (de producao), informar `MENTALL_KEYSTORE_FILE/PASSWORD/ALIAS/PASSWORD` e validar build/com assinatura reais. O build release com fallback debug nao foi exercitado com keystore.
- Lockout biologico/`unknownError` como "indisponibilidade" (06): continua como decisao de produto anterior (fail-safe), nao alterada neste lote. Reavaliar antes de publicar multi-aparelho.
- Demais itens da auditoria seguem abertos.

**Lote 3 — Fluxos clinicos/financeiros + isolamento (06/09/2026)**
- [x] Pacote nao debita ao editar (14). Regra pura `PacoteService.deveConsumirAoSalvar` (`!editando && statusPacote`) usada na tela; so consome ao criar sessao nova por pacote. Testes em `test/services/pacote_regra_test.dart`.
- [x] Financeiro reativo (19). Novo `sessoesFinanceiroPorMesProvider` (StreamProvider.family + `observarSessoes`); a tela agora recomputa ao editar/arquivar/incluir sessao, sem remover a exportacao. `_sessoesDoMes` nao-reativo removido.
- [x] Cache de audio purgado no bloqueio (parte de 12). `AudioRelatoService.limparCacheAudio()` chamado em `AuthService.bloquear()`, removendo audio clinico em claro da memoria. Teste em `test/services/audio_cache_test.dart`. O temporario de playback e o cumprimento de "nao manter" permanecem.
- [x] WhatsApp por profissional com isolamento (10). `_resolver_token_wuzapi` passa a priorizar a instancia do owner; a env global so vale em caminhos dev sem owner. Owner real sem instancia NAO usa token de outro (fail-closed). Testes em `backend/tests/test_grupo2_whatsapp_contrato.py`.
- [x] Aceite de contrato sem sobrescrita concorrente (22). `registrar_aceite` usa UPDATE condicionado (`WHERE status='pendente'`) e re-leu; corrida nao sobrescreve nome. Mesmo padrao da anamnese. Testes no mesmo arquivo.

**Verificacao Do Lote 3**
- Flutter: `flutter test --no-pub --reporter compact`, 212/212.
- Backend: `backend/`, `.venv/bin/python -B tests/run_isolated.py`, 171/171.
- `flutter analyze --no-pub`: sem erros; warning preexistente `_todosBlocos`.
- `git diff --check`: sem erros.
- Revisao independente: pacote/Financeiro/cache/aceite OK; achado de isolamento do WhatsApp PRIMEIRO achado (owner sem instancia usar token global) e linha colada por merge em `sessao_form_page.dart` — ambos corrigidos.

**Pendencias Do Lote 3**
- 12: temporario `.m4a` claro de playback e exclusao fisica ao "nao manter" ainda pendentes (exigem plataforma + integracao com o modelo da sessao).
- 22: concorrencia validada em SQLite em memoria; comportamento no transporte remoto (libsql/Turso) e transacoes multiplas caixas ainda nao cobertos.
- 23: envio ainda serializado sob o lock (lote limitado + cancelamento verificado, mas nao movido para fora do lock durante o I/O). Requer conexao de DB por transacao/thread para liberar o lock no envio.
- 24 (retries multiplicados), 21 (races do editor), 26 (PDF), 13 (fallback SQLite/Turso) seguem abertos.

**Lote 4 — Scheduler + contadores (06/09/2026)**
- [x] Scheduler: lote limitado, re-check de cancelamento e UPDATE condicionado (23). `_processar_pendentes` usa `LIMIT` (LOTE_MAXIMO_POR_CICLO, default 20), nao envia lembrete ja cancelado (`_ainda_pendente`) e so marca `enviado`/`falha`/`tentativa` com `AND status='pendente'`. Testes em `backend/tests/test_lembrete_scheduler.py`.
- [x] Indice de lembretes pendentes (23, parte). `idx_lembretes_pendentes ON lembretes(status, horario_envio)` em `db.py`.
- [x] Contadores por paciente sem piscar (25). Revisao independente apontou que `autoDispose` faria o contador exibir "0" ao reabrir a ficha (regressao de UX, mesma licao dos KPIs do AGENTS). Mantido `StreamProvider.family` (nao-autodispose), com o cache evitando o flash — o watcher e a rota, logo o cache nao fica obsoleto. O proprio item (varredura Θ(V×S)) fica documentado, mas a mudanca foi revertida por conta do flash.

**Verificacao Do Lote 4**
- Flutter: `flutter test --no-pub --reporter compact`, 212/212.
- Backend: `backend/`, `.venv/bin/python -B tests/run_isolated.py`, 175/175.
- `flutter analyze --no-pub`: sem erros; warning preexistente `_todosBlocos`.
- `git diff --check`: sem erros.
- Revisao independente: scheduler OK (cancelado nao envia, UPDATE condicionado, LIMIT, indice valido); achado do autoDispose (flash "0") corrigido revertendo para `StreamProvider.family`; teste de "sem token" corrigido para owner sem instancia; `_ainda_pendente` passa a logar erro em vez de engolir.

**Pendencias Do Lote 4**
- 24 (retries multiplicados): MANTIDO por decisao. Retry de 5xx e util (Gemini devolve 503 transitorio "high demand"); os limites ja existem (401/429 <=2, 5xx <=1). Deadline global e cancelamento do trabalho remoto exigem medicao e sao melhoria futura, nao correcao de bug.
- 13 (fallback SQLite/Turso), 26 (PDF), 12 (temporario de playback/exclusao) seguem abertos.

**Lote 5 — Races do editor (21) + retries (24)** (06/09/2026)
- [x] Races assincronas do editor (21). `_buscarArtigosEmBackground` e `_gerarProgressoAutomatico` agora usam tokens de geracao; a flag "buscando artigos"/"progresso gerando" e sempre limpa em `finally` (inclusive no retorno antecipado `sessoesAnteriores.isEmpty`); `_resetarEstadoSessao` invalida operacoes em andamento e limpa as flags. Revisao independente detectou que um contador unico compartilhado fazia o progresso invalidar a busca de artigos (mesmo fluxo); corrigido separando contadores por tipo (`_geracaoSessao`, `_geracaoArtigos`, `_geracaoProgresso`).
- [x] Retries (24): AVALIADO e MANTIDO — ver pendencias.

**Verificacao Do Lote 5**
- Flutter: `flutter test --no-pub --reporter compact`, 212/212.
- Backend: inalterado (175/175).
- `flutter analyze --no-pub`: sem erros; warning preexistente `_todosBlocos`.
- Revisao independente: achado medio (contador compartilhado quebrava busca de artigos + spinner preso) corrigido com contadores por tipo.

**Lote 6 — Acessibilidade/design** (06/09/2026)
- [x] Escala de texto nao limitada a 150% (29). `main.dart` teto do clamp passou de `maxScaleFactor: 1.5` para `2.0`; a preferencia de acessibilidade chega aos textos. Validacao de overflow em 200% fica na matriz visual (30).
- [x] Contraste de textos informativos (29). `backend/templates/anamnese.html`: extremos/labels das escalas e footer trocados de `#94A3B8` para `#475569` (7,58:1 sobre branco); titulo de Seguranca emocional de `#E65100` para `#9A3412` (6,66:1 sobre `#FFF3E0`). Calculados e acima de 4,5:1.
- [x] Semantica acessivel no HTML da anamnese (28, parte). `aria-label` adicionado aos inputs de texto, range e condicionais (sem quebrar coleta/validacao). Estado acessivel do Sim/Nao (`aria-pressed`) ja existia do lote 1.
- [x] Acao WhatsApp focavel (28, parte). `paciente_card_home.dart`: `GestureDetector` (imagem) -> `IconButton` com `tooltip` (foco de teclado + anuncio por leitor de tela).
- [x] Foto do perfil anunciada (28, parte). `perfil_profissional_form_page.dart`: foto envolvida em `Semantics(button: true, label: 'Selecionar foto')`.
- [x] Confirmar descarte de edicao no perfil (27, parte). `PopScope(canPop: false)` com snapshot inicial vs estado atual; so abre dialogo se houve alteracoes; sem alteracoes faz pop direto; botao Salvar burla o PopScope (pop imperativo nao consulta canPop). Nao cobre os dialogos de paciente/compromisso ainda.

**Verificacao Do Lote 6**
- Flutter: `flutter test --no-pub --reporter compact`, 212/212.
- Backend: `backend/`, `.venv/bin/python -B tests/run_isolated.py`, 175/175 (testes de anamnese HTML/runtime passam).
- `flutter analyze --no-pub`: sem erros; warning preexistente `_todosBlocos`.
- Revisao independente: sem achados bloqueantes/medios — PopScope nao bloqueia salvar (pop imperativo), snapshot correto, escala 2.0 sem quebra, IconButton 44px equivalente, aria-label nao quebra coleta/validacao, contrastes passam AA.

**Pendencias Do Lote 6**
- 27: dialogos de paciente/compromisso ainda perdem edicao sem confirmacao.
- 28: links de artigos (TextSpan) sem foco de teclado; barreira de dialogo fecha sem confirmacao; navegacao por teclado completa de avatar/gestos.
- 30: matriz visual (200%, 320/600/768/1024, tema escuro, teclado aberto, estados de erro/offline) — requer renderizacao em aparelho/navegador.

**Lote 7 — Entregaveis finais (13/26/12)** (06/09/2026)
- [x] PDF do Prontuario pagina conteudo longo (26). `_secaoClinicaBlocos` divide o texto clinico em blocos (±3000 chars) e o `build` do Prontuario acha os blocos na lista do `pw.MultiPage` via `expand` — corrige `PdfTooBigPageException` de sessao extensa (teste com 40 paragrafos reproduziu e agora passa). Os exportadores "Registro de Sessao"/"Sintese Revisada" mantem o `pw.Column` simples (sem quebra), sem alteracao visual.
- [x] Temporario de playback do audio rastreado (12, parte). `AudioRelatoService` registra temporarios em `_playbackTemporarios` e expoe `limparRecursosReproducao()` (chamado no `dispose` do servico). Teste em `test/services/audio_playback_test.dart`. NO `bloquear()`, apenas o cache e limpo — os temporarios de `/tmp` nao sao apagados para nao romper um player ativo (achado da revisao).
- [x] Fallback SQLite/Turso: fail-closed controlavel (13, parte). `ALLOW_SQLITE_FALLBACK` (default `"true"` para dev/testes). Em producao, definir `"false"` nos secrets do Fly: com o Turso indisponivel, `_obter_conexao` lanca `RuntimeError` em vez de aceitar escritas em disco efemero (que seriam perdidas). Teste em `backend/tests/test_fallback_db.py`. A reconciliacao/fila real do fallback permanece (decisao futura).

**Verificacao Do Lote 7**
- Flutter: `flutter test --no-pub --reporter compact`, 214/214 (era 212; +2: audio_playback + pdf conteudo longo).
- Backend: `backend/`, `.venv/bin/python -B tests/run_isolated.py`, 177/177 (era 175; +2: test_fallback_db).
- `flutter analyze --no-pub`: sem erros; warning preexistente `_todosBlocos`.
- Revisao independente: paginacao do PDF confirmada; 2 achados medios corrigidos — (a) `bloquear()` apagava temporarios durante reproducao ativa (removida a limpeza fisica no bloquear; so cache), (b) `_secaoClinica` ganhou chunking sem ganhar paginacao e mudou visual nos exportadores em Column (restaurado render simples; divisao so no Prontuario).

**Pendencias Do Lote 7**
- 13: reconciliacao/fila real do fallback (escritas feitas antes do fail-closed nao sao reconciliadas; e o `ALLOW_SQLITE_FALLBACK=false` precisa entrar nos secrets do Fly).
- 26: "Registro de Sessao"/"Sintese Revisada" ainda nao paginam dentro do `pw.Column` (item 26 parcial; Prontuario resolvido).
- 12: exclusao fisica do arquivo ao "nao manter" audio (depende do modelo da sessao).

**HOTFIX — tela de erro no boot (11/09/2026)**
- **Sintoma (dono):** app abria na tela "Erro inesperado / Ocorreu um erro ao exibir esta tela".
- **Causa raiz:** o fail-closed do `EncryptedServiceMixin.decrypt` (lote 2) LANCAVA ao ler um campo cifrado sem chave. No boot, o `AppStartPage.initState` chama `PerfilProfissionalService.obterPerfil()` (para decidir a duracao do splash) ANTES do desbloqueio — momento em que a chave ainda NAO foi carregada em memoria. Com o perfil cifrado, o `decrypt` lancava `StateError` no `initState` -> `ErrorWidget`. Antes do fail-closed, o `decrypt` devolvia o valor e o app abria.
- **Fix:** o fail-closed vale para a ESCRITA (nunca gravar em texto puro). A LEITURA sem chave volta a devolver o valor como esta (o app pede o desbloqueio e relê). `encrypted_service_mixin.dart:18-30`.
- **Testes:** novo `test/services/boot_leitura_cifrada_test.dart` (RED reproduziu o `StateError`; GREEN apos o fix). `encrypted_service_mixin_test` atualizado para o novo comportamento.
- **Verificacao:** Flutter 215/215; `flutter analyze` limpo (1 warning preexistente).
- **APK:** `1.0.36+37` -> **`1.0.37+38`** (`MentAllPRO-v1.0.37.apk`). O `1.0.36` fica descartado (boot quebrado).

**HOTFIX 2 — lembretes orfaos + gate de seguranca (14/09/2026)**
- **Lembretes orfaos (dono):** mesmo com o app formatado, o backend continuava enviando lembretes (um aviso saiu para uma paciente). Os lembretes ficam no Turso (nao no aparelho); o dono trocou de conta, entao o `owner_id` antigo (`ef9ef416`) tinha 15 lembretes `pendente` (15/09 a 23/11/2026). Cancelados no backend via `UPDATE lembretes SET status='cancelado' WHERE status='pendente'` (rowcount=15). Confirmado: `pendentes=0`. Nao reenvia mais.
- **Gate de seguranca pulado (dono):** no boot de instalacao nova, `AuthService.gerarChave()` marcava `_desbloqueado = true`, entao o `AppStartPage` pulava o login. Corrigido: `gerarChave` nao marca desbloqueado -> o gate e exigido na primeira abertura. Teste em `test/services/auth_service_test.dart`.
- **Aviso de fail-safe (dono pediu "avise e permita"):** quando o aparelho nao tem biometria/credencial (ou o gate fica indisponivel), o acesso e permitido mas com aviso. Novo `AuthService.ultimoAcessoFailSafe`; `LoginPage` mostra SnackBar informando que o acesso nao pode ser protegido. Sem PIN proprio (decisao do dono: menos configuracao/performance).
- **Verificacao:** Flutter 216/216; `flutter analyze` limpo (1 warning preexistente).
- **APK:** `1.0.37+38` -> **`1.0.38+39`** (`MentAllPRO-v1.0.38.apk`).
- **Pendente (Frente C):** endpoints `GET/DELETE /lembretes` + tela "Lembretes agendados / Cancelar todos" para o dono limpar orfaos futuros pela propria conta.

**Pendente**
Todas as demais demandas do relatorio permanecem abertas. Correcao parcial nao significa encerramento do item completo. O relatorio inicial foi preservado como registro historico; este checklist descreve o codigo apos os lotes 1-7 + hotfixes.
