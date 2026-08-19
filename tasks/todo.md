# Tarefas — Venda recorrente + Painel de Controle

## Fase 1 — Contas de psicólogos

- [x] 1.1 Backend: tabela `usuarios` em `db.py` (id, email único, password_hash, nome, plano, status, criado_em, ultimo_acesso_em)
- [x] 1.2 Backend: `services/usuarios.py` (criar, obter por email/id, hash/verificar senha bcrypt, registrar acesso)
- [x] 1.3 Backend: schemas `RegistrarRequest/Response` + `LoginResponse` com dados do usuário (aditivo)
- [x] 1.4 Backend: `POST /auth/registrar` (valida email único, cria usuário)
- [x] 1.5 Backend: `POST /auth/login` autentica por email/senha (tabela) com fallback admin legado; JWT com `owner` = id do usuário
- [ ] 1.6 Frontend: login por e-mail/senha no app (mantendo PIN local)
- [ ] 1.7 Verificação: criar 2 contas e confirmar isolamento por `owner_id`

## Fase 2 — Telemetria (online/offline + uso)

- [ ] 2.1 Backend: tabelas `dispositivos` e `eventos`
- [ ] 2.2 Backend: `POST /telemetria/heartbeat` e `POST /telemetria/evento` (autenticado, sem dado clínico)
- [ ] 2.3 Frontend: `telemetria_service.dart` + device-id/versão + heartbeat no app
- [ ] 2.4 Verificação: app aberto aparece "online"; eventos chegam

## Fase 3 — Painel web de administração

- [ ] 3.1 Backend: endpoints `/admin/*` (role-gated, paginados)
- [ ] 3.2 Frontend: projeto admin (Flutter web) com login do dono
- [ ] 3.3 Painel: KPIs, lista de usuários (online/offline, plano, aparelho), uso por usuário
- [ ] 3.4 Verificação: dono loga e vê os números

## Fase 4 — Cobrança e assinatura

- [ ] 4.1 Integração RevenueCat (entitlements + 7 dias grátis)
- [ ] 4.2 Webhooks de assinatura → backend atualiza `assinaturas`
- [ ] 4.3 Stripe para pagamento no navegador (Pix/cartão)
- [ ] 4.4 Verificação: assinar na loja de teste muda o plano no painel

## Fase 5 — App: conta + assinatura

- [ ] 5.1 Tela de login por e-mail
- [ ] 5.2 Tela da assinatura / plano
- [ ] 5.3 Gating da IA + validação offline (~30 dias)
- [ ] 5.4 Verificação: vencido pede assinatura; ativo libera

## Fase 6 — Segurança, LGPD e monitoramento

- [ ] 6.1 Auditoria de eventos (sem dado clínico)
- [ ] 6.2 Logs estruturados + alertas
- [ ] 6.3 Revisão LGPD dedicada
- [ ] 6.4 Verificação: revisar eventos e confirmar ausência de dado de paciente
