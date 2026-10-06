# Checklist de publicação nas lojas de app (Google Play / App Store)

> **Status (06/10/2026):** revisado após auditoria do `AGENTS.md` e das `tasks/` contra o código.
> APK mais recente: **`1.0.47+48`** (este arquivo dizia `1.0.28+29`).
>
> **As 4 pendências que este arquivo chamava de "bloqueiam publicação" estão RESOLVIDAS**
> (fail-closed de criptografia, CSP sem `unsafe-inline`, `TRUSTED_PROXIES`, `--proxy-headers`).
> O que bloqueia publicação hoje é: **keystore de produção, política de privacidade em URL pública,
> descrição/categorias e a assinatura (RevenueCat)**.

## 1. SEGURANÇA — resolvido

- [x] **Fail-closed de criptografia (vuln-0013)** — `EncryptedServiceMixin.encrypt` **lança**
  `StateError` sem proteção (`lib/services/encrypted_service_mixin.dart:6-16`); o uso é bloqueado
  (`lib/screens/app_start_page.dart:83-85`); indicador de proteção ativa/inativa na Home
  (`home_page.dart:505-514`) e em Configurações (`configuracoes_page.dart:57-58,100-108`). O cofre
  durável (Keystore/Keychain, sem biometria) garante cifra mesmo sem bloqueio de tela.
- [x] **CSP com nonce** (sem `unsafe-inline`) — `backend/main.py:675-677`; coberto por
  `backend/tests/test_csp.py`.
- [x] **`TRUSTED_PROXIES`** — `backend/main.py:113,133` + secret no Fly (`AGENTS.md`, 28/09).
- [x] **`--proxy-headers`** — `Dockerfile:11`, `backend/start_backend.sh:6`, `render.yaml:8`.
- [ ] **Re-scan Strix:** o último foi 30/08. Houve mudanças de segurança em 06/10 (guarda de schema
  da síntese, dupla criptografia, PII no log, CORS) **sem novo scan registrado**.

## 2. Pendências TÉCNICAS de loja — o que realmente falta

- [x] **Ícone** — `pubspec.yaml:96-103`; `store/play_icon_512.png` (512×512); mipmaps 48-192; iOS
  1024 sem alpha.
- [ ] **Screenshots:** Play pronto (5 em `store/screenshots/`, 1080×2160). **Falta App Store**
  (6.7", 6.5", 5.5").
- [ ] **Descrição e categorias:** texto pt-BR e inglês, categoria (declaração de Saúde), palavras-chave.
- [ ] **Política de Privacidade e Termos em URL pública** — hoje só existem **páginas in-app**
  (`lib/screens/lgpd/`). O repositório irmão `site-mentall-pro` tem apenas `index.html`, sem essas
  páginas nem deploy. **É o bloqueio mais concreto.**
- [ ] **Keystore de produção** — a integração está pronta
  (`android/app/build.gradle.kts:10-18,45-62`, variáveis `MENTALL_*`), mas o keystore **não existe**.
  Guardar fora do repositório.
- [ ] **Assinatura / RevenueCat (Fase 1 do plano de negócio)** — produtos no Play Billing e StoreKit,
  integração, preço e teste de 7 dias (`tasks/plan.md`). **Nada implementado.**
- [ ] **Contas de desenvolvedor:** Play (US$ 25) e App Store (US$ 99/ano).
- [ ] **Nota LGPD para o console:** declaração sobre dados sensíveis de saúde (art. 5º, II e 11).
- [ ] **Pré-lançamento em aparelho real:** login/conta, PIN, biometria, áudio, IA, backup/restore,
  WhatsApp.

## 3. INFRA — resolvido

- [x] **Deploy das dependências** — produção responde `/health` 200 (`database: turso`).
- [x] **Rotação do `WUZAPI_WEBHOOK_TOKEN`** — `AGENTS.md` (29/09): token novo -> 200, antigo -> 403.
- [x] **CI com scan de dependências** — `.github/workflows/deploy.yml:64-88`, gate em `:94`.
- [ ] **Conferir os demais secrets do Fly** (JWT_SECRET, chaves de IA, Turso, SMTP, wuzapi).
  `ALLOW_SQLITE_FALLBACK=false` foi setado em 28/09, mas **não é verificável a partir do repositório**.

## 4. Regressão antes do envio

- [ ] `flutter analyze --no-pub` — hoje: **No issues found!** (o warning antigo de `tools/` não
  existe mais).
- [ ] Suítes: Flutter **276/276**, backend **246/246**. Os números que este arquivo trazia
  (156/156 e 132/132) eram de 30/08.
- [ ] Re-verificar com Strix após as mudanças de 06/10.
