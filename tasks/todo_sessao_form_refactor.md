# Tarefas — Refatoração do `sessao_form_page.dart`

## Fase 0 — Rede de segurança
- [ ] 0.1 Corrigir flake de teardown do `sessao_form_page_test` (file-lock no deleteBoxFromDisk)
- [ ] 0.2 `dart format` no arquivo (indentação quebrada)

## Fase 1 — Estado compartilhado
- [ ] 1.1 Criar `lib/providers/sessao_form_providers.dart` (21 StateProviders públicos)
- [ ] 1.2 Remover ~40 getters/setters espelhados → ref.read/ref.watch

## Fase 2 — Extração de seções de UI
- [ ] 2.1 `SecaoFinanceiroWidget`
- [ ] 2.2 `SecaoProgressoWidget`
- [ ] 2.3 `SecaoRelatoIaWidget` + `SessaoFormActions`

## Fase 3 — Lógica de negócio
- [ ] 3.1 `SessaoFormController` (áudio/transcrição/síntese/progresso/financeiro)
- [ ] 3.2 Mover `_salvarSessao` e `_exportarSessao`

## Fase 4 — Qualidade
- [ ] 4.1 Dedupe contadores de gravação (4 → 1)
- [ ] 4.2 Unificar `_obterObjetivosTerapeuticos`/`_obterQueixaPrincipal`
- [ ] 4.3 Mapper único de `Sessao` no salvar
- [ ] 4.4 Remover `_progressoMetas` morto + `_nomeEscala` duplicado
- [ ] 4.5 `fontSize: 21` → Tipografia; SnackBars duplicados → constantes

## Fase 5 — Verificação final
- [ ] 5.1 `flutter analyze` limpo
- [ ] 5.2 `flutter test` completo
- [ ] 5.3 `flutter build apk`
- [ ] 5.4 Atualizar AGENTS.md (pendência resolvida + nova estrutura)
