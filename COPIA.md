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

## O que NÃO veio junto (ignorados pelo git)

- `backend/.env` — chaves/segredos da API (não duplicado por segurança)
- `backend/data/` — banco SQLite local (`mentall.db`)
- `backend/.venv/` — ambiente Python (recriar com
  `pip install -r backend/requirements.txt`)
- `build/`, `.dart_tool/`, APKs — artefatos gerados (recriados no build)

## Para rodar esta cópia

1. Criar `.venv` do backend e instalar `backend/requirements.txt`.
2. Copiar/ajustar um `backend/.env` próprio (chaves de teste) — **não** versionar.
3. Usar um banco SQLite separado (`backend/data/`) e **portas diferentes** do
   original (ex.: backend na 8001 e app Flutter apontando para ela).
4. Flutter: `flutter pub get` e build/run normalmente (este diretório é o projeto).

## Fluxo de trabalho

- Editar/commitar somente nesta cópia; o original fica congelado.
- Comparar com o original: `git fetch original && git log --oneline original/master..master`
- Se as mudanças derem certo: `git push origin master` (ou abrir PR no GitHub).
