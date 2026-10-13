# Plano de Resposta a Incidentes de Segurança com Dados Pessoais — MentAll PRO

**Versão:** 1.0 (rascunho para revisão) · **Data:** 09/10/2026
**Produto:** MentAll PRO — prontuário clínico psicológico com IA
**Fundamento:** LGPD, Lei nº 13.709/2018, arts. 46, 48 e 50; **Resolução CD/ANPD nº 15, de 24/04/2024**
(Regulamento de Comunicação de Incidente de Segurança); **Resolução CD/ANPD nº 2, de 27/01/2022**
(agentes de tratamento de pequeno porte)
**Natureza:** procedimento operacional em rascunho. **Não é parecer jurídico.** Pontos marcados com ⚖️
dependem de validação por advogado. O MentAll PRO está **em adequação** — este plano não declara
conformidade.

**Documentos oficiais consultados (verificados em 09/10/2026):**

- [Resolução CD/ANPD nº 15/2024 — Regulamento de Comunicação de Incidente de Segurança (DOU/in.gov.br)](https://www.in.gov.br/en/web/dou/-/resolucao-cd/anpd-n-15-de-24-de-abril-de-2024-556243024)
- [Canal oficial de Comunicação de Incidente de Segurança (ANPD gov.br)](https://www.gov.br/anpd/pt-br/canais_atendimento/agente-de-tratamento/comunicado-de-incidente-de-seguranca-cis)
- Contato da área responsável na ANPD: **incidentes@anpd.gov.br** (CTIS/CGIS/SFI/ANPD), conforme a página oficial acima
- [Resolução CD/ANPD nº 19/2024 — transferência internacional e cláusulas-padrão (gov.br)](https://www.gov.br/anpd/pt-br/acesso-a-informacao/institucional/atos-normativos/regulamentacoes_anpd/resolucao-cd-anpd-no-19-de-23-de-agosto-de-2024)

---

## 1. Definição de incidente e escopo

### 1.1 O que é incidente

**Incidente de segurança:** qualquer **evento adverso confirmado** relacionado à violação das
propriedades de **confidencialidade, integridade, disponibilidade e autenticidade** de dados pessoais
(Resolução CD/ANPD nº 15/2024, art. 3º, XII e VIII). Não é preciso haver vazamento consumado: basta o
comprometimento confirmado de uma dessas propriedades.

**Dado pessoal afetado:** aquele cuja confidencialidade, integridade, disponibilidade ou autenticidade
tenha sido comprometida no incidente (art. 3º, VIII).

### 1.2 Quando **precisa** ser comunicado (art. 5º da Res. 15/2024) ⚖️

A comunicação à ANPD e ao titular é devida quando o incidente **puder afetar significativamente
interesses e direitos fundamentais** dos titulares **E**, cumulativamente, envolver **ao menos um** dos
critérios:

| Inciso | Critério | **O MentAll PRO se encaixa?** |
|---|---|---|
| I | **dados pessoais sensíveis** | **SIM, sempre** — relato, áudio, transcrição, síntese e anamnese são dado sensível de saúde (art. 11 da LGPD) |
| II | **dados de crianças, adolescentes ou idosos** | **SIM, sempre que houver menor** — o produto atende psicologia infantil e não tem controle específico |
| III | dados financeiros | Possível — valores/forma de pagamento ficam **em claro no Hive** (`models/sessao.dart:158-168`) |
| IV | **dados de autenticação em sistemas** | **SIM** — tokens, hashes de senha, token de sessão do wuzapi (`db.py:261-267`) |
| V | **dados protegidos por sigilo legal, judicial ou profissional** | **SIM, sempre** — o prontuário psicológico é protegido por **sigilo profissional** (art. 3º, X) |
| VI | dados em larga escala | Depende do volume — avaliar caso a caso (art. 5º, §2º: número significativo de titulares + volume + duração + frequência + extensão geográfica) |

**Consequência operacional decisiva para o MentAll PRO:** como o produto trata, por definição, dado
sensível de saúde **e** dado protegido por sigilo profissional, **todo incidente confirmado que
comprometa dado clínico é, em regra, comunicável** — sem discussão longa sobre "dano concreto". A
presunção só é afastada com **fundamento técnico registrado** (§4.2).

> A ANPD é explícita: *"A obrigação do art. 48 da LGPD não se cumpre com a mera comunicação do
> incidente de segurança à ANPD. Havendo risco ou dano relevante, o controlador deve, necessariamente,
> comunicar o ocorrido aos titulares dos dados pessoais violados no incidente."* — página oficial do
> [canal de CIS](https://www.gov.br/anpd/pt-br/canais_atendimento/agente-de-tratamento/comunicado-de-incidente-de-seguranca-cis).

### 1.3 Escopo deste plano

**Incluído:** incidentes que envolvam dados pessoais tratados pelo MentAll PRO, no aparelho do
profissional ou no backend, nas finalidades clínicas e próprias.

**Excluído:** indisponibilidade sem comprometimento de dado pessoal; falhas de desempenho; incidentes
em sistemas de terceiros que **não** tratem dado pessoal do produto.

---

## 2. Exemplos reais deste produto

> Cada exemplo abaixo tem **evidência no código ou na configuração**. São os cenários que o simulado de
> mesa (§9) deve usar — não cenários genéricos de manual.

| # | Cenário | Como aconteceria | Evidência | Propriedade afetada | Comunicável? |
|---|---|---|---|---|---|
| **I1** | **Perda ou roubo do aparelho do profissional** | Terceiro com o aparelho **desbloqueado** abre o prontuário: em lockout biométrico, erro de hardware ou ausência de credencial, o app carrega a **chave mestra sem pedir nada** (*fail-open*) | `auth_service.dart:203-215,237-250`; e a chave **nunca é apagada da memória** ao bloquear (`encryption_service.dart:656-663`, sem chamador) | Confidencialidade | **SIM** — dado sensível de saúde, em regra com muitos titulares no mesmo aparelho |
| **I2** | **PDF de prontuário vazado** | PDF exportado **em claro, sem senha, sem aviso no arquivo e sem evento de auditoria**, entregue ao compartilhamento do sistema (e-mail, mensageiro, nuvem pessoal, pendrive) | `pdf_export_service.dart:1544-1549` (`Printing.sharePdf`); `PdfExportService` **não tem nenhuma referência a auditoria**; `paciente_detail_page.dart:573-648` | Confidencialidade | **SIM** — saída não rastreável de dado sensível; destino fora do controle do MentAll |
| **I3** | **Acesso indevido pela tela administrativa** | Sessão de admin comprometida (cookie `mentall_admin`) dá acesso a KPIs e à **lista de usuários** (e-mail, nome, plano, status, último acesso). Hoje **não há dado clínico** no painel, mas há PII de profissionais e um caminho privilegiado para escalar | `main.py:2055-2091` (exige `role == "admin"`); `admin.py:52-68` (`SELECT id, email, nome, plano, role, status, ...`); `admin_ui.py:86-123` | Confidencialidade | **SIM** — dados de autenticação/identificação e, no mínimo, avaliação obrigatória |
| **I4** | **Vazamento do segredo do webhook do WhatsApp — JÁ OCORREU** | O `WUZAPI_WEBHOOK_TOKEN` é montado na **query string** e aparece **130.603 vezes** em `backend/backend.launchd.log`. O log nunca é expurgado e não há `RotatingFileHandler`. O próprio projeto proíbe "logar URL com token" | `wuzapi_admin.py:47-49`; contagem verificada em 09/10/2026 (o diagnóstico registrava 130.593); `01_diagnostico_lgpd.md` §4.13 | Confidencialidade + Autenticidade | **SIM** — segredo de autenticação de sistema (critério IV) **já comprometido** |
| **I5** | **Banco em fallback perdendo dados** | Em queda do Turso, `ALLOW_SQLITE_FALLBACK` (default `true`) aceita a escrita no SQLite local, **confirma sucesso** ao usuário e o dado **desaparece no restart** — e `/health` continua respondendo `ok` | `db.py:15-17`; `main.py:688-700`; `01_diagnostico_lgpd.md` §4.13 | Disponibilidade + Integridade | **SIM** — perda de prontuário com guarda legal (avaliar também o dever de informar o controlador) |
| **I6** | **Token de anamnese vazado** | O token do link público **não expira nem é revogável**; a página pública **embute o nome da pessoa atendida**; e `/anamneses/{token}/status` devolve as **respostas** (dado de saúde) ao dono autenticado | `main.py:1468,1530,1650-1658`; `db.py:189-198` (sem coluna de expiração) | Confidencialidade | **SIM** — anamnese é dado sensível e o nome está exposto na própria página |
| **I7** | **Áudio clínico em texto claro no aparelho** | O `.m4a` é gravado em claro e cifrado **só depois** do `stop()`; queda, bateria ou encerramento deixam o relato persistido em claro; **não há varredura de órfãos** no boot; a exclusão do áudio é `unawaited` | `audio_relato_service.dart:92` vs `:171`; `01_diagnostico_lgpd.md` §4.14 (C1) | Confidencialidade | **SIM** |
| **I8** | **Conteúdo clínico em log de erro** | Falha do provedor DeepSeek grava o corpo da resposta em log: `log.error("DeepSeek síntese retornou %d: %s", ..., resp.text[:500])`; o nome do aceitante vai sem máscara | `ia_clinica.py:673-676`; `contrato_service.py:66` | Confidencialidade | **SIM** — avaliar com prioridade |
| **I9** | **Dados órfãos por reinício** | Sem `APP_USER_ID`, o backend gera **UUID novo a cada boot**: contratos, anamneses e lembretes criados pelo login legado ficam inacessíveis | `main.py:241` | Disponibilidade | **SIM** — quebra o acesso do titular (art. 18, II) |
| **I10** | **Cópia local em texto claro com dados reais** | `backend/data/mentall.db` (73.728 bytes, verificado em 09/10/2026) com dados de titulares **sem cifra** | `01_diagnostico_lgpd.md` §4.13; arquivo verificado no repositório | Confidencialidade | **SIM** — dado de titular fora do ambiente controlado |

### 2.1 Incidentes que **já ocorreram** e precisam de tratamento retroativo

Dois casos acima **não são hipotéticos**:

1. **I4 — segredo do webhook exposto em log**, confirmado por contagem no arquivo. O segredo está
   comprometido desde a primeira gravação; enquanto não for **rotacionado**, qualquer pessoa com
   acesso ao log pode forjar requisições ao webhook. Ação: **P1.13**.
2. **I10 — cópia local com dados reais**, arquivo existente e legível. Ação: **P0.11**.

⚖️ **Decisão jurídica necessária:** avaliar se esses dois casos exigem **comunicação retroativa**
(art. 48) ou se se enquadram em incidente sem risco relevante a titulares, com **fundamento registrado**
no registro de incidentes (§7). Enquanto a avaliação não estiver registrada, tratar como **pendência
aberta** — não como "não incidente".

---

## 3. Papéis: quem decide, quem executa, quem comunica

### 3.1 Estrutura

| Papel | Quem ocupa | Responsabilidade |
|---|---|---|
| **Encarregado (DPO)** | **A nomear — item P1.1. Hoje inexistente** (`politica_privacidade_page.dart:119-122`) | Ponto focal do plano; **é quem protocola a comunicação no SEI!ANPD**, com documento comprobatório de vínculo (Res. 15/2024, art. 6º, §5º). Sem encarregado, o plano **não funciona** |
| **Coordenador de incidente** (decisor) | Dono do produto ou quem ele designar | Decide contenção, aciona o jurídico, aprova a comunicação, autoriza o encerramento |
| **Responsável técnico** (executor) | Engenharia (backend/cliente) | Contenção técnica, coleta de evidências, correção, *post-mortem* técnico |
| **Jurídico / privacidade** ⚖️ | Advogado externo (a contratar) | Decide o enquadramento (art. 5º, risco relevante), redige e revisa as comunicações |
| **Comunicação** | Dono do produto | Texto ao titular e ao público, em linguagem simples |
| **Controlador — psicólogo** | Cliente do MentAll | **Recebe o aviso e decide o que é do prontuário dele**; é quem responde ao titular pelo conteúdo clínico; comunica o titular quando for o caso |
| **Suporte / atendimento** | Primeira linha | **Ponto de detecção mais provável**; registra e escala em até 1 hora |
| **Registro** | Encarregado | Mantém o registro de incidentes por **no mínimo 5 anos** (art. 10 da Res. 15/2024) |

### 3.2 Regra de substituição (o plano não pode depender de uma pessoa)

Cada papel tem **suplente nomeado** com o mesmo acesso. Enquanto não houver encarregado e advogado
contratados, o **dono do produto assume as duas funções interinamente** — com registro expresso de que a
acumulação é provisória e é um risco (⚖️ quem investiga e decide a comunicação não deveria ser,
idealmente, a mesma pessoa que executou a contenção).

### 3.3 Quem comunica o quê

```
DETECÇÃO (qualquer pessoa)  →  escalonamento em até 1 h
        ↓
COORDENADOR + TÉCNICO        →  contenção (§5.2)
        ↓
JURÍDICO + ENCARREGADO       →  avaliação de risco relevante (§4.2)
        ↓
     ┌── risco relevante? ──┐
    SIM                     NÃO
     ↓                       ↓
ENCARREGADO protocola      Registro com fundamento
no SEI!ANPD (3 dias úteis)  (guardar 5 anos)
     ↓
COORDENADOR/DONO avisa o PSICÓLOGO CONTROLADOR (até 24 h)
     ↓
PSICÓLOGO comunica o TITULAR (3 dias úteis) — com apoio do MentAll
```

**Nota de papéis:** a obrigação do art. 48 é do **controlador**. Para o dado clínico, o controlador é
**o psicólogo**; para conta e telemetria, é o **MentAll**. Quando o incidente atingir dado clínico, o
MentAll **não substitui** o psicólogo na comunicação ao titular — **apoia** (fornece lista, texto,
prazo e prova), e o MentAll comunica à ANPD na qualidade de operador solidário e informa o
controlador ⚖️. A repartição exata precisa estar no DPA (documento 04, cláusula 8).

---

## 4. Critério de decisão e prazo regulatório

### 4.1 Prazo ⚖️

| Obrigação | Prazo | Fonte |
|---|---|---|
| Comunicar **a ANPD** | **3 (três) dias úteis**, contados do **conhecimento** de que o incidente afetou dados pessoais | Resolução CD/ANPD nº 15/2024, **art. 6º, caput e §1º** |
| Comunicar **o titular** | **3 (três) dias úteis**, contados do mesmo conhecimento | Resolução CD/ANPD nº 15/2024, **art. 9º, caput** |
| Complementar informações à ANPD | até **20 (vinte) dias úteis**, de maneira fundamentada, a contar da comunicação | Resolução CD/ANPD nº 15/2024, **art. 6º, §3º** |
| Declarar que comunicou os titulares | em até **3 (três) dias úteis** contados do término do prazo de comunicação ao titular | Resolução CD/ANPD nº 15/2024, **art. 9º, §4º** |
| Guardar o **registro do incidente** | **mínimo de 5 (cinco) anos**, inclusive para incidentes **não** comunicados | Resolução CD/ANPD nº 15/2024, **art. 10, caput** |
| Agentes de **pequeno porte** | prazos dos arts. 6º e 9º **contados em dobro** | Resolução CD/ANPD nº 15/2024, art. 6º, §8º e art. 9º, §6º ⚖️ — **verificar se o MentAll se enquadra**; **NÃO CONFIRMADO — validar com advogado**. Não presuma o benefício |

**Regras práticas de contagem:**

- **Não são 72 horas.** São **3 dias úteis** — o prazo não corre em fim de semana e feriado, mas
  **começa a correr no momento do conhecimento**, não no momento da confirmação completa do escopo.
- **Conhecimento ≠ certeza.** Se a equipe sabe que houve acesso indevido a dado pessoal, o prazo já
  começou. Informação incompleta **não** adia o prazo: comunica-se o que se sabe e complementa-se
  depois (art. 6º, §3º).
- **Comunicação parcial fundamentada** é a regra, não a exceção. Se o prazo for perdido, o **motivo da
  demora** é campo obrigatório da comunicação (art. 6º, §2º, V).
- **Prazos internos deste plano são mais curtos que o regulatório** de propósito: 24 h para o
  diagnóstico inicial e 48 h para a decisão de comunicar — para nunca chegar ao terceiro dia útil sem
  texto pronto.

### 4.2 Critério de decisão ⚖️

**Pergunta 1 — houve comprometimento confirmado de confidencialidade, integridade, disponibilidade ou
autenticidade de dado pessoal?**
Não → não é incidente de dados pessoais; encerrar com registro interno.
Sim → seguir.

**Pergunta 2 — o incidente pode afetar significativamente interesses e direitos fundamentais dos
titulares?**
Considerar, entre outras situações (art. 5º, §1º): impedir o exercício de direitos ou o uso de um
serviço; causar dano material ou moral; discriminação; violação à integridade física, à imagem ou à
reputação; fraude financeira; roubo de identidade.
Não → registrar com fundamento; revisar se surgirem fatos novos.
Sim → seguir.

**Pergunta 3 — o caso se enquadra em ao menos um critério do art. 5º?**
Sensível (I) · crianças/adolescentes/idosos (II) · financeiro (III) · autenticação (IV) · sigilo
legal/judicial/profissional (V) · larga escala (VI).

**Regra de decisão deste plano:** se a resposta à Pergunta 2 é "sim" **e** ao menos um critério da
Pergunta 3 está presente → **COMUNICAR**, salvo se houver **fundamento técnico-jurídico escrito** de
que, no caso concreto, não há risco relevante. **Na dúvida, comunique.**

### 4.3 Árvore de decisão para o MentAll PRO

```
Incidente confirmado
    │
    ├─ Envolve relato, áudio, transcrição, síntese, anamnese ou contrato?
    │        │
    │        SIM ─→ critérios I (sensível) e V (sigilo profissional) presentes
    │        │       ─→ COMUNICAR (regra padrão)
    │        │
    │        └─ Envolve menor de idade?
    │                 SIM ─→ critério II também presente ─→ COMUNICAR (reforçado)
    │
    ├─ Envolve token, senha, hash, segredo de webhook ou sessão?
    │        SIM ─→ critério IV presente ─→ COMUNICAR se houver risco de acesso a dado pessoal
    │
    ├─ É apenas indisponibilidade, sem comprometer dado pessoal?
    │        SIM ─→ não é CIS; registrar como incidente operacional
    │
    └─ Ainda em dúvida? ─→ tratar como comunicável até prova em contrário documentada
```

### 4.4 Conteúdo mínimo da comunicação ⚖️

**À ANPD — Resolução CD/ANPD nº 15/2024, art. 6º, §2º (12 itens obrigatórios):**

| Inciso | Conteúdo |
|---|---|
| I | Descrição da **natureza** e da **categoria** dos dados pessoais afetados |
| II | **Número de titulares afetados**, discriminando, quando aplicável, quantos são crianças, adolescentes ou idosos |
| III | **Medidas técnicas e de segurança** utilizadas para proteção dos dados, **adotadas antes e depois** do incidente (ressalvados segredos comercial e industrial) |
| IV | **Riscos** do incidente, com identificação dos possíveis **impactos** aos titulares |
| V | **Motivos da demora**, se a comunicação não ocorreu no prazo |
| VI | **Medidas adotadas ou a adotar** para reverter ou mitigar os efeitos |
| VII | **Data da ocorrência** (quando possível) e **data do conhecimento** pelo controlador |
| VIII | Dados do **encarregado** ou de quem represente o controlador |
| IX | **Identificação do controlador** e, se for o caso, declaração de agente de pequeno porte |
| X | **Identificação do operador**, quando aplicável |
| XI | **Descrição do incidente**, incluindo a **causa principal**, se possível identificá-la |
| XII | **Total de titulares** cujos dados são tratados nas atividades afetadas |

**Ao titular — Resolução CD/ANPD nº 15/2024, art. 9º, caput (7 itens obrigatórios):**

| Inciso | Conteúdo |
|---|---|
| I | Descrição da **natureza** e da **categoria** dos dados afetados |
| II | **Medidas técnicas e de segurança** utilizadas para proteção dos dados |
| III | **Riscos** do incidente e possíveis **impactos** ao titular |
| IV | **Motivos da demora**, se houver |
| V | **Medidas adotadas ou a adotar** para reverter ou mitigar os efeitos, quando cabíveis |
| VI | **Data do conhecimento** do incidente |
| VII | **Contato para informações** e, quando aplicável, **dados do encarregado** |

**Requisitos de forma da comunicação ao titular (art. 9º, §§1º a 3º):**

- linguagem **simples e de fácil entendimento**;
- **direta e individualizada** sempre que possível (telefone, e-mail, mensagem eletrônica ou carta);
- se a comunicação individual for **inviável** ou o titular não puder ser identificado, comunicar pelos
  meios disponíveis (sítio, aplicativo, mídias sociais, canais de atendimento), de modo que permita
  **conhecimento amplo e fácil visualização por no mínimo 3 (três) meses**.
- **Boa prática recomendada pelo próprio Regulamento (art. 9º, §5º):** incluir **recomendações** para
  reverter ou mitigar os efeitos — isso conta a favor na dosimetria (art. 52, §1º, IX da LGPD).

**Via de protocolo:** a comunicação é feita por **peticionamento eletrônico no SEI!ANPD**, pelo
**encarregado** (ou representante legalmente constituído), com **documento comprobatório de vínculo**
contratual, empregatício ou funcional — ou instrumento com poderes de representação (art. 6º, §5º e
§6º). O formulário/rota está em
[Comunicação de Incidente de Segurança](https://www.gov.br/anpd/pt-br/canais_atendimento/agente-de-tratamento/comunicado-de-incidente-de-seguranca-cis).
**Documentos que devem acompanhar a comunicação** (art. 6º, §5º e §6º). A ANPD **pode** solicitar, a
qualquer tempo, o ROPA, o **RIPD** e o relatório de tratamento do incidente (art. 8º) — ou seja, o
RIPD (documento 08) e o ROPA (documento 03) precisam estar prontos **antes** do incidente.

---

## 5. Fluxo em 6 fases, com prazos

### Fase 1 — Detecção e registro inicial
**Prazo: imediato ao conhecimento; escalonamento em até 1 hora.**

- Qualquer pessoa que suspeite de incidente **registra e escala** — não investiga sozinha nem "espera
  confirmar".
- Registrar **data e hora do conhecimento** (marco legal do prazo): quem soube, quando, como, o que viu.
- Abrir o **registro de incidente** (§7) já no primeiro contato, mesmo incompleto.
- Encarregado e Coordenador são acionados simultaneamente.
- **Preservar evidências antes de qualquer ação destrutiva** (Fase 2 pode apagar rastro).

### Fase 2 — Contenção
**Prazo: até 4 horas da ciência (medida imediata); contenção completa em até 24 horas.**

| Cenário | Contenção imediata |
|---|---|
| I1 — aparelho perdido/roubado | Orientar o profissional a **revogar o acesso**, trocar credenciais e, se houver, apagar remotamente; corrigir o *fail-open* (**P0.7**) e limpar a chave da memória (**P0.9**) |
| I2 — PDF vazado | Identificar o destino do compartilhamento; solicitar exclusão formal; **não** é possível recolher — avaliar comunicação ao titular |
| I3 — admin comprometido | Invalidar o cookie/sessão, trocar a senha da conta admin, revisar `role`, revisar log de acesso ao `/admin` |
| I4 — segredo do webhook | **Rotacionar o token imediatamente**, mover para header (**P1.13**) e expurgar o log |
| I5 — fallback perdendo dados | **Desligar `ALLOW_SQLITE_FALLBACK`** em produção (**P1.12**), corrigir `/health`, congelar escritas até reconciliar |
| I6 — token de anamnese | Revogar/expirar o link (**P1.11**), remover o nome da página pública |
| I7 — áudio em claro | Cifrar/eliminar arquivos órfãos, implementar varredura no boot (**P0.8**) |
| I8 — conteúdo clínico em log | Expurgar o log, corrigir o `log.error` (**P2.8**) |
| I9 — dados órfãos | Fixar `APP_USER_ID` (**P1.12**) e reatribuir os registros órfãos |
| I10 — cópia local em claro | Eliminar o arquivo e definir descarte (**P0.11**) |

**Regra:** conter **primeiro impedindo a continuidade**, depois investigar. Nunca apagar evidência para
"limpar" o ambiente: copiar para local controlado antes.

### Fase 3 — Avaliação de risco
**Prazo: até 24 horas da ciência (diagnóstico preliminar); até 48 horas (decisão de comunicar).**

Responder, por escrito, com o critério da §4.2:

1. Que dados foram afetados (categoria, sensibilidade, volume)?
2. Quantos titulares — e há **crianças ou adolescentes**? (art. 6º, §2º, II)
3. O dado é **sensível** ou protegido por **sigilo profissional**?
4. Houve **acesso efetivo** ou apenas exposição potencial?
5. Que **riscos concretos** decorrem para o titular?
6. Que medidas já foram adotadas (antes e depois)?
7. É possível identificar todos os titulares para comunicação individual?

**Produto desta fase:** **parecer de risco** com a decisão (comunicar / não comunicar) e a
**fundamentação**. Se "não comunicar", o fundamento é obrigatório e vai ao registro (§7, campo VIII).

### Fase 4 — Comunicação
**Prazo: até 3 dias úteis do conhecimento (ANPD e titular); aviso ao psicólogo controlador em até 24 horas.**

- **ANPD:** protocolo no **SEI!ANPD** pelo encarregado, com os 12 itens do art. 6º, §2º e os documentos
  comprobatórios.
- **Titular:** comunicação direta e individualizada quando possível (art. 9º, §§1º e 2º); se inviável,
  divulgação ampla por no mínimo 3 meses (art. 9º, §3º).
- **Psicólogo controlador:** aviso por escrito em até **24 horas** — ver modelo §6.3 e cláusula 8 do
  DPA (documento 04).
- **Declaração à ANPD de que os titulares foram comunicados:** em até 3 dias úteis do fim do prazo
  (art. 9º, §4º).
- **Complementação:** até 20 dias úteis (art. 6º, §3º).
- Manter cópia de tudo (o que foi enviado, quando, por qual canal).
- Pedir **sigilo** de informações protegidas por lei, de forma fundamentada (art. 7º), quando aplicável.

### Fase 5 — Remediação
**Prazo: 7 dias (correção imediata) · 30 dias (correção estrutural).**

- Corrigir a **causa raiz**, não só o sintoma. Cada cenário da §2 tem um item do plano de ação
  associado — fechar o item é parte da remediação, não trabalho separado.
- Revisar controles correlatos: o mesmo defeito costuma existir em outros pontos (ex.: outros segredos
  em URL, outros campos sem cifra).
- Verificar se a correção foi efetiva (teste que **prova** o comportamento novo — os critérios de
  pronto do documento 02 já estão redigidos nesse formato).
- Atualizar o RIPD (documento 08) e o ROPA (documento 03) se o incidente revelou risco novo.

### Fase 6 — Lições aprendidas
**Prazo: 15 dias após o encerramento.**

- Reunião de *post-mortem* **sem culpados** (*blameless*): o objetivo é o processo, não a pessoa.
- Registrar: o que funcionou, o que falhou, o que faltou no plano, tempo real de cada fase.
- **Atualizar este plano** com o que se aprendeu — plano que não muda depois de um incidente está
  desatualizado.
- **Atualizar o RIPD** e, se o incidente expôs risco relevante não mapeado, o ROPA.
- Verificar se o **registro de incidentes** ficou completo (§7).
- Se o incidente decorreu de falha de subprocessador, acionar as cláusulas contratuais (documento 09,
  §7) e reavaliar o fornecedor.

### 5.1 Quadro-resumo de prazos

| Fase | Prazo interno | Prazo regulatório |
|---|---|---|
| Detecção e escalonamento | 1 hora | — |
| Contenção | 4 h (imediata) / 24 h (completa) | — |
| Avaliação de risco | 24 h / 48 h (decisão) | — |
| **Comunicação à ANPD** | **48 h** | **3 dias úteis** (art. 6º) |
| **Comunicação ao titular** | **48 h** | **3 dias úteis** (art. 9º) |
| Aviso ao psicólogo controlador | **24 h** | contratual (DPA, cláusula 8) |
| Declaração de comunicação ao titular | — | 3 dias úteis do fim do prazo (art. 9º, §4º) |
| Complementação à ANPD | — | 20 dias úteis (art. 6º, §3º) |
| Remediação | 7 / 30 dias | — |
| Lições aprendidas | 15 dias | — |
| Guarda do registro | — | **mínimo 5 anos** (art. 10) |

---

## 6. Modelos de comunicado

> Modelos de trabalho. ⚖️ **Devem ser revisados pelo advogado antes do primeiro uso real** — e o
> conteúdo precisa ser preenchido com os fatos, não com generalidades. Campos `[...]` a completar.

### 6.1 Modelo — Comunicação à ANPD

```
ASSUNTO: Comunicação de Incidente de Segurança com Dados Pessoais — LGPD, art. 48
         Resolução CD/ANPD nº 15/2024

CONTROLADOR
Razão social: [RAZÃO SOCIAL]
CNPJ: [CNPJ]
Endereço: [ENDEREÇO]
Representante legal / Encarregado: [NOME], [CPF], [CARGO]
Vínculo comprobatório: [documento anexo]
Contato: [e-mail] · [telefone]

OPERADOR ENVOLVIDO (quando aplicável)
[NOME/RAZÃO SOCIAL DO OPERADOR — ex.: MentAll PRO / subprocessador]

1. DESCRIÇÃO DO INCIDENTE E CAUSA PRINCIPAL (art. 6º, §2º, XI)
[Descrever o evento de forma objetiva: o que aconteceu, como foi descoberto,
qual a causa técnica identificada — ex.: token de webhook gravado em query
string e persistido em log de aplicação sem expurgo.]

2. DATA DA OCORRÊNCIA E DATA DO CONHECIMENTO (art. 6º, §2º, VII)
Ocorrência (ou estimativa, se não determinável): [DD/MM/AAAA]
Conhecimento pelo controlador: [DD/MM/AAAA HH:MM]

3. NATUREZA E CATEGORIA DOS DADOS AFETADOS (art. 6º, §2º, I)
[ ] Dados pessoais sensíveis — dados de saúde / prontuário psicológico
[ ] Dados de crianças e adolescentes
[ ] Dados de autenticação em sistemas (tokens, credenciais)
[ ] Dados protegidos por sigilo profissional
[ ] Dados financeiros
[ ] Outros: [especificar]
Descrição: [detalhar os campos afetados]

4. NÚMERO DE TITULARES AFETADOS (art. 6º, §2º, II)
Total: [N]
Crianças/adolescentes: [N] · Idosos: [N]
Total de titulares nas atividades afetadas: [N]

5. RISCOS E POSSÍVEIS IMPACTOS (art. 6º, §2º, IV)
[Demonstrar o risco concreto: acesso não autorizado, discriminação, dano à
reputação, quebra de sigilo profissional, dano moral, uso indevido de dados
clínicos. Não usar fórmula genérica.]

6. MEDIDAS TÉCNICAS E DE SEGURANÇA ADOTADAS ANTES E APÓS (art. 6º, §2º, III)
Antes: [ex.: cifra AES-GCM no dispositivo, controle de acesso, auditoria local]
Depois: [ex.: contenção aplicada, rotação de credenciais, correção da causa]

7. MEDIDAS PARA REVERTER OU MITIGAR OS EFEITOS (art. 6º, §2º, VI)
[Descrever as ações e o cronograma]

8. MOTIVOS DA DEMORA (art. 6º, §2º, V)
[Se aplicável; se a comunicação ocorreu no prazo, declarar "não aplicável —
comunicação realizada no prazo do art. 6º".]

9. IDENTIFICAÇÃO DO CONTROLADOR E DO ENCARREGADO (art. 6º, §2º, VIII e IX)
[Preencher]

10. PEDIDO DE SIGILO (art. 7º) — quando aplicável
[Indicar, de forma fundamentada, os documentos ou informações cujo acesso
deve ser restrito e o motivo (segredo comercial ou industrial).]

11. ANEXOS
[Evidências, parecer de risco, relatório de tratamento do incidente, ROPA e
RIPD quando solicitados (art. 8º)]

Local, [DD/MM/AAAA].
[NOME] — Encarregado(a) pela Proteção de Dados Pessoais
```

### 6.2 Modelo — Comunicação ao titular

```
ASSUNTO: Aviso importante sobre a segurança dos seus dados

Olá, [NOME].

Escrevemos porque identificamos uma falha de segurança que pode ter afetado
dados que você nos confiou. Explicamos abaixo, em linguagem simples, o que
aconteceu e o que você pode fazer.

1. O QUE ACONTECEU (art. 9º, I)
[Uma ou duas frases claras. Sem jargão técnico.]

2. QUAIS DADOS PODEM TER SIDO AFETADOS (art. 9º, I)
[Listar com precisão: ex.: nome, telefone, informações do seu acompanhamento.]

3. QUANDO SOUBEMOS (art. 9º, VI)
[DD/MM/AAAA]

4. QUE RISCOS ISSO PODE TRAZER PARA VOCÊ (art. 9º, III)
[Explicar de forma honesta e sem alarmismo.]

5. O QUE JÁ FIZEMOS E O QUE VAMOS FAZER (art. 9º, II e V)
[Medidas técnicas de proteção adotadas e correções em andamento.]

6. O QUE VOCÊ PODE FAZER (boa prática — art. 9º, §5º)
[Recomendações práticas e específicas.]

7. COMO FALAR CONOSCO
Encarregado(a) de Proteção de Dados: [NOME]
E-mail: [E-MAIL] · Telefone: [TELEFONE]
Canal do titular: [LINK/FORMULÁRIO]
Você também pode procurar a ANPD: https://www.gov.br/anpd

Atenciosamente,
[NOME] — [CARGO]
```

**Nota sobre o sigilo clínico:** o aviso ao titular **não** deve revelar informação clínica a terceiros.
Se o aviso for enviado a um telefone ou e-mail que não é do titular (por exemplo, de um responsável ou
familiar), ⚖️ **validar com o advogado** o conteúdo e o canal antes do envio — a própria comunicação de
incidente pode gerar quebra de sigilo profissional.

### 6.3 Modelo — Aviso ao psicólogo controlador

```
ASSUNTO: [URGENTE] Comunicação de incidente de segurança que pode afetar
         dados de pessoas atendidas — ação necessária

Prezado(a) Dr(a). [NOME], CRP [NÚMERO]:

1. O QUE ACONTECEU
[Descrição objetiva do incidente, sem dados clínicos no corpo do e-mail.]

2. QUANDO
Ocorrência: [DD/MM/AAAA] · Nosso conhecimento: [DD/MM/AAAA HH:MM]

3. DADOS E TITULARES POTENCIALMENTE AFETADOS
[Dado de saúde / identificação / contato. Quantidade. Indicar se há menores.]

4. O QUE JÁ FIZEMOS
[Contenção, correção, rotação de credenciais.]

5. O QUE PRECISAMOS DE VOCÊ
[ ] Confirmar se os titulares listados são seus pacientes (lista em anexo
    protegido/criptografado)
[ ] Comunicar os titulares afetados, se aplicável — prazo: 3 dias úteis do
    conhecimento (Res. CD/ANPD nº 15/2024, art. 9º). Enviamos modelo pronto.
[ ] Confirmar as orientações a serem dadas aos titulares
[ ] Informar se houve outra via de exposição de que tenhamos conhecimento

6. NOSSA RESPONSABILIDADE COMO OPERADOR
Comunicamos à ANPD em [data], na forma do art. 6º da Res. CD/ANPD nº 15/2024,
e prestaremos todo o apoio documental para o cumprimento do art. 48 da LGPD.
Contatos diretos do encarregado: [e-mail] · [telefone].

[NOME] — Encarregado(a) pela Proteção de Dados Pessoais — MentAll PRO
```

**Prazo deste aviso:** **até 24 horas** da ciência, conforme cláusula 8 do DPA (documento 04).

---

## 7. Registro de incidentes

**Base legal:** Resolução CD/ANPD nº 15/2024, **art. 10** — o controlador deve manter o registro
**inclusive dos incidentes não comunicados**, pelo prazo mínimo de **5 (cinco) anos** a contar da data
do registro, salvo obrigação adicional que exija prazo maior.

### 7.1 Campos do registro (mínimos exigidos pelo art. 10, §1º, mais campos de gestão)

| # | Campo | Obrigatório? | Observação |
|---|---|---|---|
| 1 | **ID do incidente** | gestão | Sequencial: `INC-AAAA-NNN` |
| 2 | **Data de conhecimento do incidente** | **art. 10, §1º, I** | Marco inicial do prazo legal |
| 3 | **Data/hora da ocorrência** | gestão | Se não determinável, registrar "estimada" |
| 4 | **Quem detectou e por qual canal** | gestão | Suporte, log, usuário, auditoria |
| 5 | **Descrição geral das circunstâncias** | **art. 10, §1º, II** | Inclui **causa principal** (art. 6º, §2º, XI) |
| 6 | **Natureza e categoria dos dados afetados** | **art. 10, §1º, III** | Sensível? De menor? De autenticação? |
| 7 | **Número de titulares afetados** | **art. 10, §1º, IV** | Discriminar crianças/adolescentes/idosos |
| 8 | **Avaliação de risco e possíveis danos** | **art. 10, §1º, V** | O parecer da Fase 3 |
| 9 | **Medidas de correção e mitigação** | **art. 10, §1º, VI** | O que foi feito e quando |
| 10 | **Forma e conteúdo da comunicação** | **art. 10, §1º, VII** | Se houve comunicação à ANPD e ao titular: data, protocolo, texto |
| 11 | **Motivos da ausência de comunicação** | **art. 10, §1º, VIII** | **Obrigatório** quando não se comunicou |
| 12 | **Cenário de origem** | gestão | Referência à §2 (I1 a I10) |
| 13 | **Sistemas e subprocessadores envolvidos** | gestão | Alimenta o documento 09 |
| 14 | **Item do plano de ação associado** | gestão | P0/P1/P2 que fecha a causa raiz |
| 15 | **Encarregado responsável pelo registro** | gestão | Nome e data |
| 16 | **Data de encerramento e lições aprendidas** | gestão | Fase 6 |
| 17 | **Prazo de guarda** | gestão | `data do registro + 5 anos` no mínimo |

### 7.2 Formato

Manter em **planilha controlada** com acesso restrito ao encarregado, ao coordenador e ao jurídico. O
registro contém dado pessoal sensível (descrição de incidente) — **não** manter em pasta compartilhada
aberta. Backup do registro segue a mesma política de cifra e acesso.

### 7.3 Registro retroativo obrigatório

Abrir registro para os dois casos **já ocorridos** identificados na §2.1:

| ID | Cenário | Situação |
|---|---|---|
| `INC-2026-001` | Exposição do token do webhook do WhatsApp em log (`wuzapi_admin.py:47-49`; 130.603 ocorrências) | **Aberto** — avaliar comunicação retroativa ⚖️; rotacionar token (P1.13) |
| `INC-2026-002` | Cópia local em texto claro com dados reais (`backend/data/mentall.db`) | **Aberto** — avaliar comunicação retroativa ⚖️; eliminar arquivo (P0.11) |

---

## 8. Contatos e escalonamento

### 8.1 Matriz de escalonamento

| Nível | Quem | Quando | Canal |
|---|---|---|---|
| **N1** | Suporte / primeira linha | Qualquer suspeita | Registrar e escalar em **até 1 hora** |
| **N2** | Encarregado (DPO) + Responsável técnico | Confirmado o incidente | Acionamento **simultâneo**; abrir registro |
| **N3** | Coordenador de incidente (dono do produto) | Em até **4 horas** | Decide contenção e recursos |
| **N4** | Jurídico / privacidade ⚖️ | Em até **24 horas** | Decide enquadramento e comunicação |
| **N5** | ANPD (SEI!ANPD) e titulares | **Até 3 dias úteis** | Pelo encarregado |
| **N6** | Psicólogos controladores afetados | **Até 24 horas** | Pelo coordenador/encarregado |

### 8.2 Contatos a preencher (nomes e telefones reais — obrigatório antes de publicar este plano)

| Função | Nome | Telefone/WhatsApp | E-mail | Suplente |
|---|---|---|---|---|
| Encarregado (DPO) | **[A NOMEAR — P1.1]** | | | |
| Coordenador de incidente | [ ] | | | [ ] |
| Responsável técnico (backend) | [ ] | | | [ ] |
| Responsável técnico (cliente) | [ ] | | | [ ] |
| Jurídico / privacidade ⚖️ | [ ] | | | [ ] |
| Comunicação | [ ] | | | [ ] |
| Suporte N1 | [ ] | | | [ ] |

### 8.3 Contatos externos

| Contato | Endereço | Uso |
|---|---|---|
| **ANPD — CTIS/CGIS/SFI** | **incidentes@anpd.gov.br** | Dúvidas sobre o procedimento de comunicação |
| **ANPD — SEI!ANPD** | [peticionamento eletrônico](https://sei.anpd.gov.br/sei/controlador_externo.php?acao=usuario_externo_logar&id_orgao_acesso_externo=0) | **Protocolo oficial** da comunicação |
| **ANPD — canal do titular** | [Denúncia/petição de titular](https://www.gov.br/anpd/pt-br/canais_atendimento/cidadao-titular-de-dados/denuncia-peticao-de-titular-referente-lgpd) | Orientações ao titular |
| **Turso / AWS** | [canal de suporte contratual] | Acesso restrito/transparência de incidentes no banco |
| **Groq / OpenAI / DeepSeek** | [canais de segurança dos provedores] | Incidente originado em provedor de IA |
| **Fly.io** | [canal de suporte contratual] | Incidente de infraestrutura da API |
| **Provedor de hospedagem do wuzapi** | **[A CONFIRMAR]** ⚖️ | Incidente no gateway de WhatsApp |

**Pendência crítica:** enquanto **não houver encarregado nomeado** (P1.1), não existe quem protocole a
comunicação no SEI!ANPD com o vínculo comprobatório exigido pelo art. 6º, §5º. **O plano está
inoperante.** Esta é a primeira pendência a resolver.

---

## 9. Simulado de mesa sugerido

**Objetivo:** testar o plano antes de precisar dele. **Periodicidade:** a cada 12 meses, e após
qualquer incidente relevante (item **P3.3**).

### 9.1 Formato

- **Duração:** 2 horas.
- **Participantes:** encarregado, coordenador, responsável técnico (backend e cliente), jurídico,
  comunicação e **um psicólogo cliente convidado** (ele é o controlador de verdade — o simulado perde
  valor sem ele).
- **Facilitador:** alguém que **não** esteja na cadeia de decisão; conduz os injetores e cronometra.
- **Regra de ouro:** as decisões são **registradas em ata** e valem como o procedimento real — se o
  plano não permitir decidir, o plano é que está errado.
- **Proibido no simulado:** culpar pessoas, "melhorar a resposta depois", pular a fase de avaliação de
  risco por achar o caso óbvio.

### 9.2 Injetores (usar cenários reais da §2 — em ordem crescente de dificuldade)

**Ciclo 1 — 30 min · Injetor: I4 (segredo do webhook)**
"Às 09h14, o time de suporte percebeu que o token do webhook do WhatsApp está impresso em 130 mil
linhas do log de produção. O log é acessível a qualquer pessoa com acesso ao servidor."
→ Perguntas: quem é acionado? em quanto tempo? o token é rotacionado? **o incidente é comunicável?**
com base em qual critério do art. 5º? A resposta esperada pela árvore da §4.3: critério IV
(autenticação) e risco de acesso a dado pessoal → **comunicar**, salvo fundamento escrito.

**Ciclo 2 — 30 min · Injetor: I5 (fallback perdendo dados)**
"Na madrugada, o Turso ficou indisponível por 40 minutos. O backend aceitou 12 contratos e 8 anamneses
no SQLite local, confirmou sucesso ao usuário e reiniciou. Os dados não existem mais."
→ Perguntas: é incidente de dados pessoais? qual propriedade foi violada? quem são os titulares? como
identificá-los se o dado se perdeu? **é comunicável?** como responder ao titular que pede acesso a um
dado que foi perdido (art. 18, II)?

**Ciclo 3 — 30 min · Injetor: I1 (aparelho perdido)**
"Um psicólogo relatou o roubo do celular com o prontuário de 46 pessoas atendidas, 9 delas menores de
idade. O aparelho estava protegido por PIN, mas o app já estava desbloqueado quando foi levado."
→ Perguntas: como identificar os titulares sem o aparelho? **quem comunica o titular — o MentAll ou o
psicólogo?** como comunicar **crianças e adolescentes** sem violar o sigilo clínico? quem paga a
comunicação? qual o papel do termo de consentimento (documento 07) nesse momento?

**Ciclo 4 — 20 min · Injetor: I6 + I2 combinados**
"Um link de anamnese foi encaminhado por engano para um grupo de WhatsApp. A página mostra o nome da
pessoa atendida e o link não expira. No mesmo dia, um PDF de prontuário foi enviado para o e-mail
pessoal errado."
→ Perguntas: dois incidentes ou um? o link pode ser revogado hoje? quanto tempo leva a correção? o PDF
tem como ser rastreado? **o que se comunica ao titular sobre um dado que já saiu do controle?**

**Ciclo 5 — 10 min · Decisão difícil**
"Um incidente envolveu dados de 3 pessoas atendidas. O jurídico avalia que o risco é relevante; o
produto argumenta que comunicar gera dano reputacional desproporcional."
→ Testar a regra da §4.2 (**na dúvida, comunique**) e a autonomia do encarregado.

### 9.3 Critérios de avaliação do simulado

| Critério | Meta |
|---|---|
| Tempo até o acionamento do encarregado | ≤ 1 hora |
| Registro aberto na Fase 1 | 100% dos injetores |
| Parecer de risco escrito | 100% dos injetores |
| Decisão de comunicar fundamentada | 100% |
| Modelo de comunicação preenchido com fatos | ≥ 1 por ciclo |
| Aviso ao psicólogo controlador redigido | 100% |
| Itens do plano de ação identificados como remediação | ≥ 1 por injetor |
| Ata registrada e plano atualizado | ao final |

### 9.4 Produto do simulado

Ata com: injetores usados, decisões tomadas, **tempo real de cada fase**, lacunas encontradas, itens
do plano atribuídos a responsáveis com prazo, e a **versão atualizada deste plano**. Sem a versão
atualizada, o simulado não cumpriu sua função.

---

## Anexo — Checklist das primeiras 2 horas

> Imprimir e manter acessível. Nas primeiras 2 horas, ninguém tem tempo de ler um plano inteiro.

### 0 a 15 minutos — Reconhecer e escalar

- [ ] **Registrar data e hora do conhecimento** (marco legal do prazo de 3 dias úteis)
- [ ] Registrar quem detectou, como e o que viu (print, log, relato)
- [ ] **Acionar o encarregado e o coordenador de incidente simultaneamente**
- [ ] Abrir o **registro de incidente** (§7) mesmo incompleto
- [ ] **Não investigar sozinho** e **não apagar nada** — preservar evidência primeiro
- [ ] Atribuir um ID (`INC-AAAA-NNN`)
- [ ] Se o vazamento estiver **em curso**, começar pela contenção imediata abaixo antes de qualquer análise

### 15 a 60 minutos — Conter e preservar

- [ ] **Copiar as evidências** para local controlado (log, prints, arquivos) **antes** de qualquer limpeza
- [ ] Aplicar a contenção do cenário correspondente (§5, Fase 2):
  - [ ] I1 aparelho perdido → orientar revogação/troca de credencial e apagamento remoto
  - [ ] I2 PDF vazado → identificar destino e solicitar exclusão formal
  - [ ] I3 admin comprometido → invalidar sessão, trocar senha, revisar `role`
  - [ ] I4 segredo de webhook → **rotacionar o token imediatamente**
  - [ ] I5 fallback → **desligar `ALLOW_SQLITE_FALLBACK`** e reconciliar
  - [ ] I6 token de anamnese → revogar/expirar o link
  - [ ] I7 áudio em claro → cifrar/eliminar órfãos
  - [ ] I8 log com conteúdo clínico → expurgar e corrigir o código
  - [ ] I9 dados órfãos → fixar `APP_USER_ID`
  - [ ] I10 cópia local em claro → eliminar e definir descarte
- [ ] Verificar se a exposição **continua ativa** (novo acesso, novo envio)
- [ ] Registrar **horário de cada ação** (vai para o parecer e para a comunicação)

### 60 a 90 minutos — Dimensionar

- [ ] Que **dados** foram afetados? São **sensíveis**? Há dados de **crianças/adolescentes**?
- [ ] **Quantos titulares**? Há como identificá-los individualmente?
- [ ] Houve **acesso efetivo** ou apenas exposição potencial?
- [ ] Quais **subprocessadores** estão envolvidos (Turso, Groq, OpenAI, DeepSeek, wuzapi)?
- [ ] O incidente cruza **fronteira** (país sem decisão de adequação)? → aciona o documento 09
- [ ] Avaliar com os critérios do **art. 5º da Res. CD/ANPD nº 15/2024** (sensível, menor, financeiro,
      autenticação, sigilo, larga escala)

### 90 a 120 minutos — Decidir e preparar

- [ ] Acionar o **jurídico/privacidade** com o resumo fático (sem dado clínico no corpo do e-mail)
- [ ] **Decisão preliminar de comunicar ou não** — na dúvida, **comunicar**
- [ ] Se decidir comunicar, é **o encarregado** quem protocola no **SEI!ANPD** (com vínculo comprobatório)
- [ ] Iniciar o rascunho com os **12 itens do art. 6º, §2º** (ANPD) e os **7 do art. 9º** (titular)
- [ ] **Agendar o aviso ao psicólogo controlador em até 24 horas** (modelo §6.3)
- [ ] Confirmar quem é o **controlador** do dado atingido (psicólogo ou MentAll) e quem comunica o titular
- [ ] Definir responsável por cada ação de remediação (mapear ao item P0/P1/P2 do documento 02)

### Lembretes que costumam ser esquecidos

- [ ] **Não são 72 horas: são 3 dias úteis** — e o prazo já começou no conhecimento
- [ ] **Informação incompleta não adia o prazo** — comunique o que se sabe e complemente em até 20 dias úteis
- [ ] A comunicação à ANPD **não substitui** a comunicação ao titular (a ANPD é explícita nisso)
- [ ] **Guarde o registro por no mínimo 5 anos**, inclusive se não comunicar
- [ ] **Anote os motivos da demora** se o prazo for perdido — é campo obrigatório
- [ ] Ao comunicar o titular, **cuidado com o sigilo clínico**: o aviso não pode revelar informação
      clínica a terceiros (⚖️ validar canal e texto)
- [ ] A ANPD pode pedir o **ROPA e o RIPD** durante o processo — mantenha-os prontos

---

## Pendências de validação jurídica

1. ⚖️ **Enquadramento como agente de pequeno porte:** confirmar se o MentAll PRO se qualifica para os
   **prazos em dobro** (Res. CD/ANPD nº 2/2022 e art. 6º, §8º e art. 9º, §6º da Res. 15/2024).
   **NÃO CONFIRMADO — validar com advogado. Não presuma o benefício.**
2. ⚖️ **Repartição de responsabilidade na comunicação:** definir, no DPA (documento 04, cláusula 8),
   quem protocola a comunicação à ANPD e quem comunica o titular quando o dado clínico é do psicólogo
   e a infraestrutura é do MentAll. A obrigação do art. 48 é do controlador — e há **dois
   controladores** em cena.
3. ⚖️ **Incidentes retroativos `INC-2026-001` e `INC-2026-002`:** decidir se exigem comunicação ao
   abrigo do art. 48 e registrar o fundamento. **Não deixar como "não incidente" sem análise escrita.**
4. ⚖️ **Conteúdo do aviso ao titular e sigilo profissional:** validar canal, forma e texto para não
   configurar quebra de sigilo clínico na própria comunicação do incidente.
5. ⚖️ **Critério de risco relevante aplicado ao produto:** obter do advogado uma orientação escrita
   sobre como aplicar o art. 5º da Res. 15/2024 aos cenários I1 a I10, com exemplos — para que a
   decisão em tempo real seja rápida e defensável.
6. ⚖️ **Comunicação a titulares não identificáveis:** validar o procedimento do art. 9º, §3º
   (divulgação ampla por no mínimo 3 meses) para o caso I5, em que o dado se perdeu e a lista de
   titulares pode não existir.
7. ⚖️ **Exigência de encarregado para protocolar:** confirmar o documento comprobatório de vínculo
   aceito pela ANPD (art. 6º, §5º) e providenciar a representação antes do primeiro incidente.
8. ⚖️ **Prazo contratual de aviso ao psicólogo (24 h):** confirmar compatibilidade com o DPA e com
   eventuais contratos de subprocessadores (documento 09, §7, cláusula 6).
9. ⚖️ **Guarda do registro por 5 anos:** confirmar se há prazo maior aplicável por obrigação legal ou
   regulatória específica do setor de saúde.
10. ⚖️ **Revisão jurídica integral deste plano** antes do primeiro uso real e antes de publicá-lo em
    qualquer material ao cliente.
