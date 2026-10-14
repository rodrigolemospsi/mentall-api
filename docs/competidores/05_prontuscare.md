# ProntusCare — funcionalidades

**Data:** 14/10/2026 · **Fonte:** `prontuscare.com.br`, `/privacidade.html` + probe REA.
**Perfil:** web. Planos **R$ 39,90 / 79,90 / 119,90**. Foco em **teleconsulta própria + prontuário
ético (CFP 06/2019) + laudos**.

> Escopo público. App (`app.prontuscare.com.br`) atrás de login; probe no marketing e login.

## 1. Financeiro / cobrança
- Público: **"emissão de faturas e controle de assinatura"** — isso é a **cobrança da própria
  assinatura** do psicólogo, **não** cobrança de pacientes. **Sem** Pix/recorrência voltada ao
  paciente no material.

## 2. Mensagens profissional → paciente
- Público: **envio do link da sala por WhatsApp** + **mensagem automática**; portal do paciente para
  **assinar contratos/termos LGPD** (rubrica na tela com trilha de IP/data/hora).

## 3. Teleconsulta
- Público: **sala virtual própria** (WebRTC) — "o paciente **não instala nada**", abre no navegador,
  com split-view (vídeo + prontuário na mesma tela). SDK/fornecedor: **não declarado**.

## 4. Achados do probe REA (14/10/2026)
- Marketing e app: bundle pequeno, **sem domínio de terceiro** e **sem SDK de vídeo/pagamento** no
  cliente. Único endpoint exposto: `/api/support/config`.
- Indica stack **server-side** e teleconsulta provavelmente **própria/embarcada** (não de terceiro
  reconhecível no cliente).

## 5. Implicações para o MentAll
- **Teleconsulta "sem app para o paciente"** (WebRTC no navegador) é o padrão de entrada — barato e
  aderente ao nosso plano (`docs/custos_teleconsulta.md`: LiveKit).
- **Assinatura de contrato/termo na tela com trilha (IP/data/hora)** é um recurso de **consentimento
  do titular** que conversa direto com os P1.5/P1.9 do pacote LGPD.
