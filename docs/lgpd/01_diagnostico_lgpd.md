# Diagnóstico LGPD — MentAll PRO

**Versão:** 1.0 (rascunho para revisão) · **Data:** 09/10/2026
**Objeto:** aplicativo MentAll PRO (cliente Flutter `1.0.49` + backend FastAPI)
**Base:** código-fonte, configuração de produção e documentos do próprio projeto
**Natureza:** diagnóstico técnico de conformidade. **Não é parecer jurídico** — os pontos
marcados com ⚖️ dependem de validação por advogado especializado antes de virarem compromisso
público.

---

## 1. Sumário executivo (o retorno em uma página)

O MentAll PRO é tecnicamente **bem construído no aparelho** — cifra AES-GCM com chave no
Keychain/Keystore, `allowBackup=false`, trilha de auditoria, avisos de revisão humana. O problema
não está no que o app protege: está no que ele **não conta** e no que ele **manda para fora**.

**Os cinco riscos que precisam de decisão sua, em ordem:**

1. **O prontuário está no exterior, em claro.** O banco Turso de produção roda em
   `aws-us-west-2.turso.io` (**Oregon, EUA**), enquanto o backend está em `gru` (São Paulo). Contrato
   terapêutico, respostas de anamnese, telefone e nome de pessoas atendidas são gravados **sem
   cifra no servidor** (`db.py:180-213`, `contrato_service.py:14-15`). A Política de Privacidade
   atual diz que os dados ficam no dispositivo e que nada clínico vai a servidor externo sem
   consentimento explícito (`politica_privacidade_page.dart:57-66`). ⚖️ Transferência internacional
   sem salvaguarda documentada (arts. 33-36).

2. **A IA de síntese clínica pode processar o conteúdo na China, automaticamente.** A ordem de
   provedores em produção é `openai,deepseek` (`AGENTS.md:191`) e a **mesma requisição** é reenviada
   ao provedor seguinte quando o primeiro falha (`ia_clinica.py:761-781`). Ou seja: o dado de saúde
   pode ser transferido a **dois países diferentes na mesma operação**. O app faz uma
   **pseudonimização parcial** do nome antes de enviar (primeiro nome + iniciais dos sobrenomes —
   `ia_clinica_service.dart:185-198`), o que é um ponto positivo — **mas** o `/gerar-progresso`
   envia `paciente_id`, sessões anteriores, queixa principal e escalas **sem pseudonimização**
   (`ia_clinica_service.dart:313-323`), e o relato/transcrição vão literais, sendo o conteúdo
   clínico identificável por si só. Não há `store: false` nem configuração de retenção zero em
   nenhum payload, e o profissional não é avisado nem escolhe o provedor.

3. **O que o app promete não corresponde ao que ele faz.** A Política de Privacidade cita
   "OpenAI ou Google Gemini" (`:71-73`); os Termos de Uso citam "OpenAI Whisper" e "OpenAI GPT-4.1"
   (`:35-36`). O que existe em produção é **Groq** (áudio), **OpenAI** (síntese) e **DeepSeek**
   (fallback) — Gemini está fora. Isso é divergência material de informação ao titular. ⚖️

4. **Faltam os instrumentos de governança obrigatórios:** não há contrato controlador-operador
   (DPA), encarregado (DPO) nomeado, canal do titular, registro das operações (ROPA), RIPD,
   política de retenção, plano de incidentes nem termo de consentimento do paciente. Ou seja:
   a base existe, a **accountability documentada** não.

5. **O servidor não tem ciclo de vida de dado nenhum.** Não existe endpoint de exclusão de dados do
   titular, retenção, expurgo automático nem exportação/portabilidade no backend — contratos,
   anamneses, lembretes, contas e telemetria **nunca são apagados** (`db.py:179-314`; os únicos
   `DELETE` são de lembrete). Além disso, há uma **cópia local em texto claro com dados reais**
   (`backend/data/mentall.db`, 3 contratos e 1 anamnese) e `ALLOW_SQLITE_FALLBACK` tem default
   `true` (`db.py:15-17`), o que faz o sistema confirmar gravação que se perde no restart.
6. **Trilha de auditoria que se apaga e áudio com exclusão não garantida.** A trilha mantém no
   máximo 1000 registros e **apaga os mais antigos** (`auditoria_service.dart:10,94-102`); não há
   evento de remoção/regravação de áudio (o próprio projeto registra essa falta). A auditoria vive
   **só no aparelho** — o servidor não tem trilha de acesso a dado clínico.
7. **Credenciais e segredos em log.** O token do webhook do WhatsApp é montado na *query string*
   (`wuzapi_admin.py:47-49`) e aparece **mais de 130 mil vezes** em `backend.launchd.log` — o próprio
   projeto proíbe "logar URL com token" (`AGENTS.md:1321`). O nome de quem assina contrato vai para
   o log sem máscara (`contrato_service.py:66`).
8. **No aparelho, o bloqueio pode falhar aberto e o áudio fica em claro.** Em lockout de biometria,
   erro de hardware ou ausência de credencial, o app carrega a **chave mestra sem pedir nada**
   (`auth_service.dart:203-215,237-250`). O áudio do relato é gravado em **texto claro** e só é
   cifrado depois que a gravação para (`audio_relato_service.dart:92` vs `:171`) — queda, bateria ou
   encerramento deixam relato clínico persistido em claro, e **não há varredura de órfãos**. A chave
   nunca é apagada da memória ao bloquear (`encryption_service.dart:656-663` sem chamador) e não há
   `FLAG_SECURE`.

**O que já está bom e não deve ser desfeito:** cifra **por campo** AES-GCM no aparelho com chave em
Keystore/Keychain (`encryption_service.dart:13-18,43-47,89-90,502-523` — atenção: **não** é o banco
inteiro, ver C6), envelope de backup AES-GCM + HMAC-SHA256, `android:allowBackup="false"`
(`AndroidManifest.xml:13`), telemetria sem PII por allowlist (`telemetria.py:1-26`), Sentry
desligado por padrão e sem PII (`main.dart:73-105`), gate de revisão humana antes de salvar, log
técnico cifrado/redigido (`logger.dart:115-124`), isolamento por `owner_id` no backend com testes
de IDOR, e um PDF de arquitetura LGPD com 14 seções que já reconhece as lacunas
(`pdf_arquitetura_lgpd_service.dart:351-354`).

**Prioridade prática:** antes de publicar nas lojas, resolva os itens **1 a 4** e o item **8** (falhas
que já expõem o prontuário no aparelho, hoje). O bloqueio mais concreto apontado pelo próprio projeto
é a **ausência de Política de Privacidade e Termos em URL pública** (`tasks/lojas_app.md:32-34`) — o
site institucional irmão (`site-mentall-pro`) só tem `index.html`.

---

## 2. Escopo e método

- **O que foi analisado:** cliente Flutter (`lib/`), backend FastAPI (`backend/`), configuração de
  deploy (`fly.toml`, `render.yaml`, `.env`), manifesto Android, e a documentação interna
  (`AGENTS.md`, `docs/`, `auditoria/`, `tasks/`).
- **O que não foi analisado:** o APK compilado byte a byte, os servidores da Turso/Fly/Groq/OpenAI/
  Gemini/DeepSeek, contratos comerciais assinados e o site institucional em produção.
- **Regra de evidência:** toda afirmação factual traz `arquivo:linha`. O que não pôde ser
  verificado está marcado como **[A CONFIRMAR]** e não deve ser usado como fato em documento
  público.

### Como ler a severidade

| Nível | Significado prático |
|---|---|
| **CRÍTICO** | Exposição atual de dado sensível, transferência irregular ou afirmação falsa ao titular. Corrigir antes de novo release/loja. |
| **ALTO** | Instrumento obrigatório ausente ou controle que falha de forma silenciosa. Corrigir em semanas. |
| **MÉDIO** | Fragilidade relevante, sem exposição imediata. Planejar. |
| **BAIXO** | Ajuste de forma, clareza ou robustez. |

---

## 3. Enquadramento de papéis

| Papel | Quem | Base |
|---|---|---|
| **Controlador** (art. 5º, VI) | O psicólogo responsável pelo atendimento | Declarado pelo próprio app (`politica_privacidade_page.dart:76-77`) |
| **Operador** (art. 5º, VII) | MentAll PRO, quanto ao prontuário e aos dados clínicos | idem |
| **Controlador** | MentAll PRO, quanto aos dados de conta do profissional (`usuarios`), telemetria (`eventos`, `dispositivos`) e segurança (`recips`, `resets_senha`) | `db.py` (tabelas), `telemetria.py:1-26` |

**Consequência prática:** o MentAll responde ao titular **junto com** o psicólogo. Quando o titular
pede eliminação de um dado clínico, quem decide é o psicólogo (com a guarda legal do prontuário);
quando o titular reclama de transferência internacional para IA, o MentAll precisa demonstrar
salvaguarda. Por isso os dois documentos centrais são o **DPA** (documento 04) e o **canal do
titular** (documento 13).

⚖️ **Nuance jurídica a validar:** o uso de IA para síntese **não** é, em si, "procedimento realizado
por profissional de saúde" para os fins do art. 11, II, "f". O enquadramento mais seguro tende a ser
consentimento específico e destacado para o uso de IA (art. 11, I), registrado no prontuário — com
a tutela da saúde sustentando o **prontuário em si**. Isso precisa de confirmação jurídica antes de
virar texto público.

---

## 4. Achados

### 4.1 Transferência internacional (o achado estrutural)

| # | Destinatário | País | O que sai | Evidência |
|---|---|---|---|---|
| T1 | **Turso / AWS us-west-2** | EUA | Contrato terapêutico, respostas de anamnese, telefone, mensagem de lembrete, nome do aceitante, e-mail do profissional | `backend/.env` (`TURSO_DATABASE_URL` → `aws-us-west-2.turso.io`); `db.py:37-38,180-213` |
| T2 | **Groq** | EUA | **Áudio do relato clínico** (base64) | `transcricao.py:13-20,64-65,85-88` |
| T3 | **OpenAI** | EUA | Nome da pessoa atendida + relato clínico integral | `ia_clinica.py:438-454,627-632`; `main.py:890-893` |
| T4 | **DeepSeek** | **China** | Nome da pessoa atendida + relato clínico integral (fallback automático) | `ia_clinica.py:635-690` (endpoint `:648`); `AGENTS.md:191` |
| T5 | **Wuzapi** (WhatsApp não oficial) | a definir | Nome da pessoa, telefone, data/hora da sessão | `compromisso.dart:159-171`; `lembrete_service.py:92-114` |

**Gravidade específica:** a divergência entre `fly.toml:2-3` (`primary_region = "gru"`) e o banco nos
EUA cria uma falsa sensação de "dados no Brasil". Além disso, **T4 acontece sem decisão humana
informada** — o circuito de provedores troca para o DeepSeek quando a OpenAI falha.

⚖️ Quanto a salvaguardas, o Brasil não tem decisão de adequação para China nem para EUA; a
transferência precisa de um dos mecanismos do art. 33 (cláusulas-padrão, garantias específicas,
consentimento específico e destacado). **Validar redação e mecanismo com advogado.**

### 4.2 Base legal e consentimento

- Não existe **nenhum registro de consentimento** do titular (pessoa atendida) no app: os
  "Consentimentos" aparecem no backlog do próprio layout como **não implementados**
  (`pdf_arquitetura_lgpd_service.dart:241`).
- Nenhum documento diz ao psicólogo **o que perguntar** à pessoa atendida antes de usar áudio/IA.
- O profissional também não aceita termos/DPA no onboarding — **[A CONFIRMAR]** (depende da
  auditoria do fluxo de cadastro).

→ Implicação: sem base legal documentada por finalidade, o MentAll não consegue demonstrar
conformidade no art. 7º/11, e o psicólogo não consegue provar que informou o titular.

### 4.3 Transparência — o que o app promete vs. o que ele faz

| Promessa no app | Onde | Realidade verificada |
|---|---|---|
| "Serviços de IA (OpenAI ou Google Gemini)" | `politica_privacidade_page.dart:71-73` | Omite **Groq** e **DeepSeek**; cita **Gemini**, que está fora da ordem de produção |
| "Transcrição (via OpenAI Whisper)… síntese (via OpenAI GPT-4.1)" | `termos_uso_page.dart:35-36` | Produção: **Groq** (áudio) + **OpenAI** + **DeepSeek** (fallback) |
| "Os dados são armazenados localmente no dispositivo do profissional" | `politica_privacidade_page.dart:57` | Contrato, anamnese, telefone e lembretes ficam em banco nos **EUA** |
| "Nenhum dado clínico é armazenado em servidores externos sem consentimento explícito" | `politica_privacidade_page.dart:63-64` | Não há mecanismo de consentimento implementado para isso |
| "não são armazenados pelos provedores de IA para treinamento (conforme políticas da OpenAI e Google)" | `politica_privacidade_page.dart:105-108` | Não comprovado; ignora Groq e DeepSeek; ausência de `store:false` no payload |
| Contato: "fale com o desenvolvedor" | `politica_privacidade_page.dart:119-122` | **Sem encarregado (DPO), sem e-mail, sem canal** (art. 41) ⚖️ |
| "Arquivamento em vez de exclusão" | `politica_privacidade_page.dart:82-84` | Precisa explicar a guarda legal do prontuário, senão conflita com o art. 18, VI ⚖️ |
| "Última atualização: Julho de 2026" | `politica_privacidade_page.dart:122`, `termos_uso_page.dart:101` | Desatualizado face ao código atual |

### 4.4 Direitos do titular (art. 18)

- A Política atual **empurra o dever inteiro** para o profissional ("O profissional… deve atender às
  solicitações", `politica_privacidade_page.dart:89-98`) sem dar a ele procedimento, prazo, modelo
  de resposta ou registro.
- Não existe canal de entrada (e-mail/formulário) nem fluxo interno de atendimento.
- **Portabilidade:** existe exportação em PDF pelo profissional, mas é um recurso clínico dele, não
  um mecanismo de portabilidade do titular. **[A CONFIRMAR]** se os 6 formatos de exportação cobrem
  os dados pessoais do titular por completo (`pdf_export_service.dart`).
- O app **não permite** que o titular (que não é usuário do app) exerça correção diretamente.
- **Revisão de decisões automatizadas (art. 20):** a síntese por IA é apoio documental com revisão
  humana obrigatória — o desenho é favorável, mas isso precisa estar escrito na política.

### 4.5 Retenção, arquivamento e eliminação

- A regra declarada é **arquivar, não excluir** (`politica_privacidade_page.dart:82-84`).
- `excluirPaciente` faz hard delete em cascata e **não tem chamador em produção** — dead code com
  potencial destrutivo (`AGENTS.md`, "Achados da auditoria da documentação").
- Não existe **prazo de retenção** definido em lugar nenhum, nem rotina de descarte/expurgo.
- Não existe política para **áudio**: por quanto tempo fica, se é apagado após a transcrição, o que
  acontece se a exclusão falhar. O projeto já registra que a exclusão do áudio é `unawaited`.
- Marcações sugerem que prontuário psicológico tem **guarda legal obrigatória** ⚖️ — o que significa
  que "direito de eliminação" não é absoluto, mas precisa ser explicado com precisão ao titular
  (documento 10).

### 4.6 Governança e accountability

Ausentes, todos confirmados: **DPA** (o próprio PDF de arquitetura marca "Acordo de Tratamento de
Dados" como `false` — `pdf_arquitetura_lgpd_service.dart:354`), **ROPA** (art. 37), **RIPD**
(art. 38 — exigível neste caso: dado sensível + IA + transferência internacional), **DPO/encarregado**
(art. 41), **política de retenção**, **plano de incidentes**, **registro de decisões** e **material
do psicólogo**. A tarefa "Revisão LGPD dedicada" está aberta no próprio backlog
(`tasks/todo.md:63`) — este pacote a executa.

### 4.7 Segurança da informação

**No aparelho (bom):** AES-GCM com chave mestra no Android Keystore/iOS Keychain e derivação PBKDF2
(`encryption_service.dart:13-18,43-47,89-90`), leitura de formato legado CBC apenas para
compatibilidade (`:483`), envelope de backup AES-GCM + HMAC-SHA256 (`:525,588`),
`android:allowBackup="false"` (`AndroidManifest.xml:13`), permissões coerentes com a função
(`:2-8` — microfone, internet, biometria, notificações, alarme).

**No servidor (fraco):**
- **Sem cifra em repouso**: `json.dumps(dados)` gravado direto (`contrato_service.py:14-15`);
  nenhum serviço do backend cifra conteúdo antes de persistir.
- **Erro de provedor vai para o log**, potencialmente com eco de conteúdo clínico:
  `log.error("DeepSeek síntese retornou %d: %s", ..., resp.text[:500])` (`ia_clinica.py:673-676`).
- **Perda silenciosa admitida:** `/health` responde `ok` mesmo com banco em fallback SQLite, e
  `ALLOW_SQLITE_FALLBACK` tem default `true` no repositório (`AGENTS.md`) — em queda da Turso o
  sistema aceita escrita e confirma sucesso, e o dado some no restart. Para um prontuário com guarda
  legal, isso é grave ⚖️.
- **Auditoria incompleta:** `_registrarAuditoria` não é `await`ado (`AGENTS.md`).

### 4.8 Trilha de auditoria

- Boa ideia, execução com furos: **limite de 1000 registros com expurgo dos mais antigos**
  (`auditoria_service.dart:10,94-102`) — a própria trilha de conformidade se autodestrói;
- eventos cobertos: gravação, transcrição, síntese/IA, revisão, cadastro, arquivamento,
  restauração, exportação, agendamento (`:19-34`);
- **não há eventos** para eliminação, acesso/consulta, cópia/backup, remoção/regravação de áudio e
  alteração de dados cadastrais — o próprio projeto registra a falta do evento de áudio
  (`AGENTS.md`).
- As descrições são cifradas (`:79`) e o log técnico não recebe conteúdo — **ponto forte**.

### 4.9 WhatsApp não oficial (wuzapi)

- A mensagem padrão revela que a pessoa **é paciente de psicologia** e o nome do profissional:
  `"Olá {nome}, lembrete da sua sessão com {profissional}..."` (`compromisso.dart:159-171`),
  enviada por gateway **não oficial** (`lembrete_service.py:92-114`).
- Riscos: exposição a terceiro sem contrato de tratamento de dados, ausência de previsão nos
  documentos, e conflito com as regras da Meta ⚖️.
- Nada no app pede consentimento específico para contato por WhatsApp.

### 4.10 Menores de idade

- Não há tratamento específico para dados de criança/adolescente no que foi verificado: nenhum
  campo de responsável legal, nenhum consentimento específico, nenhuma menção na política.
- Em psicologia isso é frequente, e o art. 14 exige cuidado reforçado ⚖️. **Lacuna relevante.**

### 4.11 Lojas (Google Play / App Store)

- O próprio projeto identifica o bloqueio: **Política de Privacidade e Termos só existem como
  páginas in-app**; o site institucional irmão tem apenas `index.html` e nenhum deploy dessas
  páginas (`tasks/lojas_app.md:32-34`).
- Falta o formulário **Data Safety** (Play) e o **App Privacy** (Apple), coerentes com o que o app
  realmente faz — hoje os textos in-app levariam a uma declaração **incorreta** (omitindo transferência
  e provedores).
- Falta **URL de exclusão de conta** e fluxo de exclusão — exigência do Play para apps com conta.
- Categoria declarada de Saúde exige cuidado redobrado com dado sensível, e o Play mantém um
  **formulário obrigatório de declaração de apps de saúde** para todos os desenvolvedores.
- **Regra de "compartilhamento" no Data Safety:** o Play só dispensa declarar compartilhamento quando
  o terceiro é **prestador de serviços** que processa sob instruções do desenvolvedor — o que
  **pressupõe contrato**. Sem DPA assinado, a resposta honesta hoje é **"compartilhado"**.
- **Apple 5.1.2(i)** exige **divulgar e pedir permissão explícita** para o uso de **IA de terceiros**
  — o card de aviso atual só fala de revisão humana, então isso é bloqueio de loja, não só de LGPD.
- **Apple 5.1.3(ii)** veda armazenar **informação de saúde no iCloud**; não foi encontrada exclusão de
  backup (`NSURLIsExcludedFromBackupKey`) no código — risco aberto a verificar.
- **Sem exclusão de conta** no app nem no backend: bloqueio de reprovação nas duas lojas.

### 4.12 Incidentes

- Não existe plano, nem registro de incidentes, nem criticério de quando comunicar. Todo o
  procedimento dependeria hoje de improviso — exatamente o cenário em que o prazo regulatório de
  comunicação à ANPD é perdido ⚖️ (documento 11).

### 4.13 Achados do backend (auditoria dedicada)

**Ciclo de vida do dado — inexistente no servidor.** Contratos, anamneses, lembretes, contas,
dispositivos e eventos **nunca são apagados** por nenhum caminho do backend (`db.py:179-314`). Os
únicos `DELETE` existentes são de lembrete (`main.py:1397,1439`). Não há coluna de expiração, job de
expurgo, política de retenção nem endpoint de exportação/portabilidade. Consequência: os arts. 16 e
18 (IV, VI) **não são atendíveis pelo servidor** — e o titular não tem como pedir.

**Cópia local em texto claro com dados reais.** Existe `backend/data/mentall.db` com contratos e
anamnese reais em claro — dado de titular fora do ambiente controlado, sem cifra e sem política de
descarte. Somado ao fallback ativo (`db.py:15-17`), forma um caminho de perda/sobra de dados.

**`APP_USER_ID` ausente da configuração.** Sem a variável, o backend gera um UUID novo a cada boot
(`main.py:241`) → contratos, anamneses e lembretes criados pelo login legado ficam **órfãos a cada
restart**. É perda de dado de titular por configuração (art. 46) e quebra o acesso (art. 18, II).

**Credencial legada compartilhada.** `APP_USERNAME`/`APP_PASSWORD_HASH` é uma conta única
(`main.py:236-240,710-719`) e **todos os usuários dessa conta compartilham o mesmo `owner_id`** —
não há segregação entre profissionais nesse caminho. O JWT dura 8 h (`main.py:234-235`), sem
revogação, sem `jti`, sem logout no servidor. A auditoria de acesso **não existe no servidor**: a
trilha é só no aparelho (`auditoria_service.dart:1,17`).

**Pontos positivos verificados (registrar para não perder):** isolamento por `owner_id` existe e
está correto nos endpoints auditados, com testes dedicados de IDOR
(`tests/test_status_idor.py`, `test_recuperacao_idor.py`, `test_lembrete_idor.py`); nenhum IDOR de
paciente/sessão foi encontrado (não há tabela de paciente/sessão no servidor); o `.env` **nunca foi
commitado** (`.gitignore:2-3`) e a varredura do histórico por chaves/tokens não achou nada.

**Outros itens que entram no plano de ação:**
- **Links públicos sem expiração nem revogação**: anamnese e contrato ficam válidos enquanto a
  linha existir; a página pública embute o **nome da pessoa atendida** (`main.py:1468,1530,1650-1658`)
  e `/anamneses/{token}/status` devolve as respostas (dado de saúde) ao dono autenticado.
- **CORS de produção com origens de desenvolvimento** (`localhost:5000/8000/3000`) e
  `allow_credentials=True` (`main.py:647-664`).
- **Token da instância do WhatsApp gravado no banco estrangeiro** (`wuzapi_instancias.wuzapi_token`,
  `db.py:261-267`) — segredo de sessão do profissional fora do Brasil.
- **OpenAlex recebe descritores clínicos** (ex.: "depressão maior") e o **e-mail pessoal** do
  profissional como `mailto` (`ia_clinica.py:56-63,83-91`).
- **Rate limit em memória** por processo (`main.py:202-228`) e `/health` público sempre `ok`
  (`main.py:688-700`).
- **Sem `RotatingFileHandler`** e sem expurgo de log; `/health` e logs acumulam 21 MB locais.

### 4.14 Achados do cliente Flutter (auditoria dedicada)

**O que está certo e deve ser preservado:** cifra por campo AES-GCM com chave no Keystore/Keychain
(`encryption_service.dart:502-523`), envelope de backup AES-GCM + HMAC-SHA256 correto
(`:530-592`), `allowBackup="false"` e `usesCleartextTraffic="false"` (`AndroidManifest.xml:13-14`),
permissões proporcionais (`:2-8`), Sentry **desligado por padrão** e configurado sem PII
(`main.dart:73-105`), `logger.dart:115-124` que cifra ou redige o log técnico, e o gate de revisão
humana antes de salvar. Nada disso precisa ser desfeito.

**Falhas de segurança com efeito direto na LGPD (art. 46):**

| # | Achado | Evidência | Consequência |
|---|---|---|---|
| C1 | **Áudio clínico em texto claro**: o `.m4a` é gravado em claro e só cifrado **depois** do `stop()`; sem varredura de órfãos no boot | `audio_relato_service.dart:92` vs `:171`, `:416-437`, `:509-512` | Queda/bateria/kill deixa relato clínico persistido em claro, sem prazo nem limpeza |
| C2 | **Desbloqueio fail-open**: lockout de biometria, erro de hardware ou ausência de credencial carregam a chave mestra sem prompt; só há um `SnackBar` | `auth_service.dart:203-215,237-250`; `login_page.dart:56-66` | Terceiro com o aparelho desbloqueado abre o prontuário |
| C3 | **PIN inexistente em instalação nova**; a reautenticação para exportar backup não funciona | `encryption_service.dart:399-406`; `backup_restore_page.dart:24-35` | A promessa "Bloqueio por PIN" (`politica_privacidade_page.dart:60`) não se sustenta |
| C4 | **Certificate pinning inefetivo**: a impressão digital é comparada dentro de `badCertificateCallback`, que **só é chamado quando a validação padrão já falhou** — no caminho normal (certificado válido, inclusive de uma CA instalada no aparelho) o pin não é verificado | `main.dart:45-68` | Contradiz `SECURITY_CHANGELOG.md` (SEC-05) e cria falsa sensação de proteção |
| C5 | **Bloqueio apenas visual**: `EncryptionService.limpar()` nunca é chamado, a chave permanece em memória; sem `FLAG_SECURE`; sem detecção de root | `encryption_service.dart:656-663`; `app_lock_gate.dart:95-113` | Dado decifrado acessível durante o "bloqueio"; captura de tela possível |
| C6 | **Campos sensíveis em claro no Hive**: data de nascimento, tipo/modo de atendimento ("Convênio"), valores e status/forma de pagamento, data da sessão, flags de áudio/IA | `models/paciente.dart:13-14,19-20,49-50`; `models/sessao.dart:20,119-120,158-168`; `sessao_service.dart:80` | "Criptografia AES-256 em repouso" não cobre esses dados (art. 46) |
| C7 | **PDF de prontuário em claro**, sem senha, sem aviso no arquivo e sem evento de auditoria, saindo pelo compartilhamento do sistema | `pdf_export_service.dart:1544-1552`; `paciente_detail_page.dart:573-648` | Saída não rastreável de dado sensível para qualquer destino |
| C8 | **Chave mestra sem vínculo com a autenticação** e sem rekey/recuperação; backup só abre no mesmo aparelho | `encryption_service.dart:70,252-264`; `backup_service.dart:191-194` | Perda do Keystore = perda irreversível do prontuário (art. 46, disponibilidade) |
| C9 | **Backup incompleto e com sobrescrita silenciosa**: não inclui compromissos, anamnese, escalas, avaliação inicial nem auditoria; exporta campos sem decifrar | `backup_service.dart:33-154,166-180`; `pacote_service.dart:41`; `progresso_service.dart:36-39` | Restauração parcial silenciosa — risco clínico e de conformidade |
| C10 | **Código morto capaz de reverter proteção**: `removerCriptografiaExistente` em 11 serviços, sem chamador | `paciente_service.dart:168`; `sessao_service.dart:252`; `configuracoes_service.dart:178` | Uma chamada acidental desprotege o prontuário inteiro |
| C11 | **Telemetria sempre ativa**, com `device_id` persistente e **sem opt-out** | `telemetria_service.dart:16-40,72-90`; `app_lock_gate.dart:39,74-82` | Rastreamento pseudônimo contínuo sem escolha nem aviso destacado (art. 9º/18) |
| C12 | **iOS sem `NSFaceIDUsageDescription`** e sem `ITSAppUsesNonExemptEncryption`; nome iOS ainda "Prontuario Tcc" | `ios/Runner/Info.plist:10` | Risco de reprovação na App Store e incoerência de marca |
| C13 | **Demo seed em instalação nova** ("Linda M. Tester") | `demo_data_service.dart:35-78`; `main.dart:192` | Dados fictícios indistinguíveis de dados reais, salvo por badge |

**Direitos do titular no cliente:** `excluirPaciente` faz hard delete em cascata e **não tem nenhum
chamador** (`paciente_service.dart:113-166`); a UI só arquiva/restaura; **não existe exclusão de
conta**; não há tela de solicitação do titular nem consentimento do titular — o próprio PDF de
arquitetura marca esses módulos como não implementados (`pdf_arquitetura_lgpd_service.dart:241,245,
296-308`). O único traço de consentimento é um checkbox de perfil **sem persistência de data/versão**
(`perfil_profissional_form_page.dart:918-922`), e `onboarding_page.dart:9-21` é **código morto**.

**Auditoria incompleta:** faltam eventos de **exportação, exclusão, remoção/regravação de áudio,
acesso, import/export de backup** (`auditoria_service.dart:31,70-126`); a gravação é
*fire-and-forget* em `sessao_form_page.dart:168-178`; a trilha é truncada em 1000 e **decifra a
descrição no próprio objeto** (`:110,123`), o que a torna mutável em memória.

**Menores (art. 14):** existem data de nascimento e idade, mas **nenhum campo de responsável legal,
autorização ou consentimento de menor** — lacuna relevante em psicologia.

---

## 5. Matriz de risco (probabilidade × impacto)

| Risco | Prob. | Impacto | Nível | Onde atacar |
|---|---|---|---|---|
| Transferência internacional de dado sensível sem salvaguarda (Turso EUA / IA) | Alta | Alto | **CRÍTICO** | Docs 08, 09; decisão de arquitetura |
| Informação enganosa ao titular sobre terceiros de IA | Alta | Alto | **CRÍTICO** | Docs 05, 06, 07 |
| Dado de saúde em claro no banco estrangeiro (anamnese, contrato, telefone) | Alta | Alto | **CRÍTICO** | P0.4 (cifrar ou parar de persistir) |
| Ausência de exclusão, retenção e portabilidade no servidor | Alta | Alto | **CRÍTICO** | Doc 10; P1.9 |
| Segredo de webhook e PII em log sem expurgo | Alta | Médio/Alto | **ALTO** | Plano de ação |
| Cópia local em texto claro com dados reais (`backend/data/mentall.db`) | Média | Alto | **ALTO** | Plano de ação |
| `APP_USER_ID` efêmero → dados órfãos a cada restart | Alta | Alto | **ALTO** | Plano de ação |
| Vazamento em PDF/backup/WhatsApp | Média | Alto | **ALTO** | Docs 10, 12, 14 |
| Falta de registro de consentimento/base legal do titular | Alta | Alto | **ALTO** | Doc 07 |
| Ausência de DPA, DPO, ROPA, RIPD | Alta | Médio/Alto | **ALTO** | Docs 04, 08, 13 |
| Perda silenciosa de dados (fallback SQLite) | Média | Alto | **ALTO** | Plano de ação |
| Trilha de auditoria truncada em 1000 eventos | Alta | Médio | **MÉDIO** | Plano de ação |
| Sanção ANPD (arts. 52-54) | Baixa/Média | Alto | **MÉDIO** | Pacote inteiro |
| Bloqueio/reprovação nas lojas | Média | Médio | **MÉDIO** | Doc 15 |

---

## 6. Referências normativas verificadas (09/10/2026)

Verificadas em fonte oficial. **Nada aqui é parecer jurídico** — é a régua usada neste diagnóstico.

| Norma | O que exige | Impacto no MentAll |
|---|---|---|
| **LGPD art. 11** | Bases legais de dado **sensível**; **não** admitem legítimo interesse (art. 7º, IX) nem execução de contrato (art. 7º, V) | Prontuário se ancora em tutela da saúde (art. 11, II, "f"); **o envio de áudio/texto clínico a IA exige consentimento específico e destacado (art. 11, I) ou cláusulas-padrão, + RIPD** ⚖️ |
| **LGPD art. 12** | Anonimização ≠ pseudonimização | A pseudonimização de nome no app **não** descaracteriza dado pessoal |
| **LGPD arts. 16 e 18** | Término, eliminação e direitos do titular | Não atendíveis no servidor (não há exclusão, retenção nem portabilidade) |
| **LGPD art. 20** | Decisão automatizada: revisão e trilha | A IA é apoio documental com revisão humana obrigatória — ponto favorável, desde que documentado e auditável |
| **LGPD arts. 33-36 + Res. CD/ANPD nº 32/2026** | Transferência internacional e adequação | **A UE/EEE foi reconhecida como adequada; EUA e China NÃO.** As transferências atuais (Turso, Groq, OpenAI, DeepSeek) seguem sem salvaguarda documentada |
| **Res. CD/ANPD nº 19/2024** | Mecanismos de transferência (cláusulas-padrão) | Caminho a adotar se a arquitetura não mudar |
| **LGPD art. 37** | Registro das operações | Documento 03. **Não há regulamento autônomo da ANPD sobre ROPA** — trate como boa prática, não invente exigência formal |
| **LGPD art. 38** | RIPD | Documento 08. Também **sem regulamento autônomo** vigente — boa prática |
| **LGPD art. 41 + Res. CD/ANPD nº 18/2024** | Encarregado: ato formal escrito/datado/assinado, **divulgação pública**, substituto, vedação de conflito de interesse; indicação pelo operador é facultativa (boa prática) | Documento 13 — hoje inexistente |
| **LGPD art. 48 + Res. CD/ANPD nº 15/2024** | Comunicação de incidente: **3 dias úteis** à ANPD e ao titular (em dobro para pequeno porte), **12 itens mínimos**, complementação em **20 dias úteis**, **registro por 5 anos inclusive dos não comunicados** | Documento 11 — hoje inexistente; sem plano, o prazo será perdido |
| **LGPD art. 52** | Sanção: multa de até **2% do faturamento no Brasil** (excluídos tributos), limitada a **R$ 50.000.000,00 por infração**, além de publicização, bloqueio, eliminação e suspensão | Dimensão do risco |
| **Lei nº 15.352/2026** | ANPD passa a **Agência Nacional de Proteção de Dados** (autonomia; regulamenta o ECA Digital) | Fiscalização mais estruturada |
| **ECA Digital (Lei nº 15.211/2025), vigente desde 17/03/2026** | Proteção reforçada de menores | O app **não tem** campo de responsável legal nem consentimento de menor (art. 14) — lacuna relevante |
| **Res. CFP nº 001/2009** | Guarda do prontuário psicológico: **piso de 5 anos** | Base da política de retenção (documento 10) |
| **Lei nº 13.787/2018 + Res. CFM nº 1.821/2007** | Prontuário médico: 20 anos | Referência comparativa; a extensão ao prontuário psicológico vem de **orientação do CRP-MT**, não do CFP ⚖️ |
| **Res. CFP nº 9/2024** | Exercício da Psicologia mediado por TDICs — **revoga expressamente a Res. CFP nº 011/2018 e a nº 4/2020** | **Nunca citar a 011/2018 como vigente** em material do produto |
| **PL 2338/2023** | Marco legal da IA | **Não é lei** (na Câmara, aguardando relator). Não citar como vigente |
| **Res. CD/ANPD nº 30/2025** | Temas prioritários de fiscalização 2026-2027, incluindo **IA e tecnologias emergentes**; Sandbox Regulatório de IA em andamento | Contexto de risco: IA em dado sensível está no radar |
| **Nota do CFP de 05/09/2025** | Software de IA em saúde mental deveria ter aprovação prévia da ANVISA (RDC 657/2022 — SaMD) ⚖️ | **Questão de alto impacto a validar** — não afirmar que o MentAll é SaMD |

**Não confirmado / requer validação jurídica:** texto oficial das políticas da Meta sobre WhatsApp não
oficial (as páginas não renderizaram); existência de guia da ANPD específico sobre dados de saúde;
prazo definitivo de guarda do prontuário psicológico (5 anos como piso legal x 20 anos por orientação
regional); enquadramento como dispositivo médico (SaMD).

---

## 7. Encaminhamento

1. **Decidir as duas questões de arquitetura** (documento 09): (a) mover o banco para região
   brasileira ou documentar a transferência; (b) remover o DeepSeek da ordem de provedores ou
   obter consentimento específico e destacado para ele.
2. **Publicar os textos corrigidos** em URL pública (documentos 05 e 06) — desbloqueia as lojas.
3. **Assinar o DPA com o psicólogo** (documento 04) e entregar o material do titular (documento 07).
4. **Nomear o encarregado e abrir o canal** (documento 13).
5. **Formalizar ROPA, RIPD, retenção, incidentes e segurança** (documentos 03, 08, 10, 11, 12).
6. **Executar o plano de ação** (documento 02) e o checklist (documento 16).

O detalhamento de cada item, com responsável e critério de pronto, está em
`02_plano_de_acao.md`.
