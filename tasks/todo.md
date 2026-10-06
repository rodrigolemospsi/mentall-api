# Tarefas — Venda recorrente + Painel de Controle

> **Revisado em 06/10/2026** (auditoria das `tasks/` contra o código).
> A lista abaixo reflete o que **existe de fato**, com evidência. As **Fases 2 e 3 estavam inteiras
> marcadas como pendentes e já estão implementadas**.
> **O que realmente falta: Fase 4 (cobrança) e Fase 5 (assinatura no app).**

## Fase 1 — Contas de psicólogos — COMPLETA

- [x] 1.1 tabela `usuarios` — `backend/services/db.py`
- [x] 1.2 `services/usuarios.py`
- [x] 1.3 schemas `RegistrarRequest/Response` + `LoginResponse`
- [x] 1.4 `POST /auth/registrar`
- [x] 1.5 `POST /auth/login` por email/senha + JWT com `owner`
- [x] 1.6 Frontend: login por e-mail/senha — `lib/screens/conta_page.dart:73,88,111,131` +
  `lib/services/api_client.dart:278`; é a **primeira tela do boot**
  (`lib/screens/app_start_page.dart:101-103`)
- [x] 1.7 Isolamento por `owner_id` — `backend/tests/test_status_idor.py:68,99`,
  `test_lembrete_idor.py`, `test_telemetria.py:66`

## Fase 2 — Telemetria — IMPLEMENTADA

- [x] 2.1 tabelas `dispositivos` e `eventos` — `backend/services/db.py:233,241`
- [x] 2.2 `POST /telemetria/heartbeat` e `/telemetria/evento` — `backend/main.py:1931,1948`
- [x] 2.3 `telemetria_service.dart` + heartbeat — `lib/services/telemetria_service.dart:72,93`,
  chamado no lock gate (`lib/widgets/app_lock_gate.dart:81,123`) + 6 eventos de uso
- [x] 2.4 Verificação — `backend/tests/test_telemetria.py:19,36`; KPI "online" em
  `backend/services/admin.py:20-28`

## Fase 3 — Painel de administração — FEITO POR OUTRO CAMINHO

- [x] 3.1 `/admin/*` role-gated e paginado — `backend/main.py:1994,2004` +
  `backend/services/admin.py:52`
- [x] 3.2 **Não é um projeto Flutter web**: o painel é **HTML server-side**
  (`backend/admin_ui.py`). A arquitetura mudou em relação ao plano; a funcionalidade existe.
- [x] 3.3 KPIs e lista de usuários — `backend/services/admin.py:24`; `admin_ui.py:123,155-156`
- [ ] 3.4 Verificação do dono em produção — sem registro de validação

## Fase 4 — Cobrança e assinatura — NADA IMPLEMENTADO

- [ ] 4.1 RevenueCat (entitlements + 7 dias grátis)
- [ ] 4.2 Webhooks de assinatura -> `assinaturas` no backend
- [ ] 4.3 Stripe para pagamento no navegador (Pix/cartão)
- [ ] 4.4 Verificação: assinar na loja de teste muda o plano no painel

Confirmado: não há `purchases_flutter` no `pubspec.yaml` nem tabela `assinaturas`.

## Fase 5 — App: conta + assinatura

- [x] 5.1 Tela de login por e-mail — a mesma `ContaPage` do item 1.6
- [ ] 5.2 Tela da assinatura / plano
- [ ] 5.3 Gating da IA + validação offline (~30 dias)
- [ ] 5.4 Verificação: vencido pede assinatura; ativo libera

## Fase 6 — Segurança, LGPD e monitoramento — PARCIAL

- [x] 6.1 Auditoria de eventos (sem dado clínico) — `lib/services/lgpd/auditoria_service.dart:76,88`
  + `Log.auditoria`. **Ressalva:** `_registrarAuditoria` não é `await`ado
  (`lib/screens/sessao_form_page.dart:168-178`), então o evento pode não ser gravado — achado em
  aberto na auditoria de 06/10.
- [~] 6.2 Logs + **alertas** — os logs existem (`logger.dart` + Sentry em `main.dart:84,91`);
  **alertas não**.
- [ ] 6.3 Revisão LGPD dedicada
- [ ] 6.4 Verificação: revisar eventos e confirmar ausência de dado de paciente
