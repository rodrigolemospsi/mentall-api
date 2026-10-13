# Política de Retenção e Descarte de Dados — MentAll PRO

**Versão:** 1.1 (rascunho para revisão jurídica) · **Data:** 13/10/2026 · **Próxima revisão:** 09/04/2027
ou a cada mudança que crie, altere ou elimine categoria de dado
**Aplicação:** cliente Flutter (`1.0.49`) e backend FastAPI do MentAll PRO
**Natureza:** documento de trabalho. **Não é parecer jurídico.** Todo item marcado ⚖️ depende de
validação por advogado especializado antes de virar compromisso público ou cláusula contratual.

> **Como ler este documento.** A coluna "onde fica" e as lacunas descrevem o **estado verificado do
> produto em 09/10/2026**, com evidência `arquivo:linha`. Os prazos da coluna "prazo proposto" são
> **proposta técnica** deste pacote de adequação — não são regra vigente até que o jurídico os
> confirme. Onde a lei já fixa piso, ele está indicado com a fonte oficial. O produto **não se declara
> em conformidade plena nem seguro por certificação**: está **em adequação**.
>
> **Regra de ouro que este documento segue:** nenhum prazo declarado em texto público pode ser maior
> do que a capacidade real de cumpri-lo. Enquanto não houver rotina de expurgo implementada, a
> política descreve o descarte como **medida em implementação**, com o cronograma do §10.

---

## 1. Objetivo e alcance

Esta política define **por quanto tempo** cada categoria de dado tratada pelo MentAll PRO é
conservada, **com que fundamento**, **como** é descartada ao fim do prazo e **quem** responde por
cada rotina de expurgo.

Ela alcança:

1. os dados sob **responsabilidade do psicólogo como controlador** (prontuário, sessões, áudio,
   transcrições, sínteses, anamnese, contrato, lembretes) — tratados pelo MentAll como **operador**;
2. os dados sob **responsabilidade do MentAll como controlador** (conta do profissional, telemetria,
   segurança e logs);
3. as **cópias derivadas** que escapam do ambiente controlado (backups, PDFs exportados, links
   públicos, registros de log).

Enquadramento de papéis conforme `04_papeis_e_contrato_controlador_operador.md` (Parte B) e
`01_diagnostico_lgpd.md` §3.

---

## 2. Princípios

| # | Princípio | O que significa na prática |
|---|---|---|
| 2.1 | **Finalidade e necessidade (art. 6º, I a III)** | Só se conserva o dado enquanto ele serve à finalidade informada. "Guardar por via das dúvidas" não é fundamento. |
| 2.2 | **Temporalidade** | Toda categoria tem prazo **definido, escrito e verificável** — inclusive a categoria "não há prazo" (que hoje é o estado do servidor: `db.py:179-314`). |
| 2.3 | **Guarda legal não é retenção indefinida** | O prontuário tem piso legal de 5 anos (Res. CFP nº 001/2009, art. 4º, §1º). Isso **prorroga** o prazo do prontuário — não autoriza manter indefinidamente áudio, log, link público ou telemetria. |
| 2.4 | **Eliminação ≠ arquivamento** | Arquivar é ato **clínico** do profissional (mantém o registro acessível sob guarda). Eliminar é ato de **descarte**, irreversível. Os dois precisam estar separados no produto e no texto ao titular. |
| 2.5 | **Verdade factual** | O documento público descreve o comportamento real do sistema (`02_plano_de_acao.md`, "regra de ouro"). Prazo prometido e não implementado é informação enganosa ao titular. |
| 2.6 | **Segregação por papel** | Quem decide o descarte do **dado clínico** é o psicólogo; quem decide o descarte de **conta, telemetria e logs** é o MentAll. O operador não elimina prontuário por conta própria. |
| 2.7 | **Descarte com evidência** | Toda eliminação relevante gera registro (protocolo, data, categoria, quem executou). Hoje a trilha de auditoria **não tem evento de exclusão** (`auditoria_service.dart:31,70-126`). |
| 2.8 | **Descarte seguro** | Apagar não é esconder: onde houver cifra, o descarte pode ser **criptográfico** (destruir a chave); onde houver arquivo, remover o arquivo **e** os resíduos (`-wal`/`-shm` do SQLite, `backend/data/mentall.db-wal`); onde houver log, truncar. |
| 2.9 | **Minimização de cópias** | Cada cópia (backup, PDF, link, log) multiplica o prazo de exposição. Reduzir cópias é a medida de retenção mais eficaz antes de qualquer rotina automática. |

---

## 3. Quem responde pela retenção

| Categoria | Decide o prazo | Executa o descarte | Observação |
|---|---|---|---|
| Prontuário, sessões, transcrições, sínteses, áudio, anamnese, contrato | **Psicólogo** (controlador) | Profissional no aparelho; MentAll apoia o descarte no servidor por instrução | O MentAll não decide sobre mérito clínico (`04_...md`, Parte B) |
| Lembretes (telefone, mensagem) | Psicólogo decide a finalidade; MentAll opera | MentAll (expurgo técnico do servidor) | Hoje só existe `DELETE` por compromisso (`main.py:1397,1439`) |
| Conta do profissional, telemetria, segurança e logs | **MentAll** (controlador) | MentAll | |
| Backups e PDFs exportados | Profissional (a partir da exportação) | Profissional | "A guarda passa a ser do profissional" (`05_politica_de_privacidade.md` §12) |
| Links públicos (token) | MentAll (operação) + psicólogo (decisão de enviar) | MentAll (expiração/revogação) | Hoje sem coluna de expiração (`db.py:180-198`) |

---

## 4. Regras gerais

1. **Prazo conta do último tratamento**, não da criação do registro. Prontuário: mínimo de 5 anos
   **do último registro** (Res. CFP nº 001/2009, art. 4º, §1º —
   [PDF oficial](http://site.cfp.org.br/wp-content/uploads/2009/04/resolucao2009_01.pdf)), podendo ser
   ampliado por lei ou decisão judicial.
2. **A referência de até 20 anos** vem da Lei nº 13.787/2018 (prontuário de saúde: mínimo 20 anos do
   último registro), combinada com a Res. CFM nº 1.821/2007 e com **orientação do CRP-MT**. A
   extensão ao prontuário **psicológico** é **orientação de conselho regional, não regra do CFP** —
   por isso está marcada ⚖️ e **não** deve ser apresentada ao titular como obrigação legal nacional.
3. **Nenhum expurgo automático pode apagar prontuário.** Descarte automático só é admitido para
   categorias operacionais (áudio quando não mantido, lembrete, log técnico, telemetria, link
   expirado) e sempre com registro.
4. **Dado anonimizado deixa de ser dado pessoal** (art. 12) e pode ser conservado para estatística —
   desde que o processo de anonimização seja documentado e irreversível na prática. **Pseudonimização
   não basta**: a redução de sobrenome a iniciais antes do envio à IA
   (`ia_clinica_service.dart:185-198`) **não** descaracteriza dado pessoal.
5. **Descarte do dado no servidor só é válido com descarte dos derivados**: réplica, cache, log,
   arquivo local de desenvolvimento e cópia de trabalho.
6. **Enquanto a rotina automática não existir**, o descarte é **manual e registrado**, e o texto
   público informa isso — ver §9 e §10.

### 4.7 Referência de mercado (13/10/2026)

O comparativo com concorrentes brasileiros (`18_comparativo_concorrentes.md`) mostra que **o mercado
não é unânime** nos prazos — o que reforça a decisão **D8** (`17_registro_de_decisoes_e_revisoes.md`)
e a pendência ⚖️ nº 1 deste documento:

| Concorrente | Prazo declarado | Fonte |
|---|---|---|
| **Copilloto** | Prontuário **5 anos** (Res. CFP nº 1/2009); financeiro 5 anos; conta cancelada 90 dias; logs 12 meses | `copilloto.com.br/privacidade` |
| **Zenklub** | Prontuários **20 anos** (Lei nº 13.787/2018 + Res. CFP nº 6/2019 + Res. CFM nº 1.821/2007) | `zenklub.com.br/privacidade` |
| **PsiLuz** | Genérico ("conforme exigências do CFP") | `psiluz.com.br/privacy` |
| **ProntusCare / PsicoPront** | Sem prazo consolidado (conforme a conta/profissional) | `prontuscare.com.br/privacidade.html`; `psicopront.com.br/privacidade` |

**Uso deste dado:** o benchmark **não** define o prazo do MentAll — apenas demonstra que adotar o piso
de **5 anos** (Res. CFP nº 1/2009) tem precedente de mercado e que a extensão a 20 anos não é consenso.
A decisão continua **jurídica** (⚖️) e precisa ser registrada antes de qualquer publicação.

---

## 5. Tabela de prazos por categoria

> Legenda de estado: **EXISTE** = comportamento verificado no código; **NÃO EXISTE** = ausência
> verificada; **PARCIAL** = existe com falha conhecida.

| Dado | Onde fica (09/10/2026) | Prazo proposto | Fundamento | Como descartar |
|---|---|---|---|---|
| **Prontuário e sessões** (relato, apontamentos, hipóteses, plano, histórico) | **Somente no aparelho**, Hive com cifra por campo; alguns campos ficam em claro (data de nascimento, tipo de atendimento, valores, data da sessão — `models/paciente.dart:13-14,19-20,49-50`; `models/sessao.dart:20,119-120,158-168`; `sessao_service.dart:80`) | **Mínimo de 5 anos do último registro**, sem eliminação automática; arquivamento em vez de exclusão; prazo maior por lei/decisão judicial. A extensão a 20 anos é ⚖️ (orientação regional) | Res. CFP nº 001/2009, art. 4º, §1º; art. 16, I (conservação por obrigação legal) | Exclusão **manual pelo profissional**, com confirmação explícita e registro de auditoria (hoje **não existe** evento de exclusão). Cripto-descarte ao remover a chave do aparelho. |
| **Áudio do relato** (`.m4a`, até 5 min) | Aparelho, **em claro durante a gravação** (`audio_relato_service.dart:92`) e cifrado só depois de parar (`:171`); enviado à **Groq (EUA)** (`transcricao.py:13-20,64-65`); pode ir ao backup em base64 quando &lt; 500 kB (`backup_service.dart:72-73,103-104`) | **Se "não manter": descarte imediato após a transcrição.** **Se "manter"**: 90 dias (**recomendação**) ou, se o profissional tratar o áudio como parte do prontuário, a mesma guarda do prontuário ⚖️. Prazo **a declarar** — hoje não existe | Minimização (art. 6º, III); finalidade (ditar o relato); ⚖️ a decisão de manter é do profissional | Apagar o arquivo **e** os órfãos de gravação interrompida no boot (`audio_relato_service.dart:284-300,544`; ausência de varredura em `:416-437,509-512`); evento de auditoria (hoje ausente — `AGENTS.md`). |
| **Transcrição** | Aparelho, cifrada; cópia no provedor de transcrição (EUA) | **Integra o prontuário** → mesma guarda do prontuário (mín. 5 anos) | Decorre do item "prontuário"; Res. CFP nº 001/2009, art. 4º, §1º | Exclusão junto com a sessão; verificar retenção no provedor ⚖️ (sem `store:false` no payload — `transcricao.py:85-99`). |
| **Síntese de IA e progresso** | Aparelho, cifrada; material enviado a **OpenAI (EUA)** e, no fallback automático, **DeepSeek (China)** (`ia_clinica.py:594-690`, endpoint `:648`); Gemini no código, fora da ordem de produção | **Integra o prontuário** se revisada e salva. Se **descartada na revisão**, eliminar em até **30 dias** da geração | Art. 16 (término do tratamento); art. 20 (revisão humana); minimização | Exclusão com registro; revisão humana obrigatória já existe como gate de produto. |
| **Anamnese** (respostas) | **Turso (EUA), em claro** (`db.py:189-198`; `anamnese_service.py`) + eventual cópia importada/exportada | Cópia **no servidor**: eliminar em até **30 dias** após a confirmação de recebimento pelo profissional. O conteúdo clínico segue a guarda do prontuário **no aparelho** | Minimização (art. 6º, III) + art. 16 ⚖️ | `DELETE` por token + rotina de expurgo por idade (**não existem** hoje — `db.py:179-314`). |
| **Contrato terapêutico e aceite** | **Turso (EUA), em claro** (`db.py:180-188`; `contrato_service.py:14-15`); o nome do aceitante vai ao log sem máscara (`contrato_service.py:66`) | Enquanto o atendimento vigorar **+** guarda do prontuário (mín. 5 anos); se houver obrigação civil/fiscal associada ao contrato, o prazo aplicável ⚖️ | Art. 16, I; execução de contrato (art. 7º, V) para o instrumento | Eliminar o JSON completo após o prazo, preservando apenas o **comprovante do aceite** quando houver necessidade de prova. |
| **Lembretes** (telefone, mensagem, status, tentativas) | **Turso (EUA), em claro** (`db.py:199-213`); enviados por wuzapi; o nome do profissional e da pessoa vão na mensagem (`compromisso.dart:159-171`) | **90 dias** após o envio ou a última tentativa, o que ocorrer depois. Hoje: **indefinido** | Finalidade operacional (reduzir faltas) + minimização ⚖️ | Já existe `DELETE` por compromisso (`main.py:1397,1439`) — falta o expurgo **por idade**, automático. |
| **Dados de conta do profissional** (nome, e-mail, senha em hash, plano, tokens) | Turso (EUA) — `usuarios`, `recuperacoes`, `resets_senha` | Enquanto a conta existir **+** prazo legal/fiscal aplicável ⚖️. Hoje **não existe exclusão de conta** | Execução de contrato (art. 7º, V); art. 16, I | Fluxo de exclusão de conta ponta a ponta (P1.9, `02_plano_de_acao.md`), com janela de arrependimento e eliminação dos vínculos (`owner_id`). |
| **Telemetria** (`dispositivos`, `eventos`, heartbeat) | Turso (EUA); conteúdo por allowlist, sem PII clínica (`telemetria.py:1-26`) | **12 meses**, depois agregação anônima ou eliminação | Legítimo interesse (art. 7º, IX) ⚖️ + minimização | Rotina de expurgo por idade (**não existe**); hoje a telemetria **nunca é apagada** (`db.py:179-314`). |
| **Logs técnicos** (app, backend, log do serviço) | Aparelho (cifrado/redigido — `logger.dart:115-124`); arquivos locais do backend; log do serviço de deploy | **90 dias**, com expurgo automático e **zero segredo/PII clínica** no conteúdo | Art. 46 + minimização (art. 6º, III) | Rotação + expurgo. Hoje **não existe** `RotatingFileHandler` (0 ocorrências em `backend/`) e `backend/backend.launchd.log` tem **15,3 MB** com o segredo do webhook repetido **mais de 130 mil vezes** (ver §8.5). |
| **Logs de acesso e autenticação** | **Não existe trilha estruturada de acesso no servidor** — a auditoria vive só no aparelho (`auditoria_service.dart:1,17`); JWT de 8 h sem `jti`/revogação (`main.py:234-235`) | **6 meses** (proposta) ⚖️ — a confirmar a regra setorial aplicável | Segurança (art. 46) e prevenção a fraude (art. 7º, II e IX) | Implementar log mínimo (conta, IP, evento, resultado), sem conteúdo clínico, com prazo e expurgo definidos. |
| **Trilha de auditoria** (eventos LGPD no aparelho) | Aparelho, Hive; **máximo de 1000 registros com expurgo dos mais antigos** (`auditoria_service.dart:10,94-102`); `tipoEvento`, `pacienteId` e `dataHora` em claro (só a descrição é cifrada — `:79`) | **Todo o período de guarda do prontuário** (mín. 5 anos), **exportando/arquivando antes de qualquer poda**. Hoje: **PARCIAL** — a própria trilha se autodestrói | Art. 37 (accountability) + art. 46 | Exportar a trilha antes de podar (P2.1); adicionar eventos de eliminação, acesso, exportação e áudio (P2.2). |
| **Backups** | Gerados pelo profissional; o **servidor não tem rotina de backup do banco** (0 ocorrências de *dump*/*backup* no backend). O backup do app é **incompleto** (não inclui compromissos, anamnese, escalas, avaliação inicial nem auditoria — `backup_service.dart:33-154`) e **só abre no mesmo aparelho** (`:191-194`) | O MentAll **não retém** backup. Recomendação ao profissional: manter **as 2 últimas gerações + 1 cópia anual** e descartar as demais em **12 meses** | Continuidade (art. 46, disponibilidade) + minimização | Eliminação das gerações antigas pelo profissional; teste de restauração periódico (P3.3) — **a restauração completa não é possível hoje** (P2.15). |
| **PDFs exportados** (6 formatos) | **Fora do controle do MentAll** — saem pelo compartilhamento do sistema, **em claro, sem senha e sem evento de auditoria** (`pdf_export_service.dart:1544-1552`) | O MentAll **não retém**. Recomendação: eliminar após a finalidade; nunca manter em nuvem pessoal sem cifra. A **guarda legal** do conteúdo continua sendo do profissional | Art. 46; guarda do prontuário na origem | Exclusão pelo profissional; implementar **senha/cifra opcional + aviso de sigilo + evento de auditoria** (P1.16). |
| **Links públicos de anamnese e contrato** | Turso (EUA) — token sem coluna de expiração (`db.py:180-198`); a página pública embute o **nome da pessoa atendida** (`main.py:1468,1530,1650-1658`) | **Anamnese: 15 dias** · **Contrato: 30 dias** · revogáveis a qualquer momento; eliminar o token após o uso/prazo | Minimização + finalidade; segurança (art. 46) | Expiração no banco + rota de cancelamento + remoção do nome da página pública (P1.11). |

### 5.1 Leitura executiva da tabela

- **Só o prontuário tem prazo legal claro.** Todo o resto (áudio, anamnese, contrato, lembrete,
  telemetria, log, link) **não tem prazo definido em lugar nenhum** hoje.
- **O servidor não tem ciclo de vida de dado.** Nenhum caminho do backend apaga contratos, anamneses,
  lembretes, contas, dispositivos ou eventos (`db.py:179-314`); os únicos `DELETE` são de lembrete
  (`main.py:1397,1439`).
- **O mentir-por-omissão é o maior risco:** a Política atual diz "arquivamento em vez de exclusão"
  (`politica_privacidade_page.dart:82-84`) sem explicar a guarda legal — o que precisa ser corrigido
  na publicação (`05_politica_de_privacidade.md` §8).

---

## 6. Regra específica do áudio

O áudio é a categoria com pior relação risco × necessidade do produto. O estado verificado:

| Fato | Evidência |
|---|---|
| O arquivo é gravado **em claro** e só cifrado **depois** de parar a gravação | `audio_relato_service.dart:92` (grava) vs `:171` (cifra) |
| Queda, bateria ou encerramento no meio da gravação deixam relato clínico **em claro** no aparelho | idem; ausência de varredura de órfãos em `:416-437,509-512` |
| A exclusão existe, mas é disparada **sem espera** em um dos caminhos | `AGENTS.md`, auditoria de degradação silenciosa; `01_diagnostico_lgpd.md` §4.5 |
| **Não há evento de auditoria** para remoção/regravação de áudio | `auditoria_service.dart:31,70-126`; `AGENTS.md` |
| A Política atual **não menciona** prazo, opção de guardar ou descarte do áudio | `politica_privacidade_page.dart` (varredura) |
| Existe flag de "áudio mantido" no modelo da sessão | `models/sessao.dart:119-120` (`audioMantido`) |
| O backup **pode carregar o áudio** em base64 quando &lt; 500 kB, com flag de exclusão | `backup_service.dart:72-73,103-104` |

**Regra proposta (a declarar ao titular):**

1. **Padrão do produto: não manter.** Concluída a transcrição e o aceite do texto pelo profissional,
   o arquivo de áudio é eliminado em **até 24 h**, incluindo órfãos de gravação interrompida.
2. **Se o profissional optar por manter** (`audioMantido = true`), o áudio passa a ser **parte do
   prontuário** e segue a mesma guarda (mín. 5 anos) — ou um prazo menor declarado (recomendação:
   **90 dias**), desde que isso esteja escrito e o profissional saiba que o áudio **não** será
   recuperável depois. ⚖️
3. **Nunca em claro**: a gravação deve ocorrer já em contêiner cifrado, ou cifrada em blocos durante
   a gravação (P0.8).
4. **Sempre com evento**: gravação, cifra, transcrição, remoção e regravação geram evento de
   auditoria (P2.2, P2.5).
5. **No backup**: o áudio só entra no backup se a opção de manter estiver ativa **e** o profissional
   confirmar — hoje ele entra silenciosamente quando pequeno (`backup_service.dart:72-73,103-104`).

**Referência de mercado (13/10/2026):** a **PsiLuz** declara que o áudio "é excluído definitivamente
quando a gravação é excluída ou quando o paciente é excluído" e a **Copilloto** declara áudio
"deletado em 24h". Ambos **reforçam** a regra "não manter" acima — nenhum concorrente promete guarda
longa do áudio (`18_comparativo_concorrentes.md`).

> ⚖️ **Pendência jurídica:** decidir se o áudio do relato (voz do profissional, conteúdo clínico) é
> documento do prontuário ou insumo descartável. A decisão muda o prazo, o texto ao titular e o
> desenho do backup.

---

## 7. Eliminação a pedido do titular × guarda obrigatória ⚖️

O direito de eliminação (art. 18, VI) **não é absoluto**. Quando o titular pede eliminação de dado
clínico, o roteiro abaixo evita promessa que não pode ser cumprida.

### 7.1 Roteiro de decisão (para o psicólogo, com apoio do MentAll)

| Etapa | Pergunta | Se SIM | Se NÃO |
|---|---|---|---|
| 1 | O dado pedido é **prontuário / documento psicológico** sob guarda obrigatória? | Não eliminar agora; informar prazo e fundamento | Ir à etapa 2 |
| 2 | O dado foi tratado com **consentimento** (ex.: áudio, IA, WhatsApp)? | Atender a revogação e eliminar o que não estiver sob outra base | Ir à etapa 3 |
| 3 | O dado é **desnecessário, excessivo ou tratado em desconformidade** (art. 16, IV; art. 18, IV)? | Eliminar, bloquear ou anonimizar imediatamente | Ir à etapa 4 |
| 4 | O dado é **operacional** (lembrete, log, link, telemetria)? | Eliminar em até **15 dias**, com confirmação por escrito | Ir à etapa 5 |
| 5 | Persiste **necessidade de conservação para exercício regular de direitos** (art. 16, II)? | Conservar apenas o mínimo necessário e registrar o motivo | Eliminar e confirmar |

### 7.2 Fundamento legal que sustenta a recusa parcial ⚖️

- **LGPD, art. 16, I** — a conservação é autorizada para **cumprimento de obrigação legal ou
  regulatória** pelo controlador. É esse o dispositivo que sustenta a manutenção do prontuário.
- **LGPD, art. 18, VI** — o direito de eliminação é expressamente **ressalvado** pelas hipóteses do
  art. 16.
- **Res. CFP nº 001/2009, art. 4º, §1º** — guarda por **no mínimo 5 anos**, ampliável por lei/decisão
  judicial. É a "obrigação legal ou regulatória" que aciona o art. 16, I.
- **Res. CFP nº 001/2009, art. 5º, II** — **acesso integral** ao usuário ou ao representante legal:
  o pedido de **acesso** quase sempre **pode** ser atendido, ainda que a **eliminação** não possa.
- ⚖️ A referência de **20 anos** é **orientação de conselho regional** (CRP-MT), combinando a Lei nº
  13.787/2018 e a Res. CFM nº 1.821/2007 — **não** é regra do CFP e não deve ser apresentada como
  obrigação nacional.

### 7.3 O que o MentAll pode e não pode fazer ⚖️

| Pedido | Posição do MentAll (operador) | Posição do psicólogo (controlador) |
|---|---|---|
| Acesso/confirmação sobre dado clínico | Apoia tecnicamente (exportação) e **encaminha**, registrando | Decide e responde; entrega em formato útil |
| Eliminação de dado clínico | **Não decide**; informa que o dado está sob guarda do controlador | Decide, à luz do art. 16, I; se puder eliminar, instrui o MentAll |
| Eliminação de áudio/lembrete/log | Executa o descarte operacional | Informa ao titular |
| Eliminação de conta do profissional | Executa (é controlador) | — |
| Correção de dado clínico | Apoia; não altera conteúdo clínico por conta própria | Executa e registra a correção |

**Frase-modelo para a resposta (não usar sozinha, adaptar):**

> "Seu pedido de **eliminação** foi registrado sob o protocolo nº ___. Parte do registro que você
> pede integra o **prontuário psicológico**, cuja guarda é exigida por **no mínimo 5 (cinco) anos**
> (Resolução CFP nº 001/2009, art. 4º, §1º), prazo que pode ser ampliado por lei ou decisão judicial.
> A LGPD autoriza essa conservação para cumprimento de obrigação legal (art. 16, I) e ressalva a
> hipótese no direito de eliminação (art. 18, VI). **O que não está sob guarda obrigatória foi
> eliminado**, conforme detalhado abaixo." ⚖️

---

## 8. Descarte seguro por ambiente

| Ambiente | O que descartar | Como (regra técnica) | Cuidado específico |
|---|---|---|---|
| **8.1 Aparelho do profissional** | Prontuário, áudio, transcrições, sínteses, cache, arquivos de exportação temporários | (a) exclusão lógica pelo serviço, com confirmação e evento de auditoria; (b) remoção dos arquivos físicos de áudio e temporários; (c) **cripto-descarte**: destruir a chave mestra torna o Hive ilegível | Hoje **não existe evento de exclusão** (`auditoria_service.dart:31`); a exclusão de áudio é disparada sem espera; não há varredura de órfãos no boot. Destruir a chave **sem plano de recuperação** torna o prontuário irrecuperável (P2.13). |
| **8.2 Servidor (Turso EUA + backend)** | Contrato, anamnese, lembrete, telemetria, tokens, dados de conta | `DELETE` **verificado** (confirmar contagem = 0), com registro de quem/quando/quantos; expurgo por idade para lembrete, telemetria e link. Considerar que **réplicas, snapshots e backups do provedor** podem sobreviver ao `DELETE` — exige cláusula contratual e verificação ⚖️ | **Nenhuma rotina existe hoje** (`db.py:179-314`). O backend roda em Fly `gru`, mas o banco está nos EUA (`backend/.env`, `aws-us-west-2.turso.io`) — o descarte precisa ser confirmado **no provedor**, não só na API. |
| **8.3 Cópia local de desenvolvimento** | `backend/data/mentall.db` + `-wal` + `-shm` (**arquivo em claro com dados reais**, 09/10/2026) | Eliminar os três arquivos; impedir que o fallback SQLite volte a criar base com dado real (`ALLOW_SQLITE_FALLBACK` default `true` — `db.py:15-17`) | É o item **P0.11**. O `-wal` de 111 KB pode conter dado não consolidado — apagar só o `.db` **não** resolve. |
| **8.4 Backups e exportações do profissional** | Gerações antigas de backup; PDFs já usados | Exclusão pelo próprio profissional; recomendação de retenção mínima (2 gerações + 1 anual) | O MentAll **não consegue** apagar arquivo que já saiu do app (`pdf_export_service.dart:1544-1552`). A política precisa dizer isso com clareza. |
| **8.5 Logs** | Log do app, log do backend, log do serviço e logs do provedor | Rotação + expurgo por idade; **expurgo imediato** do log atual que contenha segredo ou PII | O log do webhook foi montado com o token na *query string* (`wuzapi_admin.py:47-49`) e aparece **mais de 130 mil vezes** em `backend/backend.launchd.log` (15,3 MB). O nome do aceitante de contrato vai ao log sem máscara (`contrato_service.py:66`). Ação: **P1.13**. |
| **8.6 Links públicos** | Tokens de anamnese e contrato | Expiração + revogação + remoção do nome da página pública | Hoje o token é a chave primária e **não tem expiração** (`db.py:180-198`); a página embute o nome da pessoa (`main.py:1468,1530,1650-1658`). |

---

## 9. O que hoje não existe e precisa ser implementado

Todos os itens abaixo vêm do `02_plano_de_acao.md`. A coluna "P" usa a prioridade daquele documento
(**P0** = antes do próximo release; **P1** = 30 dias; **P2** = 90 dias).

| # | Lacuna de retenção/descarte | P | Evidência |
|---|---|---|---|
| 9.1 | **Nenhum ciclo de vida de dado no servidor**: sem coluna de expiração, sem job de expurgo, sem endpoint de exclusão para contrato/anamnese/telemetria/conta | **P0/P1** | `db.py:179-314`; `main.py:1397,1439` (únicos `DELETE`) |
| 9.2 | **Cópia local em texto claro com dados reais** a eliminar | **P0** | `backend/data/mentall.db`, `-wal`, `-shm` |
| 9.3 | **Áudio em claro durante a gravação** e sem varredura de órfãos | **P0** | `audio_relato_service.dart:92` vs `:171`; `:416-437,509-512` |
| 9.4 | **Exclusão de conta inexistente** (loja + art. 18, VI) | **P1** | varredura de `main.py`; `conta_page.dart` |
| 9.5 | **Política de retenção publicada** com prazos declarados | **P1** | este documento; `politica_privacidade_page.dart:82-84` |
| 9.6 | **Links públicos com expiração e revogação** | **P1** | `db.py:180-198`; `main.py:1468,1530,1650-1658` |
| 9.7 | **Segredo/PII fora de URL e expurgo dos logs** | **P1** | `wuzapi_admin.py:47-49`; `contrato_service.py:66`; `backend/backend.launchd.log` |
| 9.8 | **PDF com senha/cifra e evento de auditoria na exportação** | **P1** | `pdf_export_service.dart:1544-1552` |
| 9.9 | **Trilha de auditoria exportável, sem poda silenciosa** | **P2** | `auditoria_service.dart:10,94-102` |
| 9.10 | **Eventos de auditoria** de eliminação, acesso, exportação, backup e áudio | **P2** | `auditoria_service.dart:31,70-126`; `AGENTS.md` |
| 9.11 | **Log de erro de IA sem eco de conteúdo clínico** | **P2** | `ia_clinica.py:668,671` |
| 9.12 | **Backup completo + teste de restauração** | **P2/P3** | `backup_service.dart:33-154,191-194` |
| 9.13 | **Descarte de telemetria e de log por idade** (nada é apagado hoje) | **P2** | `db.py:179-314`; 0 `RotatingFileHandler` |

---

## 10. Cronograma de expurgo, responsável e evidência de execução

> Enquanto os itens de §9 não estiverem implementados, o expurgo é **manual**. A tabela abaixo é o
> regime-alvo **e** o registro de exequibilidade. "Responsável" é papel (a ser preenchido com nome no
> documento 17).

| Rotina | Frequência | Responsável | Evidência de execução | Estado hoje |
|---|---|---|---|---|
| Expurgo de **lembretes** com mais de 90 dias | mensal | MentAll (operação) | Consulta de contagem antes/depois + registro datado | **NÃO EXISTE** (só `DELETE` por compromisso) |
| Expurgo de **telemetria** com mais de 12 meses | mensal | MentAll | Contagem + registro | **NÃO EXISTE** |
| Expurgo de **links** de anamnese/contrato expirados | diário (job) | MentAll | Log do job + contagem | **NÃO EXISTE** (sem coluna de expiração) |
| Expurgo de **logs** técnicos com mais de 90 dias | semanal | MentAll | Data do último expurgo + tamanho do log | **NÃO EXISTE** (sem rotação) |
| **Varredura de áudio órfão** no boot do app | a cada inicialização | App (MentAll) | Evento de auditoria "áudio órfão removido" | **NÃO EXISTE** |
| Expurgo do **áudio** não mantido | diário (job no app) | MentAll (ferramenta) | Evento de auditoria + contagem | **PARCIAL** (exclusão existe, sem garantia nem evento) |
| Exclusão de **anamnese** no servidor após recebimento | mensal | MentAll | Protocolo + contagem | **NÃO EXISTE** |
| **Exclusão de conta** a pedido do profissional | sob demanda (15 dias) | MentAll | Protocolo + confirmação ao titular | **NÃO EXISTE** |
| Eliminação de **dado clínico** a pedido do titular (o que não está sob guarda) | sob demanda (15 dias) | Psicólogo decide; MentAll executa | Protocolo + resposta por escrito + evento | **NÃO EXISTE** |
| Descarte de **cópias de trabalho** (`backend/data/*.db`, `-wal`, `-shm`) | imediato e a cada deploy | MentAll | Checklist de deploy | **PENDENTE (P0.11)** |
| **Teste de restauração** de backup | anual | Profissional + MentAll | Termo de teste datado | **NÃO EXISTE** (P3.3) |
| Revisão desta política | semestral ou a cada mudança | Encarregado (doc. 13) | Versão publicada + registro de revisão | **NÃO EXISTE** |

**Critério de pronto da política:** (a) uma rotina automática para cada linha com frequência
"diária/mensal"; (b) registro de execução recuperável; (c) texto público coerente com o que existe;
(d) exclusão de dado clínico com confirmação por escrito ao titular.

---

## 11. Revisão e atualização

Esta política é revisada **a cada mudança que crie, altere ou elimine categoria de dado** (novo
provedor, novo campo, novo país, novo prazo legal) e, no mínimo, a cada **seis meses**. Cada revisão
gera nova versão datada; a versão em vigor é a publicada em URL, e o app exibe a mesma versão
(`02_plano_de_acao.md`, P0.5).

### 11.1 Decisões que precisam ser registradas

Estas decisões **ainda não foram tomadas** e devem entrar no `17_registro_de_decisoes_e_revisoes.md`:

| Decisão | Opções | Impacto se não decidir |
|---|---|---|
| **Prazo do áudio** (manter × não manter × por quanto tempo) | (a) descarte imediato após transcrição; (b) manter 90 dias; (c) tratar como prontuário (5 anos) | O app continua sem prazo e o texto ao titular continua incompleto (§6) |
| **Prazos do servidor** (anamnese, contrato, lembrete, telemetria, log) | Definir prazo e rotina para cada categoria | Nada é apagado hoje (`db.py:179-314`) e o ROPA permanece rascunho |
| **Contagem da guarda do prontuário** (5 × 20 anos) | Adotar o piso do CFP ou a orientação regional | A resposta ao titular sobre eliminação fica sem fundamento estável (§7.2) |
| **Recuperação de chave × guarda legal** | Definir mecanismo de recuperação sem quebrar o sigilo | Perda do aparelho = perda definitiva do prontuário (§8.1) |

---

## Pendências de validação jurídica

| # | Pendência | Onde impacta | Situação |
|---|---|---|---|
| 1 | ⚖️ **Prazo definitivo do prontuário psicológico**: 5 anos (piso do CFP) × 20 anos (Lei nº 13.787/2018 + Res. CFM nº 1.821/2007 + orientação do CRP-MT). Confirmar se a orientação regional se aplica ao consultório e como declarar isso ao titular. | §4.2, §5 (prontuário), §7.2 | NÃO CONFIRMADO |
| 2 | ⚖️ **Natureza do áudio**: insumo descartável após transcrição ou documento do prontuário sob guarda de 5 anos? | §6, §5 (áudio) | NÃO CONFIRMADO |
| 3 | ⚖️ **Prazo de retenção no servidor** para contrato, anamnese e lembrete, e a base legal de cada um. | §5 | NÃO CONFIRMADO |
| 4 | ⚖️ **Prazo de retenção de logs de acesso** e eventual regra setorial aplicável (verificar incidência da Lei nº 12.965/2014 sobre logs de aplicação). | §5 (logs de acesso) | NÃO CONFIRMADO |
| 5 | ⚖️ **Descarte efetivo no provedor de banco**: verificar se `DELETE` alcança réplicas, snapshots e backups da Turso/AWS e o que o contrato garante. | §8.2 | NÃO CONFIRMADO |
| 6 | ⚖️ **Redação exata do roteiro de recusa parcial de eliminação** (art. 16, I × art. 18, VI) para uso em resposta ao titular. | §7 | NÃO CONFIRMADO |
| 7 | ⚖️ **Papel do encarregado** na aprovação e revisão desta política (art. 41). | §10, §11 | depende do documento 13 |
| 8 | ⚖️ **Verificação da retenção nos provedores de IA** (OpenAI, DeepSeek, Groq) para sustentar o prazo das transcrições e sínteses. | §5 | NÃO CONFIRMADO |
| 9 | ⚖️ **Enquadramento como agente de pequeno porte** e o que isso flexibiliza nos prazos e nas rotinas de registro. | §10 | NÃO CONFIRMADO |

> Este documento **não é parecer jurídico** e não substitui a análise de advogado especializado em
> proteção de dados. Enquanto as pendências acima estiverem abertas, os prazos aqui propostos **não
> podem** ser publicados como definitivos.
