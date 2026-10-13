# Relatório de Impacto à Proteção de Dados Pessoais (RIPD/DPIA) — MentAll PRO

**Versão:** 1.0 (rascunho para revisão) · **Data:** 09/10/2026
**Produto:** MentAll PRO — prontuário clínico psicológico com IA (cliente Flutter `1.0.49` + backend FastAPI)
**Fundamento:** LGPD, Lei nº 13.709/2018, arts. 5º, 6º, 7º, 11, 14, 16, 18, 20, 33 a 36, 37, 38, 46 e 48
**Natureza:** documento técnico de avaliação de impacto. **Não é parecer jurídico.** Os pontos marcados com ⚖️
dependem de validação por advogado especializado antes de virarem compromisso público ou cláusula
contratual. O MentAll PRO está **em adequação** — este relatório não declara conformidade.

**Base factual:** `_base_factual.md`, `01_diagnostico_lgpd.md`, `02_plano_de_acao.md`,
`03_data_mapping_e_ropa.md`, `04_papeis_e_contrato_controlador_operador.md`, conferidos contra o
código-fonte do repositório em 09/10/2026.

**Por que este RIPD é exigível neste caso:** o tratamento reúne, simultaneamente, (a) **dado pessoal
sensível de saúde** (art. 11), (b) **uso de IA** para apoiar documentação clínica, (c) **transferência
internacional** para EUA e China e (d) **potencial tratamento de dados de crianças e adolescentes**
(art. 14). O art. 38 da LGPD autoriza a ANPD a determinar a elaboração de RIPD justamente quando o
tratamento se funda em legítimo interesse ou quando a atividade envolve risco relevante; o art. 8º do
Regulamento de Comunicação de Incidente de Segurança (Resolução CD/ANPD nº 15/2024) prevê que a ANPD
**pode solicitar o RIPD** no curso de um processo de incidente. Ou seja: a ausência do documento é um
risco verificável, não apenas formalidade.

> Referências normativas oficiais citadas neste bloco:
> [Resolução CD/ANPD nº 15/2024 — Regulamento de Comunicação de Incidente de Segurança](https://www.in.gov.br/en/web/dou/-/resolucao-cd/anpd-n-15-de-24-de-abril-de-2024-556243024) ·
> [Resolução CD/ANPD nº 19/2024 — Regulamento de Transferência Internacional de Dados e cláusulas-padrão](https://www.gov.br/anpd/pt-br/acesso-a-informacao/institucional/atos-normativos/regulamentacoes_anpd/resolucao-cd-anpd-no-19-de-23-de-agosto-de-2024) ·
> [Resolução CD/ANPD nº 32/2026 — adequação recíproca Brasil–União Europeia](https://bibliotecadigital.mj.gov.br/handle/1/16638) ·
> [Canal oficial de Comunicação de Incidente de Segurança da ANPD](https://www.gov.br/anpd/pt-br/canais_atendimento/agente-de-tratamento/comunicado-de-incidente-de-seguranca-cis).

---

## 1. Identificação

| Item | Conteúdo |
|---|---|
| Controlador | **O(a) psicólogo(a) usuário(a)** do MentAll PRO, CRP ativo — decide finalidade e conteúdo do prontuário |
| Operador | **MentAll PRO** — software e infraestrutura; trata o dado clínico em nome do controlador |
| Controlador (em sentido próprio) | **MentAll PRO** quanto a conta do profissional, telemetria, segurança e logs |
| Encarregado (DPO) | **Inexistente** — lacuna confirmada (`politica_privacidade_page.dart:119-122` só menciona "o desenvolvedor do MentAll PRO"). Item **P1.1** do plano de ação |
| Titulares | (i) pessoas atendidas — inclusive **crianças e adolescentes**; (ii) profissionais usuários; (iii) responsáveis legais |
| Versão do produto avaliada | APK `1.0.49`; backend FastAPI em Fly.io `primary_region = "gru"` (`fly.toml:2-3`) |
| Responsável pela elaboração | MentAll PRO (equipe técnica) |
| Próxima revisão obrigatória | Trimestral, ou a qualquer mudança de provedor, campo, país ou finalidade (item **P3.1**) |

**Enquadramento adotado (não contradizer):** psicólogo = controlador dos dados clínicos; MentAll PRO =
operador. O MentAll é controlador apenas da conta do profissional e da telemetria.

---

## 2. Descrição do tratamento (fluxos reais)

### 2.1 Natureza, escopo e contexto

O MentAll PRO é um prontuário psicológico offline-first. O prontuário vive no aparelho do profissional,
cifrado por campo com AES-GCM e chave no Android Keystore/iOS Keychain
(`encryption_service.dart:502-523`). **Parte dos dados, porém, sai do aparelho** — em claro ou não —
para servidores no exterior. É essa parte que concentra o risco e justifica o RIPD.

### 2.2 Fluxos de dados verificados

| # | Fluxo | Dado que sai | Destino / país | Cifra em repouso no destino | Evidência |
|---|---|---|---|---|---|
| F1 | Prontuário local | Relato, sessão, apontamentos | Só o aparelho | **Sim** — AES-GCM por campo | `encryption_service.dart:502-523` |
| F2 | Anamnese (formulário web) | Respostas de anamnese (dado sensível) | **Turso/libSQL — `aws-us-west-2` (EUA)** | **Não** | `backend/.env:40`; `db.py:189-198` |
| F3 | Contrato terapêutico + aceite | JSON do contrato, `nome_aceite` | **Turso (EUA)** | **Não** | `contrato_service.py:14-15`; `db.py:180-188` |
| F4 | Lembretes de sessão | Telefone, nome, mensagem, data/hora | Turso (EUA) + **gateway wuzapi (não oficial)** | **Não** | `db.py:199-215`; `lembrete_service.py`; `wuzapi_admin.py:47-49` |
| F5 | Transcrição de áudio | **Áudio do relato clínico** (base64) | **Groq (EUA)**; alternativa **OpenAI (EUA)** | Não declarada | `transcricao.py:13-20,64-65`; `backend/.env:7` |
| F6 | Síntese clínica por IA | Nome + relato clínico integral | **OpenAI (EUA)** → fallback automático **DeepSeek (`api.deepseek.com`, China)** | Sem `store:false` nem retenção zero | `ia_clinica.py:296` (`ORDEM_PROVEDORES_PADRAO = "openai,deepseek"`), `:648`, `:656-668`; `AGENTS.md:191` |
| F7 | Progresso/evolução por IA | `paciente_id`, sessões anteriores, queixa principal, escalas | OpenAI / DeepSeek | — | `ia_clinica_service.dart:313-323` |
| F8 | Telemetria | `owner_id`, `device_id`, plataforma, versão, tipo do evento | Turso (EUA) | Não | `telemetria.py:1-26` |
| F9 | Exportação de PDF | Prontuário completo | **Fora do controle do MentAll** (compartilhamento do sistema) | **Não — PDF em claro, sem senha e sem evento de auditoria** | `pdf_export_service.dart:1544-1552` (`Printing.sharePdf`) |
| F10 | E-mails transacionais | E-mail do profissional, token | SMTP (Gmail, EUA) | — | `main.py:1709-1713` |
| F11 | Erro de provedor em log | Trecho da resposta do provedor, com possível eco de conteúdo clínico | Log do servidor | Não | `ia_clinica.py:673-676` |
| F12 | Nome do aceitante em log | `nome=%s` sem máscara | Log do servidor | Não | `contrato_service.py:66` |
| F13 | Token do webhook do WhatsApp | Segredo na *query string* | Log do servidor | Não | `wuzapi_admin.py:47-49`; **130.603 ocorrências** em `backend/backend.launchd.log` (contagem verificada em 09/10/2026; o diagnóstico registrava 130.593) |

### 2.3 Pseudonimização parcial — o que ela cobre e o que não cobre

Existe pseudonimização do nome **no cliente** antes de chamar a IA: primeiro nome + iniciais dos
sobrenomes (`ia_clinica_service.dart:185-198`, aplicada em `:107` e enviada em `:115`). O ponto é
positivo e deve ser preservado. **Mas**:

- o `/gerar-progresso` envia `paciente_id`, queixa principal e escalas **sem pseudonimização**
  (`ia_clinica_service.dart:313-323`);
- o relato e a transcrição vão **literais**, e o conteúdo clínico é identificável por si só — a
  pseudonimização do nome não descaracteriza dado de saúde.

Conclusão técnica: para fins de risco, tratar F5/F6/F7 como **transferência internacional de dado
pessoal sensível identificável**, e não como dado anonimizado.

### 2.4 Decisões automatizadas

Não há decisão clínica automatizada: a IA é **apoio documental** e existe *gate* de revisão humana
obrigatória antes de salvar (ponto forte do produto). Ainda assim, o art. 20 se aplica ao direito de o
titular solicitar revisão e obter informação sobre os critérios — o que exige texto e procedimento
próprios (documento 13) e não existe hoje.

---

## 3. Necessidade e proporcionalidade (art. 6º)

| Princípio (art. 6º) | Avaliação | Situação verificada |
|---|---|---|
| **Finalidade** | Adequada no propósito, incompleta na informação | O app declara finalidades clínicas, mas a Política cita "OpenAI ou Google Gemini" e omite Groq e DeepSeek (`politica_privacidade_page.dart:71-73`) |
| **Adequação** | OK para o prontuário; **questionável** na transcrição/síntese em nuvem | O prontuário poderia ser 100% local; o envio de áudio e do relato integral a terceiros é uma escolha de produto, não uma necessidade clínica |
| **Necessidade / minimização** | **Reprovado nos fluxos atuais** | Vai o **relato clínico integral** e o **áudio integral** (`ia_clinica.py:438-454`); a pseudonimização cobre só o nome; `contrato`, `anamnese` e `telefone` são persistidos em servidor estrangeiro **sem cifra** quando poderiam ficar só no aparelho (`db.py:180-213`) |
| **Livre acesso / qualidade** | Parcial | Sem canal do titular (art. 18) e sem trilha de acesso no servidor |
| **Transparência** | **Reprovado** | Divergência material entre promessa e código (`01_diagnostico_lgpd.md`, §4.3); ausência de encarregado (art. 41) |
| **Segurança** | Bom no aparelho; **fraco no servidor** | Falhas C1–C13 do diagnóstico; sem cifra no Turso; log com segredo e PII |
| **Prevenção** | Parcial | Plano de resposta a incidentes **inexistente** até a emissão do documento 11 |
| **Não discriminação** | Sem indício de tratamento discriminatório | O uso de IA para sugerir hipóteses merece aviso expresso de revisão humana |
| **Responsabilização** | **Reprovado até a execução do plano** | Sem DPA, ROPA, RIPD, retenção, incidentes e DPO — itens P1.1 a P1.8 |

**Teste de proporcionalidade — três perguntas objetivas:**

1. *A finalidade justifica o envio?* O prontuário clínico justifica o tratamento local. O envio do
   **áudio bruto** e do **relato integral** a dois provedores estrangeiros, com fallback automático
   para a China, **não** está justificado enquanto não houver (a) informação específica ao titular,
   (b) base legal específica e (c) salvaguarda de transferência.
2. *Existe alternativa menos invasiva?* Sim: transcrição e síntese no aparelho, ou provedor único
   contratado com retenção zero, ou processamento em região brasileira. Está no documento 09.
3. *O risco é proporcional ao benefício?* Para o profissional, sim (economia de tempo). Para a pessoa
   atendida, **não** — ela não escolheu o fluxo, não foi informada e pode ter o relato processado em
   jurisdição sem decisão de adequação.

⚖️ A ponderação final e a escolha do mecanismo do art. 33 são decisão jurídica; a análise acima é
técnica.

---

## 4. Base legal por finalidade ⚖️

> Coluna "proposta" = enquadramento técnico sugerido, sujeito a validação. Não usar como texto público
> enquanto não revisado.

| Finalidade | Dados | Base proposta (LGPD) | Observação crítica |
|---|---|---|---|
| Registro do prontuário e documentação clínica | Relato, sessão, apontamentos | **Tutela da saúde — art. 11, II, "f"** (para dado sensível) | É o enquadramento mais defensável para o prontuário em si; ainda assim, o art. 11, II, "f" exige que o tratamento seja realizado por profissionais de saúde/serviços de saúde |
| Guarda e manutenção do prontuário | Prontuário arquivado | **Cumprimento de obrigação legal/regulatória — art. 7º, II / art. 11, II, "a"** | Sustenta o "arquivar em vez de excluir" (`politica_privacidade_page.dart:82-84`) **somente** se houver norma de guarda apontada expressamente ⚖️ |
| Coleta de dados cadastrais da pessoa atendida | Nome, nascimento, contato | **Tutela da saúde / execução de contrato** | Minimizar: `data de nascimento`, `tipo de atendimento` e `forma de pagamento` hoje ficam **em claro no Hive** (C6, `models/paciente.dart:13-14,19-20,49-50`) |
| **Transcrição de áudio por terceiro (Groq/OpenAI)** | Áudio clínico | **Consentimento específico e destacado — art. 11, I** | Transferência a terceiro + país sem adequação; consentimento precisa ser por titular e registrado |
| **Síntese por IA (OpenAI / DeepSeek)** | Nome pseudonimizado + relato integral | **Consentimento específico e destacado — art. 11, I** | ⚖️ Usar IA de síntese **não** é, em si, "procedimento realizado por profissional de saúde" (art. 11, II, "f"); o enquadramento seguro é consentimento específico **por provedor e por país**, com possibilidade de recusa sem prejuízo do atendimento |
| Envio de anamnese e contrato por link | Respostas de anamnese, contrato | **Tutela da saúde** (anamnese) + **execução de contrato — art. 7º, V** (contrato) | O link **não expira nem é revogável** e embute o **nome da pessoa atendida** na página pública (`main.py:1468,1530,1650-1658`) — corrigir (P1.11) |
| Lembretes por WhatsApp | Telefone, nome, mensagem | **Consentimento específico do titular — art. 7º, I / art. 11, I** | Gateway **não oficial** (wuzapi); a mensagem revela que a pessoa faz psicoterapia (`compromisso.dart:159-171`). Alternativa oficial ou consentimento registrado (P2.7) |
| Telemetria de uso | `owner_id`, `device_id`, versão | **Legítimo interesse — art. 7º, IX** | Hoje **sem opt-out** (C11, `telemetria_service.dart:16-40,72-90`); exige teste de ponderação documentado e aviso (P1.14) |
| Segurança, logs e antifraude | IP, tentativas de login, e-mail mascarado | **Legítimo interesse / cumprimento de obrigação — art. 7º, II e IX** | Log atual retém segredo e PII (F11–F13) — sanear (P1.13, P2.8) |
| Conta do profissional | E-mail, nome, senha (hash), plano | **Execução de contrato — art. 7º, V** | MentAll é **controlador** aqui |
| Dados de criança/adolescente | Tudo do prontuário | **Melhor interesse + consentimento do responsável — art. 14** | Nenhum campo de responsável legal existe hoje; lacuna relevante (P1.15/P2.6) ⚖️ |

**Regra de coerência:** a base legal escolhida tem de aparecer (a) no aviso ao titular, (b) no
consentimento, quando exigido, e (c) no ROPA (documento 03). Hoje **não há registro de consentimento
algum** de pessoa atendida: os "Consentimentos" estão no próprio layout como não implementados
(`pdf_arquitetura_lgpd_service.dart:241`).

---

## 5. Identificação e avaliação de riscos

**Escala:** Probabilidade — Baixa / Média / Alta. Impacto — Baixo / Médio / Alto / Crítico.
Risco residual = risco depois das medidas do plano de ação (documento 02) **executadas**.

### 5.1 Tabela principal de riscos

| # | Risco | Causa técnica (evidência) | Prob. | Impacto | Titulares afetados | Medida mitigadora | Risco residual |
|---|---|---|---|---|---|---|---|
| R1 | Dado de saúde legível em banco estrangeiro | Contrato, anamnese e telefone gravados **sem cifra** no Turso EUA — `contrato_service.py:14-15`; `db.py:180-215`; `backend/.env:40` | Alta | Crítico | Pessoas atendidas | **P0.4** (cifrar em repouso no servidor ou parar de persistir); **P0.3** (decisão de localização, doc. 09) | Médio (dado cifrado ainda trafega/repousa fora) |
| R2 | Transferência internacional sem salvaguarda do art. 33 | Turso/AWS EUA, Groq EUA, OpenAI EUA, DeepSeek China — `backend/.env:40`; `transcricao.py:13-20`; `ia_clinica.py:648` | Alta | Alto | Pessoas atendidas | Documento 09 + cláusulas-padrão da ANPD (Res. 19/2024) + decisão de arquitetura | Médio |
| R3 | Processamento clínico na **China** por fallback automático, sem decisão informada | `ORDEM_PROVEDORES_PADRAO = "openai,deepseek"` — `ia_clinica.py:296`; `:648`; `AGENTS.md:191` | Alta | Alto | Pessoas atendidas | **P0.2** (remover DeepSeek da cascata **ou** consentimento específico + RIPD específico) | Baixo (se removido) / Médio (se mantido com consentimento) |
| R4 | Informação enganosa ao titular sobre terceiros e países | Política cita "OpenAI ou Google Gemini" — `politica_privacidade_page.dart:71-73`; Termos citam "OpenAI Whisper/GPT-4.1" — `termos_uso_page.dart:35-36` | Alta | Alto | Pessoas atendidas, profissionais | **P0.1**, **P0.5**, **P0.6**; publicação em URL | Baixo |
| R5 | Reidentificação a partir de material clínico pseudonimizado | Relato/transcrição vão **literais**; `/gerar-progresso` envia `paciente_id` e queixa sem pseudonimização — `ia_clinica_service.dart:313-323`; `:185-198` | Alta | Médio/Alto | Pessoas atendidas | Ampliar pseudonimização; minimizar o que vai ao provedor (P0.4/P1.11) | Médio |
| R6 | Ausência de base legal documentada e de consentimento | Nenhum registro de consentimento do titular; módulo marcado como não implementado — `pdf_arquitetura_lgpd_service.dart:241` | Alta | Alto | Pessoas atendidas | **P1.5** (aviso + termo, doc. 07); **P1.2** (DPA, doc. 04) | Baixo |
| R7 | Violação do **sigilo profissional** por exposição a terceiros sem contrato | Áudio e relato enviados a provedores sem DPA/instrução documentada — `ia_clinica.py:656-668` | Média | Alto | Pessoas atendidas | DPA + cláusulas mínimas por subprocessador (doc. 09) | Médio |
| R8 | Incidente com dado sensível sem plano, sem prazo e sem registro | Plano de resposta a incidentes **inexistente** (até o documento 11) | Alta | Alto | Pessoas atendidas, profissionais | **P1.7** (documento 11 + registro + simulado) | Baixo |
| R9 | Vazamento de segredo do webhook do WhatsApp | Token na query string — `wuzapi_admin.py:47-49`; **130.603 ocorrências** em `backend/backend.launchd.log` | Alta | Alto | Pessoas atendidas (mensagens), profissionais | **P1.13** (mover para header, rotacionar, expurgar log) | Baixo |
| R10 | Eco de conteúdo clínico em log de erro | `log.error(... resp.text[:500])` — `ia_clinica.py:673-676`; nome sem máscara — `contrato_service.py:66` | Média | Alto | Pessoas atendidas | **P2.8**, **P1.13** | Baixo |
| R11 | Perda silenciosa de dados confirmando gravação que não persiste | `ALLOW_SQLITE_FALLBACK` default `true` — `db.py:15-17`; `/health` sempre `ok` — `main.py:688-700` | Média | Alto | Pessoas atendidas | **P1.12**, **P2.4** | Baixo |
| R12 | Cópia local em texto claro com dados reais | `backend/data/mentall.db` (verificado: 73.728 bytes, 25/08) | Média | Alto | Pessoas atendidas | **P0.11** (eliminar e definir descarte) | Baixo |
| R13 | Perda/roubo do aparelho com prontuário acessível | Desbloqueio *fail-open*: lockout/erro de hardware carrega a chave mestra — `auth_service.dart:203-215`; chave não é limpa da memória ao bloquear — `encryption_service.dart:656-663` (sem chamador) | Média | Crítico | Pessoas atendidas | **P0.7**, **P0.9** | Médio |
| R14 | Relato clínico persistido em claro no aparelho | `.m4a` gravado em claro e cifrado só após `stop()` — `audio_relato_service.dart:92` vs `:171`; sem varredura de órfãos | Média | Alto | Pessoas atendidas | **P0.8** | Baixo |
| R15 | PDF/exportação sem proteção e sem rastreio | `Printing.sharePdf` sem senha e sem evento de auditoria — `pdf_export_service.dart:1544-1549`; nenhuma referência a auditoria no serviço | Alta | Alto | Pessoas atendidas | **P1.16**, **P2.9** | Médio (destino fica fora do controle) |
| R16 | Exclusão não exercível (art. 18, VI) e ausência de retenção no servidor | Nenhum `DELETE` de contrato/anamnese; só lembretes têm `DELETE` — `db.py:179-314` | Alta | Alto | Pessoas atendidas | **P1.6**, **P1.9**, doc. 10 | Médio |
| R17 | Trilha de auditoria que se autodestrói e não cobre acesso/exportação | Máximo de 1000 registros com expurgo dos mais antigos — `auditoria_service.dart:10,94-102`; eventos ausentes — `:31,70-126` | Alta | Médio | Pessoas atendidas, profissionais | **P2.1**, **P2.2**, **P2.3** | Baixo |
| R18 | Telemetria contínua sem escolha | `telemetria_service.dart:16-40,72-90`; sem opt-out | Alta | Baixo | Profissionais | **P1.14** | Baixo |
| R19 | Acesso interno indevido pela tela administrativa | `/admin` exige cookie httpOnly + `role == "admin"` — `main.py:2055-2091`; o painel lista **usuários** (e-mail, nome, plano) — `admin.py:52-68`. **Não** exibe dado clínico | Baixa | Médio | Profissionais (e indiretamente pessoas atendidas) | Revisar escopo do painel, registrar acesso e aplicar minimização (doc. 12) | Baixo |
| R20 | Dados órfãos por `APP_USER_ID` efêmero | Sem a variável, o backend gera UUID novo a cada boot — `main.py:241` | Alta | Alto | Pessoas atendidas | **P1.12** | Baixo |
| R21 | Retenção indefinida de áudio | Exclusão `unawaited`; nada no app declara prazo | Média | Médio | Pessoas atendidas | **P2.5**, doc. 10 | Baixo |

### 5.2 Riscos específicos — dados sensíveis de saúde

- O dado é **sensível por natureza** (art. 11) e o vazamento pode causar **discriminação, dano à
  reputação e sofrimento psíquico** — impactos que o art. 5º, §1º do Regulamento de Comunicação de
  Incidente (Res. 15/2024) trata como "afetar significativamente interesses e direitos fundamentais".
- O dado também é **protegido por sigilo profissional** (art. 5º, X do mesmo Regulamento) — o que faz
  qualquer incidente com ele **presumir risco relevante**, dispensando discussão sobre "dano concreto".
- Consequência operacional: incidente com relato/áudio/síntese **entra pela porta da comunicação
  obrigatória** (documento 11), salvo demonstração técnica em contrário registrada.

### 5.3 Riscos específicos — crianças e adolescentes (art. 14)

- O produto **não tem** campo de responsável legal, autorização nem consentimento específico para
  menor (nenhum campo encontrado no cliente; confirmado no diagnóstico §4.14).
- Há data de nascimento e idade (`models/paciente.dart:13-14`), portanto **é possível identificar
  menores** — o que torna a lacuna efetiva, não hipotética. Em psicologia infantil, o uso é frequente.
- O art. 14 exige tratamento **no melhor interesse** e consentimento específico de pelo menos um dos
  pais ou responsável legal. A Cláusula 12 das cláusulas-padrão da ANPD (Anexo II da Res. 19/2024)
  reforça **salvaguardas adicionais** em transferência internacional que envolva menores.
- Incidente com dados de criança/adolescente é **critério autônomo** de risco relevante (art. 5º, II
  do Regulamento de Comunicação).
- Ação: **P1.15** / **P2.6** — campo de responsável, autorização registrada com data e versão, e
  vedação de uso de IA para menores sem consentimento específico do responsável ⚖️.

### 5.4 Riscos específicos — transferência internacional (arts. 33 a 36)

- **EUA** (Turso/AWS `us-west-2`, Groq, OpenAI, Google, Sentry, SMTP): **não há decisão de adequação**
  da ANPD para os EUA. É necessário um mecanismo do art. 33 — na prática, **cláusulas-padrão
  contratuais** (art. 33, II, "b"), cujo texto foi aprovado pelo Anexo II da Resolução CD/ANPD
  nº 19/2024 e cuja incorporação aos contratos passou a ser exigível após o prazo de 12 meses contado
  da publicação da Resolução.
- **China** (DeepSeek): **não há decisão de adequação** e o fluxo ocorre **por fallback automático**,
  sem escolha informada do controlador no momento do uso. É o risco de maior sensibilidade política e
  o de menor defensabilidade.
- ⚖️ **Adequação Brasil–União Europeia (Resolução CD/ANPD nº 32, de 26/01/2026)** não resolve este
  caso: nenhum dos destinos acima é país do EEE.
- A Resolução 19/2024 exige, ainda, **transparência ativa**: documento em português, em linguagem
  simples, na internet, informando forma, duração, finalidade, **país de destino**, responsabilidades,
  medidas de segurança e direitos do titular (art. 17, §2º). Isso **não existe** hoje no produto.
- Análise completa, cenários de decisão e recomendação: **documento 09**.

### 5.5 Riscos específicos — decisões automatizadas e IA (art. 20)

- **Desenho favorável:** a IA é apoio documental, com *gate* de revisão humana obrigatória antes de
  salvar, e não emite diagnóstico. Isso afasta o cenário de "decisão tomada unicamente com base em
  tratamento automatizado" no sentido do art. 20.
- **Mas** o direito do art. 20 permanece: o titular pode pedir **revisão** e **informação sobre os
  critérios**. Hoje não há canal, texto nem procedimento (documento 13 pendente).
- **Risco de automação por omissão:** o fallback troca o provedor — e o **país** — sem aviso ao
  profissional e sem registro na trilha. Do ponto de vista de accountability, isso é uma decisão de
  arquitetura tomada pelo operador que altera a natureza da transferência; precisa ser decidida,
  documentada e informada (P0.2).
- **Risco de viés e de erro clínico:** modelos podem reproduzir estereótipos. Mitigação já existente:
  revisão humana obrigatória. Mitigação a acrescentar: aviso explícito de que a síntese é **rascunho**,
  registro de qual provedor gerou cada síntese e trilha de auditoria do evento de IA (P2.2).

---

## 6. Medidas de mitigação

### 6.1 O que já existe e deve ser preservado

| Medida | Evidência |
|---|---|
| Cifra por campo AES-GCM no aparelho, chave em Keystore/Keychain | `encryption_service.dart:502-523` |
| `allowBackup=false` e `usesCleartextTraffic=false` | `AndroidManifest.xml:13-14` |
| Revisão humana obrigatória antes de salvar a síntese | *gate* de produto verificado no diagnóstico (§4.4) |
| Telemetria sem PII por *allowlist* | `telemetria.py:1-26` |
| Sentry desligado por padrão e sem PII | `main.dart:73-105` |
| Log técnico cifrado/redigido no cliente | `logger.dart:115-124` |
| Pseudonimização do nome antes de enviar à IA | `ia_clinica_service.dart:107,185-198` |
| Isolamento por `owner_id` no backend, com testes de IDOR | `tests/test_status_idor.py`, `test_recuperacao_idor.py`, `test_lembrete_idor.py` |
| `.env` nunca commitado | `.gitignore:2-3` |
| Painel administrativo restrito a `role == "admin"` e sem dado clínico | `main.py:2055-2091`; `admin.py:52-68` |

### 6.2 O que o plano de ação resolve — mapeamento por item

| Item | Prioridade | Risco que mitiga |
|---|---|---|
| **P0.1** corrigir terceiros e países nos textos | P0 | R4 |
| **P0.2** decidir o DeepSeek (remover ou consentimento + RIPD específico) | P0 | R3, R2 |
| **P0.3** decidir a localização do banco | P0 | R1, R2 |
| **P0.4** cifrar o conteúdo no servidor ou parar de persistir | P0 | R1, R5 |
| **P0.5** publicar Política e Termos em URL | P0 | R4, transparência |
| **P0.6** remover a afirmação não comprovada sobre treinamento | P0 | R4 |
| **P0.7** fechar o desbloqueio *fail-open* | P0 | R13 |
| **P0.8** áudio nunca em claro + varredura de órfãos | P0 | R14 |
| **P0.9** bloqueio real (`limpar()`, `FLAG_SECURE`) | P0 | R13 |
| **P0.10** corrigir ou remover a afirmação de *pinning* | P0 | R4 |
| **P0.11** eliminar a cópia local em texto claro (`backend/data/mentall.db`) | P0 | R12 |
| **P1.1** nomear encarregado e publicar canal | P1 | R6, R8 |
| **P1.2** assinar o DPA | P1 | R6, R7 |
| **P1.3** ROPA mantido | P1 | accountability |
| **P1.4** **este RIPD** aprovado e arquivado | P1 | accountability |
| **P1.5** aviso + termo de consentimento do titular | P1 | R6 |
| **P1.6** política de retenção e descarte | P1 | R16, R21 |
| **P1.7** plano de resposta a incidentes + registro + simulado | P1 | R8 |
| **P1.8** canal e procedimento do titular (art. 18) | P1 | R16, art. 20 |
| **P1.9** fluxo e URL de exclusão de conta | P1 | R16 |
| **P1.11** links de anamnese/contrato com expiração e sem nome embutido | P1 | R5, R15 |
| **P1.12** fixar `APP_USER_ID`, desligar fallback, `/health` honesto | P1 | R11, R20 |
| **P1.13** segredos fora da URL + expurgo de log + mascarar nome | P1 | R9, R10 |
| **P1.14** telemetria com opt-out | P1 | R18 |
| **P1.15** menores de idade (art. 14) | P1 | §5.3 |
| **P1.16** PDF/backup protegidos e auditados | P1 | R15 |
| **P2.1 a P2.18** robustez (auditoria, log, CORS, Hive, iOS, demo, aceite versionado) | P2 | R17, R5, R19 |

### 6.3 Medidas novas propostas por este RIPD

1. **Registro de provedor por geração de IA** — gravar, no aparelho, qual provedor gerou cada síntese
   (OpenAI ou DeepSeek), com data. Sem isso, não há como responder a um incidente nem ao art. 20.
2. **Selo de procedência no PDF** — todo PDF exportado deve conter aviso de sigilo, origem e
   orientação de guarda (P1.16), além de evento de auditoria.
3. **Bloqueio de IA para menores sem autorização registrada** enquanto o fluxo do art. 14 não existir.
4. **Página pública de transferência internacional** em português (art. 17, §2º da Res. 19/2024), com
   país, finalidade, medida de segurança e canal do titular.
5. **Teste de ponderação do legítimo interesse** para telemetria e logs, datado e arquivado.
6. **Revisão do RIPD a cada novo provedor, país ou campo** — gatilho obrigatório, não discricionário.

---

## 7. Consulta ao titular

**Situação atual: a consulta não existe.** Não há canal, formulário, registro de solicitação nem
previsão de consulta às pessoas atendidas — lacuna confirmada (`politica_privacidade_page.dart:89-122`).

**Medidas propostas (não substituem a decisão do controlador):**

| Nível | Medida | Prazo |
|---|---|---|
| Imediato | O psicólogo entrega ao titular o **aviso de privacidade + termo de consentimento** (documento 07) antes de usar áudio/IA | Junto com P1.5 |
| Curto prazo | **Opt-in explícito** e destacado para: (a) gravação de áudio; (b) envio a provedor de transcrição; (c) envio a provedor de síntese por IA, **nomeando o provedor e o país**; (d) lembretes por WhatsApp | P1.5 |
| Curto prazo | Registrar no prontuário **data, versão do texto aceito e escopo** do consentimento | P1.5 |
| Médio prazo | **Consulta em linguagem simples** às pessoas atendidas (e responsáveis, quando menor) sobre o uso de IA no prontuário, com resultado registrado | P2.10 |
| Médio prazo | Publicar a página de transferência internacional e o canal do encarregado | P1.1, P1.4 |
| Contínuo | A **recusa** ao uso de IA não pode impedir o atendimento: deve existir caminho de prontuário 100% local documentado | P1.5 |

⚖️ A forma exata do consentimento (escrito, eletrônico, registrado no prontuário), o momento da coleta
e a repartição de responsabilidade entre MentAll e psicólogo na obtenção dependem de validação
jurídica — ver documento 04 (DPA) e documento 07.

---

## 8. Conclusão e recomendação

### 8.1 O que é aceitável manter, com documentação

- Prontuário cifrado no aparelho, com chave em Keystore/Keychain.
- Telemetria **sem PII clínica** por *allowlist*, **desde que** haja aviso, opt-out e teste de
  legítimo interesse documentado.
- Uso de IA como **apoio documental com revisão humana obrigatória**, desde que informado e com
  registro de provedor.
- Persistência de **conta do profissional** no banco (MentAll é controlador), com retenção definida.

### 8.2 O que exige consentimento específico e destacado do titular

- **Gravação em áudio** do relato e seu **envio a provedor de transcrição (Groq/OpenAI, EUA)**.
- **Envio do relato clínico a provedor de síntese por IA**, com **nomeação de provedor e país**,
  inclusive no cenário de *fallback*.
- **Qualquer processamento na China (DeepSeek)** — enquanto o fluxo existir, com RIPD específico.
- **Lembretes por WhatsApp** por gateway não oficial.
- **Tratamento de dados de criança/adolescente**, com consentimento de ao menos um responsável legal.

### 8.3 O que exige mudança de arquitetura (contrato não resolve)

1. **Persistir contrato, anamnese e telefone sem cifra em banco estrangeiro** — cifrar em repouso ou
   deixar de persistir (P0.4). Um DPA que liste o subprocessador **documenta** esse risco, não o
   elimina (`04_papeis_e_contrato_controlador_operador.md`, Parte D).
2. **Fallback automático para a China** — remover da cascata **ou** tornar a escolha explícita,
   informada e consentida por titular (P0.2).
3. **Exportação de PDF em claro** — proteção e rastreio são capacidade de produto, não cláusula.
4. **Ausência de exclusão, retenção e portabilidade no servidor** — exige implementação (P1.6, P1.9).
5. **Fallback SQLite que confirma gravação perdida** — exige mudança de comportamento (P1.12).
6. **Segredo e PII em log** — exige rotação, expurgo e mudança de código (P1.13, P2.8).

### 8.4 Recomendação

**Recomendação técnica:** executar **P0.1 a P0.11 antes do próximo release/loja**; em especial,
**remover o DeepSeek da cascata** (decisão de menor custo e maior redução de risco) e **decidir a
localização do banco** antes de assinar o DPA — porque o DPA precisa listar subprocessadores
**verdadeiros** (documento 09). Emitir o RIPD em versão 1.1 **após** as decisões P0.2 e P0.3, com o
mapa de transferência consolidado.

**Posição a declarar publicamente:** o MentAll PRO está **em adequação**. Não usar "LGPD compliant",
"certificado" ou "100% seguro" em nenhum material.

### 8.5 Plano de revisão

| Gatilho | Ação | Responsável |
|---|---|---|
| Adição/remoção de provedor de IA | Revisar §2.2, §5.4 e documento 09 | MentAll |
| Mudança de região do banco | Revisar §2.2, §5.4 e o mapa de transferência | MentAll |
| Novo campo de dado sensível ou de menor | Revisar base legal (§4) e riscos (§5) | MentAll |
| Incidente de segurança relevante | Revisar §5 e o documento 11; registrar lição aprendida | Encarregado |
| Alteração normativa da ANPD | Revisar §5.4 e §8 | Encarregado + advogado |
| Revisão periódica | **Trimestral**, com registro de data e versão | Encarregado |
| Revisão jurídica | Antes de qualquer publicação ou assinatura | Advogado ⚖️ |

---

## Pendências de validação jurídica

1. ⚖️ **Base legal do prontuário:** confirmar se a tutela da saúde (art. 11, II, "f") sustenta o
   prontuário **e** afastar expressamente o uso dessa hipótese para o envio a provedores de IA.
2. ⚖️ **Forma e momento do consentimento** do titular para áudio, transcrição, síntese por IA,
   WhatsApp e tratamento de menores (art. 11, I e art. 14).
3. ⚖️ **Mecanismo do art. 33** aplicável a EUA e China e redação final das cláusulas-padrão — confirmar
   se as cláusulas da Resolução CD/ANPD nº 19/2024 podem ser aceitas por adesão aos contratos-padrão
   dos provedores ou se exigem instrumento próprio com cada subprocessador.
4. ⚖️ **Guarda legal do prontuário psicológico:** norma, prazo e extensão — e como isso se concilia com
   o direito de eliminação (art. 18, VI). Sem isso, o "arquivar em vez de excluir" continua sem lastro.
5. ⚖️ **RIPD específico para o DeepSeek**, caso a decisão P0.2 seja mantê-lo.
6. ⚖️ **Papel do MentAll no fluxo de IA:** confirmar que permanece **operador** (e não vira controlador
   por decidir a cascata de provedores) — a escolha de arquitetura é do MentAll, mas a decisão sobre o
   tratamento clínico é do psicólogo. Esta distinção afeta responsabilidade solidária (art. 42, §1º).
7. ⚖️ **Menores:** exigência de consentimento de ambos os responsáveis ou de um; tratamento de
   adolescente com autonomia progressiva.
8. ⚖️ **Retenção de logs** com PII e segredo: prazo defensável e base legal.
9. ⚖️ **Legítimo interesse** para telemetria: validar o teste de ponderação.
10. ⚖️ **Data mapping ainda pendente** (documento 03, §5): retenção real nos provedores de IA, região
    do wuzapi e do SMTP, e se o app exige aceite de termos/DPA no cadastro. Enquanto qualquer item
    estiver aberto, este RIPD é **rascunho** e não pode ser apresentado à ANPD como documento
    definitivo.

**NÃO CONFIRMADO — validar com advogado:** obrigatoriedade de decisão de adequação específica para os
EUA; suficiência das cláusulas-padrão para o caso de subprocessador que processa **dado sensível de
saúde** em larga escala; e eventual necessidade de consulta prévia à ANPD.
