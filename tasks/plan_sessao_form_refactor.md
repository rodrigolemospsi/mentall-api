# Plano — Refatoração de `sessao_form_page.dart` (2388 linhas)

## Visão geral
Reduzir o arquivo principal de **2388 → ~800–1000 linhas** extraindo (a) os 21 `StateProvider` privados + ~40 getters para um arquivo de providers, (b) as seções de UI acopladas para widgets `ConsumerWidget` autocontidos (padrão já comprovado: `ArtigosSugeridosCard`, `BotoesAudioWidget`), e (c) a lógica de negócio (áudio/transcrição/síntese/salvar/exportar) para um controller. O padrão da app (StateProvider 100%, Riverpod 2.6.1) é preservado.

## Decisões de arquitetura
- **Não usar `part` files + extension** — caminho já falho (deletados em 01/08/2026; Dart resolve extensions estaticamente e métodos de instância têm precedência).
- **Providers globais públicos** como mecanismo de desacoplamento — é o que já funcionou para `BotoesAudioWidget`/`ArtigosSugeridosCard`.
- **API pública da página preservada**: `SessaoFormPage({paciente, sessaoExistente})` — 8 callers existentes não mudam.
- Seções muito acopladas recebem um **objeto de callbacks agrupados** (`SessaoFormActions`) em vez de 15 parâmetros soltos.

## Fases e tarefas

### Fase 0 — Rede de segurança (commit 1)
- T0.1 Corrigir flake de teardown do `sessao_form_page_test` (file-lock no `deleteBoxFromDisk`).
- T0.2 `dart format` no arquivo (indentação quebrada em `_pararGravacaoRelato` e `_removerAudioRelato`).
- Verificação: teste sem travar; `analyze` limpo.

### Fase 1 — Estado compartilhado (commit 2)
- T1.1 Criar `lib/providers/sessao_form_providers.dart` com os 21 `StateProvider` privados (renomear p/ públicos `sessao*`).
- T1.2 Remover ~40 getters/setters espelhados → `ref.read`/`ref.watch` direto.
- Verificação: testes de widget da página passam; `analyze` limpo.

### Fase 2 — Extração de seções de UI (commit 3)
- T2.1 `SecaoFinanceiroWidget` (160 ln) em `lib/widgets/sessao_financeiro_widget.dart`.
- T2.2 `SecaoProgressoWidget` (101 ln) em `lib/widgets/sessao_progresso_widget.dart`.
- T2.3 `SecaoRelatoIaWidget` (105 ln) em `lib/widgets/sessao_relato_ia_widget.dart` + `SessaoFormActions`.
- Verificação: testes de widget da página passam; `analyze` limpo.

### Fase 3 — Lógica de negócio (commit 4)
- T3.1 `SessaoFormController` em `lib/services/sessao_form_controller.dart` (áudio 13 métodos + transcrição + síntese + artigos/progresso/financeiro).
- T3.2 Mover `_salvarSessao` e `_exportarSessao`.
- Verificação: fluxo ponta a ponta nos testes; `analyze` limpo.

### Fase 4 — Qualidade (commit 5)
- T4.1 Dedupe dos 4 contadores de gravação.
- T4.2 Unificar `_obterObjetivosTerapeuticos` ≡ `_obterQueixaPrincipal`.
- T4.3 Mapper único de `Sessao` no `_salvarSessao` (remove ~75 ln duplicadas).
- T4.4 Remover `_progressoMetas` morto + `_nomeEscala` duplicado → `escala_service`.
- T4.5 `fontSize: 21` → `Tipografia`; SnackBars duplicados → constantes.
- Verificação: testes passam; `analyze` limpo.

### Fase 5 — Verificação final (commit 6)
- `flutter analyze` · `flutter test` completo · `flutter build apk` · atualizar AGENTS.md (pendência resolvida + nova estrutura).

## Checkpoints
- Após Fase 0–1: página compila e teste não-trava.
- Após Fase 2: UI idêntica com seções em arquivos separados.
- Após Fase 3: lógica extraída; arquivo principal ≤ ~1000 linhas.
- Após Fase 4: sem duplicação/hardcoded; revisão humana antes do merge final.

## Riscos e mitigação
| Risco | Impacto | Mitigação |
|---|---|---|
| Regressão visual/comportamental nas seções extraídas | Alto | Extração 100% mecânica; testes de widget existentes (12) |
| Flake de teardown cega os testes | Alto | Corrigir na Fase 0 |
| Providers globais com nome colidindo | Médio | Prefixo `sessao*` consistente |
| `_valorController` (TextEditingController) não é trivial de providerizar | Médio | Manter no State e passar ao `SecaoFinanceiroWidget` (1 parâmetro) |
| Cross-talk do `artigosSugeridosProvider` global | Baixo | Já documentado; fora de escopo (comportamento preservado) |

## Perguntas em aberto
- Nenhuma (decisões tomadas com o dono). Caso alguma extração pura exija mudar comportamento, parar e consultar.
