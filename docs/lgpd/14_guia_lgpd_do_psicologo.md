# Guia LGPD do Psicólogo — MentAll PRO

**Versão:** 1.0 · **Data:** 09/10/2026
**Natureza:** rascunho de trabalho, guia operacional. **Não é parecer jurídico.**
**Público:** psicólogas e psicólogos clínicos que usam o MentAll PRO (cliente Flutter `1.0.49` + backend FastAPI)
**Documento companheiro:** `07_aviso_de_privacidade_e_termo_de_consentimento.md` — é o material que você entrega à pessoa atendida.

> ⚠️ **Aviso honesto antes de começar.** O MentAll PRO **está em adequação** à LGPD. Ele **não** é
> "LGPD compliant", **não** é certificado e **não** é "100% seguro". Há lacunas abertas e registradas
> no diagnóstico — inclusive lacunas que **você** precisa cobrir no consultório, porque o software
> ainda não cobre. Este guia serve para você não herdar sozinho os riscos que são do produto.
> Tudo marcado com ⚖️ depende de validação jurídica antes de virar compromisso.

> **Enquadramento que orienta tudo:** **você é o controlador** dos dados clínicos; o **MentAll PRO é
> operador**. Está declarado no próprio app (`lib/screens/lgpd/politica_privacidade_page.dart:76-77`).
> Quem responde ao titular pelo conteúdo clínico é **você** — o MentAll responde junto na quota de
> operador quando descumpre instruções (LGPD, art. 42, §1º, I).

---

## 1. O primeiro atendimento: o que fazer

Você tem **um documento** e **uma conversa** a fazer. Nada além disso.

### 1.1 Checklist — primeiro atendimento (10 minutos)

- [ ] **Imprima o documento 07** (Aviso + Termo) antes da sessão. Leve duas vias.
- [ ] **Leia o Aviso em voz alta** (seções 1 a 5 do documento 07) ou entregue para a pessoa ler ali
      mesmo. Não peça para "levar para casa e assinar" — o consentimento precisa ser obtido em momento
      de destaque e com fácil identificação ⚖️.
- [ ] **Diga em voz alta, com suas palavras, os três pontos que ninguém entende sozinho:**
      1. o **áudio do relato vai para um serviço de transcrição nos EUA**;
      2. o **texto clínico pode ser processado por IA nos EUA e, se o primeiro provedor falhar,
         também na China**;
      3. o **contrato e o formulário de anamnese ficam gravados em um banco nos EUA, hoje sem cifra
         lá** (`backend/services/db.py:180-213`; `backend/services/contrato_service.py:14-15`).
- [ ] **Pergunte se ficou alguma dúvida** e registre no prontuário que perguntou e o que foi
      respondido. Anote a data.
- [ ] **Marque os 5 consentimentos granulares** (seção 8 do documento 07) **junto com a pessoa** —
      nunca antes, nunca depois. Deixe claro que **NÃO em qualquer item não impede o atendimento**.
- [ ] **Colha a assinatura** da pessoa atendida (Caminho A) **ou** o bloco de responsável legal
      (Caminho B, para criança/adolescente).
- [ ] Se for **criança ou adolescente**: preencha a seção 7 do documento 07 **em papel** — o app
      **não tem campo de responsável legal** (`01_diagnostico_lgpd.md` §4.10; busca por
      `responsavel_legal` em `lib/models/` e `lib/services/` não retorna resultado).
- [ ] **Assine os dois lados**, coloque **versão (1.0) e data**, e **arquive uma via no prontuário**.
- [ ] **Entregue a outra via** à pessoa atendida.
- [ ] Se algum item foi recusado (por exemplo, o 8.3 — IA), **registre no prontuário** e ajuste seu
      fluxo: você passa a redigir a síntese manualmente.
- [ ] **Lembre-se do limite do app:** o MentAll **não registra consentimento nenhum** — nem tela, nem
      data, nem versão (`01_diagnostico_lgpd.md` §4.2 e §4.14). **O papel assinado é o seu único
      registro.** Trate-o como documento clínico.

### 1.2 Frase de abertura (sugestão, adapte ao seu estilo)

> "Antes de começarmos, preciso te explicar como eu guardo as informações do nosso trabalho, porque eu
> uso um programa de computador que manda parte do conteúdo para fora do Brasil. Vou ler com você, são
> duas páginas, e você pode dizer não para algumas coisas sem nenhum prejuízo no atendimento."

---

## 2. A cada novo atendimento: o que fazer

| Situação | O que fazer |
|---|---|
| **Retorno normal** | Nada a assinar. O consentimento vale enquanto não mudar. Confirmar uma vez por ano, por escrito, que a pessoa segue de acordo — e arquivar. |
| **A pessoa revogou um item** (8.2 a 8.5) | Registrar a revogação em papel, anexar ao prontuário, ajustar o fluxo **na hora** (ver seção 9 do documento 07) e observar que o app **não tem evento de auditoria para eliminação nem para remoção de áudio** (`01_diagnostico_lgpd.md` §4.8) — o controle é seu. |
| **Pessoa nova** | Checklist completo da seção 1.1. |
| **Atendimento de criança/adolescente** | Documento 07, Caminho B, com responsável legal. Revisar a cada aniversário relevante e sempre que houver mudança de guarda ou de responsável ⚖️. |
| **Pessoa pediu acesso/correção/eliminação** | Ir para a seção 4 deste guia. |
| **Mudou o provedor de IA ou o país de destino** | **Reemitir o termo** e colher novo consentimento. A ordem de provedores é configurável (`AGENTS.md:191-192`) e pode mudar sem aviso ao titular — isso é um dever **seu** de avisar. |
| **Perdeu o aparelho, vazou PDF, suspeita de vazamento** | Ir para as seções 5 e 6 deste guia. **Não improvise.** |
| **Risco de perder o prontuário** (troca de aparelho, formatação, perda do Keystore) | Ler a seção 7 **antes**, não depois. |

---

## 3. O que NÃO fazer (regras duras)

1. **Não gravar a sessão inteira. Nunca.**
   O áudio do MentAll é um **relato breve feito por você depois do atendimento**, com limite de
   **5 minutos** (`lib/screens/lgpd/privacidade_seguranca_page.dart:88-90`; o próprio Termo de Uso diz
   que você é responsável por garantir que o áudio **não contenha gravação da sessão** —
   `lib/screens/lgpd/termos_uso_page.dart:53-59`). Gravar a sessão tem problema ético, clínico e
   jurídico, e não é o propósito da ferramenta.

2. **Não ditar dados que identifiquem terceiros.**
   Nada de cônjuge, filhos, colegas de trabalho ou vizinhos pelo nome no relato. Isso cria dado
   sensível de **outra pessoa** — que não assinou termo nenhum, não é sua paciente e não consentiu com
   transferência internacional.

3. **Não compartilhar PDF de prontuário por WhatsApp.**
   O PDF sai **em claro, sem senha, sem aviso no arquivo e sem evento de auditoria**, pelo
   compartilhamento do sistema (`01_diagnostico_lgpd.md` §4.14, C7; `lib/services/pdf_export_service.dart:1544-1552`;
   `lib/screens/paciente_detail_page.dart:573-648`). Uma vez exportado, **o destino está fora do
   controle do MentAll e fora do seu**. Se precisar entregar um documento, entregue **impresso, em
   mãos**, ou por canal que você controla, com o arquivo protegido — e registre a entrega.

4. **Não usar aparelho compartilhado.**
   O bloqueio do app **falha aberto** em lockout de biometria, erro de hardware ou ausência de
   credencial: ele carrega a chave mestra **sem pedir nada** (`01_diagnostico_lgpd.md` §4.14, C2;
   `lib/services/auth_service.dart:203-215,237-250`). E o "bloqueio" é **apenas visual** — a chave
   continua na memória e não há `FLAG_SECURE` (C5). Em aparelho de uso compartilhado, **qualquer
   pessoa na frente da tela pode abrir o prontuário**. Use aparelho pessoal, com tela de bloqueio
   própria, e nunca deixe terceiros manuseando ele.

5. **Não deixar o áudio "para depois".**
   O `.m4a` é gravado **em texto claro** e só é cifrado **depois** que a gravação para
   (`01_diagnostico_lgpd.md` §4.14, C1). Queda, bateria fraca ou encerramento forçado deixam **relato
   clínico em claro** no aparelho, e não há varredura de órfãos. Termine a gravação e aguarde o
   processamento.

6. **Não prometer o que o app não faz.**
   Não diga à pessoa atendida que os dados ficam "todos no Brasil" (o banco está em Oregon, EUA —
   `01_diagnostico_lgpd.md` §4.1, T1), que o sistema é "certificado", nem que usa "só a OpenAI"
   (a Groq e a DeepSeek também recebem dados — §4.3).

7. **Não jogar fora o termo assinado.**
   Sem ele, você não consegue provar que informou a pessoa atendida. O app não guarda isso por você.

---

## 4. Pedido de titular (art. 18): como responder em 5 passos

A pessoa atendida **não é usuária do app** e **não existe canal de titular publicado** — a Política
atual ainda diz apenas "fale com o desenvolvedor do MentAll PRO", **sem encarregado e sem e-mail**
(`politica_privacidade_page.dart:119-122`; `01_diagnostico_lgpd.md` §4.6). Os pedidos vão chegar
**para você**. O procedimento abaixo cobre isso.

### Passo 1 — Receber e registrar (no mesmo dia)

Anote em papel ou em arquivo próprio: **data do recebimento**, nome de quem pediu, **como** pediu
(e-mail, telefone, presencial), **o que** pediu exatamente, e o **protocolo** que você atribuiu.
Guarde uma cópia da mensagem original.

⚠️ **O app não tem tela de solicitação do titular nem canal de entrada**
(`01_diagnostico_lgpd.md` §4.4). Este registro é seu, manual. Faça dele um hábito.

### Passo 2 — Identificar o pedido e o prazo

| Pedido | Base | Prazo |
|---|---|---|
| Confirmação de tratamento / **acesso** aos dados | LGPD, art. 18, I e II; art. 19 | Formato simplificado: **imediatamente**. Declaração clara e completa: até **15 dias** do requerimento ([art. 19, I e II](https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm)) |
| **Correção** de dado incompleto, inexato ou desatualizado | art. 18, III | **De imediato** (art. 18, §4º) ⚖️ |
| **Anonimização, bloqueio ou eliminação** de dado desnecessário, excessivo ou em desconformidade | art. 18, IV | **De imediato** ⚖️ |
| **Portabilidade** a outro fornecedor | art. 18, V | ⚖️ **NÃO CONFIRMADO** — a LGPD exige regulamentação da ANPD; o app tem exportação em PDF, mas ela é **recurso clínico seu**, não mecanismo de portabilidade do titular (`01_diagnostico_lgpd.md` §4.4) |
| **Eliminação** de dado tratado com consentimento | art. 18, VI | **De imediato** — **ressalvadas** as hipóteses do art. 16 (ver seção 8) ⚖️ |
| Informação sobre **compartilhamento** | art. 18, VII | **De imediato** ⚖️ |
| Informação sobre **não consentir** e consequências | art. 18, VIII | **De imediato** ⚖️ |
| **Revogação do consentimento** | art. 18, IX + art. 8º, §5º | **De imediato** ⚖️ |
| **Revisão de decisão automatizada** | art. 20 | ⚖️ No MentAll a IA é apoio documental **com revisão humana obrigatória** — não há decisão tomada unicamente por tratamento automatizado. Confirmar redação. |

⚠️ Sobre "de imediato": a lei **não fixa prazo em dias** para os itens que não são acesso/confirmação.
O dever é atender **sem demora**; se não for possível, você responde no menor prazo possível indicando
as providências (art. 18, §4º). **NÃO CONFIRMADO — validar com advogado** qual prazo operacional você
deve declarar ⚖️.

### Passo 3 — Verificar se você é o responsável e juntar o material

Você é o **controlador** dos dados clínicos — então, para pedidos sobre clínica, **é você quem
decide** (MentAll, 04, Parte B). Para dados de **conta do profissional, telemetria e segurança**, o
controlador é o **MentAll PRO**: nesse caso, encaminhe e registre o encaminhamento.

Ao juntar o material, considere (LGPD, art. 18, §3º):

- [ ] Exportar/imprimir o prontuário ou a parte pedida, em formato que a pessoa consiga usar.
- [ ] **Escrever o acessório com cuidado:** documentos psicológicos podem precisar de
      **linguagem técnica e destinação correta** para não causar dano à própria pessoa atendida.
      O CFP admite a restrição de compartilhamento em situações específicas, e é exatamente para isso
      que existe o **registro documental sigiloso** (Resolução CFP nº 001/2009, art. 1º —
      [texto oficial](http://site.cfp.org.br/wp-content/uploads/2009/04/resolucao2009_01.pdf)) ⚖️.
      **Se houver risco de dano, decida com apoio jurídico e clínico — não sozinho.**
- [ ] Anotar que existe **acesso integral garantido ao usuário ou representante legal**
      (Resolução CFP nº 001/2009, art. 5º, II). Isso favorece o atendimento do pedido.
- [ ] Lembrar que os dados **no servidor** (contrato, anamnese, telefone) **não podem ser apagados
      hoje** — não há rotina de expurgo nem endpoint de exclusão (`01_diagnostico_lgpd.md` §4.13).
      **Seja verdadeiro sobre isso** na sua resposta.

### Passo 4 — Responder por escrito, dentro do prazo

Responda **sempre por escrito**, mesmo que tenha conversado. A resposta precisa dizer: o que foi
pedido, o que foi atendido, o que **não** foi atendido e **por qual motivo**, e o que fazer se a pessoa
discordar (peticionar à ANPD — art. 18, §1º).

### Passo 5 — Arquivar e aprender

- [ ] Arquivar cópia da solicitação **e** da resposta junto ao prontuário, com data e protocolo.
- [ ] Registrar internamente a decisão e o fundamento.
- [ ] Se o pedido revelou uma falha recorrente (por exemplo, "não consigo apagar áudio"), **abra um
      item no seu controle** — e cobre do MentAll (documento 02, P2.5).
- [ ] Só encerre o registro quando o prazo tiver sido cumprido e a resposta comprovadamente entregue.

### 4.1 Modelo de resposta (adapte; não copie sem ler)

> **Assunto:** Resposta à solicitação de titular de dados — protocolo nº ____/______
>
> Prezado(a) [nome],
>
> Recebemos em [data] a sua solicitação de [descrever: acesso / correção / eliminação / revogação /
> informação], registrada sob o protocolo nº ____/______.
>
> **1. O que foi atendido.** [Descrever exatamente.]
> Em anexo, segue [o prontuário / a parte solicitada / a correção realizada], em [formato].
>
> **2. O que não foi atendido e por quê.** [Se houver.] O [item] não pode ser eliminado porque a
> legislação e as normas do Conselho Federal de Psicologia exigem que o registro documental
> psicológico seja guardado por **no mínimo 5 (cinco) anos**, prazo que pode ser ampliado por lei, por
> determinação judicial ou quando for necessário manter a guarda por mais tempo (Resolução CFP nº
> 001/2009, art. 4º, §1º). A LGPD autoriza essa conservação para cumprimento de obrigação legal ou
> regulatória (art. 16, I) e ressalva essa hipótese no direito de eliminação (art. 18, VI). ⚖️
>
> **3. Informações sobre o tratamento.** Os seus dados clínicos são tratados sob a responsabilidade
> do(a) psicólogo(a) [nome, CRP], que é o **controlador**. O software MentAll PRO atua como
> **operador**. Para organizar o prontuário, parte do conteúdo é processada por terceiros no exterior:
> **[descrever conforme o que foi efetivamente consentido: áudio para transcrição nos EUA; texto
> clínico para IA nos EUA e, em caso de falha, na China]**.
>
> **4. Revogação de consentimento.** Você pode revogar, a qualquer momento e item por item, os
> consentimentos da seção 8 do termo que assinou, sem precisar justificar.
>
> **5. Se você não concordar.** Você pode peticionar em relação aos seus dados perante a Autoridade
> Nacional de Proteção de Dados (ANPD) — [gov.br/anpd](https://www.gov.br/anpd/pt-br) — nos termos do
> art. 18, §1º, da LGPD.
>
> Permanecemos à disposição para esclarecer qualquer ponto.
>
> [Nome do(a) psicólogo(a)] — CRP nº ______
> [E-mail] · [Telefone] · [Data]

---

## 5. Perda ou roubo do aparelho

**Trate como incidente de segurança, porque é.** Chave mestra no Keystore mais bloqueio fail-open
significa que um aparelho desbloqueado pode entregar o prontuário inteiro
(`01_diagnostico_lgpd.md` §4.14, C2 e C5).

**Nas primeiras horas:**

- [ ] **Não tente "resolver" silenciosamente.** Registre o que aconteceu, com data e hora.
- [ ] Se possível, **remova o acesso do aparelho**: troque a senha da sua conta MentAll PRO.
- [ ] Se tiver backup exportado, **preserve-o** e **não o sobrescreva**.
- [ ] **Avalie com o encarregado** se há risco ou dano relevante aos titulares. **Praticamente
      sempre há** — os dados do prontuário são **dados pessoais sensíveis de saúde**, critério
      expresso de risco relevante (Resolução CD/ANPD nº 15/2024, art. 5º, I) ⚖️.
- [ ] **Comunique as pessoas atendidas afetadas** e, se cabível, a **ANPD** — ver seção 5.1.

**Aviso sobre a estrutura atual:** o **plano de resposta a incidentes não existe** e o **encarregado
(DPO) não está nomeado** (`01_diagnostico_lgpd.md` §4.6 e §4.12). Enquanto isso, **não há para quem
escalar dentro do MentAll**. Registre tudo por escrito, cobre formalmente o fornecedor e, se o risco
for relevante, **procure apoio jurídico**. ⚖️

### 5.1 O prazo que existe (e ele é curto)

Se o incidente puder acarretar **risco ou dano relevante** aos titulares, **o controlador** deve
comunicar **a ANPD e o titular** em **3 (três) dias úteis**, contados do conhecimento de que o
incidente afetou dados pessoais (LGPD, art. 48; [Resolução CD/ANPD nº 15/2024](https://bibliotecadigital.mj.gov.br/handle/1/12879), arts. 6º e 9º).

Pontos que importam para o seu caso:

- O **controlador é você**. A comunicação é sua obrigação — com apoio técnico do MentAll, que como
  operador deve avisar você (documento 04, cláusula 8).
- **Dado pessoal sensível** é, por si, critério de risco relevante (art. 5º, I). Seu prontuário é
  dado sensível.
- A comunicação deve ter **linguagem simples e ser direta e individualizada**, pelos meios usuais de
  contato (art. 9º, §§1º e 2º).
- Você deve **manter o registro do incidente por no mínimo 5 anos**, mesmo daquele **não comunicado**
  (art. 10).
- **Agentes de tratamento de pequeno porte têm prazos em dobro** (arts. 6º, §8º, e 9º, §6º) —
  **verifique com o advogado se você se enquadra** ⚖️.

⚠️ **O MentAll ainda não tem plano de incidentes nem formulário de registro** (documento 02, P1.7).
Use o modelo do documento 11 quando ele existir; até então, registre à mão com os campos do art. 10.

---

## 6. PDF vazado ou suspeita de vazamento

1. **Pare de circular o arquivo.** Se ele está em um grupo, em um e-mail encaminhado, em uma pasta de
   nuvem compartilhada ou em um pendrive emprestado, **revogue o acesso ou apague onde estiver** —
   inclusive em backups de e-mail.
2. **Identifique o alcance:** quantas pessoas atendidas estão no arquivo, quais dados, onde ele
   esteve, quem teve acesso, por quanto tempo.
3. **Considere o incidente como de risco relevante** até prova em contrário — dado sensível de saúde
   em arquivo **sem senha e sem aviso**, saído pelo compartilhamento do sistema
   (`01_diagnostico_lgpd.md` §4.14, C7).
4. **Registre e comunique** conforme a seção 5.1.
5. **Escreva em linguagem simples** o que aconteceu, quais dados foram expostos, quais riscos existem
   e o que a pessoa deve fazer. Sem jargão.
6. **Corrija a causa:** enquanto o PDF sair sem cifra e sem auditoria, **não volte a compartilhar PDF
   de prontuário por mensageiro**. Entregue impresso ou protegido.
7. **Leve ao encarregado** e cobre a correção do produto (documento 02, P1.16 — senha/cifra opcional,
   aviso de sigilo e evento de auditoria em cada exportação).

---

## 7. Backup: o que ele faz, o que ele não faz

O backup do MentAll é útil, mas **não é uma política de guarda**. Ele é um envelope cifrado com
AES-GCM e HMAC-SHA256 (`01_diagnostico_lgpd.md` §4, "O que já está bom"). Três limites, porém, mudam
tudo:

1. **O backup só abre no mesmo aparelho.**
   A chave mestra é vinculada ao aparelho e não tem rekey nem recuperação
   (`01_diagnostico_lgpd.md` §4.14, C8; `lib/services/encryption_service.dart:70,252-264`). O próprio
   app, ao falhar a leitura, responde: *"Nao foi possivel abrir o backup: chave diferente ou
   integridade comprometida. Preserve o arquivo e o aparelho original."*
   (`lib/services/backup_service.dart:191-194`). Ou seja: **se o aparelho morrer, o backup pode não
   servir de nada.** Guardar o arquivo criptografado em nuvem não resolve.

2. **O backup é incompleto e restaura em silêncio o que conseguiu.**
   Ele **não inclui compromissos, anamnese, escalas, avaliação inicial nem a auditoria**
   (`01_diagnostico_lgpd.md` §4.14, C9; `lib/services/backup_service.dart:33-154,166-180`). A
   restauração é **parcial e sem alerta claro** — risco clínico (você acha que tem tudo e não tem) e
   de conformidade (falta o próprio registro da trilha).

3. **O PIN pode não existir quando você precisa.** Em instalação nova o PIN é inexistente e a
   reautenticação para exportar backup não funciona (`01_diagnostico_lgpd.md` §4.14, C3).

**O que fazer na prática:**

- [ ] **Não trate o backup como guarda.** Guarda é o dever legal de manter o registro por no mínimo
      5 anos (Resolução CFP nº 001/2009, art. 4º, §1º) — o backup é uma cópia operacional.
- [ ] **Configure o PIN antes de precisar dele** e teste uma restauração **agora**, não em emergência.
- [ ] **Registre em papel o essencial:** identificação, avaliação de demanda, evolução,
      encaminhamento/encerramento (Resolução CFP nº 001/2009, art. 2º, I a IV). Se o aparelho cair,
      o papel é o que sobra.
- [ ] **Guarde o backup em local que você controla**, e não o sobrescreva com uma cópia parcial.
- [ ] **Cobre a correção** do produto (documento 02, P2.15 — backup completo e teste de restauração).

⚖️ Duas regras de guarda convivem aqui: a **norma profissional** (registro documental sigiloso, guarda
mínima de 5 anos — Resolução CFP nº 001/2009, art. 4º, §1º) e a **LGPD** (eliminação após o término do
tratamento, ressalvada a conservação para cumprimento de obrigação legal — art. 16, I). **Validar com
advogado** como elas se combinam no seu caso concreto, inclusive sobre onde e como o registro deve
ficar (a norma exige local que **garanta sigilo e privacidade** e que esteja à disposição dos
Conselhos — art. 4º, §2º).

---

## 8. "Arquivar em vez de excluir" × direito de eliminação

Esta é a tensão que mais gera dúvida — e a razão mais comum de uma resposta errada ao titular.

O app hoje declara a regra **"arquivamento em vez de exclusão"** no texto da sua Política de
Privacidade (`politica_privacidade_page.dart:82-84`). Isso, escrito assim, **colide de frente** com o
direito de eliminação do art. 18, VI — e o próprio diagnóstico registra a colisão
(`01_diagnostico_lgpd.md` §4.5 e §4.3). A saída não é escolher um dos dois lados: é **separar o que é
lei do que é escolha sua.**

### 8.1 O que é guarda legal (não é escolha sua)

- O **registro documental psicológico é obrigatório** e a **guarda é de no mínimo 5 anos**, ampliável
  por lei, por determinação judicial ou quando for necessário manter por mais tempo. A
  responsabilidade pela guarda é **do psicólogo e/ou da instituição**
  (Resolução CFP nº 001/2009, arts. 1º, 4º, §1º e 5º, IV — [texto oficial](http://site.cfp.org.br/wp-content/uploads/2009/04/resolucao2009_01.pdf);
  confirmado na [FAQ do CFP](https://site.cfp.org.br/faq/como-devo-fazer-guarda-e-descarte-de-documentos-utilizados-no-atendimento/),
  que cita também a Resolução CFP nº 007/2003).
- A LGPD **autoriza** a conservação para **cumprimento de obrigação legal ou regulatória**
  (art. 16, I) e **ressalva expressamente** essa hipótese no direito de eliminação
  (art. 18, VI: "exceto nas hipóteses previstas no art. 16").
- **Consequência prática:** quando a pessoa pede eliminação do **conteúdo clínico que integra o
  registro obrigatório**, a resposta correta é **"não é possível eliminar agora, e eis o motivo e o
  prazo"** — com transparência e por escrito. **Não** é "arquivamos por opção nossa". ⚖️

### 8.2 O que é escolha sua (e por isso precisa de critério)

- **Arquivar em vez de excluir é uma decisão de produto**, não uma imposição da lei. Arquivar protege
  o histórico clínico, mas **não pode ser usada como desculpa para nunca eliminar nada**.
- O que **não** integra o registro mínimo obrigatório deve seguir a lógica da LGPD: **eliminar após o
  término do tratamento** (art. 16, caput), salvo hipótese de conservação autorizada.
- **Escolhas que são suas e devem estar escritas:**
  - por quanto tempo você mantém além do mínimo de 5 anos;
  - se mantém o **áudio** depois da transcrição (o app **não define prazo** e não garante o
    apagamento — `01_diagnostico_lgpd.md` §4.5);
  - o que fazer com **transcrições** já incorporadas ao relato revisado;
  - o destino do prontuário em caso de **encerramento do serviço psicológico**: a norma manda seguir as
    orientações do Código de Ética do Psicólogo ⚖️.
- ⚖️ **Atenção ao Código de Ética:** o psicólogo deve registrar **apenas as informações necessárias**
  ao cumprimento dos objetivos do trabalho (art. 12 do Código de Ética Profissional do Psicólogo,
  citado na [página de Registro em prontuário do Sistema Conselhos](https://transparencia.cfp.org.br/crp16/pergunta-frequente/registro-em-prontuario/)).
  Isso significa que **minimizar é dever**, não gentileza: dado que não é necessário **não deve ser
  coletado nem guardado**, e aí a eliminação é devida.

### 8.3 Como explicar isso à pessoa atendida

> "Você pode me pedir para eliminar seus dados, e eu sou obrigado a analisar. Mas parte do prontuário
> eu **não posso** apagar, porque a lei e as normas do meu Conselho exigem que eu guarde o registro
> por **no mínimo 5 anos**, para garantir continuidade do cuidado, defesa sua e defesa minha. O que
> não faz parte desse registro mínimo — como o áudio — eu posso e devo eliminar quando você pedir."

⚠️ **Lacuna do produto que você precisa conhecer:** hoje o backend **não apaga nada** (contrato,
anamnese, telefone, lembretes) e o app **não tem evento de auditoria para eliminação**
(`01_diagnostico_lgpd.md` §4.13 e §4.8). Se você prometeu eliminar, **verifique se conseguiu** — e
registre em papel o que não foi tecnicamente possível.

---

## 9. Responsabilidades do controlador que NÃO podem ser terceirizadas ao software

Contratar um bom software **não transfere** o dever de proteger dados. Estas obrigações são **suas** e
continuam suas mesmo que o MentAll falhe, mude de provedor ou saia do ar:

1. **Decidir a finalidade e a base legal** de cada tratamento. O software não decide por você ⚖️.
2. **Informar a pessoa atendida** — de forma clara, antes ou no início do tratamento — sobre quem
   trata, para quê, com quem compartilha, por quanto tempo e como exercer direitos
   (LGPD, arts. 6º, VI, e 9º). **É para isso que existe o documento 07.**
3. **Colher e manter o consentimento** quando ele for a base legal — especialmente para dado sensível
   (art. 11, I) e para transferência internacional (art. 33, VIII) ⚖️. O app **não registra
   consentimento**; você registra em papel.
4. **Atender o titular** nos prazos dos arts. 18 e 19. O app não tem canal nem tela para isso.
5. **Decidir sobre eliminação versus guarda legal** (seção 8). Ninguém decide isso por você.
6. **Comunicar incidente** à ANPD e aos titulares no prazo (art. 48; Resolução CD/ANPD nº 15/2024).
   A obrigação é **do controlador**.
7. **Demonstrar conformidade** (*accountability*, art. 6º, X): manter o registro das operações
   (art. 37) e o RIPD quando exigível (art. 38). O MentAll entrega modelos
   (`03_data_mapping_e_ropa.md`), mas **o registro é seu**.
8. **Escolher e supervisionar o operador** (arts. 39 e 42, §1º): exigir a lista real de
   subprocessadores, com país e finalidade, e cobrar o DPA. **O MentAll ainda não entregou os anexos
   do DPA** (`04_papeis_e_contrato_controlador_operador.md`, Parte C e Anexo III).
9. **Zelar pelo sigilo profissional** (Código de Ética do Psicólogo) — dever que não se satisfaz com
   criptografia. **Nunca** anote o que não é necessário (art. 12 do Código).
10. **Garantir acesso ao registro** pela pessoa atendida ou representante legal (Resolução CFP nº
    001/2009, art. 5º, II).

**E o que o MentAll deve a você:** tratar dados **só conforme suas instruções** (LGPD, art. 39),
**não usar dado clínico para finalidade própria nem para treinar modelo**
(`04_papeis_e_contrato_controlador_operador.md`, Anexo I, cláusula 4), avisar você de incidentes, e
**não** prometer conformidade que não existe. O DPA que formaliza isso **ainda está em minuta e não
assinado** ⚖️.

---

## 10. Checklist final — 10 itens

- [ ] **1.** Entreguei o **documento 07** a todas as pessoas atendidas ativas, li o aviso com elas e
      tenho **via assinada arquivada no prontuário**.
- [ ] **2.** Marquei os **5 consentimentos granulares** individualmente, com **SIM ou NÃO**, e deixei
      claro que recusar **não impede** o atendimento.
- [ ] **3.** Resolvi o caso dos **menores**: termo em papel, com bloco de **responsável legal**,
      já que o app **não tem esse campo** (`01_diagnostico_lgpd.md` §4.10).
- [ ] **4.** **Não** gravo a sessão inteira: o áudio é o meu **relato pós-sessão, até 5 minutos**
      (`privacidade_seguranca_page.dart:88-90`).
- [ ] **5.** **Não** compartilho PDF de prontuário por WhatsApp nem por mensageiro; entrego impresso ou
      em arquivo protegido, e **registro a entrega**.
- [ ] **6.** Uso **aparelho pessoal**, com tela de bloqueio própria, e **não** deixo terceiros
      manusearem ele — porque o bloqueio do app **falha aberto**
      (`01_diagnostico_lgpd.md` §4.14, C2 e C5).
- [ ] **7.** Tenho um **registro em papel** do que o backup não cobre (compromissos, anamnese,
      escalas, avaliação inicial, auditoria) e **testei uma restauração** de backup.
- [ ] **8.** Sei **responder a um pedido de titular em 5 passos** (seção 4) e tenho o **modelo de
      resposta** pronto para usar.
- [ ] **9.** Sei o que fazer em **perda de aparelho, PDF vazado ou suspeita de vazamento**, e sei que
      o prazo de comunicação é de **3 dias úteis**, com o **controlador sendo eu**
      ([Resolução CD/ANPD nº 15/2024](https://bibliotecadigital.mj.gov.br/handle/1/12879), arts. 6º e 9º).
- [ ] **10.** Entendi que **o software não assume minhas obrigações de controlador** (seção 9) — e que
      o MentAll PRO **está em adequação**, não é certificado e não é "100% seguro".

---

## Pendências de validação jurídica

| # | Pendência | Onde aparece | Status |
|---|---|---|---|
| 1 | ⚖️ **Base legal do prontuário e dos consentimentos.** Confirmar "tutela da saúde" (art. 11, II, "f") versus obrigação legal (art. 11, II, "a") e a necessidade de consentimento específico e destacado (art. 11, I) para áudio, IA e transferência internacional. | Seções 1, 9 | NÃO CONFIRMADO — validar com advogado |
| 2 | ⚖️ **Prazo de resposta "de imediato" (art. 18, §4º).** A lei não fixa dias para correção, eliminação, portabilidade, informação e revogação. Definir o prazo operacional a declarar ao titular e no seu procedimento. | Seção 4, Passo 2 | NÃO CONFIRMADO — validar com advogado |
| 3 | ⚖️ **Portabilidade (art. 18, V).** Depende de regulamentação da ANPD; hoje a exportação em PDF do app é recurso clínico do profissional, não mecanismo de portabilidade do titular. Definir o que será entregue. | Seção 4, Passo 2 | NÃO CONFIRMADO — validar com advogado |
| 4 | ⚖️ **Acesso ao prontuário versus risco de dano.** Conciliar o acesso integral garantido ao usuário/representante legal (Resolução CFP nº 001/2009, art. 5º, II) com a possibilidade de restrição de compartilhamento em situações específicas (art. 1º). Definir critério e redação de documentos sensíveis. | Seção 4, Passo 3 | NÃO CONFIRMADO — validar com advogado |
| 5 | ⚖️ **Guarda legal × eliminação.** Confirmar o prazo mínimo de 5 anos e suas hipóteses de ampliação (Resolução CFP nº 001/2009, art. 4º, §1º, com remissão da Resolução CFP nº 007/2003) e sua combinação com os arts. 16, I, e 18, VI da LGPD. Definir critério escrito para o que você mantém além do mínimo. | Seção 8 | PARCIALMENTE CONFIRMADO (norma do CFP lida na fonte oficial) — validar a interação com a LGPD |
| 6 | ⚖️ **Destino do prontuário no encerramento do serviço psicológico** e em caso de extinção do serviço. A norma remete ao Código de Ética; o procedimento não está detalhado na Resolução 001/2009. | Seção 8.2 | NÃO CONFIRMADO — validar com advogado |
| 7 | ⚖️ **Prazo de retenção do áudio** e o que fazer com transcrições já incorporadas ao relato revisado. Não há prazo definido no app nem decisão do produto. | Seções 8.2, 2 | NÃO CONFIRMADO — validar com advogado |
| 8 | ⚖️ **Comunicação de incidente.** Confirmar a aplicação da Resolução CD/ANPD nº 15/2024 ao consultório, os 3 dias úteis (arts. 6º e 9º), o registro mínimo de 5 anos (art. 10) e o **prazo em dobro para agentes de pequeno porte** (arts. 6º, §8º, e 9º, §6º) — inclusive se você se enquadra. | Seções 5 e 10 | PARCIALMENTE CONFIRMADO (regulamento lido na fonte oficial) — validar o enquadramento |
| 9 | ⚖️ **Menores de idade.** Confirmar consentimento específico e em destaque de pelo menos um dos pais ou responsável legal (art. 14, §1º), os esforços razoáveis de verificação (art. 14, §5º) e a idade a partir da qual o próprio adolescente consente. | Seções 1.1, 3 | NÃO CONFIRMADO — validar com advogado |
| 10 | ⚖️ **WhatsApp por gateway não oficial (wuzapi).** Confirmar licitude diante dos termos da Meta e a necessidade de consentimento específico. | Seções 1.1, 4 (modelo) | NÃO CONFIRMADO — validar com advogado |
| 11 | ⚖️ **DPA com o MentAll.** Está em minuta e **não assinado**; os anexos obrigatórios ainda não existem (`04_papeis_e_contrato_controlador_operador.md`, Parte C). Definir com o advogado se assinar com ressalva ou aguardar. | Seção 9 | NÃO CONFIRMADO — validar com advogado |
| 12 | **Fluxo de trabalho real versus lacunas do produto.** O app não registra consentimento, não tem canal de titular, não tem evento de auditoria de eliminação nem de áudio e o backup é incompleto. Este guia assume controle manual em papel como contingência — o que **não** substitui a correção do produto (documento 02, P1.5, P1.8, P2.2, P2.5, P2.15). | Todo o guia | Ação de produto + validação jurídica |
| 13 | **Revisão jurídica registrada.** Após validação, preencher: advogado(a), OAB, data — e incrementar a versão para 1.1. | Todo o documento | Pendente |
