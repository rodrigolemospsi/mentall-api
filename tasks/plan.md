# Plano — Venda recorrente do MentAll + Painel de Controle

## Objetivo

Transformar o MentAll de app individual em uma **plataforma por assinatura**: cada
psicólogo tem conta própria, paga mensalmente (7 dias grátis de teste) e o dono tem um
**painel web** para acompanhar o negócio em tempo real.

## Decisões confirmadas

| Tema | Decisão |
|---|---|
| Modelo | Assinatura mensal para outros psicólogos |
| Teste | 7 dias grátis, depois cobra |
| Cobrança | Google Play (Android) + App Store (iPhone) + Pix/cartão no navegador |
| Online/offline | Online = app aberto agora; Offline = tem app mas não usa agora |
| Tipos de acesso | Plano (grátis/pago) + aparelho (Android/iPhone/navegador) |
| Painel | Site no computador, só do dono, com senha |

## Regra de ouro (LGPD)

O prontuário dos pacientes continua trancado **no celular de cada psicólogo**. A nuvem
só recebe **números** (contagens de eventos), **nunca** nome de paciente nem conteúdo
clínico. O painel do dono não enxerga dado clínico.

## Arquitetura-alvo

- **Backend FastAPI** (Fly.io + Turso): contas de psicólogos, telemetria (heartbeat +
  eventos), assinaturas e endpoints de admin.
- **Cobrança**: RevenueCat (playa as lojas) + Stripe (Pix/cartão no navegador).
- **App Flutter**: login por e-mail, tela de assinatura, gating da IA, heartbeat e eventos.
- **Painel web**: site só do dono (Flutter web), com login e KPIs.

## Fases

1. Contas de psicólogos (cadastro/login, dados separados por usuário).
2. Telemetria (heartbeat online/offline + eventos de uso, sem dado clínico).
3. Painel web de administração (KPIs, listas de usuários/planos/aparelhos).
4. Cobrança e assinatura (RevenueCat + lojas + Stripe; backend sabe o plano ativo).
5. App: login por e-mail, tela de assinatura, gating de IA com tolerância offline.
6. Segurança, LGPD e monitoramento (logs estruturados, alertas, auditoria).

## Critérios de sucesso

- Psicólogo novo cria conta, usa 7 dias grátis e assina pela loja.
- Dono vê no painel: total de psicólogos, online agora, plano/aparelho de cada um, receita do mês.
- Psicólogo que cancela deixa de usar IA, mas não perde dados locais.
- Nenhum dado de paciente aparece na nuvem nem no painel.

## Riscos

| Risco | Mitigação |
|---|---|
| Vazar dado de paciente na telemetria | Só contagens; revisão dedicada na Fase 6 |
| Uso offline sem pagar | Validação da assinatura a cada ~30 dias; bloqueio da IA |
| Perda do dado atual do dono | Migração com backup antes de ligar as contas |
| Cobrança dupla/falha | RevenueCat trata idempotência/retry |
