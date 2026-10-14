# Método e ferramenta (REA)

**Data:** 14/10/2026 · Como o REA foi instalado e como reproduzir a análise.

## 1. O que é o REA

[`morluto/rea`](https://github.com/morluto/rea) (`rea-agents`, MIT, v6.4.0) é um **servidor MCP + CLI**
de engenharia reversa. A análise roda **localmente**. Para **web** ele usa o **Chrome DevTools
Protocol (CDP)**: você sobe um Chrome com porta de depuração e o REA **anexa** (não controla) à aba.

## 2. Instalação (sem Homebrew)

Node 22 LTS via **tarball oficial** em `~/.local` (mesmo padrão de `uv`/`gh` do projeto):

```bash
# 1) baixar e verificar (arm64 mostrado; x64 muda o sufixo)
VER=22.23.3
curl -fLO https://nodejs.org/dist/latest-v22.x/node-v$VER-darwin-arm64.tar.gz
echo "<sha256 do SHASUMS256.txt>  node-v$VER-darwin-arm64.tar.gz" | shasum -a 256 -c -

# 2) extrair para ~/.local e expor no PATH
tar -xzf node-v$VER-darwin-arm64.tar.gz -C ~/.local
for b in node npm npx corepack; do ln -sf ~/.local/node-v$VER-darwin-arm64/bin/$b ~/.local/bin/$b; done

# 3) npm global → ~/.local
npm config set prefix "$HOME/.local"
npm install -g rea-agents
rea --version   # 6.4.0
```

- Instalado: **Node v22.23.3**, **npm 10.9.9**, **rea 6.4.0** em `~/.local/bin`.
- Readiness: `rea doctor` (nós: `node` OK; **Hopper/Ghidra/IDA ausentes** — só necessários para
  binários nativos, **não** para web/JS).

## 3. Registro no opencode (MCP)

`rea setup --client opencode --yes` gravou (com backup) em
`~/.config/opencode/opencode.jsonc`:

```jsonc
{ "mcp": { "rea": { "type": "local", "command": ["/Users/<user>/.local/bin/rea", "mcp"], "enabled": false } } }
```

**`enabled: false` por padrão** — o MCP do REA adiciona ~170 ferramentas ao contexto; habilite só
quando for usar. Validação: `rea mcp doctor` → `healthy: true` (170 ferramentas, 6 prompts).

## 4. Fluxo de análise web (1 concorrente)

```bash
# a) subir um Chrome DEDICADO com porta de depuração (perfil separado; não usar o perfil pessoal)
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless=new --remote-debugging-port=9222 \
  --user-data-dir=/tmp/rea-chrome "https://<alvo>"

# b) descobrir o alvo
rea list-browser-targets http://127.0.0.1:9222

# c) analisar bundle (scripts, rotas, endpoints, fingerprints de fornecedor)
rea analyze-web-bundle http://127.0.0.1:9222 <TARGET_ID> \
  --allowed-origins https://<origem> --observation-ms 12000 --format json > cap.json

# d) inspecionar a página (rede, console, scripts, source maps se houver)
rea inspect-web-page http://127.0.0.1:9222 <TARGET_ID> \
  --observation-ms 12000 --include-json-body-shapes --include-console-text \
  --include-script-sources --json > inspect.json
```

- **Escopo CDP:** endpoint precisa ser **loopback** (`http://127.0.0.1:PORTA` ou socket
  `ws://127.0.0.1:PORTA/devtools/browser/<id>`). O REA **não** sobe/derruba o navegador — **feche o
  Chrome dedicado ao terminar**.
- **Filtro de origem** (`--allowed-origins`) restringe o que é retido; use-o sempre.

## 5. Limitações observadas (importantes)

- **Lógica no servidor não aparece no cliente.** Em apps **Next.js/server-side**, SDKs de pagamento,
  mensageria e vídeo **não** estão no bundle do browser — só se confirmam por **captura de rede durante
  o uso** (autenticado) ou por **APK**. Foi exatamente o que ocorreu com a Copilloto.
- `export-web-scripts` exige capturas de `inspect_web_page`/`capture_browser_scenario` (não de
  `analyze_web_bundle`).
- Sem source maps publicados, o código do cliente é praticamente ilegível (minificado/Turbopack).

## 6. Escopo e limites legais (⚖️)

- Uso **público e local**: páginas públicas + demo público; **sem** login, **sem** capturar área
  autenticada, **sem** descompilar APK — isso exige **aval jurídico** (ToS/EULA + Lei 9.609/98).
- **Nunca** copiar código/assets de concorrente; objetivo é entender **comportamento**.

## 7. Desinstalar (se necessário)

```bash
npm uninstall -g rea-agents
# remover a entrada "rea" de ~/.config/opencode/opencode.jsonc
# (Node em ~/.local/node-v22.23.3-darwin-arm64 e symlinks em ~/.local/bin)
```
