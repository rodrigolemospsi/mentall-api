# Zenklub — funcionalidades

**Data:** 14/10/2026 · **Fonte:** `zenklub.com.br`, `/privacidade`, help center + probe REA.
**Perfil:** marketplaces de saúde mental (grupo **Conexa**). CNPJ 24.166.595/0001-18. Dois lados:
paciente (cliente) e **especialista** (`office.zenklub.com.br`). Teleconsulta é o **core**.

> Escopo público. App do especialista atrás de login; probe em `office.zenklub.com.br/login` e home.

## 1. Financeiro / cobrança
- No modelo **marketplace**, o pagamento do paciente passa pela plataforma (Zenklub/Conexa) e o
  **repasse** ao especialista é feito pela plataforma. É **cobrança da plataforma**, não faturamento do
  consultório. **Sem** gateway de Pix do profissional exposto publicamente.

## 2. Mensagens profissional → paciente
- **WhatsApp** (canais de atendimento) + plataforma/app; comunicação e lembretes. Provedor de
  mensageria **não declarado**.

## 3. Teleconsulta
- **Vídeo nativo** (é o produto principal). SDK/fornecedor de vídeo: **não declarado** e **não
  observável** no cliente (server-side).

## 4. Achados do probe REA (14/10/2026)
- `office.zenklub.com.br`: bundle maior (SPA), mas **sem** domínio de terceiro nem SDK de
  vídeo/pagamento no cliente; rota pública observada: `/appointments`.
- Home: nenhuma rota/SDK exposta.
- Confirma o padrão: **marketplace web server-side**.

## 5. Implicações para o MentAll
- O Zenklub é **marketplace** (liga paciente↔profissional) — modelo de negócio **diferente** do nosso
  (ferramenta do profissional). Pouco comparável em feature; útil como referência de **teleconsulta**
  e de **governança** (é o concorrente com o aviso de privacidade mais completo — ver
  `docs/lgpd/18_comparativo_concorrentes.md`).
- Reforça que **teleconsulta por SDK reconhecível no cliente** não é o caso deles; todos escondem o
  fornecedor no servidor.
