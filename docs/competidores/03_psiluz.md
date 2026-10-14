# PsiLuz — funcionalidades

**Data:** 14/10/2026 · **Fonte:** páginas públicas (`psiluz.com.br`, `/lgpd`, `/privacy`) + probe REA.
**Perfil:** web/cloud (Next.js). "Servidores no Brasil". Controlador **AssemblySystems Tecnologia
Ltda**, CNPJ 30.696.028/0001-76. Copiloto de IA próprio: **Lia**. `app.psiluz.com.br` apresentou
**erro de certificado** em headless (probe feito no domínio público).

> Escopo público; nada logado/copiado. ⚠️ O bundle do cliente é **server-side**: fornecedores de
> feature **não** aparecem no JS.

## 1. Financeiro / cobrança
- Público: "**Fatura em 1 clique**, **Pix gerado sozinho**, aviso por WhatsApp e **cobrança recorrente**
  no piloto automático"; relatórios (entrou/atrasou/rendimento por horário); **Receita Saúde (gov.br)
  integrada** (emite recibos no portal).
- Fornecedor de pagamento: **não declarado** publicamente. Probe: **nenhum** domínio/ SDK de pagamento
  no cliente (server-side).

## 2. Mensagens profissional → paciente
- Público: lembretes automáticos por **WhatsApp + e-mail**, confirmação em 1 toque; **app do paciente**
  (documentos, confirmação, anamnese, registro de emoções) — "sem grupo de WhatsApp bagunçado".

## 3. Teleconsulta
- Público: teleconsulta integrada; app de gravação (desktop capta **mic + áudio da chamada**; celular
  para presencial). SDK/fornecedor de vídeo: **não declarado**; não aparece no cliente.

## 4. Achados do probe REA (14/10/2026) — superfície de API
O bundle público expôs **rotas de autenticação e integração** (útil para nos compararmos):
- Autenticação: `/auth/login`, `/auth/register`, `/auth/me`, `/auth/refresh`, `/auth/logout`.
- **MFA/2FA**: `/auth/verify-mfa`, `/auth/resend-mfa`, `/auth/toggle-two-factor`.
- **Google Calendar**: `/auth/google/calendar`, `/auth/google/calendar/sync-now`, `/status`, `/toggle`.
- Agendamento público: `/appointments/request`.
- Terceiro observado: **`servicodados.ibge.gov.br`** (provável autofill de endereço/CEP).
- Evidence: `docs/competidores` (bundle `psiluz-bundle.json`).

## 5. Implicações para o MentAll
- **Features que o PsiLuz tem e nós não**: **MFA/2FA**, integração **Google Calendar**, **app do
  paciente**, **Pix recorrente + Receita Saúde**, teleconsulta.
- Confirma o padrão de mercado do `docs/lgpd/18`: gate de revisão e local-first continuam nossos
  diferenciais.
