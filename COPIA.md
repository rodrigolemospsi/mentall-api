# Cópia de trabalho — MentAll PRO (não é o original)

Esta pasta é uma **cópia independente** do app original
(`/Users/rodrigolemos/mentall-pro-app`), criada em 2026-10-28 para fazer mudanças
sem afetar o original. Qualquer commit/edição aqui fica só aqui.

## Base

- Commit inicial da cópia: `8649d4d` (`master`) — mesmo HEAD do original e do GitHub.
- Original permanece intocado (working tree limpo).

## Remotos

| Nome | URL | Uso |
|------|-----|-----|
| `origin` | https://github.com/rodrigolemospsi/mentall-api.git | remoto oficial (push/PR) |
| `original` | /Users/rodrigolemos/mentall-pro-app | referência local; `git fetch original` traz commits feitos no original |

## Configuração local incluída (copiada do original)

- `backend/.env` — copiado do original em 28/10/2026 (`chmod 600`, ignorado pelo
  git). Contém **as mesmas chaves de produção** (OpenAI, Groq, Wuzapi, SMTP,
  Mailu, VAPID...). Não versionar, não compartilhar.
- `backend/data/mentall.db` — snapshot consistente do banco local do original
  (SQLite `.backup`; 21 tabelas com as mesmas contagens). O banco local está
  **vazio de usuários** (0 contas) — não é o banco de produção (Fly).
- `backend/data/mentall.db-wal` / `-shm` são recriados ao rodar.

## O que NÃO veio junto (ignorados/gerados)

- `build/`, `.dart_tool/`, APKs — artefatos gerados (recriados no build)
- `.opencode/`, `auditoria/`, PDFs e APKs do original — não fazem parte do app
- `backend/.venv/` — **já criado nesta cópia** (Python 3.12 + `requirements.txt`).
  Se apagar, recriar com `python3.12 -m venv .venv` +
  `.venv/bin/pip install -r requirements.txt`

## Verificação já feita (28/10/2026)

- Banco copiado com `.backup`: `PRAGMA quick_check` = ok; 21 tabelas com contagens
  idênticas ao original.
- Backend da cópia: `GET /health` → `200 {"status":"ok","versao":"1.0.0",
  "debug_info":{"database":"sqlite_local"}}` em `127.0.0.1:8001` (teste com
  integrações neutralizadas).

## Cuidados ao rodar esta cópia

- O backend do original está rodando na **porta 8000**; rode a cópia em **8001**:
  `cd backend && ./.venv/bin/python -m uvicorn main:app --host 127.0.0.1 --port 8001`
- Ao subir, o backend inicia rotinas de background (lembretes/Wuzapi, alertas de
  e-mail, sync de custos). Com as chaves reais, isso pode gerar **efeitos reais**
  (mensagens de WhatsApp a pacientes, e-mails). Para testar com segurança,
  neutralize no shell — o ambiente tem precedência sobre o `.env`
  (`load_dotenv` não sobrescreve):
  `WUZAPI_TOKEN= SMTP_HOST= EMAIL_ALERTA_WHATSAPP= MAGALU_CONSUMPTION_API_KEY= \
   ./.venv/bin/python -m uvicorn main:app --port 8001`
- O app Flutter aponta por padrão para **produção** (`https://mentall-api.fly.dev`).
  Para testar a cópia, mude a URL do backend nas Configurações do app (box
  `app_config.backend_url` / `ApiClient.setBaseUrl`): no emulador Android use
  `http://10.0.2.2:8001`; no desktop/iOS simulador, `http://127.0.0.1:8001`.
- Flutter: `flutter pub get` e build/run normalmente (este diretório é o projeto).

## Fluxo de trabalho

- Editar/commitar somente nesta cópia; o original fica congelado.
- Comparar com o original: `git fetch original && git log --oneline original/master..master`
- Se as mudanças derem certo: `git push origin master` (ou abrir PR no GitHub).
