# Comparativo de funcionalidades de concorrentes — MentAll PRO

**Versão:** 1.2 · **Data:** 20/10/2026 · **Próxima revisão:** 20/04/2027 ou a cada nova função/navegador
**Natureza:** pesquisa de **produto**. **Não é** parecer jurídico nem auditoria de terceiros. As fontes
são **públicas** — com **uma exceção autorizada** (conta trial do PsicoManager, §2).
**Ferramentas:** [REA](https://github.com/morluto/rea) (`rea-agents`, MIT) — engenharia reversa local
via CDP/CLI — e [RES/saas-reverse](https://github.com/veyralabsgroup/saas-reverse) (MIT) — OSINT
público + síntese de produto. São **complementares**: o REA prova o **cliente/runtime**; o RES dá o
**produto/negócio** (e suas saídas são hipóteses, não evidência). Comparação em `02_metodo_rea.md` §8.

## 1. Objetivo

Entender **como os concorrentes implementam** três funções, para reduzir as nossas desvantagens e
decidir o que construir:

1. **Financeiro / cobrança** (como acoplam; quais fornecedores).
2. **Mensagens profissional → paciente** (canal; oficial × não oficial; portal).
3. **Teleconsulta** (SDK de vídeo; sala; custo).

O `08` (PsicoManager) acrescenta uma camada pedida pelo dono em 20/10/2026: **documentos do paciente**
(tipos, modelos, assinatura, app) e **LGPD documental** (termos, política, retenção, direitos).

## 2. Escopo e limites (seguro por padrão)

- **Só fontes/artefatos públicos**: páginas de marketing, políticas, FAQs, docs — e, quando houver,
  **demo público**. **Sem login**, **sem capturar área autenticada**, **sem descompilar APK** (isso
  fica para depois de aval jurídico).
- **Exceção autorizada (19/10/2026):** conta **trial do PsicoManager**, criada e usada pelo próprio
  dono, com **dados sintéticos**, **captura passiva** da própria sessão e **sem automação em escala**.
  APK continua fora do escopo (aval jurídico).
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
- **RES/saas-reverse** (público): scraper + coleta de reviews/HN/Reddit/vagas para montar o
  **blueprint de produto**. Saídas são **hipóteses** e precisam ser cruzadas com o REA; o scraper
  **não renderiza SPA** (ver limitações em `02_metodo_rea.md` §8).

## 4. Índice

| # | Arquivo | Conteúdo |
|---|---|---|
| 00 | `00_LEIA-ME.md` | Este guia e escopo |
| 01 | `01_copilloto.md` | Copilloto — financeiro, mensagens e teleconsulta |
| 02 | `02_metodo_rea.md` | Como o REA foi instalado/rodado e como reproduzir |
| 03 | `03_psiluz.md` | PsiLuz |
| 04 | `04_psicopront.md` | PsicoPront |
| 05 | `05_prontuscare.md` | ProntusCare |
| 06 | `06_zenklub.md` | Zenklub |
| 07 | `07_sintese.md` | Síntese das 3 funções × concorrentes + gaps do MentAll |
| 08 | `08_psicomanager.md` | PsicoManager — financeiro/PsicoBank, mensagens, LiveKit, **documentos do paciente e LGPD** |

> **Regra de ouro:** cada afirmação traz a **evidência** (URL pública ou observação do REA). O que
> não pôde ser verificado fica marcado como **não observado**, nunca como fato.
