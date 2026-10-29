# Layout do projeto — original + backup

Este diretório (`/Users/rodrigolemos/mentall-pro-app`) é agora o **projeto original** do MentAll PRO,
com a linha visual v2.0.x e o backend mesclado (custos Magalu/IA por profissional).

## Origem

Em 28/10/2026 os dois diretórios foram trocados de lugar:
- **Original (aqui):** era a "cópia de trabalho" em
  `~/Documents/deepseek-harness/default-workspace/mentall-pro-app-copia`; foi promovida a original.
- **Backup (histórico):** o antigo original (com `build/`, APKs e histórico de releases) agora está em
  `~/Documents/deepseek-harness/default-workspace/mentall-pro-app-copia`.

## Git / remotos

| Nome | URL | Uso |
|------|-----|-----|
| `origin` | https://github.com/rodrigolemospsi/mentall-api.git | remoto oficial (push/PR) |
| `backup` | ~/Documents/.../mentall-pro-app-copia | antigo original, para consulta/comparação |

- Branch `master` está **20 commits à frente** do GitHub (commits locais da linha visual 2.0.x).
- Antes do swap os 2 commits de custos do antigo original (`8b9edad`, `e84ac60`) foram integrados por
  merge (conflito só no `AGENTS.md`, resolvido mantendo os dois lados).

## O que veio junto (não versionado)

- `backend/.env` (chmod 600) — mesmas chaves de produção
- `backend/data/mentall.db` — snapshot do banco local (0 usuários)
- `backend/.venv/` — ambiente Python 3.12 com as dependências
- `build/`, `.dart_tool/`, APKs `MentAllPRO-v2.0.4-*` — artefatos gerados

## Serviços

- **Backend local:** launchd `com.mentall.backend` aponta para
  `/Users/rodrigolemos/mentall-pro-app/backend/start_backend.sh` (porta 8000). Reiniciado após o swap;
  `GET /health` → `{"status":"ok","versao":"1.0.0","debug_info":{"database":"sqlite_local"}}`.
- **Wuzapi:** inalterado (`~/wuzapi`).

## Observação sobre o agente (DSH)

O projeto original agora fica **fora do workspace do DSH**; edições feitas pelo agente nesse caminho
exigem aprovação de sandbox por operação.
