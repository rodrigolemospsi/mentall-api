# Memória — linha visual 2.0.x (MentAll PRO)

> Documento de continuidade criado em 28/10/2026. O `AGENTS.md` (~248 KB) guarda checklist, regras e
> seções recentes; o histórico antigo fica em `docs/AGENTS_historico.md`. Este arquivo consolida o
> **estado atual** para retomadas rápidas.

## Estado do projeto

- **Original:** `/Users/rodrigolemos/mentall-pro-app` (este diretório)
- **Backup histórico** (antigo original, 16 GB com `build/` e APKs):
  `~/Documents/deepseek-harness/default-workspace/mentall-pro-app-copia`
- **Versão:** `2.0.6+66` (`pubspec.yaml`)
- **Git:** `master` == `origin/master` == `d0707be`; remotos `origin` (GitHub) e `backup` (pasta antiga)
- **Tag de release:** `v2.0.4` (anotada, objeto `662afdd`) → commit `e5be382`
- **CI GitHub Actions** (`Deploy to Fly.io`): analyze/test Flutter + testes do backend + pip-audit/
  osv-scanner + **deploy automático no Fly**. Run `40863361107` verde. Commits só de `**.md` não
  disparam CI.

## Linha visual 2.0.x (o que mudou na UI)

- Paleta do painel portada para o app em `lib/utils/mentall_colors.dart` (`PainelCores`): roxo
  `#7C3AED`, gradiente da sidebar `#6D28D9 → #4C1D95`, fundo `#F3F5FB`, cards brancos com borda
  `#E6EAF2`, sombra suave, semânticas ok/atenção/erro e escala do modo escuro.
- Tema global em `lib/main.dart` (`_criarTema` + `_esquemaPainel`): ColorScheme explícito claro/escuro
  + AppBar, Card, botões, inputs, chips, diálogo, bottom sheet, snackbar, FAB, navbar, list tile e
  popup menu.
- Navbar inferior em gradiente da sidebar (`lib/screens/main_shell.dart`).
- Login e splash com fundo em gradiente (login com cartão branco, largura máx. 420).
- AppBar padrão voltou a ser roxo com título branco (corrige título preto em “Pacientes” e a Agenda
  branca).
- Home: AppBar com o **fundo da tela** (cinza) e **foto do profissional** em avatar de **92 px**
  (anel 3 px, key `foto-profissional`), fallback para a logo; `toolbarHeight: 104`.

## Verificação (MEDI, 28/10/2026)

- Flutter: `flutter analyze` sem issues; `flutter test` **355/355 OK**.
- Backend mesclado (custos): `tests/run_isolated.py` **532/532 OK**.
- APKs v2.0.4: `MentAllPRO-v2.0.4-debugsign.apk` (debug key, instala por cima) e
  `MentAllPRO-v2.0.4-release.apk` (upload key) + AAB em `build/app/outputs/bundle/release/`.
  SHA-256: debugsign `05b7978a…f49a81`; release `b95d7e13…4388ac9`.
- Assinaturas: debug SHA-1 `B6:38:41:F4:…:21:F7`; upload key SHA-1 `C2:E5:C8:5E:…:B5:62`.
- Backend local (launchd `com.mentall.backend`, porta 8000): `/health` 200 (`sqlite_local`).
- Backend produção (Fly): `/health` 200 após o deploy do CI.

## Rotina para gerar APK (a partir do original)

```bash
cd /Users/rodrigolemos/mentall-pro-app
export PATH="$HOME/flutter/bin:$PATH" ANDROID_HOME="$HOME/Android/sdk"
flutter analyze --no-pub && flutter test --no-pub
flutter build apk --release                        # assinatura debug (instala por cima)
cp build/app/outputs/flutter-apk/app-release.apk MentAllPRO-vX.Y.Z-debugsign.apk
source "$HOME/.mentall-pro-keys/release.env"
flutter build apk --release                        # assinatura de produção (upload key)
cp build/app/outputs/flutter-apk/app-release.apk MentAllPRO-vX.Y.Z-release.apk
flutter build appbundle --release
```

- O sandbox do agente bloqueia escrita no cache do Flutter → esses comandos precisam de aprovação
  (`danger-full-access`).
- Bump de versão em `pubspec.yaml` (`version: X.Y.Z+CODE`) e commit `chore(release): ...`.

## Backend local

- launchd `com.mentall.backend` → `/Users/rodrigolemos/mentall-pro-app/backend/start_backend.sh`
  (porta 8000, `.venv`, `.env` com chaves de produção).
- Wuzapi em `~/wuzapi` (serviço separado, intocado).

## Backup automático em pasta escolhida (correção 2.0.6+66)

- **Sintoma:** ao escolher uma pasta manual em “Backup e dados → Local do backup”, o “Fazer agora”
  (e o backup automático) falhava com o snackbar genérico “Não foi possível salvar o backup.
  Tente novamente.”.
- **Causa:** o `file_picker.getDirectoryPath()` devolve um caminho de arquivo; o app gravava com
  `dart:io`, que não tem permissão de escrita em pastas fora do diretório privado no Android 11+
  (Storage Access Framework não é aplicado por caminho). O erro era engolido e virava `null`.
- **Correção (Android):**
  - `MainActivity.kt` expõe o canal `mentall/backup_saf` com `pickDirectory` (ACTION_OPEN_DOCUMENT_TREE
    + permissão persistível), `testDirectory` (grava e apaga um arquivo de teste) e `writeFile`
    (DocumentsContract/ContentResolver). A URI da árvore fica salva em `backup_local`.
  - `backup_storage_io.dart` grava via canal quando o local é `content://`; mantém caminho de arquivo
    para o diretório padrão e para iOS. `escolherPastaBackup()` valida a pasta com teste de escrita e
    devolve nome amigável (`backup_local_nome`).
  - Se a pasta configurada falhar depois (removida/permissão revogada), `BackupAgendamentoService`
    grava na **pasta padrão do app** e liga `backup_fallback_padrao`; a tela mostra o aviso “Pasta
    escolhida indisponível” e o snackbar informa o fallback — o backup nunca é perdido em silêncio.
  - iOS segue com `file_picker` + validação de escrita; web segue com stub (sem arquivo).
- **Verificado no emulador (30/10):** escolher `Download/MentAll` → “Pasta do backup definida:
  MentAll.”; “Fazer agora” cria o `.json` via SAF; após force-stop/reabrir, a permissão persistida
  continua válida; ao apagar a pasta, o próximo backup cai em `app_flutter` com o aviso de fallback.
- **Testes:** `flutter analyze` sem issues; `flutter test` **355/355** verde.
- **Confirmado no aparelho pelo dono (30/10):** instalou a 2.0.6+66, reescolheu a pasta no
  fluxo novo e o “Fazer agora” gravou o backup — correção aceita.
- **Artefatos 2.0.6+66 (upload key):** `MentAllPRO-v2.0.6-release.apk` (82,1 MB, SHA-256
  `c95bbe75…1fce05`) e `MentAllPRO-v2.0.6.aab` (74,4 MB, SHA-256 `280e677c…a66985b`) — `.aab`
  agora ignorado no git.

## Pendências / próximos passos

- Validar no aparelho: foto da Home (92 px), barras roxas, login/splash.
- Telas de cadastro/onboarding (`conta_page.dart`, `onboarding_page.dart`) ainda sem o gradiente.
- Opcional: GitHub Release a partir da tag `v2.0.4`; atualizar actions (`checkout@v4`/`setup-python@v5`
  ainda usam Node 20, deprecado).
- `AGENTS.md` passou de 200 KB: comprimir histórico antigo para `docs/AGENTS_historico.md` (regra do
  próprio arquivo).

## Onde procurar

- Layout e remotos: `COPIA.md`
- Histórico detalhado por tarefa: `docs/AGENTS_historico.md` (índice no `AGENTS.md`)

## Anamnese com criptografia ponta-a-ponta (01/11/2026, versão 2.0.7+67)

- **Motivação:** respostas de anamnese (dado sensível de saúde) ficavam em texto
  claro no banco do servidor — item P0.4/P1.11 da auditoria LGPD.
- **Desenho:** chave AES-256-GCM aleatória por ficha, gerada e guardada só no
  app (cifrada no Hive); vai ao paciente no **fragmento do link** (`#k=...`),
  que o navegador não envia ao servidor. A página cifra com WebCrypto e o
  backend grava apenas `{alg:A256GCM, iv, ct}`. O app decifra no sync.
- **Backend:** colunas `e2e`/`cifrada` em `anamneses` (migração automática);
  `POST /anamneses` aceita `e2e`; `/responder` aceita `{cifrada, iv, ct}` e
  rejeita texto claro quando a ficha é E2E; `/status` devolve o envelope.
  Fichas antigas continuam no caminho legado em texto claro (compatibilidade).
- **App:** `lib/services/anamnese_e2e_crypto.dart` (pointycastle),
  campos Hive 10–12 (`chaveCripto`, `e2e`, `falhaDecifrar`), link do WhatsApp
  usa `anamnese.urlComChave`, diálogo avisa quando não foi possível decifrar.
- **Limitação:** perder o aparelho/dados = perder a chave (respostas cifradas
  no servidor ficam ilegíveis — inclusive para o suporte). É o trade-off do E2E.
- **Testes:** backend 541 OK (9 novos de E2E); Flutter 365 OK (6 de crypto +
  4 de serviço). Validado também no Chrome real (fragmento → WebCrypto → banco
  cifrado → decifração batendo com o enviado). Detalhes em `docs/ANAMNESE_E2E.md`.
- **Política:** in-app e site atualizados para v1.3 — 01/11/2026 (anamnese
  cifrada ponta a ponta; servidor sem a chave).
- **Deploy/validação (01/11):** backend no ar (CI run 41255598544 verde, migração
  criou `e2e`/`cifrada` no banco de produção); política v1.3 publicada em
  mentallpro.com.br/privacidade. Validado de ponta a ponta em produção: ficha
  aberta no Chrome com `#k=`, envelope `A256GCM` no banco sem texto claro e
  decifração batendo; e no app real do emulador (2.0.7+67): link do WhatsApp com
  `#k=`, ficha criada como `e2e=1`, sync mostrou "Respondido em 01/11" e o
  diálogo exibiu as respostas decifradas. Dados de teste apagados ao final.
- **Artefatos 2.0.7+67:** `MentAllPRO-v2.0.7-debugsign.apk` (SHA-256
  `d985eab2…c2b6b5`), `MentAllPRO-v2.0.7-release.apk` (upload key; instala por
  cima da 2.0.6) e `MentAllPRO-v2.0.7.aab`.
- **Pendências:** TTL/limpeza de respostas antigas em texto claro, expiração/
  revogação de links (P1.11), migração opcional de fichas legadas pendentes para
  E2E no reenvio e publicação nas lojas (AAB).

## Assinatura eletrônica com evidências (Fase A) — 01/11/2026, 2.0.8+68

- **Contrato:** página pública (modelo padrão e personalizado) ganhou CPF
  opcional + checkbox "Li e concordo"; o backend registra nome, CPF validado,
  data/hora UTC, IP, User-Agent, versão `contrato-v1`, **hash SHA-256** do texto
  canônico e **código de verificação** (`XXXXX-XXXXX`). Novo endpoint público
  `GET /verificar/<código>`.
- **App:** card do contrato mostra comprovante (código, hash, data, CPF
  mascarado) com botões **Comprovante em PDF** (contrato + página de
  comprovante + QR) e **Verificar autenticidade**.
- **Dados novos:** CPF no paciente; CPF/CNPJ no perfil profissional (formulários
  e envio no POST /contratos). CPF/CNPJ aparecem no cabeçalho do contrato.
- **Correções de robustez:** contratos agora gravam sempre cópia cifrada no
  Hive (evita cache com nome/CPF/hash em texto claro) e leituras devolvem cópias.
- **Política:** v1.4 — 01/11/2026 (in-app + site), citando evidências de
  assinatura e anamnese E2E. Site publicado com a nova versão.
- **Pesquisa CFP/Receita (recibos):** PF → Receita Saúde obrigatório desde
  2025; PJ/CNPJ → NFS-e municipal; CFP exige PJ registrada (Res. 16/2019);
  recibos/notas sem dados clínicos. RFB tem emissão em lote por arquivo de
  integração — é o caminho para o app (não há API oficial de emissão).
  Detalhes em `docs/ASSINATURA_ELETRONICA.md`.
- **Deploy/validação (01/11):** primeiro deploy falhou no smoke check (índice
  criado antes da migração da coluna `aceite_codigo`); corrigido em `db.py`
  (tabelas → migrações → índices) e reimplantado com sucesso (run
  `41336333919`). Validado em produção no Chrome: checkbox bloqueia, assinatura
  gera código/hash, página `/verificar/<código>` mascara paciente/CPF e o hash
  recomputado bateu com o banco. Contrato de teste apagado. Política v1.4
  publicada no site.
- **Artefatos 2.0.8+68:** `MentAllPRO-v2.0.8-debugsign.apk` (SHA-256
  `1f430d85…da0f01`), `MentAllPRO-v2.0.8-release.apk` (upload key; instala por
  cima da 2.0.7) e `MentAllPRO-v2.0.8.aab`.
- **Próximos passos:** Fase 2 (recibos Receita Saúde em lote + declaração de
  comparecimento com entrada/saída + retenção 5 anos). Opcional: OTP por
  e-mail e ICP-Brasil/plataforma certificada.

## Recibos e declarações (Fase 2) — 01/11/2026, 2.0.9+69

- **Card "Documentos"** no Resumo do paciente com: declaração de
  comparecimento (entrada/saída, sem CID/diagnóstico, assinatura eletrônica
  simples), **arquivo Receita Saúde em lote (CSV no leiaute oficial)**,
  comprovante de pagamento (não fiscal) e informe anual de pagamentos.
- **Leiaute oficial:** CSV `;`, 16 campos, `R01.001.001`, ocupação `255`,
  `PF`, CPFs pagador/beneficiário/profissional, `S`, registro profissional
  (Manual Receita Saúde v2.1, pergunta 24). Arquivo é importado no e-CAC →
  Carnê-Leão → Escrituração; o recibo oficial é emitido pelo Receita Saúde.
- **Registro local:** box `documentos_emitidos` (`DocumentoEmitido`, typeId 13)
  com numeração DOC-AAAA-0001/LOTE-AAAA-0001, código e hash SHA-256; snapshot
  cifrado no Hive. Testes: 7 novos (CSV/validações/numeração/cifra).
- **Regras fiscais documentadas:** PF → Receita Saúde; PJ/CNPJ → NFS-e;
  sem dados clínicos nos documentos; retenção 5 anos.
- **Validação (01/11):** Flutter 376 OK (7 novos), backend 551 OK; card
  "Documentos" validado no emulador 2.0.9+69; CI run `41339526378` verde e
  `/health` OK. Artefatos: `MentAllPRO-v2.0.9-debugsign.apk` (SHA-256
  `bf8afec5…f0b8b4`), `MentAllPRO-v2.0.9-release.apk` (upload key, instala por
  cima da 2.0.8) e `MentAllPRO-v2.0.9.aab`.
- **Pendências Fase 2.1:** backup/retenção da box, verificação pública dos
  documentos, envio ao paciente, NFS-e (PJ), OTP/ICP-Brasil opcionais.
