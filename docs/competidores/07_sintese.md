# Síntese — 3 funções x concorrentes

**Data:** 14/10/2026 · Consolida `01`–`06`. **Escopo público**; ⚠️ onde a fonte é o probe REA, os
fornecedores de feature são **server-side** e **não** confirmáveis pelo cliente.

## 1. Financeiro / cobrança

| Concorrente | Recebimento de paciente | Fiscal | Fornecedor observável |
|---|---|---|---|
| **PsiLuz** | Pix gerado + **recorrência**; fatura em 1 clique | **Receita Saúde (gov.br)** integrada | não (server-side) |
| **Copilloto** | **Pix recorrente** automático | NFS-e | **Asaas** (gateway) + **NFe.io** (NFSe) |
| **PsicoPront** | ✗ (só registro) | **Carnê Leão** + Receita Saúde (CSV) | ✗ (é escrituração) |
| **ProntusCare** | ✗ (cobra a própria assinatura) | — | não |
| **Zenklub** | via marketplace | — | não |
| **MentAll** | ✗ (registro manual + pacote) | ✗ | ✗ |

**Nosso gap:** não temos **recebimento** (Pix/recorrência) nem **fiscal** (NFS-e/Receita Saúde). É o
maior gap depois da teleconsulta. O caminho de mercado é **gateway de Pix + emissor de NFS-e/
Receita Saúde**.

## 2. Mensagens profissional → paciente

| Concorrente | Canal | Extras |
|---|---|---|
| **PsiLuz** | WhatsApp + e-mail | **app do paciente** (documentos, anamnese, humor) |
| **Copilloto** | WhatsApp automático | cobrança, check-in, exit interview, portal do paciente |
| **ProntusCare** | WhatsApp | link da sala + mensagem automática |
| **Zenklub** | WhatsApp + app | plataforma do paciente |
| **PsicoPront** | não anunciado | links de contrato/coleta |
| **MentAll** | **wuzapi (WhatsApp não oficial)** | **sem** portal/app do paciente |

**Nosso gap:** canal **não oficial** (risco LGPD/ToS), **sem** portal do paciente e **sem** automação
(check-in, cobrança, retenção).

## 3. Teleconsulta

| Concorrente | Vídeo | Observação |
|---|---|---|
| **Copilloto** | **Jitsi** (zero custo) | sala por agendamento + notas |
| **ProntusCare** | **sala própria (WebRTC)** | paciente **não instala nada** |
| **PsiLuz** | integrada (SDK não declarado) | app de gravação mic+chamada |
| **Zenklub** | nativa (core) | SDK não declarado |
| **PsicoPront** | ✗ | não oferece |
| **MentAll** | ✗ | **inexistente** (planejado: LiveKit) |

**Nosso gap:** **feature ausente**. Opções de mercado: **Jitsi** (grátis, como a Copilloto) ou
**WebRTC próprio** (ProntusCare); alinhado a `docs/custos_teleconsulta.md`.

## 4. O que o MentAll tem e eles não
- **Local-first** (prontuário cifrado no aparelho) — **nenhum** concorrente.
- **Gate de revisão humana obrigatório** antes de salvar conteúdo de IA.
- **Tratamento de menores (art. 14)** de forma estruturada (previsto) — nenhum endereça.

## 5. Prioridade sugerida (produto)
1. **Teleconsulta** (Jitsi/LiveKit) — fecha a maior lacuna, custo controlado.
2. **Financeiro** — Pix (+recorrência) e, se possível, **Receita Saúde/NFS-e**.
3. **Mensagens** — migrar para **canal oficial** + **portal do paciente** + automações.
4. **Fiscal** (Carnê Leão/Receita Saúde estilo PsicoPront) — se o público autônomo justificar.

> Nada aqui é decisão fechada: serve de insumo para um plano de produto. Qualquer aprofundamento em
> fornecedor (HAR/APK) depende de **aval jurídico** (`00_LEIA-ME.md` §2).
