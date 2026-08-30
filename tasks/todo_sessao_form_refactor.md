# Tarefas — Refatoração do `sessao_form_page.dart`

## Fase 0 — Rede de segurança
- [x] 0.1 Corrigir flake de teardown do `sessao_form_page_test` (causa raiz: Hive.box.put no corpo de testWidgets + audioPlayerProvider injetavel)
- [x] 0.2 `dart format` no arquivo (indentação quebrada)

## Fase 1 — Estado compartilhado
- [x] 1.1 Criar `lib/providers/sessao_form_providers.dart` (21 StateProviders públicos)
- [x] 1.2 Getters/setters espelhados mantidos como camada fina do State (decisao: remocao em massa nao desacoplava mais)

## Fase 2 — Extração de seções de UI
- [x] 2.1 `SecaoFinanceiroWidget`
- [x] 2.2 `SecaoProgressoWidget`
- [x] 2.3 `SecaoRelatoIaWidget` + `SessaoFormActions`

## Fase 3 — Lógica de negócio
- [x] 3.1 Helpers puros em `lib/utils/sessao_form_helpers.dart` (decisao: audio/transcricao/sintese/salvar ficam no State por acoplamento a context/mounted/controllers)

## Fase 4 — Qualidade
- [x] 4.1 Dedupe contadores de gravacao (4 → 2: iniciar{resetarDuracao} + parar)
- [x] 4.2 Unificar `_obterObjetivosTerapeuticos`/`_obterQueixaPrincipal` (helpers)
- [x] 4.3 Mapper unico de `Sessao` no salvar (`_aplicarDadosComuns`)
- [x] 4.4 Remover `_progressoMetas` morto + `sessaoProgressoMetasProvider`
- [x] 4.5 `fontSize: 21` → Tipografia.xl

## Fase 5 — Verificação final
- [x] 5.1 `flutter analyze` limpo (1 warning pre-existente em tools/)
- [x] 5.2 `flutter test` completo: **153/153**
- [x] 5.3 Corrigido bug pre-existente em `compromisso_service_test` (horario fixo em vez de DateTime.now)
- [x] 5.4 Atualizar AGENTS.md (pendencia resolvida + nova estrutura)
