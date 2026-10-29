# MentAll PRO — Prontuário Clínico com IA

> **Regra de comunicação (obrigatória):** o dono do projeto se chama **Rodrigo**. Toda resposta deve começar se dirigindo a ele como "Rodrigo".

> **Regra de trabalho (obrigatória):** ao receber **qualquer solicitação**, invocar obrigatoriamente a skill `using-agent-skills` **antes de qualquer leitura de código ou planejamento**. Ela apontará as demais skills aplicáveis (ex.: `planning-and-task-breakdown`, `test-driven-development`, `frontend-ui-engineering`, `debugging-and-error-recovery`), que devem ser invocadas em sequência antes de planejar e executar. Não iniciar análise, plano ou código sem ter passado por esse passo.

> **Regra de memória (obrigatória):** ao concluir **qualquer tarefa que altere o projeto** (código, config, documentação ou decisão), atualizar este `AGENTS.md` **automaticamente, sem esperar pedido** — inserindo uma **nova seção datada logo abaixo do CHECKLIST DE FUMAÇA** (mais recente no topo), no formato das seções existentes: **Contexto / O que mudou (arquivos) / Verificação (testes, analyze) / Pendências**. Não reescrever nem remover seções antigas; não incluir segredos nem PII; ser conciso (detalhes longos vão para `tasks/` ou para o commit). Sessões puramente conversacionais (sem mudança no projeto) não geram seção.

> **Regra de verificação (obrigatória):** toda afirmação sobre o código carrega seu **tipo de evidência** — `LI` (li as linhas citadas), `MEDI` (executei e obtive este número), `INFERI` (concluí de um padrão) ou `NÃO ENCONTREI` (procurei e não achei **nesta busca**). **Nenhuma ausência pode ser afirmada como fato:** sem um **controle positivo** — a mesma busca encontrando algo que se sabe estar lá —, o texto é "não encontrei", nunca "não existe". Para afirmar que algo está **implementado**, é obrigatório apontar o **ponto de imposição** (onde bloqueia ou altera o comportamento) e, quando existir, **o teste que falha se aquilo for removido**; a mera existência de flag, mensagem, tradução ou comentário **não prova comportamento**. Antes de editar **cada arquivo**, declarar: **(a)** o que foi lido, com a fronteira explícita do que **não** foi lido; **(b)** o que será alterado; **(c)** as dúvidas — e **dúvida é motivo para parar e perguntar**, nunca para resolver sozinho. Nunca usar `git add -A` (há sessões paralelas no mesmo repositório): adicionar **apenas** os arquivos alterados nesta sessão.

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

## Compressão do AGENTS.md — 28/10/2026

### Contexto
O dono aprovou a compressão: o `AGENTS.md` estava em ~248 KB e é truncado nas sessões. O
histórico antigo foi movido verbatim para `docs/AGENTS_historico.md`; aqui ficam as regras, o checklist,
as seções recentes da linha 2.0.x, o índice do histórico e as seções de referência.

### O que mudou (arquivos)
1. **`docs/AGENTS_historico.md` (novo)** — 94 seções antigas movidas verbatim (~201 KB).
2. **`AGENTS.md`** — de ~248 KB para ~54 KB; nova seção "Histórico comprimido" com o
   índice e as referências (projeto/stack/comandos) mantidas no fim.
3. **`MEMORIA_2.0.x_2026-10-28.md`** — aponta para o histórico comprimido.

### Verificação
- MEDI: seções `##` antes = 118; depois = 25 no AGENTS + 94 no histórico =
  119 (iguals antes/depois: False).
- MEDI: conteúdo movido é cópia verbatim (fatias do original); nada foi reescrito ou removido.
- Commit só de `**.md` — não dispara CI.

### Pendências
- Consultar `docs/AGENTS_historico.md` quando precisar do detalhe de uma tarefa antiga.


## Memória consolidada da linha 2.0.x — 28/10/2026

### Contexto
O dono pediu uma memória consolidada (o `AGENTS.md` já passou de 200 KB e é truncado nas sessões).

### O que mudou (arquivos)
1. **`MEMORIA_2.0.x_2026-10-28.md` (novo)** — estado atual: layout (original/backup), versão 2.0.4+64,
   tag `v2.0.4` (→ `e5be382`), o que mudou na UI, rotina de APK, backend local/produção e pendências.
2. **`AGENTS.md`** — esta seção.

### Verificação
- MEDI: fatos conferidos na escrita — versão `2.0.4+64`, HEAD `d0707be`, `master == origin/master`,
  tag `v2.0.4` → `e5be382`, APKs v2.0.4 (`05b7978a…`/`b95d7e13…`), `/health` local e produção 200.
- Commit só de documentação (`**.md`) — não dispara CI nem deploy.

### Pendências
- Comprimir o histórico antigo do `AGENTS.md` em `docs/AGENTS_historico.md` quando o dono quiser.

## Tag v2.0.4 criada e enviada — 28/10/2026

### Contexto
O dono pediu para marcar o release da linha visual 2.0.x no GitHub.

### O que mudou (arquivos)
1. **`AGENTS.md`** — esta seção.
2. **Tag anotada `v2.0.4`** no commit `e5be382` (objeto da tag `662afdd`), enviada ao `origin`
   (`refs/tags/v2.0.4`). Não existia nenhuma tag no repositório até aqui.

### Verificação
- MEDI: `git push origin v2.0.4` → `* [new tag] v2.0.4 -> v2.0.4`; `git ls-remote --tags origin v2.0.4`
  devolve o mesmo objeto (`662afdd`) do commit `e5be382`.
- MEDI: `master` local == `origin/master`; CI do push anterior passou (run `40863361107`, inclusive
  deploy no Fly).
- Por ser commit só de documentação (`**.md`), o `paths-ignore` do workflow não dispara CI.

### Pendências
- Opcional: criar GitHub Release a partir da tag (notas de versão) e/ou tags para os próximos ajustes
  (v2.0.5...).

## Push da linha visual 2.0.x para o GitHub — 28/10/2026

### Contexto
O dono pediu para enviar a linha visual 2.0.x ao GitHub. O push foi **fast-forward** (o `origin` estava
em `8b9edad`, ancestral do `master` local).

### O que mudou (arquivos)
1. **`AGENTS.md`** — esta seção.
2. **Remoto `origin/master`**: `8b9edad..d382083` — 21 commits (tema do painel, navbar, login/splash,
   correções de AppBar, foto do profissional na Home, versão 2.0.4+64, merge dos custos e docs do swap).

### Verificação
- MEDI: `git push origin master` → `8b9edad..d382083`; `local == remoto == d382083`; 0 à frente/atrás.
- MEDI: o CI do repositório (`.github/workflows/deploy.yml`) roda `flutter analyze` e `flutter test`
  em todo push.
- Backup (antigo original) continua intocado em
  `~/Documents/deepseek-harness/default-workspace/mentall-pro-app-copia`.

### Pendências
- Acompanhar o resultado do CI no GitHub; novo APK/PR só se o CI apontar algo.

## Promoção da cópia a original (swap de diretórios) — 28/10/2026

### Contexto
O dono pediu para trocar as pastas: a cópia de trabalho passou a ser o **projeto original** e o antigo
original virou backup. Antes do swap, os 2 commits de custos do antigo original (já no GitHub) foram
integrados por merge, para não regredir o backend.

### O que mudou (arquivos)
1. **Diretórios trocados (renomeações no mesmo volume, nada apagado):**
   - original agora em `/Users/rodrigolemos/mentall-pro-app` (era a cópia, versão 2.0.4+64);
   - antigo original (16 GB, com build/APKs) agora em
     `~/Documents/deepseek-harness/default-workspace/mentall-pro-app-copia`.
2. **Git do novo original:** `origin` → GitHub; novo remoto `backup` → antigo original; branch `master`
   20 commits à frente do GitHub (linha visual 2.0.x). Merge `354ae5a` integrou `e84ac60` + `8b9edad`
   (conflito só em `AGENTS.md`, mantidos os dois lados).
3. **`COPIA.md`** — reescrito para descrever o novo layout.
4. **Backend local (launchd)** — reiniciado pelo caminho novo; `GET /health` 200 (`sqlite_local`).

### Verificação
- MEDI: backend mesclado **532/532 OK** (`tests/run_isolated.py`); Flutter já verificado antes do swap
  (**analyze limpo**, **355/355 OK**, APK v2.0.4+64).
- MEDI: `/health` 200 após reinício; git do novo original limpo; backup limpo no HEAD `8b9edad`.
- Nada foi enviado ao GitHub (20 commits locais à frente).

### Pendências
- Push/PR da linha visual 2.0.x quando o dono decidir.
- Próximas edições do agente no original exigem aprovação de sandbox (fora do workspace).

## Foto da Home em dobro (v2.0.4) — 28/10/2026

### Contexto
O dono pediu para aumentar em **100%** o tamanho da foto do profissional na barra da Home.

### O que mudou (arquivos)
1. **`lib/screens/home_page.dart`** — avatar da foto: 46 → **92 px** (anel 2 → 3 px); `toolbarHeight`
   da Home: 80 → **104** para a foto caber sem corte. Logo de fallback (sem foto) segue em 78 px.
2. **`pubspec.yaml`** — `version: 2.0.4+64`.

### Verificação
- MEDI (28/10): `flutter analyze` → **No issues found**; `flutter test` → **355/355 OK**.
- MEDI: `aapt` confirma `versionCode=64 versionName=2.0.4`; assinaturas conferidas — debug
  `b63841f4…` (instala por cima) e produção `c2e5c85e…`; AAB regerado. APKs `v2.0.3` removidos da cópia.
- Nada foi enviado ao GitHub.

### Pendências
- Validar no aparelho: foto maior na Home (92 px) e barra mais alta (104 px).

## Foto do profissional na Home (v2.0.3) — 28/10/2026

### Contexto
O dono pediu para substituir a logo MentAll da Home pela **foto do profissional**.

### O que mudou (arquivos)
1. **`lib/screens/home_page.dart`** — AppBar da Home: se `perfil.fotoBase64` não estiver vazio, mostra a
   foto em avatar circular (46 px, anel na cor do card, `Semantics` "Foto do profissional", key
   `foto-profissional`); sem foto, mantém a logo MentAll como fallback.
2. **`test/widgets/home_page_test.dart`** — teste novo: perfil com foto renderiza o avatar (PNG 1x1
   embutido em base64 para o teste).
3. **`pubspec.yaml`** — `version: 2.0.3+63`.

### Verificação
- MEDI (28/10): `flutter analyze` → **No issues found**; `flutter test` → **355/355 OK** (354 + o
  teste novo da foto).
- MEDI: `aapt` confirma `versionCode=63 versionName=2.0.3`; assinaturas conferidas — debug
  `b63841f4…` (instala por cima) e produção `c2e5c85e…`; AAB regerado. APKs `v2.0.2` removidos da cópia.
- Nada foi enviado ao GitHub (código em `b6a24ac` + `0aec382`).

### Pendências
- Validar no aparelho: Home com a foto do perfil e fallback da logo sem foto.

## Barras superiores padronizadas no roxo (v2.0.2) — 28/10/2026

### Contexto
Dois problemas reportados no tema claro: (1) o título "Pacientes" saía **preto** na barra roxa;
(2) a tela **Agenda** tinha barra superior **branca**, diferente das demais telas principais. Causa: o
tema novo fixava `titleTextStyle` escuro no `AppBarTheme` e deixava o AppBar padrão branco.

### O que mudou (arquivos)
1. **`lib/main.dart`** — `AppBarTheme` volta ao padrão do app: fundo `colorScheme.primary` (roxo
   `#7C3AED`), `foregroundColor` branco, sem `titleTextStyle`/`iconTheme` fixos e sem borda inferior;
   assim título e ícones seguem a cor de cada tela e a Agenda fica igual às demais (Pacientes,
   Financeiro etc.).
2. **`pubspec.yaml`** — `version: 2.0.2+62` (versionCode 62).

### Verificação
- MEDI (28/10): `flutter analyze` → **No issues found**; `flutter test` → **354/354 OK**.
- MEDI: `aapt` confirma `versionCode=62 versionName=2.0.2`; assinaturas conferidas — debug
  `b63841f4…` (instalar por cima) e produção `c2e5c85e…`. APKs `v2.0.1` removidos da cópia.
- Nada foi enviado ao GitHub.

### Pendências
- Validar visualmente no aparelho: Pacientes (título branco), Agenda (barra roxa) e Home (barra cinza).

## Nova numeração de versão 2.0.1+61 — 28/10/2026

### Contexto
O dono pediu nova numeração para a linha visual, começando em **v2.0.1**. O `versionCode` 61 é maior
que o 60 anterior, então o APK atualiza por cima do app instalado preservando os dados.

### O que mudou (arquivos)
1. **`pubspec.yaml`** — `version: 2.0.1+61` (versionName 2.0.1 / versionCode 61).
2. Artefatos regerados (não versionados): `MentAllPRO-v2.0.1-debugsign.apk`,
   `MentAllPRO-v2.0.1-release.apk` e o AAB em `build/app/outputs/bundle/release/`.
   Os antigos `MentAllPRO-v1.0.59-visual*.apk` foram removidos da cópia para não confundir.

### Verificação
- MEDI (28/10): `flutter analyze` → **No issues found**; `flutter test` → **354/354 OK**.
- MEDI: `aapt` confirma `versionCode=61 versionName=2.0.1` nos dois APKs; assinaturas conferidas —
  debug `b63841f4…` (teste no aparelho) e produção `c2e5c85e…` (upload key).
- Nada foi enviado ao GitHub.

### Pendências
- Validar no aparelho a atualização 1.0.59 → 2.0.1 (instalar por cima, dados preservados).

## Barra superior da Home sem o topbar branco fixo — 28/10/2026

### Contexto
O dono pediu para retirar a barra superior "fixa" da Home (topbar branca com borda inferior) e deixar
a **mesma cor de fundo da tela** (cinza `#F3F5FB`). A mudança é só na Home; as demais telas mantêm o
topbar branco do painel.

### O que mudou (arquivos)
1. **`lib/screens/home_page.dart`** — AppBar da Home: `backgroundColor: context.corFundo`,
   `foregroundColor: context.corPrimaria` (ícones roxos, como antes) e `shape: const Border()` para
   anular a borda inferior herdada do `AppBarTheme`.

### Verificação
- MEDI (28/10): `flutter analyze` → **No issues found**; `flutter test` → **354/354 OK**.
- MEDI: APKs regerados e assinados — debug `b63841f4…` (instala por cima, preserva dados) e produção
  `c2e5c85e…`; AAB regerado. Nada foi enviado ao GitHub (2 commits à frente: `8325c02` + este).

### Pendências
- Validar visualmente no aparelho (Home com fundo contínuo, sem barra branca).

## Visual do app alinhado ao painel de controle — 28/10/2026

### Contexto
O dono pediu que a UI do app imitasse as **cores e o estilo do painel do dono**. A identidade do painel
(tema v2 em `backend/admin_ui.py`, variáveis CSS `--v2-*`) foi portada para o tema Material 3 do app.

### O que mudou (arquivos)
1. **`lib/utils/mentall_colors.dart`** — nova classe `PainelCores` (fonte única: roxo `#7C3AED`,
   gradientes, fundo `#F3F5FB`, card branco, borda `#E6EAF2`, sombra `0 10px 30px rgba(15,23,42,.06)`,
   semânticas ok/atenção/erro e escala do modo escuro) + tokens do extension remapeados.
2. **`lib/main.dart`** — `_criarTema` deixa o `ColorScheme.fromSeed` e passa a usar `_esquemaPainel`
   explícito (claro/escuro) + temas de AppBar, Card, botões, inputs, chips, diálogo, sheet, snackbar,
   FAB, navbar, list tile e popup menu.
3. **`lib/screens/main_shell.dart`** — navbar inferior com o gradiente da sidebar do painel e ícones/
   rótulos brancos.
4. **`lib/screens/login_page.dart`** — fundo com o gradiente das telas de entrada do painel e conteúdo
   em cartão (largura máxima 420).
5. **`lib/screens/app_start_page.dart`** — splash com o mesmo gradiente e logo branca.
6. **`lib/screens/home_page.dart`** — AppBar da Home no estilo do topbar do painel (fundo branco,
   ícones muted).

### Verificação
- MEDI (28/10): `flutter pub get` OK; `flutter analyze` → **No issues found**; `flutter test` →
  **354/354 OK**.
- MEDI: diff restrito aos 6 arquivos; base `328ac41`; nada foi enviado ao GitHub.
- NÃO rodado em aparelho/emulador: conferir visualmente splash → login → Home e a navbar.

### Pendências
- Validar visualmente no aparelho (o teste verde não prova visual).
- Telas de cadastro/onboarding (`conta_page.dart`, `onboarding_page.dart`) ainda não receberam o
  gradiente de entrada.

## Cópia de trabalho independente do app — 28/10/2026

### Contexto
O dono pediu uma cópia do app para fazer mudanças sem tocar no original. Foi criado um clone git
independente em `~/Documents/deepseek-harness/default-workspace/mentall-pro-app-copia` (o original
continua em `~/mentall-pro-app`). Remotos: `origin` → GitHub (`mentall-api`) e `original` → pasta
local do app original. A pedido do dono, a cópia recebeu também as configs locais.

### O que mudou (arquivos)
1. **`COPIA.md` (novo)** — origem, remotos, configs incluídas, o que não veio junto e como rodar a
   cópia (porta 8001, chaves reais, avisos de efeitos reais).
2. **`backend/.env` e `backend/data/mentall.db` (não versionados)** — copiados do original
   (`chmod 600`): mesmas chaves de produção + snapshot consistente do banco local (0 usuários).
3. **`backend/.venv/` (não versionado)** — recriado com Python 3.12 + `requirements.txt`.
4. **`AGENTS.md` (cópia)** — esta seção. O `AGENTS.md` do repositório original **não** foi alterado.
5. Nenhum arquivo de código foi editado nesta etapa.

### Verificação
- MEDI (28/10): HEAD da cópia = HEAD do original = `8649d4d`; 535 arquivos rastreados; árvore limpa
  antes deste registro.
- MEDI: original com `git status --porcelain` vazio e HEAD inalterado após a cópia.
- MEDI: clone com `--no-local` (sem link físico) — 33 MB de código + 21 MB de `.git`.
- MEDI: banco copiado com `.backup` — `PRAGMA quick_check` ok; 21 tabelas com contagens idênticas
  ao original; `backend/.env` com permissão 600.
- MEDI: smoke test do backend da cópia em `127.0.0.1:8001` → `GET /health` 200
  (`{"status":"ok","versao":"1.0.0","debug_info":{"database":"sqlite_local"}}`), shutdown limpo.
- NÃO foi feito `git push`: a cópia é local, nada foi enviado ao GitHub.

### Pendências
- `flutter pub get` ainda não rodou nesta cópia (o sandbox do agente não escreve no cache do Flutter);
  rodar no Terminal do macOS antes de buildar/rodar o app.
- Ao rodar: backend na porta 8001 e app apontando para a cópia (ver `COPIA.md`), com integrações
  reais neutralizadas para não gerar WhatsApp/e-mail a pacientes.

## Histórico comprimido (tarefas anteriores a 28/10/2026)

> Histórico antigo movido **verbatim** para [`docs/AGENTS_historico.md`](docs/AGENTS_historico.md) em
> 28/10/2026 para manter este arquivo abaixo de 200 KB. Índice das seções arquivadas (mais recente no
> topo):

- Custos: IA por profissional (item 7.3 do checklist) — 28/10/2026
- Custos Magalu em tempo quase real — 28/10/2026
- Ajustes de painel: precisão de custos e auto-status do reporte — 28/10/2026
- Reportes de IA: follow-ups (e-mail, SLA, lote, métricas, modelo/prompt, templates, push) — 28/10/2026
- Painel: resolução dos reportes de IA — 28/10/2026
- Painel: Reportes de IA (follow-up do item 3.4) — 28/10/2026
- Quick wins de publicação (4.6/4.7/4.8) + reporte de IA in-app (3.4) — 27/10/2026
- Rascunho de Data Safety / App Privacy (itens 3.1–3.3) — Fase 5V (23/10/2026)
- Keystore de produção e AAB assinado (itens 4.1/4.2) — Fase 5U (23/10/2026)
- URLs legais dentro do app (item 1.5) — Fase 5T (23/10/2026)
- PDFs com fonte Unicode embutida (correção do travessão) — Fase 5R (23/10/2026)
- Exportação completa em PDF (prontuário + financeiro) — Fase 5Q (23/10/2026)
- Exclusão de conta dentro do app — Fase 5P (23/10/2026)
- Ações administrativas e detalhe do usuário — Fase 5A.2 (22/10/2026)
- Alerta de WhatsApp desconectado na Home — Fase 5J (24/10/2026)
- Alertas de e-mail na Saúde + gráfico diário — Fase 5N (24/10/2026)
- SLA por endereço + alerta no WhatsApp — Fase 5O (24/10/2026)
- Métricas das caixas de e-mail — Fase 5M (24/10/2026)
- Dashboard analítico — Fase 5L (24/10/2026)
- Dashboard v2 (transformação visual) — Fase 5K (24/10/2026)
- Psicólogo × equipe do painel — Fase 5I (24/10/2026)
- Lembretes no painel + teto de retry — Fase 5H (24/10/2026)
- Backup portátil com senha + chave de recuperação — Fase 5G (24/10/2026)
- Card do WhatsApp com status ao vivo — Fase 5F (23/10/2026)
- Painel instalável (PWA) e responsivo no celular — Fase 5E (23/10/2026)
- IA de síntese e transcrição separadas no painel — Fase 5D (23/10/2026)
- Banco local no volume do Fly — Fase 5C (22/10/2026)
- Papéis e revogação de sessão do app — Fase 5B.2 (22/10/2026)
- Segurança do painel — Fase 5B.1 (22/10/2026)
- Painel operacional — Fase 5A (22/10/2026)
- E-mail (Mailu) no painel do dono — Fase 4 (22/10/2026)
- Google Calendar — Fase 2A (21/10/2026)
- Release (20/10/2026) — APK 1.0.51+52
- Agenda — Fase 1 (20/10/2026)
- Agenda — Fase 0 (20/10/2026)
- PsicoManager — documentos do paciente e LGPD (20/10/2026)
- PsicoManager + REA × RES (19/10/2026)
- Correções de IA e privacidade — 5 edições (16/10/2026)
- Checklist de publicação em PDF (16/10/2026)
- Infra REA + pesquisa de funcionalidades de concorrentes (14/10/2026)
- Comparativo de LGPD com concorrentes + calibração dos documentos (13/10/2026)
- Teste no aparelho bloqueado pela política de cleartext do Android (08/10/2026)
- WhatsApp (wuzapi) por profissional — conexão pelo app (08/10/2026)
- Indicações de artigos: descritores alinhados + crivo por metadado (07/10/2026)
- Circuito aberto nos provedores de IA (07/10/2026)
- Provedores de IA: Gemini fora, OpenAI primeiro (07/10/2026)
- Release (06/10/2026) — APK 1.0.48+49
- Buraco do gate de revisão fechado (06/10/2026) — A ORIGEM NÃO SE APAGA
- Gate de revisão humana implementado (06/10/2026) — A GARANTIA PASSOU A SER DO SOFTWARE
- Auditoria da documentação contra o código (06/10/2026) — O DOC MENTIA SOBRE A REVISÃO
- Expurgo do log em claro e A1 nas indicações de artigos (06/10/2026)
- Log técnico deixa de gravar PII em texto puro (06/10/2026) — FAIL-CLOSED TAMBÉM NO LOG
- Guarda contra dupla criptografia (06/10/2026) — A LEITURA QUE FALHA NÃO PODE DESTRUIR O DADO
- Auditoria de degradação silenciosa e primeiras correções (06/10/2026) — O ERRO QUE VIRA SUCESSO
- Qualidade das indicações de artigos (06/10/2026) — PERIÓDICO PRIMEIRO + LIMPEZA
- Retry para indisponibilidade transitória da IA (06/10/2026) — O 503 DEIXA DE SER SILENCIOSO
- Remoção do rerank por IA nas indicações de artigos (06/10/2026) — MENOS DADO, MENOS FALHA
- Verificação do backup no emulador (06/10/2026) — EXPORT/IMPORT APROVADOS
- Verificações no emulador (06/10/2026) — GATE DE BIOMETRIA OK + STARTUP MEDIDO
- Encerramento de plano (06/10/2026) — PLANO DE STARTUP/PIN ARQUIVADO
- UI/Configurações (05/10/2026) — BACKUP UNIFICADO EM "BACKUP E DADOS"
- Correções e Funcionalidades (05/10/2026) — FRENTE C (LEMBRETES ÓRFÃOS) + ITENS PARCIAIS DA AUDITORIA
- Acessos (30/09/2026) — REDEFINIÇÃO DA SENHA DO ADMIN ANDERSON
- Acessos (30/09/2026) — NOVO DONO DO PAINEL + GATE DE `status`
- Correções e Funcionalidades (30/09/2026) — PRESENÇA CONFIÁVEL + PAINEL EM HORÁRIO DE BRASÍLIA
- Lojas (29/09/2026) — SCREENSHOTS (emulador + seed de demo)
- Lojas (29/09/2026) — ÍCONES (iOS sem alpha + 512 do Play)
- Segurança (29/09/2026) — GATE DE SCAN DE DEPENDÊNCIAS NO CI
- Segurança (29/09/2026) — ROTAÇÃO DO `WUZAPI_WEBHOOK_TOKEN`
- Ops (29/09/2026) — LIMPEZA DE CONTAS (só o dono)
- Correções e Funcionalidades (29/09/2026) — HEARTBEAT AUTENTICADO + CI IGNORA DOCS
- Correções e Funcionalidades (29/09/2026) — FASE 3: PAINEL DO DONO (web)
- Correções e Funcionalidades (29/09/2026) — FASE 2: TELEMETRIA (heartbeat + eventos)
- Segurança (28/09/2026) — CSP COM NONCE (remove `unsafe-inline` do `script-src`)
- Segurança (28/09/2026) — TRUSTED_PROXIES (CIDR) + `--proxy-headers`
- Correções e Funcionalidades (28/09/2026) — DIÁLOGO DE BIOMETRIA EM PORTUGUÊS
- Deploy (28/09/2026) — PUSH PARA O GITHUB + CI VERDE (corrige gate do analyze)
- Deploy (28/09/2026) — BACKEND NO FLY (recuperação de senha no ar)
- Correções e Funcionalidades (28/09/2026) — RECUPERAÇÃO DE SENHA DA CONTA + SESSÃO NO DESBLOQUEIO
- Release (28/09/2026) — APK 1.0.41+42
- Release (28/09/2026) — APK 1.0.40+41
- Documentação (28/09/2026) — REDUÇÃO DO AGENTS.md + REGRA DE MEMÓRIA AUTOMÁTICA
- Correções e Funcionalidades (28/09/2026) — CREDENCIAIS DURÁVEIS PARA RE-AUTENTICAÇÃO (fecha o teste RED de 27/09)
- Correções e Funcionalidades (04/09/2026) — DESBLOQUEIO ABRIA SEM PEDIR BIOMETRIA/SENHA (GATE RESTAURADO)
- Correções e Funcionalidades (03/09/2026) — DESBLOQUEIO POR BIOMETRIA "NÃO FOI POSSÍVEL AUTENTICAR"
- Correções e Funcionalidades (03/09/2026) — UI DA TELA DE PERFIL PROFISSIONAL
- Correções e Funcionalidades (30/08/2026) — PENTEST STRIX 2º SCAN (MODO DEEP) + FIX TABCONTROLLER
- Correções e Funcionalidades (31/08/2026) — SUPPLY-CHAIN (TRAIL OF BITS) + DEPENDÊNCIAS (fastapi/starlette/google-genai)
- Correções e Funcionalidades (02/09/2026) — FAIL-CLOSED DE CRIPTOGRAFIA (VULN-0013) + INDICADOR DE PROTEÇÃO
- Decisões e plano (02/09/2026) — TELECONSULTA (ainda NÃO implementada)
- Correções e Funcionalidades (02/09/2026) — FIX DE DESBLOQUEIO POR BIOMETRIA + BACKUP CONFIGURÁVEL
- Checklist de publicação nas lojas de app (Google Play / App Store)
- REFATORAÇÃO DO SESSÃO_FORM_PAGE (29/08/2026) — 2388 → 1901 LINHAS
- INFRAESTRUTURA LOCAL (25/08/2026) — Setup e automação


## Projeto
App Flutter para prontuário clínico adaptado à abordagem terapêutica do profissional (TCC, Psicanálise, ACT, DBT, etc.), com assistência de IA para transcrição e análise de sessões.

## Stack
- **Framework:** Flutter (SDK ^3.12.2)
- **Linguagem:** Dart / Python (backend)
- **Estado:** Riverpod como base (StreamProvider + StateProvider + ConsumerStatefulWidget), **mas não é
  100%**: há ~55 `setState` em 10 arquivos (ex.: `login_page.dart`, `conta_page.dart`,
  `compromisso_form_dialog.dart`, `app_lock_gate.dart`, `app_start_page.dart`)
- **Banco local:** Hive CE (hive_ce + hive_ce_flutter + hive_ce_generator)
- **Áudio:** record + audioplayers + path_provider
- **Geração de código:** build_runner + hive_ce_generator
- **Backend:** Python FastAPI. **Síntese:** OpenAI (padrão `gpt-4o-mini`) / DeepSeek (`deepseek-v4-flash`) / Gemini (`gemini-3.7-flash`). **Transcrição:** Groq `whisper-large-v3-turbo` (padrão) ou OpenAI `gpt-4o-mini-transcribe` (`TRANSCRICAO_PROVIDER`)
- **Deploy backend:** Fly.io, região `gru` (São Paulo) — CI + `flyctl deploy` a cada push em `master`
- **Segurança:** Criptografia **AES-256-GCM** (nonce aleatório por registro; o formato `2:` CBC é só legado e **não migra automaticamente** — `migrarCamposLegados` não tem chamador). A chave mestra é **aleatória** em cofre durável; PBKDF2 só no caminho legado de PIN. Autenticação **PyJWT** no backend

## Infraestrutura

### Backend em Nuvem (Fly.io) — migrado do Render
- **URL produção:** `https://mentall-api.fly.dev`
- **Repositório GitHub:** `https://github.com/rodrigolemospsi/mentall-api`
- **Região:** `gru` (São Paulo); `fly.toml` + `Dockerfile` na raiz
- **Deploy:** push no branch `master` dispara o GitHub Action **Deploy to Fly.io**
  (`flyctl deploy --remote-only`). O workflow reimplanta **em qualquer push que não seja só de docs**,
  então um push de código reinicia a máquina (ver 29/09/2026).
- **Configuração:** `fly.toml`. O `render.yaml` da raiz é **resquício da era Render** e nenhum workflow
  o usa.
- **Variáveis de ambiente (secrets do Fly):**
  - `OPENAI_API_KEY` — chave API da OpenAI (projeto, formato `sk-proj-...`)
  - `OPENAI_PROJECT_ID` — ID do projeto OpenAI (formato `proj_...`)
  - `GEMINI_API_KEY` — chave API do Google Gemini (opcional; usada apenas se `IA_MODEL_PROVIDER=gemini`)
  - `DEEPSEEK_API_KEY` — chave API do DeepSeek (formato `sk-...`)
  - `IA_MODEL_PROVIDER` — provedor de síntese: `openai`, `deepseek` (ativo em produção) ou `gemini`
  - `IA_MODEL` — modelo OpenAI (padrão `gpt-4o-mini`). DeepSeek é fixo em `deepseek-v4-flash` e o Gemini usa `GEMINI_MODEL` (padrão `gemini-3.7-flash`) — ver `_get_model_name`
  - `JWT_SECRET` — chave secreta para tokens JWT
  - `APP_PASSWORD_HASH` — hash bcrypt da senha (vazio = senha padrão `admin`)
  - `OPENALEX_API_KEY` — chave gratuita da OpenAlex (https://openalex.org/settings/api, $1/dia ≈ 10k buscas; **obrigatória** — sem ela a API retorna 429 em IP de datacenter)
  - `OPENALEX_MAILTO` — email de contato enviado nas requisições à OpenAlex (`mentall.brasil@gmail.com`)
  - `TURSO_DATABASE_URL` — URL do banco Turso (formato `libsql://nome-banco.turso.io`; **obrigatória**)
  - `TURSO_AUTH_TOKEN` — token de autenticação do Turso (gerado em https://console.turso.org)

### APK (Android)
- **Permissões necessárias:** `INTERNET`, `RECORD_AUDIO`, `usesCleartextTraffic=true`
- **URL do backend:** Configurável via Hive box `app_config`. Padrão: `https://mentall-api.fly.dev` (`api_client.dart`)
- **Timeout API:** 120 segundos (transcrição longa)
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
│   ├── paciente.dart / .g.dart             # Hive typeId: 1 (16 campos)
│   ├── perfil_profissional.dart / .g.dart  # Hive typeId: 3 (13 campos)
│   ├── sessao.dart / .g.dart               # Hive typeId: 2 (35 campos)
│   ├── compromisso.dart / .g.dart          # Hive typeId: 4 (17 campos: +canalLembrete)
│   ├── contrato_terapeutico.dart / .g.dart # Hive typeId: 5 (10 campos)
│   └── lgpd/
│       └── registro_auditoria.dart / .g.dart  # Hive typeId: 10
├── screens/
│   ├── app_start_page.dart                 # Roteamento inicial (verifica PIN + perfil)
│   ├── home_page.dart                      # Dashboard (saudações, ações rápidas, KPIs) + Privacidade
│   ├── login_page.dart                     # Tela de PIN (configurar/desbloquear)
│   ├── paciente_detail_page.dart           # Detalhes + sessões + acesso última sessão ~893 linhas
│   ├── sessao_form_page.dart               # Formulário de sessão ~1972 linhas (+ error handling)
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
│   ├── service_providers.dart              # 42 providers (Stream com async* para emitir valor inicial)
│   └── sessao_form_providers.dart          # 20 StateProviders públicos da tela de sessão (fase 1 do refactor)
├── services/
│   ├── api_client.dart                     # URL dinâmica via Hive + credenciais no Hive + ensureAuthenticated() + timeout 120s
│   ├── paciente_service.dart               # + criptografia AES nos campos sensíveis + cascade delete
│   ├── perfil_profissional_service.dart    # + criptografia AES
│   ├── sessao_service.dart                 # + criptografia AES (19 campos) + cache próximo número
│   ├── compromisso_service.dart            # CRUD de compromissos + recorrência + cancelamento de lembretes
│   ├── lembrete_service.dart               # Agendamento de notificações locais + envio ao backend (WhatsApp/SMS)
│   ├── backup_service.dart                 # Export/import JSON com exclusão de áudio grande + O(1) import
│   ├── transcricao_relato_service.dart     # Lê arquivo .m4a e converte Base64 (mobile) + JWT auto-auth
│   ├── ia_clinica_service.dart             # Conectado ao backend (gpt-4o-mini por padrão) + pseudonimização + retry
│   ├── audio_relato_service.dart           # Gravação web (WAV/Base64) + mobile (M4A/arquivo)
│   ├── status_clinico_sessao_service.dart
│   ├── hive_migration_service.dart         # Schema V3
│   ├── encryption_service.dart             # PBKDF2-HMAC-SHA256 (100k iterações) + IV aleatório por registro
│   ├── auth_service.dart                   # PIN local + JWT backend (credenciais no Hive)
│   ├── pdf_export_service.dart             # 7 geradores (sessão, histórico, relatório, síntese, prontuário, anamnese, financeiro)
│   ├── contrato_service.dart               # CRUD contratos + comunicação com backend
│   ├── configuracoes_service.dart          # Preferências (duração, lembretes, IA, tema, canal)
│   ├── logger.dart                         # Log.erro / Log.info / Log.auditoria + persistência em Hive+arquivo
│   └── lgpd/
│       ├── auditoria_service.dart          # Registro de eventos LGPD
│       └── pdf_arquitetura_lgpd_service.dart
├── utils/                                  # gerado de `ls lib/utils`
│   ├── app_bar_padrao.dart
│   ├── artigos_validacao.dart
│   ├── imagem_cache.dart
│   ├── mentall_colors.dart
│   ├── raio.dart
│   ├── responsivo.dart
│   ├── sessao_form_helpers.dart
│   └── tipografia.dart
├── widgets/
│   ├── home_dashboard.dart                # Dashboard da Home (5 seções)
│   ├── compromisso_form_dialog.dart       # Diálogo de criação/edição de compromisso
│   ├── novo_paciente_dialog.dart          # Diálogo de cadastro de paciente
│   ├── paciente_card_home.dart            # Card de paciente na lista (avatar, status, WhatsApp)
│   ├── paciente_resumo_card.dart          # Card de resumo na ficha do paciente (+ status contrato)
│   ├── sessao_card.dart                   # Card de sessão na lista
│   ├── sessao_audio_controls.dart         # Controles de áudio (+ 12 providers de áudio/IA)
│   ├── sessao_artigos_sugeridos.dart      # Card de artigos sugeridos
│   ├── sessao_form_widgets.dart           # CardBuscandoArtigos + AudioMantidoSwitch + BotaoSalvarSessao
│   ├── sessao_progresso_widget.dart       # SecaoProgressoWidget (evolução clínica)
│   ├── sessao_financeiro_widget.dart      # SecaoFinanceiroWidget
│   ├── sessao_relato_ia_widget.dart       # SecaoRelatoIaWidget + SessaoFormActions
│   ├── secao_campos_clinicos_widget.dart  # 5 seções clínicas simplificadas
│   ├── status_processamento_card.dart     # DEAD CODE — zero usos (achado 06/10)
│   └── lgpd/
│       └── aviso_privacidade_ia_card.dart
```

> As árvores abaixo listam os **principais** arquivos, não todos. Para a lista completa use `ls` —
> a auditoria de 06/10 achou omissões (ex.: `lib/utils/`, `backend/admin_ui.py`, `backend/tests/`,
> e ~17 services / 6 screens / 6 models não listados).

### Backend Python (`backend/`)
```
backend/
├── main.py                           # FastAPI app, CORS, JWT auth, rotas protegidas, /health com debug de provedores
├── .env                              # Chaves de API + JWT_SECRET (NÃO commitar)
├── .env.example                      # Template com variáveis documentadas
├── requirements.txt                  # openai==1.109.1 + PyJWT==2.15.0 + bcrypt + httpx
├── models/
│   └── schemas.py                    # Pydantic models + LoginRequest/LoginResponse
├── templates/
│   └── contrato.html                  # Página HTML do Acordo Terapêutico (patient-facing)
├── services/
│   ├── ia_clinica.py                 # Síntese clínica (OpenAI/DeepSeek/Gemini) + busca de artigos (cascata de filtros OpenAlex; sem rerank por IA desde 06/10)
│   ├── transcricao.py               # Transcrição (gpt-4o-mini-transcribe, modelo configurável via TRANSCRICAO_MODEL)
│   ├── contrato_service.py          # Armazenamento de contratos (token único + aceite)
│   └── lembrete_service.py          # Scheduler de lembretes WhatsApp/SMS (asyncio + Twilio/Meta)
└── prompts/
    └── abordagens.py                 # 14 abordagens (inclui Análise do Comportamento)
```

### Arquivos de Deploy
```
fly.toml                             # Config do Fly.io (região gru)
Dockerfile                           # Imagem do backend
.github/workflows/                   # CI + "Deploy to Fly.io"
render.yaml                          # LEGADO (era Render; nenhum workflow usa)
```

## Segurança

### Autenticação
- **Backend**: JWT com **PyJWT** (`requirements.txt`: `PyJWT==2.15.0`; `main.py:25` `import jwt`) — rota `POST /auth/login`, endpoints protegidos via `Authorization: Bearer <token>`
- **Flutter**: `ApiClient.ensureAuthenticated()` chamado antes de cada requisição API (transcrição e síntese)
- Usuário padrão `admin` (env `APP_USERNAME`), mas a **senha vem de `APP_PASSWORD_HASH` (bcrypt) por
  ambiente e o boot FALHA sem ela** (`main.py:229-234`). Não há senha fixa no código, e o app não tem
  credencial embutida: usa `setCredentials()` (`api_client.dart:84,309`).
- Expiração do token: 480 minutos (8 horas)

### Criptografia Local
- **Algoritmo**: **AES-256-GCM**, formato `3:<nonce base64>:<cifra base64>`. O formato `2:` (CBC) é
  **legado**, só é lido; `migrarParaGcm` converte.
- **Chave**: a chave mestra é **aleatória** (`Key.fromSecureRandom(32)`, `encryption_service.dart:247`),
  gerada no boot (`main.dart:161-162`) e persistida em **cofre durável** (`flutter_secure_storage` sem
  biometria, chave `aes_master_key_duravel`) — é o que garante dado cifrado mesmo sem bloqueio de tela
  (correção da vuln-0013). **PBKDF2 existe só no caminho legado de PIN** (`:356`, `:418`), e
  `kdf_version` **não tem escritor**, então as iterações efetivas são **10.000**, não 100.000.
- **Áudio**: não usa o formato `3:` — usa envelope binário `[MAV1][nonce 12B][cifra]`
  (`encryption_service.dart:121-155`), com MAC. Não é decifrável por `descriptografar()`.
- **Escrita é fail-closed**: `EncryptedServiceMixin.encrypt` **lança** `StateError` quando a proteção
  não está disponível, em vez de gravar em texto puro. A **leitura** é fail-open por desenho: no boot,
  antes do desbloqueio, devolve o valor como está para não travar (o app pede desbloqueio e relê).
- **Nunca cifra o que já está cifrado**: `criptografar` preserva valor no formato `3:`/`2:` (via
  `estaCifrado`) — evita a dupla criptografia que torna o dado ilegível (seção 06/10/2026).
- **Services**: `PacienteService`, `SessaoService`, `PerfilProfissionalService` criptografam/descriptografam automaticamente

### LGPD / Privacidade
- **Áudio**: Limite de 5 minutos com contador e parada automática
- **Microtexto**: a frase existe **apenas na especificação do PDF de arquitetura LGPD**
  (`pdf_arquitetura_lgpd_service.dart:219`), **não na tela** — a tela de gravação
  (`widgets/sessao_audio_controls.dart:129-143`) mostra só "Tempo de gravação" + mm:ss. O limite de
  5 min e a parada automática existem (`sessao_form_page.dart:75,545-547`).
- **Auditoria**: Registro de eventos (gravação, transcrição, IA, revisão) em `RegistroAuditoria` (typeId 10)
- **Arquivamento**: a UI usa `arquivarPaciente` (`pacientes_page.dart:115`). Existe `excluirPaciente`
  (hard delete em cascata, `paciente_service.dart:113-166`) **sem chamador de produção** — dead code
  com potencial destrutivo.
- **Revisão**: registrada em `revisadoPeloProfissional`, **mas NÃO bloqueia o salvamento**.
  `_salvarSessao()` (`sessao_form_page.dart:1373`) valida apenas `sessaoSalvandoProvider` e
  `_existeAcaoEmAndamento` — não checa a flag, que é gravada como um campo qualquer (`:1490`). O único
  efeito hoje é o rótulo "Revisão pendente" (`status_clinico_sessao_service.dart:123`).
  **Gate implementado em 06/10/2026**: `_salvarSessao` agora **bloqueia** o salvamento nessa condição
  (`precisaRevisarAntesDeSalvar`), com aviso orientando a usar "Marcar como revisado" — botão que
  aparece exatamente nessa condição. Sessões sem IA não são afetadas.
- **IA**: Apenas apoio documental, nunca substitui julgamento clínico
- **Tela Privacidade**: Acessível pelo ícone de escudo na Home — PIN, áudio, IA, retenção, auditoria
- **Exportação**: Aviso de dados sensíveis; **6 opções no diálogo** (`paciente_detail_page.dart:669-797`) e **7 geradores** no serviço (`pdf_export_service.dart`)
- **Logs**: `Log.auditoria()` separado de `Log.erro()`. O log técnico é gravado **cifrado**; sem cifra
  disponível grava apenas o rótulo (nível e contexto) com `(conteudo nao registrado: cifra
  indisponivel)` — **nunca o conteúdo**, que pode conter PII (`response.body`). Ver 06/10/2026.

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

### Achados da auditoria de degradação silenciosa (06/10/2026) — EM ABERTO
Já corrigidos: guarda de schema da síntese, campo do profissional preservado, `crpVerificado` gravado,
dupla criptografia, PII no log técnico (+ expurgo do histórico) e busca de artigos que não apaga.
**Continuam abertos:**
- **`/health`** responde `status:"ok"` mesmo com o banco em fallback SQLite — o monitor não enxerga.
- **`ALLOW_SQLITE_FALLBACK`** tem default `"true"` no repositório; se os secrets do Fly não tiverem
  `false`, uma queda do Turso aceita escrita e confirma sucesso (o dado some no restart).
- **`_registrarAuditoria`** não é `await`ado: a falha vira Future não tratado e o evento LGPD pode
  nunca ser gravado.
- **Bloqueio por inatividade** desbloqueia sem prompt e sem o aviso de fail-safe (que só existe no
  login).
- **Migração Hive**: o marcador de schema avança mesmo com registros não migrados (nunca repete).
- **Anamnese**: `status='respondido'` com `respostas_json` vazio é gravado (gatilho no backend).
- **OpenAlex**: falha de rede chega ao app como `sucesso: true` com "Busca sugerida" —
  indistinguível de "as bases não tinham artigos".
- **wuzapi/lembretes**: webhook inválido responde 200 e o recibo se perde; falha de banco vira
  "wuzapi não conectado"; lembrete pode ser duplicado ou marcado como falha por erro de leitura.
- **Recuperação de senha/PIN**: `except: pass` deixa o bloqueio por tentativas **fail-open**.
- **Áudio "não mantido"**: a exclusão do arquivo é `unawaited` — se falhar, o áudio permanece.
- **`progresso_service.dart`**: `..take(limite)` em cascata não tem efeito (bug funcional).

### Achados da auditoria da documentação (06/10/2026) — EM ABERTO
- **`migrarParaGcm` / `migrarCamposLegados` sem chamador**: o formato legado `2:` (CBC) é lido mas
  **nunca migrado**. Ligar isso reescreve todos os campos cifrados — o tipo de operação do incidente de
  16/07. Decisão do dono.
- **`excluirPaciente`** (`paciente_service.dart:113-166`): hard delete em cascata **sem chamador de
  produção** — dead code com potencial destrutivo.
- **`StatusProcessamentoCard`**: dead code (zero usos).
- **Falta evento de auditoria para remoção/regravação de áudio**, exigido pela especificação do PDF de
  arquitetura LGPD (`pdf_arquitetura_lgpd_service.dart:214`).

### APK
- Versão atual `1.0.47+48`; release ~70MB.

## Cores do App

> **ATENÇÃO — a tabela anterior estava errada.** O app **não usa paleta fixa**: `lib/main.dart:255` cria
> o tema com `ColorScheme.fromSeed(seedColor: #8806CE)` (Material 3, `tonalSpot`) e
> `lib/utils/mentall_colors.dart` deriva tudo de `colorScheme`. Os hexadecimais que estavam aqui
> (#1E293B, #334155, #F7F9FA, #D32F2F…) são a paleta de **PDF/HTML**, não de tela. Não existe
> `lib/theme/` — o tema está em `lib/main.dart:_criarTema`.

TEMA REAL (Material 3, derivado do seed #8806CE)
```
primary               #725187   AppBar, FAB, ações
primaryContainer      #F4DAFF
surface               #FFF7FC   Fundo das telas (scaffoldBackgroundColor, main.dart:273)
surfaceContainerLow   #FAF1F9   corSuperficie (cards)
onSurface             #1E1A20   Texto: heading 100%, body 87%, secondary 60%, muted 50%,
                                placeholder 38%, disabled 25%  (mentall_colors.dart:17-23)
onSurfaceVariant      #4B454D
outlineVariant        #CDC3CE   corDivider
error                 #BA1A1A   corError
```

MARCA / SEED / SEMÂNTICAS
```
#8806CE    seed do tema + cor de PDF (pdf_export_service.dart:18) + manifest + splash
#A10AF5    Primary Claro (PDF) — corAcaoBorda / corAcaoFgClaro
#52047C    splash escuro (android/.../drawable-night/launch_background.xml)
#A10AF5 12%  fundo translúcido de cards de destaque (0x1FA10AF5)
#6D05A5 / #360250   NÃO DETERMINADO — só aparecem neste AGENTS.md, sem uso no código
#2E7D32 sucesso · #E65100 atenção · #C62828 perigo · #1976D2 agendado · #757575 cancelado
#25D366 / #075E54 WhatsApp · #0D9488 corPacote          (mentall_colors.dart:44-54)
```

DOCUMENTOS (PDF/HTML — NÃO é a UI do app)
```
#1E293B título · #334155 corpo · #475569 subtítulo · #64748B secundária
#F7F9FA fundo (HTML do backend) · #F8FAFC card (PDF) · #F1F5F9 superfície (PDF)
#94A3B8 sombra de card · #E2E8F0 borda de ação (PDF) · #CBD5E1 desabilitado (contrato.html)
#FFF3E0 fundo de aviso (PDF)
```

## Layout da Sessão (após redesenho 08/07/2026)
A tela de sessão foi simplificada:
- **Cabeçalho**: apenas `SESSÃO N` em maiúsculo/negrito (`sessao_form_page.dart:1747-1764`) — **o nome do paciente não aparece na tela** (só no prompt de IA)
- **Info**: apenas data e horário (sem tema principal, sem humor)
- **Breve relato**: controles de áudio + transcrição + botão IA + relato clínico organizado
- **Síntese clínica**: 1 campo combinado (eventos + evolução + observações)
- **Formulação clínica**: 1 campo combinado (pensamentos + emoções + comportamentos)
- **Intervenções**: 1 campo (`intervencoes`); `tecnicasTcc` é forçado a `''` (`sessao_form_page.dart:1470`) — só o PDF concatena os dois, e sempre com técnicas vazias
- **Apontamentos**: 1 campo (renomeado de "Apontamentos do Copiloto")
- Removidos: **Tarefas** (`tarefaCasa` nunca aparece), status card, humor, tema principal
- **"Plano para a próxima sessão" NÃO foi removido** — existe e é renderizado
  (`secao_campos_clinicos_widget.dart:86-95`, persistido em `sessao.planoProximaSessao`)
- `StatusProcessamentoCard` é **dead code** (zero usos)

## Comandos

### App Flutter
- `flutter analyze --no-pub` — estado atual: **No issues found!**
- `flutter test --no-pub` — **276 testes** (o total muda a cada correção; use o que o runner informar)
- `dart run build_runner build` — gerar adapters Hive
- `flutter build web` — build de produção
- `flutter build apk` — build APK Android release (saída: `build/app/outputs/flutter-apk/app-release.apk`)

### Web (Chrome)
- `flutter run -d chrome` — a alegação de que está quebrado ("debug service timeout") **não tem evidência no repositório**; `tools/gerar_guia_mac_pdf.dart:364` ainda recomenda o comando. **NÃO DETERMINADO** — revalidar antes de repetir.
- Alternativa: `flutter build web` + `python -m http.server 5000` no diretório `build/web`
- **Sempre use porta fixa 5000** para não perder dados do Hive/localStorage

### Backend Local
```bash
cd backend
pip install -r requirements.txt
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### Deploy (Fly.io)
```bash
git add -A
git commit -m "mensagem"
git push origin master
# O GitHub Action "Deploy to Fly.io" roda CI + flyctl deploy --remote-only.
# ATENCAO: reimplanta em qualquer push fora de docs/**, tasks/** e **.md (paths-ignore do workflow).
```

### Testar API em produção
```bash
# Health check
curl https://mentall-api.fly.dev/health

# Login (obter token JWT) — a senha padrao "admin" nao vale mais em producao
curl -X POST https://mentall-api.fly.dev/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"<usuario>","password":"<senha>"}'
```

## Memória: Layout do Acordo Terapêutico (PDF de referência)

O layout do contrato (`backend/templates/contrato.html` + `main.py` `_renderizar_template_personalizado`)
segue um modelo de referência. **O arquivo `Acordo Terapêutico.pdf` NÃO existe no repositório** — a
referência é esta tabela abaixo, não um PDF. Os únicos PDFs do repo são
`docs/prompt_site_institucional_mentall_pro.pdf` e `auditoria/relatorio_auditoria.pdf`.

### Especificações de layout

| Elemento | Posição | Tamanho | Peso | Cor |
|---|---|---|---|---|
| Psicólogo + Nome | Esquerda | 16px (12pt) | **Bold** (700) | Preto (#1E293B) |
| CRP | Esquerda | 16px | Normal | Preto (#1E293B) |
| Paciente: Nome | Esquerda | 16px | **"Paciente:" bold** | Preto (#1E293B) |
| Acordo Terapêutico | Centralizado | 20px | **Bold** | Roxo (#3C096C — marca MentAll; `contrato.html:62`, `main.py:393`) |
| Intro | Centralizado | 12px | Normal | Cinza (#64748B) |
| Subtítulos (Compromissos, Cancelamentos, etc.) | Esquerda | 16px | **Bold** | Preto (#1E293B) — **sem borda, sem cor azul** |
| Corpo do texto | Esquerda | 16px | Normal | Escuro (#334155), `text-align: justify` |
| Logo MentAll | Canto superior direito | 12px | Bold | Lilás (#C77DFF, `contrato.html:31`), opacidade 0.45 |

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
