# Comparativo de funcionalidades de concorrentes — MentAll PRO

**Versão:** 1.0 · **Data:** 14/10/2026 · **Próxima revisão:** 14/04/2027 ou a cada nova função/navegador
**Natureza:** pesquisa de **produto**. **Não é** parecer jurídico nem auditoria de terceiros. Todas as
fontes são **públicas**.
**Ferramenta:** [REA](https://github.com/morluto/rea) (`rea-agents`, MIT) — engenharia reversa local
via MCP/CLI.

## 1. Objetivo

Entender **como os concorrentes implementam** três funções, para reduzir as nossas desvantagens e
decidir o que construir:

1. **Financeiro / cobrança** (como acoplam; quais fornecedores).
2. **Mensagens profissional → paciente** (canal; oficial × não oficial; portal).
3. **Teleconsulta** (SDK de vídeo; sala; custo).

## 2. Escopo e limites (seguro por padrão)

- **Só fontes/artefatos públicos**: páginas de marketing, políticas, FAQs, docs — e, quando houver,
  **demo público**. **Sem login**, **sem capturar área autenticada**, **sem descompilar APK** (isso
  fica para depois de aval jurídico).
- **Sem copiar código** de concorrente. O objetivo é **entender a lógica** para escrever a nossa.
- **Limite conhecido:** quando a lógica roda **no servidor** (ex.: Next.js API routes), ela **não
  aparece** no JavaScript do cliente. Nesses casos, os fornecedores só se confirmam por **captura de
  rede durante o uso** ou por **análise do APK** — ambos fora do escopo atual.

## 3. Método

- **Fontes públicas** lidas diretamente (evidência: URL).
- **Probe local com REA** (escopo público): subir um Chrome dedicado com
  `--remote-debugging-port`, apontar para a página/demo pública e usar
  `rea analyze-web-bundle` / `rea inspect-web-page` para observar scripts, rotas, endpoints e
  **fingerprints de fornecedor**. Passo a passo em `02_metodo_rea.md`.

## 4. Índice

| # | Arquivo | Conteúdo |
|---|---|---|
| 00 | `00_LEIA-ME.md` | Este guia e escopo |
| 01 | `01_copilloto.md` | Copilloto — financeiro, mensagens e teleconsulta |
| 02 | `02_metodo_rea.md` | Como o REA foi instalado/rodado e como reproduzir |
| — | *(a criar)* | `02_psiluz.md`, `03_psicopront.md`, `04_prontuscare.md`, `05_zenklub.md` |

> **Regra de ouro:** cada afirmação traz a **evidência** (URL pública ou observação do REA). O que
> não pôde ser verificado fica marcado como **não observado**, nunca como fato.
