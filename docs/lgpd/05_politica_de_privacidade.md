# Política de Privacidade — MentAll PRO

**Versão:** 1.1 · **Data:** 13/10/2026 · **Próxima revisão:** 09/04/2027 (ou a cada mudança relevante)
**Aplicação:** aplicativo MentAll PRO (Android e iOS) e site institucional

> ⚠️ **NOTA DE PUBLICAÇÃO (não publicar esta nota junto com o texto):** este texto só pode ir ao ar
> **depois de concluídos os itens P0 do plano de ação** (`02_plano_de_acao.md`), porque descreve
> compartilhamentos que hoje já existem, mas cujas salvaguardas ainda não foram formalizadas, e
> porque a versão publicada precisa ser **idêntica** à versão exibida no app. Pontos marcados com ⚖️
> dependem de revisão jurídica. As telas in-app
> (`politica_privacidade_page.dart`) precisam ser atualizadas para refletir este texto.

> **Aviso:** este documento descreve como o MentAll PRO trata dados pessoais. Ele **não substitui** o
> aviso que o profissional de psicologia entrega à pessoa atendida (documento 07). O MentAll PRO
> **não é** um serviço de saúde e **não** realiza atendimento.

---

## 1. Quem faz o quê (papéis)

O MentAll PRO é um **software de prontuário** usado por psicólogas e psicólogos. Quem atende é o
profissional. Isso define duas posições distintas na Lei Geral de Proteção de Dados (LGPD):

| Quem | Papel | Sobre quais dados |
|---|---|---|
| **Profissional de psicologia** (usuário do app) | **Controlador** | Prontuário, sessões, relatos, áudio, transcrições, sínteses, anamnese e contrato terapêutico das pessoas que atende |
| **MentAll PRO** (fornecedor do software) | **Operador** | Os mesmos dados, tratados **em nome e por instrução** do profissional |
| **MentAll PRO** | **Controlador** | Dados da **conta do profissional** (nome, e-mail, senha protegida por hash, plano) e **telemetria técnica** (sem conteúdo clínico) |

Na prática: **quem decide sobre o conteúdo clínico é o profissional**. O MentAll PRO responde por
tratar esses dados de forma segura, pela finalidade contratada e pelas instruções recebidas — e
responde solidariamente se descumprir a LGPD.

---

## 2. Quais dados são tratados

**a) Dados da pessoa atendida** (inseridos pelo profissional):
nome, data de nascimento, contato, e-mail, observações, tipo de atendimento, dados financeiros do
atendimento (valor e forma de pagamento, quando registrados) e dados de agendamento.

**b) Dados clínicos (dados pessoais sensíveis de saúde — art. 11 da LGPD):**
relato da sessão, anotações, transcrição, síntese e apontamentos gerados com apoio de IA, respostas
de anamnese, contrato terapêutico e histórico de sessões.

**c) Áudio:** o relato pós-sessão ditado pelo profissional (até 5 minutos). **O aplicativo não se
destina a gravar a sessão com a pessoa atendida.**

**d) Dados do profissional:** nome, registro profissional (CRP), abordagem clínica, preferências,
e-mail de acesso e senha (armazenada apenas como hash).

**e) Dados técnicos:** identificador de dispositivo (UUID aleatório), plataforma, versão do app,
**tipo** de evento de uso (lista fechada, sem conteúdo clínico), registros de erro técnico e de
segurança, endereço IP em requisições.

**O MentAll PRO não coleta** dados de localização, contatos, agenda do aparelho, fotos ou histórico de
navegação. **Não há** anúncios, rastreadores de marketing ou venda de dados.

---

## 3. Para que tratamos e com qual fundamento

| Finalidade | Dados | Fundamento (LGPD) |
|---|---|---|
| Registrar e organizar o prontuário psicológico | Dados da pessoa atendida e dados clínicos | Tutela da saúde (art. 11, II, "f") — decisão do profissional ⚖️ |
| Transcrever o relato em áudio | Áudio | Consentimento específico do titular + tutela da saúde ⚖️ |
| Organizar o relato em síntese e acompanhar evolução com apoio de IA | Relato, transcrição, escalas | Consentimento específico e destacado (art. 11, I) por envolver transferência a terceiros ⚖️ |
| Enviar link de anamnese e de contrato terapêutico | Nome, respostas, aceite | Execução do contrato de atendimento e tutela da saúde ⚖️ |
| Enviar lembretes de sessão por WhatsApp | Nome, telefone, data/hora | Consentimento específico do titular ⚖️ |
| Autenticar e manter a conta do profissional | Nome, e-mail, senha (hash) | Execução de contrato (art. 7º, V) |
| Medir uso e presença do app (telemetria) | UUID do dispositivo, plataforma, versão, tipo de evento | Legítimo interesse (art. 7º, IX), com dados minimizados e sem conteúdo clínico ⚖️ |
| Segurança, prevenção a fraude e diagnóstico de falhas | IP, registros de acesso e erro | Legítimo interesse e cumprimento de dever de segurança (art. 7º, II e IX; art. 46) |
| Cumprir obrigações legais e regulatórias | Conforme a obrigação | Art. 7º, II |

**Não usamos dados clínicos** para finalidade própria, marketing, melhoria de produto ou
treinamento de modelos de inteligência artificial.

---

## 4. Com quem os dados são compartilhados

O compartilhamento é **limitado ao necessário** para o funcionamento do serviço. Todos os terceiros
abaixo atuam como **operadores/subprocessadores** e estão vinculados a obrigações de confidencialidade
e segurança.

| Terceiro | Serviço | O que recebe | País |
|---|---|---|---|
| **Fly.io** | Hospedagem do backend | Trânsito dos dados da API | Brasil (região São Paulo) |
| **Turso / AWS** | Banco de dados do serviço | Contrato terapêutico, respostas de anamnese, telefone e conteúdo de lembretes, dados de conta e telemetria | **Estados Unidos** |
| **Groq** | Transcrição de áudio | **Áudio do relato** | **Estados Unidos** |
| **OpenAI** | Síntese e evolução com IA | **Relato clínico** e primeiro nome da pessoa atendida | **Estados Unidos** |
| **DeepSeek** | Síntese com IA (usado quando o provedor principal falha) | **Relato clínico** e primeiro nome da pessoa atendida | **China** |
| **Google (Gemini)** | Síntese com IA (presente no código, **fora da cascata de produção**) | Relato clínico, somente se reativado | Estados Unidos |
| **Google Calendar** (opcional) | Sincronização da agenda | Resumo do evento ("Sessão" ou título), data/hora e sala; **sem nome de paciente** por padrão | Internacional (Google) |
| **Sentry** | Relatório de erros (desativado por padrão) | Dados técnicos do erro, sem conteúdo clínico e sem identificação de usuário | Estados Unidos |
| **Provedor de e-mail** | Envio de verificação de conta e redefinição de senha | E-mail do profissional | Estados Unidos |
| **OpenAlex** | Sugestão de artigos científicos | Descritores clínicos do tema e e-mail do profissional | Internacional |
| **Conselho Federal de Psicologia / API de CRP** | Verificação do registro profissional | Número de CRP informado | Brasil |
| **Gateway de WhatsApp** | Envio de lembretes | Nome, telefone e texto do lembrete | A confirmar ⚖️ |
| **Google Play / Apple App Store** | Distribuição do app | Dados da conta de desenvolvedor e relatórios de falha da loja | Estados Unidos |

> A integração com o **Google Calendar** é opcional e só ocorre se o profissional conectar a própria
> conta. O app envia resumo genérico, data/hora e sala; não envia nome de paciente nem conteúdo
> clínico por padrão. A desconexão não apaga os eventos já criados no Google.

**Não vendemos, alugamos nem cedemos dados pessoais.** Fora dos casos acima, só há compartilhamento
por obrigação legal, ordem judicial ou autoridade competente.

---

## 5. Transferência internacional de dados

Parte do tratamento ocorre **fora do Brasil**:

- **Estados Unidos:** banco de dados (Turso/AWS), transcrição (Groq), IA (OpenAI, Google) e
  relatório de erros (Sentry);
- **China:** IA (DeepSeek), **quando o provedor principal apresenta falha e a geração é repetida
  automaticamente**.

A **União Europeia** é reconhecida pela ANPD como detentora de grau de proteção adequado
(Resolução CD/ANPD nº 32/2026) — **os Estados Unidos e a China não o são**. Por isso, essas
transferências dependem de **cláusulas contratuais padrão (Resolução CD/ANPD nº 19/2024)** ou de
**consentimento específico e destacado** do titular, e são objeto de **Relatório de Impacto (RIPD)**.
O MentAll PRO **está em processo de formalização dessas salvaguardas** — este item é tratado como
prioridade no plano de adequação. ⚖️

Se você não concordar com esse processamento, é possível **usar o app sem os recursos de IA**: a
transcrição e a síntese são acionadas manualmente, uma a uma, pelo profissional.

---

## 6. Uso de inteligência artificial

- A IA é **apoio documental**. **Não emite diagnóstico, não decide conduta e não substitui o
  julgamento clínico.**
- Todo conteúdo gerado **precisa ser revisado e validado pelo profissional** antes de integrar o
  prontuário — o app bloqueia o salvamento de sessão gerada por IA que não tenha sido marcada como
  revisada.
- Antes do envio, o **sobrenome da pessoa atendida é reduzido a iniciais** pelo aplicativo. Isso
  **reduz, mas não elimina**, a identificação: o relato clínico em si pode identificar a pessoa.
- **Não autorizamos** o uso do conteúdo enviado para treinamento de modelos. As condições de
  retenção de cada provedor estão em verificação e serão documentadas neste item. ⚖️
- Se a IA falhar, o sistema pode repetir o envio em **outro provedor** (inclusive fora do Brasil).
  A lista de provedores está na seção 4.

---

## 7. Segurança

Medidas adotadas:

- criptografia **por campo** dos dados clínicos no aparelho (AES-256-GCM), com a chave-mestra
  guardada no **Android Keystore** ou no **iOS Keychain**;
- bloqueio de acesso por biometria e/ou senha do aparelho — a **biometria é verificada apenas no
  aparelho** e **não é coletada nem enviada** ao MentAll PRO ou a terceiros;
- conexões do aplicativo sempre por **HTTPS**, com validação de certificado do servidor;
- trilha de auditoria local dos eventos relevantes;
- controle de acesso por profissional no servidor (isolamento por conta);
- backup cifrado (AES-GCM com autenticação HMAC), exportado apenas pelo próprio profissional;
- no relatório de erros, nenhuma informação clínica é enviada.

O MentAll PRO **está em processo de adequação** e há medidas em implementação, entre elas:
criptografia dos dados armazenados no servidor, exclusão definitiva de dados a pedido, ampliação dos
eventos de auditoria e proteção adicional contra captura de tela. **Nenhum sistema é infalível** —
por isso recomendamos manter o aparelho protegido e nunca compartilhar o prontuário por canais
inseguros.

---

## 8. Por quanto tempo guardamos

- **Prontuário psicológico:** guardado pelo profissional pelo prazo legal aplicável — **mínimo de 5
  anos**, conforme a Resolução CFP nº 001/2009, podendo ser maior por determinação legal, judicial ou
  por orientação do conselho profissional. ⚖️
- **Áudio do relato:** mantido apenas se o profissional optar por mantê-lo; do contrário, é descartado
  após a transcrição. ⚖️
- **Dados de conta:** enquanto a conta existir e pelo prazo necessário ao cumprimento de obrigações
  legais.
- **Telemetria e registros de segurança:** pelo prazo necessário às finalidades de segurança e
  diagnóstico, com descarte periódico.
- **Lembretes, anamnese e contrato:** pelo tempo necessário à finalidade e ao prazo de guarda acima.

Detalhamento completo em `10_politica_de_retencao_e_descarte.md`.

---

## 9. Seus direitos como titular

Se você é **pessoa atendida**, procure **primeiro o profissional que faz seu atendimento** — ele é o
controlador dos seus dados clínicos. Se você é **profissional usuário**, pode falar diretamente
conosco.

Você pode solicitar, a qualquer momento:

1. confirmação de que tratamos seus dados;
2. acesso aos dados;
3. correção de dados incompletos, inexatos ou desatualizados;
4. anonimização, bloqueio ou eliminação de dados desnecessários, excessivos ou tratados em
   desconformidade;
5. portabilidade;
6. eliminação dos dados tratados com consentimento — **observado o dever legal de guarda do
   prontuário**;
7. informação sobre com quem compartilhamos seus dados;
8. informação sobre a possibilidade de não fornecer consentimento e as consequências;
9. revogação do consentimento;
10. oposição a tratamentos que não se justifiquem.

**Canal:** [E-MAIL/ENCARREGADO A DEFINIR — ver documento 13]. ⚖️

**Prazo de resposta:** procuramos responder em **até 15 dias** da solicitação, observados os prazos
legais aplicáveis e a necessidade de encaminhamento ao profissional quando o pedido envolver conteúdo
clínico. ⚖️

Você também pode apresentar reclamação à **Autoridade Nacional de Proteção de Dados (ANPD)** —
`gov.br/anpd`.

Alguns pedidos de **eliminação** não podem ser atendidos imediatamente quando o prontuário está sob
guarda legal obrigatória: nesse caso, explicamos o motivo e o prazo.

---

## 10. Crianças e adolescentes

Quando a pessoa atendida é criança ou adolescente, o tratamento é feito **no melhor interesse dela**,
com participação do responsável legal e consentimento específico (art. 14 da LGPD e ECA Digital —
Lei nº 15.211/2025). O profissional deve registrar a identificação do responsável legal e o
consentimento correspondente. O aplicativo está em processo de adequação para registrar esses campos
de forma estruturada. ⚖️

---

## 11. Comunicações e WhatsApp

Os **lembretes de sessão por WhatsApp** são enviados apenas quando o profissional habilita o recurso
e com o consentimento da pessoa atendida. O texto do lembrete é definido pelo profissional e
**não deve conter informação clínica** — apenas dados de identificação e do agendamento.
O MentAll PRO está avaliando a migração para um canal oficial de mensagens. ⚖️

---

## 12. Backup, exportação e responsabilidade do profissional

O app permite **exportar** o prontuário em PDF e gerar **backup** dos dados. Quando um arquivo é
exportado, ele deixa de estar sob controle do MentAll PRO: **a guarda passa a ser do profissional**.
Por isso:

- arquivos exportados **não são protegidos por senha** nesta versão — evite compartilhá-los por
  canais inseguros; ⚖️
- o backup é um recurso de continuidade e **não substitui** a política de guarda do prontuário;
- recomenda-se manter cópia segura e testar a restauração periodicamente.

---

## 13. Site institucional, cookies e tecnologias

O site usa apenas recursos necessários ao seu funcionamento e não perfiliza visitantes para
publicidade. Se ferramentas de medição de audiência forem adicionadas, esta política será atualizada e
passará a existir uma **Política de Cookies** específica, informando categorias, finalidade e como
recusar cookies não essenciais.

---

## 14. Alterações desta política

Esta política é versionada: cada alteração relevante gera **nova versão datada**, comunicada no
aplicativo e no site, com **data de entrada em vigor**. O histórico de versões fica disponível e o uso
continuado após a comunicação implica ciência da versão vigente.

---

## 15. Contato e encarregado de dados

**Fornecedor (operador do software):** [RAZÃO SOCIAL], CNPJ [•], endereço [•]. ⚖️
**Encarregado (DPO) pelo MentAll PRO:** [NOMEAR — ver documento 13] ⚖️
**E-mail de privacidade / encarregado:** [DEFINIR — considerar o endereço institucional de privacidade] ⚖️
**Controlador dos dados clínicos:** o profissional de psicologia que realiza o atendimento.

---

### Anexo — resumo em uma página

| Pergunta | Resposta curta |
|---|---|
| Onde ficam meus dados clínicos? | No aparelho do profissional, cifrados; contrato, anamnese e lembretes também ficam no servidor (EUA) |
| O áudio da sessão é gravado? | Não. O áudio é o **relato do profissional** após a sessão, limitado a 5 minutos |
| Para onde vai o áudio? | Para um serviço de transcrição **nos Estados Unidos** |
| Para onde vai o texto clínico? | Para provedores de IA **nos Estados Unidos** e, em caso de falha, **na China** |
| Os dados treinam IA? | Não autorizamos isso; as condições de retenção de cada provedor estão em documentação |
| Vendem meus dados? | **Não** |
| Posso pedir exclusão? | Sim, observado o dever legal de guarda do prontuário |
| Como peço meus direitos? | Pelo canal do encarregado (seção 15) ou pelo profissional que atende |

---

**Documentos relacionados:** `03_data_mapping_e_ropa.md` · `06_termos_de_uso.md` ·
`07_aviso_de_privacidade_e_termo_de_consentimento.md` · `09_transferencia_internacional.md` ·
`10_politica_de_retencao_e_descarte.md` · `13_encarregado_dpo_e_canal_do_titular.md` ·
`18_comparativo_concorrentes.md`
