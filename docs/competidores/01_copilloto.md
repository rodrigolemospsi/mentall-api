# Copilloto — funcionalidades

**Data do levantamento:** 14/10/2026 · **Fonte:** páginas públicas + probe local com REA.
**Perfil:** plataforma **web** (Next.js/Turbopack). Beta **R$ 99/mês** (depois R$ 139). CNPJ
66.620.366/0001-71 (Curitiba/PR). Política de Privacidade v2026-05-27. Demo público read-only
(`app.copilloto.com.br/demo`, 15 min). Fontes: `copilloto.com.br`, `/precos`, `/recursos`, `/privacidade`.

> **Natureza:** leitura de **fonte pública**. Nada foi logado, descompilado nem copiado.

## 1. Financeiro / cobrança

| Aspecto | Achado | Evidência |
|---|---|---|
| O que faz | **Cobrança Pix recorrente automática**; recibo/declaração/atestado em PDF; financeiro com "recebido, projeção do mês, valor em risco"; export CSV | home + `/precos` |
| Gateway de pagamento | **Asaas** | `/privacidade` §4 (subprocessadores) |
| Emissão fiscal | **NFe.io** (emissão automática de **NFSe**) | `/privacidade` §4 |
| Outros operadores | Brevo (e-mail), Google/**Gemini** (IA, "modo no-train, áudio deletado em 24h"), Apify | `/privacidade` §4 |
| Probe REA | O cliente (Next.js) **não** carrega SDK de pagamento; **zero domínio de terceiro** no bundle | `analyze-web-bundle` (demo) — ev `ev_84aa1d12…` |

**Leitura:** a cobrança e a emissão fiscal rodam **no servidor** (Next.js API routes), por isso não
aparecem no JavaScript do cliente. O padrão técnico é: **gateway de Pix (Asaas) + emissor de NFS-e
(NFe.io) + documentos PDF assinados**.

**MentAll hoje:** só **registro** (valor, status/forma de pagamento, saldo de pacote —
`SecaoFinanceiroWidget`/pacote). **Desvantagens:** sem **Pix**, sem **recorrência**, sem **NFS-e /
Receita Saúde**, sem gateway.

## 2. Mensagens profissional → paciente

| Aspecto | Achado | Evidência |
|---|---|---|
| O que faz | **WhatsApp automático**: lembrete 24h, **cobrança Pix**, onboarding, **check-in entre sessões**, **exit interview** — "sem você abrir o celular" | home + `/precos` |
| Canal | **WhatsApp** (provedor **não nomeado** publicamente) | home |
| Portal do paciente | Diário de humor, metas semanais, conquistas, journal privado, check-ins pós-sessão | home |
| Probe REA | O envio é **server-side** → não observável no cliente | `inspect-web-page` — ev `ev_1243533f…` |

**Leitura:** o diferencial não é só o lembrete — é **automação de relacionamento** (cobrança,
check-in, retenção) + **portal do paciente**.

**MentAll hoje:** lembrete por **`wuzapi` (WhatsApp não oficial)** via `compromisso.dart` /
`lembrete_service.py`; **sem portal/app do paciente**. **Desvantagens:** canal **não oficial**
(risco LGPD/ToS — ver `docs/lgpd/01` §4.9), sem portal, sem automação.

## 3. Teleconsulta

| Aspecto | Achado | Evidência |
|---|---|---|
| O que faz | **Teleconsulta integrada** — sala de vídeo por agendamento, com timer, notas (autosave) e contexto clínico; "encerra a sessão e gera prontuário em um clique" | home + `/precos` |
| SDK de vídeo | **Jitsi** ("código aberto, **sem custo** por minuto") | home (seção Teleconsulta) |
| Probe REA | No demo não há entrada de teleconsulta; o cliente não carrega SDK de vídeo (sala externa) | `analyze-web-bundle` |

**Leitura:** a escolha de **Jitsi** confirma o caminho "zero custo" — a mesma conclusão de
`docs/custos_teleconsulta.md` (alternativa ao LiveKit).

**MentAll hoje:** **não tem teleconsulta** (planejado: LiveKit). **Desvantagem:** feature ausente.

## 4. Achados do probe REA (14/10/2026)

- O app é **Next.js/Turbopack**, bundle **minificado**, **sem source maps** e **sem nenhum domínio de
  terceiro** no cliente (só `react.dev`/`nextjs.org`). O demo público carrega apenas o "shell".
- **Consequência metodológica:** para concorrentes **web com lógica no servidor**, a análise estática
  do cliente **não revela** os fornecedores — isso só aparece em **captura de rede durante o uso**
  (autenticado) ou em **APK**. Ambos fora do escopo atual (ver `00_LEIA-ME.md` §2).
- IDs de evidência REA: `ev_84aa1d128e1bb577f12a94d23f3a05fb4cfb916002793d6b78f0da497cea903c`
  (bundle) e `ev_1243533ff2b29009487b268def17262e3e584772a80fb7520dbd7950bac8bd28` (inspect).

## 5. Conclusões e implicações para o MentAll

- A Copilloto fecha as **três funções com peças baratas/abertas**: **Asaas** (Pix), **NFe.io**
  (fiscal), **Jitsi** (vídeo grátis) e **WhatsApp**. Nenhuma é tecnologia exótica.
- **Padrões a considerar** (sem copiar código): **Pix recorrente** + **Receita Saúde** (PsiLuz/
  PsicoPront fazem), **portal do paciente**, **teleconsulta** (Jitsi ou LiveKit) e **automação de
  mensagens** com **canal oficial**.
- Cruzar com `docs/lgpd/18_comparativo_concorrentes.md` (transparência) e
  `docs/custos_teleconsulta.md` (teleconsulta).

## 6. Próximos passos (fora do escopo atual)

- **Captura de rede autenticada** (HAR) do fluxo de cobrança/mensagens — exige aval jurídico.
- **APK** de concorrentes com app (ex.: Zenklub) via JADX — revelaria SDKs de vídeo/pagamento.
- Repetir para **PsiLuz**, **PsicoPront** e **ProntusCare** (web) e **Zenklub**.
