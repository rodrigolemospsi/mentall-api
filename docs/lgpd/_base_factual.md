# Base factual verificada — MentAll PRO × LGPD

> **LEIA TAMBÉM (consolidação mais recente e completa):** `01_diagnostico_lgpd.md` — seções **4.13**
> (auditoria do backend), **4.14** (auditoria do cliente Flutter) e **6** (referências normativas
> verificadas em fonte oficial). Este arquivo é o registro das verificações de primeira mão do
> analista principal; o diagnóstico incorpora também as auditorias independentes.

> Documento de trabalho interno. Cada afirmação abaixo foi verificada diretamente no
> código ou na configuração do repositório, com indicação de `arquivo:linha`.
> Nada aqui é opinião jurídica: é o substrato de fato para o diagnóstico e para as políticas.
> Verificado em **09/10/2026**.

## 1. Identificação do produto

| Item | Valor | Fonte |
|---|---|---|
| Produto | MentAll PRO — prontuário clínico psicológico com IA | `site-referencia.txt` |
| Público | psicólogos(as) clínicos(as) com CRP ativo no Brasil | `site-referencia.txt` |
| Cliente móvel | Flutter (Android/iOS), offline-first | `lib/`, `pubspec.yaml` |
| Backend | FastAPI (Python 3.12) | `backend/main.py`, `render.yaml` |
| Versão em análise | APK `1.0.49` | `MentAllPRO-v1.0.49.apk` |
| Deploy backend | Fly.io, `primary_region = "gru"` (São Paulo) | `fly.toml:2-3` |
| Banco | libSQL/Turso (`libsql.connect`) com fallback SQLite local | `backend/services/db.py:37-38`, `:58-107` |

## 2. Papéis (LGPD art. 5º, VI e VII)

- O próprio app declara: **"O profissional é o controlador dos dados clínicos. O MentAll PRO
  atua como operador tecnológico."** — `lib/screens/lgpd/politica_privacidade_page.dart:76-77`.
- Enquadramento adotado nos documentos: **psicólogo = controlador**; **MentAll PRO = operador**
  quanto ao prontuário; **controlador** quanto aos dados de conta do profissional e telemetria
  do dispositivo (`backend/services/telemetria.py:1-8` declara que só sobem números).

## 3. Dados tratados

Política atual em tela (`politica_privacidade_page.dart:30-49`) declara:

- **Do profissional**: nome, registro profissional, abordagem clínica, preferências de termo.
- **Da pessoa atendida**: nome, data de nascimento, contato, e-mail, observações.
- **Clínicos**: relatos de sessão, **áudio do relato pós-sessão**, transcrições, **sínteses
  geradas por IA**, apontamentos clínicos.
- **Técnicos**: status de processamento, erros técnicos, datas.

Classificação LGPD: dados da pessoa atendida = **dados pessoais**; relato, áudio, transcrição,
síntese e apontamentos = **dados pessoais sensíveis de saúde (art. 11)**.

## 4. Fluxos que saem do aparelho (transferência a terceiros)

### 4.1 Transcrição de áudio

- Provedor default: **Groq** (`TRANSCRICAO_PROVIDER=groq` em `backend/.env`), modelo
  `whisper-large-v3-turbo` — `backend/services/transcricao.py:13-20`, `:64-65`, `:85-88`.
- Alternativa: **OpenAI** (`gpt-4o-mini-transcribe`) — `transcricao.py:17-20`, `:96-99`.
- Envia: **o áudio do relato clínico** em base64 (dado sensível) para servidor nos EUA.

### 4.2 Síntese clínica

- O prompt inclui **o nome da pessoa atendida** e o **material clínico integral**:
  `_montar_prompt_sintese(..., nome_pessoa_atendida=...)` — `backend/services/ia_clinica.py:438-454`;
  chamada com dado real do request em `backend/main.py:890-893`.
- Provedores implementados: **OpenAI** (`ia_clinica.py:627-632`), **DeepSeek**
  (`https://api.deepseek.com/v1/chat/completions`, `:635-690`, endpoint literal na `:648`) e
  **Gemini** (`:594-625`).
- **Não há** configuração de retenção zero nem `store: false` em nenhum payload — verificado nos
  três blocos acima. O payload DeepSeek envia `messages` com o prompt clínico completo
  (`ia_clinica.py:656-668`).
- `.env` de desenvolvimento tem `IA_MODEL_PROVIDER=gemini` com `IA_MODEL=gpt-4.1`
  (combinação incoerente) — `backend/.env`.

### 4.3 Erro de provedor devolvido para log

- Em falha do DeepSeek, o corpo da resposta do provedor é gravado em log:
  `log.error("DeepSeek síntese retornou %d: %s", resp.status_code, resp.text[:500])` —
  `backend/services/ia_clinica.py:673-676`.

### 4.4 Lembretes por WhatsApp

- Integração **wuzapi** (API não oficial do WhatsApp) com `WUZAPI_BASE_URL`, `WUZAPI_TOKEN`,
  `WUZAPI_WEBHOOK_TOKEN` — `backend/.env`, `backend/services/wuzapi_admin.py`,
  `backend/services/lembrete_service.py`.
- Não verificável neste momento: se nome/telefone da pessoa atendida trafegam no corpo do lembrete
  (a confirmar na auditoria do backend).

## 5. Contradições entre o que o app promete e o que foi verificado

| Promessa | Onde | Situação |
|---|---|---|
| "Serviços de IA (OpenAI ou **Google Gemini**)" | `politica_privacidade_page.dart:72-73` | **Omite Groq (transcrição, EUA) e DeepSeek (China).** Divergência material. |
| "Transcrição automática (via **OpenAI Whisper**)" e "síntese (via **OpenAI GPT-4.1**)" | `termos_uso_page.dart:35-36` | Produção usa **Groq + Gemini**; código também suporta DeepSeek. Divergência material. |
| "não são armazenados pelos provedores de IA para treinamento de modelos (conforme políticas da OpenAI e Google)" | `politica_privacidade_page.dart:105-108` | Afirmação não comprovada para OpenAI/Gemini e **não menciona** Groq/DeepSeek. |
| "Criptografia AES-256 para proteção dos dados em repouso" | `politica_privacidade_page.dart:59` | Escopo (quais campos) não declarado — a confirmar na auditoria do cliente. |
| "Nenhum dado clínico é armazenado em servidores externos sem consentimento explícito do profissional" | `politica_privacidade_page.dart:63-64` | Precisa confronto com o que o backend persiste (Turso). A confirmar. |
| "Retenção: arquivamento em vez de exclusão" | `politica_privacidade_page.dart:82-84` | Colide com o direito de eliminação (art. 18, VI) e exige justificativa de guarda legal. |
| Contato: "entre em contato com o desenvolvedor do MentAll PRO" | `politica_privacidade_page.dart:119-122` | **Sem encarregado (DPO), sem e-mail, sem canal.** Não atende ao art. 41. |
| "Última atualização: Julho de 2026" | `politica_privacidade_page.dart:122`, `termos_uso_page.dart:101` | Documentos desatualizados face ao código atual. |

## 6. Sinais já registrados pelo próprio projeto (auditoria interna)

- `excluirPaciente` — hard delete em cascata **sem chamador de produção** (`AGENTS.md`, seção
  "Achados da auditoria da documentação (06/10/2026)").
- `_registrarAuditoria` **não é `await`ado** → evento de auditoria pode nunca ser gravado
  (`AGENTS.md`, idem).
- **Falta evento de auditoria** para remoção/regravação de áudio (`AGENTS.md`, idem).
- `ALLOW_SQLITE_FALLBACK` com default `"true"` → risco de perda silenciosa de dados
  (`AGENTS.md`, "Achados da auditoria de degradação silenciosa").
- Termo de "5 minutos" de áudio existe na especificação do PDF de arquitetura LGPD, **não na
  tela** (`AGENTS.md`, seção LGPD/Privacidade; `pdf_arquitetura_lgpd_service.dart:219`).

## 7. Artefatos de privacidade que já existem no produto

| Artefato | Caminho | Estado |
|---|---|---|
| Política de Privacidade (tela) | `lib/screens/lgpd/politica_privacidade_page.dart` | Publicável com correções |
| Termos de Uso (tela) | `lib/screens/lgpd/termos_uso_page.dart` | Publicável com correções |
| Tela Privacidade e Segurança | `lib/screens/lgpd/privacidade_seguranca_page.dart` | Existe |
| Trilha de auditoria LGPD | `lib/services/lgpd/auditoria_service.dart`, `lib/models/lgpd/registro_auditoria.dart` | Existe |
| PDF "Arquitetura LGPD" (14 seções) | `lib/services/lgpd/pdf_arquitetura_lgpd_service.dart` | Documento de trabalho, seção 12 admite os que faltam |
| Aviso de privacidade da IA | `lib/widgets/lgpd/aviso_privacidade_ia_card.dart` | Só fala de revisão humana; não menciona envio a terceiros |

O próprio PDF de arquitetura lista como **pendentes** (`pdf_arquitetura_lgpd_service.dart:351-354`):
Política de Privacidade, Termos de Uso e **Acordo de Tratamento de Dados** (este último marcado
como ausente).

## 8. Lacunas já confirmadas (independentes das auditorias)

1. **Acordo de tratamento de dados (DPA/art. 39)** entre MentAll (operador) e o psicólogo
   (controlador) — inexistente.
2. **Encarregado (DPO/art. 41)** — inexistente, sem canal publicado.
3. **Canal do titular (art. 18)** — sem procedimento nem porta de entrada.
4. **Registro das operações (art. 37)** — inexistente.
5. **RIPD (art. 38)** — inexistente, apesar de tratamento de dado sensível + IA + transferência
   internacional (é exatamente o caso de RIPD exigível).
6. **Política de retenção e descarte** — inexistente.
7. **Plano de resposta a incidentes** — inexistente; o prazo regulatório de comunicação é curto
   (a confirmar no dossiê normativo).
8. **Aviso e termo de consentimento do paciente** (titular não usuário do app) — inexistente.
9. **Documentação de transferência internacional** — inexistente.
10. **Data Safety / App Privacy (lojas)** — não produzidos.
