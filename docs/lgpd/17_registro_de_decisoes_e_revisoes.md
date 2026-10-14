# 17 — Registro de decisões e revisões (documento vivo)

**Versão:** 1.1 · **Data:** 13/10/2026
**Natureza:** documento **vivo** de trabalho — rascunho em manutenção contínua. Registra **decisões
pendentes**, o **formato** das decisões já tomadas, o **histórico de revisões** dos documentos e o
**calendário e os gatilhos de revisão**. Não é parecer jurídico; ⚖️ marca o que depende de validação
de advogado.
**Regra:** decisão não registrada aqui **não aconteceu**. Se não está neste documento, o time ainda
está discutindo — e a discussão não protege ninguém.

**Base:** `01_diagnostico_lgpd.md`, `02_plano_de_acao.md`, `03_data_mapping_e_ropa.md`,
`04_papeis_e_contrato_controlador_operador.md`, `15_lojas_google_play_e_app_store.md`,
`16_checklist_de_conformidade.md`, `18_comparativo_concorrentes.md` e verificação direta no código do
app em 09/10/2026 (comparativo de mercado em 13/10/2026).

---

## 1. Decisões pendentes

Legenda de custo: ordem de grandeza de **esforço interno** (não inclui honorário jurídico).
"Consequência de não decidir" descreve o que **já está acontecendo** enquanto a decisão não sai.

| # | Decisão | Opções | Impacto LGPD | Custo estimado | Consequência de não decidir | Prazo sugerido |
|---|---|---|---|---|---|---|
| **D1** | **Manter ou remover o DeepSeek** da ordem de provedores de IA | (a) Remover do `IA_PROVIDER_ORDER`; (b) manter com consentimento específico e destacado por pessoa atendida + RIPD específico; (c) manter e apenas documentar | Dado sensível de saúde pode ser processado na **China**, sem decisão de adequação, hoje **sem decisão humana informada** (arts. 11, 33-36) — `ia_clinica.py:648`; `AGENTS.md:191` | (a) 2 h · (b) 3 dias + jurídico · (c) 1 h | A transferência continua ocorrendo silenciosamente a cada falha da OpenAI; é o item `P0.2` do plano e o "país" do Data Safety/App Privacy fica indefinido | **até 14/10/2026** (antes do próximo release) |
| **D2** | **Migrar o banco para região brasileira ou documentar a transferência** | (a) Migrar Turso/libSQL para região nacional ou provedor brasileiro; (b) manter nos EUA e formalizar mecanismo do art. 33 (cláusulas-padrão/garantias específicas); (c) manter e apenas declarar no ROPA | Contrato, anamnese, telefone e lembrete ficam em `aws-us-west-2` (EUA) **sem cifra**; o backend em `gru` cria falsa sensação de "dados no Brasil" (`backend/.env`; `fly.toml:2-3`; `db.py:180-213`) | (a) decisão 1 dia + migração (janela e testes) · (b) 1–2 dias + jurídico | Todo o restante da documentação pública fica condicionado; a resposta "onde ficam os dados" continua ambígua e a declaração de loja insegura | **até 23/10/2026** |
| **D3** | **Cifrar no servidor ou parar de persistir** o que o app pode manter local | (a) Cifrar os campos persistidos (contrato, anamnese, telefone/lembrete); (b) deixar de persistir no servidor o que o aparelho já guarda; (c) híbrido por tipo de dado | Dado de saúde hoje legível no banco: `json.dumps(dados)` sem cifra (`contrato_service.py:14-15`) — falha direta do art. 46 | (a) 2–3 dias · (b) 3–5 dias (mexe em fluxo de link público) · (c) 3 dias | O dado permanece legível em território estrangeiro a cada dia; nenhuma afirmação de "criptografia em repouso" pode ir para a loja | **até 30/10/2026** |
| **D4** | **WhatsApp oficial ou não oficial (wuzapi)** | (a) Migrar para API oficial (WhatsApp Business Platform) com contrato; (b) manter wuzapi com consentimento específico do titular, contrato com o provedor e região identificada; (c) desativar o recurso de lembrete | Mensagem revela que a pessoa faz psicoterapia ("lembrete da sua sessão com {profissional}") por gateway **sem contrato de tratamento**; sem consentimento específico (`compromisso.dart:159-171`; `lembrete_service.py:92-114`) — riscos de LGPD e de regras da Meta | (a) semanas + custo por mensagem · (b) 3 dias + jurídico · (c) 1 dia | Uso de terceiro sem contrato continua; a resposta "compartilhado com" no Data Safety fica sem destinatário definido; risco de bloqueio do número | **até 06/11/2026** |
| **D5** | **Manter a telemetria com opt-out ou desligá-la** | (a) Manter com toggle funcional, aviso no primeiro uso e teste de legítimo interesse documentado; (b) manter apenas telemetria agregada não vinculada a `device_id`; (c) desligar | Hoje é **sempre ativa**, com `device_id` persistente e sem opt-out (`telemetria_service.dart:16-40,72-90`) — art. 9º e 18, e exigência de "way to withdraw consent" na Apple 5.1.1(ii) | 4 h | Rastreamento pseudônimo contínuo sem escolha; a política de loja fica desalinhada do comportamento e o item `P1.14` nunca fecha | **até 23/10/2026** |
| **D6** | **PIN obrigatório ou senha do aparelho como fator de liberação da chave** | (a) PIN próprio **obrigatório** na primeira execução, com fallback explícito; (b) aceitar a credencial do aparelho como fator principal; (c) ambos, com PIN para exportar backup e apagar dados | Hoje o desbloqueio é **fail-open**: lockout de biometria, erro de hardware ou ausência de credencial carregam a chave **sem prompt** (`auth_service.dart:203-215,237-250`); PIN não existe em instalação nova (`encryption_service.dart:399-406`) | 1 dia | A promessa "Bloqueio por PIN/biometria" (`politica_privacidade_page.dart:60`) permanece falsa e o prontuário fica acessível a quem tem o aparelho desbloqueado | **até 20/10/2026** (item `P0.7`) |
| **D7** | **Como garantir que o áudio nunca exista em claro** | (a) Usar contêiner/stream cifrado desde o primeiro byte; (b) cifrar em blocos durante a gravação; (c) gravar em memória e só persistir após cifrar; e decidir **se o áudio é retido** após a transcrição | O `.m4a` é gravado em claro e cifrado **depois** do `stop()` (`audio_relato_service.dart:92` vs `:171`); queda, bateria ou kill deixam relato clínico persistido sem cifra e **não há varredura de órfãos** | (a)+(b) 2 dias · (c) 1–2 dias (limite de tamanho) | Persistência de dado sensível em claro, sem prazo e sem limpeza; contradiz qualquer texto de loja sobre proteção do áudio | **até 23/10/2026** (item `P0.8`) |
| **D8** | **Contagem de guarda do prontuário** (prazo de retenção e o que sobrevive ao pedido de eliminação) | (a) Guarda legal definida pelo conselho profissional/aplicação da norma setorial; (b) prazo contratual próprio declarado ao titular; (c) arquivamento indefinido com justificativa de exercício regular de direitos | Hoje a regra declarada é "arquivar, não excluir" (`politica_privacidade_page.dart:82-84`), que **colide com o art. 18, VI** se não houver justificativa de guarda; não há prazo em lugar nenhum | 1 dia + validação profissional e jurídica ⚖️ | Nem a política de retenção (`P1.6`) nem a resposta "retenção" no Data Safety/App Privacy podem ser preenchidas; o titular fica sem resposta sobre seus direitos | **até 13/11/2026** ⚖️ |
| **D9** | **Tratar os provedores de IA como "provedores de serviços" (com DPA) ou declará-los como terceiros com compartilhamento** | (a) Contratar DPA/termos de operador com Groq, OpenAI, DeepSeek, Google, Turso/AWS, Sentry, SMTP e wuzapi e declarar "não compartilhado"; (b) não contratar e declarar "compartilhado" no Data Safety e no App Privacy; (c) híbrido: contratar onde houver instrumento disponível e declarar o resto | O Play **não** exige declarar como compartilhamento a transferência a um "provedor de serviços" que processa em nome do desenvolvedor — mas isso pressupõe o contrato. Hoje **não há** lista contratada (`04_papeis_e_contrato_controlador_operador.md`, Partes C e D) | (a) 3–5 dias (contratação + jurídico) · (b) 4 h | A linha "compartilhado?" do formulário fica sem resposta defensável; declarar "não compartilhado" sem contrato é declaração incorreta de loja | **até 20/10/2026** (bloqueia `P1.10`) |
| **D10** | **Categoria de loja e enquadramento do app** | (a) Play "Medicina" + Apple "Medical", com declaração de apps de saúde como "Suporte à decisão clínica" e declaração de **não** dispositivo médico regulamentado; (b) Play "Produtividade" + Apple "Business" e texto conservador, mantendo a declaração de saúde obrigatória | Categoria de saúde atrai escrutínio maior (Apple 1.4.1) e exige política de privacidade detalhada sobre dados sensíveis (Play, Health Content and Services). Não muda a LGPD, mas **muda o que pode ser prometido no texto** | 4 h + revisão de textos | O texto de loja fica sem categoria e sem linguagem calibrada; risco de reprovação por alegação médica ou por declaração incompleta | **até 06/11/2026** |

### 1.1 Notas de decisão (onde as opções precisam de unpacking)

**D1 — por que a opção (a) é a recomendada como padrão operacional.** O circuito troca de provedor
**na mesma requisição** quando o anterior falha (`ia_clinica.py:761-781`). Isso significa que a
decisão "usar ou não a China" não é tomada por operação: ela é tomada pelo acaso da disponibilidade
do provedor. Remover o DeepSeek é reversível, custa 2 h e devolve previsibilidade. Manter exige
consentimento **por pessoa atendida** (não é consentimento do profissional) e RIPD específico — o que
é mais caro e mais frágil do que remover agora e reavaliar depois.

**D2 × D9 — ordem correta.** Não faz sentido escolher o instrumento contratual (D9) antes de saber
**onde** o dado vai ficar (D2). Assinar DPA listando "EUA" e depois migrar para o Brasil obriga a
reemitir todos os contratos. Sequência: D2 → D3 → D9 → D1 (o Anexo II do DPA precisa da lista final
de subprocessadores e países).

**D3 — decidir por tipo de dado, não por serviço.** Vale separar: (i) dado clínico de saúde
(contrato, anamnese, respostas) — candidato a **parar de persistir** no servidor quando o aparelho já
guarda, porque o link público pode resolver a coleta sem armazenar o conteúdo no backend; (ii) dado de
coordenação (telefone, mensagem de lembrete) — candidato a **cifrar**; (iii) conta e telemetria —
cifrar é suficiente. Essa separação deve ser registrada na decisão, não deixada para o implementador.

**D5 — o teste de legítimo interesse é pré-requisito, não enfeite.** O art. 7º, IX exige que o
legítimo interesse seja documentado com balanceamento. Sem esse teste escrito, a telemetria não tem
base legal demonstrável — e o item `P1.14` do plano não pode ser fechado apenas com o toggle.

**D6 — "senha do aparelho" não é a mesma coisa que PIN do app.** A opção (b) pode ser aceitável como
degradação, mas o comportamento de hoje não é isso: em falha do sensor, **nada** é exigido
(`auth_service.dart:203-215,237-250`). A decisão precisa dizer explicitamente qual é o comportamento
em cada caminho de erro (lockout, hardware indisponível, credencial removida pelo usuário).

**D8 — "não inventar prazo".** O prazo de guarda do prontuário psicológico **não foi confirmado** nas
fontes consultadas neste pacote. A decisão precisa nomear quem valida (conselho profissional e
advogado) e registrar a norma ou resolução aplicada. Enquanto isso, o campo de retenção na Política
de Privacidade e nos formulários de loja permanece **"NÃO DECLARAR AINDA — depende do item P1.6"**.
**Benchmark de mercado (13/10/2026):** a **Copilloto** adota 5 anos (Res. CFP nº 1/2009) e a
**Zenklub** adota 20 anos (Lei nº 13.787/2018 + Res. CFP nº 6/2019 + Res. CFM nº 1.821/2007) — o
mercado **não é unânime**, o que confirma que a decisão é jurídica (`18_comparativo_concorrentes.md`).

---

## 2. Formato de registro de decisão (ADR curto)

Toda decisão — inclusive as de escopo pequeno — entra no formato abaixo. Uma decisão por bloco.
Decisão **sem** os oito campos está incompleta.

```markdown
### [Dn] — <título curto e afirmativo da decisão>

- **Data:** dd/mm/aaaa
- **Situação:** Proposta | Em avaliação | Decidida | Em implementação | Implementada | Revisada | Substituída por Dn
- **Quem decidiu:** <nome e papel> (e quem foi consultado)
- **Contexto:** <o fato verificado que obriga a decidir, com `arquivo:linha` ou documento>
- **Alternativas consideradas:**
  1. <alternativa> — prós: <...>; contras: <...>
  2. <alternativa> — prós: <...>; contras: <...>
- **Justificativa:** <por que esta e não as outras; o que foi pesado>
- **Impacto LGPD:** <arts. afetados, transferência internacional, base legal, dados sensíveis, direitos do titular>
- **Consequência de não decidir:** <o que continua acontecendo>
- **Itens do plano afetados:** P0.x / P1.x / P2.x
- **Documentos a atualizar:** <ROPA, RIPD, DPA, política, Data Safety, App Privacy...>
- **Indicador de que a decisão está implementada:** <teste, evidência ou verificação concreta>
- **Revisão:** <data da próxima revisão obrigatória e o gatilho que a antecipa>
```

### 2.1 Exemplo preenchido (ilustrativo — **não** é uma decisão tomada)

> Este bloco serve apenas para mostrar o nível de detalhe esperado. Ele **não** substitui a decisão
> real, que deve ser escrita por quem decide.

```markdown
### [D1] — Remover o DeepSeek da ordem de provedores de IA

- **Data:** __/__/____
- **Situação:** Proposta
- **Quem decidiu:** __________ (decisão do responsável pelo produto, com validação jurídica ⚖️)
- **Contexto:** `backend/services/ia_clinica.py:648` aponta `https://api.deepseek.com/v1/chat/completions`;
  `AGENTS.md:191` registra a ordem de produção `openai,deepseek`; `ia_clinica.py:761-781` reenvia a
  **mesma requisição** ao provedor seguinte quando o anterior falha, levando o relato clínico
  integral e o nome da pessoa atendida (`:438-454`) para um provedor na China **sem decisão humana
  informada**.
- **Alternativas consideradas:**
  1. Remover do `IA_PROVIDER_ORDER` — prós: elimina a transferência para a China; reversível; 2 h;
     contras: reduz a resiliência quando a OpenAI falha (mitigável com segundo provedor em país com
     mecanismo de transferência definido).
  2. Manter com consentimento específico e destacado por pessoa atendida + RIPD — prós: preserva a
     resiliência; contras: 3 dias + jurídico, exige registro de consentimento (hoje inexistente,
     `pdf_arquitetura_lgpd_service.dart:241`) e não resolve o caso de a pessoa recusar.
- **Justificativa:** __________
- **Impacto LGPD:** arts. 11 (dado sensível), 33-36 (transferência internacional sem decisão de
  adequação para a China), 18, VII (informação sobre compartilhamento).
- **Consequência de não decidir:** a transferência continua ocorrendo de forma automática e a
  coluna "país" do Data Safety e do App Privacy permanece indefinida.
- **Itens do plano afetados:** P0.2, P0.1, P1.10.
- **Documentos a atualizar:** `03`, `04` (Anexo II), `15` §2.2 e §3.1, `16` (linhas X5 e T3).
- **Indicador de implementação:** `IA_PROVIDER_ORDER` sem `deepseek` em produção, com teste que falhe
  se o provedor reaparecer, e política publicada sem menção ao provedor.
- **Revisão:** revisar na revisão trimestral do ROPA ou imediatamente se entrar um novo provedor.
```

### 2.2 Índice de decisões registradas

| # | Título | Situação | Data da decisão | Quem decidiu | Bloco neste documento |
|---|---|---|---|---|---|
| — | *(nenhuma decisão registrada ainda)* | — | — | — | — |

> Enquanto este índice estiver vazio, **nenhuma** das decisões D1 a D10 foi tomada — e todo o
> documento 15 continua impedido de virar declaração de loja.

---

## 3. Histórico de revisões dos documentos

Tabela pronta para uso. **Regra:** toda alteração de conteúdo em qualquer documento deste pacote
gera uma linha, no mesmo dia. Alteração sem linha é alteração não autorizada.

| Data | Documento | Versão | Mudança | Autor | Aprovador |
|---|---|---|---|---|---|
| 13/10/2026 | `18_comparativo_concorrentes.md` | 1.0 | Criação — comparativo de LGPD com 5 concorrentes brasileiros (PsiLuz, Zenklub, Copilloto, ProntusCare, PsicoPront) | MentAll PRO (documentação) | — (rascunho) |
| 13/10/2026 | `05_politica_de_privacidade.md` | 1.1 | Padrão de mercado: controlador+CNPJ, prazo de resposta (15 dias), canal ANPD, biometria local, versionamento e aviso de cookies | MentAll PRO (documentação) | — (pendente revisão jurídica ⚖️) |
| 13/10/2026 | `06_termos_de_uso.md` | 1.1 | Nova cláusula de comunicações/opt-out; contato com razão social + CNPJ | MentAll PRO (documentação) | — (pendente revisão jurídica ⚖️) |
| 13/10/2026 | `10_politica_de_retencao_e_descarte.md` | 1.1 | Benchmark de mercado: retenção 5 × 20 anos; tratamento do áudio pelos concorrentes | MentAll PRO (documentação) | — (rascunho) |
| 13/10/2026 | `15_lojas_google_play_e_app_store.md` | 1.1 | Referências de mercado: subprocessadores nomeados, "IA sem treinamento", linguagem "em adequação" | MentAll PRO (documentação) | — (rascunho) |
| 13/10/2026 | `17_registro_de_decisoes_e_revisoes.md` | 1.1 | Registra o comparativo; corrige a linha de base do §3; acrescenta o benchmark de D8 | MentAll PRO (documentação) | — (rascunho) |
| 13/10/2026 | `00_LEIA-ME.md` | 1.1 | Índice passa a incluir o documento 18 | MentAll PRO (documentação) | — (rascunho) |

**Linha de base do pacote (fato, para rastreabilidade):**

| Data | Documento | Versão | Mudança | Autor | Aprovador |
|---|---|---|---|---|---|
| 09/10/2026 | `00_LEIA-ME.md` | 1.0 | Criação — índice e guia de uso | MentAll PRO (documentação) | — (rascunho) |
| 09/10/2026 | `_base_factual.md` | 1.0 | Criação — base factual verificada no código | MentAll PRO (documentação) | — (rascunho) |
| 09/10/2026 | `01_diagnostico_lgpd.md` | 1.0 | Criação — diagnóstico com achados e matriz de risco | MentAll PRO (documentação) | — (rascunho) |
| 09/10/2026 | `02_plano_de_acao.md` | 1.0 | Criação — plano P0/P1/P2/P3 | MentAll PRO (documentação) | — (rascunho) |
| 09/10/2026 | `03_data_mapping_e_ropa.md` | 1.0 | Criação — data mapping e ROPA (rascunho, 7 pendências) | MentAll PRO (documentação) | — (rascunho) |
| 09/10/2026 | `04_papeis_e_contrato_controlador_operador.md` | 1.0 | Criação — papéis e minuta de DPA | MentAll PRO (documentação) | — (pendente revisão jurídica ⚖️) |
| 09/10/2026 | `05_politica_de_privacidade.md` | 1.0 | Criação — Política de Privacidade (publicável) | MentAll PRO (documentação) | — (pendente revisão jurídica ⚖️) |
| 09/10/2026 | `06_termos_de_uso.md` | 1.0 | Criação — Termos de Uso (publicável) | MentAll PRO (documentação) | — (pendente revisão jurídica ⚖️) |
| 09/10/2026 | `07_aviso_de_privacidade_e_termo_de_consentimento.md` | 1.0 | Criação — material do psicólogo (aviso + consentimento) | MentAll PRO (documentação) | — (pendente revisão jurídica ⚖️) |
| 09/10/2026 | `08_ripd_relatorio_de_impacto.md` | 1.0 | Criação — RIPD (art. 38) | MentAll PRO (documentação) | — (pendente revisão jurídica ⚖️) |
| 09/10/2026 | `09_transferencia_internacional.md` | 1.0 | Criação — transferência internacional e salvaguardas | MentAll PRO (documentação) | — (pendente revisão jurídica ⚖️) |
| 09/10/2026 | `10_politica_de_retencao_e_descarte.md` | 1.0 | Criação — retenção e descarte | MentAll PRO (documentação) | — (pendente revisão jurídica ⚖️) |
| 09/10/2026 | `11_plano_de_resposta_a_incidentes.md` | 1.0 | Criação — plano de resposta a incidentes | MentAll PRO (documentação) | — (pendente revisão jurídica ⚖️) |
| 09/10/2026 | `12_politica_de_seguranca_da_informacao.md` | 1.0 | Criação — política de segurança da informação | MentAll PRO (documentação) | — (rascunho) |
| 09/10/2026 | `13_encarregado_dpo_e_canal_do_titular.md` | 1.0 | Criação — encarregado e canal do titular | MentAll PRO (documentação) | — (pendente revisão jurídica ⚖️) |
| 09/10/2026 | `14_guia_lgpd_do_psicologo.md` | 1.0 | Criação — guia prático de LGPD para o psicólogo | MentAll PRO (documentação) | — (rascunho) |
| 09/10/2026 | `15_lojas_google_play_e_app_store.md` | 1.0 | Criação — requisitos de loja, Data Safety e App Privacy | MentAll PRO (documentação) | — (rascunho) |
| 09/10/2026 | `16_checklist_de_conformidade.md` | 1.0 | Criação — checklist operacional com semáforo executivo | MentAll PRO (documentação) | — (rascunho) |
| 09/10/2026 | `17_registro_de_decisoes_e_revisoes.md` | 1.0 | Criação — decisões pendentes, ADR, calendário e gatilhos | MentAll PRO (documentação) | — (rascunho) |

> **Correção da linha de base (13/10/2026):** a versão 1.0 desta seção listava apenas os documentos do
> primeiro lote e citava `05` a `14` como "ainda não produzidos". **Eles já existem** e estão indexados
> no `00_LEIA-ME.md`; foram incorporados à linha de base acima. Nenhum documento do pacote (00 a 18)
> está pendente de criação.

**Campos obrigatórios da linha:** data, documento, versão, mudança, autor e aprovador. Mudança que
altera promessa pública (política, termos, textos de loja) exige **aprovador nomeado** — não pode
ficar em branco.

---

## 4. Calendário de revisões

| Periodicidade | O que revisar | Responsável sugerido | Evidência esperada |
|---|---|---|---|
| **Trimestral** | **ROPA** (`03`) — todas as operações, subprocessadores, países e bases legais | Encarregado (DPO) + produto | Versão nova com data de revisão e linha no §3 |
| **Trimestral** | **RIPD** (`08`) — riscos do tratamento com IA, medidas mitigadoras e o que mudou no produto | Encarregado (DPO) ⚖️ | RIPD revisado e aprovado |
| **Anual** | **Política de Privacidade e Termos** (`05`, `06`) — conteúdo contra o código, data de atualização, canais e DPO | Encarregado + jurídico ⚖️ | Texto publicado atualizado em URL |
| **Anual** | **Política de segurança da informação** (`12`) — controles, incidentes do período, acessos e logs | Responsável técnico | Documento revisado + evidência de execução dos controles |
| **Anual** | **Simulado de resposta a incidentes** (`11`) — cenário de vazamento com dado sensível | Encarregado + técnico | Ata do simulado, tempo de detecção e de resposta medidos |
| **Anual** | **Teste de restauração de backup** e verificação de que o backup está completo | Responsável técnico | Registro de execução com resultado (itens `P2.15`, `P3.3`) |
| **Anual** | **Revisão de acesso** aos ambientes (Fly, Turso, provedores de IA, SMTP, wuzapi, admin) | Responsável técnico | Lista de acessos conferida e reduzida |
| **Anual** | **Treinamento** de quem responde ao titular e a incidentes (`16` §11) | Encarregado | Registro de participação |
| **A cada novo subprocessador, país ou funcionalidade** | ROPA, RIPD, DPA (Anexo II), Política de Privacidade, Data Safety e App Privacy | Produto + Encarregado | Ver §5 (gatilhos) |
| **A cada alteração normativa da ANPD** ou de lei aplicável | Todo o pacote, começando pelo dossiê normativo | Encarregado + jurídico ⚖️ | Nota de impacto + plano de adequação (§6) |
| **Semestral** | Acompanhamento da regulamentação da ANPD sobre IA e dados sensíveis (`P3.5`) | Encarregado | Nota de atualização semestral |
| **Semestral** | **Comparativo de mercado** (`18_comparativo_concorrentes.md`) — políticas dos concorrentes e padrões de transparência | Produto + Encarregado | Versão datada com novas fontes |
| **A cada release relevante** | Conferência de que o comportamento do código não contradiz o texto publicado | Responsável técnico | Checklist `16` reavaliado nas linhas afetadas |

**Regra do calendário:** a revisão **não** é "olhar o documento". É refazer a verificação **contra o
código** e atualizar status no `16_checklist_de_conformidade.md`.

---

## 5. Gatilhos de revisão obrigatória

Qualquer um dos eventos abaixo **obriga** a uma revisão com registro neste documento — **não** se
espera a data do calendário.

| # | Gatilho | O que revisar imediatamente | Por quê |
|---|---|---|---|
| G1 | **Novo provedor de IA** (ou troca de modelo/versão) | `03` O5, `04` Anexo II, `08` RIPD, `05` política, `15` §2.2 e §3.1, `16` linhas T3/X6 | Muda quem recebe dado sensível e em que país; a Apple exige divulgação de compartilhamento **com IA de terceiros** (5.1.2(i)) |
| G2 | **Novo país** de tratamento ou armazenamento | `09`, `03` §3, `04` Anexo II e cláusula 7, `05`, `15` §2.2 e §3.1 | Transferência internacional exige mecanismo do art. 33 |
| G3 | **Nova categoria de dado** coletado (ex.: biometria enviada, imagem, localização, dado financeiro do profissional) | ROPA, RIPD, política, Data Safety, App Privacy, base legal | Muda a finalidade e pode mudar a base legal e a classificação de sensibilidade |
| G4 | **Mudança de base legal** de qualquer operação (ex.: sair de consentimento para legítimo interesse) | ROPA, RIPD, política, aviso ao titular, registro de consentimento | A base legal determina os direitos do titular e o que pode ser recusado |
| G5 | **Incidente relevante** (vazamento, acesso indevido, perda de dado de titular) | `11` (plano e registro), ROPA, RIPD, política se houver mudança de controle, comunicação à ANPD e ao titular | O aprendizado do incidente precisa virar controle; repetir o mesmo incidente é agravante |
| G6 | **Alteração normativa da ANPD** (resolução, guia, regulamentação de IA, transferência internacional) | Todo o pacote; começar pelo dossiê normativo e pelo RIPD | O ordenamento brasileiro de proteção de dados está em regulamentação ativa |
| G7 | **Mudança de preço/plano que colete mais dado** (ex.: assinatura com histórico de compras, CPF/CNPJ, nota fiscal, dados de cartão) | Data Safety, App Privacy, ROPA O12, política, `15` §1 R16 | Passa a existir "Informações financeiras"/"Histórico de compras" que hoje **não** são coletados; declarar de menos é declaração incorreta de loja |
| G8 | **Nova funcionalidade que envia dado para fora do aparelho** (ex.: sincronização em nuvem, integração com agenda, exportação automática) | ROPA, política, Data Safety, App Privacy, RIPD | O Play define "coleta" como transmissão para fora do dispositivo — muda o formulário |
| G9 | **Mudança de arquitetura de cifra ou de autenticação** (ex.: vincular a chave ao usuário, rekey, PIN obrigatório) | `12`, `16` §6, política, textos de loja | Textos públicos afirmam propriedades de segurança que precisam continuar verdadeiras |
| G10 | **Entrada de dado de criança ou adolescente por novo fluxo** | `16` §9, política, RIPD, Data Safety/App Privacy | Art. 14 exige cuidado reforçado e consentimento do responsável |
| G11 | **Novo subprocessador de infraestrutura** (hosting, banco, e-mail, observabilidade) | `04` Anexo II, `03` §3, política, ROPA | Muda a cadeia de operadores e o país |
| G12 | **Saída de pessoa-chave** (encarregado, responsável técnico) | `13`, `16` §1 e §11, `17` §4 | Atribuição de responsabilidade não pode ficar vaga |

---

## 6. O que fazer quando a norma mudar — fluxo em 4 passos

**Passo 1 — Detectar e registrar.**
Quem identificar a mudança (notícia, resolução, guia, decisão da ANPD, alteração de política de loja)
abre um registro imediato: data, fonte, link oficial, o que mudou e quais operações do ROPA são
afetadas. **Nada de alterar documento no mesmo dia** — primeiro registra-se o fato.
*Saída:* entrada no histórico do §3 com situação "em avaliação".

**Passo 2 — Avaliar impacto contra o código, não contra a memória.**
Percorrer `03_data_mapping_e_ropa.md` respondendo: alguma operação muda de base legal? Algum dado
passa a ser sensível de outro modo? Alguma transferência internacional muda de status? Algum direito
do titular ganha prazo novo? Cada resposta precisa de evidência (`arquivo:linha`) ou da marca
**"NÃO CONFIRMADO"**.
*Saída:* nota de impacto com a lista de itens afetados e o esforço estimado.

**Passo 3 — Decidir e registrar no formato ADR (§2).**
Escrever a decisão com contexto, alternativas, justificativa, impacto, itens do plano afetados,
documentos a atualizar, indicador de implementação e data de revisão. Se a decisão depende de
advogado, marcar ⚖️ e **não publicar** texto público até a validação.
*Saída:* bloco de decisão no §2 + entrada no índice §2.2.

**Passo 4 — Implementar, verificar e comunicar.**
(a) Implementar o que a decisão exige; (b) verificar com o indicador definido (teste, evidência,
conferência no código); (c) atualizar **todos** os documentos da lista, incluindo os textos de loja em
`15`; (d) se a mudança afeta direito do titular ou o que é informado, comunicar no canal do
encarregado e, se for o caso, aos profissionais clientes e às pessoas atendidas; (e) registrar a
conclusão no histórico §3 com aprovador nomeado.
*Saída:* documento atualizado, linha no histórico e evidência arquivada.

> **Regra final:** se a mudança normativa tornar **falsa** alguma frase já publicada na Política de
> Privacidade, nos Termos ou na loja, a correção do texto tem prioridade sobre qualquer outra
> atividade — texto falso publicado é o risco mais caro e o mais fácil de evitar.

---

## 7. Encerramento deste ciclo de documentação

- Este documento **não fecha** enquanto o índice §2.2 estiver vazio: nenhuma das decisões D1 a D10
  foi tomada.
- Enquanto D1 a D10 estiverem pendentes, o documento `15_lojas_google_play_e_app_store.md`
  **permanece impedido** de virar declaração de loja, e as linhas correspondentes do
  `16_checklist_de_conformidade.md` permanecem **"Não atende"**.
- O item `P3.1` do plano de ação ("RIPD e ROPA revisados a cada mudança relevante") **é este
  documento**: a revisão trimestral do §4 é a evidência de que ele foi cumprido.
- O comparativo de mercado (`18_comparativo_concorrentes.md`) é **referência viva** para a redação dos
  documentos públicos (05, 06, 10, 15) e entra na revisão semestral do §4 — concorrentes mudam de
  política com frequência.
- A investigação de **funcionalidades** dos concorrentes (financeiro, mensagens, teleconsulta), feita
  com a ferramenta **REA** e limitada a fontes **públicas**, vive em `docs/competidores/` (fora deste
  pacote LGPD). Escopo e limites em `docs/competidores/00_LEIA-ME.md`.
