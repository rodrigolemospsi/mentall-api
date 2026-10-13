# Aviso de Privacidade do Consultório e Termo de Consentimento

**Versão:** 1.0 · **Data:** 09/10/2026
**Natureza:** rascunho de trabalho para uso do psicólogo com a pessoa atendida. **Não é parecer jurídico.**
**Produto ao qual se refere:** MentAll PRO — cliente Flutter `1.0.49` + backend FastAPI (`backend/main.py`)
**Base factual:** `_base_factual.md`, `01_diagnostico_lgpd.md`, `03_data_mapping_e_ropa.md`, `04_papeis_e_contrato_controlador_operador.md`

> ⚠️ **Leia antes de usar.** Este documento descreve o comportamento **verificado** do MentAll PRO em
> 09/10/2026 — inclusive o que ainda **não está adequado**. Ele não afirma que o software é
> "LGPD compliant", "certificado" ou "100% seguro": o MentAll PRO está **em adequação**
> (`01_diagnostico_lgpd.md`, matriz de risco). Todos os pontos marcados com ⚖️ dependem de
> validação por advogado antes de virarem compromisso público.

> 🖨️ **Como usar.** As seções 1 a 5 são o **Aviso de Privacidade**, para entregar em papel ou ler em
> voz alta. As seções 6 a 11 são o **Termo de Consentimento**, que precisa de assinatura. Imprima o
> bloco de consentimento **duas vezes** (uma via para a pessoa atendida, uma para o prontuário).

---

## 0. Nota de uso para o psicólogo (não entregar à pessoa atendida)

1. O **psicólogo é o controlador** dos dados clínicos; o **MentAll PRO é operador** desses dados
   (declarado pelo próprio app em `lib/screens/lgpd/politica_privacidade_page.dart:76-77`). O MentAll é
   controlador apenas da conta do profissional e da telemetria.
2. A pessoa atendida **não é usuária do app** e não tem login. Por isso, **todo o exercício de
   direitos acontece por meio do psicólogo**, em papel, e-mail ou telefone.
3. O app **não possui campo de responsável legal** (`01_diagnostico_lgpd.md` §4.10; busca por
   `responsavel_legal` em `lib/models/` e `lib/services/` não retorna resultado). O termo para
   criança/adolescente (seção 7) existe justamente para funcionar **em papel**.
4. O app também **não tem** registro de consentimento do titular, tela de solicitação do titular nem
   exclusão de conta (`01_diagnostico_lgpd.md` §4.14 e §4.4). Portanto o registro de consentimento é
   **este documento assinado**, guardado no prontuário.
5. Quando o app melhorar, este termo deve ser revisado — não o contrário.

---

# PARTE I — AVISO DE PRIVACIDADE DO CONSULTÓRIO

> Texto em linguagem simples, para leitura em conjunto no primeiro atendimento (1 a 2 páginas).

## 1. Quem cuida dos seus dados

Quem decide **por que** e **para quê** os seus dados são usados neste consultório é o(a) psicólogo(a)
que assina este documento — ele(a) é o **controlador** dos seus dados de saúde.

Para organizar o prontuário, ele(a) usa um software chamado **MentAll PRO**. Nesse uso, o MentAll PRO
é **operador**: ele guarda e processa os dados **seguindo as instruções do(a) psicólogo(a)**, e não pode
usar o seu conteúdo clínico para finalidades próprias.

O MentAll PRO **está em adequação** à Lei Geral de Proteção de Dados (LGPD). Ele **não** é
"certificado" nem pode ser descrito como "100% seguro" — como qualquer sistema, tem riscos e medidas
de proteção conhecidas.

## 2. Quais dados são tratados e para quê

| Dado | Para quê |
|---|---|
| Nome, data de nascimento, contato, e-mail | Identificar você no prontuário e conseguir falar com você |
| Relato de sessão, apontamentos, hipóteses e plano | Documentar o atendimento — é o prontuário psicológico |
| Áudio do relato pós-sessão (**gravado pelo profissional, não é a gravação da sessão**) | Permitir que o(a) psicólogo(a) dite o relato em vez de digitar |
| Transcrição e resumo organizado por inteligência artificial | Apoio documental, sempre revisado pelo(a) psicólogo(a) antes de entrar no prontuário |
| Contrato terapêutico e respostas do formulário de anamnese | Formalizar o acordo e conhecer seu histórico inicial |
| Telefone, nome e data/hora da sessão | Enviar lembrete de sessão, se você autorizar |
| Data de nascimento, tipo de atendimento, valores e forma de pagamento | Controle administrativo do consultório |

Os dados de saúde (relato, áudio, transcrição, resumo e apontamentos) são **dados pessoais sensíveis**
e recebem proteção reforçada (LGPD, art. 11).

## 3. Com quem os dados são compartilhados — e para onde vão

Este é o ponto mais importante deste aviso. **Parte do conteúdo clínico sai do aparelho do(a)
psicólogo(a) e é processada por empresas no exterior.** Isso acontece porque o MentAll PRO usa
serviços de transcrição e de inteligência artificial.

**a) O áudio do relato vai para um serviço de transcrição nos Estados Unidos.**
Quando o(a) psicólogo(a) grava o relato em áudio, esse áudio é enviado pela internet, em base64, para
o serviço **Groq, nos Estados Unidos**, para virar texto
(`backend/services/transcricao.py:13-20,64-65,85-88`; provedor padrão `TRANSCRICAO_PROVIDER=groq`,
com alternativa **OpenAI**, também nos EUA — `transcricao.py:17-20,96-99`).

**b) O texto clínico pode ser processado por inteligência artificial nos Estados Unidos e, se houver
falha, também na China.**
Para gerar a síntese, o MentAll PRO envia ao provedor de IA **o nome da pessoa atendida e o relato
clínico integral** (`backend/services/ia_clinica.py:438-454`; chamada com dado real em
`backend/main.py:890-893`). O primeiro provedor é a **OpenAI (EUA)**. Se ele falhar, **a mesma
requisição é reenviada automaticamente ao provedor seguinte — a DeepSeek, na China**
(`ia_clinica.py:635-690`, endpoint literal na `:648`; a ordem padrão é `openai,deepseek` em
`AGENTS.md:191`; o reenvio automático está em `ia_clinica.py:761-781`). Ou seja: **na mesma operação,
o dado pode ser transferido para dois países diferentes, sem nova decisão humana.**
O Brasil **não possui decisão de adequação** para os EUA nem para a China; a transferência depende de
um dos mecanismos do art. 33 da LGPD. ⚖️

**c) O contrato terapêutico e as respostas da anamnese ficam gravados em um banco de dados nos
Estados Unidos, sem cifra.**
O banco de produção é o Turso, em `aws-us-west-2.turso.io` (**Oregon, EUA**), enquanto o servidor da
aplicação está em São Paulo (`backend/.env`; `fly.toml:2-3`). Nesse banco, contrato, anamnese,
telefone e mensagem de lembrete são gravados **sem cifra no servidor**
(`backend/services/db.py:180-213`; `backend/services/contrato_service.py:14-15`). Isso significa que
"seus dados ficam só no aparelho do psicólogo" **não é verdade para esses itens** — a Política de
Privacidade atual do app afirma isso (`politica_privacidade_page.dart:57`) e está incorreta
(`01_diagnostico_lgpd.md` §4.3). ⚖️

**d) Lembrete de sessão por WhatsApp (somente se você autorizar).**
O envio é feito por um **gateway não oficial do WhatsApp** (wuzapi), e a mensagem padrão contém o seu
nome e o nome do(a) profissional — ou seja, revela que você faz psicoterapia
(`lib/models/compromisso.dart:159-171`; `backend/services/lembrete_service.py:92-114`). Onde esse
gateway está hospedado está **[A CONFIRMAR]** (`03_data_mapping_e_ropa.md`, O9). ⚖️

**e) Outros destinatários técnicos.** Verificação de registro profissional no Conselho Federal de
Psicologia (no Brasil); e-mails de verificação e recuperação de senha; hospedagem do servidor; e, se
você ou o(a) psicólogo(a) exportarem um PDF, **o destino do arquivo passa a estar fora do controle do
MentAll PRO** (`01_diagnostico_lgpd.md` §4.14, C7).

⚠️ **Aviso importante sobre o site e os textos do app:** a Política de Privacidade que aparece dentro
do aplicativo está desatualizada ("Última atualização: Julho de 2026") e **omite a Groq e a DeepSeek**
(`politica_privacidade_page.dart:71-73,122`; `01_diagnostico_lgpd.md` §4.3). **Este aviso em papel é a
informação correta** neste momento.

## 4. Por quanto tempo os dados ficam guardados

- **Prontuário psicológico:** a guarda é dever do(a) psicólogo(a) e o período mínimo é de **5 (cinco)
  anos**, podendo ser ampliado por lei, por determinação judicial ou quando for necessário manter por
  mais tempo (Resolução CFP nº 001/2009, art. 4º, §1º — [texto oficial](http://site.cfp.org.br/wp-content/uploads/2009/04/resolucao2009_01.pdf);
  confirmado também na [FAQ do CFP](https://site.cfp.org.br/faq/como-devo-fazer-guarda-e-descarte-de-documentos-utilizados-no-atendimento/),
  que cita a Resolução CFP nº 007/2003). ⚖️
- **Direito de acesso ao prontuário:** é garantido a você **ou ao seu representante legal** o acesso
  integral às informações registradas (Resolução CFP nº 001/2009, art. 5º, II).
- **Áudio do relato:** o app hoje **não define** um prazo de retenção, não pergunta se você quer manter
  o áudio e não garante o apagamento após a transcrição (a exclusão é disparada sem espera —
  `AGENTS.md`, auditoria de degradação silenciosa; `01_diagnostico_lgpd.md` §4.5). **NÃO CONFIRMADO —
  validar com advogado** o prazo a declarar. ⚖️
- **Contrato e anamnese no servidor:** hoje **nunca são apagados** — o servidor não tem ciclo de vida
  de dado, expurgo automático nem endpoint de exclusão (`01_diagnostico_lgpd.md` §4.13). **Prazo:
  NÃO CONFIRMADO — validar com advogado.** ⚖️

## 5. Seus direitos e como pedir

Você pode, a qualquer momento, pedir (LGPD, art. 18):

1. **Confirmação** de que tratamos seus dados e **acesso** a eles;
2. **Correção** de dados incompletos, inexatos ou desatualizados;
3. **Anonimização, bloqueio ou eliminação** de dados desnecessários, excessivos ou tratados em
   desconformidade com a lei;
4. **Portabilidade** a outro fornecedor, mediante requisição expressa;
5. **Informação** sobre com quem os dados foram compartilhados;
6. **Informação** sobre a possibilidade de não consentir e sobre as consequências disso;
7. **Revogação do consentimento** (ver seção 9).

**Como pedir:** fale diretamente com o(a) psicólogo(a) que assina este documento — por e-mail, telefone
ou presencialmente — e diga o que você quer. Não é preciso justificar o pedido.

**O que acontece depois:**

- **Acesso ou confirmação:** em formato simplificado, **imediatamente**; ou por declaração clara e
  completa em até **15 (quinze) dias** contados do seu pedido (LGPD, art. 19, I e II).
- **Demais pedidos:** a lei manda atender **de imediato**; não sendo possível, o controlador responde
  no menor prazo possível, indicando as providências adotadas (LGPD, art. 18, §4º) ⚖️.
- Se você não concordar com a resposta, pode peticionar à **ANPD** (Autoridade Nacional de Proteção de
  Dados) — [gov.br/anpd](https://www.gov.br/anpd/pt-br) (LGPD, art. 18, §1º).

**Uma observação honesta sobre eliminação:** parte do prontuário **não pode ser apagada a pedido**,
porque a lei e as normas do Conselho de Psicologia obrigam o profissional a guardá-lo por no mínimo
5 anos (ver seções 4 e 9). Explicamos isso em detalhe no item 9 para você saber exatamente o que é
possível e o que não é. ⚖️

**Canal do encarregado (DPO):** hoje o MentAll PRO **não possui encarregado nomeado nem canal
publicado** — a política do app ainda diz apenas "entre em contato com o desenvolvedor do MentAll PRO"
(`politica_privacidade_page.dart:119-122`; `01_diagnostico_lgpd.md` §4.6) ⚖️. Enquanto isso não for
corrigido, **todo pedido deve ser dirigido ao(à) psicólogo(a)** — que é, de todo modo, quem decide
sobre o conteúdo clínico.

---

# PARTE II — TERMO DE CONSENTIMENTO

> Este termo tem **dois caminhos**: escolha **um** deles. O caminho A é para pessoa adulta capaz; o
> caminho B é para criança ou adolescente, com bloco de responsável legal.

## 6. Caminho A — Pessoa adulta capaz

Eu, **______________________________________________________________________**,
portador(a) do documento nº ______________________, declaro que:

- li (ou ouvi a leitura de) o **Aviso de Privacidade do Consultório** nas seções 1 a 5 deste
  documento, e ele me foi explicado em linguagem que eu entendi;
- compreendi, em especial, que **o áudio do relato é enviado a um serviço de transcrição nos Estados
  Unidos** e que **o texto clínico pode ser processado por inteligência artificial nos Estados Unidos
  e, em caso de falha do primeiro provedor, também na China**;
- compreendi que **fui informado(a) da possibilidade de não consentir** e das consequências da
  negativa (LGPD, art. 18, VIII) — em resumo: sem áudio e sem uso de IA, o registro clínico continua
  sendo feito, apenas por digitação do(a) psicólogo(a);
- compreendi que a IA **não emite diagnóstico e não decide nada**: ela apenas organiza o relato, e
  **todo conteúdo passa por revisão do(a) psicólogo(a)** antes de entrar no prontuário
  (`termos_uso_page.dart:44-56`);
- autorizo o tratamento dos meus dados nos limites e nas finalidades descritas no aviso.

Escolhi as opções marcadas no **bloco de consentimentos granulares (seção 8)**.

## 7. Caminho B — Criança ou adolescente (com bloco de responsável legal)

> ⚠️ **Lacuna conhecida e registrada:** o MentAll PRO **não possui campo de responsável legal** nem
> consentimento específico para menores (`01_diagnostico_lgpd.md` §4.10; busca por `responsavel_legal`
> em `lib/models/` e `lib/services/` não retorna resultado). Por isso **este termo é o único registro
> de consentimento para menores** e **precisa ser preenchido em papel e arquivado no prontuário**.

### 7.1 Pessoa atendida (criança ou adolescente)

Nome: **______________________________________________________________________**
Data de nascimento: ____/____/________ · Idade: ______

A pessoa atendida participou da conversa sobre este documento **na medida da sua idade e do seu
entendimento**, em linguagem adequada (LGPD, art. 14, §6º). Sua opinião foi registrada abaixo:

- [ ] A pessoa atendida foi ouvida e concorda em participar do atendimento.
- [ ] A pessoa atendida foi ouvida e manifestou desconforto ou dúvida — registrado no prontuário.
- [ ] Não foi possível colher a manifestação (motivo): ______________________________________

### 7.2 Responsável legal

Eu, **______________________________________________________________________**,
portador(a) do documento nº ______________________, **______________________** (parentesco ou
qualidade: mãe, pai, tutor(a), guardião(ã)), responsável legal por
**____________________________________________**, declaro que:

- li o **Aviso de Privacidade do Consultório** (seções 1 a 5) e ele me foi explicado;
- compreendi que **o áudio do relato é enviado a um serviço de transcrição nos Estados Unidos** e que
  **o texto clínico pode ser processado por inteligência artificial nos Estados Unidos e, em caso de
  falha, também na China**;
- **consinto, de forma específica e em destaque**, com o tratamento dos dados pessoais da criança ou
  adolescente sob minha responsabilidade, para as finalidades descritas no aviso (LGPD, art. 14, §1º)
  ⚖️;
- compreendi que posso **revogar** este consentimento a qualquer momento e que isso não apaga o
  prontuário já constituído (seção 9) ⚖️;
- compreendi que o MentAll PRO **está em adequação** à LGPD e que **não** é possível afirmar que o
  sistema é "100% seguro" ou "certificado".

Escolhi as opções marcadas no **bloco de consentimentos granulares (seção 8)**.

---

## 8. Consentimentos granulares (cada um é separado, e cada um é opcional)

> **Instrução:** marque **SIM** ou **NÃO** em cada linha. **NÃO** em qualquer item **não impede o
> atendimento**. Os itens 8.2 e 8.3 têm relação direta com transferência internacional.

| # | Consentimento | O que muda se for NÃO | SIM | NÃO |
|---|---|---|---|---|
| 8.1 | **Registro clínico em prontuário.** Autorizo o registro do atendimento em prontuário psicológico (relato, evolução, apontamentos). | ⚠️ O prontuário é **obrigatório por norma profissional** e não depende de consentimento para existir (Resolução CFP nº 001/2009, art. 1º), mas o registro é feito da forma menos exposta possível. ⚖️ | ☐ | ☐ |
| 8.2 | **Gravação de áudio do relato e transcrição por serviço nos Estados Unidos.** Autorizo a gravação do relato pós-sessão **feito pelo(a) psicólogo(a)** e seu envio à **Groq (EUA)** — ou, alternativamente, à **OpenAI (EUA)** — para transcrição. | O(A) psicólogo(a) **digita o relato**. Nenhum áudio é gravado nem enviado. A qualidade do prontuário não é prejudicada. | ☐ | ☐ |
| 8.3 | **Uso de inteligência artificial para organizar o relato.** Autorizo o envio do relato (com o meu nome) à **OpenAI (EUA)** e, **em caso de falha técnica, à DeepSeek (China)**, que processa a mesma requisição automaticamente. Finalidade: organizar a síntese clínica, com revisão humana obrigatória. | O(A) psicólogo(a) **redige a síntese manualmente**. Nenhum texto clínico é enviado a provedor de IA. | ☐ | ☐ |
| 8.4 | **Contato por WhatsApp (lembretes de sessão).** Autorizo o envio de lembrete por WhatsApp, com o meu nome e a data/hora da sessão. Ciente de que o envio usa um **gateway não oficial** e de que a mensagem revela que faço psicoterapia. | Os lembretes são feitos por **telefone, e-mail ou outro meio que eu escolher**: ____________________________. | ☐ | ☐ |
| 8.5 | **Envio de link de anamnese e de contrato terapêutico.** Autorizo o recebimento de link (web) para preencher a anamnese e assinar o contrato. | O preenchimento é feito **presencialmente ou em papel**, no consultório. | ☐ | ☐ |

**Observações do(a) psicólogo(a) sobre escolhas feitas ou recusadas:**

________________________________________________________________________________________
________________________________________________________________________________________

---

## 9. Revogação do consentimento

### 9.1 Como revogar

Você (ou o responsável legal) pode **revogar qualquer um dos consentimentos da seção 8, a qualquer
momento**, por manifestação expressa — verbal, por escrito, por e-mail ou por telefone — dirigida
ao(à) psicólogo(a) (LGPD, art. 8º, §5º, combinado com o art. 18, IX) ⚖️.

**Basta dizer qual item você quer revogar.** Não é necessário justificar. Peça o registro por escrito
desta revogação — ele será arquivado junto ao seu prontuário, com data.

Data da revogação: ____/____/________ · Itens revogados: ☐ 8.2 ☐ 8.3 ☐ 8.4 ☐ 8.5
Assinatura de quem revogou: ________________________________________________

### 9.2 O que muda imediatamente

| Item revogado | Efeito a partir da revogação |
|---|---|
| 8.2 — áudio | Nenhum novo áudio é gravado nem enviado. O(A) psicólogo(a) passa a digitar o relato. |
| 8.3 — IA | Nenhum novo conteúdo clínico é enviado a provedor de IA. A síntese passa a ser redigida manualmente. |
| 8.4 — WhatsApp | Os lembretes passam a ser feitos pelo meio alternativo que você indicar. |
| 8.5 — link de anamnese/contrato | O preenchimento passa a ser presencial ou em papel. |

### 9.3 O que continua, mesmo após a revogação — e por quê

A revogação **não apaga o que já foi feito com base no consentimento anterior**, nem elimina o
**prontuário já constituído**. Motivo: o psicólogo tem **dever legal e normativo de guarda** do
registro documental por **no mínimo 5 anos**, ampliável por lei, por determinação judicial ou quando
necessário por mais tempo (Resolução CFP nº 001/2009, art. 4º, §1º — [texto oficial](http://site.cfp.org.br/wp-content/uploads/2009/04/resolucao2009_01.pdf)).
A LGPD trata dessa mesma hipótese ao autorizar a conservação de dados para **cumprimento de obrigação
legal ou regulatória** (art. 16, I) e ao ressalvar esse caso no direito de eliminação (art. 18, VI).
⚖️ **Validar com advogado** a redação final deste parágrafo e o prazo aplicável ao caso concreto.

**O que isso significa na prática:**

- O **conteúdo clínico** (relato, evolução, apontamentos e a síntese que já foi revisada e incorporada)
  **permanece** em prontuário durante o prazo de guarda, porque o psicólogo é obrigado a guardá-lo.
- O **áudio** e as **transcrições** que não fazem parte do registro mínimo exigido **podem e devem ser
  eliminados** quando a revogação ocorrer — **porém o app hoje não oferece esse caminho de forma
  garantida** (`01_diagnostico_lgpd.md` §4.5: a exclusão de áudio é disparada sem espera e não há prazo
  definido). **NÃO CONFIRMADO — validar com advogado** o que o app efetivamente consegue apagar hoje. ⚖️
- Dados que estejam **no servidor** (contrato, anamnese, telefone) **não são apagáveis hoje**, porque o
  backend não tem rotina de expurgo nem endpoint de exclusão (`01_diagnostico_lgpd.md` §4.13). Este é
  um **problema real do produto**, e o(a) psicólogo(a) deve ser transparente sobre ele. ⚖️

### 9.4 Registro da revogação (uso do psicólogo)

- [ ] Revogação registrada na auditoria do app (observação: o app **não possui evento de auditoria para
      eliminação nem para remoção de áudio** — `01_diagnostico_lgpd.md` §4.8).
- [ ] Revogação registrada em papel e anexada ao prontuário.
- [ ] Medidas tomadas: ______________________________________________________________
- [ ] Data e responsável: ___________________________________________________________

---

## 10. O que a pessoa atendida precisa saber em 1 minuto

| Pergunta | Resposta curta |
|---|---|
| Quem manda nos meus dados? | O(A) **psicólogo(a)**. O MentAll PRO é só a ferramenta. |
| O software é seguro e certificado? | Ele está **em adequação** à LGPD. **Não** é "certificado" nem "100% seguro". |
| Alguém de fora vê meu relato? | **Sim, em parte.** O áudio vai para transcrição nos **EUA**; o texto clínico pode ir para IA nos **EUA** e, se falhar, na **China**. |
| Vocês gravam a sessão? | **Não.** O áudio é um relato curto (até 5 min) feito pelo(a) psicólogo(a) **depois** da sessão (`termos_uso_page.dart:53-59`). |
| Meu contrato e minha anamnese ficam só no aparelho? | **Não.** Eles ficam em um banco nos **EUA**, e hoje **sem cifra** lá. |
| Vou poder ler meu prontuário? | **Sim**, você ou seu representante legal têm acesso integral (Resolução CFP nº 001/2009, art. 5º, II). |
| Posso pedir para apagar tudo? | Você pode **pedir**, e pode revogar consentimentos. O prontuário, porém, tem **guarda obrigatória de no mínimo 5 anos**. |
| Em quanto tempo respondem meu pedido? | Acesso/confirmação: imediato ou até **15 dias**. Demais pedidos: **de imediato** (LGPD, arts. 18 e 19). |
| Como peço alguma coisa? | Diretamente ao(à) **psicólogo(a)** — e-mail, telefone ou presencialmente. |
| Posso recusar? | **Sim**, item por item. Recusar áudio ou IA **não impede** o atendimento. |

---

## 11. Assinaturas

### 11.1 Pessoa atendida (ou responsável legal)

Declaro que li, compreendi e recebi uma via deste documento.

Nome: **______________________________________________________________________**

Documento: ______________________ · ☐ Pessoa atendida ☐ Responsável legal
(qualidade: ______________________)

Assinatura: ________________________________________  Data: ____/____/________

### 11.2 Psicólogo(a) — controlador dos dados

Nome: **______________________________________________________________________**

CRP nº: ______________________ (uf: ______) · CPF/CNPJ: ______________________

E-mail de contato para assuntos de privacidade: ____________________________________
Telefone: ______________________________

Assinatura: ________________________________________  Data: ____/____/________

---

**Rodapé de controle do documento**

- Documento: Aviso de Privacidade do Consultório e Termo de Consentimento
- **Versão do termo: 1.0** · **Data: 09/10/2026**
- Psicólogo(a): ______________________________ · **CRP nº: ______________**
- Software: MentAll PRO `1.0.49` — **em adequação** à LGPD (não certificado)
- Via: ☐ Pessoa atendida ☐ Prontuário

---

## Pendências de validação jurídica

| # | Pendência | Onde aparece | Status |
|---|---|---|---|
| 1 | ⚖️ **Base legal do prontuário.** Confirmar se "tutela da saúde" (LGPD, art. 11, II, "f") sustenta o prontuário psicológico, ou se é obrigação legal/regulatória (art. 11, II, "a") combinada com as Resoluções do CFP. | Seções 1, 2, 8.1 | NÃO CONFIRMADO — validar com advogado |
| 2 | ⚖️ **Base legal do áudio e da IA.** Confirmar se basta consentimento específico e destacado (art. 11, I) e se ele precisa ser lido em conjunto ou separado por provedor (EUA e China). | Seções 8.2, 8.3 | NÃO CONFIRMADO — validar com advogado |
| 3 | ⚖️ **Transferência internacional.** Escolher e documentar o mecanismo do art. 33 (cláusulas-padrão, garantias específicas ou consentimento específico e destacado, art. 33, VIII) para EUA e China — o Brasil não tem decisão de adequação para nenhum dos dois. | Seções 3, 8.2, 8.3 | NÃO CONFIRMADO — validar com advogado |
| 4 | ⚖️ **Guarda obrigatória do prontuário.** Confirmar o prazo de 5 anos (Resolução CFP nº 001/2009, art. 4º, §1º, e remissão da Resolução CFP nº 007/2003) e as hipóteses de ampliação; confirmar como isso interage com o art. 16, I e com o art. 18, VI da LGPD. | Seções 4, 9.3, 10 | PARCIALMENTE CONFIRMADO (norma do CFP lida na fonte oficial) — validar a interação com a LGPD |
| 5 | ⚖️ **Prazo de retenção do áudio.** Não há prazo declarado no app nem decisão do produto. | Seção 4 | NÃO CONFIRMADO — validar com advogado |
| 6 | ⚖️ **Prazo de retenção de contrato e anamnese no servidor.** Hoje não há expurgo algum; é preciso definir prazo e base legal. | Seção 4 | NÃO CONFIRMADO — validar com advogado |
| 7 | ⚖️ **Prazo de resposta ao titular.** "De imediato" (art. 18, §4º) não é prazo determinado; confirmar o prazo operacional a declarar ao titular (além dos 15 dias do art. 19, II, que valem para acesso/confirmação). | Seções 5, 10 | NÃO CONFIRMADO — validar com advogado |
| 8 | ⚖️ **Menores de idade.** Confirmar a exigência de consentimento específico e em destaque de pelo menos um dos pais ou responsável legal (LGPD, art. 14, §1º), os "esforços razoáveis" para verificar esse consentimento (art. 14, §5º, e a [Resolução CD/ANPD sobre dados de crianças e adolescentes](https://www.gov.br/anpd/pt-br/acesso-a-informacao/institucional/atos-normativos/regulamentacoes_anpd/tratamento_de_dados_de_criancas_e_adolescentes.pdf)) e a idade a partir da qual o próprio adolescente consente. | Seção 7 | NÃO CONFIRMADO — validar com advogado |
| 9 | ⚖️ **WhatsApp por gateway não oficial.** Confirmar a licitude do envio por wuzapi diante dos termos da Meta, e a necessidade de consentimento específico. | Seções 3(d), 8.4 | NÃO CONFIRMADO — validar com advogado |
| 10 | ⚖️ **Revogação e efeito retroativo.** Confirmar a redação do que "continua" após a revogação, especialmente áudio e transcrições que não integram o registro mínimo obrigatório. | Seções 9.2, 9.3 | NÃO CONFIRMADO — validar com advogado |
| 11 | **Texto corrigido do app.** Enquanto `politica_privacidade_page.dart:71-73,105-108,119-122` não for corrigido, este aviso em papel é a informação correta e deve ser entregue sempre. | Seção 3 (aviso) | Ação de produto (documento 02, P0.1/P0.6) |
| 12 | **Encarregado (DPO).** Não existe nome nem canal publicado (art. 41). Enquanto isso, todo pedido vai ao psicólogo. | Seção 5 | Ação de produto (documento 02, P1.1) |
| 13 | **Revisão jurídica registrada.** Após validação, preencher: advogado(a), OAB, data — e incrementar a versão para 1.1. | Todo o documento | Pendente |
