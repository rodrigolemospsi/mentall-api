# Checklist de publicação nas lojas de app (Google Play / App Store)

> **Status (30/08/2026):** pendências de segurança do pentest Strix de 30/08 corrigidas
> (IDORs, XSS, prompt injection, rate-limit XFF, webhook token, supply-chain, criptografia
> parcial, logs, inactivity). Restam **decisões do dono** e **pendências técnicas de loja**.
> APK mais recente: `MentAllPRO-v1.0.28.apk` (versão `1.0.28+29`).

## 1. Pendências de SEGURANÇA que bloqueiam publicação

Estas são as pendências que, se não resolvidas, podem gerar rejeição na revisão das lojas
(especialmente por envolver **dados sensíveis de saúde** — LGPD):

- [ ] **Fail-closed de criptografia (vuln-0013, decisão do dono):** hoje, se o dispositivo não
  tem bloqueio de tela/biometria (ex.: tablet clínico compartilhado), a chave fica só em memória
  e dados clínicos podem ser persistidos em **texto puro** silenciosamente.
  - Ação recomendada: tela de setup obrigatória que orienta ativar o bloqueio de tela do
    dispositivo **antes** de permitir o uso do prontuário (como o `AudioRelatoService` já faz
    para gravação), **e** um indicador visível de "proteção ativa/inativa" na Home e em
    Configurações > Segurança.
  - Parcial já aplicado em 30/08: `EncryptionService.gerarChave()` retorna `false` quando a
    chave não é durável e `main.dart` loga aviso de auditoria. Falta o bloqueio (fail-closed).
- [ ] **CSP `script-src 'unsafe-inline'`** no backend: remover `unsafe-inline` e usar
  hashes/nonces para os scripts inline de `contrato.html`/`anamnese.html` (recomendação do
  relatório Strix para harden futuro; também evita questionamentos de revisão de segurança).
- [ ] **`TRUSTED_PROXIES` no deploy:** definir os IPs do edge do Fly na env
  `TRUSTED_PROXIES` (`.env` + secrets do Fly). Sem isso, atrás do proxy o rate-limit por IP
  perde a distinção por cliente real. (O Dockerfile já roda uvicorn com `--proxy-headers`.)
- [ ] **Normalizar `render.yaml`/`start_backend.sh`:** adicionar `--proxy-headers` ao uvicorn
  nesses dois caminhos (hoje só o Dockerfile tem). Se não forem mais usados, remover para
  evitar deploy inseguro futuro.

## 2. Pendências TÉCNICAS de loja

- [ ] **Ícone do app:** regenerar ícone adaptativo (Android) e legado a partir da logo
  `logo_mentallpro_sem_nome` (pendência registrada desde 15/08). Verificar mipmaps e
  tamanhos exigidos (Play exige 512×512; App Store exige ícone sem alpha).
- [ ] **Telas de captura (screenshots):** gerar screenshots das telas principais (Home,
  Pacientes, Sessão com IA, Financeiro, Agenda) em resoluções exigidas por cada loja
  (Play: telefone ≥ 2 telas; App Store: 6.7", 6.5", 5.5").
- [ ] **Descrição e categorias:** texto de descrição do app (pt-BR e inglês), categoria
  (Saúde/Medicina — Medical no Play? requer declaração), palavras-chave.
- [ ] **Política de Privacidade e Termos de Uso:** publicar em URL pública (repositório
  `mentall-site`/Vercel ou GitHub Pages) e preencher no console da loja. **Destaque LGPD**:
  coleta/armazenamento de dados sensíveis de saúde, criptografia local, sem venda de dados.
- [ ] **Nota da LGPD:** declaração específica sobre dados sensíveis de saúde (art. 5º, II e
  11 da LGPD), finalidade (prontuário clínico), base legal (consentimento do titular).
- [ ] **CPI / Google Play Console:** conta de desenvolvedor (US$ 25) e conta App Store
  (US$ 99/ano). Verificar se há empresa/CNPJ ou usar conta individual.
- [ ] **Assinatura do release (keystore):** gerar/cuidar da keystore de produção do Android
  (Play App Signing recomendado) e do certificado iOS. **Guardar em local seguro** (senha +
  arquivo .keystore fora do repo).
- [ ] **Plano de assinatura / RevenueCat (Fase 1 do plano de negócio):** configurar produtos
  de assinatura no Play Billing e StoreKit, integrar RevenueCat, definir preço e teste de 7
  dias grátis (ver `tasks/plan.md`).
- [ ] **Pré-lançamento:** teste do APK release em aparelho real (física: login/conta, PIN,
  biometria, áudio, IA, backup/restore, WhatsApp), teste do fluxo de conta e-mail.

## 3. Pendências de INFRA (backend/deploy) relacionadas

- [ ] **Deploy das dependências novas:** rodar `uv pip install -r requirements.txt` no
  ambiente e redeploy do Fly (migração `fastapi`/`PyJWT`/`starlette`).
- [ ] **Rotacionar `WUZAPI_WEBHOOK_TOKEN`** após a mudança para `Authorization: Bearer` (o
  token antigo pode ter vazado em access logs).
- [ ] **Secrets do Fly:** adicionar `TRUSTED_PROXIES` e conferir os demais secrets
  (JWT_SECRET, chaves de IA, Turso, SMTP, wuzapi).
- [ ] **CI:** adicionar scan de dependências (pip-audit/osv-scanner/trivy) no GitHub Actions
  como gate de segurança (recomendação Strix medium-term).

## 4. Regressão de segurança antes do envio

- [ ] `flutter analyze` limpo (1 warning pré-existente em `tools/`).
- [ ] Suíte Flutter completa (atualmente **156/156**) e backend (**132/132**).
- [ ] Re-verificar com Strix scoped após qualquer mudança de segurança (ver skill
  `fix-security-vulnerabilities-with-strix`).
