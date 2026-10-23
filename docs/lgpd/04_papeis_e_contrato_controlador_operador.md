# Papéis LGPD e Contrato de Tratamento de Dados (DPA)

**Versão:** 1.0 (minuta para revisão jurídica) · **Data:** 09/10/2026
**Natureza:** ⚖️ **minuta de trabalho**. O texto do Anexo I não substitui a revisão de um advogado
especializado em proteção de dados antes de ser assinado ou anexado ao aceite no cadastro.

---

## Parte A — Por que este documento existe

O MentAll PRO trata dados pessoais sensíveis de saúde de pessoas que **não são usuárias do app**. O
psicólogo decide sobre o atendimento e sobre o prontuário; o MentAll fornece o software e a
infraestrutura. Essa divisão precisa estar **escrita**, porque é ela que define quem responde a cada
pedido do titular e a cada incidente.

O próprio app já declara o enquadramento:
> "O profissional é o controlador dos dados clínicos. O MentAll PRO atua como operador tecnológico."
> — `lib/screens/lgpd/politica_privacidade_page.dart:76-77`

Este documento transforma essa frase em obrigações recíprocas verificáveis.

---

## Parte B — Enquadramento adotado (LGPD art. 5º, VI e VII)

| Atividade | Controlador | Operador | Fundamento |
|---|---|---|---|
| Prontuário, sessões, relato, áudio, transcrição, síntese, anamnese, contrato terapêutico, lembretes | **Psicólogo** | MentAll PRO | Decisão sobre finalidade e conteúdo é do profissional |
| Conta de acesso do profissional (e-mail, senha, plano) | **MentAll PRO** | Provedores de infraestrutura | MentAll decide a finalidade (autenticação, licenciamento) |
| Telemetria de uso/presença (sem dados clínicos) | **MentAll PRO** | Provedores de infraestrutura | Finalidade própria: produto e suporte |
| Segurança, logs de acesso e prevenção a fraude | **MentAll PRO** | Provedores de infraestrutura | Finalidade própria: integridade do serviço |
| Anamnese e contrato (formulários *web* preenchidos pela pessoa atendida) | **Psicólogo** | MentAll PRO (hospeda e operacionaliza o link) | O conteúdo e a decisão de coletar são do profissional |

**Consequências práticas deste enquadramento (é isto que o psicólogo precisa entender):**

1. Quem responde ao titular pelo conteúdo clínico é o **psicólogo**; o MentAll responde **junto** na
  quota de operador (art. 42, §1º: o operador responde solidariamente quando descumpre obrigações de
   tratamento ou age fora das instruções do controlador).
2. O MentAll **não pode usar dado clínico para finalidade própria** — nem para treinar modelo, nem
   para métrica de produto, nem para marketing. Isso precisa estar escrito (Anexo I, cláusula 4).
3. Quando o titular procura o MentAll diretamente, o MentAll **não responde pelo mérito clínico**:
   encaminha ao psicólogo e registra o encaminhamento.
4. Toda vez que o titular pedir eliminação de dado clínico, a decisão é do psicólogo, **limitada pela
   guarda legal do prontuário** (ver documento 10).

---

## Parte C — O que o MentAll precisa entregar ao psicólogo (anexo do contrato)

| Item | Documento | Situação |
|---|---|---|
| Lista de subprocessadores autorizados, com país e finalidade | `09_transferencia_internacional.md` | A produzir |
| Descrição das medidas de segurança | `12_politica_de_seguranca_da_informacao.md` | A produzir |
| Política de retenção e descarte | `10_politica_de_retencao_e_descarte.md` | A produzir |
| Procedimento de incidente e prazo de aviso ao controlador | `11_plano_de_resposta_a_incidentes.md` | A produzir |
| Canal do encarregado e do titular | `13_encarregado_dpo_e_canal_do_titular.md` | A produzir |
| Material de repasse ao titular (aviso + consentimento) | `07_aviso_de_privacidade_e_termo_de_consentimento.md` | A produzir |
| RIPD do uso de IA | `08_ripd_relatorio_de_impacto.md` | A produzir |
| Guia de uso responsável | `14_guia_lgpd_do_psicologo.md` | A produzir |

**Regra:** o DPA só é verdadeiro se estes anexos existirem. Enquanto estiverem "a produzir", o DPA
deve ser assinado **com a ressalva expressa** de que os anexos serão entregues em prazo definido — ou
não ser assinado ainda.

---

## Parte D — Riscos que o DPA sozinho não resolve

Escrever o contrato **não** conserta os problemas abaixo, que são de arquitetura:

1. O banco de produção está nos **EUA** (`aws-us-west-2.turso.io`) e guarda contrato, anamnese e
   telefone **sem cifra** (`db.py:180-213`; `contrato_service.py:14-15`).
2. A síntese clínica pode ser processada na **China** de forma automática, no fallback
   (`ia_clinica.py:648`; `AGENTS.md:191`).
3. O áudio clínico sai para a **Groq (EUA)** (`transcricao.py:13-20,64-65`).

Um DPA que liste esses subprocessadores sem salvaguarda **documenta o risco, mas não o elimina**.
A ordem correta é: decidir a arquitetura (documento 09) → depois assinar o DPA com a lista verdadeira.

---

## Anexo I — Minuta do Contrato de Tratamento de Dados

> **CONTROLE DE VERSÃO:** v1.0 — minuta técnica para revisão jurídica. Campos `[...]` devem ser
> preenchidos; cláusulas em **negrito** são pontos de atenção para o advogado.

**CONTRATO DE TRATAMENTO DE DADOS PESSOAIS E ADITIVO DE PRIVACIDADE**

**Partes:**
- **CONTROLADOR:** `[NOME DO PSICÓLOGO/CLÍNICA]`, inscrito(a) no CPF/CNPJ sob nº `[...]`, CRP nº
  `[...]`, com endereço em `[...]` ("Profissional").
- **OPERADOR:** `[RAZÃO SOCIAL DO MENTALL PRO]`, CNPJ nº `[...]`, com sede em `[...]` ("MentAll").

**Considerando** que o Profissional utiliza o software MentAll PRO para registrar e organizar
prontuário psicológico, incluindo recursos de gravação de áudio, transcrição automática e geração de
síntese por inteligência artificial; e que o MentAll trata dados pessoais em nome do Profissional,
as partes ajustam:

**1. Objeto.** Este contrato rege o tratamento de dados pessoais realizado pelo MentAll em nome do
Profissional, na qualidade de operador, nos termos do art. 39 da LGPD.

**2. Definições.** Aplicam-se as definições da Lei nº 13.709/2018 (LGPD), em especial as do art. 5º.

**3. Instruções do Controlador.** O MentAll tratará dados pessoais **apenas** conforme as instruções
documentadas neste contrato e nas funcionalidades contratadas. Se uma instrução violar a LGPD, o
MentAll informará o Profissional e poderá recusá-la, justificadamente.

**4. Finalidade limitada e proibições.** O MentAll **não** poderá, em hipótese alguma:
(a) utilizar dado clínico para finalidade própria, marketing ou melhoria de produto;
(b) utilizar dado clínico para treinar, ajustar ou avaliar modelos de IA;
(c) vender, ceder ou compartilhar dados pessoais com terceiros fora da lista do Anexo II;
(d) reidentificar dados pseudonimizados ou anonimizados.

**5. Medidas de segurança.** O MentAll manterá medidas técnicas e administrativas compatíveis com o
art. 46, incluindo: cifra em repouso no aparelho (AES-GCM com chave em Android Keystore/iOS
Keychain), controle de acesso por PIN/biometria, autenticação por token, trilha de auditoria de
eventos relevantes e minimização de dados em log. **[Advogado: definir obrigação de cifra em repouso
no servidor como condição contratual, dado o estado atual — ver documento 09.]**

**6. Subprocessadores.** O MentAll poderá contratar os subprocessadores listados no **Anexo II**,
vinculando-os a obrigações equivalentes. A substituição ou inclusão de subprocessador que implique
**nova transferência internacional ou novo país** será comunicada ao Profissional com antecedência
mínima de `[30]` dias, com direito de oposição.

**7. Transferência internacional.** O Profissional autoriza a transferência para os países e
destinatários do Anexo II, com base `[mecanismo do art. 33 — definir: cláusulas contratuais
padrão / garantias específicas / consentimento]`. **[Advogado: a China e os EUA não contam com
decisão de adequação; o mecanismo precisa ser escolhido e documentado.]**

**8. Aviso de incidente.** O MentAll comunicará ao Profissional, em até **`[24]` horas** da ciência,
qualquer incidente que possa acarretar risco ou dano relevante, informando: natureza, dados
afetados, titulares, medidas adotadas e recomendações. O MentAll prestará apoio na comunicação à
ANPD e aos titulares, quando cabível.

**9. Direitos dos titulares.** O MentAll disponibilizará `[canal/formulário]` e apoiará tecnicamente o
atendimento das solicitações do art. 18, **sem decidir sobre o mérito** — encaminhando ao
Profissional e registrando o encaminhamento. Prazos: `[definir]`.

**10. Término e devolução.** Ao término, o MentAll `[devolverá / eliminará]` os dados pessoais em seu
poder em até `[30]` dias, ressalvadas as hipóteses de guarda obrigatória legal ou regulatória e a
necessidade de retenção para exercício regular de direitos (art. 16).

**11. Responsabilidade.** Cada parte responde pelos danos que causar na forma dos arts. 42 a 45.
O MentAll responde solidariamente quando descumprir obrigações de tratamento ou agir fora das
instruções lícitas do Controlador (art. 42, §1º, I e II).

**12. Auditoria.** O Profissional poderá solicitar, uma vez por ano, informações e evidências
(documentais) sobre o cumprimento deste contrato, resguardado o sigilo de outros clientes.

**13. Vigência.** Vinculado à vigência do contrato de licença de uso, sobrevivendo ao término as
obrigações de sigilo e de eliminação.

**14. Foro e lei aplicável.** Lei brasileira. Foro `[definir — atenção: em contrato de adesão com
consumidor, a cláusula de foro do fornecedor pode ser considerada abusiva; ver documento 06]`.

**Anexo II — Subprocessadores autorizados**

| Subprocessador | Serviço | Dados tratados | País |
|---|---|---|---|
| Turso / AWS | Banco de dados | Contrato, anamnese, telefone, lembrete, conta, telemetria | EUA |
| Fly.io | Hospedagem do backend | Trânsito de todos os dados da API | Brasil (gru) |
| Groq | Transcrição de áudio | Áudio do relato clínico | EUA |
| OpenAI | Síntese/progresso por IA | Nome + relato clínico | EUA |
| DeepSeek | Síntese por IA (fallback) | Nome + relato clínico | China |
| Google (Gemini) | Síntese por IA (inativo no padrão) | Nome + relato clínico | EUA |
| Google Calendar (opcional) | Sincronização de agenda | Resumo do evento, data/hora e sala; **sem nome de paciente por padrão** | Internacional (Google) |
| OpenAlex | Literatura científica | Descritores clínicos | Internacional |
| Sentry (desativado por padrão) | Relatório de erros do app | Dados técnicos do erro, sem PII nem conteúdo clínico | EUA |
| Conselho Federal de Psicologia (API de CRP) | Verificação de registro profissional | CRP informado | Brasil |
| `[wuzapi]` | Lembretes por WhatsApp | Telefone, nome, mensagem | `[definir]` |
| `[provedor SMTP]` | E-mails transacionais | E-mail, tokens | `[definir]` |

> A integração com o Google Calendar é **opcional**, ativada pelo profissional via OAuth no
> aparelho. Por padrão o app envia apenas resumo genérico ("Sessão" ou título do evento), data/hora e
> sala; **não envia nome de paciente nem conteúdo clínico**. O profissional pode desconectar a
> qualquer momento; os eventos já criados permanecem no Google até serem removidos por ele.

---

## Anexo III — Checklist de celebração

- [ ] Razão social, CNPJ e endereço do MentAll preenchidos
- [ ] Anexo II conferido **contra o código em produção** (não contra a memória)
- [ ] Decisão sobre DeepSeek tomada (documento 17) e refletida no Anexo II
- [ ] Mecanismo de transferência internacional escolhido com o advogado
- [ ] Anexos C produzidos e publicados
- [ ] Cláusula de aviso de incidente compatível com o documento 11
- [ ] Aceite eletrônico do DPA implementado no cadastro do profissional
- [ ] Revisão jurídica registrada (nome, OAB, data)
