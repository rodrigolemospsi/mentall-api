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

## Painel: resolução dos reportes de IA — 28/10/2026

### Contexto
O painel listava os reportes, mas não havia como tratá-los. Cada reporte agora abre uma página de
resolução com contato com o profissional, devolutiva, como ficou no sistema, causa raiz, severidade
e status (aberto → em análise → resolvido/descartado), com responsável/data e auditoria.

### O que mudou (arquivos)
1. **`backend/services/db.py`** — migrações incrementais em `reportes_ia`: `status`, `severidade`,
   `causa_raiz`, `contato_feito`, `contato_canal`, `contato_em`, `contato_resumo`, `devolutiva`,
   `como_ficou`, `mudanca_aplicada`, `resolvido_por`, `resolvido_em`, `atualizado_em`.
2. **`backend/services/reportes_ia.py`** — enums/labels do workflow; `resumo_reportes` com
   contagem por status; `listar_reportes(..., status=)`; `obter_reporte`; `atualizar_resolucao`
   (valida enums, preenche/limpa data de resolução e passa pela auditoria do painel).
3. **`backend/admin_ui.py`** — lista com status/severidade e link "Abrir"; página de detalhe com
   metadados e formulário de resolução.
4. **`backend/main.py`** — `GET /admin/reportes-ia/{id}` e `POST /admin/reportes-ia/{id}/resolver`
   (admin, rate limit, auditoria `reporte_ia.resolver`, 400 para valor inválido, 404 se não existir).
5. **`backend/tests/test_admin_reportes_ia.py`** — +12 testes (serviço, página e HTTP).
6. **`AGENTS.md`** — esta seção.

### Verificação
- Suíte isolada do backend **511/511 OK** (MEDI, 28/10; 12 testes novos).

### Pendências
- Devolutiva automática ao profissional no app (notificação/e-mail) é follow-up — hoje é registro
  interno do painel.
- Ações em lote (ex.: marcar vários como descartados) não existem; fazer se o volume justificar.

## Painel: Reportes de IA (follow-up do item 3.4) — 28/10/2026

### Contexto
O item 3.4 (reporte in-app de saída de IA) já estava em produção, mas o painel do dono não tinha
onde ver os reportes. Adicionada a página `/admin/reportes-ia` (admin) com os metadados: data,
profissional, motivo, protocolo, sessão, provedor e observação — sem conteúdo clínico (LGPD).

### O que mudou (arquivos)
1. **`backend/services/reportes_ia.py`** — `resumo_reportes()` (total, últimos 7 dias, por motivo) e
   `listar_reportes(motivo, limite)` com join em `usuarios` para o e-mail.
2. **`backend/admin_ui.py`** — novo item de menu "Reportes IA" (ícone `alerta`), `pagina_reportes_ia`
   com cards + filtro por motivo + tabela.
3. **`backend/main.py`** — `GET /admin/reportes-ia` com gate `_exigir_papel(("admin",))` e rate limit.
4. **`backend/tests/test_admin_reportes_ia.py` (novo)** — serviço, página e HTTP (admin vê, suporte
   toma 403, sem sessão mostra login, filtro por motivo).
5. **`AGENTS.md`** — esta seção.

### Verificação
- Suíte isolada do backend **499/499 OK** (MEDI, 28/10; 10 testes novos).
- Página não exibe relato/síntese: o banco de `reportes_ia` só guarda metadados.

### Pendências
- Ação sobre o reporte (marcar como revisado/arquivar) é follow-up, se o volume justificar.
- Índice na tabela é somente leitura; nada no app foi alterado.

## Quick wins de publicação (4.6/4.7/4.8) + reporte de IA in-app (3.4) — 27/10/2026

### Contexto
Fechar quick wins de loja do checklist v3.0 sem tocar no WIP de painel: iOS (Face ID e privacy
manifest), ambiente local OpenAI-only e o caminho in-app de reporte de saída de IA exigido pelo Play.
4.6/4.7/4.8 foram commitados em `fix/checklist-quick-wins-4.6-4.7-4.8` (commit `0ee8e7d`); o 3.4 sai
nesta branch/worktree para merge independente.

### O que mudou (arquivos)
1. **`ios/Runner/Info.plist`** — `NSFaceIDUsageDescription` (4.6).
2. **`ios/Runner/PrivacyInfo.xcprivacy` (novo)** + `ios/Runner.xcodeproj/project.pbxproj` — manifest
   sem tracking, 9 tipos de dado (App Privacy) e APIs UserDefaults/FileTimestamp/SystemBootTime;
   incluído em Copy Bundle Resources (4.7). Calendar só após a decisão 0.8.
3. **`backend/.env`** (não versionado) — GEMINI/DEEPSEEK/TURSO vazios, `IA_MODEL_PROVIDER=openai`,
   `IA_MODEL=gpt-4.1-mini` e `IA_PROVIDER_ORDER=openai` (4.8).
4. **`backend/models/schemas.py`**, **`backend/services/reportes_ia.py` (novo)**,
   **`backend/services/db.py`** e **`backend/main.py`** — `POST /reportar-sintese` (token + rate limit,
   422 para motivo inválido) e tabela `reportes_ia`; grava só metadados (sem conteúdo clínico).
5. **`lib/widgets/reportar_sintese_dialog.dart` (novo)**, **`lib/widgets/sessao_relato_ia_widget.dart`**,
   **`lib/screens/sessao_form_page.dart`** e **`lib/services/ia_clinica_service.dart`** — botão
   "Reportar problema com o texto gerado" após a síntese, diálogo com 5 motivos + observação e envio.
6. **Testes** — `backend/tests/test_reportes_ia.py` (9), `test_reportes_ia_endpoint.py` (4),
   `test/widgets/reportar_sintese_dialog_test.dart` (3), `ia_clinica_service_test.dart` (+1).

### Verificação
- Backend (MEDI, 27/10): `run_isolated.py` **489/489 OK** (476 + 13 novos).
- Flutter (MEDI, 27/10): `dart analyze` **No issues found!**; `flutter test` **354/354 OK** (350 + 4).
- iOS (MEDI parcial): `plutil -lint` OK nos três arquivos; `flutter build ios --no-codesign` não
  concluiu na sessão (>35 min, interrompido).
- Pendente NO APARELHO: gerar síntese → reportar → conferir protocolo e registro.

### Pendências
- Merge da branch do 3.4 e deploy do backend para o endpoint existir em produção.
- Listar os reportes no painel (hoje só banco/log) — próximo passo de suporte.
- 4.7: validar o manifest no archive/App Store Connect quando a conta Apple abrir.

## Rascunho de Data Safety / App Privacy (itens 3.1–3.3) — Fase 5V (23/10/2026)

### Contexto
Preparar as respostas dos formulários de privacidade das lojas (Google Play Data Safety, declaração
de app de saúde e Apple App Privacy) a partir do código, para preenchimento rápido quando as contas
de loja abrirem. Nenhum código do app mudou; é documentação técnica.

### O que mudou (arquivos)
1. **`docs/lojas/DATA_SAFETY_E_APP_PRIVACY.md` (novo)** — inventário do que sai do aparelho (servidor,
   OpenAI, Groq, Google Calendar, WhatsApp/Meta, Resend, Cloudflare, Fly/Magalu/Mailu) e do que fica
   só no aparelho; tabela linha a linha do Data Safety (coletado/compartilhado/vinculado/finalidades);
   respostas de segurança, exclusão de dados e URL da política; declaração de “Health apps”; tabela
   do App Privacy (Apple) com finalidades e vínculo; o que **não** declarar; pendências (DPA, decisão
   do Calendar 0.8, retenção OpenAI/Groq, financeiro, e-mail do titular) e passo a passo de
   preenchimento.
2. **`AGENTS.md`** — esta seção.

### Verificação
- Documento revisado contra `backend/models/schemas.py`, `backend/services/{exclusao_conta,telemetria,wuzapi_admin}.py`,
  `lib/services/{telemetria_service,ia_clinica_service}.dart`, manifestos e textos publicados (LI, 23/10).
- Nenhuma alteração de código/teste nesta fase (suíte permanece 350/350 do commit e64d580/6d75a71).
- Conferido que o áudio e o texto de síntese transitam mas **não são persistidos** no servidor
  (`/transcrever` e `/gerar-sintese` em `backend/main.py`) e que o nome do paciente vai vazio ao
  backend/IA (`ia_clinica_service.dart`).

### Pendências
- Preencher os consoles só depois de: DPA com provedores (1.6/1.7), decisão do Calendar no 1º envio
  (0.8), definição de preço/cobrança (0.6) e e-mail do titular (0.7).
- Apple ainda precisa de `NSFaceIDUsageDescription` (4.6) e revisão das nutrition labels no envio.

## Keystore de produção e AAB assinado (itens 4.1/4.2) — Fase 5U (23/10/2026)

### Contexto
O release era assinado com a chave de debug — não serve para a Play Store. Foi gerada a **upload
key** de produção (fora do repositório) e produzidos o AAB e o APK assinados de verdade.

### O que mudou (arquivos)
1. **Chave gerada fora do repo:** `~/.mentall-pro-keys/` — `mentall-upload.jks` (PKCS12, RSA 4096,
   validade ~27 anos), `release.env` (variáveis `MENTALL_*`), `LEIA-ME.txt` (senha + backup),
   `fingerprints.txt` e `keystore.sha256` (integridade). **Nenhuma senha está neste arquivo.**
   SHA-1 do certificado: `C2:E5:C8:5E:93:04:15:18:FA:7C:F5:4A:51:A4:A5:47:6E:D8:B5:62`.
2. **`tools/build_release.sh` (novo)** — roda analyze/testes, gera AAB + APK assinados e valida a
   assinatura com `apksigner verify --print-certs`.
3. **`docs/RELEASE_ANDROID.md` (novo)** — operação, backup/restauração, Play App Signing e cadastro
   do SHA-1 no Google Cloud (Google Sign-In/Calendar).
4. **`.gitignore`** — bloqueia `*.jks`, `*.keystore`, `*.p12`, `key.properties`, `release.env`.
5. **`AGENTS.md`** — esta seção.

### Verificação
- `flutter analyze --no-pub` + `flutter test --no-pub`: **350/350 OK** (MEDI, 23/10).
- AAB assinado em `build/app/outputs/bundle/release/app-release.aab` (MEDI).
- APK assinado em `build/app/outputs/flutter-apk/app-release.apk`; `apksigner verify` OK (MEDI);
  cópia em `MentAllPRO-v1.0.58-release.apk` para teste no aparelho.
- SHA-1 do APK confere com a upload key (MEDI).
- **Pendente:** upload na Play Store (depende das contas 0.1/0.2), Play App Signing e cadastro do
  SHA-1 no Google Cloud.

### Pendências
- Item 4.3 (tag de versão) fica para o upload aprovado.
- Google Cloud: cadastrar o SHA-1 da upload key agora e o SHA-1 da chave de assinatura do app
  após ativar o Play App Signing.

## URLs legais dentro do app (item 1.5) — Fase 5T (23/10/2026)

### Contexto
Item 1.5 do checklist: o app mantinha apenas o texto embutido das páginas legais, divergente das
páginas publicadas em 23/10 em `mentallpro.com.br`. O texto in-app foi alinhado à versão 1.2 e as
telas passaram a abrir as URLs oficiais.

### O que mudou (arquivos)
1. **`lib/utils/links_legais.dart` (novo)** — URLs oficiais (privacidade, termos, exclusão, contato),
   versão publicada 1.2 e helper `abrir()` via `url_launcher` (navegador externo).
2. **`lib/screens/lgpd/politica_privacidade_page.dart`** — texto reescrito e alinhado à v1.2
   publicada (papéis, dados, compartilhamento real: Fly/SQLite, Magalu, Cloudflare, OpenAI, Groq,
   Resend, Mailu, Google Calendar opcional; retenção/exclusão; direitos; IA OpenAI-only) + atalho
   "Ler a versão oficial no site".
3. **`lib/screens/lgpd/termos_uso_page.dart`** — texto alinhado (removido DeepSeek como fallback;
   incluídos conta/segurança, exclusão e foro do usuário) + atalho "Ler a versão oficial no site".
4. **`lib/screens/lgpd/privacidade_seguranca_page.dart`** — "Documentos Legais" agora abre as URLs
   públicas (privacidade, termos, exclusão) e mantém "Versões offline no app".
5. **`lib/screens/configuracoes_page.dart`** — nova seção "Privacidade e documentos" com Política,
   Termos e Exclusão (site) e atalho para Privacidade e Segurança.
6. **`test/widgets/links_legais_test.dart` (novo)** — 4 testes: URL enviada ao `url_launcher`,
   constantes oficiais, telas mostram a versão 1.2 e abrem o site.
7. **`pubspec.yaml`** — `1.0.58+59` (APK de teste).
8. **`AGENTS.md`** — esta seção.

### Verificação
- `flutter analyze --no-pub`: **No issues found** (MEDI, 23/10).
- `flutter test --no-pub`: **350/350 OK** (MEDI, 23/10).
- `flutter build apk --release`: APK `MentAllPRO-v1.0.58.apk` (debug signing).
- Pendente NO APARELHO: abrir os links nas três telas e conferir que o navegador carrega as páginas
  publicadas.

### Pendências
- O texto in-app é um resumo fiel; a versão oficial é a do site.
- Revisão jurídica (itens 1.6/1.8/1.9) pode exigir ajuste nos dois textos.

## PDFs com fonte Unicode embutida (correção do travessão) — Fase 5R (23/10/2026)

### Contexto
Os PDFs gerados usavam as fontes padrão do pacote `pdf` (Helvetica, sem Unicode): travessão (—),
aspas curvas e o ✓ do cabeçalho saíam como quadrado e o texto "perdia a configuração". Reportado ao
abrir a exportação completa.

### O que mudou (arquivos)
1. **`assets/fonts/Lato-Regular.ttf` + `Lato-Bold.ttf` + `OFL.txt` (novos)** — fonte Unicode (OFL).
2. **`pubspec.yaml`** — `assets/fonts/` declarado nos assets.
3. **`lib/services/pdf_export_service.dart`** — `carregarAssets()` (logo + fontes), `temaPdf()` e
   `_novoDocumento()` com `ThemeData.withFont`; os 9 geradores usam o tema; "✓ Verificado" do
   cabeçalho virou texto.
4. **`lib/services/lgpd/pdf_arquitetura_lgpd_service.dart`** — mesmo tema; símbolos `✓`/`→` textuais.
5. **`lib/main.dart`** — `await PdfExportService.carregarAssets()` no boot.
6. **`test/services/exportacao_completa_test.dart`** — teste novo exige `/FontFile2` (TTF embutido).

### Verificação
- `flutter analyze --no-pub`: **No issues found** (MEDI, 23/10).
- `flutter test --no-pub`: **346/346 OK** (MEDI, 23/10).
- PDF de verificação gerado e renderizado: travessão aparece correto (MEDI, inspeção visual).
- `flutter build apk --release`: APK `MentAllPRO-v1.0.57.apk` (debug signing).
- Pendente NO APARELHO: gerar a exportação de novo e conferir o PDF.

### Pendências
- A fonte adiciona ~1,3 MB ao APK; avaliar subsetting depois.
- Símbolos fora do Latin-1 que a Lato não tenha continuam sem fallback; se aparecerem, incluir
  DejaVuSans como `fontFallback`.

## Exportação completa em PDF (prontuário + financeiro) — Fase 5Q (23/10/2026)

### Contexto
Levantado ao testar a exclusão de conta: se a conta é excluída, o prontuário cifrado continua no
aparelho, mas o app não abre — sem um PDF legível não há "utilização posterior". Entrega: PDF único
consolidado (dados, sessões, contratos e anamneses) + financeiro em arquivo separado, com
autenticação local antes de gerar. PDF não substitui o backup cifrado (é leitura/arquivo, não restore).

### O que mudou (arquivos)
1. **`lib/models/exportacao_paciente.dart` (novo)** — agrega paciente + sessões + contrato + anamnese.
2. **`lib/services/pdf_export_service.dart`** — `gerarPdfTudoConsolidado` (capa, índice, modelo do
   acordo e, por paciente: dados, contrato com status/aceite, anamnese respondida e sessões),
   `gerarPdfFinanceiroConsolidado` (por mês: recebido/a receber/convênio/pacote) e
   `exportarTudoEmPdf` (gera os dois e compartilha juntos).
3. **`lib/services/exportacao_arquivos{,_io,_web}.dart` (novos)** — compartilhamento multiplataforma
   dos PDFs (no web, stub que informa indisponibilidade).
4. **`lib/screens/exportar_tudo_page.dart` (novo)** — resumo do acervo, avisos (dado sensível e
   "PDF ≠ backup"), autenticação local (biometria/PIN) e geração.
5. **`lib/screens/exclusao_conta_page.dart`** — botão "Exportar tudo em PDF antes de continuar"
   no passo 1 da exclusão.
6. **`lib/screens/backup_restore_page.dart`** — ação "Exportar tudo em PDF" no AppBar.
7. **`test/services/exportacao_completa_test.dart` (novo)** — 4 testes de geração dos PDFs.
8. **`test/widgets/exportar_tudo_page_test.dart` (novo)** — 4 testes da tela.
9. **`pubspec.yaml`** — `1.0.56+57` (APK de teste).
10. **`AGENTS.md`** — esta seção.

### Verificação
- `flutter analyze --no-pub`: **No issues found** (MEDI, 23/10).
- `flutter test --no-pub`: **345/345 OK** (MEDI, 23/10; 8 testes novos).
- `flutter build apk --release`: APK `MentAllPRO-v1.0.56.apk` (debug signing).
- Pendente NO APARELHO: gerar a exportação com conta real, conferir o share sheet, abrir o PDF e
  validar contrato/anamnese/sessões; testar biometria/PIN.

### Pendências / decisões
- PDFs **não são cifrados** (23/10: aviso + autenticação agora; senha no PDF exige lib nova —
  syncfusion ou similar — e fica para depois).
- O financeiro é resumo histórico por mês (não por paciente); sessões arquivadas entram no
  histórico — validar com o uso.

## Exclusão de conta dentro do app — Fase 5P (23/10/2026)

### Contexto
Item 2.4a do checklist de publicação: Google Play e Apple 5.1.1(v) exigem exclusão de conta iniciada e
concluída dentro do app. O backend já tinha `DELETE /conta` (caminho B, item 2.4); faltava o fluxo
in-app e a limpeza da sessão local. O prontuário clínico é cifrado no aparelho e NÃO é apagado pelo
servidor — a tela diz isso com todas as letras e não promete "exclusão total".

### O que mudou (arquivos)
1. **`lib/screens/exclusao_conta_page.dart` (novo)** — 3 passos: aviso (apagado no servidor × mantido
   no aparelho × backup), confirmação digitada (`EXCLUIR`, comparação sem caixa como no backend) e
   recibo (data, contagens por tabela, retido, como apagar os dados do aparelho). O voltar fica
   bloqueado no recibo; "Concluir" navega para a tela de login/cadastro (`ContaPage`).
2. **`lib/services/api_client.dart`** — `excluirConta()` (DELETE /conta com corpo JSON e Bearer;
   devolve `{sucesso, recibo|erro, status}`; não lança) e `limparSessaoLocal()` (token JWT, conta,
   `app_config` e cofre `CredenciaisStore`; NÃO apaga prontuário/backups locais).
3. **`lib/screens/configuracoes_page.dart`** — seção "Conta" → "Excluir minha conta", oferecida só
   quando `ApiClient.possuiConta` (conta registrada); o login admin legado não vê a opção (spec §2).
4. **`test/services/api_client_exclusao_test.dart` (novo)** — 6 testes: método/corpo/Bearer, 403 da
   conta admin, 400 de confirmação, 401 sem sessão, falha de conexão e limpeza da sessão local.
5. **`test/widgets/exclusao_conta_page_test.dart` (novo)** — 7 testes: aviso, confirmação digitada,
   recibo/limpeza, 403, nova tentativa, conta já excluída e conclusão.
6. **`pubspec.yaml`** — `1.0.55+56` (APK de teste).
7. **`AGENTS.md`** — esta seção.

### Verificação
- `flutter analyze --no-pub`: **No issues found** (MEDI, 23/10).
- `flutter test --no-pub`: **337/337 OK** (MEDI, 23/10).
- `flutter build apk --release`: APK `MentAllPRO-v1.0.55.apk` com assinatura debug (MEDI).
- Pendente NO APARELHO: Configurações → Conta → Excluir minha conta, os 3 passos, cancelar o voltar
  no recibo e o retorno à tela de login.

### Pendências
- Página web de exclusão (item 2.5) continua pendente — requisito do Play.
- Retenção: a tela remete o prazo à Política de Privacidade (sem cravar 20 anos) — o prazo do doc 10
  ainda está em validação jurídica (item 1.9).

## Ações administrativas e detalhe do usuário — Fase 5A.2 (22/10/2026)

### Contexto
Continuação do lote P0 aprovado na análise do painel (P0.3 filtros/CSV, P0.4 detalhe do usuário,
P0.5 ações administrativas com auditoria). Objetivo: o dono resolve o dia a dia pelo painel, sem SQL,
e toda intervenção fica registrada.

### O que mudou (arquivos)
1. **`backend/services/db.py`** — nova tabela `admin_auditoria` (id, ator, ação, alvo, detalhe, IP,
   criado_em) + índice por data. Criada automaticamente no boot (Turso e SQLite).
2. **`backend/services/admin.py`** — `listar_usuarios()` reescrito em **uma única consulta** (fim do
   N+1), com filtros (`busca`, `status`, `plano`, `online`, `versao`, `ordenar`); `exportar_usuarios()`
   para CSV; `opcoes_filtros()`; `detalhar_usuario()` (só metadados: dispositivos, eventos,
   contratos/anamneses/lembretes por status, WhatsApp conectado, auditoria da conta);
   `registrar_auditoria()`/`listar_auditoria()`; `definir_status_usuario()` (ativo/suspenso) e
   `definir_plano_usuario()`.
3. **`backend/admin_ui.py`** — barra de filtros + botão **Exportar CSV**; link do e-mail para a página
   de detalhe; seção **Últimas ações administrativas**; nova página `pagina_usuario()` com cards,
   ações (suspender/reativar/plano/reenviar confirmação), dispositivos, eventos e auditoria da conta.
4. **`backend/services/usuarios.py`** — `renovar_token_confirmacao(email)`: gera novo token só para
   conta `pendente` (não mexe na senha).
5. **`backend/main.py`** — rotas `GET /admin/usuarios.csv`, `GET /admin/usuarios/{id}`,
   `POST /admin/usuarios/{id}/acao`; `/admin` aceita filtros e carrega opções/auditoria; login do app
   agora bloqueia **conta suspensa** (antes só `pendente` era recusada); helpers
   `_identidade_admin`/`_filtros_admin`.

### Verificação
```bash
cd backend && ./.venv/bin/python -B tests/run_isolated.py
./.venv/bin/python -B tests/run_isolated.py test_admin_acoes
```
Cobertura nova: filtros combinados, CSV (conteúdo/tipo), detalhe sem campo clínico, ações
(suspender/reativar/plano), reenvio de confirmação com e-mail mockado, exigência de sessão de admin e
login bloqueado para conta suspensa.

### Limitação conhecida
Suspender bloqueia **novos logins**, mas um JWT de app já emitido continua válido até expirar (8 h) —
não existe registro de tokens por usuário. Revogação global por usuário (token_version) fica para o
P1 de segurança.

## Alerta de WhatsApp desconectado na Home — Fase 5J (24/10/2026)
> **Nota:** o alerta está ligado em `home_page.dart` (commitado).


### Contexto
Os lembretes das sessões são enviados pelo WhatsApp (Wuzapi). Quando a sessão cai (celular
desconectado, logout, perda de conexão), o psicólogo não era avisado no app — só descobria quando um
lembrete falhava. Requisito do dono: **mostrar na home um alerta para reconectar**.

### O que mudou (arquivos)
1. **`lib/widgets/alerta_wuzapi.dart` (novo)** — banner de alerta com dois estados:
   - **"WhatsApp desconectado"** (configurado, mas `conectado`/`logado` = false): “A conexão caiu.
     Reconecte para não perder os lembretes das sessões.”
   - **"WhatsApp não conectado"** (ainda não configurado): convida a conectar.
   - Botão **Reconectar** abre a tela `WhatsappConexaoPage` e revalida ao voltar.
   - Verifica ao abrir a Home, ao retornar do segundo plano (`WidgetsBindingObserver`) e a cada **60 s**.
   - Se a consulta falhar (sem internet), **mantém o estado anterior** (não gera falso alarme).
   - Não consulta nada além de `GET /wuzapi/status` (metadados, sem conteúdo clínico).
2. **`lib/screens/home_page.dart`** — `AlertaWuzapi` no topo da home (antes da saudação).
3. **`test/widgets/alerta_wuzapi_test.dart`** (novo) — 4 testes (desconectado, não configurado,
   conectado, falha de consulta).

### Observação
O status vem do backend (`/wuzapi/status`), que agora também **sincroniza o banco** (Fase 5F), então o
card da Saúde do painel e o alerta do app concordam entre si.

## Alertas de e-mail na Saúde + gráfico diário — Fase 5N (24/10/2026)

### O que mudou
1. **`backend/services/saude.py`** — novo check **“E-mail (caixas)”**:
   - `info` quando o monitoramento não está configurado;
   - `atencao` quando há caixa com erro de leitura IMAP;
   - `atencao` quando existe e-mail **sem resposta há +24h**;
   - `ok` caso contrário (mostra quantos recebidos nos últimos 30 dias).
   Usa o cache de 5 min do `email_metricas` (não abre IMAP a cada carregamento).
2. **`backend/services/email_metricas.py`** — cada caixa agora devolve `serie_dias`
   (contagem por dia) e a agregação monta **`serie_dias`** com os últimos **14 dias**.
3. **`backend/admin_ui.py`** — a seção de métricas da página **E-mail** ganhou o gráfico
   **“Entradas por dia (14 dias)”** (barras, reutilizando `_grafico_barras`).
4. **`backend/tests/test_email_metricas.py`** — +4 testes da Saúde e marcador do gráfico.

## SLA por endereço + alerta no WhatsApp — Fase 5O (24/10/2026)

### O que mudou
1. **SLA por endereço** (`email_metricas`): `suporte@` = **4h** e `financeiro@` = **24h**
   (configurável no secret `MAIL_SLA_HORAS`). Cada endereço passa a ter: respondidas 30d,
   tempo médio de resposta, **pendentes fora do SLA**, **violações** e SLA configurado.
2. **Painel → E-mail**: novos cartões/colunas de SLA ("Fora do SLA", "Pendentes fora do SLA",
   "Violações") e botão **“Testar alerta no WhatsApp”**.
3. **Alerta por WhatsApp** (`backend/services/email_alertas.py`):
   - loop em background a cada **30 min** (env `EMAIL_ALERTAS_INTERVALO_MINUTOS`);
   - envia resumo via Wuzapi para o número do secret `EMAIL_ALERTA_WHATSAPP`;
   - **anti-spam**: no máximo 1 envio a cada **6h** (`EMAIL_ALERTAS_COOLDOWN_HORAS`);
   - estado em `email_alertas_estado` (tabela nova).
4. **Saúde do painel**: check “E-mail (caixas)” fica **atenção** quando há e-mails fora do SLA.
5. **Testes**: SLA (violação/pendente/dentro), alertas (cooldown, mensagem, envio) e rota de teste.

## Métricas das caixas de e-mail — Fase 5M (24/10/2026)

### Contexto
O dono pediu acompanhamento de **contato@, suporte@ e financeiro@** no painel: quantidade de
entradas, tempo de resposta e outros indicadores úteis para os admins.

### Como funciona
- Novo serviço **`backend/services/email_metricas.py`** coleta via **IMAP read-only**
  (`mail.mentallpro.com.br:993`) das caixas credenciadas no secret
  `MAIL_METRICAS_CAIXAS` (JSON: `[{email, senha, rotulo}]`).
- **Privacidade:** só contadores/tempos; nenhum assunto/corpo/remetente exposto; `SELECT readonly`
  + `BODY.PEEK` (nunca marca como lida); cache de 5 min (`?atualizar=1` força).
- Métricas por caixa: total, não lidas, recebidas hoje/7d/30d, enviadas 30d, **tempo médio de
  resposta**, respondidas 30d, **sem resposta há +24h**, última entrada, status.
- **Por endereço** (contato/suporte/financeiro): recebidas 7d/30d (varre To/Cc dos e-mails nas
  caixas monitoradas — cobre aliases como financeiro@ → anderson@).
- Pareamento de respostas por `In-Reply-To`/`References` × `Message-ID`.

### Arquivos
- `backend/services/email_metricas.py` (novo)
- `backend/admin_ui.py` — `pagina_email(..., metricas=None)` + `_secao_metricas_email`
- `backend/main.py` — import, `_pagina_email(metricas=...)` e rota `/admin/email` com cache
- `backend/tests/test_email_metricas.py` (novo) — 10 testes

### Operação
Secret `MAIL_METRICAS_CAIXAS` com as 4 caixas (contato, rodrigo, suporte, anderson).
A senha da `contato@` foi redefinida via API do Mailu e registrada em `CREDENCIAIS_EMAIL.txt`.

## Dashboard analítico — Fase 5L (24/10/2026)

### Contexto
Depois da transformação visual (Fase 5K), o dono pediu **mais cartões/gráficos** no dashboard
(ex.: lembretes por status, contratos por mês).

### O que foi adicionado
1. **`backend/services/admin.py` — `estatisticas_dashboard()`** ganhou:
   - `serie_contratos`: últimos 12 meses com **criados** e **aceitos** por mês;
   - `serie_lembretes`: últimos 12 meses com **total** e **entregues** por mês;
   - `contratos_status`, `lembretes_status`, `anamneses_status` (contagens por status).
2. **`backend/admin_ui.py`** — dashboard ganhou:
   - **Dois gráficos novos**:
     - **Contratos por mês** (barras agrupadas: criados × aceitos, legenda no rodapé);
     - **Lembretes por status** (donut: pendentes, enviados, falhas, cancelados + legenda).
   - **4 mini-KPIs**: Contratos aceitos, Anamneses respondidas, Lembretes entregues,
     Falhas de lembrete (em vermelho quando há falhas).
   - CSS novo para barras agrupadas, legendas e mini-KPIs (responsivo).
3. **`backend/tests/test_admin_analytics.py`** (novo) — 6 testes (séries de 12 meses, contratos,
   lembretes, anamneses e marcadores no HTML).

## Dashboard v2 (transformação visual) — Fase 5K (24/10/2026)

### Contexto
O painel era funcional, mas visualmente simples. O dono pediu a transformação no estilo de um mock
de admin dashboard web (sidebar colorida, topbar, cards com anéis, gráficos e tabelas limpas).

### O que mudou
1. **`backend/admin_ui.py`**
   - **Tema v2** (CSS anexado ao `_ESTILO`): sidebar em gradiente roxo, topbar clara com busca,
     botões de exportar/notificações, avatar; cards brancos com sombra; tabelas com cabeçalho
     uppercase; pills de saúde; formulários e botões redesenhados; responsivo (`@media 760px`).
   - **Novo layout compartilhado** (`_cabecalho_painel`): sidebar + topbar em **todas** as páginas
     (dados, segurança, 2FA, e-mail, lembretes, detalhe); `_cabecalho_email` usa o mesmo layout.
   - **Dashboard v2** (`pagina_dashboard`): KPIs (Psicólogos, Equipe, Online, Novos 7 dias, Contas
     pendentes), 3 **anéis de progresso** (online, contratos aceitos, lembretes entregues), gráfico de
     **barras** (cadastros por mês) e **donut** (distribuição de contas), Saúde, Operação, tabela de
     pessoas com filtros e auditoria — tudo em HTML/CSS/SVG puro (sem JS externo; CSP ok).
   - Helpers novos: `_icone` (SVG inline), `_anel`, `_grafico_barras`, `_grafico_donut`.
   - Login/2FA ganharam cards centralizados no novo tema.
2. **`backend/services/admin.py`** — `estatisticas_dashboard()`: série de 12 meses de cadastros,
   distribuição por status, percentuais de online/contratos/lembretes e variação de novos 7 dias.
3. **`backend/main.py`** — rota `/admin` calcula e passa `estatisticas` ao dashboard.
4. **`backend/tests/test_admin_visual.py`** (novo) — 7 testes (estatísticas + layout/marcadores).

### Compatibilidade
Nenhuma rota, ação, formulário ou texto funcional mudou (testes antigos de funcionalidade continuam
valendo). A transformação é só de apresentação, com gráficos calculados no servidor.

## Psicólogo × equipe do painel — Fase 5I (24/10/2026)

### Contexto
O painel contava **todos os usuários** como "Psicólogos" e listava administradores junto. Na prática:
- o dono (Rodrigo) é **psicólogo E admin** do painel;
- Anderson é **admin**, não psicólogo;
- a conta `helena.demo@` era apenas teste.

Papel do painel (`role`: admin/financeiro/suporte/user) não é a mesma coisa que "usa o app como
psicólogo". Foi criado um eixo separado.

### O que mudou (arquivos)
1. **`backend/services/db.py`** — coluna `usuarios.eh_psicologo` (migração automática, padrão 1).
2. **`backend/services/admin.py`**
   - `kpis()`: novos campos **`psicologos`** (eh_psicologo=1) e **`equipe`** (role do painel);
     `online_agora` passa a contar psicólogos online.
   - `listar_usuarios/exportar_usuarios`: filtro **`tipo`** (`psicologos` padrão, `equipe`, `todos`);
     coluna `eh_psicologo` no retorno/CSV.
   - `detalhar_usuario`: devolve `eh_psicologo`.
   - **`definir_eh_psicologo(usuario_id, valor)`**.
3. **`backend/main.py`** — filtro `tipo` no painel/CSV; ação `tipo` no detalhe do usuário (auditada como
   `usuario.tipo`).
4. **`backend/admin_ui.py`** — cards "Psicólogos" e "Equipe do painel", select de tipo na listagem,
   coluna "Psicólogo" na tabela, card e formulário "Tipo de conta" no detalhe.
5. **`backend/tests/test_admin_equipe.py`** (novo) — 10 testes.

### Limpeza de dados (executada em produção)
- `helena.demo@mentallpro.com.br` **excluída** via `services/exclusao_conta.excluir_conta` (registro em
  `auditoria_exclusoes`; tinha 2 dispositivos e nenhum dado clínico).
- `anderson.lemos@icloud.com` → `eh_psicologo = 0` (equipe/admin).
- Dono permanece com `eh_psicologo = 1` (psicólogo + admin).

## Lembretes no painel + teto de retry — Fase 5H (24/10/2026)

### Diagnóstico
A Saúde mostrava **"Lembretes: 4 com falha"** permanentemente. Investigação no banco de produção
(SQLite do volume, via `fly ssh`):
- **4 falhas históricas**: 29/09, 02/10, 09/10 e 16/10 (período em que o WhatsApp estava desconectado);
- **0 atrasados** e 11 pendentes futuros (nov/2026 a jan/2027);
- tentativas de **103, 104 e 180** por lembrete.

Bug encontrado: o scheduler roda a cada **30 s** e a janela de retry é de **60 min** — sem teto de
tentativas, um lembrete quebrado martelava o WhatsApp ~120x/hora.

### O que mudou (arquivos)
1. **`backend/services/lembrete_service.py`** — `MAX_TENTATIVAS_LEMBRETE` (env, padrão **12**): ao
   atingir o teto dentro da janela, marca `falha` e o reenvio passa a ser manual.
2. **`backend/services/admin.py`** — `resumo_lembretes()` (contagens em 1 consulta),
   `listar_lembretes_painel()` (**LGPD: não seleciona `mensagem`; telefone mascarado**),
   `reenviar_lembrete()`, `arquivar_lembrete()`, `arquivar_falhas_antigas(dias=7)`.
3. **`backend/services/saude.py`** — card separa **atrasados**, **falhas recentes (7 dias)** e
   **falhas antigas**: só as duas primeiras geram "atenção"; antigas aparecem como "arquiváveis".
4. **`backend/admin_ui.py`** — nav **Lembretes** (admin) + página com cards, filtro por status e ações
   (Reenviar / Arquivar / Arquivar falhas antigas).
5. **`backend/main.py`** — `GET /admin/lembretes`, `POST /admin/lembretes/{id}/acao`,
   `POST /admin/lembretes/arquivar-antigas` (papel admin; tudo auditado em `admin_auditoria`).
6. **`backend/tests/test_admin_lembretes.py`** (novo) — 17 testes (resumo, listagem LGPD, ações,
   saúde, teto de retry e HTTP).

### Uso
Painel → **Lembretes**: filtrar por status, **Reenviar** falhas pontuais, **Arquivar** falhas
antigas em lote. O card da Saúde fica limpo quando não há atrasados nem falhas nos últimos 7 dias.

## Backup portátil com senha + chave de recuperação — Fase 5G (24/10/2026)

### Contexto
O backup do app era um envelope **preso à chave mestra do aparelho** (`mentall_backup_v1`). Ao
reinstalar/limpar os dados do app (necessário para resolver login), a chave é destruída e o backup
deixa de abrir ("chave diferente ou integridade comprometida"). Não havia como migrar dados entre
aparelhos nem recuperar backups antigos.

### O que mudou (arquivos)
1. **`lib/services/encryption_service.dart`** — envelopes com senha:
   - `criptografarEnvelopeComSenha` / `descriptografarEnvelopeComSenha` (formato `mentall_backup_v2`:
     PBKDF2-SHA256 100k + salt aleatório + AES-256-GCM + HMAC-SHA256);
   - `exportarChaveProtegida` / `importarChaveProtegida` (formato `mentall_chave_v1`): embrulha a
     chave mestra com senha para recuperar backups antigos em aparelho novo.
2. **`lib/services/backup_service.dart`** — `exportarParaJsonPortavel(senha)`,
   `importarDeJson(json, {senha})` (detecta v1 e v2), `ehBackupComSenha`,
   `exportarChaveRecuperacao`/`importarChaveRecuperacao`; `exportarParaJson` (v1) refatorado para
   `_montarDados()` e mantido por compatibilidade com o backup agendado.
3. **`lib/screens/backup_restore_page.dart`** — ao exportar, escolha **Portátil (com senha)** ou
   **Só neste aparelho**; ao importar, detecta v2 e pede a senha; novo card **Chave de recuperação**
   (exportar/importar com confirmação de substituição de chave) + aviso na tela.
4. **`test/services/backup_portavel_test.dart`** (novo) — v2 roundtrip em "outro aparelho", senha
   errada, arquivo adulterado (integridade), v1 compatível e chave de recuperação.

### Segurança
- v2 usa salt + nonce aleatórios por arquivo, KDF PBKDF2 100k e MAC em tempo constante.
- A senha do backup **não** é armazenada em lugar nenhum; sem ela o arquivo não abre.
- Importar chave de recuperação substitui a chave local — a UI avisa e pede confirmação.

### Observação
O backup portátil resolve o cenário "troquei/reinstalei o aparelho". Backups **v1 antigos** continuam
abrindo somente no aparelho original **ou** em outro aparelho após importar a **chave de recuperação**
(que precisa ter sido exportada antes).

## Card do WhatsApp com status ao vivo — Fase 5F (23/10/2026)

### Contexto
O card **"WhatsApp (Wuzapi)"** da Saúde lia apenas a coluna `conectado` de `wuzapi_instancias`, que só
era atualizada em eventos de reconexão. Depois da migração do banco ela ficou defasada: o painel dizia
**"0 de 1 conectado"** enquanto o Wuzapi estava **conectado e recebendo mensagens** (confirmado por
`GET /wuzapi/status`).

### O que mudou (arquivos)
1. **`backend/services/wuzapi_admin.py`** — `status(owner_id, timeout=...)` ganhou timeout configurável;
   interno `_consultar_status()` devolve `(estado, erro_de_consulta)`; novo
   **`sincronizar_status()`**: consulta ao vivo e **grava `conectado` no banco** (só grava se a consulta
   funcionou — falha de rede não derruba a flag).
2. **`backend/services/saude.py`** — `_wuzapi()` agora consulta o **status ao vivo** (timeout de 3 s,
   até 5 instâncias) e mostra a verdade: `ok · 1 de 1 WhatsApp conectados` ou `atenção · 0 de 1 ...`;
   se a consulta ao vivo falhar, cai para o banco e informa "(consulta ao vivo falhou em N)".
3. **`backend/main.py`** — `GET /wuzapi/status` (tela de WhatsApp do app) passa a usar
   `sincronizar_status()`, mantendo o banco fresco sempre que o app consulta.
4. **`backend/tests/test_saude_wuzapi.py`** (novo) + ajuste do teste antigo em
   `test_painel_operacional.py` (mock da consulta ao vivo).

### Verificação
```bash
cd backend && ./.venv/bin/python -B tests/run_isolated.py test_saude_wuzapi
./.venv/bin/python -B tests/run_isolated.py
```

## Painel instalável (PWA) e responsivo no celular — Fase 5E (23/10/2026)

### Contexto
O painel é web server-rendered e funciona bem no desktop, mas no celular as tabelas ficavam apertadas e
não dava para "instalar" como app. Em vez de um app nativo (custo alto para 1–3 admins), foi feito um
**PWA** — instalável na tela inicial, sem loja e sem build — e o layout ganhou **responsividade**.

### O que mudou (arquivos)
1. **`backend/static/admin/`** (novo) — `sw.js` (service worker mínimo: sempre busca na rede, **nunca
   cacheia dados do painel**), `painel.js` (registra o SW, adapta tabelas no celular e mostra o botão
   "Instalar app" quando o navegador permite) e ícones PNG 192/512/180 (roxo com "M").
2. **`backend/main.py`** — rotas públicas (sem login, só assets estáticos):
   `GET /admin/manifest.webmanifest`, `/admin/sw.js` (com `Service-Worker-Allowed: /admin`),
   `/admin/painel.js`, `/admin/icon-192.png`, `/admin/icon-512.png`, `/admin/apple-touch-icon.png`.
3. **`backend/admin_ui.py`** — `_PWA_HEAD` injetado no `<head>` de **todas as páginas do painel**
   (manifest, theme-color, ícone, apple-touch-icon, script) e bloco de **CSS responsivo**
   (`@media max-width:760px`: header/nav quebrando, cards menores, tabelas em rolagem horizontal,
   formulários 100% largura, ações empilhadas).
4. **`backend/tests/test_admin_pwa.py`** (novo) — 6 testes.

### Como instalar no celular
Abra `https://admin.mentallpro.com.br/admin` no Chrome/Safari e use **"Adicionar à tela inicial"**
(ou o botão "Instalar app" quando aparecer). Abre em tela cheia, ícone próprio, e sempre com dados frescos.

### Segurança
- PWA **não** cacheia páginas/dados (service worker é passthrough) — nada sensível fica no aparelho.
- Assets do manifest/ícones são públicos (não expõem nada além do nome do painel).
- 2FA, sessão com inatividade e logout global continuam valendo normalmente no app instalado.

## IA de síntese e transcrição separadas no painel — Fase 5D (23/10/2026)

### Contexto
O painel mostrava apenas um card **"IA clínica"**, que na verdade cobria só a cadeia de **texto/síntese**
(`IA_MODEL_PROVIDER`/`IA_PROVIDER_ORDER`, cascata openai→deepseek com circuit breaker). A **transcrição**
de áudio usa outro provedor/modelo (`TRANSCRICAO_PROVIDER`/`TRANSCRICAO_MODEL`, hoje Groq
`whisper-large-v3-turbo`) e **não aparecia em lugar nenhum** — se quebrasse, o painel continuava "ok".

### O que mudou (arquivos)
1. **`backend/services/transcricao.py`** — registro em memória da **última falha** (`_registrar_falha`,
   `ultima_falha`, `limpar_ultima_falha`): provider + mensagem curta (160 chars), sem áudio/conteúdo.
   Some no restart/deploy (é estado operacional da instância).
2. **`backend/services/saude.py`** — `_ia` renomeada para **`_ia_sintese`** (card "IA de síntese";
   alias `_ia` mantido por compatibilidade) e novo check **`_transcricao`**:
   - provedor/modelo atuais (ex.: `groq/whisper-large-v3-turbo`);
   - chave da API presente (`GROQ_API_KEY` ou `OPENAI_API_KEY`);
   - **atenção** se houve falha nas últimas 24 h, com horário e motivo curto.
3. **`backend/tests/test_saude_transcricao.py`** (novo) — 8 testes.

### Verificação
```bash
cd backend && ./.venv/bin/python -B tests/run_isolated.py test_saude_transcricao
./.venv/bin/python -B tests/run_isolated.py
```

### Observação
A síntese **consome** o texto da transcrição no fluxo (`/transcrever` → app → `/gerar-sintese`), mas são
duas chamadas e dois monitoramentos independentes — agora visíveis separadamente na Saúde do painel.

## Banco local no volume do Fly — Fase 5C (22/10/2026)

### Contexto
O Turso de produção estava em **`aws-us-west-2` (Oregon, EUA)** enquanto o backend roda em **`gru`
(São Paulo)**: cada consulta custava **1,2–2 s** e o dashboard do painel levava **~54 s** (o navegador
desistia e mostrava erro). O banco tem apenas **0,5 MB / 150 linhas** — não justifica dependência
remota. Decisão: **SQLite persistente no volume do Fly**, sem Turso.

### O que mudou (arquivos)
1. **`backend/services/db.py`** — `SQLITE_PATH` (env) define o arquivo SQLite persistente; helper
   `_sqlite_path()`; `_conectar_local()` respeita o caminho; novo branch em `_obter_conexao()`:
   se `SQLITE_PATH` existe e **não** há Turso configurado, usa o arquivo local como banco oficial
   (sem log de "fallback efêmero").
2. **`backend/services/saude.py`** — com `SQLITE_PATH` o card "Banco de dados" mostra
   **`ok · SQLite local (volume — persistente)`**.
3. **`fly.toml`** — `[mounts] source = "mentall_data" destination = "/data"` e
   `[env] SQLITE_PATH = "/data/mentall.db"`.
4. **`backend/scripts/migrar_turso_para_sqlite.py`** (novo) — migra schema + dados do Turso para o
   arquivo no volume, com verificação de contagens; seguro para reexecutar.
5. **`backend/tests/test_db_local_path.py`** (novo) — cobre `SQLITE_PATH` e conexão local.
6. **`.env.example`** — documenta `SQLITE_PATH`.

### Passos da migração (executados uma vez)
1. `fly volumes create mentall_data --region gru --size 1`
2. deploy (o volume é montado em `/data`; Turso ainda configurado → app continua no Turso)
3. `fly ssh console -C "python /app/scripts/migrar_turso_para_sqlite.py"`
4. `fly secrets unset TURSO_DATABASE_URL TURSO_AUTH_TOKEN` → app reinicia no SQLite do volume
5. validação: health, login, painel rápido, contagens, e-mail
6. **Rollback:** `fly secrets set TURSO_DATABASE_URL=... TURSO_AUTH_TOKEN=...` (banco Turso permanece
   intacto como backup por 30 dias)

### Backup / durabilidade
- Snapshots automáticos diários do volume do Fly (`fly volumes snapshots list`).
- O banco Turso **não é apagado** — vira backup congelado da migração.
- Próximo passo recomendado: rotina diária de `VACUUM INTO /data/backups/...` + cópia para R2
  (Litestream) quando definirmos o bucket.

### Trade-offs
- **1 máquina só** (já era o caso; `min_machines_running = 1`).
- Latência deixa de existir: queries em ~1 ms, painel instantâneo, app mais rápido.
- Sem replicação geográfica: se a máquina/volume cair, restaura-se pelo snapshot.

## Papéis e revogação de sessão do app — Fase 5B.2 (22/10/2026)

### Contexto
Complemento do P1 de segurança: o painel agora edita o papel (RBAC) de qualquer pessoa e consegue
encerrar todas as sessões do **app** de um usuário — antes, suspender bloqueava só logins novos e um
JWT já emitido continuava valendo até expirar (8 h).

### O que mudou (arquivos)
1. **`backend/services/db.py`** — migração incremental `usuarios.token_version` (usa o helper
   `_garantir_coluna`, seguro para bancos existentes).
2. **`backend/services/usuarios.py`** — `incrementar_token_version(usuario_id)`: sobe a versão e
   invalida todos os JWT de app emitidos.
3. **`backend/services/admin.py`** — `definir_papel_usuario()` (admin/financeiro/suporte/user) e
   `revogar_sessoes_app()`; `detalhar_usuario()` passa a devolver `token_version`.
4. **`backend/main.py`** — JWT de app agora carrega o claim **`tv`** (versão); `_verificar_token()`
   confere `tv` e o **status** da conta com cache de 30 s (`_ESTADO_TOKEN_CACHE`, invalidado pelas
   ações do painel); ações novas no detalhe do usuário: **trocar papel** (com trava para não remover o
   próprio admin) e **encerrar sessões do app**; suspender/reativar também revoga as sessões do app.
5. **`backend/admin_ui.py`** — formulários "Salvar papel" e "Encerrar sessões do app" no detalhe,
   card "Sessões do app revogadas".
6. **`backend/tests/test_painel_seguranca_app.py`** (novo).

### Verificação
```bash
cd backend && ./.venv/bin/python -B tests/run_isolated.py test_painel_seguranca_app
./.venv/bin/python -B tests/run_isolated.py
```
Cobre: token antigo rejeitado após revogação, token novo aceito, token legado (sem tv) preservado,
conta suspensa derrubando token existente, troca de papel com auditoria, trava de self-demote,
suspensão revogando sessões e login de app emitindo `tv`.

### Trade-off documentado
`_verificar_token` usa cache de 30 s do estado do usuário (1 leitura de banco por usuário a cada 30 s,
em vez de 1 por chamada). As ações do painel invalidam a chave na mesma instância; com mais de uma
instância do backend, a revogação pode levar até 30 s para valer nas outras. Hoje o Fly roda 1 máquina
(`min_machines_running = 1`), então na prática é imediato.

### Subdomínio do painel
O kit inclui a parte de infra em `infra/` (Caddy + runbook + verificação + opção Cloudflare Access).
O DNS `admin.mentallpro.com.br → 201.23.82.2` **já existe**; falta só adicionar o bloco no Caddyfile
da VPS e recarregar o Caddy.

## Segurança do painel — Fase 5B.1 (22/10/2026)

### Contexto
Primeiro lote do P1 de segurança aprovado na análise do painel: o painel guarda dados de todos os
psicólogos, então precisa de 2FA, sessão que expira, papéis e defesa anti-CSRF.

### O que mudou (arquivos)
1. **`backend/services/admin_seguranca.py` (novo)** — implementação própria de **TOTP** (RFC 6238,
   HMAC-SHA1, 6 dígitos, 30 s, janela ±1) sem dependências novas; **códigos de recuperação** (8,
   hash SHA-256, uso único); **sessões administrativas** (`admin_sessoes`) com expiração por
   inatividade (`ADMIN_IDLE_MINUTOS`, padrão 60); `revogar_todas_sessoes()` para "sair de todos os
   dispositivos"; `ADMIN_2FA_OBRIGATORIO` (padrão desligado) obriga a ativação.
2. **`backend/services/db.py`** — tabelas `admin_seguranca` (segredo TOTP ativo/pendente + hashes de
   backup) e `admin_sessoes` (jti, ator, criado, último visto) + índice.
3. **`backend/main.py`** — login em **duas etapas** (senha → cookie curto `/admin/2fa` → código);
   helpers `_sessao_admin`/`_papel_admin`/`_exigir_papel`; gate passa a aceitar papéis
   **admin / financeiro / suporte**; `/admin/seguranca` (ativar/desativar 2FA, ver status, sair de
   todos os dispositivos), `/admin/2fa` (GET/POST), `/admin/logout-todos`; **anti-CSRF por
   Origin/Referer** em todos os POSTs do painel (defesa em profundidade ao SameSite=Strict).
4. **`backend/admin_ui.py`** — nav com "Segurança" (e "E-mail" só para admin); páginas
   `pagina_2fa_login`, `pagina_2fa_ativar`, `pagina_2fa_backup`, `pagina_seguranca`,
   `pagina_sem_permissao`; página de detalhe esconde ações para papéis não-admin.
5. Papéis: **admin** = tudo; **financeiro** = painel + CSV (sem e-mail, sem ações, sem auditoria);
   **suporte** = painel + detalhe somente leitura.

### Verificação
```bash
cd backend && ./.venv/bin/python -B tests/run_isolated.py
./.venv/bin/python -B tests/run_isolated.py test_admin_seguranca
```
Cobre: vetor oficial RFC 6238, ativação + códigos de backup (uso único), sessão expirando por
inatividade, logout global derrubando cookies, login em duas etapas, papéis financeiro/suporte,
bloqueio de POST cross-site por Origin e modo `ADMIN_2FA_OBRIGATORIO`.

### Pendências (5B.2)
- Painel em subdomínio dedicado `admin.mentallpro.com.br` (CNAME + TLS) e, se o DNS for para Cloudflare,
  **Cloudflare Access** (e-mail OTP/Google) como camada extra antes do próprio login.
- Tokens de formulário por sessão (o Origin/Referer + SameSite já cobrem o vetor prático de CSRF).
- Revogação de JWT de **app** por usuário (token_version) — hoje suspender bloqueia login novo, mas
  JWT já emitido vale até expirar.

## Painel operacional — Fase 5A (22/10/2026)

### Contexto
Análise profunda do painel (`ANALISE_PAINEL_E_GITHUB_2026-10-22.md`, fora do repo) apontou 6 lacunas:
painel read-only, "Receita do mês" vazio, sem saúde do sistema, sem auditoria, 3 falhas de segurança e
dados coletados sem uso. O dono aprovou o primeiro lote (P0.1, P0.2, P0.6, P0.7).

### O que mudou (arquivos)
1. **`backend/services/saude.py` (novo)** — verificações isoladas de Banco (Turso/local), IA (circuito
   por provedor), Wuzapi (instâncias conectadas/total), Mailu (API com timeout de 4 s), SMTP e
   Lembretes (atrasados/falhas). Nenhuma verificação derruba o painel; nenhuma lê conteúdo clínico.
2. **`backend/services/admin.py`** — `kpis_operacionais()`: novos cadastros 7/30 d, contas ativas e
   pendentes, contratos (aceitos/pendentes), anamneses (respondidas/pendentes), lembretes
   (enviados/entregues/lidos/falhas/pendentes) e top-3 versões do app. Só números.
3. **`backend/admin_ui.py`** — dashboard ganhou a seção **Saúde do sistema** (pills ok/atenção/erro
   com detalhe e latência) e **Operação** (contratos, anamneses, lembretes, versões), novos cards
   "Novos (7 dias)" e "Contas pendentes" e **removido o placeholder "Receita do mês"** (volta quando
   existir cobrança). Header compartilhado `_cabecalho_painel()`.
4. **`backend/main.py`** — rota `/admin` passa saúde + KPIs; **rate limit do login** agora é por IP
   (30/min) **e por conta** (5/min, vale entre IPs — antes era um bucket global: 10 erros de qualquer
   IP bloqueavam todos os admins); **logout revoga o jti** em `tokens_revogados` e
   `_usuario_admin_autenticado()` recusa jti revogado (antes o cookie continuava valendo até 8 h
   após "Sair"); `_revogar_token()` novo.
5. **`backend/services/email_admin.py`** — `listar_caixas/listar_aliases(..., timeout=)` opcional
   (usado pela verificação de saúde com prazo curto).

### Verificação
```bash
cd backend && ./.venv/bin/python -B tests/run_isolated.py          # suíte completa
./.venv/bin/python -B tests/run_isolated.py test_painel_operacional # módulo novo
```
Novos testes: KPIs (contagens/janelas/versões), saúde (isolamento de falha e cada check), rate limit
(por conta entre IPs e por IP) e logout (cookie revogado + registro em `tokens_revogados`).

### Pendências
- P1 (próximo lote): 2FA TOTP, CSRF, expiração ociosa, papéis, painel em `admin.mentallpro.com.br`
  com Cloudflare Access.
- Auditoria das ações administrativas (tabela `admin_auditoria`) ficou para o P0.5 — depende das
  ações de conta (P0.4/P0.5), que não entraram neste lote.
- "Receita/MRR" só com a frente de cobrança (Asaas/Pix) — prioridade de produto.

## E-mail (Mailu) no painel do dono — Fase 4 (22/10/2026)

### Contexto
O domínio `mentallpro.com.br` passou a ter servidor de e-mail próprio (Mailu 2.0 na VPS Magalu, com
relay de saída Resend — detalhes em `deploy-magalu/mail/RUNBOOK-MAILU.md`, fora deste repositório).
O dono pediu para **administrar as caixas dos funcionários pelo painel do dono** (`/admin`), sem abrir
outro painel. O token da API do Mailu fica só no backend; o navegador nunca vê credencial de e-mail.

### O que mudou (arquivos)
1. **`backend/services/email_admin.py` (novo)** — cliente da API do Mailu com httpx (timeout 15 s).
   Config: `MAILU_API_URL`, `MAILU_API_TOKEN`, `MAILU_DOMINIO`. Operações: listar caixas/aliases,
   criar caixa (senha temporária gerada no backend), redefinir senha, ativar/desativar, excluir e
   gerenciar aliases. **Proteções:** toda operação valida que o endereço é do domínio configurado;
   caixa com `global_admin` não pode ser desativada nem excluída pelo painel; erros da API viram
   mensagens curtas (sem detalhe interno).
2. **`backend/admin_ui.py`** — nav do painel (`Psicólogos | E-mail`), `pagina_email()` (cards, tabela
   de caixas com ações, criação com senha exibida **uma única vez**, tabela de aliases e formulário)
   e `pagina_confirmar_exclusao()` (exclusão só por POST com `confirmar=sim`). Todo valor dinâmico
   continua passando por `_esc` (anti-XSS).
3. **`backend/main.py`** — rotas `GET /admin/email`, `POST /admin/email/criar`,
   `POST /admin/email/senha`, `POST /admin/email/status`, `GET|POST /admin/email/excluir`,
   `POST /admin/email/alias/criar`, `POST /admin/email/alias/excluir`. Todas sob o gate
   `_usuario_admin_autenticado` (cookie httpOnly do painel) + `_rate_limit_check`.
4. **`backend/.env.example`** — `MAILU_API_URL`, `MAILU_API_TOKEN`, `MAILU_DOMINIO`.
5. **`backend/tests/test_email_admin.py` (novo)** — serviço (payload, validação de prefixo/domínio,
   cota limitada a 10 GB, proteções da caixa admin), UI (escape de HTML, senha exibida uma vez) e
   rotas (login, listagem, criar, desativar, caixa admin protegida, alias externo recusado).

### Verificação
```bash
cd backend && ./.venv/bin/python -B tests/run_isolated.py
```
Smoke real (com token): listar as caixas pela API do Mailu — comandos na seção "Integração com o
painel" do runbook. A senha inicial aparece **uma vez** na tela; não é gravada em banco nem em log.

### Pendências
- Definir `MAILU_API_TOKEN` (e URL/domínio) nos secrets do Fly: `fly secrets set MAILU_API_TOKEN=...`
  e reiniciar o backend local para o painel sair do modo "não configurado".
- Criar as caixas restantes dos funcionários pelo painel (a do Anderson já foi criada).
- (Opcional) trocar o SMTP de recuperação de PIN (hoje Gmail) pela submission do Mailu
  (`mail.mentallpro.com.br:587` com uma caixa de serviço `naoresponder@`).

## Google Calendar — Fase 2A (21/10/2026)

### Contexto
Integração **opcional** com o Google Calendar, **OAuth no aparelho** (sem backend de agenda). O
profissional conecta a própria conta; o app cria/atualiza/exclui eventos ao salvar, editar, excluir
ou cancelar. **Nenhum nome de paciente é enviado** por padrão: o resumo é “Sessão” (ou o título do
evento geral), com data/hora e sala. Android primeiro; iOS fica para depois.

### Estado atual (21/10/2026)
- **OAuth funcionou no aparelho** em **Testing**, com o Gmail cadastrado como test user. O erro
  “Acesso bloqueado: o app não concluiu a verificação” era o portão do Google (app em produção/sem
  verificação ou conta fora dos test users), não bug do app.
- **O calendário do paciente não muda:** o app não envia `attendees` e usa `sendUpdates: none`; ele
  escreve apenas no calendário escolhido **pelo profissional**.
- **Sair de Testing:** a verificação de sensitive scopes leva **3–5 dias úteis** após submissão
  completa (oficial), com **1–3 semanas** de preparação realista; exige homepage e política públicas
  no mesmo domínio, Search Console, branding, vídeo em inglês e justificativa dos scopes.
  `mentallpro.com.br` ainda é “Em construção!” e bloqueia a verificação.
- **Custo:** API gratuita dentro das cotas (10.000 req/min por projeto, 600/min por usuário,
  1.000.000/dia); acima disso o Google planeja cobrar em 2026. A verificação é gratuita.
- Detalhes, checklist de verificação e troubleshooting em `docs/google_calendar_2a.md`.

### O que mudou (arquivos)
- `pubspec.yaml`: `google_sign_in ^7.2.0`, `googleapis ^17.0.0`,
  `extension_google_sign_in_as_googleapis_auth ^3.0.0`, `googleapis_auth ^2.3.5`.
- `lib/config/google_calendar_config.dart`: client IDs (via `--dart-define`), scopes
  `calendar.events.owned` + `calendar.calendarlist.readonly`.
- `lib/models/compromisso.dart` (+ `.g.dart`): `googleEventId`, `googleCalendarId`, `googleSyncedAt`.
- `lib/services/google_calendar_api.dart` (interface/fake-friendly), `google_calendar_google_api.dart`
  (Google real), `google_calendar_service.dart` (sync).
- `lib/screens/google_calendar_page.dart` + entrada em `configuracoes_page.dart` (Integrações).
- `lib/providers/service_providers.dart`: providers do serviço/API.
- `lib/screens/agenda_page.dart` e `home_page.dart`: sync em segundo plano após criar/editar/excluir/
  cancelar/reagendar; `configuracoes_service.dart`: calendário, auto-sync e último sync.
- `lib/services/backup_service.dart`: export/import dos campos Google.
- LGPD: `docs/lgpd/03,04,05,06,09` e `_base_factual.md`; textos de privacidade/termos no app.
- Testes: `google_calendar_service_test` (6), `google_calendar_page_test` (1), asserts em modelo/
  backup/recorrência.

### Verificação
- `flutter analyze --no-pub`: **No issues found!**
- `flutter test --no-pub`: **314/314**.
- `flutter build apk --release`: OK (~48 s).
- APK de teste: **`MentAllPRO-v1.0.52.apk`** (`1.0.52+53`, ~77 MB), sha256
  `5c5736e35c3088f05e17a5f1d90d1b1e101d8d733de0c9a280eefbc2c11bec8d` (assinatura debug).

### Pendências
- **Testar no aparelho o fluxo completo:** a conexão já foi validada; faltam criar/editar/excluir,
  evento geral e desconectar conferindo no Google Calendar. O client Android precisa do package
  `com.mentall.app` + SHA-1 de debug `B6:38:…:21:F7`; se o login falhar com
  `clientConfigurationError`, é SHA-1/package.
- **Release/loja:** adicionar o SHA-1 do keystore de release (ou Play App Signing) e passar pela
  **verificação do Google** para os scopes sensíveis (ver `docs/google_calendar_2a.md`).
- **iOS:** adiar; o bundle atual ainda é `com.example.prontuarioTcc`.
- **Limites:** sem sync com o app fechado; a recorrência acompanha as ocorrências geradas (até
  52/180 dias) — limitar a 90 dias fica pendente; importar eventos ocupados do Google (conflitos) e
  sync ao abrir a Agenda ficam para a etapa seguinte.
- Nada foi commitado.

## Release (20/10/2026) — APK 1.0.51+52

### Contexto
Rodrigo pediu o APK após as Fases 0/1 da agenda. A versão foi bumpada de `1.0.50+51` para
**`1.0.51+52`** para não sobrescrever o APK anterior.

### O que mudou (arquivos)
- `pubspec.yaml`: `1.0.51+52`.
- `MentAllPRO-v1.0.51.apk` (~76 MB), sha256
  `91b30f75f15e29035e26e83cf4b2a40b1449f09e54a9d8afbb6c380deafe0c11`.

### Verificação
- `flutter analyze --no-pub`: **No issues found!**
- `flutter test --no-pub`: **306/306**.
- `flutter build apk --release`: OK (~63 s; aviso KGP já conhecido de `package_info_plus`,
  `sentry_flutter`, `share_plus`, `wakelock_plus`).
- Assinatura **debug** (`android/key.properties` ausente), como nos APKs anteriores.

### Pendências
- **Testar no aparelho**: agenda (evento geral, filtros, modo Salas, aba Agenda) e lembretes da Fase 0.
- O APK usa a **árvore atual**, que já tinha alterações de outra sessão em
  `whatsapp_conexao_page.dart`/`ia_clinica_service.dart`; elas compilam e passam nos testes, mas não
  foram revisadas nesta rodada.
- Falta o keystore de release para publicação nas lojas.

## Agenda — Fase 1 (20/10/2026)

### Contexto
Fase 1 da agenda para **psicólogo individual**, local-first. Sem clínica, sem teleconsulta (plano
separado) e mantendo o **wuzapi**. O objetivo foi fechar o gap de produto do PsicoManager sem
backend novo.

### O que mudou (arquivos)
- `lib/models/compromisso.dart` (+ `compromisso.g.dart`): novos campos `tipoEvento`
  (`sessao`/`evento_geral`), `modalidade` (`presencial`/`online`), `sala`, `servico` e `linkOnline`,
  com **defaults no adapter** (registros antigos continuam legíveis).
- `lib/widgets/compromisso_form_dialog.dart`: seletor de **Tipo**, modalidade, sala/local, serviço e
  link online; **evento geral** salva sem paciente; lembrete do paciente fica oculto no evento geral.
- `lib/screens/agenda_page.dart`: filtros de **Tipo** e **Modalidade**; novo modo **Salas** (agrupa a
  semana por sala); card mostra Online/sala/serviço; grade do mês respeita os filtros.
- `lib/utils/agenda_helpers.dart` (novo): `filtrarCompromissos` e `agruparPorSala` (lógica pura).
- `lib/screens/main_shell.dart`: **aba Agenda** adicionada à navegação principal (Home, Pacientes,
  Financeiro, Agenda).
- `lib/services/compromisso_service.dart`: novas campos propagados em criar/editar/recorrência e na
  remoção de criptografia.
- `lib/services/backup_service.dart`: export/import dos novos campos (compatível com backup antigo).
- Testes: `compromisso_test` (+2), `agenda_helpers_test` (+3), `compromisso_form_dialog_test` (+1),
  `compromisso_service_test` (asserts extras) e `backup_service_test` (asserts extras).

### Verificação
- `flutter analyze --no-pub`: **No issues found!**
- `flutter test --no-pub`: **306/306**.
- `dart run build_runner build`: regenerou apenas `compromisso.g.dart`.

### Pendências
- **Testar no aparelho** os novos campos, o evento geral e o modo Salas.
- **Aba Agenda** criada; falta validar a navegação e o carregamento lazy no aparelho.
- **Sala** é texto livre; não há entidade sala, capacidade ou conflito por sala.
- “Próximas sessões” na ficha do paciente ainda não foi implementado.
- Google Calendar, confirmação e agendamento público continuam na **Fase 2**.
- Conflito de evento único segue com override; editar o pai ainda não propaga para as ocorrências.
- Nada foi commitado.

## Agenda — Fase 0 (20/10/2026)

### Contexto
Rodrigo pediu para melhorar a agenda a partir do PsicoManager. Escopo decidido: **psicólogo
individual**, **manter wuzapi**, **teleconsulta em plano separado**, **sem clínica agora**. Antes das
features, foram corrigidos bugs de recorrência, conflito, lembrete e backup.

### O que mudou (arquivos)
- `lib/widgets/compromisso_form_dialog.dart`: ao editar, preserva `recorrencia`/
  `dataLimiteRecorrencia` do pai e `compromissoPaiId` da ocorrência.
- `lib/services/compromisso_service.dart`: nova `ConflitoDeHorarioException`; série recorrente
  **verifica todas as datas antes de gravar** e aborta sem escrita parcial (override via
  `permitirConflito`); ocorrências retornadas em **texto claro** (corrige lembrete com criptograma).
- `lib/services/lembrete_service.dart`: removeu `matchDateTimeComponents: time` (não repete mais todo
  dia); agenda no **instante UTC correto**; pede permissão de notificação/alarme exato no Android.
- `lib/screens/agenda_page.dart`: rearma lembrete ao voltar para “agendado”; trata conflito de série.
- `lib/screens/home_page.dart`: mesmo tratamento no atalho de criação.
- `lib/services/backup_service.dart`: backup agora exporta/importa `compromissos` (compatível com
  backup antigo sem a seção).
- Testes: `compromisso_service_test` (+4), `backup_service_test` (+1),
  `compromisso_form_dialog_test` (+2), `lembrete_service_test` (+1).

### Verificação
- `flutter analyze --no-pub`: **No issues found!**
- `flutter test --no-pub`: **298/298**.

### Pendências
- **Testar no aparelho** o lembrete (permissão Android 13+, alarme exato, fuso) e o reagendamento.
- **Fase 1** (não iniciada): evento geral sem paciente, modalidade presencial/online, sala/local,
  serviço, filtros e “Agenda de salas”.
- Conflito de **evento único** continua com override (“Agendar assim mesmo”); só a série é fail-closed.
- Editar o pai **não propaga** ainda para as ocorrências futuras (só preserva os marcadores).
- Nada foi commitado.

## PsicoManager — documentos do paciente e LGPD (20/10/2026)

### Contexto
Rodrigo autorizou a captura autenticada na **conta trial** (criada por ele; sem PII) para ver
**documentos do paciente** e **LGPD**. Foi criado um paciente sintético (“Paciente Teste MentAll”) e
**um documento de teste** (Declaração). **Nenhum documento fiscal foi emitido.** Em 20/10/2026 também
foi feita a **captura ativa**: sessão sintética às 21:00 com **LiveKit** e uma **cobrança de R$ 1,00
gerada e não paga**.

### O que mudou (arquivos)
- `docs/competidores/08_psicomanager.md`: novas §10 (documentos: 16 tipos, 13 modelos, editor, upload,
  assinatura paga, app do paciente, exportação/logs/permissões) e §11 (LGPD: Termos v1, política
  ausente, FAQ, tensões de retenção/compartilhamento); pendências renumeradas.
- `docs/competidores/07_sintese.md`: §6 documentos × LGPD (PsicoManager × MentAll).
- `docs/competidores/00_LEIA-ME.md`: objetivo e índice do `08` atualizados.
- **Nenhum código** do app/backend foi alterado.

### Verificação
- `MEDI`: `GET /api/publico/politicas` → 200 **só com `termos-de-uso`**;
  `GET /api/publico/politicas/politica-de-privacidade` → **404**; `/termos-de-uso` → 200;
  `/privacidade` e `/termos` → **404**.
- REA (CLI): `ev_6110d02c…` (modelos/LGPD), `ev_258c6ac6…` (paciente/termos), `ev_b6d48bdc…`
  (paciente sintético), `ev_71690812…` (docs do paciente), `ev_6424f1fc…` (16 tipos),
  `ev_d9f0a38d…` (13 modelos), `ev_3ce41914…` (Declaração criada), `ev_d637d171…` (FAQ LGPD).
- Captura ativa: `ev_4e0c042d…` (sala abre `/room/<uuid>`), `ev_4ae960df…` (**`POST
  api-room.psicomanager.com/livekit/token`**), `ev_81b53206…` (modal “Nova cobrança”), `ev_92048851…`
  (`gerar-cobranca` avulsa de R$ 1,00; **não paga**).
- **Achados-chave:** **LiveKit confirmado** (`POST /livekit/token`); cobrança criada por
  `/psico/financeiro/gerar-cobranca` (Asaas é server-side; Termos §5.5); Termos citam **Asaas**;
  **Política de Privacidade não publicada** (mas Termos
  §10.1 e FAQ a citam); FAQ diz “não compartilhamos com terceiros” mas a área logada carrega
  **Smooch/Zendesk + GA/Ads/Meta/HubSpot/Clarity/VWO/LTRCK/Pipz**; retenção nos Termos é condicionada
  a pagamento e exclui após 1 ano de inadimplência, enquanto a FAQ promete **5 anos** (Res. CFP
  01/2009 — conferir frente à 09/2024).

### Pendências
- **WhatsApp/IA:** provedor segue **server-side** (não observado no cliente).
- **Pagamento/sala:** cobrança de R$ 1,00 **gerada e não paga**; LiveKit confirmado pelo token.
  Faltam split/repasse/webhook, mídia real e o paciente entrando na sala.
- **Fiscal:** só UI de NFSe/Receita Saúde; sem emissão.
- **Dados sintéticos:** paciente, documento, sessão 21:00 e cobrança R$ 1,00 não paga permanecem na
  conta trial (remover manualmente).
- **APK** do app do paciente: fora do escopo (aval jurídico).

## PsicoManager + REA × RES (19/10/2026)

### Contexto
Rodrigo pediu para analisar o concorrente **PsicoManager** (`psicomanager.com.br`) e perguntou se o
**REA** fazia isso ou se o repositório **RES** (`veyralabsgroup/saas-reverse`) era o caminho. A conta
**trial** foi autorizada (dados sintéticos, captura passiva, sem APK). O RES foi clonado em `/tmp`
(sem alterar o repo) e usado só como camada de **produto**; o **REA** provou a camada **técnica**.

### O que mudou (arquivos)
- `docs/competidores/08_psicomanager.md` (**novo**): financeiro (Asaas + PsicoBank + NFSe/Receita
  Saúde + repasses), mensagens (WhatsApp/SMS/e-mail/push + app do paciente), teleconsulta (**LiveKit**
  + Google Meet + sala Neft legada), IA, stack, LGPD/trackers, 160 rotas e evidências.
- `docs/competidores/07_sintese.md`: linhas do PsicoManager nas 3 tabelas + prioridades.
- `docs/competidores/00_LEIA-ME.md`: índice `08`, versão 1.1, exceção autorizada da conta trial e o
  RES como ferramenta complementar.
- `docs/competidores/02_metodo_rea.md`: §8 **REA × RES** (o que cada um prova) + limitações medidas.
- **Nenhum código** do app/backend foi alterado nesta rodada.

### Verificação
- `rea 6.4.0` (CLI; MCP segue `enabled:false`): `analyze-web-bundle` + `capture-browser-scenario`.
  Evidências: `ev_857621a0…` (www), `ev_90cb6e18…` (inspect), `ev_d0ca109b…` (www), `ev_8e471db7…`
  (login), `ev_c1d02095…` (cadastro), `ev_8c61c76b…` (room), `ev_022138b4…` (salavirtual).
- `MEDI`: `api-live-kit.psicomanager.com` → 200 `OK`; `api-room` e `transcrition-psi` → JSON 404/400
  (NestJS). Bundles públicos: `_app` `7d1c16d6…`, `_buildManifest` `e9c80053…`, `room` `ec24c3d2…`.
- **Achados-chave:** marketing **React/Vite/Lovable + Supabase**; app **Next.js**; API **Phalcon/PHP**
  (`apip.psicomanager.com/v1/1003`); sala **LiveKit + NestJS**; transcrição **NestJS**; financeiro
  **Asaas + PsicoBank** (cartão 3,09%/3,49%, Pix/boleto R$2,59, saque R$3,00); página de cadastro
  carrega **GA/Ads/Meta/HubSpot/Clarity/VWO/LTRCK** antes do login.
- `RES` local: scraper **não renderiza SPA** e o `saas_intel` veio vazio (0 reviews/HN/Reddit) — por
  isso o valor veio do bundle + REA. Mudança só de documentação: `flutter analyze`/testes não foram
  afetados (não rodados nesta rodada).

### Pendências
- **Fase 3 (conta trial)**: captura autenticada para confirmar (a) provedor do WhatsApp (oficial ×
  não oficial), (b) modelo/provedor da IA, (c) Asaas em produção, (d) LiveKit × Neft na sala real,
  (e) se dados da área logada vão para os trackers.
- **APK do app do paciente**: fora do escopo (aval jurídico — ToS + Lei 9.609/98).
- O `AGENTS.md` já estava modificado por outra sessão antes desta; esta seção é a única alteração
  desta rodada.

## Correções de IA e privacidade — 5 edições (16/10/2026)

### Contexto
A verificação do **ambiente de produção** (e não só do código) revelou que o billing da OpenAI estava
inativo, o que fazia **toda a síntese clínica ser processada pelo DeepSeek, na China**. O billing foi
ativado no mesmo dia. Cinco correções decorreram daí.

### O que mudou (arquivos)

1. **`backend/services/ia_clinica.py` — `_MARCADORES_FALHA_DURA`**
   `billing_not_active` e `billing_hard_limit_reached` passaram a ser **falha dura**. Antes, o
   circuito abria por 180 s em vez de 1200 s e cada síntese tentava a OpenAI **duas vezes** antes de
   cair no provedor que funcionava.

2. **`backend/main.py` + `backend/models/schemas.py` — campo `provedor`**
   A síntese agora informa **qual provedor de IA processou o dado** (`resultado["provedor"] = prov`
   em `ia_clinica.py`, campo novo em `SinteseResponse`, preenchido na rota `/gerar-sintese`).
   **São três pontos:** o `response_model` do Pydantic descarta campos fora do esquema, então mexer
   só na cascata não basta — o campo simplesmente não chegaria ao app.

3. **`backend/tests/test_circuito_provedores.py` — `test_billing_inativo_e_falha_dura`**
   Trava a regressão da edição 1.

4. **`lib/services/ia_clinica_service.dart` — o nome da pessoa atendida não é mais enviado à IA**
   O campo `nome_pessoa_atendida` passou a ir **vazio**. Motivo medido: no teste de síntese de
   16/10/2026, com `Paciente: Maria S. S.` no prompt, o **DeepSeek copiou o pseudônimo para dentro do
   `relato_clinico_organizado`** — o identificador sairia do trânsito e entraria no prontuário.
   O modelo não precisa do nome: o material clínico identifica o sujeito.
   `_pseudonimizarNome` ficou sem uso (marcada com `// ignore: unused_element`, preservada para reuso).

5. **Verificação:** `dart analyze` limpo · **290 testes do app** · **290 testes do backend**, todos passando.

### Como rodar os testes do backend (importante)

`pytest` **não** está instalado no venv. Use o runner isolado, que troca o SQLite por memória:

```bash
cd backend && ./.venv/bin/python -B tests/run_isolated.py
```

Rodar `unittest discover` direto **falha com 65 erros** (`attempt to write a readonly database`),
porque os testes tentariam escrever no banco **real** em `backend/data/mentall.db`.

### Pendências
- **O WhatsApp continua quebrado em produção:** faltam `WUZAPI_BASE_URL`, `WUZAPI_TOKEN` e
  `WUZAPI_ADMIN_TOKEN` nos secrets do Fly. Nenhuma alteração de código resolve ausência de credencial.
- **`IA_MODEL_PROVIDER` ainda é `gemini`** nos secrets do Fly — valor legado que a cascata ignora,
  mas que mente para auditoria e gera alarme falso no boot.
- **A cascata ainda troca de país sozinha:** com a OpenAI saudável o DeepSeek não é acionado, mas se
  a OpenAI falhar a síntese vai para a China sem o profissional escolher.

## Checklist de publicação em PDF (16/10/2026)

### Contexto
Rodrigo pediu um **checklist completo de publicação** (Google Play + App Store + LGPD + processo),
**sem novas features**, em **PDF**. As fontes foram `tasks/lojas_app.md`, o checklist de conformidade
(`docs/lgpd/16`) e os requisitos de loja (`docs/lgpd/15`) e o plano (`docs/lgpd/02`).

**Decisão de escopo (do dono, 16/10/2026):** **não** acrescentar novas features (teleconsulta,
Pix/financeiro, mensagens automáticas etc.). O foco é **publicar o que já existe** e **melhorar o
processo**; a **LGPD é pré-requisito** inegociável. Pedidos anteriores de feature (ex.: o plano de
teleconsulta) ficam **fora** até decisão em contrário.

### O que mudou (arquivos)
- `tools/gerar_checklist_publicacao_pdf.dart` (**novo**): gera `Checklist_Publicacao_MentAll_PRO.pdf`
  na raiz. Checklist com **Parte A** (bloqueadores LGPD/loja), **B** (pendências de loja),
  **C** (processo de release), **D** (submissão Play/Apple) e **E** (pós-publicação).
- `Checklist_Publicacao_MentAll_PRO.pdf` (**novo**, ~14,5 KB).
- O guia antigo `tools/gerar_guia_publicacao_pdf.dart` (ago/2026) **não** foi alterado.
- **Correção de encoding:** travessão (`—`) e ponto médio (`·`) foram trocados por ASCII. O fonte
  Helvetica padrão do pacote `pdf` só mapeia Latin-1; caracteres fora dele (ex.: `—`) saíam como
  símbolo aleatório no PDF. Regra: nesses geradores, usar **apenas ASCII ou Latin-1**.

### Verificação
- `dart run tools/gerar_checklist_publicacao_pdf.dart` → PDF gerado (14,5 KB).
- `flutter analyze --no-pub`: **No issues found!** (o CI cobre `tools/`).

### Pendências
- Os itens das Partes A e B **continuam abertos** — são o próprio conteúdo do checklist (nada foi
  publicado). A Parte A (LGPD) é pré-requisito de qualquer envio às lojas.

## Infra REA + pesquisa de funcionalidades de concorrentes (14/10/2026)

### Contexto
Rodrigo pediu entender **como** os concorrentes implementam 3 funções — financeiro, mensagens ao
paciente e teleconsulta — para reduzir nossas desvantagens. Ferramenta escolhida: **REA**
(`morluto/rea`, MIT — engenharia reversa local via MCP/CLI), com escopo **seguro** (só fontes
públicas; sem login; sem APK/descompilação).

### O que mudou (arquivos)
- **Infra fora do repo:** **Node 22.23.3** via tarball em `~/.local` (sem Homebrew), `npm prefix`
  em `~/.local`, **`rea-agents` 6.4.0**; MCP `rea` registrado em `~/.config/opencode/opencode.jsonc`
  com **`enabled: false`** (o REA adiciona ~170 ferramentas ao contexto).
- `docs/competidores/` (**novo**): `00_LEIA-ME.md` (escopo/limites), `01_copilloto.md`,
  `02_metodo_rea.md` (instalação e como reproduzir), `03_psiluz.md`, `04_psicopront.md`,
  `05_prontuscare.md`, `06_zenklub.md` e `07_sintese.md` (3 funções × concorrentes + gaps).
- `docs/lgpd/18` e `docs/lgpd/17`: cross-reference para `docs/competidores/`.
- **Nenhum código** do app foi alterado.

### Verificação
- `rea mcp doctor` → **healthy** (170 tools, 6 prompts). `rea doctor` → `node` OK.
- Probe REA (CDP) nos **5 concorrentes web** (Copilloto, PsiLuz, PsicoPront, ProntusCare, Zenklub):
  todos são **server-side** e **não** expõem fornecedor de feature no cliente (Copilloto é
  Next.js/Turbopack). O REA confirmou a arquitetura e revelou parte da **API/rotas** (ex.: PsiLuz —
  `/auth/*` com **MFA/2FA** e **Google Calendar**). Evidence IDs em `docs/competidores/`.

### Pendências
- Fase 1 cobriu **Copilloto, PsiLuz, PsicoPront, ProntusCare e Zenklub** (web). `07_sintese.md`
  consolida os gaps do MentAll: **teleconsulta** (ausente), **Pix/fiscal**, **portal do paciente** e
  **canal oficial**.
- Confirmar os fornecedores (server-side) exigiria **HAR autenticado** ou **APK (JADX)** — ambos
  dependem de **aval jurídico** (ToS/EULA + Lei 9.609/98); fora do escopo atual.

## Comparativo de LGPD com concorrentes + calibração dos documentos (13/10/2026)

### Contexto
Rodrigo pediu, antes de executar o pacote LGPD, comparar os documentos de LGPD do MentAll com apps
brasileiros de prontuário para psicólogos. Lidos nas fontes oficiais em 13/10/2026 (LI): **PsiLuz**
(`/privacy` + `/lgpd`), **Zenklub/Conexa** (`/privacidade`), **Copilloto** (`/privacidade`),
**ProntusCare** (`/privacidade.html`) e **PsicoPront** (`/privacidade`). **Mently** e **Corpora** não
foram localizados nesta busca (não achei — não é afirmação de que não existam).

### O que mudou (arquivos)
- `docs/lgpd/18_comparativo_concorrentes.md` (**novo**, v1.0): matriz por elemento, síntese por
  concorrente, gap→item do plano, onde o MentAll já está à frente (local-first, gate de revisão,
  menores) e achados de posicionamento (2 concorrentes citam a Res. CFP 11/2018, revogada pela 9/2024;
  retenção 5×20 anos; "100% conforme" × "em adequação").
- `docs/lgpd/05_politica_de_privacidade.md` (v1.1): razão social+CNPJ, prazo de resposta **15 dias**
  + canal **ANPD**, biometria não sai do aparelho, versionamento, aviso de cookies.
- `docs/lgpd/06_termos_de_uso.md` (v1.1): nova **§12 Comunicações/opt-out** (seções 13–16 renumeradas);
  contato com CNPJ.
- `docs/lgpd/10_politica_de_retencao_e_descarte.md` (v1.1): §4.7 **benchmark de mercado** (5×20 anos;
  tratamento do áudio pelos concorrentes) — insumo de **D8**.
- `docs/lgpd/15_lojas_google_play_e_app_store.md` (v1.1): referências de mercado (subprocessadores
  nomeados, "IA sem treinamento", manter "em adequação").
- `docs/lgpd/17_registro_de_decisoes_e_revisoes.md` (v1.1): registra o comparativo; **corrige a linha
  de base** (05–14 existiam mas eram listados como "não produzidos"); benchmark de D8; calendário.
- `docs/lgpd/00_LEIA-ME.md` (v1.1): índice passa a incluir o **18**.
- **Nenhum código** foi alterado; só documentação.

### Verificação
- Páginas dos concorrentes lidas diretamente (LI). Não há teste de app/backend a rodar (mudança só de
  documentação). Links internos do pacote conferidos; `00_LEIA-ME`, `17` e `18` consistentes.

### Pendências
- Preencher placeholders (**razão social/CNPJ**, **DPO/e-mail**) — dependem do doc 13 e de decisão.
- Decisões **D1/D2/D3/D8/D9** seguem abertas; **nada** dos textos públicos pode ir à URL antes dos P0.
- Comparativo é revisado a cada novo provedor/funcionalidade e, no mínimo, **semestralmente**.

## Teste no aparelho bloqueado pela política de cleartext do Android (08/10/2026)

### Contexto
Rodrigo instalou o `MentAllPRO-v1.0.49` e, ao trocar o servidor para o backend local
(`http://192.168.x.x:8000`), o "Salvar e testar" falhou. Causa (LI):
`android/app/src/main/AndroidManifest.xml` tem `usesCleartextTraffic="false"` e
`network_security_config.xml` só permite HTTP em claro para `localhost`, `127.0.0.1`,
`192.168.0.0` e `192.168.1.0` — que **não são faixas** (Android não aceita CIDR), então
nenhum IP real da LAN casa. Firewall desligado; backend escuta `*:8000` e responde 200
pelos dois IPs do Mac (MEDI). Wuzapi local conectado.

### O que mudou (arquivos)
- Só **investigação** (sem mudança de código nesta rodada). `pubspec.yaml` bumpado para
  **`1.0.49+50`**; APK **`MentAllPRO-v1.0.49.apk`** (sha256 `9d9ef6c920f48355b2d448b2383b02f8eed692c9c9c92f90c89e3dbea6ab08e1`);
  backend local reiniciado (`/wuzapi/*` no ar — 401 sem auth).

### Verificação
- `AndroidManifest.xml` e `network_security_config.xml` lidos (LI); bind/`lsof`/`curl`
  e firewall medidos (MEDI).

### Pendências
- Testar no aparelho: decidir entre **`adb reverse tcp:8000` + servidor `http://localhost:8000`**
  (usa o APK atual, sem rebuild) ou **rebuild** com exceção de cleartext para o IP da LAN.
- No "Salvar e testar", credenciais = `APP_USERNAME`/senha do `backend/.env` local.

## WhatsApp (wuzapi) por profissional — conexão pelo app (08/10/2026)

### Contexto
Rodrigo relatou que o cadastro não apareceu no wuzapi e que os lembretes pararam após
mudar o e-mail. Diagnóstico: (a) o app **nunca teve** tela de wuzapi (endpoint `/wuzapi/config`
existia sem chamador); (b) a instância é amarrada ao `owner_id` (uuid aleatório — conta nova =
órfã) e `_resolver_token_wuzapi` é fail-closed; (c) **em produção o backend não tinha
`WUZAPI_BASE_URL`/`WUZAPI_ADMIN_TOKEN`** (MEDI: `fly secrets list`) — nada era enviado no app
apontando para o Fly. Decidido: VPS dedicada BR, `wuzapi.mentallpro.com.br`, um número por
profissional, **pareamento por código** (resolve o QR no mesmo celular) com QR de alternativa.

### O que mudou (arquivos)
- `backend/services/wuzapi_admin.py` (**novo**): provisiona instância por owner via `/admin/users`
  (`events=ReadReceipt`), status (`/session/status`), parear (`/session/connect` + `/session/pairphone`),
  `qr`, `desconectar`, `testar`. Fail-closed sem admin token/base URL.
- `backend/models/schemas.py` + `backend/main.py`: schemas e endpoints JWT `GET /wuzapi/status`,
  `POST /wuzapi/parear`, `GET /wuzapi/qr`, `POST /wuzapi/desconectar`, `POST /wuzapi/testar`.
- App: `lib/services/wuzapi_service.dart` (novo), `lib/screens/whatsapp_conexao_page.dart` (novo) e
  entrada em `lib/screens/configuracoes_page.dart` ("Agenda e lembretes").
- Testes: `backend/tests/test_wuzapi_admin.py` (12), `test/services/wuzapi_service_test.dart` (6),
  `test/screens/whatsapp_conexao_page_test.dart` (2). Planos em `tasks/plan_whatsapp_wuzapi.md`.

### Verificação
- Backend isolado: **289/289** (era 277; +12). `flutter analyze --no-pub` limpo; **290/290** Flutter.
- Contrato conferido na fonte do wuzapi: `POST /session/pairphone` devolve `data.LinkingCode`.
- APK de teste **`MentAllPRO-v1.0.49.apk`** (`1.0.48+49`→`1.0.49+50`), sha256 `9d9ef6c920f48355b2d448b2383b02f8eed692c9c9c92f90c89e3dbea6ab08e1`;
  backend local reiniciado (`/wuzapi/*` no ar — 401 sem auth). Teste no aparelho usa o backend local + `WUZAPI_ADMIN_TOKEN`.

### Pendências
- **Fase 3 (infra) não feita** — VPS ainda não contratada. Sem `WUZAPI_BASE_URL`/`WUZAPI_ADMIN_TOKEN`
  no Fly, a tela funciona mas o envio em produção segue desligado.
- O polling automático do status virou botão manual "Verificar conexão" (evita timer em teste).
- `/wuzapi/config` mantido (deprecado). Verificar pareamento/lembrete no aparelho quando houver infra.

## Indicações de artigos: descritores alinhados + crivo por metadado (07/10/2026)

### Contexto
O dono relatou que **num relato nenhuma indicação foi relevante** e no seguinte foram assertivas. Investigando com ele: os 3 artigos eram sobre um **instrumento** ("Inventário de Depressão Maior") quando a sessão era sobre **tratamento** (TCC).

### Causa raiz: a instrução do prompt
O prompt pedia, literalmente: *expressão de busca específica **(4 a 6 palavras) combinando** o problema clínico central **com contexto, população ou intervenção***, e dava o exemplo empilhado *"terapia cognitiva ansiedade social adultos"*. **A base faz "E" entre as palavras**, então 3+ conceitos retornam ZERO — e aí o código caía no termo amplo de 2 palavras, que casa com homônimos.

Medições (OpenAlex, PT, psicologia, 07/10/2026):
- `terapia cognitivo-comportamental depressão maior remissão parcial` → **0**
- `terapia cognitivo-comportamental depressão maior` → **21, todos pertinentes**
- `depressão maior` (o fallback) → **975**, os 3 primeiros são o **inventário**

### Outras medições que moldaram o desenho
- **`OU` (`|`) existe, mas `(D1 E D2) OU D3` faz o genérico dominar:** 2.285 resultados ≈ 2.265 (só "idoso"). Parênteses são **ignorados**; a palavra `or` **não** é operador (vira termo de busca); repetir a chave de filtro faz **E**, não OU.
- **A sigla "TCC" é homônimo:** 644 resultados, o primeiro sobre *serious games* — na literatura brasileira "TCC" é majoritariamente *Trabalho de Conclusão de Curso*. `terapia cognitivo-comportamental` traz 850 corretos.
- **O crivo negativo (detectar instrumento) falhava:** marcava como "instrumento" o **único artigo bom** (via `topics` largos). O crivo **positivo** (exigir sinal de tratamento, só nas `keywords`) manteve 10/10 nos controles.

### O que mudou (arquivos)
- `backend/services/ia_clinica.py`:
  - **prompt**: 3 descritores de **UM conceito** — (1) a abordagem clínica por extenso (nunca a sigla), (2) o tema central, (3) o contexto da pessoa atendida **só se discriminante** ("idoso", "viúva"; **não** "adulto");
  - **`_normalizar_temas`**: devolve descritores (não mais pares específico/amplo), teto de 3, com `_EXPANSOES_SIGLAS` (tcc/act/dbt);
  - **`_montar_artigos`**: busca por **pares** (`D1+D2`, `D1+D3`, `D2+D3`), pontua por quantos pares cada artigo casa, e **corta em 3**;
  - **crivo `_tem_sinal_tratamento`**: usa as `keywords` **atribuídas pela base** (já vinham no payload e eram descartadas) e, sem elas, as palavras do resumo. Marcas configuráveis por `IA_ARTIGOS_SINAL_TRATAMENTO`;
  - **sem candidato aprovado → buscas sugeridas** (links), em vez de artigo fora do tema (decisão do dono);
  - **removida `_buscar_candidatos_tema`**: ela fazia **união** de específico+amplo, então o termo amplo poluía a lista mesmo quando o específico funcionava.
- `backend/tests/test_artigos_relevancia.py` (novo, 12 testes) e `TestNormalizarTemas` atualizado (codificava o contrato anterior).

### Verificação
- Backend isolado: **277/277** (era 265; +12). `flutter analyze` limpo; **282/282** Flutter.
- **Cadeia real, material real:** antes → 3 artigos de instrumento; depois → *"TCC da depressão: relato de caso"* e *"Psicoeducação na TCC: um caso de depressão"*. A busca caiu de ~6s para **1,1s** (1 consulta em vez de 4).

### Pendências
- **O crivo é heurístico** (lista de palavras): pode cortar artigo bom em tema não testado (luto, dependência química, violência doméstica). Amostra medida: 3 consultas.
- **Passa coisa estranha:** *"Trimetilaminúria e TCC"* (doença metabólica rara) sobreviveu por ter "TCC"/"intervenção" nas keywords.
- **O contexto só hierarquiza se for discriminante** — "adulto" (3.895 resultados) não discrimina; o prompt já foi ajustado para não emiti-lo.
- **A idade existe no app** (`paciente.dart`: `dataNascimento`/`idade`) mas **não é enviada** ao backend; hoje o extrator a lê do próprio relato.

## Circuito aberto nos provedores de IA (07/10/2026)

### Contexto
A cascata tinha ordem fixa mas **memória nenhuma**: em 07/10/2026 tentava o Gemini a cada síntese e
pagava o 503 outra vez. Com o Gemini fora, o mesmo valeria para a OpenAI — se a cota acabasse, **toda**
síntese pagaria o tempo da falha dela antes de chegar ao DeepSeek.

### O que mudou (arquivos)
- `backend/services/ia_clinica.py`: circuito por provedor, em memória do processo.
  - **falha dura** (cota, chave, modelo inexistente, permissão) abre o circuito por **20 min** já na
    primeira falha;
  - **falha transitória** (503, timeout) abre após **2 falhas seguidas**, por **3 min**;
  - um **sucesso limpa** o estado;
  - se **todos** estiverem abertos, faz-se **uma** tentativa no primeiro da ordem — estado velho não
    pode bloquear tudo.
- **Síntese e progresso** usam o circuito (ambos passam por `_provedores_a_tentar()`).
- `backend/tests/test_circuito_provedores.py` (novo, 11 testes).

### Verificação
- Backend isolado: **265/265** (era 254; +11). `flutter analyze` limpo; **282/282** Flutter.

### Pendências
- O estado é **por processo**: correto com uma máquina só (o caso hoje). Com mais instâncias, cada uma
  teria o seu circuito — aí precisaria de estado compartilhado.
- O circuito **não distingue "cota acabou" de "chave trocada"**: as duas abrem por 20 min. Se a chave
  for corrigida, o provedor só volta depois da janela (ou num restart).

## Provedores de IA: Gemini fora, OpenAI primeiro (07/10/2026)

### Contexto
A síntese levava **52s** em produção. Medi os logs e a causa **não era o modelo**: a cascata
tentava, em ordem fixa, provedores que estavam fora — **19s** no Gemini (503), **9s** na OpenAI
(429 "no credits"), e só então **24s** no DeepSeek, que funcionava.

Investigando o 503 do Gemini (pedido do dono), a causa ficou clara por medição:
- **não era a chave** (válida, 62 modelos listados), **nem o nome do modelo** (o `gemini-3.7-flash`
  está listado, com `generateContent`), **nem a rede** (falha igual daqui e do Fly);
- a **família Flash inteira devolvia 503**; o `3.8-flash` estourou timeout de 25s; os modelos
  **Pro devolviam 429** (fora do plano);
- o único que respondia, `gemini-3.1-flash-lite`, **falhou 1 de 2 vezes** e entregou o **menor
  conteúdo** (aderência 44,9% contra 62,4% do `gpt-4.1` e 84,3% do DeepSeek) — descartado;
- dois modelos **aposentados** (`gemini-2.5-flash`, `gemini-2.5-flash-lite`) ainda aparecem na
  lista e devolvem **404**. **"Estar na lista" não significa "funciona".**

**Achado grave no caminho:** o `/gerar-progresso` **não tinha cascata** — usava um provedor só, que
em produção era o Gemini. Resultado medido em produção: **32s e falha**, devolvendo HTTP 200 com
`sucesso:false`. A evolução clínica estava **morta**.

### O que mudou (arquivos)
- `backend/services/ia_clinica.py`: nova `_ordem_providers()` — padrão **`openai,deepseek`**,
  configurável por `IA_PROVIDER_ORDER`, com **nomes desconhecidos descartados** (assim o Gemini não
  volta por engano ao mexer no secret). A **síntese** passou a usá-la e o **progresso** ganhou a
  reserva que não tinha (percorre a mesma ordem, parando no primeiro que responder).
- `backend/tests/test_ordem_providers.py` (novo, 8 testes), incluindo a regressão "alguém põe
  `gemini,openai` no secret".
- **Secrets do Fly:** `IA_MODEL` = **`gpt-4.1`**. Uma tentativa de trocar para `gpt-4o-mini`
  **quebrou** (403 `model_not_found`: a conta só tem 3 modelos) e foi revertida. **`IA_MODEL` é
  obrigatório** — o default do código (`gpt-4o-mini`) não existe nesta conta, então remover o
  secret quebra a OpenAI.

### Verificação
- Backend isolado: **254/254** (era 246; +8). `flutter analyze` limpo; **282/282** Flutter.
- Medição (mesmo material clínico real, 2 rodadas cada): **`gpt-4.1` 11,9s** / aderência 62,4% ·
  **DeepSeek 27,3s** / 84,3% · `gemini-lite` 16,3s / 44,9% com 1 falha. O `invent%` empatou (~66%):
  nenhum provedor inventa mais que os outros — a diferença é **quanto do material capturam**.

### Pendências
- **O DeepSeek registra mais do que foi dito** (escores PHQ-9/GAD-7, distorções nomeadas, hipótese
  diagnóstica) contra a velocidade do `gpt-4.1`. Sem **streaming**, a escolha é entre 12s enxuto e
  27s fiel; com streaming, dá para ter o fiel.
- `IA_MODEL_PROVIDER=gemini` continua nos secrets e agora é **inerte**: `_get_provider()` só é
  alcançável por um `_get_model_name()` **sem argumento**, e as 5 chamadas passam o provedor
  explicitamente. A seleção depende **só** de `IA_PROVIDER_ORDER`. Vale remover o secret.
- A cascata **deixou de insistir** em quem acabou de falhar — o circuito aberto veio no commit
  seguinte (`8308fc8`), na seção "Circuito aberto nos provedores de IA".

## Release (06/10/2026) — APK 1.0.48+49

### Contexto
- Rodrigo pediu para gerar o APK. A árvore estava limpa e o último APK (`1.0.47`, sha `9b2e1123...`)
  era anterior aos commits do gate de revisão. Decisão do dono: **bump** para não sobrescrever o 1.0.47.

### O que mudou (arquivos)
- `pubspec.yaml`: `1.0.47+48` → **`1.0.48+49`**.
- `MentAllPRO-v1.0.48.apk` (~79,4 MB), sha256 `7346cea700b9c8ed7373e1f508ed223ab30e794268112fdfe140c477c44aca21`.

### Verificação (checklist de fumaça)
- `flutter analyze --no-pub`: **No issues found!**
- `flutter test --no-pub`: **282/282**.
- `flutter build apk --release`: OK (~50s; aviso KGP de `package_info_plus`/`sentry_flutter`/`share_plus`/`wakelock_plus`, já conhecido).

### Pendências
- Verificar no aparelho o gate de revisão (marcar/desmarcar revisão, alterar transcrição) — só código de app, sem deploy de backend.
- Bump não commitado (pubspec) — aguardando confirmação para commit de release.

## Buraco do gate de revisão fechado (06/10/2026) — A ORIGEM NÃO SE APAGA

### Contexto
O gate de revisão exigia `geradoComIa && !revisado`. Havia um caminho que o contornava:
`_invalidarIaERevisaoPorAlteracaoDaTranscricao()` (`sessao_form_page.dart:440`) zerava `_geradoComIa`
**preservando os campos clínicos que a IA tinha preenchido**. Depois de alterar a transcrição, o texto
de origem IA ficava no formulário marcado como se não fosse de IA — e podia ser salvo sem revisão.

### O que mudou (arquivos)
- `lib/screens/sessao_form_page.dart`: a invalidação **não zera mais `_geradoComIa`**. O que se
  invalida é a **revisão** (o material de origem mudou, então o conteúdo precisa ser reconferido); a
  origem da IA permanece enquanto o texto dela estiver nos campos. A mensagem ao profissional passou a
  dizer a verdade: os campos foram preservados **mas precisam ser conferidos**, e ele deve marcar a
  revisão de novo (ou gerar nova síntese).
- `test/widgets/sessao_form_page_test.dart` (+1): alterar a transcrição de uma sessão de IA já revisada
  faz o botão "Marcar como revisado" **voltar a aparecer**, com o conteúdo preservado — provando que a
  origem sobreviveu. O bloqueio do salvamento já era provado pelo teste vizinho.

### Por que não limpar os campos
Limpar o conteúdo na invalidação era a alternativa e foi **descartada**: os campos podem conter texto
que o profissional **editou à mão**, e apagá-lo perderia trabalho. Preservar os campos e manter o gate
não perde dado nem abre exceção.

### Verificação
- `flutter analyze --no-pub`: limpo. `flutter test --no-pub`: **282/282** (era 281). Backend isolado:
  **246/246**.
- Nota de teste: a primeira versão falhava porque o SnackBar da invalidação cobria o botão de salvar e
  o `tap()` não acertava — e o texto no hit test era o novo aviso, o que já provava que a invalidação
  disparava com o comportamento novo. O teste foi simplificado para verificar a propriedade central
  (origem preservada) sem depender do toque.

### Pendências
- O gate segue **por sessão**: se o profissional substituir manualmente todo o texto da IA,
  `geradoComIa` permanece `true` e ele precisará marcar a revisão mesmo para o próprio texto. É
  fail-closed e aceitável.

## Gate de revisão humana implementado (06/10/2026) — A GARANTIA PASSOU A SER DO SOFTWARE

### Contexto
A auditoria da documentação provou que o `AGENTS.md` afirmava **"Revisão: Obrigatória pelo
profissional"** sem que nada a impusesse: `_salvarSessao()` validava apenas `sessaoSalvandoProvider` e
`_existeAcaoEmAndamento`. A flag `revisadoPeloProfissional` era informativa, e conteúdo gerado por IA
podia ser gravado no prontuário sem revisão marcada.

### O que mudou (arquivos)
- `lib/utils/sessao_form_helpers.dart`: nova `precisaRevisarAntesDeSalvar({geradoComIa,
  revisadoPeloProfissional})` — regra nomeada, pura e testável: bloqueia quando
  `geradoComIa && !revisadoPeloProfissional`.
- `lib/screens/sessao_form_page.dart`: `_salvarSessao()` chama a regra **antes de qualquer efeito**
  (antes de parar áudio ou marcar `sessaoSalvandoProvider`) e, se bloqueado, orienta o profissional a
  usar "Marcar como revisado".
- `test/services/revisao_gate_test.dart` (novo, 4 testes) e um teste de widget que verifica o bloqueio
  **de ponta a ponta** (`test/widgets/sessao_form_page_test.dart`): o aviso aparece **e nada é gravado**
  no Hive.

### Por que bloquear em vez de só avisar
Um aviso permitiria gravar conteúdo de IA não revisado com um clique de confirmação — e a afirmação
"revisão obrigatória" continuaria falsa. Bloquear é fail-closed, no mesmo espírito do
`EncryptedServiceMixin.encrypt`. **Sessões sem IA não são afetadas** (`geradoComIa == false`) e o botão
de revisão aparece exatamente na condição que o gate exige — não há beco sem saída.

### Verificação
- `flutter analyze --no-pub`: limpo. `flutter test --no-pub`: **281/281** (era 276). Backend isolado:
  **246/246**.
- O gate **quebrou um teste existente** (`Persistencia de artigos sugeridos`), cuja fixture salvava uma
  sessão de IA nunca revisada — estado que o gate agora impede. A fixture passou a refletir um estado
  alcançável (revisada) e o cenário bloqueado virou teste próprio.

### Pendência conhecida (buraco residual do gate)
`_invalidarIaERevisaoPorAlteracaoDaTranscricao()` (`sessao_form_page.dart:441`) zera `geradoComIa`
**preservando os campos clínicos que a IA preencheu**. Nesse caminho, texto de origem IA pode ser salvo
com `geradoComIa=false` e sem revisão, **contornando o gate**. É decisão de produto: ou esses campos
são limpos na invalidação, ou o gate passa a olhar outra marcação.

## Auditoria da documentação contra o código (06/10/2026) — O DOC MENTIA SOBRE A REVISÃO

### Contexto
Pergunta do dono: "o AGENTS.md está atualizado?". Foram auditadas as seções **sem data** (as que
descrevem o estado atual, não o histórico), em quatro frentes independentes, cada afirmação conferida
contra o código com `arquivo:linha`. **Resultado: mais de 40 afirmações desatualizadas ou falsas** —
três delas sobre segurança e uma sobre conformidade.

### O achado crítico (DECISÃO DE PRODUTO PENDENTE)
O arquivo afirmava **"Revisão: Obrigatória pelo profissional"**. **Não é.**
`_salvarSessao()` (`sessao_form_page.dart:1373`) valida apenas `sessaoSalvandoProvider` e
`_existeAcaoEmAndamento`; a flag `revisadoPeloProfissional` é gravada como campo comum (`:1490`) e o
único efeito é o rótulo "Revisão pendente". **Conteúdo gerado por IA pode ser salvo no prontuário sem
revisão marcada.** Enquanto o gate não existir, a revisão humana é garantia de **processo**, não de
**software** — e é ela que sustenta a narrativa de apoio documental (LGPD/CFP).

### Correções aplicadas (somente documentação)
- **Segurança**: JWT é **PyJWT** (não python-jose); a senha vem de `APP_PASSWORD_HASH` (não existe
  `admin`/`admin`); a chave mestra é **aleatória** (PBKDF2 só no caminho legado, 10k iterações, e
  `kdf_version` não tem escritor); o áudio usa envelope binário `[MAV1][nonce][cifra]`; PDFs: 6 opções
  no diálogo e 7 geradores; o microtexto dos 5 minutos **não está na tela**.
- **Infra**: a seção apontava para o **Render** (plataforma abandonada) — app e deploy estão no
  **Fly.io**. `render.yaml` marcado como legado.
- **Stack**: "Riverpod 100%, 0 `setState`" -> há ~55 `setState` em 10 arquivos.
- **Cores**: a tabela descrevia a paleta de **PDF/HTML** como se fosse o tema. O app usa
  `ColorScheme.fromSeed(#8806CE)` (M3) e as cores de UI são derivadas dele.
- **Estrutura**: contagens (providers 12->42, StateProviders 21->20, campos Hive 12/10/31/9 ->
  16/13/35/10, linhas dos arquivos), arquivo deletado (`agenda_inline_widget.dart`), `lib/utils/`
  ausente (agora **gerado de `ls lib/utils`**) e indentação da árvore de widgets.
- **Memória do Acordo**: o PDF de referência **não existe** no repositório; o título é `#3C096C` e a
  logo `#C77DFF` (não "azul").
- **`tasks/lojas_app.md`**: as **4 pendências que ele chamava de bloqueadoras de publicação estão
  resolvidas** (fail-closed, CSP, `TRUSTED_PROXIES`, `--proxy-headers`); o cabeçalho dizia `1.0.28+29`.
  **`tasks/todo.md`**: Fases 2 e 3 inteiras marcadas como pendentes e já implementadas.
- **CORS**: removida a origem `mentall-api.onrender.com` do `main.py` (subdomínio de terceiro,
  tratado como confiável com `allow_credentials`).

### Achados de código que NÃO foram corrigidos (precisam de decisão)
- ~~**Gate de revisão**~~ — **implementado no mesmo dia** (ver a seção mais recente no topo).
- `migrarParaGcm` / `migrarCamposLegados` **sem nenhum chamador**: o formato legado `2:` é lido mas
  nunca migrado. Ligar isso reescreve todos os campos cifrados — exatamente o tipo de operação do
  incidente de 16/07. Decisão do dono.
- `excluirPaciente` (hard delete em cascata) **sem chamador de produção** — dead code destrutivo.
- `StatusProcessamentoCard` é **dead code**.
- Não existe evento de auditoria para **remoção/regravação de áudio**, exigido pela especificação do
  PDF de arquitetura LGPD.

### Verificação
- Nenhum arquivo de código alterado nesta rodada além do CORS (commit `4f9fbb5`). `flutter analyze`
  limpo, **276/276** Flutter, **246/246** backend.
- Método: quatro auditorias independentes com evidência `arquivo:linha`; as afirmações de maior
  consequência foram conferidas pelo próprio agente antes de virarem texto — a da revisão, inclusive,
  foi lida linha por linha.

## Expurgo do log em claro e A1 nas indicações de artigos (06/10/2026)

### Contexto
Duas pendências da auditoria de degradação silenciosa, autorizadas juntas:
- **Log legado**: a correção M3 impede gravação **nova** de PII em texto puro, mas não apaga o que as
  versões anteriores já gravaram em disco (box e `mentall_tecnicos.log`) — texto que pode conter nome
  e telefone de paciente.
- **A1**: quando a busca de artigos falhava (retorno `null`), o campo já havia sido limpo antes da
  busca, nada avisava o profissional e o app **persistia `artigosSugeridos = ''`**, apagando as
  indicações salvas na sessão. O card simplesmente desaparecia.

### O que mudou (arquivos)
- `lib/services/logger.dart`: novo `purgarHistoricoLegado()`, com flag `purge_log_claro_v1` gravada no
  próprio box. **Preserva as linhas que já estavam cifradas** (começam com `3:`/`2:`) e descarta o
  texto puro — no box e no arquivo —, e só age **uma vez**, para não apagar diagnóstico novo.
- `lib/main.dart`: expurgo chamado no boot logo após as migrações. O box de logs já está aberto e o
  expurgo **não depende da chave de cifra**.
- `lib/utils/sessao_form_helpers.dart`: novo `resolverBuscaArtigos` (lógica pura e testável).
  `null` = falha -> mantém as indicações anteriores; string vazia = sucesso sem resultados -> limpa,
  porque as antigas eram de outra síntese.
- `lib/screens/sessao_form_page.dart`: guarda o valor anterior, passa pela busca via o resolver e
  **avisa o profissional** quando a busca falha, informando se as indicações anteriores foram mantidas.
- Testes: `artigos_busca_resolver_test.dart` (novo, 5) e `logger_pii_test.dart` (+2: o expurgo e a
  preservação das linhas cifradas).

### Verificação
- `flutter analyze --no-pub`: limpo. `flutter test --no-pub`: **276/276**. Backend isolado:
  **246/246**.

### Pendências
- O backend ainda devolve `sucesso: true` com o texto "Busca sugerida" quando o OpenAlex falha: o app
  **não distingue** isso de "as bases não tinham artigos". O rótulo é honesto (links reais de busca) e
  o fallback é útil — falta sinalizar a falha na resposta, o que é decisão de produto.
- O expurgo roda **uma vez por instalação**: quem não atualizar o app permanece com o histórico em
  claro no aparelho.

## Log técnico deixa de gravar PII em texto puro (06/10/2026) — FAIL-CLOSED TAMBÉM NO LOG

### Contexto
Achado M3 da auditoria de degradação silenciosa. O log técnico tinha **dois caminhos de vazamento**:
- **box** (`_persistir`): se o serviço de cifra fosse nulo ou não estivesse configurado — a janela do
  boot, antes do desbloqueio — ou se `criptografar` lançasse, a linha permanecia em **texto puro** e
  era gravada no Hive;
- **arquivo** (`_persistirArquivo`): mesma lógica, gravando **texto puro em disco** em
  `mentall_tecnicos.log`.

As linhas podem conter `response.body` (`anamnese_enviada_service.dart:112`,
`api_client.dart:227`) — ou seja, **nome e telefone do paciente**. O comentário do próprio código
afirmava "sem nunca logar PII em claro", o que não se cumpria.

### O que mudou (arquivos)
- `lib/services/logger.dart`: a linha só é persistida **cifrada**; sem cifra disponível grava-se
  apenas o rótulo (nível e contexto) via novo `_redigir`, com o marcador
  `(conteudo nao registrado: cifra indisponivel)`. `_persistirArquivo` deixou de cifrar por conta
  própria — recebe a linha já protegida, então não resta caminho que escreva texto puro. Passa a valer
  a mesma regra fail-closed do `EncryptedServiceMixin.encrypt`.
- `test/services/logger_pii_test.dart` (novo, 3 testes): comprova que o conteúdo **não** aparece no
  box sem cifra, que com cifra a linha continua legível, e que `info`/`auditoria` seguem a regra.

### Verificação
- `flutter analyze --no-pub`: limpo. `flutter test --no-pub`: **269/269** (era 266). Backend isolado:
  **246/246** (inalterado).
- Commit anterior publicado: CI run `37530943493` verde (4/4 jobs), deploy 1m0s, `/health` 200.

### Pendências
- **O histórico já gravado em claro por versões anteriores permanece em disco** até o usuário limpar
  os logs: não há migração nem expurgo automático. A correção impede vazamento **novo**, não apaga o
  antigo.
- Quando a cifra está indisponível, o conteúdo deixa de ser recuperável para diagnóstico — é o custo
  deliberado de não vazar PII. O rótulo (quando, onde, de que tipo) é preservado.
- `obterLogs()` devolve o conteúdo cru do box, misturando linhas cifradas e redigidas; quem exibe o
  log precisa decifrar. Não foi alterado aqui.

## Guarda contra dupla criptografia (06/10/2026) — A LEITURA QUE FALHA NÃO PODE DESTRUIR O DADO

### Contexto
Achado M2 da auditoria de degradação silenciosa. Cadeia do incidente:
1. a chave está indisponível (boot, antes do desbloqueio) ou a decifragem falha;
2. `descriptografar` devolve o **próprio criptograma** como se fosse conteúdo (fail-open da leitura,
   intencional: lançar quebraria o boot);
3. o app exibe o criptograma no campo clínico;
4. o profissional salva -> `criptografar` envolve o criptograma em uma **segunda camada**;
5. o conteúdo original passa a exigir duas decifragens: **o prontuário fica ilegível para sempre**.

Não é hipótese: o projeto **já viveu esse incidente em 16/07/2026**, citado no comentário de
`sessao_service.dart:264`. A mitigação existente cobria só o caminho de cifra parcial na
retentativa, não o campo cifrado voltando pela leitura.

### O que mudou (arquivos)
- `lib/services/encryption_service.dart`: novo `estaCifrado(String)` (formatos `3:` GCM e `2:` CBC,
  com piso de 40 caracteres para não confundir texto clínico com criptograma) e guarda em
  `criptografar` — o **funil único** de cifra do app. Valor já cifrado é devolvido intacto em vez de
  re-cifrado, com o ocorrido registrado no log.
- `test/services/encrypted_service_mixin_test.dart` (+3 testes): reconhecimento do formato, não
  re-cifragem, e o **caminho do incidente de ponta a ponta** (leitura sem chave -> salvamento)
  provando que o dado continua legível.

### Por que a correção mudou em relação ao plano inicial
O plano era fazer a tela mostrar "não foi possível ler este registro" no lugar do criptograma.
Lendo o código, isso **criaria uma perda nova**: com o campo exibido vazio, salvar gravaria vazio e o
criptograma original seria perdido de fato. Exibir o criptograma é feio, mas **preserva o dado** — e
com a guarda em `criptografar` ele é gravado de volta sem alteração. A camada certa para a proteção é
o funil da cifra, não a tela.

### Verificação
- `flutter analyze --no-pub`: limpo. `flutter test --no-pub`: **266/266** (era 263). Backend isolado:
  **246/246** (inalterado).

### Pendências
- O campo ilegível continua sendo **exibido** como criptograma. Melhorar isso exige um aviso que
  **preserve o valor original** (nunca deixar o campo vazio) — é desenho de UI, não só código.
- `descriptografar` segue fail-open na leitura (intencional, pelo boot) e `criptografar` segue
  fail-open quando `_key == null` (linha 484): o fail-closed de escrita está no
  `EncryptedServiceMixin.encrypt`, que lança antes de chegar aqui. Vale revisar chamadas diretas a
  `criptografar` que não passam pelo mixin.

## Auditoria de degradação silenciosa e primeiras correções (06/10/2026) — O ERRO QUE VIRA SUCESSO

### Contexto
Auditoria dedicada à classe de falha que causou o bug do rerank: **erro engolido -> resultado
degradado devolvido como sucesso -> persistido no prontuário, sem aviso**. Foram varridos os 76
`except` do backend e os 163 `catch` do app, seguindo a cadeia até a persistência.
Achados de gravidade alta corrigidos aqui; o restante está em Pendências.

### O que mudou (arquivos)
- `backend/services/ia_clinica.py`: `_parse_resultado_sucesso` agora **exige conteúdo clínico**.
  Resposta JSON válida porém fora do schema (`{}`, `{"erro": ...}`, recusa do modelo) devolve
  `sucesso: False` — antes devolvia **sucesso com os 6 campos vazios**, a cascata de provedores
  parava no primeiro e o app gravava prontuário em branco. Campos agora passam por `.strip()`.
- `lib/screens/sessao_form_page.dart`: `_preencherController` **não sobrescreve campo preenchido com
  vazio** ("a IA preenche, nunca apaga"). O helper só era usado nesse fluxo.
- `lib/services/perfil_profissional_service.dart`: `salvarPerfil` copiava campo por campo e **não
  copiava `crpVerificado`/`crpDataVerificacao`**, então o `true` da verificação do CFP era descartado
  na gravação. Como `atualizarPerfil` **não tem nenhum chamador**, o selo "Verificado" só existia em
  modo demo — e `crp_verificado: false` era enviado no contrato do paciente e na anamnese, e omitido
  no PDF, para todo profissional.
- `backend/tests/test_sintese_schema.py` (novo, 9 testes); `test_artigos_filtros.py` (+2 testes do
  caminho de exceção de rede, lacuna apontada pela própria auditoria).

### Verificação
- `flutter analyze --no-pub`: limpo. `flutter test --no-pub`: **263/263**. Backend isolado:
  **246/246** (era 235).

### Pendências (achadas na auditoria, NÃO corrigidas)
- **Banco**: Turso fora -> SQLite efêmero com escrita confirmada como sucesso (2.866 linhas de
  fallback nos logs reais), e `/health` responde sempre `status:"ok"`. `ALLOW_SQLITE_FALLBACK` tem
  default `"true"` no repositório; não é possível conferir os secrets do Fly daqui.
- **Artigos**: falha de rede ainda chega ao app como `sucesso: true` com "Busca sugerida" (o rótulo é
  honesto), o app **não avisa**, e `_artigosSugeridos = ''` antes da busca **apaga os artigos já
  salvos na sessão** quando a busca falha.
- **Anamnese**: `status='respondido'` com `respostas_json` vazio é gravado (gatilho no backend).
- **Cripto**: `descriptografar` devolve o criptograma como conteúdo; salvar re-cifra e corrompe o dado
  de forma permanente. Log técnico é gravado em **texto puro** (box e `mentall_tecnicos.log`) quando
  a cifra falha ou não está configurada — pode conter nome/telefone do paciente.
- **Migração**: o marcador de schema avança mesmo com registros não migrados.
- **Bloqueio por inatividade**: desbloqueia sem prompt e sem o aviso de fail-safe, que só existe na
  tela de login.
- **Auditoria LGPD**: `_registrarAuditoria` não é `await`ado — a falha vira Future não tratado e o
  evento pode nunca ser gravado.
- **wuzapi/lembretes**: webhook inválido responde 200 e o recibo se perde; falha de banco vira
  "wuzapi não conectado"; lembrete pode ser duplicado ou marcado como falha por erro de leitura.
- **Recuperação de senha/PIN**: `except: pass` deixa o bloqueio por tentativas **fail-open**.
- `lib/services/progresso_service.dart:51-58`: `..take(limite)` em cascata não tem efeito (bug
  funcional, não é degradação silenciosa).

## Qualidade das indicações de artigos (06/10/2026) — PERIÓDICO PRIMEIRO + LIMPEZA

### Contexto
- Duas pendências da seção anterior: (a) os resultados vinham muito de **repositórios e
  agregadores** (LA Referencia, Dialnet, Zenodo) em vez de periódicos; (b) `_reconstruir_resumo_openalex`
  seguia calculando o `resumo` dos candidatos, que ficou **sem leitor** após a remoção do rerank.
- O filtro de periódico foi **medido antes de implementar**, na configuração real do app.

### O que mudou (arquivos)
- `backend/services/ia_clinica.py`: novo `OPENALEX_FILTRO_PERIODICO`
  (`primary_location.source.type:journal`). A busca passa a ter **cascata de 3 filtros**:
  periódico + psicologia → psicologia → qualquer área. `_reconstruir_resumo_openalex` e o campo
  `resumo` dos candidatos foram removidos.
- `backend/tests/test_artigos_filtros.py` (novo, 5 testes): verifica a **ordem da cascata** e a
  degradação (se um filtro zera, cai para o próximo em vez de não devolver nada).

### Verificação
- Medição, mesma consulta e mesma configuração: `ruminação` 52→36;
  `transtorno de ansiedade generalizada mindfulness` 11→7; `episódio depressivo maior` 24→20.
  **Nenhuma consulta zerou**, e o topo passou a ser periódico — no lugar do repositório
  LA Referencia, agora vem *Temas em Saúde* (artigo sobre risco de suicídio em EDM).
- `flutter analyze --no-pub`: limpo. `flutter test --no-pub`: **263/263**. Backend isolado:
  **235/235** (era 230; +5 do teste novo).
- Lote anterior publicado no mesmo dia: CI run `37527021295` verde (4/4 jobs), deploy 54s,
  `/health` 200 e `/gerar-progresso` sem auth → 401.

### Pendências
- A cascata de provedores de IA continua **só na síntese**; os helpers JSON retentam, mas não trocam
  de provedor se a indisponibilidade for longa.
- `log.info("Solicitacao de artigos - temas=%d")` segue sendo a única janela para saber quais
  palavras o extrator produz.
- `/gerar-artigos` pode virar **100% local** (só palavras-chave saem do aparelho).

## Retry para indisponibilidade transitória da IA (06/10/2026) — O 503 DEIXA DE SER SILENCIOSO

### Contexto
- Um **503 do Gemini** ("high demand, usually temporary") derrubava a busca de artigos **sem nenhuma
  retentativa**, e o log rotulava tudo como "Gemini JSON error" — inclusive 503, timeout e falha de
  rede. Foi esse rótulo que atrasou o diagnóstico.
- A síntese **já tinha** cascata de provedores (`gerar_sintese_clinica`), e por isso resistia. Os
  helpers JSON (`_chamar_llm_json_*`), que servem progresso e artigos, não tinham retry nem cascata.

### O que mudou (arquivos)
- `backend/services/ia_clinica.py`: novos `_erro_transitorio` (classifica 408/429/5xx/timeout/rede
  como retentável; erro de formato e de autenticação, não) e `_executar_com_retry` (até 3 tentativas,
  backoff de 2s e 4s via `time.sleep` — seguro porque os callers rodam em `run_in_executor`). Os três
  `_chamar_llm_json_*` passaram a usá-lo e trocaram o rótulo único por três mensagens distintas
  (tentativa / indisponível após N / falha não transitória). O contrato de retorno foi preservado.
- `backend/tests/test_llm_retry.py` (novo, 10 testes): classificação de erro e comportamento do retry
  (retenta e vence, desiste no máximo, não retenta erro não transitório, `time.sleep` mockado).

### Verificação
- `flutter analyze --no-pub`: limpo. `flutter test --no-pub`: **263/263**. Backend isolado:
  **230/230** (era 220; +10 do teste novo).
- Efeito: um 503 isolado passa a ser absorvido por retentativa em vez de degradar a saída.

### Pendências
- A cascata de provedores continua **só na síntese**. Os helpers JSON retentam, mas não trocam de
  provedor se a indisponibilidade for longa — considerar alinhar ao padrão da síntese.
- `_reconstruir_resumo_openalex` segue calculando o `resumo` dos candidatos, que ficou sem leitor
  após a remoção do rerank (2 linhas para remover).

## Remoção do rerank por IA nas indicações de artigos (06/10/2026) — MENOS DADO, MENOS FALHA

### Contexto
- A linha "Relevância:" nunca chegava à tela. A causa era falha **silenciosa**: o Gemini devolvia
  **503 (capacidade)**, `_chamar_llm_json_gemini` capturava tudo sob o rótulo enganoso "Gemini JSON
  error", `_rerankear_artigos` degradava para os candidatos sem justificativa, o backend respondia
  **200 com sucesso** e o app **persistia** o resultado degradado na sessão.
- O dono confirmou que a justificativa **não tem valor** para o profissional: ele quer os artigos
  pertinentes, não o caminho percorrido. E a recuperação por palavra-chave sozinha entrega
  **3 de 3 artigos relevantes** — o rerank não sustentava nada.

### O que mudou (arquivos)
- `backend/services/ia_clinica.py`: `_rerankear_artigos` removida (~68 linhas); `_montar_artigos` e
  `gerar_artigos` perdem o parâmetro `contexto_clinico`; `_formatar_artigos` não emite mais a linha
  `Relevância:`.
- `backend/models/schemas.py` e `backend/main.py`: campo e argumento `contexto_clinico` removidos.
- `lib/services/ia_clinica_service.dart` e `lib/screens/sessao_form_page.dart`: o app deixa de montar
  e enviar relato+síntese como contexto.
- `backend/tests/test_prompt_injection.py`: removido `test_contexto_clinico_sanitizado_no_rerank`
  (existia porque texto clínico cru era injetado num prompt — sem contexto, sem injeção).
- `backend/tests/test_artigos.py`: removida a asserção da linha `Relevância:`.
- **Mantido:** `_sanitizar_prompt` / `INJECAO_PADROES` / `MAX_PROMPT_CHARS` (usados em ~15 pontos da
  síntese e do progresso) e toda a recuperação por palavra-chave no OpenAlex.

### Verificação
- `flutter analyze --no-pub`: limpo. `flutter test --no-pub`: **263/263**. Backend isolado:
  **220/220** (era 221; -1 pelo teste do rerank removido — queda esperada).
- Efeito: até 100.000 caracteres de narrativa clínica deixam de sair do aparelho por sessão, e some
  a dependência de LLM (e a classe de falha silenciosa por 503) neste fluxo.

### Pendências
- `/gerar-artigos` passa a ser a única função de IA que pode rodar **100% local** (só palavras-chave
  saem do aparelho). Não implementado.
- Considerar filtrar a fonte para `journal` no OpenAlex: os resultados vêm muito de repositórios e
  agregadores (LA Referencia, ARES, Zenodo, Dialnet, Redalyc).
- `log.info("Solicitacao de artigos - temas=%d")` continua sendo a única janela para saber quais
  palavras o extrator produz.
- A mesma fragilidade de rótulo (`log.exception("Gemini JSON error")` para 503/timeout) permanece em
  `_chamar_llm_json_gemini`, que ainda serve a geração de progresso.

## Verificação do backup no emulador (06/10/2026) — EXPORT/IMPORT APROVADOS

### Contexto
- Fechar a pendência da seção de 05/10 (verificar no aparelho o menu ⋮ > "Backup e dados").
  Feito no emulador `mentall` (API 34) com o APK release da v1.0.47 — mesmo código publicado.

### O que mudou (arquivos)
- `AGENTS.md`: esta seção. **Nenhum código foi alterado.**

### Verificação
- **Hub unificado confirmado:** "Backup e dados" traz Exportar + Importar + Backup automático
  (frequência / local / último backup) numa só página — o objetivo do commit de 05/10.
- **Export (end-to-end):** botão -> JSON gravado em cache -> folha de compartilhamento do sistema
  (`share_plus`). **O backup NÃO é texto puro:** envelope AES-GCM (`tipo`/`nonce`/`cifrado`/`mac`,
  380.150 bytes). Confirma que o achado "backup plaintext" (seção de 29/08) segue corrigido —
  mandar o arquivo para Gmail/Drive não vaza prontuário.
- **Import (end-to-end):** `file_picker` entregou e cacheou o arquivo; o import decifrou o envelope e
  **gravou seletivamente por ID** — `pacientes`, `sessoes`, `perfil_profissional`, `app_config` e
  `encryption_meta` com mtime 11:32 (mesmo minuto do retorno do picker), enquanto outras 9 caixas
  ficaram em 29/09. Home intacta (23 pacientes); 0 `FATAL EXCEPTION`.
- **Prova indireta da cripto:** se o MAC AES-GCM falhasse, `importarDeJson` lançaria, cairia no catch
  ("Não foi possível importar o backup") e **nenhuma** caixa seria reescrita. Houve escrita, logo o
  round-trip export -> cifra -> import -> decifra é consistente com a chave do aparelho.

### Pendências
- Não exercitado: a gravação em disco do "Fazer agora" (o teste de widget cobre o disparo com
  dublê, não a escrita real), nem a persistência da frequência por interação real.
- UX menor (não é defeito): o botão fica em "Exportando..." enquanto a folha de compartilhamento
  está aberta, porque `Share.shareXFiles` só resolve quando ela fecha.

## Verificações no emulador (06/10/2026) — GATE DE BIOMETRIA OK + STARTUP MEDIDO

### Contexto
- Suspeita de que o app abria direto na Home sem exigir autenticação (sinal de alarme nº 1 do
  checklist). **Não é bug** — o gate roda e o emulador cai no fail-safe por não ter tela bloqueada.
- As métricas de startup existentes (`[startup]` no logcat, `Displayed` do sistema) medem a init do
  Dart e o splash, **não** o tempo até a Home. Medição real: **~3,5s até a Home** no emulador.

### O que mudou (arquivos)
- `AGENTS.md`: esta seção. **Nenhum código foi alterado.**

### Verificação
- **Gate (funciona como projetado):** `chave_gerada` existe no `encryption_meta.hive`
  (`encryption_service.dart:188-191`) -> `requerAutenticacao` true (`auth_service.dart:285`) ->
  `LoginPage` montado (`app_start_page.dart:106`) -> auto-tentativa (`login_page.dart:30,40`). Com
  `locksettings get-disabled=true` (emulador sem tela bloqueada) `suportaGate()` é false -> fail-safe
  (`auth_service.dart:195-206`) -> cofre durável -> Home, com o aviso de `login_page.dart:56-66`. Em
  aparelho COM tela bloqueada o prompt aparece e cancelar honra o gate (linha 199: "não burla").
- **Startup:** `[startup]` ~708-710ms (init Dart) e `Displayed +1s537ms` (= splash, primeiro frame).
  Aos 3,5s o app já estava na Home. **Suspeito principal é o splash, não o KDF:**
  `app_start_page.dart:45-49` usa 1s se `obterPerfil() != null`, senão 3s; a splash seguia opaca aos
  2,0s, sugerindo a ramificação de 3s (hipótese a confirmar — seriam até 2s gratuitos por lançamento).
- `flutter analyze` limpo; `flutter test` **263/263**; `tests/run_isolated.py` **221/221**;
  `flutter build apk --release` OK (13,3s), sha256 `9b2e1123...ff4bcb33` = o mesmo da v1.0.47;
  instalado e aberto no emulador `mentall` (API 34) sem erro fatal.

### Pendências
- **Release `1.0.47+48` em limbo:** 3 commits locais sem push (inclui este). O `deploy.yml` roda o job
  `deploy` até para mudança só de app (`paths-ignore` cobre só `*.md`/`tasks/`/`docs/`),
  reiniciando o backend no Fly sem necessidade.
- **Upgrade do Flutter:** `package_info_plus`, `sentry_flutter`, `share_plus`, `wakelock_plus` aplicam
  KGP e o Gradle avisa que versões futuras do Flutter **falharão** o build — atualizar os 4 antes de
  qualquer `flutter upgrade`.
- Confirmar a duração do splash; medir startup em aparelho físico (emulador != baixo custo).
- APK release usa assinatura de debug (`key.properties` ausente) — não serve para a Play Store.

## Encerramento de plano (06/10/2026) — PLANO DE STARTUP/PIN ARQUIVADO

### Contexto
- O plano `.opencode/plans/otimizacao-startup-pin.md` (startup 13s → <3s) seguia no repo como
  se estivesse pendente. A verificação contra o código mostrou que 3 dos 4 itens já estavam no
  ar desde 13/08 e que o item 4 (PBKDF2 nativo no Android) ficou obsoleto com a mudança de
  arquitetura de 02/09 (envelope encryption: desbloqueio lê a chave do Keystore, sem KDF na UI).

### O que mudou (arquivos)
- `.opencode/plans/otimizacao-startup-pin.md`: cabeçalho **ENCERRADO** com data, motivo e aviso de
  segurança sobre o snippet do `MainActivity`; conteúdo original preservado abaixo. O arquivo é
  ignorado pelo git, então a marcação é local.
- `AGENTS.md`: esta seção.

### Verificação
- Itens 1-3 rastreados no código: `_sessoesDoMesHomeProvider` (`home_dashboard.dart:549`),
  `_tabsConstruidas` (`main_shell.dart:19`), cache de frame (`sessao_service.dart:14-15,35-67`) —
  todos introduzidos em `4f10804` (13/08/2026, junto de Dockerfile/Fly.io, sem menção no título).
- PBKDF2 hoje só em `login_page.dart:241` (migração única do PIN legado) e
  `backup_restore_page.dart:82` (backup/restore). `app_start_page.dart` não referencia PIN,
  PBKDF2 nem desbloqueio.
- Suíte Flutter **263/263**, backend **221/221**, `flutter analyze` limpo (medidos em 06/10/2026,
  antes desta alteração — que é só de documentação).

### Pendências
- Nenhuma de código. Se o startup voltar a incomodar, **medir antes** (DevTools/Stopwatch): o PBKDF2
  não está mais no caminho de abertura.

## UI/Configurações (05/10/2026) — BACKUP UNIFICADO EM "BACKUP E DADOS"

### Contexto
- Havia backup em dois lugares: **Configurações > "Backup e dados"** (automático) e **menu ⋮ da Home > "Backup e restauração"** (exportar/importar). O dono pediu unificar tudo no menu de backup.

### O que mudou (arquivos)
- `lib/screens/backup_restore_page.dart`: vira o hub único — título **"Backup e dados"**; novo bloco **"Backup automático"** (frequência, local do backup, último backup + **"Fazer agora"**), com os helpers movidos de Configurações.
- `lib/screens/configuracoes_page.dart`: removida a seção "Backup e dados" e os helpers/import órfãos (`_labelFrequenciaBackup`, `_abreviaPasta`, `_formatarDataHora`, `_backupAtrasado`, `backup_storage.dart`).
- `lib/screens/home_page.dart`: item do menu ⋮ renomeado para **"Backup e dados"** (valor `'backup'` inalterado).
- `test/widgets/backup_restore_page_test.dart` (novo, 3): renderiza exportar/importar + automático, persiste a frequência e dispara "Fazer agora".

### Verificação
- Flutter **263/263** (era 260; +3). Backend inalterado (**221/221**). `flutter analyze` limpo.
- APK: `MentAllPRO-v1.0.47.apk` (~79,4 MB), sha256 `9b2e11236fd8428dbb9f6e61d88fc38d0626b4f2a3d2fd0072f28a61ff4bcb33`.

### Pendências
- Verificar no aparelho: menu ⋮ > "Backup e dados" (automático + exportar/importar). Só código de app — **sem deploy de backend**.

## Correções e Funcionalidades (05/10/2026) — FRENTE C (LEMBRETES ÓRFÃOS) + ITENS PARCIAIS DA AUDITORIA

### Contexto
- Fechar a **Frente C** (o profissional cancelar os próprios lembretes agendados na nuvem) e resolver 4 itens parciais da auditoria de 06/09 (26, 27, 12, 13).

### O que mudou (arquivos)
- **Lembretes (Frente C):** backend `GET /lembretes` (escopado por `owner_id` + `?status=`) e `DELETE /lembretes` (soft-cancel em lote dos pendentes). `listar_lembretes` agora **exige `owner_id`** (antes listava todas as linhas, sem filtrar dono — fecha vazamento). App: `ApiClient.delete`, `LembreteService.listarLembretes/cancelarTodosLembretes` e tela `lib/screens/lembretes_page.dart` (Configurações > Agenda e lembretes).
- **PDF (item 26):** `lib/services/pdf_export_service.dart` pagina conteúdo clínico longo em "Registro de Sessão" e "Síntese Revisada" (`_secaoClinicaBlocos` + novo `_blocoTextoBlocos`); removidos `_secaoClinica`/`_blocoTexto` órfãos. Hooks de teste `gerarPdfSessaoParaTeste`/`gerarPdfSinteseRevisadaParaTeste`.
- **Descarte de edição (item 27):** `compromisso_form_dialog.dart` e `novo_paciente_dialog.dart` confirmam descarte (`PopScope(canPop:false)` + snapshot), no padrão do `perfil_profissional_form_page`.
- **Áudio (item 12):** ao salvar com "não manter" (ou ao remover o áudio), o `.m4a` é excluído — `AudioRelatoService.excluirArquivoAudioFisico` (no-op no web, testável sem instanciar o gravador); `audioRelatoPath` zerado.
- **DB (item 13):** `services/db.py` `reset_cache()` corrigido (chamava `cache_clear` inexistente → `AttributeError`); **`ALLOW_SQLITE_FALLBACK=false` nos secrets do Fly** (fail-closed já existia no código; faltava ligar no deploy).
- **Deploy:** push para `master` (7 commits) → CI verde. O gate `pip-audit` acusou **PyJWT 2.14.0 → PYSEC-2026-4141** (novo advisory); bump para **`2.15.0`** e novo push (`253ca15`) → CI verde e deploy concluído.

### Verificação
- Backend **221/221** (era 215; +6). Flutter **260/260** (era ~243; +17). `flutter analyze` limpo.
  - Nota: o commit do áudio sobrescreveu por engano `test/services/audio_relato_service_test.dart` (perdeu 4 testes pré-existentes); restaurado em `faa984a`.
- Produção: `/health` 200 (`database: turso`); `GET /lembretes` sem auth → **401** (rota nova no ar). A máquina foi reiniciada pelo secret do Fly (rolling) e pelo deploy.
- APK: `MentAllPRO-v1.0.46.apk` (~79,4 MB), sha256 `cecec4f38d0040b1d792d1baeb8baf67af07f571e6f43105a9abff5b2b776fdc`.

### Pendências
- Verificar no aparelho: tela "Lembretes agendados" (listar/cancelar), descarte nos diálogos e exclusão do áudio ao "não manter".
- Itens ainda abertos: matriz visual de acessibilidade (item 30, adiada) e paginação do "Histórico" (`_cardSessao`, não incluída no item 26).

## Acessos (30/09/2026) — REDEFINIÇÃO DA SENHA DO ADMIN ANDERSON

### Contexto
- A senha do 2º admin do painel (`anderson.lemos@icloud.com`) **não havia sido registrada** (decisão de segurança). O dono pediu a redefinição.

### O que mudou (dados no Turso)
- `password_hash` de `anderson.lemos@icloud.com` trocado via `services.usuarios.redefinir_senha` (bcrypt), com conexão confirmada no Turso. **Nova senha não registrada aqui** (repassada por canal seguro).

### Verificação
- Conexão Turso confirmada (`db._usa_turso=True`, abortado se caísse no SQLite local); `hash_mudou=True`; `verificar_senha(nova)=True`; `role=admin`, `status=ativo`.
- Produção: `POST https://mentall-api.fly.dev/admin/login` com a nova senha → **303** para `/admin`.

### Pendências
- Nenhuma. Senha é irrecuperável (bcrypt); próximas trocas via app ou novo comando.

## Acessos (30/09/2026) — NOVO DONO DO PAINEL + GATE DE `status`

### Contexto
- O dono pediu um **segundo administrador** do painel (`/admin`).

### O que mudou (dados no Turso)
- Criada a conta **`anderson.lemos@icloud.com`** (nome "Anderson Lemos"), **`role='admin'`**, `status='ativo'` — login no painel confirmado (303). **Senha não registrada aqui** (repassar por canal seguro; troca via app ou novo comando).
- **Não há tela/rota para promover** um dono: hoje é `UPDATE usuarios SET role='admin' WHERE email=?` (decisão do dono: **sem script/UI** por enquanto).

### O que mudou (código)
- `backend/main.py`: `/admin/login` e `_usuario_admin_autenticado` passam a exigir **`status='ativo'`** (antes só checavam o papel — uma conta `pendente` com `role='admin'` entrava no painel sem confirmar o e-mail; o `/auth/login` já recusava `pendente` com 403). O admin legado (`APP_USERNAME`) segue ativo.
- `backend/tests/test_admin.py` (+2): login de admin `pendente` recusado; cookie de admin `pendente` não abre o painel.

### Verificação
- Backend **215/215** (era 213; +2). CI verde (Backend · Flutter · Dependency scan · Deploy). Produção: login do Anderson 303; `/health` 200.

## Correções e Funcionalidades (30/09/2026) — PRESENÇA CONFIÁVEL + PAINEL EM HORÁRIO DE BRASÍLIA

### Contexto
- O painel mostrava o usuário **offline mesmo com o app aberto** (uso real: app no celular, painel no PC). O heartbeat (a cada 3 min) só rodava em **primeiro plano** e a janela era de **5 min**; quando o Android suspendia o app (tela apagada/troca de app), a presença caía. Além disso, o painel exibia os horários em **UTC**.

### O que mudou (arquivos)
- `lib/widgets/app_lock_gate.dart`: heartbeat **60s** (era 3 min); **heartbeat ao pausar** (antes de `bloquear()` apagar o JWT = "visto por último", com timeout de 3s para não atrasar o bloqueio); heartbeat ao desbloquear.
- `lib/screens/login_page.dart`: heartbeat após `estabelecerSessaoServidor()`.
- `backend/services/admin.py`: `ONLINE_JANELA_MINUTOS` **5 → 10**; expõe `ultimo_hb`.
- `backend/admin_ui.py`: `_quando()` converte **UTC → America/Sao_Paulo** (`dd/mm/aaaa hh:mm`); nova coluna **"Visto"** (tempo relativo do heartbeat).
- `backend/requirements.txt`: **`tzdata==2026.4`** (base IANA no container `python:3.12-slim`).
- `backend/tests/test_admin.py` (+5): BRT, `_visto_ha`, janela de 10 min, `ultimo_hb`.
- `test/widgets/app_lock_gate_test.dart` (+1): ao pausar envia heartbeat **antes** de bloquear.

### Verificação
- Backend **213/213** (era 208; +5). `flutter analyze` limpo; `flutter test` **243/243** (era 242; +1).
- CI verde (Backend · Flutter · Dependency scan · Deploy). Produção: `/health` 200; painel em BRT + coluna "Visto".
- APK: `MentAllPRO-v1.0.45.apk` (~76 MB), sha256 `d33b212060e8eca6da854e115e56fd00ae7792686420820bad1c3b26dddffaf0`.

### Pendências
- Instalar o **1.0.45** no celular e confirmar: app aberto → painel **online**; celular ocioso → "há X min"; horário em BRT.

## Lojas (29/09/2026) — SCREENSHOTS (emulador + seed de demo)

### Contexto
- Frente 2 (publicação): gerar as **capturas de tela** exigidas pelas lojas.

### O que mudou (arquivos)
- **Emulador Android** instalado (`emulator` + `system-images;android-34;google_apis;arm64-v8a`), AVD **`mentall`** (Pixel 7).
- `lib/services/demo_lojas_service.dart` (novo): semeia **Helena** (com foto), **23 pacientes**, **7 agendamentos** para hoje, **R$ 5.780** recebidos + **R$ 380** pendentes (mês corrente) e uma **sessão com IA** (relato/síntese/formulação/intervenções/apontamentos). Gated por **`--dart-define=DEMO_LOJAS=true`** → produção intacta.
- `lib/main.dart`: usa o seed no lugar do paciente demo quando a flag está ligada.
- `test/services/demo_lojas_service_test.dart` (6).
- `store/screenshots/*.png` (5, **1080×2160 RGB**): Home, Pacientes, Financeiro, Agenda, Sessão com IA.

### Verificação
- `flutter analyze` limpo; `flutter test` **242/242** (era 236; +6). Capturas geradas no emulador (Android 14) e ajustadas ao Play (máx 2:1, sem alfa).

### Pendências (Frente 2)
- Descrição/categorias, Política/Termos (URL pública) e nota LGPD.
- Contas de dev (Play/App Store) + keystore de release.
- App Store: screenshots próprios (6.7"/6.5"/5.5").

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
