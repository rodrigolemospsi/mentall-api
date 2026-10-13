# Encarregado (DPO) e Canal do Titular — MentAll PRO

**Versão:** 1.0 (rascunho para revisão jurídica) · **Data:** 09/10/2026 · **Próxima revisão:** 09/04/2027
**Aplicação:** MentAll PRO (controlador dos dados de conta e telemetria; operador dos dados clínicos) e
o psicólogo usuário (controlador dos dados clínicos)
**Natureza:** documento de trabalho. **Não é parecer jurídico.** Todo item marcado ⚖️ depende de
validação por advogado especializado antes de virar nomeação, publicação ou compromisso público.

> **Como ler.** Este documento resolve duas lacunas apontadas no diagnóstico
> (`01_diagnostico_lgpd.md` §4.4 e §4.6): **não existe encarregado nomeado nem canal do titular**, e a
> Política atual apenas diz "entre em contato com o desenvolvedor do MentAll PRO"
> (`politica_privacidade_page.dart:119-122`). Ele traz o **ato de nomeação**, o **procedimento em 6
> passos** com prazos, os **modelos de resposta** e o **registro de solicitações**. O MentAll PRO
> **não possui certificação nem declaração de conformidade plena**: está **em adequação**.

---

## 1. Objetivo

1. Definir **quem** precisa de encarregado (DPO) neste arranjo de dois controladores.
2. Formalizar **como** nomear, **o que** publicar e **por quanto tempo** manter o registro.
3. Criar o **canal do titular** com proteção contra coleta excessiva de dado sensível.
4. Descrever o **procedimento interno em 6 passos**, com prazos legais e responsáveis.
5. Entregar **modelos** de resposta por tipo de pedido e o **registro** de solicitações.
6. Tratar o caso específico do **pedido sobre dado clínico** ⚖️.
7. Registrar a **recomendação formal** sobre o endereço `dpo@mentallpro.com.br` — sem presumir que
   ele esteja ativo ou publicado.

---

## 2. Quem precisa de encarregado neste arranjo ⚖️

O art. 41 da LGPD determina que **o controlador** indique encarregado. Aqui há **dois controladores**,
para conjuntos de dados diferentes (`04_papeis_e_contrato_controlador_operador.md`, Parte B):

| Quem trata | Papel | Precisa de encarregado? | Fundamento |
|---|---|---|---|
| **MentAll PRO** — conta do profissional, telemetria, segurança, logs e painel | **Controlador** | **SIM, obrigatoriamente** | Art. 41, *caput*. É este encarregado que atende o **profissional usuário** |
| **MentAll PRO** — prontuário, áudio, IA, anamnese, contrato, lembretes | **Operador** | **Facultativo**, mas **boa prática** (a Res. CD/ANPD nº 18/2024 admite a indicação pelo operador) | Art. 41 + art. 39; utilidade prática: o titular que procura o app precisa de uma porta de entrada única |
| **Psicólogo** — dados clínicos das pessoas atendidas | **Controlador** | ⚖️ **Sim, em tese** — mas o exercício é tipicamente feito pelo próprio profissional, sem estrutura de DPO | Art. 41, *caput* |

### 2.1 Consequências práticas (é isto que precisa de decisão jurídica)

1. **O encarregado do MentAll não "cobre" o psicólogo.** Se o titular pedir eliminação de dado clínico
   ao MentAll, o encarregado do MentAll **não decide o mérito** — encaminha ao psicólogo e registra
   (cláusula 9 da minuta do documento 04).
2. **O titular não deve ser obrigado a saber de quem é o dado.** O canal do MentAll precisa funcionar
   como **porta de entrada única**: recebe, classifica, encaminha ao controlador competente e
   responde ao titular com o andamento — sem obrigá-lo a adivinhar o responsável.
3. **O psicólogo individual (pessoa natural) precisa de solução simples.** A recomendação prática é
   que o MentAll ofereça **canal e procedimento prontos** (este documento) e que o profissional os
   **assuma como seus** no material do titular (documento 07), com o nome e o contato dele. ⚖️
4. **Vedação de conflito de interesse** (Res. CD/ANPD nº 18/2024): o encarregado não pode ter
   atribuição que o leve a decidir contra o interesse do titular. No MentAll, o encarregado **não
   deve** ser o único responsável pela área comercial.

### 2.2 Decisão pendente ⚖️

| Opção | Vantagem | Custo/risco |
|---|---|---|
| (a) **Encarregado único do MentAll**, que atende profissional, titular e psicólogo como porta de entrada | Simples, publicável rápido, atende ao art. 41 para os dados de conta/telemetria | Não resolve formalmente o art. 41 do psicólogo como controlador clínico |
| (b) **Encarregado do MentAll + orientação ao psicólogo** para que ele se identifique como ponto de contato clínico | Cobre os dois papéis na prática; mantém a decisão clínica com o profissional | Exige clareza no texto ao titular (documento 07) |
| (c) **Encarregado pessoa jurídica terceirizado** (a Res. 18/2024 permite) | Independência e menor conflito de interesse | Custo recorrente; exige contrato e dever de sigilo |

> **Recomendação técnica:** combinar **(a) + (b)** — nomear um encarregado do MentAll e orientar o
> psicólogo a se identificar como **controlador** e ponto de contato clínico, mantendo o canal do
> MentAll como porta de entrada única. A decisão final é jurídica. ⚖️

---

## 3. Atribuições do encarregado

Base: **art. 41, §2º, da LGPD** e **Res. CD/ANPD nº 18/2024**.

| # | Atribuição | Como se materializa |
|---|---|---|
| 3.1 | **Receber reclamações e comunicações dos titulares** | Operar o canal (formulário + e-mail); abrir protocolo para cada solicitação |
| 3.2 | **Receber comunicações da ANPD** | Caixa e endereço monitorados; responder nos prazos com apoio jurídico |
| 3.3 | **Prestar esclarecimentos e adotar providências** | Responder ao titular nos prazos do §7; encaminhar ao controlador competente; acompanhar até o encerramento |
| 3.4 | **Orientar funcionários e contratados** sobre proteção de dados | Treinamento (§11 do documento 12) e consulta interna obrigatória |
| 3.5 | **Ser ouvido em decisões sobre proteção de dados** | RIPD (documento 08), ROPA (documento 03), incidentes (documento 11), novos fornecedores e novas finalidades |
| 3.6 | **Fiscalizar o cumprimento da LGPD** | Revisões periódicas, indicadores (§12), registro de achados |
| 3.7 | **Executar e manter o registro das operações** | ROPA vivo e atualizado (art. 37) |
| 3.8 | **Coordenar a resposta a incidentes** | Acionar o documento 11; apoiar comunicação à ANPD e ao titular |
| 3.9 | **Zelar pelo canal e pelos prazos** | Registro de solicitações obrigatório (§9) |

**Nota de honestidade:** nenhuma dessas atribuições existe hoje — não há encarregado, canal,
procedimento, registro nem indicador (`01_diagnostico_lgpd.md` §4.6; `07_aviso_de_privacidade_e_termo_de_consentimento.md`
item 12 da tabela de pendências). Este documento é o instrumento que precede a implementação.

---

## 4. Como nomear e publicar

### 4.1 Ato formal de nomeação (requisitos)

Conforme a **Res. CD/ANPD nº 18/2024**, o ato de indicação do encarregado deve ser:

| Requisito | Conteúdo mínimo | Observação |
|---|---|---|
| **Forma** | Ato **formal, escrito, datado e assinado** | Não serve indicação verbal nem aviso de site |
| **Identidade** | Nome/Razão social; se pessoa física, CPF ou identificação equivalente; se pessoa jurídica, CNPJ e responsável | **Pessoa jurídica pode ser encarregada** |
| **Contato** | E-mail dedicado e, se houver, endereço postal e telefone | Precisa ser **funcional e monitorado** |
| **Substituto** | Indicação de **substituto** (nome, contato) para ausências | Exigência da Res. 18/2024 |
| **Ausência de conflito de interesse** | Declaração expressa de que a função não conflita com outras atribuições | Ex.: não ser o único responsável comercial |
| **Vigência e revisão** | Data de início; hipóteses de substituição | Revisar a cada troca de pessoa |
| **Publicidade** | Divulgação pública do ato ou dos dados de identificação/contato | §5 |
| **Registro** | Guarda do ato assinado no repositório de governança | Vinculado ao documento 17 (registro de decisões) |

**Minuta do ato (a preencher e assinar):**

> **ATO DE NOMEAÇÃO DE ENCARREGADO PELO TRATAMENTO DE DADOS PESSOAIS**
>
> Pelo presente ato, `[RAZÃO SOCIAL DO MENTALL PRO]`, CNPJ nº `[...]`, representada na forma de seus
> atos constitutivos, nomeia como **Encarregada pelo Tratamento de Dados Pessoais**, nos termos do
> art. 41 da Lei nº 13.709/2018 e da Resolução CD/ANPD nº 18/2024:
>
> **Nome/Razão social:** `[...]` · **CPF/CNPJ:** `[...]` · **E-mail:** `[...]` ·
> **Telefone/endereço:** `[...]` · **Substituto:** `[...]` (`[...]`) · **Início:** `[...]`
>
> A nomeada declara **não ter conflito de interesse** com a função e compromete-se a desempenhar as
> atribuições do art. 41, §2º, da LGPD e da Res. CD/ANPD nº 18/2024.
>
> Local, data. — Assinatura do representante legal / Assinatura da encarregada.

### 4.2 O que publicar, onde

| Onde | O que publicar | Estado hoje |
|---|---|---|
| **Site institucional** (URL pública) | Nome (ou razão social) do encarregado + canal + prazo de resposta | **NÃO EXISTE** — o site irmão só tem `index.html` (`tasks/lojas_app.md:32-34`) |
| **Política de Privacidade publicada** | Seção "Contato e encarregado" (documento 05 §15) | Seção existe, com campos a preencher |
| **App** (tela de privacidade e seção de direitos) | Mesmo texto da política + botão de contato | Hoje diz só "fale com o desenvolvedor" (`politica_privacidade_page.dart:119-122`) |
| **Termos de Uso** | Canal de privacidade | Placeholder (`06_termos_de_uso.md:159`) |
| **Ficha da loja (Play/Apple)** | Contato de privacidade e URL de exclusão de conta | **Não produzidos** (P1.10) |
| **Material do titular** (documento 07) | Canal do MentAll + orientação de falar primeiro com o psicólogo | Em elaboração |
| **Contrato/DPA** (Anexo, documento 04) | Como o MentAll avisa o controlador e encaminha pedidos | Minuta pronta |

**Regra de coerência:** o mesmo nome, o mesmo e-mail e o mesmo prazo precisam aparecer **em todos**
os lugares acima. Divergência é informação enganosa ao titular.

---

## 5. Canal do titular

### 5.1 Desenho do canal

| Elemento | Definição proposta |
|---|---|
| **Porta de entrada principal** | Formulário público no site **+** e-mail dedicado (não caixa pessoal de colaborador) |
| **Porta de entrada secundária** | Botão no app, para o profissional usuário |
| **Porta de entrada indireta** | O psicólogo (material do documento 07) — o titular deve poder falar com quem o atende |
| **Registro** | Toda solicitação gera **protocolo** e entra no registro do §9 |
| **Confirmação de recebimento** | Resposta automática imediata com protocolo e prazo aplicável |
| **Acessibilidade** | Linguagem simples; opção de atendimento presencial/telefone pelo psicólogo |
| **Prazo declarado** | Publicar o prazo **real** que se consegue cumprir, dentro do limite legal (§7) |

### 5.2 Minimização: o canal **não** deve coletar dado sensível em excesso

Este é o ponto mais delicado: um formulário de privacidade mal desenhado **cria** um novo banco de
dados sensíveis.

**Regras obrigatórias:**

1. **Nunca pedir dado clínico no formulário.** Não perguntar diagnóstico, queixa, medicação, conteúdo
   de sessão ou nome de terceiros. Para pedidos clínicos, o canal apenas **identifica e encaminha** —
   lembrando que, no caso clínico, o **titular é a pessoa atendida**, que normalmente **não é usuária
   do aplicativo**.
2. **Campos mínimos do formulário:** nome, forma de contato (e-mail ou telefone), tipo de pedido
   (lista fechada do art. 18), descrição **livre e opcional** do que se pede, e identificação do
   profissional ou do serviço a que se refere. A caixa de texto deve trazer o aviso **"não descreva
   informação clínica aqui"**.
3. **Aviso de canal inseguro:** e-mail e formulário **não** são canais adequados para conteúdo
   clínico. A entrega de conteúdo clínico deve ocorrer pelo psicólogo, em meio adequado
   (documento 07 §5 e §9).
4. **Retenção do registro de solicitação:** guardar **o registro do pedido e da resposta** pelo prazo
   necessário à demonstração (proposta: **5 anos**, alinhado ao prazo de guarda dos registros de
   incidentes da Res. CD/ANPD nº 15/2024 ⚖️ e ao piso do prontuário), **sem** anexar conteúdo clínico
   ao registro do canal.
5. **Acesso restrito:** só o encarregado e o substituto acessam a caixa; acesso com registro.

---

## 6. Procedimento interno em 6 passos

### Passo 1 — Receber

- Registrar **data e hora de entrada**, canal de origem e protocolo.
- Enviar **confirmação de recebimento** ao titular no mesmo dia útil, com o prazo aplicável.
- ⏱️ O prazo legal começa a correr **do recebimento**, não da classificação.

### Passo 2 — Confirmar a identidade

- Conferir se quem pede é o **titular**, o **representante legal** (obrigatório no caso de criança ou
  adolescente — art. 14 e ECA Digital, Lei nº 15.211/2025) ou procurador com poderes.
- **Não coletar mais do que o necessário**: nome completo + um dado de verificação já existente no
  cadastro/registro (ex.: confirmação do vínculo com o profissional). **Nunca** pedir cópia de
  documento com dado sensível sem necessidade.
- Se a identidade não puder ser confirmada, **não** entregar o dado: responder explicando o motivo e
  o que é necessário.

### Passo 3 — Classificar

Classificar o pedido em uma das categorias do art. 18 (e do art. 20, quando for revisão de decisão
automatizada) e identificar **o controlador competente**:

| Categoria | Controlador competente |
|---|---|
| Confirmação/acesso, correção, eliminação, portabilidade, informação sobre compartilhamento de **dado clínico** | **Psicólogo** |
| Revogação de consentimento para IA, áudio ou WhatsApp | **Psicólogo** (decide) + MentAll (executa o descarte operacional) |
| Conta, telemetria, logs, segurança, exclusão de conta do profissional | **MentAll** |
| Incidente que afete o titular | **Quem controla o dado afetado**; com apoio do encarregado do MentAll |

### Passo 4 — Encaminhar ao psicólogo quando o pedido for clínico

- Encaminhar **no mesmo dia útil**, com protocolo, prazo e o roteiro do §10.
- Registrar **data e forma do encaminhamento**.
- **O MentAll não responde pelo mérito clínico e não elimina prontuário por conta própria.**
- Se o psicólogo não responder dentro do prazo, o encarregado **cobra**, registra a cobrança e informa
  o titular sobre o andamento (sem expor o conteúdo clínico).

### Passo 5 — Responder

- **Sempre por escrito**, mesmo que haja conversa telefônica.
- A resposta deve dizer: **o que foi pedido**, **o que foi atendido**, **o que não foi atendido e por
  quê**, **o prazo de guarda aplicável** e **o que fazer se discordar** (peticionar à ANPD — art. 18,
  §1º, e endereço [gov.br/anpd](https://www.gov.br/anpd/pt-br)).
- Formato (art. 18, §3º): **expresso, claro e adequado**, em meio eletrônico ou impresso, conforme a
  preferência do titular. Para acesso/confirmação: **simplificado imediato** ou **declaração clara e
  completa em até 15 dias** (art. 19, I e II).

### Passo 6 — Registrar e encerrar

- Preencher o **registro de solicitações** (§9) com decisão, fundamento e evidência de entrega.
- Arquivar cópia da solicitação e da resposta (sem conteúdo clínico no registro do canal).
- Indicador atualizado (§12). Só encerrar com **resposta comprovadamente entregue** ou com
  **esgotamento do prazo documentado**.

### 6.1 Prazos aplicáveis (resumo operacional)

| Pedido | Prazo legal | Como declarar ao titular |
|---|---|---|
| **Confirmação de existência de tratamento** e **acesso** | **Imediato**, em formato simplificado; se não for possível, **declaração clara e completa em até 15 dias** do pedido | "Responderemos imediatamente, de forma simplificada; o detalhamento completo sai em até 15 dias (LGPD, art. 19, I e II)" |
| **Correção, anonimização, bloqueio, eliminação, portabilidade, informação sobre compartilhamento, informação sobre não consentir, oposição, revogação** | **Imediato**; não sendo possível, no **menor prazo possível**, com indicação das providências (art. 18, §4º) | Publicar um prazo **real** (proposta: **até 15 dias**), explicitando que a lei não fixa prazo em dias para esses itens ⚖️ |
| **Revisão de decisão automatizada (art. 20)** | Mediante requisição, com **informação sobre critérios e procedimentos**; a revisão é **humana** | "A IA é apoio documental; a revisão é sempre feita pelo profissional" |
| **Peticionar contra o controlador à ANPD** | Direito autônomo do titular (art. 18, §1º) | Informar o endereço da ANPD em toda resposta negativa |

> ⚠️ A lei **não fixa prazo em dias** para os itens que não são acesso/confirmação. O dever é
> **atender sem demora**; declarar "15 dias" para tudo é escolha operacional — que precisa caber na
> capacidade real de resposta. ⚖️

---

## 7. Modelos de resposta por tipo de pedido

> Adaptar sempre; nunca copiar sem ler. Campos `[...]` são obrigatórios. Toda resposta inclui o
> protocolo, o prazo aplicável e o caminho de recurso à ANPD.

**7.1 Confirmação e acesso**

> Prezado(a) `[nome]`, em resposta ao protocolo nº `[___]`, **confirmamos** que tratamos dados a você
> relacionados no âmbito do atendimento realizado por `[profissional]`. Em anexo/como abaixo, segue a
> relação dos dados e o acesso correspondente, em formato `[eletrônico/impresso]`. Este é o
> atendimento simplificado; caso você precise da declaração clara e completa, ela será enviada em até
> **15 dias** (LGPD, art. 19, II).

**7.2 Correção**

> Registramos a correção de `[descrever o dado]` para `[novo valor]`, em `[data]`. Os dados que
> integram o registro documental psicológico são atualizados com a devida anotação da alteração; se a
> correção não for possível por razão técnica ou clínica, você será informado do motivo.

**7.3 Anonimização, bloqueio ou eliminação (dado em desconformidade)**

> Atendemos o pedido: `[anonimizamos / bloqueamos / eliminamos]` `[descrever]` em `[data]`. Fundamento
> e efeito prático: `[...]`. Não há conservação além do necessário para `[...]`.

**7.4 Eliminação de dado sob guarda obrigatória (resposta parcial)** ⚖️

> Parte do que você pede integra o **prontuário psicológico**, cuja guarda é exigida por **no mínimo 5
> (cinco) anos** (Resolução CFP nº 001/2009, art. 4º, §1º), prazo que pode ser ampliado por lei ou
> decisão judicial. A LGPD autoriza essa conservação para cumprimento de obrigação legal ou
> regulatória (**art. 16, I**) e **ressalva** essa hipótese no direito de eliminação (**art. 18, VI**).
> **O que não está sob guarda obrigatória foi eliminado**, conforme detalhado: `[...]`. Se você
> discordar, pode peticionar à ANPD.

**7.5 Portabilidade**

> Em atendimento ao art. 18, V, segue `[formato]` com os dados `[...]`, incluindo `[observação sobre
> formato e limitações — ex.: registros clínicos podem exigir interpretação técnica]`. A portabilidade
> não inclui dados de terceiros nem conteúdo protegido por sigilo de outra pessoa.

**7.6 Informação sobre compartilhamento**

> Informamos que os dados do atendimento são tratados com apoio dos seguintes terceiros:
> `[lista objetiva com país e finalidade — ver documento 05 §4]`. Fundamento da transferência:
> `[...]` ⚖️.

**7.7 Revogação de consentimento**

> Registramos a revogação, em `[data]`, do consentimento para `[finalidade: transcrição por IA /
> síntese / lembrete por WhatsApp]`. Efeitos imediatos: `[o recurso deixa de ser usado; o dado
> correspondente será eliminado, salvo o que integra o prontuário sob guarda]`. A revogação não afeta
> o tratamento realizado antes dela com base no consentimento.

**7.8 Oposição / informação sobre não consentir**

> Você tem o direito de se opor a tratamento que não se justifique (art. 18, §2º) e de não consentir,
> sendo informado das consequências. No caso de `[...]`, a consequência de não consentir é `[...]`
> (ex.: o relato será digitado em vez de transcrito; o lembrete não será enviado).

**7.9 Revisão de decisão automatizada (art. 20)**

> A geração de síntese por IA é **apoio documental**: não há decisão tomada unicamente por tratamento
> automatizado. Os critérios e procedimentos são `[...]`, e a revisão é sempre **humana**, feita pelo
> profissional `[nome]`. Solicitamos a revisão, que será registrada em `[data]`.

**7.10 Encarregado do MentAll não é o controlador do dado clínico**

> Sua solicitação envolve **dados clínicos**, cujo controlador é o(a) psicólogo(a) `[nome]`, que
> realiza o atendimento. Encaminhamos o pedido a ele(a) em `[data]`, sob o protocolo nº `[___]`, e
> acompanharemos o prazo de resposta. O MentAll PRO atua como **operador tecnológico** e não decide
> sobre o conteúdo clínico (LGPD, art. 5º, VII).

---

## 8. Modelo do registro de solicitações

Planilha ou sistema com os campos abaixo. **Não anexar conteúdo clínico** ao registro do canal.

| # | Campo | Conteúdo | Obrigatório |
|---|---|---|---|
| 1 | Protocolo | `AAAA-NNNN` | Sim |
| 2 | Data/hora de entrada | Timestamp do recebimento | Sim |
| 3 | Canal | Formulário / e-mail / app / psicólogo / ANPD / outro | Sim |
| 4 | Titular | Nome e forma de contato | Sim |
| 5 | Representante legal | Nome e vínculo, quando aplicável (art. 14) | Quando aplicável |
| 6 | Tipo de pedido | Lista fechada do art. 18 (+ art. 20) | Sim |
| 7 | Dado/atividade envolvida | Categoria (sem conteúdo clínico) | Sim |
| 8 | Controlador competente | Psicólogo / MentAll | Sim |
| 9 | Identidade confirmada | Sim/Não + método + data | Sim |
| 10 | Prazo aplicável | Imediato / 15 dias / outro | Sim |
| 11 | Data-limite | Calculada | Sim |
| 12 | Encaminhamento | Data, destinatário e forma | Quando houver |
| 13 | Decisão | Atendido / parcial / negado / encaminhado | Sim |
| 14 | Fundamento | Dispositivo e motivo (ex.: art. 16, I + Res. CFP 001/2009) | Sim |
| 15 | Data e forma da resposta | Data + canal de entrega | Sim |
| 16 | Evidência de entrega | Comprovante/confirmação | Sim |
| 17 | Situação | Aberto / em prazo / vencido / encerrado | Sim |
| 18 | Lição aprendida | Falha de produto ou de processo identificada | Recomendado |

**Campos derivados para indicadores:** tempo de resposta, cumprimento de prazo, taxa de
encaminhamento ao psicólogo, motivo recorrente.

---

## 9. Pedido sobre dado clínico ⚖️

1. **A decisão é do psicólogo** (controlador). O encarregado do MentAll **não** avalia mérito clínico
   e **não** autoriza eliminação de prontuário.
2. **O acesso quase sempre pode ser atendido.** A Res. CFP nº 001/2009, art. 5º, II, garante **acesso
   integral ao usuário ou ao representante legal**. O psicólogo pode precisar de **linguagem técnica e
   destinação adequada** para não causar dano, e o CFP admite restrição de compartilhamento em
   situações específicas, com registro documental sigiloso (art. 1º) — isso **não elimina** o direito
   de acesso, mas muda **como** ele é entregue. ⚖️
3. **A eliminação é limitada pela guarda legal** (art. 16, I) — roteiro completo no documento 10 §7.
4. **Menores:** pedido deve vir do **responsável legal** ou com sua participação (art. 14 + ECA
   Digital, Lei nº 15.211/2025, vigente desde 17/03/2026).
5. **O que o MentAll faz:** encaminha, acompanha o prazo, apoia tecnicamente (exportação), registra o
   encaminhamento e informa o titular sobre o andamento. **Não** responde pelo mérito, **não** elimina
   prontuário, **não** altera conteúdo clínico.
6. **Honestidade sobre o estado atual:** hoje os dados no servidor (contrato, anamnese, lembretes)
   **não podem ser apagados** — não há rotina de expurgo nem endpoint de exclusão
   (`db.py:179-314`). Enquanto isso não for corrigido, a resposta ao titular **deve dizer a verdade**
   sobre a impossibilidade e o prazo para corrigir. ⚖️

---

## 10. Relação com a ANPD

| Situação | O que fazer | Base |
|---|---|---|
| **Comunicação de incidente** | Comunicar à ANPD em até **3 dias úteis** do conhecimento (em dobro para agente de pequeno porte ⚖️), com os **12 itens** mínimos; complementar em **20 dias úteis**; guardar o registro por **5 anos, inclusive dos incidentes não comunicados** | Art. 48 + Res. CD/ANPD nº 15/2024 |
| **Requisição da ANPD** | Responder nos prazos indicados, com apoio jurídico; registrar tudo | Art. 41, §2º, II; Lei nº 15.352/2026 (ANPD como **Agência Nacional de Proteção de Dados**) |
| **Titular insatisfeito** | Informar o caminho de petição à ANPD em **toda** resposta negativa | Art. 18, §1º |
| **Fiscalização temática** | Manter ROPA, RIPD, retenção e incidentes prontos para exibição; a ANPD incluiu **IA e tecnologias emergentes** nos temas prioritários de 2026-2027 (Res. CD/ANPD nº 30/2025) | — |
| **Transferência internacional** | EUA e China **não** têm adequação (só a UE/EEE — Res. CD/ANPD nº 32, de 26/01/2026); o mecanismo do art. 33 precisa estar documentado (Res. CD/ANPD nº 19/2024) | Arts. 33-36 ⚖️ |

---

## 11. Indicadores

| Indicador | Meta | Fonte |
|---|---|---|
| Solicitações recebidas no mês | — (medida) | Registro §8 |
| **% respondidas dentro do prazo** | **100%** | Registro §8 |
| Tempo médio de resposta (confirmação/acesso) | ≤ 15 dias | Registro §8 |
| Tempo médio de resposta (demais pedidos) | ≤ 15 dias (prazo declarado) ⚖️ | Registro §8 |
| Pedidos encaminhados ao psicólogo sem resposta no prazo | **0** | Registro §8 |
| Reclamações recorrentes (mesmo motivo 2× ou mais) | 0 sem ação aberta | Registro + documento 02 |
| Requisições da ANPD respondidas no prazo | 100% | Registro interno |
| Incidentes comunicados no prazo | 100% | Documento 11 |
| Atualização do ato de nomeação/publicação | ≤ 30 dias após qualquer troca | §4 |

---

## 12. Recomendação sobre `dpo@mentallpro.com.br`

O endereço **está previsto no projeto**, mas **não se presume ativo nem publicado**. Decisão formal a
tomar — recomendação técnica em passos:

| # | Passo | Observação |
|---|---|---|
| 1 | **Confirmar** que o domínio `mentallpro.com.br` está sob controle do MentAll e que a caixa existe | O domínio aparece como origem autorizada na API (`main.py:653-654`); isso **não** prova que o e-mail funcione |
| 2 | **Decidir o endereço definitivo** — `dpo@` ou `privacidade@`/`encarregado@` | `dpo@` é aceito e comum; `privacidade@` costuma ser mais claro ao titular. Escolher **um** e usar em todos os canais |
| 3 | **Garantir operação**: caixa dedicada (não pessoal), acesso restrito, resposta automática com protocolo e prazo | Sem isso, o canal **piora** a situação: gera expectativa e perde prazo |
| 4 | **Publicar apenas depois** do ato de nomeação assinado (§4.1) | Publicar canal sem encarregado nomeado é informação incoerente |
| 5 | **Definir retenção da caixa** e o que **não** pode ser recebido nela (conteúdo clínico) | Ver §5.2; proposta de guarda do registro: 5 anos ⚖️ |
| 6 | **Testar o caminho completo** (envio → protocolo → classificação → resposta) antes de divulgar | Registrar o teste no documento 17 |
| 7 | **Manter o substituto** com acesso à caixa e ao registro | Exigência da Res. CD/ANPD nº 18/2024 |

**Recomendação:** adotar `dpo@mentallpro.com.br` **se** os passos 1, 3 e 6 forem cumpridos; caso
contrário, **não publicar** e manter, provisoriamente, o contato pelo psicólogo (documento 07 §5) —
com a ressalva expressa de que o MentAll ainda **não possui** encarregado nomeado nem canal público
(`politica_privacidade_page.dart:119-122`).

**Decisões que precisam ser registradas** no `17_registro_de_decisoes_e_revisoes.md`:

| Decisão | Opções | Impacto se não decidir |
|---|---|---|
| **Quem é o encarregado** e com que escopo (só MentAll controlador × também porta de entrada do dado clínico) | (a) encarregado único do MentAll; (b) + orientação ao psicólogo; (c) PJ terceirizada | O art. 41 continua descumprido e o titular segue sem canal |
| **Substituto** designado | Nomear e publicar | Ausência/afastamento deixa o canal sem resposta e o prazo correndo |
| **Endereço definitivo do canal** | `dpo@` × `privacidade@` × `encarregado@` | Publicação de canal que não funciona é pior do que não publicar |
| **Escopo do registro de solicitações** e sua retenção | 5 anos × outro prazo ⚖️ | Sem registro, não há indicador nem defesa em fiscalização |

---

## Pendências de validação jurídica

| # | Pendência | Onde impacta | Situação |
|---|---|---|---|
| 1 | ⚖️ **Quem deve indicar encarregado** neste arranjo de dois controladores, e se o psicólogo pessoa natural precisa de ato próprio ou pode ser representado pelo canal do MentAll. | §2 | NÃO CONFIRMADO |
| 2 | ⚖️ **Forma e conteúdo do ato de nomeação** conforme a Res. CD/ANPD nº 18/2024 (incluindo substituto e declaração de conflito de interesse). | §4.1 | MINUTA PRONTA — validar redação |
| 3 | ⚖️ **Encarregado pessoa jurídica** (permitido pela Res. 18/2024): decidir entre pessoa interna e terceiro. | §2.2 | DECISÃO PENDENTE |
| 4 | ⚖️ **Prazo operacional a declarar** para os pedidos do art. 18 que não são acesso/confirmação (a lei manda "sem demora", sem prazo em dias). | §6.1, §7 | NÃO CONFIRMADO |
| 5 | ⚖️ **Conteúdo e limites da resposta ao titular** sobre dado clínico: como conciliar acesso integral (Res. CFP 001/2009, art. 5º, II) com a restrição de compartilhamento em situações específicas (art. 1º). | §9 | NÃO CONFIRMADO |
| 6 | ⚖️ **Retenção do registro de solicitações** (proposta de 5 anos) e sua base. | §5.2, §8 | NÃO CONFIRMADO |
| 7 | ⚖️ **Enquadramento como agente de pequeno porte** e efeitos sobre prazos, encarregado e registro. | §6.1, §10 | NÃO CONFIRMADO |
| 8 | ⚖️ **Relação com o incidente** e quem assina as comunicações à ANPD (encarregado, representante legal ou ambos). | §10 | depende do documento 11 |
| 9 | ⚖️ **Efeito da revogação de consentimento sobre dado já incorporado ao prontuário** (texto do modelo 7.7). | §7.7 | NÃO CONFIRMADO |
| 10 | ⚖️ **Decisão formal sobre o endereço do canal** e registro do teste ponta a ponta antes da publicação. | §12 | DECISÃO PENDENTE |

> Este documento **não é parecer jurídico**. A nomeação só produz efeito após o **ato formal assinado**
> e a **divulgação pública** — e nenhuma das duas coisas existe hoje.
