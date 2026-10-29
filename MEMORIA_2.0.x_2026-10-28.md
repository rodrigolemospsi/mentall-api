# Memória — linha visual 2.0.x (MentAll PRO)

> Documento de continuidade criado em 28/10/2026. O `AGENTS.md` (~247 KB) guarda o histórico completo;
> este arquivo consolida o **estado atual** para retomadas rápidas.

## Estado do projeto

- **Original:** `/Users/rodrigolemos/mentall-pro-app` (este diretório)
- **Backup histórico** (antigo original, 16 GB com `build/` e APKs):
  `~/Documents/deepseek-harness/default-workspace/mentall-pro-app-copia`
- **Versão:** `2.0.4+64` (`pubspec.yaml`)
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

## Pendências / próximos passos

- Validar no aparelho: foto da Home (92 px), barras roxas, login/splash.
- Telas de cadastro/onboarding (`conta_page.dart`, `onboarding_page.dart`) ainda sem o gradiente.
- Opcional: GitHub Release a partir da tag `v2.0.4`; atualizar actions (`checkout@v4`/`setup-python@v5`
  ainda usam Node 20, deprecado).
- `AGENTS.md` passou de 200 KB: comprimir histórico antigo para `docs/AGENTS_historico.md` (regra do
  próprio arquivo).

## Onde procurar

- Layout e remotos: `COPIA.md`
- Histórico detalhado por tarefa: `AGENTS.md` (seções datadas no topo, abaixo do checklist de fumaça)
