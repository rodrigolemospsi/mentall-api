# MentAll PRO — Prontuário Clínico com IA

> **Regra de comunicação (obrigatória):** o dono do projeto se chama **Rodrigo**. Toda resposta deve começar se dirigindo a ele como "Rodrigo".

> **Regra de trabalho (obrigatória):** ao receber **qualquer solicitação**, invocar obrigatoriamente a skill `using-agent-skills` **antes de qualquer leitura de código ou planejamento**. Ela apontará as demais skills aplicáveis (ex.: `planning-and-task-breakdown`, `test-driven-development`, `frontend-ui-engineering`, `debugging-and-error-recovery`), que devem ser invocadas em sequência antes de planejar e executar. Não iniciar análise, plano ou código sem ter passado por esse passo.

> **Regra de memória (obrigatória):** ao concluir **qualquer tarefa que altere o projeto** (código, config, documentação ou decisão), atualizar este `AGENTS.md` **automaticamente, sem esperar pedido** — inserindo uma **nova seção datada logo abaixo do CHECKLIST DE FUMAÇA** (mais recente no topo), no formato das seções existentes: **Contexto / O que mudou (arquivos) / Verificação (testes, analyze) / Pendências**. Não reescrever nem remover seções antigas; não incluir segredos nem PII; ser conciso (detalhes longos vão para `tasks/` ou para o commit). Sessões puramente conversacionais (sem mudança no projeto) não geram seção.

> **Disciplina de tamanho:** manter cada seção concisa (~10–20 linhas); quando o arquivo passar de ~200 KB, comprimir as entradas antigas (resumo no topo + detalhe movido para `docs/AGENTS_historico.md`).

## CHECKLIST DE FUMAÇA — obrigatório antes de gerar APK/deploy

> **Por que existe:** em 06–14/09/2026 uma auditoria de segurança (7 lotes + 2 hotfixes, 66 arquivos) foi aplicada de uma vez, sem commits intermediários e sem teste no aparelho. Os 221 testes passavam, mas usam **dublês** (`_FakeGate`, `_MemStorage`) e **não exercitam o platform channel**. Resultado: `MainActivity` continuou sendo `FlutterActivity` (o `local_auth` exige `FlutterFragmentActivity`) e a biometria parou de funcionar sem nenhum teste falhar. **Teste verde NÃO significa app funcionando.**

### Regras de processo (evitam a "avalanche")
- **Uma correção = um commit.** Nunca acumular lotes grandes sem commit; sem commits não há rollback nem `git bisect`.
- **Toda mudança em boot/cripto/biometria/áudio/IA/persistência exige verificação NO APARELHO**, além de `flutter analyze` + `flutter test`.
- Mudanças de segurança (fail-closed) precisam validar o **caminho feliz** ponta a ponta, não só o caso de bloqueio.

### Antes de gerar o APK
- [ ] `flutter analyze` **exit 0** (sem warnings: o CI reprova em qualquer issue, incl. `unused_element`)
- [ ] `flutter test` 100% (0 falhas; a contagem varia com o tempo — não remover testes)
- [ ] `flutter build apk --release` compila
- [ ] Árvore de trabalho sem mudanças soltas (tudo commitado)

### No aparelho (fluxos críticos)
1. **Boot/desbloqueio:** "Desbloquear com digital/face" ON + biometria cadastrada → reabrir **exige o prompt do sistema**; cancelar mostra erro e permite retentar; acertar abre a Home.
2. **Gravar → transcrever:** gravar áudio → finalizar (aparece "Gravação finalizada") → Transcrever → o texto aparece no campo.
3. **Síntese → salvar (tela apaga):** tocar Gerar síntese → **apagar a tela no meio** (a síntese leva até 150s) → voltar: a operação conclui e a **mesma tela de sessão continua aberta**. Salvar → sessão aparece na lista.
4. **Prontuário/PDF:** exportar "Prontuário completo" → gera sem travar.
5. **Bloqueio:** com o app aberto, mandar para segundo plano → ao voltar, o **overlay** de bloqueio aparece por cima da **mesma tela** (não volta para a Home e não perde a sessão).

### Sinais de alarme (parar e investigar)
- App abre sem pedir biometria (com a opção ligada) ou diz que o aparelho não tem biometria.
- "Não foi possível salvar a sessão" / "Serviço de IA temporariamente indisponível".
- Sessão/transcrição perdida após a tela apagar.
- PDF que não gera ou tela que congela.

### Observabilidade
- **Sentry** está integrado e **desligado por padrão**. Para ativar: criar conta no Sentry, pegar o DSN e compilar com `--dart-define=SENTRY_DSN=<dsn>`. Envia apenas stack trace (sem PII, sem corpo de requisição, sem breadcrumbs).
- **Nota de ambiente (macOS) — RESOLVIDO em 28/09/2026:** o Xcode estava **sem licença/first-launch aceitos** (`xcrun` retornava **exit 69** com stdout vazio; o `git` também imprimia "You have not agreed to the Xcode license agreements"). A licença foi aceita (`sudo xcodebuild -license accept`) e `flutter test`/`git` passaram a rodar **sem** variáveis nem workaround — confirmado: `flutter test --no-pub` **224/224** e `flutter analyze --no-pub` limpo, sem `DEVELOPER_DIR`. Se o erro voltar (ex.: reinstalação/máquina nova), a solução definitiva é `sudo xcodebuild -license accept` (exige senha de admin). Detalhe técnico (para referência futura): `DEVELOPER_DIR=/Library/Developer/CommandLineTools` resolve o **tool do Flutter** e o **git**, mas **NÃO basta** para `flutter test` quando a licença não está aceita, porque o hook de native assets (`objective_c`, puxado pelo `flutter_secure_storage`) roda em ambiente **semi-hermético** (o pacote `hooks` repassa só `PATH`, não `DEVELOPER_DIR`) → `xcrun --show-sdk-path` volta vazio → `Bad state: No element`; nesse caso, além do `DEVELOPER_DIR`, era preciso um shim de `xcrun` no `PATH` (`#!/bin/sh` → `export DEVELOPER_DIR=/Library/Developer/CommandLineTools; exec /usr/bin/xcrun "$@"`). Observação: `xcodebuild -checkFirstLaunchStatus` ainda retorna **69** (first-launch não concluído) — **não** afeta `flutter test`, mas pode ser concluído com `sudo xcodebuild -runFirstLaunch`.

## Lojas (29/09/2026) — ÍCONES (iOS sem alpha + 512 do Play)

### Contexto
- Frente 2 (publicação): regenerar o ícone e preparar o asset do Google Play.

### O que mudou (arquivos)
- `pubspec.yaml`: `flutter_launcher_icons` com **`ios: true`** + **`remove_alpha_ios: true`** (App Store exige ícone sem alfa).
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/`: regenerado (**RGB, sem alfa**; +50/57/72 px).
- `store/play_icon_512.png` (**512×512, RGB**) — asset para o Google Play.
- Android: regenerado **idêntico** (logo inalterada).
- `ios/Runner.xcodeproj/project.pbxproj`: **revertido** o efeito colateral do plugin (`GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` voltou a `YES`).

### Verificação
- `flutter analyze` limpo; `flutter test` **236/236**. Play 512×512 sem alfa; iOS 1024 sem alfa.

### Pendências (Frente 2)
- **Screenshots** (Home/Pacientes/Sessão/Financeiro/Agenda) — exigem o app rodando.
- Descrição/categorias, Política/Termos (URL pública) e nota LGPD.
- Contas de dev (Play/App Store) + keystore de release.

## Segurança (29/09/2026) — GATE DE SCAN DE DEPENDÊNCIAS NO CI

### Contexto
- Frente 1 (restante): adicionar **scan de dependências no CI** como gate.

### O que mudou (arquivos)
- `backend/requirements.txt`: **PyJWT 2.13.0 → 2.14.0** (CVE-2026-102274; o `pip-audit` acusava).
- `.github/workflows/deploy.yml`: novo job **`dependency-scan`** (`pip-audit -r backend/requirements.txt` + **`osv-scanner scan -L pubspec.lock`**); o job `deploy` agora **depende** dele (gate).

### Verificação
- Backend **208/208** com PyJWT 2.14.0. `pip-audit`: **"No known vulnerabilities found"**; `osv-scanner` no `pubspec.lock`: **"No issues found"**.
- CI verde: Backend ✓ · Flutter ✓ · **Dependency scan ✓** · Deploy ✓. Produção: `/health` 200; Fly **v41**.
- **Nota:** o parser de `requirements.txt` do osv-scanner resolve transitivas de forma imprecisa (falso positivo em `tqdm 4.9.0` etc.) → por isso o osv-scanner varre **só** o `pubspec.lock`; o Python fica com o `pip-audit`.

## Segurança (29/09/2026) — ROTAÇÃO DO `WUZAPI_WEBHOOK_TOKEN`

### Contexto
- Pendência do pentest: o token do webhook do wuzapi (enviado na **query string**) pode ter vazado em access logs. Rotacionado.

### O que mudou
- Novo `WUZAPI_WEBHOOK_TOKEN`. Atualizado em: **`backend/.env`**, **secret no Fly** (`mentall-api`) e o **`users.webhook`** do wuzapi (`~/wuzapi/dbdata/users.db`, instância `profissional`).
- Serviços reiniciados (wuzapi + backend local via `launchctl`) e a máquina do Fly atualizada ao trocar o secret.

### Verificação
- `POST /wuzapi/webhook?token=<novo>` → **200** (local e Fly); com o token **antigo** → **403**. O wuzapi passou a apontar para o novo. Sem mudança de código.

### Pendências
- Frente 1 (restante): scan de dependências no CI (pip-audit/osv-scanner) como **gate**.

## Ops (29/09/2026) — LIMPEZA DE CONTAS (só o dono)

### Contexto
- Deixar apenas a conta do dono (`rodrigolemosba@gmail.com`) e remover as demais (2 de teste + 1 com typo `...@gmail.com@gmail.com`).

### O que mudou (dados no Turso)
- **Excluídas** (conta + dados vinculados): `mentall.brasil@gmail.com` (2 contratos, 9 anamneses, 24 lembretes), `rodrigolemosba@hotmail.com` (vazia), `rodrigolemosba@gmail.com@gmail.com` (vazia, pendente).
- **Mantida:** `rodrigolemosba@gmail.com` (role=`admin`) — dados intactos (1 contrato, 1 anamnese, 1 dispositivo, 4 eventos).
- **Sem backup** (decisão do dono: eram contas de teste; ele já migrou para o outro e-mail).

### Verificação
- `SELECT` confirma **1 conta** em `usuarios`; dados do dono intactos. Sem alteração de código.

## Correções e Funcionalidades (29/09/2026) — HEARTBEAT AUTENTICADO + CI IGNORA DOCS

### Contexto
- Ao validar o painel, os logs mostraram `POST /telemetria/heartbeat → **401**`: o app enviava o heartbeat **sem autenticar**; como o `bloquear()` apaga o JWT no segundo plano, o heartbeat falhava (online não contava).
- Além disso, um push **só de docs** (`7267f02`) **reiniciou a máquina** no Fly (o workflow sempre reimplanta em push para `master`), derrubando a sessão do painel por ~1 min.

### O que mudou (arquivos)
- `lib/services/telemetria_service.dart`: `heartbeat()` e `_enviarEvento()` chamam **`ApiClient.ensureAuthenticated()`** antes de enviar (online conta mesmo em background; sem autenticação, não envia — evita 401).
- `test/services/telemetria_service_test.dart`: JWT válido de teste + caso "heartbeat não envia sem autenticação".
- `.github/workflows/deploy.yml`: **`paths-ignore`** para `AGENTS.md`, `tasks/**`, `docs/**`, `**.md` → push só de docs **não reimplanta** o backend.
- `pubspec.yaml`: `1.0.43+44` → `1.0.44+45`.

### Verificação
- `flutter analyze` exit 0; `flutter test` **236/236** (era 235; +1).
- APK: `MentAllPRO-v1.0.44.apk` (~76 MB), sha256 `52580c6c3afc40c5e2659bf84d2b805a4772d00fecd8e8272a25781dcc1c5026`.

### Pendências
- Instalar o **1.0.44** e confirmar que o app aparece **online** no painel.

## Correções e Funcionalidades (29/09/2026) — FASE 3: PAINEL DO DONO (web)

### Contexto
- Painel web **só do dono** (Fase 3 do plano de venda recorrente), consumindo a telemetria da Fase 2. Decisão de segurança: **server-rendered pelo backend** (mesma origem, sem CORS) + **cookie `httpOnly`** — evita código de admin em bundle público e token acessível a JS.

### O que mudou (arquivos)
- **Backend:**
  - Coluna **`role`** em `usuarios` (default `'user'`) + migração `_garantir_coluna`.
  - `services/admin.py`: `kpis()` (total, **online agora** ≤5 min, aparelhos, eventos por tipo) e `listar_usuarios()` (paginado + busca + online/aparelho).
  - `admin_ui.py`: login e dashboard **server-rendered** (HTML/CSS, **sem JS inline**).
  - Rotas **`GET /admin`**, **`POST /admin/login`**, **`POST /admin/logout`**; sessão em **cookie `httpOnly`+`Secure`+`SameSite=Strict`** (path `/admin`). Gate: `role='admin'` (ou admin legado).
  - `backend/tests/test_admin.py` (10).
- **Ops:** conta `rodrigolemosba@gmail.com` → `role='admin'` no Turso.

### Verificação
- Backend **208/208** (era 198; +10). CI verde (Backend · Flutter · Deploy).
- Produção: `GET https://mentall-api.fly.dev/admin` → 200 (form de login); CSP com nonce.

### Pendências
- **Dono:** abrir `https://mentall-api.fly.dev/admin`, entrar com e-mail/senha e conferir KPIs/lista.
- **Domínio** `admin.mentallpro.com.br`: apontar **CNAME → `mentall-api.fly.dev`** e emitir o certificado no Fly (`fly certs add admin.mentallpro.com.br`).
- Receita do mês: depende da Fase 4 (assinaturas).

## Correções e Funcionalidades (29/09/2026) — FASE 2: TELEMETRIA (heartbeat + eventos)

### Contexto
- Pré-requisito do painel (Fase 3): o app passa a reportar **presença** (online/offline) e **uso** à nuvem — **só números, sem PII** (LGPD).

### O que mudou (arquivos)
- **Backend:** tabelas `dispositivos` e `eventos` (+ índices) em `db.py`; `services/telemetria.py` (`registrar_heartbeat` upsert + `registrar_evento` com **allowlist** de tipos); `POST /telemetria/heartbeat` e `POST /telemetria/evento` (autenticados); schemas com `extra="forbid"` (PII → 422). Testes: `backend/tests/test_telemetria.py` (8).
- **App:** `lib/services/telemetria_service.dart` (device_id UUID persistido, plataforma, versão via **`package_info_plus`**, **fila offline best-effort**); `telemetriaServiceProvider`; heartbeat no boot/resume + **Timer de 3 min** (`AppLockGate`); eventos nos pontos-chave (`sessao_salva`, `transcricao`, `sintese`, `paciente_criado`, `contrato_enviado`, `anamnese_enviada`).
- **Dep nova:** `package_info_plus` (direta).

### Verificação
- Backend **198/198** (era 190; +8). Flutter **235/235** (era 230; +5). `flutter analyze` limpo.
- APK: `MentAllPRO-v1.0.43.apk` (~76 MB), sha256 `a5d52beabaf3fd860e9c8b1001453c3837686e09b55e1f6c2d3771fc97e83b6a`.

### Pendências
- **Deploy do backend** (push → CI) para os endpoints existirem.
- Instalar o APK e confirmar que heartbeat/eventos chegam (consultar `dispositivos`/`eventos` no Turso).
- Depois: **Fase 3** (painel) consome esses dados.

## Segurança (28/09/2026) — CSP COM NONCE (remove `unsafe-inline` do `script-src`)

### Contexto
- Pendência do Strix: o CSP das páginas públicas (contrato/anamnese) usava `script-src 'self' 'unsafe-inline'`, o que permite executar script inline injetado.

### O que mudou (arquivos)
- `backend/main.py`: o middleware gera um **nonce por resposta** (`request.state.csp_nonce`) e o CSP passa a **`script-src 'self' 'nonce-...'`**; as rotas (contrato/anamnese) injetam o nonce nas tags `<script>` via `_com_nonce_script`.
- `backend/templates/anamnese.html` e `contrato.html`: **removidos os handlers inline `onclick`**; toggle/enviar/aceitar passam a usar `addEventListener` (delegação por classe `.btn-sim/.btn-nao`).
- `fetch` do aceite agora **relativo** (`/contratos/{token}/aceitar`) — mesma origem, para não ser barrado pelo CSP.
- `backend/tests/test_csp.py` (novo, 2) + `test_anamnese_xss.py` atualizado.

### Verificação
- Backend **190/190** (era 188; +2). CI verde (Backend · Flutter · Deploy).
- Produção: CSP com **`script-src 'self' 'nonce-...'`** (sem `unsafe-inline`); Fly **v35**.

### Pendências
- Verificar no navegador (contrato e anamnese): a página carrega e o botão envia (nonce aplicado).

## Segurança (28/09/2026) — TRUSTED_PROXIES (CIDR) + `--proxy-headers`

### Contexto
- Pendência do pentest (Strix): definir `TRUSTED_PROXIES` no deploy e normalizar `--proxy-headers`. O Fly **não tinha** `TRUSTED_PROXIES`.
- **Achado:** `_cliente_ip` fazia **membership exato** (`peer not in TRUSTED_PROXIES`) → um **CIDR nunca casava** com o IP do peer. O rate-limit por IP funcionava no Fly só porque `_peer_eh_proxy` confia em IP privado (edge do Fly, ex.: `172.16.28.234`).

### O que mudou (arquivos)
- `backend/main.py`: novo `_ip_em_proxies(peer)` — casa **IP exato ou CIDR**; `_cliente_ip` usa-o.
- `backend/tests/test_rate_limit.py`: **+2** testes (dentro/fora do CIDR).
- `render.yaml` e `backend/start_backend.sh`: uvicorn com **`--proxy-headers`** (paridade com o Dockerfile).
- `backend/.env.example`: documenta a faixa do Fly (`172.16.0.0/12`, `fdaa::/16`).
- **Secret no Fly:** `TRUSTED_PROXIES=172.16.0.0/12,fdaa::/16`.

### Verificação
- Backend **188/188** (era 186; +2); CI verde (Backend · Flutter · Deploy). Produção: `/health` 200; Fly **v34**.

### Pendências (Frente 1 — segurança, restantes)
- CSP `script-src 'unsafe-inline'` (contrato/anamnese).
- Rotacionar `WUZAPI_WEBHOOK_TOKEN`.
- CI: scan de dependências (pip-audit/osv-scanner).

## Correções e Funcionalidades (28/09/2026) — DIÁLOGO DE BIOMETRIA EM PORTUGUÊS

### Contexto (bug reportado)
- O diálogo de autenticação (biometria/credencial) mostrava **título e subtítulo em inglês**: **"Authentication required"** e **"Verify identity"**. O resto já era português (descrição e botão do sistema).

### Causa
- `AuthService._LocalAuthGate.autenticar()` chamava `local_auth.authenticate(localizedReason: ...)` **sem `authMessages`** → o plugin `local_auth_android` usava os defaults em inglês (`androidSignInTitle` / `androidSignInHint`).

### O que mudou (arquivos)
- `pubspec.yaml`: dependência direta **`local_auth_android: ^2.0.9`** (evita o lint `depend_on_referenced_packages`, fatal no CI) + versão `1.0.41+42` → `1.0.42+43`.
- `lib/services/auth_service.dart`: novo `const mensagensBiometria = AndroidAuthMessages(signInTitle: 'Acesso com biometria', signInHint: '', cancelButton: 'Cancelar')`; o `authenticate(...)` passa `authMessages` e a descrição virou **"Autentique-se para acessar o MentAll."**.
- `test/services/auth_service_test.dart`: teste das strings.

### Verificação
- `flutter analyze` **exit 0** (No issues found); `flutter test` **230/230** (era 229; +1); `flutter build apk --release` OK.
- APK: `MentAllPRO-v1.0.42.apk` (~76 MB), sha256 `65ced8ac21a41725192063478feb53e7c84fd04a88b62ae473fa2ebf577b1b30`.

### Pendências
- Verificar no aparelho: o diálogo deve exibir **"Acesso com biometria"** + **"Autentique-se para acessar o MentAll."** (sem "Verify identity").

## Deploy (28/09/2026) — PUSH PARA O GITHUB + CI VERDE (corrige gate do analyze)

### Contexto
- O push para `master` (repo público `mentall-api`) disparou o workflow. O job `flutter-checks` **falhou no `Analyze`** e o `deploy` foi **pulado**.
- Causa: `tools/gerar_prompts_ia_pdf.dart` tinha a função **morta `_todosBlocos`** (`unused_element`). O `flutter analyze` trata isso como **erro (exit 1)** — mas localmente a saída era lida ignorando o **código de retorno**, então passou despercebido.

### O que mudou (arquivos)
- `tools/gerar_prompts_ia_pdf.dart`: removida a função não referenciada → `flutter analyze` **exit 0 (No issues found!)**.
- `git push origin master` (20 commits acumulados desde 03/09 + este fix). Commit `5f7640a`.

### Verificação
- CI (`gh run watch`): **Flutter (analyze+test) ✓ · Backend ✓ · Deploy app ✓** (`flyctl deploy`).
- Produção: `GET /health` → 200 (turso); `POST /auth/solicitar-reset-senha` → 200. Fly agora em **v31** (v30 = deploy manual; v29 = 03/09).

## Deploy (28/09/2026) — BACKEND NO FLY (recuperação de senha no ar)

### Contexto
- O app mostrava **"Não foi possível enviar o código. Verifique sua conexão."** ao redefinir a senha. Causa: o Fly estava na **v29 (03/09/2026)** e **não tinha** os endpoints novos — `POST /auth/solicitar-reset-senha` retornava **404**. Todo o backend desde 03/09 (auditoria 06–14/09 + credenciais + reset) **nunca havia sido implantado**.

### O que mudou
- `fly deploy --remote-only` (raiz do repo; o Dockerfile copia `backend/`). Máquina `48ed314fe15d08` atualizada.
- Verificação: `GET /health` → **200** (turso); `POST /auth/solicitar-reset-senha` → 200 genérico; com `rodrigolemosba@gmail.com` → `"Codigo enviado para o email."` (SMTP configurado no Fly: `SMTP_HOST/PORT/USER/PASS/FROM`).
- **Sem push para o GitHub** (commits seguem locais) — deploy direto pelo `flyctl` autenticado. O workflow `.github/workflows/deploy.yml` continua sendo o caminho no push para `master`.

### Verificação no aparelho
- ✅ **Concluído (28/09/2026):** redefinição de senha feita no aparelho e as 4 funções testadas — "Tudo funcionando".

## Correções e Funcionalidades (28/09/2026) — RECUPERAÇÃO DE SENHA DA CONTA + SESSÃO NO DESBLOQUEIO

### Contexto (bug reportado: "não funciona anamnese/acordo/transcrição/síntese")
- O erro era **"Não foi possível autenticar com o servidor"** (transcrição/síntese) e **"Erro ao criar questionário"** (anamnese). Os **logs do Fly** mostraram `POST /auth/login → 401` para `rodrigolemosba@gmail.com` (conta **ativa** no Turso): a **senha guardada no app não batia com a conta**.
- Agravantes: após o bloqueio (`bloquear()` apaga o JWT), o **desbloqueio por biometria não restabelecia a sessão** (dependia de reautenticar a cada chamada); `anamnese`/`contrato` **não retentavam em 401**; e **não havia recuperação de senha** (o fluxo existente é do **PIN**, não da conta).

### O que mudou (arquivos)
- **Backend:** novos `POST /auth/solicitar-reset-senha` e `POST /auth/redefinir-senha` (código por e-mail, expiração 10 min, tentativas/bloqueio, senha forte, anti-enumeração) + tabela `resets_senha` + `usuarios.redefinir_senha`. Testes em `backend/tests/test_reset_senha.py` (9).
- **App:** tela `RedefinirSenhaPage` (acessível em **Configurações > Avançado** e no **ContaPage**); ao concluir, salva a credencial nova (cofre durável). `ApiClient.solicitarResetSenha`/`redefinirSenha`.
- **Frente B:** restabelece a sessão no desbloqueio (`AuthService.estabelecerSessaoServidor` chamado no `LoginPage` e no overlay `_TelaBloqueio`); **retry em 401** na anamnese e no contrato (que passou a usar `ApiClient.post/get`); **log do status/body** no `forceReauthenticate`.

### Verificação
- Backend **186/186** (era 177; +9). Flutter **229/229** (era 224; +3 API +2 widget). `flutter analyze` limpo (1 warning pré-existente `_todosBlocos`).

### Verificação no aparelho (28/09/2026)
- ✅ **Resolvido:** com o APK 1.0.41 + backend implantado, a redefinição de senha (Configurações > Avançado > Redefinir senha da conta) e as 4 funções (**anamnese, acordo, transcrição e síntese**) passaram a funcionar. Confirmado pelo dono: "Tudo funcionando".

## Release (28/09/2026) — APK 1.0.41+42

### Contexto
- Empacotar a recuperação de senha da conta + as correções de sessão (`cafefd8`).

### O que mudou (arquivos)
- `pubspec.yaml`: `1.0.40+41` → `1.0.41+42`.
- APK: `MentAllPRO-v1.0.41.apk` (~76 MB), sha256 `225ae9a5fd4970200f2e96d6fc12e9171ec80acf35d0ed0046b8ec6b5684a3ac`.

### Verificação (checklist de fumaça)
- `flutter analyze --no-pub`: limpo (1 warning pré-existente `_todosBlocos` em `tools/`).
- `flutter test --no-pub`: **229/229**.
- `flutter build apk --release`: OK (exit 0).

## Release (28/09/2026) — APK 1.0.40+41

### Contexto
- Empacotar em release o fix de credenciais duráveis (`72937f4`) e a redução do `AGENTS.md` (`01be7f8`, `b215723`).

### O que mudou (arquivos)
- `pubspec.yaml`: `1.0.39+40` → `1.0.40+41`.
- APK: `MentAllPRO-v1.0.40.apk` (~76 MB), sha256 `02df2914e49a17ca5c5654bc2c81a2d24a0746c83c97cfad984d2e6b9ef1e5d1`.

### Verificação (checklist de fumaça)
- `flutter analyze --no-pub`: limpo (1 warning pré-existente `_todosBlocos` em `tools/`).
- `flutter test --no-pub`: **224/224**.
- `flutter build apk --release`: OK (exit 0).
- APK copiado para a raiz como `MentAllPRO-v1.0.40.apk` (`.apk` é gitignored).

### Pendências
- Instalar no aparelho e rodar os fluxos críticos do checklist de fumaça (boot/biometria, gravar→transcrever, síntese→salvar com a tela apagando, PDF, bloqueio).

## Documentação (28/09/2026) — REDUÇÃO DO AGENTS.md + REGRA DE MEMÓRIA AUTOMÁTICA

### Contexto
- O `AGENTS.md` tinha 2256 linhas (~216 KB), ~79% de histórico datado, e é carregado em toda sessão (custo de contexto). Faltava uma regra para manter a memória sem pedido explícito.

### O que mudou (arquivos)
- `AGENTS.md`: 2256 → 677 linhas; **Regra de memória** + **Disciplina de tamanho** no topo; índice no fim.
- `docs/AGENTS_historico.md` (novo): 34 seções datadas anteriores a 29/08/2026, movidas verbatim (mais recente primeiro).
- Commit `01be7f8`.
- Complemento: a contagem de testes no CHECKLIST DE FUMAÇA deixou de ser fixa (estava "221"; a suíte atual é **224**) — evita ficar desatualizada.

### Verificação
- Multiset de linhas contra backup: **0 linhas de conteúdo perdidas**; 6 linhas novas (2 regras + índice + cabeçalho). Sem mudança de código/testes.

### Pendências
- Skills de handoff (A/B) seguem instaladas globalmente — decisão do dono: "depois".

## Correções e Funcionalidades (28/09/2026) — CREDENCIAIS DURÁVEIS PARA RE-AUTENTICAÇÃO (fecha o teste RED de 27/09)

### Contexto (o que ficou pela metade em 27/09)
- `test/services/api_client_test.dart` foi reescrito em 27/09 para exigir um `CredenciaisStore` durável + injeção de `httpClient`/`credenciaisStore`/`resetarCredenciaisEmMemoria` no `ApiClient`. A **implementação nunca foi feita**: o teste não compilava (11 erros) e `lib/services/credenciais_store.dart` não existia.
- Bug real por trás: com a chave ainda **não carregada** (app bloqueado), o getter `password` devolvia `''` e o `forceReauthenticate` fazia POST com usuário/senha em branco → 401 confuso. E o login (`entrarComEmailSenha`) não persistia credenciais em cofre durável, então não havia de onde recuperá-las (era a pendência do 03/09).

### Fix (TDD — teste RED → GREEN)
- **Novo `lib/services/credenciais_store.dart`:** interface `CredenciaisStore` (`salvar`/`carregar`/`limpar`) + `SecureCredenciaisStore` (Keychain/Keystore via `flutter_secure_storage`), usando as **mesmas chaves** de `AuthService.salvarCredenciaisServidor` (fonte única).
- **`lib/services/api_client.dart`:**
  1. `static http.Client httpClient` injetável; `post`/`get`/`forceReauthenticate` usam-no.
  2. `static CredenciaisStore credenciaisStore` + `resetarCredenciaisEmMemoria()`.
  3. `setCredentials` persiste também no cofre durável (falha de cofre não interrompe o login).
  4. `forceReauthenticate` recupera do cofre quando o `app_config` está vazio e retorna `false` **sem tocar a rede** se não houver credencial nenhuma.

### Verificação
- `test/services/api_client_test.dart` **6/6** (era 11 erros de compilação).
- Suíte Flutter **224/224**; `flutter analyze` limpo (1 warning pré-existente `_todosBlocos` em `tools/`).

## Correções e Funcionalidades (04/09/2026) — DESBLOQUEIO ABRIA SEM PEDIR BIOMETRIA/SENHA (GATE RESTAURADO)

### Bug reportado (dono): "O app está abrindo sem solicitar senha ou biometria, mesmo estando marcado desbloquear com digital/face"
- **Sintoma:** com a opção "Desbloquear com digital / face" ativa, o app abria direto na Home, sem passar pelo prompt de biometria/credencial do sistema.
- **Causa raiz (regressão do fix de 03/09 — `43fc065`):** o desbloqueio real ia por `EncryptionService.carregarChaveDoSecureStorage()`, que lê **primeiro o cofre durável** (`FlutterSecureStorage(aOptions: AndroidOptions())`, **sem `enforceBiometrics`**) — ou seja, reler a chave ali **não dispara prompt nenhum**. O gate de biometria de verdade (cofre `_pin`, `AndroidOptions.biometric(enforceBiometrics: true)`) só era lido como **fallback** quando o cofre durável estava vazio. Além disso, `LocalAuthentication.authenticate()` **nunca era chamado** em lugar algum do app (o `_localAuth` só era usado para consultar suporte, não para autenticar) — conferido por grep. Resultado: em qualquer aparelho com a chave no cofre durável, `desbloquearComBiometria()` retornava `true` imediatamente; o `LoginPage` auto-disparava isso no `initState` e o app "abria" sozinho. Em instalação sem chave reconhecida, o boot (`main.dart`) chamava `gerarChave()` e setava `_desbloqueado = true`, pulando o login por completo.
- **Decisões do dono (perguntas):** (1) com "Desbloquear com digital/face" ativo + aparelho com biometria/credencial → **exigir prompt de verdade**; (2) manter **fail-safe** (nunca travar) quando o aparelho não tiver biometria/tela bloqueada ou a biometria for invalidada.
- **Segundo achado:** `ConfiguracoesService.biometriaAtivada` (chave `biometria_ativada`, padrão `'true'`) era lido **só** na service e na UI — **nenhuma parte do fluxo de autenticação o lia** (grep). O switch era puramente cosmético.

### Fix (TDD — testes RED antes)
- **`lib/services/auth_service.dart`:**
  1. Nova abstração injetável `GateDeAutenticacao` (`suportaGate()` / `autenticar()`) + implementação real `_LocalAuthGate` que chama `isDeviceSupported()` e `authenticate()` do `local_auth` (com `persistAcrossBackgrounding: true`) — soluciona a dependência do platform channel p/ testes sem subclasse de `LocalAuthentication`.
  2. `desbloquearComBiometria()` reescrito: com `biometriaAtivada` **on** + aparelho com gate → **exige o prompt do sistema**; retorna `false` se o usuário cancelar/falhar (não burla). Gate indisponível (sem credencial/biometria/hardware fora/bio bloqueado) ou opção **off** → cai no cofre durável **fail-safe** (preserva o fix de lockout do 03/09).
  3. Erros `LocalAuthException` classificados por `LocalAuthExceptionCode`: `noCredentialsSet`, `noBiometricsEnrolled`, `noBiometricHardware`, `biometricHardwareTemporarilyUnavailable`, `biometricLockout`, `temporaryLockout`, `deviceError`, `uiUnavailable`, `unknownError` → indisponibilidade (fail-safe); `userCanceled`/`userRequestedFallback`/`authInProgress`/`timeout`/`systemCanceled` → honram o gate (retornam `false`).
  4. Getter `biometriaAtivada` lê o box `app_config` (default `true`) — agora o toggle **realmente controla** se o gate aparece.
  5. `_carregarChave()` extraído (carrega a chave do secure storage, seta `_desbloqueado`).
- **`lib/screens/configuracoes_page.dart`** — subtítulos do switch "Desbloquear com digital / face" agora refletem o comportamento real (on = pede a digital/face ao desbloquear; off = sem prompt, dados seguem cifrados no cofre do aparelho).
- **Testes:** **+6** em `test/services/auth_service_test.dart` (novo group "desbloquearComBiometria — gate de biometria/credencial"), com `_FakeGate` (subclasse de `GateDeAutenticacao`) e `_MemStorage` (chave no cofre durável): exige o gate e autenticou; não desbloqueia em cancelamento; não desbloqueia em erro não-indisponível; erro de indisponibilidade → fail-safe (desbloqueia); opção off → não chama o gate; aparelho sem suporte → fail-safe silencioso. RED reproduziu o comportamento antigo (retornava true sem chamar `authenticate`); GREEN após o fix.
- **Verificação:** `flutter analyze` limpo (só warning pré-existente em `tools/gerar_prompts_ia_pdf.dart`); suíte Flutter **177/177** (era 171; +6 do novo grupo).
- **APK:** bump `1.0.34+35` → **`1.0.35+36`** (`MentAllPRO-v1.0.35.apk`, ~72 MB).

### Comportamento agora (para validar no aparelho)
- Opção ON + aparelho com biometria/credencial → reabrir exibe o prompt do sistema; cancelar/errar mostra "Não foi possível autenticar. Tente novamente." (permite retentar); acerto → Home.
- Opção ON + aparelho SEM biometria/tela bloqueada (ou biometria invalidada) → abre direto (fail-safe, sem travar).
- Opção OFF → abre sem prompt (escolha explícita; dados seguem cifrados no cofre do aparelho).



### Bug reportado (dono): "Link invalido ou expirado" mesmo com link válido/fresco, e acesso ao app funcionando
- **Sintoma:** o link de confirmação chega no e-mail, mas ao clicar aparece "Link invalido ou expirado". Mesmo assim o dono conseguiu dar continuidade e acessar o app.
- **Diagnóstico (passo 0, logs do Fly `mentall-api` em 03/09 21:37–21:39 UTC):** evidência inequívoca de **múltiplos `GET /auth/confirmar-email`** para o mesmo cadastro. O **1º hit ativou a conta (`200`, log `Email confirmado: id=...`)**; os hits seguintes retornaram **`400`** porque o token já tinha sido consumido. Como a ativação **já tinha ocorrido**, o login passava — daí a aparente contradição.
- **Causa raiz:** `confirmar_email` (`backend/services/usuarios.py`) usava **token de uso único consumido num GET não-idempotente**. O 1º hit zerava `email_verificacao_token_hash`; o 2º/3º clique (duplo toque no celular, scanner de segurança do e-mail, reabrir o link) não encontrava mais o hash → página "Link invalido ou expirado". **Não** era problema de codificação de URL (token usa só `[A-Za-z0-9_-]`, sem `=`) nem furo no login (a rota `/auth/login` bloqueia conta `pendente` com 403).
- **Decisão do dono (pergunta feita):** manter o **link mágico** (padrão one-tap de signup) em vez de trocar por código de confirmação. A fragilidade do link é **operacional** (token na query string + sem idempotência), não criptográfica (token é `token_urlsafe(32)` ≈ 256 bits).

### Fix (TDD — teste RED antes)
- **`backend/services/usuarios.py::confirmar_email`** — agora **idempotente**: NÃO zera mais o token ao confirmar (fica válido até `email_verificacao_expiracao`); se a conta já estiver `ativo`, apenas retorna sucesso (em vez de `None`/inválido). Token expirado/desconhecido continua inválido.
- **`backend/main.py`** — página de confirmação: "Sua conta está ativa. Volte ao app e toque em 'Ja confirmei' para entrar." (vale tanto para ativação quanto para re-clique).
- **Testes:** novo `backend/tests/test_confirmar_email.py` (5) com `_FakeDb` em memória que executa fielmente as queries (é o SQL que decide se o hash sai da lookup). RED reproduziu o re-clique com None; GREEN após o fix. Backend **137/137**.
- **Sem mudança Dart** (app já trata 403/sucesso corretamente).

## Correções e Funcionalidades (03/09/2026) — DESBLOQUEIO POR BIOMETRIA "NÃO FOI POSSÍVEL AUTENTICAR"

### Bug reportado (dono): após acessar com e-mail/senha, ao sair do app e voltar, não autentica
- **Sintoma:** o dono loga na conta (e-mail/senha), usa o app, sai e retorna → tela "Acesso protegido" com **"Não foi possível autenticar. Tente novamente."**
- **Localização:** logs do Fly mostram **backend 100% saudável** (nenhum 401; `POST /auth/login` 200 nas 21:40/21:47/22:00 de 03/09). O problema é **apenas o desbloqueio local da chave**, não a sessão do servidor.
- **Causa raiz:** o fluxo `didChangeAppLifecycleState(paused)` → `AuthService.bloquear()` zera o token e apaga o JWT; ao voltar, o `LoginPage` desbloqueia via `carregarChaveDoSecureStorage()`. Para **instalações atualizadas (APK por cima)**, o boot (`main.dart:121`) **não roda `gerarChave()`** (já existe `possuiChaveProtegida`); a migração antiga `marcarProtecaoDuravel()` só gravava o **marcador** `chave_duravel` e **NÃO copiava a chave para o cofre durável `_duravel`**. Com `_duravel` vazio, o desbloqueio dependia 100% do **gate de biometria/credencial** (`_pin`); quando esse gate falha (biometria indisponível/invalidada) → `carregarChaveDoSecureStorage()` retorna `false` → "Não foi possível autenticar".
- **Decisão:** manter a autenticação ao voltar (não reverter a vuln-0013), mas garantir que o desbloqueio funcione pelo cofre durável **sem depender do gate**.

### Fix (TDD — teste RED antes)
- **`lib/services/encryption_service.dart`:**
  1. `marcarProtecaoDuravel()` agora faz a **migração de verdade**: além de gravar o marcador, se `_key == null` chama `carregarChaveDoSecureStorage()` (que faz backfill da chave no cofre durável), garantindo que `_duravel` sempre fique preenchido em instalações legadas.
  2. `carregarChaveDoSecureStorage()` passou a **ler o cofre durável PRIMEIRO** (fonte primária, sem exigir biometria) e só depois o **gate** `_pin` — o desbloqueio nunca mais depende da biometria para uma chave já durável.
- **Testes:** `+2` em `test/services/encryption_service_test.dart` (migração legada popula o cofre durável; e não lança sem chave), ambos com `_MemStorage`. RED reproduziu (`_duravel` vazio) → GREEN. Suíte Flutter **171/171**; `flutter analyze` limpo (1 warning pré-existente em `tools/`).
- **APK:** bump `1.0.31+32` → **`1.0.32+33`** (`MentAllPRO-v1.0.32.apk`, ~75.7 MB).

### Pendência relacionada (não incluída neste fix — combinar depois)
- O login de conta (`ApiClient.entrarComEmailSenha`) grava credenciais no `app_config` mas **não chama `AuthService.salvarCredenciaisServidor()`** (SecureStorage), que é o que `tentarAutoLoginServidor()` lê. Não é o sintoma reportado e o fluxo real de reautenticação funciona via `ensureAuthenticated` (evidência: 3× re-login 200). Incluir exigiria refactor de fronteira (injetar storage/http) sem teste.

## Correções e Funcionalidades (03/09/2026) — UI DA TELA DE PERFIL PROFISSIONAL

### Ajustes solicitados (dono)
- **Cabeçalho (perfil novo):** removido "Bem-vindo ao MentAll PRO"; novo texto **"O app MentAll Pro valoriza a abordagem psicológica que você atua! Configure agora o seu perfil profissional:"**, estilo **normal e centralizado** (antes havia texto justificado + título em negrito).
- **Labels sempre visíveis:** `floatingLabelBehavior: FloatingLabelBehavior.always` nos 5 campos do cabeçalho (Nome profissional, Registro profissional - CRP, Abordagem clínica principal, Como se referir, Tratamento).
- **"Escolher" dentro das 3 caixas suspensas** (Abordagem, Como se referir, Tratamento) — via `hintText`. Para Como se referir e Tratamento exibirem "Escolher", os `StateProvider` `_termoProvider`/`_tratamentoProvider` passaram a começar **vazios** (antes `'paciente'`/`'masculino'`); o `initialValue` vira `null` para não descasar dos itens, e o `TermoPessoaAtendida.fromString('')`/`perfil_profissional_service` mantêm fallback seguro (`paciente`/`masculino`). No perfil já existente (edição), `initState` continua preenchendo com o valor salvo.
- **Registro profissional:** `hintText` → **"Ex.: 00/000000"** (antes `00/00000`); dentro da caixa fica só o exemplo, com a label sempre visível acima.
- **Tipografia dos dropdowns:** `style` padronizado (`fontSize: Tipografia.base`, `corTextoBody`) — itens e valor selecionado uniformes.
- **Escopo:** só os 5 campos do cabeçalho + 3 dropdowns + textos do cabeçalho. **NÃO** mexeu nos campos de Endereço nem em outras telas.
- **Arquivo:** `lib/screens/perfil_profissional_form_page.dart`.
- **Testes:** `perfil_form_page_test.dart` (texto novo + "Escolher" ×3 + "Ex.: 00/000000") e `app_start_page_test.dart` (2 asserts do texto antigo → novo). Suíte Flutter **171/171**; `flutter analyze` limpo (1 warning pré-existente em `tools/`).
- **APK:** bump `1.0.32+33` → **`1.0.33+34`** (`MentAllPRO-v1.0.33.apk`, ~75.7 MB).

### Ajustes complementares (dono, mesma sessão)
- **Tratamento:** dropdown reordenado para **Feminino → Masculino**.
- **Tipografia uniforme:** todos os textos **dentro das caixas do cabeçalho** agora usam **`Tipografia.base` (14px)** — os 2 `TextField` (Nome, Registro) ganharam `style` + `hintStyle` 14px (mesma fonte/cor dos dropdowns, que já eram 14px). Antes os TextFields usavam o padrão do tema (~16px via `bodyLarge`).
- **APK:** bump `1.0.33+34` → **`1.0.34+35`** (`MentAllPRO-v1.0.34.apk`, ~75.7 MB). Suíte Flutter **171/171**; `analyze` limpo.

## Correções e Funcionalidades (30/08/2026) — PENTEST STRIX 2º SCAN (MODO DEEP) + FIX TABCONTROLLER

### 2º scan Strix (30/08/2026) — 21 achados (7 High, 12 Medium, 2 Low)
- **Comando:** `strix -n -t /tmp/strix-target --scan-mode deep --max-budget 10` (checkout limpo `git archive HEAD`). Run `strix_runs/strix-target_8081/`. 294 requests LLM (~27,5M tokens, DeepSeek), status `completed`.
- **Validação das correções de 29/08:** NÃO reapareceram IDOR lembretes, PIN-recovery brute-forçável, senha fraca, backup plaintext, badge CRP falseável nem os CVEs de `python-multipart`/`requests`/`python-dotenv`. Os 21 achados novos são de maior profundidade (modo deep).
- **7 High:** CVE `starlette 0.41.3` via `fastapi==0.115.6` (Range ReDoS, form bypass, Host header, multipart) + CVE `pyasn1 0.4.8`/`ecdsa 0.19.2` via `python-jose==3.4.0` (4 DoS + Minerva). **Todos resolvidos** (ver supply-chain abaixo).
- **12 Medium + 2 Low:** ver fixes abaixo.

### Fix: TabController da aba Arquivadas (bug do dia: "todas as sessões sumiram")
- **Sintoma (30/08):** ao arquivar a 1ª sessão de um paciente, a aba Sessões da ficha crashava com "Erro inesperado" persistente (mesmo reiniciando). As sessões NÃO eram perdidas — só o flag `arquivada=true` persistia.
- **Causa raiz:** `PacienteSessoesTab` renderizava `TabBar`/`TabBarView` interno (Ativas/Arquivadas) **sem `TabController`** e sem `DefaultTabController` ancestral. Em release, `_controller` fica `null` → `_controller!.index` crasha → `ErrorWidget.builder` (`main.dart`). O caminho com tabs só era construído quando havia ≥1 arquivada — por isso só aparecia após a 1ª arquivada e persistia no restart.
- **Fix:** `lib/widgets/paciente_sessoes_tab.dart` → envolver o `Card` (com `TabBar`+`TabBarView`) em `DefaultTabController(length: 2, ...)`.
- **Testes:** novo em `test/widgets/paciente_detail_page_test.dart` ("deve exibir abas Ativas/Arquivadas sem erro..."). RED falhou com `No TabController for TabBar`; GREEN passou. Suíte Flutter: **156/156**.

### Correções do 2º scan (TDD — testes RED antes de cada fix)
- **IDOR `/auth/registrar-recuperacao` (Medium, vuln-0011):** qualquer JWT sobrescrevia `recovery_token` de outro e-mail (chave `sha256(email)`). `registrar_recuperacao` agora recebe `auth` e rejeita `403` se `request.email` ≠ `username` do JWT; rota sem `dependencies` (evita dupla autenticação). Tests: `backend/tests/test_recuperacao_idor.py` (3).
- **IDOR `GET /contratos/{token}/status` e `GET /anamneses/{token}/status` (Medium, vuln-0012):** liam dados clínicos de outro profissional (respostas completas da anamnese). Handlers agora checam `owner_id` e retornam "não encontrado" em mismatch (sem vazar existência). Tests: `backend/tests/test_status_idor.py` (4).
- **Stored XSS na anamnese (Medium, vuln-0021):** a correção de 29/08 protegeu o bloco `<script>`, mas `anamnese.html` interpolava `q.min`/`q.max` (injeção de atributos `onfocus`+`autofocus`) e `q.id` em `onclick` (escape sem aspas simples). Fix: `parseInt` coercive com swap min/max; `esc()` agora escapa `'`; `toggleYn(this, valor)` resolve o id via `closest('.pergunta').getAttribute('data-id')`. Tests: `test_anamnese_xss.py` ampliado (9).
- **Prompt injection (Medium, vuln-0018):** `_sanitizar_prompt` (blocklist de 5 regex) não cobria todos os campos. `INJECAO_PADROES` reforçado (ignore all/everything, answer/act as, you are now, override prompt); aplicado em `gerar_progresso` (sintese/relato/intervencoes/escalas) e `_rerankear_artigos` (contexto_clinico). Tests: `backend/tests/test_prompt_injection.py` (6).
- **Prompt injection — variantes (30/08, re-verificação scoped):** o Strix re-verificou os PoCs e achou 2 variantes: (a) `termo_pessoa_atendida`/`abordagem_clinica` interpolados crus em `_montar_prompt_sintese` (o `termo.capitalize()` não neutraliza; o blocklist não cobria `forget all previous instructions`/`output the system prompt verbatim`/`ignore the system prompt`); (b) sub-campos de `gerar_progresso` (`sessoes_anteriores[].numero/.data`, `escalas[].datas[].data/.pontuacao`, `sessao_atual.data`) interpolados crus. Fix definitivo (allowlist + tipagem, não só blocklist): `SinteseRequest` com `field_validator` que rejeita `termo_pessoa_atendida` fora de `TERMOS_PESSOA_ATENDIDA={paciente,cliente,pessoa atendida}` e `abordagem_clinica` fora de `PROMPTS_ABORDAGEM` (HTTP 422); `_montar_prompt_sintese` resolve ambos para defaults seguros (`paciente`/`Integrativa`) por defesa em profundidade; `ProgressoRequest` com validators que rejeitam `numero` não-numérico, `data` não-ISO e `pontuacao` não-numérica; `INJECAO_PADROES` ampliado (forget/system prompt/output). Tests: `test_prompt_injection.py` **20** (incl. schema allowlist + sub-campos). Re-verificação Strix final (`strix-target_d751`): **0 vulnerabilidades** — 4 critérios passam, PoCs re-executados retornam 422/`[removido]`.
- **Rate-limit bypass X-Forwarded-For (Medium, vuln-0019):** `_cliente_ip` confiava no último XFF sem validar proxy → rotação burlava limites. Agora só confia em XFF quando o socket peer está em `TRUSTED_PROXIES` (env, CIDR/IP) **ou** é IP privado/link-local (edge do Fly na rede 6PN); valida `ipaddress`; caso contrário usa o socket peer. Tests: `test_rate_limit.py` atualizado (12, inclui o cenário exato do Strix).
- **Webhook token na query string (Medium, vuln-0020):** `?token=` ia para access logs. Agora `Authorization: Bearer` é preferido; query string mantida só como fallback de transição; comparação com `secrets.compare_digest`. Helpers `_extrair_token_webhook`/`_token_webhook_valido`. Tests: `test_webhook_wuzapi.py` (+6, 21 total).
- **CVE supply-chain (7 High + 3 Medium/Low):** `requirements.txt` — `fastapi 0.115.6→0.120.1` (+ `starlette>=0.49.1`, resolve 0.49.3), `python-jose[cryptography]==3.4.0` → **`PyJWT>=2.10,<3`** (remove pyasn1/ecdsa). `main.py`: `from jose import JWTError, jwt` → `import jwt` + `from jwt.exceptions import InvalidTokenError as JWTError`. Boot validado + backend 118/118.
- **JWT persistido em texto puro (Medium, vuln-0014):** `AuthService.autenticarBackend` gravava `jwt_token` em claro quando `tryEncrypt` retornava null. Agora: se não criptografa, deleta a chave e mantém em memória (padrão do `ApiClient`). Teste novo `test/services/auth_service_test.dart` (injetou `http.Client` opcional no método para mockar).
- **`mensagemLembrete` sem criptografia (Medium, vuln-0015):** `CompromissoService` só cifrava `titulo`/`observacoes`. Adicionado `mensagemLembrete` a `_encryptCompromisso`/`_decryptCompromisso` e aos 3 pontos de cópia ao persistir (`adicionar`, recorrência, `atualizar`) + `removerCriptografiaExistente`.
- **Logs/auditoria com PII em claro (Medium, vuln-0016):** `logger.dart` — `debugPrint` agora com guarda `kDebugMode`; conteúdo do box `logs_tecnicos` cifrado quando a criptografia está ativa. `AuditoriaService.registrar` loga só o `tipoEvento` no log técnico (a descrição com nome do paciente fica apenas no box de auditoria cifrado).
- **Inactivity auto-lock (Low, vuln-0017):** o timer de 5 min existia em `bc5c7b1` mas foi removido em `4f10804` (migração Fly). Restaurado em `app_start_page.dart` (`_inactivityTimer`, `_resetarInactivityTimer`, `_bloquearPorInatividade`) + `Listener` no `MaterialApp.builder` de `main.dart` (`AppStartPage.onUserActivity`). Teste novo em `app_start_page_test.dart` (mock `_FakeAuthService extends AuthService`).
- **Criptografia fail-open (Medium, vuln-0013, parcial):** `EncryptionService.gerarChave()` agora retorna `false` quando a chave NÃO foi durável (secure storage indisponível); `main.dart` loga auditoria de aviso. **Decisão de produto pendente (dono):** bloquear completamente o app sem proteção durável (fail-closed) — hoje dados clínicos podem ficar em texto puro em dispositivos sem bloqueio de tela/biometria (ex.: tablet clínico). O relatório recomenda tela de setup obrigatória; não aplicado para não quebrar fluxos existentes.

### Verificação
- Backend **132/132** (era 89/89; novos: recuperacao_idor 3, status_idor 4, prompt_injection 20, token webhook 6).
- Flutter **156/156** (era 154; novos: auth_service_test 1, app_start inactivity 1).
- `flutter analyze` limpo (1 warning pré-existente em `tools/`).
- **Re-verificação Strix scoped final** (`strix_runs/strix-target_d751/`, instruction focada): **0 vulnerabilidades restantes** — IDORs, XSS anamnese, prompt injection (todas as variantes), rate-limit XFF, webhook token, supply-chain e achados Flutter confirmados fechados.
- APK: **`1.0.27+28` → `1.0.28+29`** (`MentAllPRO-v1.0.28.apk` gerado). Checklist de loja criado em `tasks/lojas_app.md`.

### Pendências (decisão do dono)
1. ~~**Fail-closed de criptografia (vuln-0013):** bloquear app sem proteção durável + indicador de proteção ativa/inativa na Home e Configurações.~~ ✅ **implementado em 02/09/2026** (cofre durável Keystore sem exigir biometria + fail-closed + indicador). Não bloqueia mais publicação neste ponto.
2. **CSP `script-src 'unsafe-inline'`** no backend (recomendação do relatório para harden futuro).
3. ~~Re-verificação Strix scoped das correções~~ ✅ **concluída em 30/08** (`strix_runs/strix-target_d751/`): 0 vulnerabilidades restantes.
4. **`TRUSTED_PROXIES` no deploy:** `.env`/secrets do Fly precisam ganhar os IPs do edge do Fly (rate-limit por IP atrás do proxy). Sem isso, o rate-limit perde a distinção por IP real no deploy.

## Correções e Funcionalidades (31/08/2026) — SUPPLY-CHAIN (TRAIL OF BITS) + DEPENDÊNCIAS (fastapi/starlette/google-genai)

### Nova skill: Trail of Bits `supply-chain-risk-auditor` (vendored, local)
- Skill do marketplace **`trailofbits/skills`** (CC BY-SA 4.0) copiada para `.opencode/skills/supply-chain-risk-auditor/` (SKILL.md + scripts/ com pyproject/uv.lock + assets + agents). **Só essa** foi instalada (as demais — smart-contracts, C/Rust, YARA, DWARF — irrelevantes para o stack Flutter/Python).
- **Atenção — o opencode NÃO tem `/plugin marketplace`:** skills são lidas de `**/SKILL.md` sob `skills.paths` (padrão `.opencode/skills`; NADA mudou no `opencode.json` — só o `permission.skill: allow`).
- `.opencode/` é **gitignored** (linha 7) → a skill fica **local**, como as do Strix (não entra no repo). **Reiniciar o opencode** para ativar.
- `DEVREADME.md` no diretório da skill com a atribuição CC BY-SA 4.0 (Trail of Bits).
- **Decisão do dono (31/08):** instalar só a supply-chain; `static-analysis`/semgrep **só se** virar gate de CI; `modern-python` e `second-opinion` **adiadas** (a segunda bloqueada: sem `codex`/`gemini` CLI e usa `--yolo` auto-approve em app clínico).

### Auditoria de supply-chain — achado REAL revelado pelo pin exato
- Rodada inicial (antes dos fixes): 16 deps diretas; **`google-genai==1.12.0` yanked** no PyPI (único achado que chegava a produção) + 6 deps em range avaliadas contra o "latest" em vez do instalado.
- **⚠️ Correção à memória de 30/08:** a nota "starlette CVEs **todos resolvidos** via fastapi 0.120.1 + `starlette>=0.49.1`" estava **incompleta/incorreta**. Com pino exato + OSV: **`starlette 0.49.3` (linha 0.x) ainda tem 10 advisories** (StaticFiles SSRF/NTLM via UNC, Host-header poisoning, HTTP method dispatch arbitrário em `HTTPEndpoint`, `request.form()` limits ignorados). A linha 0.x (até 0.50.0) **nunca** é corrigida — o fix está **só na 1.x** (1.6.0 = 0). `fastapi==0.120.1` travava `starlette<0.50.0`, bloqueando o upgrade.
- **Fix aplicado (Fase 2):** `fastapi 0.120.1→0.135.0` (**menor** versão que solta o teto; `starlette>=0.46.0` sem teto) + `starlette 0.49.3→1.6.0` (= **0 advisories**). O "no topo" (`0.141.1`/`2.20.0`) foi descartado por salto maior; escolhido o mínimo (mesmo resultado). `google-genai 1.12.0→1.75.0` (des-yank; última 1.x não-yanked; mesmo major = risco mínimo de API). Imports `from google import genai` / `import google.genai.types` validados.
- **Fase 1:** deps que estavam em range → pins nas versões instaladas (`openai==1.109.1`, `groq==1.6.0`, `PyJWT==2.13.0`, `Pillow==12.3.0`, `libsql==0.1.11`, `starlette`). `PyJWT` mantido (não voltar p/ `python-jose` — pyasn1/ecdsa com CVEs).
- **Portão de verificação:** `uv pip check` 49/49 OK · boot/import `main` OK (Turso) · suíte backend **132/132** · `test_sintese` 8/8 · chamada real **DeepSeek** OK (`{"sintese":"teste ok"}`) — Gemini deu 503 transitório de "high demand" (comportamento conhecido, NÃO é regressão) · **webhook `/wuzapi/webhook` processou `Message` em runtime** (valida o caminho `form()` do starlette 1.x).
- **Re-auditoria final:** **0 dependências com flag** — "No known advisory affects any of the 16 direct dependencies, checked at the versions this project resolves".
- Backend local reiniciado (`launchctl kickstart -k gui/$(id -u)/com.mentall.backend`) — serviço saudável (Turso, scheduler, uvicorn, webhook).
- **Gap remanescente:** árvore transitiva ainda não examinada (sem `uv.lock`). **Decisão do dono: ADIADO** (plano separado com `modern-python`/pyproject).

### Commits (31/08, locais, SEM push)
1. `9b10b21` `security(backend): fortalece dependencias e zera CVEs de supply-chain` (Fase 1+2).
2. `1f7a833` `security: corrige achados do 2o pentest Strix + auditoria (30/08)` (26 arquivos código/testes pendentes; escolha do dono "só código/testes").
3. `ee0d244` `chore: remove arquivos de referencia/marketing obsoletos` (10 deleções: LGPD txt, logos, apresentação, PROMPT `.lnk`/`.txt`, ACORDO docx, `security_fixes_2026_08.md`, `flutter_01.png` — recuperáveis via `git restore`).

## Correções e Funcionalidades (02/09/2026) — FAIL-CLOSED DE CRIPTOGRAFIA (VULN-0013) + INDICADOR DE PROTEÇÃO

**Pendência de produto (dono) resolvida.** Decisões documentadas antes de implementar (pesquisa com fontes: `flutter_secure_storage` docs, Bitwarden KDF/unlock-with-PIN, OWASP Password Storage Cheat Sheet).

### Contexto (por que a vuln existia)
- A chave mestra era persistida só em `_secureStoragePin`/`_secureStorageBiometria` com `AndroidOptions.biometric(enforceBiometrics: true)`. Em dispositivo **sem biometria/tela bloqueada**, o `write` lançava exceção → `gerarChave()` retornava `false` → chave só em memória → `tryEncrypt` devolvia `null` → **dados clínicos em texto puro** (fail-open) naquele dispositivo. Era o cenário "tablet de clínica compartilhado".

### Pesquisa (resumo das fontes)
- **`flutter_secure_storage`:** `AndroidOptions()` (default) usa **RSA OAEP + AES-GCM no Android Keystore** e **NÃO exige biometria** — funciona em qualquer aparelho e continua hardware-backed/rápido. `enforceBiometrics: true` exige biometria e **lança exceção** se não houver (é a causa do fail-open).
- **Bitwarden:** a derivação cara (KDF/PBKDF2) é para o **login**; o **desbloqueio diário** lê a chave do cofre do sistema (rápido, sem KDF). Padrão de "envelope encryption". Também documenta o trade-off: PIN pode enfraquecer a proteção local.
- **OWASP:** hash de senha deve levar < 1 segundo; o custo alto (vários segundos) da versão antiga de PIN vinha de PBKDF2 repetido a cada abertura na UI.

### Implementação
- **`lib/services/encryption_service.dart`:**
  - Novo cofre durável `_secureStorageDuravel = FlutterSecureStorage(aOptions: AndroidOptions())` (Keystore sem exigir biometria — RSA OAEP + AES-GCM).
  - `gerarChave()` agora persiste a chave **obrigatoriamente** no cofre durável (funciona sem biometria); o `_secureStoragePin` (com prompt) vira **gate opcional** (best-effort). Retorna `true` só com persistência durável.
  - `carregarChaveDoSecureStorage()` tenta biometria → credencial do dispositivo → **fallback durável** (cobre aparelhos onde os 2 primeiros falham). Sempre consegue carregar a chave → nunca mais texto puro.
  - `migrarChaveDoPinLegado()` e `limpar()` também passam a gravar/remover no cofre durável.
  - Novo getter `bool get protecaoDuravel` (marcador `chave_duravel`) + `marcarProtecaoDuravel()` + `observar()` (stream p/ providers).
- **Fail-closed (`lib/main.dart`):** quando `gerarChave()` não consegue durabilidade → `EncryptionService.protecaoIndisponivel = true` (não grava em texto puro). Instalações antigas (chave já existe) → `marcarProtecaoDuravel()` (backfill, evita falso bloqueio no upgrade).
  - **`lib/screens/app_start_page.dart`:** tela de bloqueio "Proteção de dados indisponível" com botão "Tentar novamente" quando `protecaoIndisponivel`.
- **Indicador de proteção (ativa/inativa):**
  - `protecaoDuravelProvider` (StreamProvider reativo via `encryption_meta`) em `lib/providers/service_providers.dart`.
  - **Configurações → Segurança:** chip "Proteção de dados" (verde ativa / laranja inativa).
  - **Home:** chip "Proteção de dados ativa/inativa" (toca → abre Configurações) logo abaixo da saudação.

### Segurança/performance
- Sem KDF na UI: desbloqueio continua lendo a chave do cofre do sistema (rápido). A durabilidade não depende mais de o aparelho ter biometria/tela bloqueada.
- Trade-off aceito (padrão Bitwarden): em dispositivo sem tela bloqueada, a chave no Keystore protege contra acesso offline ao storage (nada de texto puro), mas não há "gate" de biometria — o gate só existe para aparelhos que suportam.

### Verificação
- Testes novos em `test/services/encryption_service_test.dart` (3: `protecaoDuravel` inicial false; `gerarChave` retorna false sem persistência durável = sinal de fail-closed; `protecaoDuravel` reflete marcador).
- `flutter analyze`: limpo (1 warning pré-existente em `tools/gerar_prompts_ia_pdf.dart`).
- Suíte Flutter: **159/159** (era 156; +3 da criptografia). `sessao_form_page_test`: flake conhecido do tap (warn), não é falha.

## Decisões e plano (02/09/2026) — TELECONSULTA (ainda NÃO implementada)

Pesquisa de mercado + viabilidade técnica + custos para a feature de teleconsulta (vídeo). **Escopo decidido pelo dono: sem gravação/transcrição — a chamada fica separada do fluxo de IA (a mídia NÃO vai para a IA).**

### Contexto de mercado (Brasil)
- Concorrentes diretos (prontuário/gestão p/ psicólogos): **Corpora** (Grátis + R$89), **Copilloto** (R$99/139), **PsiLuz** (preço dinâmico), **PsicoPront** (R$79; Carnê Leão/Receita Saúde), **ProntusCare** (R$39,90/79,90/119,90). Todos têm teleconsulta, portal do paciente, IA, assinatura digital; **todos web/cloud**.
- Diferencial do MentAll: **offline-first + dados no aparelho + LGPD**; gap principal: **sem teleconsulta, sem portal do paciente, sem assinatura com validade jurídica, sem Receita Saúde/Carnê Leão, sem web/iOS**.

### Decisão técnica — LiveKit (SDK `livekit_client` 2.x, ativo; Android+iOS+Web)
- `jitsi_meet` 4.0 está **descontinuado** (→ `jitsi_meet_wrapper`); `daily_flutter` é pago/terceirizado e dados fora do BR. **Escolhido LiveKit.**
- **Hospedagem configurável por env:** `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`. Recomendação: iniciar em **VPS BR pequena (~R$ 60–120/mês)**; LiveKit Cloud como alternativa. ⚠️ **Fly.io NÃO serve bem p/ WebRTC** (limitações de UDP) — a mídia vai para infra separada.
- **Arquitetura:** `Compromisso` ganha `@HiveField(17) bool? teleconsulta` + `@HiveField(18) String? salaId` (room uuid). Backend espelha o padrão de `/contratos/{token}`: `POST /consultas` (JWT → cria sala + token curto LiveKit) e `GET /consulta/{room_id}` (página HTML do paciente com cliente Web LiveKit). App: `TeleconsultaPage` com `livekit_client` + permissões Android `CAMERA`/`MODIFY_AUDIO_SETTINGS`/`BLUETOOTH_CONNECT`. Compartilhar link via `WhatsAppService.escolher` (já existe).
- **Segurança/LGPD:** sala uuid não adivinhável; token curto (~30 min) por sala+identidade; HTTPS; **não logar URL com token**; gravação OFF.

### Custos mapeados (100 profissionais, 20 pacientes × 4 sessões/mês = 80 sessões/prof, ~800.000 min WebRTC/mês, pico ~35–60 chamadas)
- **LiveKit Cloud:** Ship ~**R$ 1.875/mês** | Scale ~**R$ 2.500/mês** (+HIPAA, region pinning, relatórios). Dados fora do Brasil (EUA/EU).
- **Self-hosted DigitalOcean São Paulo:** 1 servidor ~**R$ 550–875/mês** | HA (cluster) ~**R$ 1.250–2.500/mês**. Dados no Brasil (LGPD).
- **Conclusão:** em 100 profissionais, **self-host (1 servidor) é mais barato + LGPD-friendly**; para confiabilidade o HA empata com o Cloud. Documento detalhado (com tabelas e premissas) em **`docs/custos_teleconsulta.md`**.

### Pendência em aberto (decisão do sócio)
1. Posicionamento: "dados no Brasil" como argumento central de venda?
2. Custo-alvo mensal para 100 profissionais (até R$ 875 / R$ 1.875 / R$ 2.500)?
3. Atender clínicas/corporativo (→ HIPAA/Scale)?
4. Horizonte do crescimento para 100 profissionais (define HA agora ou depois).

## Correções e Funcionalidades (02/09/2026) — FIX DE DESBLOQUEIO POR BIOMETRIA + BACKUP CONFIGURÁVEL

**Bug crítico (dono):** após atualizar para `1.0.29`, o app não autenticava ("Não foi possível autenticar"), mesmo com digital cadastrada e sem o usuário ter alterado biometria/senha.

### Causa raiz (desbloqueio)
- `carregarChaveDoSecureStorage()` tinha um **`return false` prematuro** na etapa do cofre `enforceBiometrics: true`, que **impedia o fallback do cofre durável**. Em instalação antiga, a chave só existia no cofre biométrico/credencial; o cofre **durável** (adicionado em 02/09 para a vuln-0013) ficava **vazio** (pois `gerarChave` não roda de novo quando `possuiChaveProtegida` já é true). Resultado: ao falhar o gate, nada o resgatava → lockout.
- A camada `_secureStorageBiometria` (strong-only) era **morta** (nunca recebia a chave) e causava o prompt duplo que confundia.

### Fix (A — socorro)
- `carregarChaveDoSecureStorage()` reescrito: tenta o gate (`_pin`, `biometricOrDeviceCredential`) → **se falhar/vazio, cai no cofre durável** (sem `return false` prematuro). Ao carregar, faz **backfill** da chave para o cofre durável + marca `chave_duravel` (migração de instalações antigas — nunca mais trava por biometria).
- Removida a camada forte morta; cofres (`_pin`, `_duravel`) agora **injetáveis** (construtor com `pin`/`duravel`) para testes.
- **Testes:** `test/services/encryption_service_test.dart` +4 (`_MemStorage` fake: chave do gate + backfill; fallback com gate vazio; gate lança erro → durável; ambos vazios → false sem lançar).
- **APK:** `1.0.29+30` → `1.0.30+31` (`MentAllPRO-v1.0.30.apk`) — build de socorro.

### Fix (B — backup configurável — solicitado pelo dono)
- **Local:** `ConfiguracoesService.backupLocal` (pasta escolhida via `file_picker.getDirectoryPath`; vazio = documentos do app).
- **Tempo:** `ConfiguracoesService.backupFrequencia` (`off`/`diario`/`semanal`/`mensal`) + `ultimoBackupEm` (ISO). Regra pura `BackupAgendamentoService.deveExecutarAgora` (null+ativa=dispara; diário≥1d, semanal≥7d, mensal≥30d).
- **Execução:** `BackupAgendamentoService.executar` escreve JSON (via `BackupService.exportarParaJson`, cifrado com envelope AES-GCM+HMAC quando a criptografia está ativa) no local configurado + atualiza `ultimoBackupEm`. `verificarEExecutar` roda a cada abertura da Home (post-frame); default `off` = sem efeito.
- **Armazenamento condicional:** `lib/services/backup_storage.dart` (io/web), para não quebrar o build web. UI em **Configurações → Backup e dados** (frequência, local, último backup + aviso de atraso, "Fazer agora").
- **Testes:** novos `test/services/backup_agendamento_service_test.dart` (6). Suíte **169/169**; `flutter analyze` limpo (1 warning pré-existente em `tools/`).
- **APK:** `1.0.30+31` → `1.0.31+32` (`MentAllPRO-v1.0.31.apk`) — inclui A + B.

### ⚠️ Nota ao dono (lockout já ocorrido)
- Se o keystore da biometria tiver sido invalidado e você **não tinha backup**, os dados criptografados antigos podem ser irrecuperáveis. **Instale o `1.0.31` agora**: se a digital autenticar uma vez, a chave é copiada para o cofre durável e o acesso fica garantido. Ative o **backup automático** para evitar perda futura.

## Checklist de publicação nas lojas de app (Google Play / App Store)
- **Pendências de segurança pendentes ANTES de publicar** (ver `tasks/lojas_app.md`): ~~fail-closed de criptografia (vuln-0013) + indicador de proteção~~ ✅ **implementado em 02/09/2026**; CSP `unsafe-inline` no backend; `TRUSTED_PROXIES` no Fly; normalizar `render.yaml`/`start_backend.sh` para `--proxy-headers`; definir `TRUSTED_PROXIES` no `.env`.
- **Pendências técnicas de loja:** ícone adaptativo/legacy atualizado, telas de captura (screenshots), descrição, categorias, política de privacidade, termos de uso, nota da LGPD (dados sensíveis de saúde), CPI da conta de desenvolvedor, assinatura do release (keystore), plano de assinatura/RevenueCat (Fase 1 do plano de negócio).
- **Detalhes completos em `tasks/lojas_app.md`.**

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

## Histórico (arquivado)

Seções datadas anteriores a 29/08/2026 foram movidas para `docs/AGENTS_historico.md` (o git preserva tudo). Consulte lá para contexto antigo.
