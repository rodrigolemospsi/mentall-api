# Síntese — 3 funções x concorrentes

**Data:** 19/10/2026 · Consolida `01`–`08`. **Escopo público**; ⚠️ onde a fonte é o probe REA, os
fornecedores de feature são **server-side** e **não** confirmáveis pelo cliente. A exceção é o
**PsicoManager** (`08`), cuja captura autenticada foi feita em 20/10/2026 (documentos e LGPD); os
fornecedores de WhatsApp/IA continuam server-side.

## 1. Financeiro / cobrança

| Concorrente | Recebimento de paciente | Fiscal | Fornecedor observável |
|---|---|---|---|
| **PsiLuz** | Pix gerado + **recorrência**; fatura em 1 clique | **Receita Saúde (gov.br)** integrada | não (server-side) |
| **Copilloto** | **Pix recorrente** automático | NFS-e | **Asaas** (gateway) + **NFe.io** (NFSe) |
| **PsicoPront** | ✗ (só registro) | **Carnê Leão** + Receita Saúde (CSV) | ✗ (é escrituração) |
| **ProntusCare** | ✗ (cobra a própria assinatura) | — | não |
| **Zenklub** | via marketplace | — | não |
| **PsicoManager** | Pix/boleto/cartão + **carteira própria** + repasses | **NFSe + Receita Saúde** | **Asaas** (Termos §5.5; server-side) + PsicoBank |
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
| **PsicoManager** | WhatsApp + SMS + e-mail + push | **créditos**, automação e **app do paciente** |
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
| **PsicoManager** | **LiveKit** (confirmado: `/api-room/livekit/token`) | **Google Meet** como alternativa + sala Neft legada |
| **MentAll** | ✗ | **inexistente** (planejado: LiveKit) |

**Nosso gap:** **feature ausente**. Opções de mercado: **Jitsi** (grátis, como a Copilloto),
**WebRTC próprio** (ProntusCare) ou **LiveKit** (PsicoManager — a mesma escolha do nosso plano);
alinhado a `docs/custos_teleconsulta.md`.

## 4. O que o MentAll tem e eles não
- **Local-first** (prontuário cifrado no aparelho) — **nenhum** concorrente.
- **Gate de revisão humana obrigatório** antes de salvar conteúdo de IA.
- **Tratamento de menores (art. 14)** de forma estruturada (previsto) — nenhum endereça.

## 5. Prioridade sugerida (produto)
1. **Teleconsulta** (Jitsi/LiveKit) — fecha a maior lacuna, custo controlado.
2. **Financeiro** — Pix (+recorrência) e, se possível, **Receita Saúde/NFS-e**. O PsicoManager mostra
   que o patamar de mercado inclui **carteira/conta digital** (PsicoBank) e **repasses** — bem acima
   de "gerar um Pix".
3. **Mensagens** — migrar para **canal oficial** + **portal do paciente** + automações.
4. **Fiscal** (Carnê Leão/Receita Saúde estilo PsicoPront) — se o público autônomo justificar.

## 6. Documentos e LGPD (PsicoManager, 20/10/2026)

| Item | PsicoManager | MentAll hoje |
|---|---|---|
| Tipos de documento | **16** (atestado, declaração, contrato, recibo, laudo, parecer, relatório, etc.) | 7 geradores PDF |
| Modelos prontos | **14** (incl. Res. CFP 06/2019) + upload + editor | sem biblioteca de modelos |
| Assinatura digital | módulo **pago** | ✗ |
| Documento no app do paciente | coluna **“Disponível no App do Paciente?”** | ✗ |
| Exportação | prontuários `.xls`, documentos `.zip`, anotações `.xls` (90 dias) | backup/export JSON |
| Política de Privacidade | **não publicada** (`/privacidade` 404) | `docs/lgpd/05` (v1.1) |
| Termos de Uso | v1, 20/07/2026, `/termos-de-uso` | `docs/lgpd/06` (v1.1) |
| Retenção | Termos (pagamento) × FAQ (5 anos) — **tensão** | regra explícita em `docs/lgpd/10` |

**Leitura:** em documentos, o PsicoManager está à frente em **biblioteca + assinatura + portal**;
em LGPD documental, o MentAll está à frente por ter **política publicada** e pacote versionado.
Detalhe e evidências em `08_psicomanager.md` §10–11.

> Nada aqui é decisão fechada: serve de insumo para um plano de produto. Qualquer aprofundamento em
> fornecedor (HAR/APK) depende de **aval jurídico** (`00_LEIA-ME.md` §2).
