# MentAll — Prontuário Clínico com IA

## Projeto
App Flutter para prontuário clínico adaptado à abordagem terapêutica do profissional (TCC, Psicanálise, ACT, DBT, etc.), com assistência de IA para transcrição e análise de sessões.

## Stack
- **Framework:** Flutter (SDK ^3.12.2)
- **Linguagem:** Dart / Python (backend)
- **Estado:** Riverpod 100% — 0 `setState` em todo o app. StreamProvider + StateProvider + ConsumerStatefulWidget
- **Banco local:** Hive CE (hive_ce + hive_ce_flutter + hive_ce_generator)
- **Áudio:** record + audioplayers + path_provider
- **Geração de código:** build_runner + hive_ce_generator
- **Backend:** Python FastAPI, OpenAI GPT-4.1 / DeepSeek / Gemini (síntese) + gpt-4o-transcribe (transcrição)
- **Deploy backend:** Render.com (plano gratuito, cold start ~30-60s)
- **Segurança:** Criptografia AES-256-CBC (encrypt + pointycastle) + autenticação JWT no backend (python-jose + passlib)

## Infraestrutura

### Backend em Nuvem (Render)
- **URL produção:** `https://mentall-api.onrender.com`
- **Repositório GitHub:** `https://github.com/rodrigolemospsi/mentall-api`
- **Plano:** Free (cold start na primeira requisição após inatividade)
- **Deploy:** Automático via push no branch `master`
- **Configuração:** `render.yaml` na raiz do repo (Blueprint)
- **Variáveis de ambiente no Render:**
  - `OPENAI_API_KEY` — chave API da OpenAI (projeto, formato `sk-proj-...`)
  - `OPENAI_PROJECT_ID` — ID do projeto OpenAI (formato `proj_...`)
  - `GEMINI_API_KEY` — chave API do Google Gemini (opcional; usada apenas se `IA_MODEL_PROVIDER=gemini`)
  - `DEEPSEEK_API_KEY` — chave API do DeepSeek (formato `sk-...`)
  - `IA_MODEL_PROVIDER` — provedor de síntese: `openai`, `deepseek` (ativo em produção) ou `gemini`
  - `IA_MODEL` — modelo específico (opcional; padrão por provedor: `gpt-4.1`, `deepseek-chat`, `gemini-2.0-flash`)
  - `JWT_SECRET` — chave secreta para tokens JWT
  - `APP_PASSWORD_HASH` — hash bcrypt da senha (vazio = senha padrão `admin`)
  - `OPENALEX_API_KEY` — chave gratuita da OpenAlex (https://openalex.org/settings/api, $1/dia ≈ 10k buscas; **obrigatória** — sem ela a API retorna 429 em IP de datacenter)
  - `OPENALEX_MAILTO` — email de contato enviado nas requisições à OpenAlex (`mentall.brasil@gmail.com`)

### APK (Android)
- **Permissões necessárias:** `INTERNET`, `RECORD_AUDIO`, `usesCleartextTraffic=true`
- **URL do backend:** Configurável via Hive box `app_config`. Padrão: `https://mentall-api.onrender.com`
- **Timeout API:** 120 segundos (necessário para cold start do Render + transcrição)
- **Diálogo de config:** Ícone ![dns](...) na AppBar da Home permite alterar URL sem rebuild

### Desenvolvimento Local
- Backend local: `python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload`
- Para testar APK no celular com backend local: mesmo Wi-Fi, firewall liberado porta 8000, `--host 0.0.0.0`
- URL padrão local: `http://192.168.1.24:8000` (Wi-Fi) ou `http://192.168.1.4:8000` (Ethernet)

## Estrutura

### Flutter App (`lib/`)
```
lib/
├── main.dart                              # Entry point, Hive init, ErrorWidget.builder, tema Material 3
├── hive_registrar.g.dart                  # Generated
├── config/
│   └── configuracao_abordagem_clinica.dart # 14 templates de abordagens (inclui Análise do Comportamento)
├── models/
│   ├── enums.dart                          # AbordagemClinica (14), TermoPessoaAtendida, StatusProcessamento, OrigemRelato (6)
│   ├── paciente.dart / .g.dart             # Hive typeId: 1 (10 campos: +email, +dataAtualizacao)
│   ├── perfil_profissional.dart / .g.dart  # Hive typeId: 3 (8 campos: +fotoBase64)
│   ├── sessao.dart / .g.dart               # Hive typeId: 2 (30 campos: +transcricaoRevisada)
│   └── lgpd/
│       └── registro_auditoria.dart / .g.dart  # Hive typeId: 10
├── screens/
│   ├── app_start_page.dart                 # Roteamento inicial (verifica PIN + perfil)
│   ├── home_page.dart                      # Lista de pacientes + botão servidor + Privacidade
│   ├── login_page.dart                     # Tela de PIN (configurar/desbloquear)
│   ├── paciente_detail_page.dart           # Detalhes + sessões + acesso última sessão ~720 linhas
│   ├── sessao_form_page.dart               # Formulário de sessão ~2090 linhas (+ error handling)
│   ├── backup_restore_page.dart            # Export/import JSON (conditional import)
│   ├── backup_restore_page_web.dart        # Web: Blob download + FileUpload
│   ├── backup_restore_page_io.dart         # Mobile/desktop: share_plus (export) + file_picker (import)
│   ├── perfil_profissional_form_page.dart
│   └── lgpd/
│       └── privacidade_seguranca_page.dart  # Tela de Privacidade e Segurança (LGPD)
├── providers/
│   └── service_providers.dart              # 12 providers (Stream com async* para emitir valor inicial)
├── services/
│   ├── api_client.dart                     # URL dinâmica via Hive + ensureAuthenticated() + timeout 120s
│   ├── paciente_service.dart               # + criptografia AES nos campos sensíveis
│   ├── perfil_profissional_service.dart    # + criptografia AES
│   ├── sessao_service.dart                 # + criptografia AES (18 campos)
│   ├── backup_service.dart                 # Export/import JSON com novos campos
│   ├── transcricao_relato_service.dart     # Lê arquivo .m4a e converte Base64 (mobile) + JWT auto-auth
│   ├── ia_clinica_service.dart             # Conectado ao backend GPT-4.1 + JWT auto-auth
│   ├── audio_relato_service.dart           # Gravação web (WAV/Base64) + mobile (M4A/arquivo)
│   ├── status_clinico_sessao_service.dart
│   ├── hive_migration_service.dart         # Schema V3
│   ├── encryption_service.dart             # AES-256-CBC (encrypt + pointycastle)
│   ├── auth_service.dart                   # PIN local + JWT backend
│   ├── pdf_export_service.dart             # 5 tipos: sessão, histórico, relatório clínico, síntese revisada, prontuário completo
│   ├── logger.dart                         # Log.erro / Log.info / Log.auditoria
│   └── lgpd/
│       └── auditoria_service.dart          # Registro de eventos LGPD
├── widgets/
  │   ├── secao_campos_clinicos_widget.dart   # 4 seções clínicas simplificadas: síntese, formulação, intervenções, apontamentos
│   └── lgpd/
│       └── aviso_privacidade_ia_card.dart
```

### Backend Python (`backend/`)
```
backend/
├── main.py                           # FastAPI app, CORS, JWT auth, rotas protegidas, /health com debug de provedores
├── .env                              # Chaves de API + JWT_SECRET (NÃO commitar)
├── .env.example                      # Template com variáveis documentadas
├── requirements.txt                  # openai>=1.0.0 + httpx + python-jose + passlib
├── models/
│   └── schemas.py                    # Pydantic models + LoginRequest/LoginResponse
├── services/
│   ├── ia_clinica.py                 # Síntese clínica (OpenAI/DeepSeek/Gemini) + busca de artigos (OpenAlex > SciELO RSS > rerank IA > links)
│   └── transcricao.py               # Transcrição (gpt-4o-mini-transcribe + project ID)
└── prompts/
    └── abordagens.py                 # 14 abordagens (inclui Análise do Comportamento)
```

### Arquivos de Deploy
```
render.yaml                          # Render Blueprint (na raiz do repo)
```

## Segurança

### Autenticação
- **Backend**: JWT (python-jose) — rota `POST /auth/login`, endpoints protegidos via `Authorization: Bearer <token>`
- **Flutter**: `ApiClient.ensureAuthenticated()` chamado antes de cada requisição API (transcrição e síntese)
- Token JWT gerado automaticamente com credenciais fixas (`admin`/`admin`)
- Expiração do token: 480 minutos (8 horas)

### Criptografia Local
- **Algoritmo**: AES-256-CBC (encrypt + pointycastle)
- **Proteção**: PIN do usuário deriva chave que protege a chave AES mestra
- **Services**: `PacienteService`, `SessaoService`, `PerfilProfissionalService` criptografam/descriptografam automaticamente
- **Fallback**: Sem PIN = dados em texto puro; descriptografia detecta texto puro e retorna como está

### LGPD / Privacidade
- **Áudio**: Limite de 5 minutos com contador e parada automática
- **Microtexto**: "Relato breve do profissional após a sessão. Limite: 5 minutos." na tela de gravação
- **Auditoria**: Registro de eventos (gravação, transcrição, IA, revisão) em `RegistroAuditoria` (typeId 10)
- **Arquivamento**: Em vez de exclusão (padrão desde o início)
- **Revisão**: Obrigatória pelo profissional (campo `revisadoPeloProfissional`)
- **IA**: Apenas apoio documental, nunca substitui julgamento clínico
- **Tela Privacidade**: Acessível pelo ícone de escudo na Home — PIN, áudio, IA, retenção, auditoria
- **Exportação**: Aviso de dados sensíveis; 5 formatos de PDF
- **Logs**: `Log.auditoria()` separado de `Log.erro()`; logs técnicos não contêm dados clínicos

## Padrões e Regras de Código

### StreamProvider com Hive (IMPORTANTE)
`Hive.box.watch()` NÃO emite na subscrição inicial — apenas quando há mudanças. Sempre use `async*` para emitir o valor inicial:
```dart
final provider = StreamProvider<List<T>>((ref) async* {
  final service = ref.watch(serviceProvider);
  yield service.listar();                       // ← emite valor inicial
  await for (final _ in service.observar()) {   // ← observa mudanças
    yield service.listar();
  }
});
```

### _triggerRebuild() no SessaoFormPage
A página `SessaoFormPage` usa `ref.read` nos getters (não `ref.watch`), então mudanças de estado NÃO causam rebuild automático. Todo método que altera providers de UI deve chamar `_triggerRebuild()` após as alterações.

### Autenticação Backend
Chamadas à API (`TranscricaoRelatoService`, `IaClinicaService`) devem chamar `ApiClient.ensureAuthenticated()` antes de cada requisição para garantir token JWT válido.

### Áudio Mobile vs Web
- **Web**: PCM 16-bit → WAV em memória → Base64 direto
- **Mobile**: AAC LC → arquivo .m4a → `TranscricaoRelatoService` lê arquivo e converte para Base64
- `AudioRelatoService.obterAudioAtualBase64()` só retorna dados no Web

## Problemas Conhecidos

### Pendentes
1. **VS Build Tools incompleto**: Windows Desktop workload não instalado — `flutter run -d windows` falha
2. **Web debug service**: `flutter run -d chrome` falha com timeout no WebkitDebugger (Chrome 150 + Flutter 3.44). Workaround: `flutter build web` + `python -m http.server 5000`
3. **Chave OpenAI**: Formato `sk-proj-...` (project key) requer `OPENAI_PROJECT_ID` no ambiente
4. **Render cold start**: Primeira requisição após inatividade leva 30-60s. Timeout do app ajustado para 120s
5. **APK release vs debug**: `flutter build apk` gera release (menor). Debug: `flutter build apk --debug`
6. **SciELO bloqueia datacenter**: `search.scielo.org` usa anti-bot "bunny-shield" que retorna 403 para IPs de datacenter (Render). OpenAlex é a fonte primária; SciELO é fallback (funciona só localmente).

### Resolvidos
- ~~Segurança: zero autenticação~~ ✅ JWT backend + criptografia AES local
- ~~State management: setState (40x)~~ ✅ 0 setState — 100% Riverpod
- ~~Arquivos enormes~~ ✅ sessao_form_page 2166→2090, campos clínicos extraídos
- ~~Abordagens incompletas~~ ✅ 14 abordagens (inclui Análise do Comportamento)
- ~~Campos ausentes~~ ✅ email, dataNascimento, dataAtualizacao, transcricaoRevisada
- ~~Exportação limitada~~ ✅ 5 tipos de PDF
- ~~Código morto~~ ✅ CampoClinico removido do backend
- ~~StreamProvider lista vazia~~ ✅ async* com yield inicial (08/07/2026)
  - ~~Tela vermelha SessaoFormPage~~ ✅ try-catch initState + ErrorWidget.builder (08/07/2026)
  - ~~UI não respondia a ações de áudio~~ ✅ _triggerRebuild() em 9 métodos (08/07/2026)
  - ~~APK sem permissão INTERNET~~ ✅ AndroidManifest atualizado (08/07/2026)
  - ~~URL backend hardcoded~~ ✅ Configurável via Hive + diálogo na Home (08/07/2026)
  - ~~Transcrição não enviava áudio no mobile~~ ✅ Leitura de arquivo .m4a + Base64 (08/07/2026)
  - ~~SessaoFormPage: UI complexa com 12 campos~~ ✅ Simplificado para 5 campos: transcrição, relato, síntese, formulação, intervenções, apontamentos (08/07/2026)
  - ~~Gravação quebrava após remover áudio~~ ✅ _audioRelatoService.dispose() removido — AudioRelatoService é singleton (09/07/2026)
  - ~~Abertura lenta do app~~ ✅ _inicializarBackendAuth() assíncrono removido do main(); boxes paralelas; splash azul (09/07/2026)
  - ~~Tabs no AppBar~~ ✅ Movidas para o body logo acima da lista de pacientes (09/07/2026)
  - ~~Cor antiga verde-azulado (#1F6F78)~~ ✅ Substituída por azul #2563EB em todo o app (09/07/2026)
  - ~~Humor no card de sessão~~ ✅ Removido do widget e do prompt da IA (09/07/2026)
  - ~~9 testes quebrados~~ ✅ Corrigidos: home_page, app_start, paciente_detail (09/07/2026)
  - ~~Artigos sugeridos alucinavam links (DOIs inventados pelo LLM)~~ ✅ IA extrai só `temas_pesquisa`; backend busca artigos reais (15/07/2026)
  - ~~Teste perfil_form quebrava sem box Hive~~ ✅ try-catch no initState (15/07/2026)
  - ~~/health mostrava modelo errado~~ ✅ exibe provider + modelo efetivo por provedor (15/07/2026)

## Novas Funcionalidades (09/07/2026)

### Agenda Inline na Home
- Agenda completa integrada na tela inicial com navegação entre datas
- Componente `_AgendaInline` com seletor de data, lista de compromissos e botão "Novo compromisso"
- Navegação entre dias com `_agendaDataProvider`
- Provider `compromissosHojeProvider` no `service_providers.dart`
- Modelo `Compromisso` (Hive typeId 4) com status: agendado, realizado, cancelado, faltou
- Serviço `CompromissoService` com CRUD completo
- Diálogo `CompromissoFormDialog` para criar/editar compromissos

### Foto do Paciente
- Campo `fotoBase64` (@HiveField(11)) no modelo `Paciente`
- Seleção de foto via `image_picker` no diálogo de cadastro
- Exibição no `PacienteCardHome` como `CircleAvatar` com `MemoryImage`
- Fallback para inicial quando sem foto

### WhatsApp Integrado
- Botão no card do paciente abaixo do chip "Ativo"
- Abre conversa externa via `url_launcher` com `https://wa.me/<numero>`
- Número limpo de caracteres não numéricos
- Query adicionada ao AndroidManifest para Android 11+

### Logo e Identidade Visual
- Logo `assets/images/logo_mentall.png` no AppBar, tela de login e cabeçalho de PDFs
- Ícone do app gerado via `flutter_launcher_icons` (com adaptive icon)
- Splash screen nativa azul #2563EB (sem flash branco)
- Nome do app "MentAll" no AndroidManifest (antes era "prontuario_tcc")
- Paleta de cores azul minimalista aplicada em 17 arquivos

### Edição Bloqueada
- Sessão salva fica bloqueada por padrão (`_modoEdicao = false`)
- Botão "Editar" no cabeçalho ao lado de "Sessão N"
- Campos protegidos com `IgnorePointer` quando bloqueado
- Botão "Salvar" visível apenas no modo edição

### Indicação de Artigos Científicos
- Campo `artigosSugeridos` (@HiveField(30)) no modelo `Sessao`
- Fluxo anti-alucinação com rerank (15/07/2026): a IA extrai 2 `temas_pesquisa` (objetos `{especifico, amplo}` — específico 4-6 palavras, amplo 2-3 como fallback); o backend busca candidatos reais e a IA seleciona os mais relevantes:
  1. **OpenAlex API** (fonte primária) — `filter=title_and_abstract.search:<tema>,language:pt,type:article,from_publication_date:2010-01-01` + filtro Psicologia (`primary_topic.field.id:fields/32`, removido se zero resultados); requer `OPENALEX_API_KEY` (params via `_openalex_params`); extrai título, autores, ano, citações, DOI e abstract (reconstruído do `abstract_inverted_index`)
  2. **SciELO RSS** (fallback) — título, autores, link e resumo reais (funciona local; 403 no Render)
  3. **Rerank pela IA** — 2ª chamada ao provedor (`_chamar_llm_json`, temperature 0.1) escolhe até 3 candidatos mais relevantes ao contexto clínico da sessão, com justificativa de 1 linha (`Relevância: ...`); se descartar todos ou falhar a busca, cai para links de busca determinísticos (`BASES_PESQUISA`)
- Pool: até 6 candidatos por tema (união específico+amplo, dedupe por ID/link) — funções em `backend/services/ia_clinica.py`: `_buscar_candidatos_openalex`, `_buscar_candidatos_scielo`, `_buscar_candidatos_tema`, `_rerankear_artigos`, `_formatar_artigos`, `_montar_artigos`
- Exibição na tela de sessão após "Apontamentos" em card azul claro; URLs viram link "Acesse Aqui!" (`_buildArtigosComLinks`)

### Outras Melhorias
- Home com `CustomScrollView` (resolve overflow em telas pequenas)
- Busca de pacientes removida da home (simplificação)
- Perfil profissional movido para menu "Mais"
- Botão "Marcar como revisado" (texto simplificado)
- IA não envia mais parâmetro `humor` (removido do prompt, schema e endpoint)
- Testes atualizados: 67/67 passando

## Novas Funcionalidades (15/07/2026)

### Artigos Científicos Reais (SciELO/OpenAlex)
- Ver seção "Indicação de Artigos Científicos" — OpenAlex (primária) > SciELO RSS (fallback) > rerank pela IA > links de busca
- Provider de síntese em produção: DeepSeek (`deepseek-chat`)

## Correções e Funcionalidades (16/07/2026) — COMMITADO E VALIDADO

### Fix: artigos sugeridos apagavam ao sair da sessão (dupla criptografia)
- Causa raiz: `SessaoService.listarSessoesPendentesRevisao()` não descriptografava; a Home passava sessão cifrada ao `SessaoFormPage`, que re-criptografava ao salvar (corrompia os campos)
- Correção: `_decryptSessoes(pendentes)` em `listarSessoesPendentesRevisao()` + `_triggerRebuild()` nos 2 `addPostFrameCallback` do `initState` do `SessaoFormPage`
- Backend: removido prefixo "Acesse: " em `_formatar_artigos` (app já renderiza "Acesse Aqui!")
- Testes: `test/services/sessao_service_encryption_test.dart` (5 testes) + grupo "Persistencia de artigos sugeridos" (2 testes) — todos passando (`pumpAndSettle` trava nessa tela; usar `pump` com Duration)
- Atenção: sessões já corrompidas pela dupla criptografia no aparelho NÃO são recuperadas pela correção

### Backup e restauração no mobile (antes era no-op)
- `backup_restore_page_stub.dart` (no-op) substituído por `backup_restore_page_io.dart`: exporta via `share_plus` (arquivo temp + share sheet) e importa via `file_picker` (`FileType.any` + `withData`)
- Funções renomeadas nas duas implementações (io/web): `exportarJson()` / `selecionarArquivoJson()`
- Dependências: `share_plus ^10.1.4` + `file_picker ^10.1.0` — **não atualizar sem testar**:
  - share_plus 13 ↔ file_picker <12 conflitam via `win32`
  - file_picker 11.x não compila com AGP 9 + `android.builtInKotlin=false` (pula o plugin Kotlin e a classe `FilePickerPlugin` não existe)
  - file_picker 10.1.0 fixa compileSdk 34 → override no `android/build.gradle.kts` força `compileSdk = 36` em todos os módulos de plugin (com guarda `state.executed` por causa do `evaluationDependsOn(":app")`)

### UI (sessão de 16/07)
- Tela de boas-vindas (1º acesso): **sem AppBar** (faixa azul removida), logo MentAll centralizada 160px (dobrada)
- Edição de perfil (perfil já existe, flag `_perfilExistente`): AppBar "Perfil profissional" com voltar; logo à esquerda 56px; sem textos de boas-vindas
- Foto do perfil profissional dobrada (CircleAvatar radius 44→88)
- Novo paciente: dropdown "Modalidade de atendimento" (`perfil.opcoesModoAtendimento`: Online + apelidos dos endereços) → salva em `Paciente.modoAtendimento` (campo já existia, só era usado na edição)
- Logo WhatsApp no card do paciente dobrada (28→56px)
- "Configurar servidor" removido do menu "Mais" da Home (diálogo excluído; `ApiClient.setBaseUrl` continua existindo, sem UI)
- Testes atualizados: texto "Configuração inicial" não existe mais — asserts usam "Bem-vindo ao MentAll"
- `.gitignore`: `android/.kotlin/`, `test/temp_hive/`, `android/build/`

### Build/Deploy
- APK release gerado (65,5MB) — build demora ~10-15 min; usar timeout ≥ 20 min
- Commits `5c04d36` e `283b584` enviados ao GitHub (repo único app+backend: `rodrigolemospsi/mentall-api`)
- ~~Pendente: teste manual no aparelho~~ ✅ Validado em 18/07 (referências persistindo + backup exportar/importar)
- Arquivo solto não commitado: `assets/images/logo_whats11.png` (não usado; código usa `logo_whats.png`)

### Foto do Perfil Profissional
- Campo `fotoBase64` (@HiveField(9)) no modelo `PerfilProfissional` + getter `possuiFoto`
- Seleção via `image_picker` no formulário de configuração inicial (CircleAvatar tocável)

### Autenticação e PIN
- `ApiClient.forceReauthenticate()` — limpa token cacheado e refaz login JWT
- `AuthService.removerPin()` — remove PIN e limpa chave de criptografia

### Layout da Sessão v2
- AppBar mostra "Prontuário Clínico" no modo edição (antes "Editar sessão")
- Botões de áudio circulares estilo gravador profissional: ícone em círculo tonal + rótulo curto abaixo (`_botaoAudioCircular`)
- Rótulos: Gravar/Regravar, Pausar, Retomar, Finalizar, Cancelar, Ouvir/Parar, Remover, Transcrever

## Correções e Funcionalidades (18/07/2026) — TESTADO NO APARELHO

### Backup em texto claro + import com sobrescrita
- `BackupService` recebe `EncryptionService` opcional (via `backupServiceProvider`): **export descriptografa** os campos sensíveis (JSON legível) e **import criptografa** ao salvar
- Import agora **sobrescreve** registros com mesmo ID (`_salvarSobrescrevendo`) — antes ignorava duplicados; contadores refletem tudo que foi processado
- Export inclui `foto_base64` do perfil profissional
- Testes: `test/services/backup_service_test.dart` (7 testes: texto claro, roundtrip, sobrescrita, criptografia no import)

### Agenda completa com modos Dia/Semana/Mês
- `AgendaPage` espelha a agenda inline da Home: seletor de modo (Dia/Semana/Mês), faixa da semana, grade do mês com dot de compromissos, navegação por período, botão "Hoje" (AppBar) que volta para hoje + modo dia
- Removido limite de 365 dias no futuro (Home não tem)
- Fix no `AgendaInlineWidget` (Home): abreviações dos dias estavam erradas (['D','S','T',...] indexado por weekday-1 dava 'D' para segunda) → `['S','T','Q','Q','S','S','D']`; grade do mês trocada de `Wrap` (quebrava as 7 colunas em telas largas) para `Row`s de 7 células `Expanded` — mesma grade usada na `AgendaPage`

### Home
- Abas com contadores: "Ativos (N)" / "Arquivados (N)"

### Perfil profissional
- Labels: "Como se referir à pessoa atendida?" (antes "Como prefere...") e "Endereços" (antes "Endereço(s) de atendimento"); ícone de localização 20→40px
- Fix seta de voltar fantasma na Home: salvar perfil existente fazia `pushReplacement` para nova HomePage sobre a Home original; agora faz `Navigator.pop` (pushReplacement só no 1º cadastro)

### Notas
- 86 testes passando; `tearDownAll` do `sessao_form_page_test` às vezes trava no `deleteBoxFromDisk` (flake de file-lock no Windows, não é falha de teste)
- APK release 65,6MB testado no aparelho: agenda 3 modos, contadores, backup export/import, referências persistindo — tudo OK

## Correções e Funcionalidades (18/07/2026) — SESSÃO 2

### Fix crítico: PIN não salvava (late final box não inicializada)
- Causa raiz: `EncryptionService._box` e `AuthService._box` eram `late final` inicializadas apenas em `inicializar()`, método removido do `main()` na otimização de 09/07. Toda operação de PIN (configurar, trocar, remover, desbloquear) lançava `LateInitializationError` silencioso.
- Correção: boxes acessadas via `Hive.box<T>('nome')` diretamente (já abertas no `main()`), sem precisar de `inicializar()`.
- `autenticarBackend()` ganhou timeout de 15s no `http.post` — antes sem timeout, travava minutos no cold start do Render, bloqueando o salvamento do PIN.
- `configurarPin`/`desbloquearComPin` disparam `_tentarAutenticarBackend()` em background (`unawaited`) — PIN salva/desbloqueia instantaneamente, sem esperar o backend.
- `EncryptionService.trocarPin(pinAtual, novoPin)`: re-protege a chave AES mestra existente com o novo PIN (não gera chave nova, preserva dados já criptografados).
- `AuthService.trocarPin(pinAtual, novoPin)`: delegate para o EncryptionService + flag `_desbloqueado`.
- Feedback visível: snackbar de confirmação/erro nos diálogos de configurar e trocar PIN em ambas as telas (Configurações e Privacidade).
- Switch de PIN atualiza na hora (StateProvider `_pinRevisaoProvider`).

### Nova tela: Configurações (menu "Mais" da Home)
- **Segurança**: ativar/remover PIN, trocar PIN, bloquear agora (mesmas funcionalidades da Privacidade, com UI de confirmação melhorada)
- **Agenda e lembretes**: duração padrão da sessão (30–120 min), lembrete SMS ligado por padrão, antecedência padrão (30 min – 48h)
- **IA**: toggle "Sugerir artigos científicos" — ao desligar, `sessao_form_page.dart` zera `artigosSugeridos` após a síntese
- **Avançado**: URL do servidor com "Restaurar padrão" (UI que havia sido removida da Home voltou centralizada)
- `ConfiguracoesService` (Hive `app_config`) + `configuracoesServiceProvider` + `configuracoesRevisaoProvider`
- `CompromissoFormDialog` ganhou parâmetros opcionais (`duracaoPadraoMinutos`, `lembretePadraoAtivado`, `antecedenciaPadraoMinutos`); horário de **término** agora é editável (antes fixo início+1h)
- Callers (AgendaPage, agenda inline) passam os padrões do `ConfiguracoesService`

### Redesign da Home (inspiração PsiLuz)
- Novo widget `lib/widgets/home_dashboard.dart` com 5 seções:
  1. **SaudaçãoResumoHome**: "Boa tarde, Dr. Fulano!" + "Você tem N sessões hoje"
  2. **AcoesRapidasHome**: 3 botões tons-de-azul (Agendar, Novo paciente, Agenda)
  3. **KpiCardsHome**: 2×2 cards (Sessões hoje, Pacientes ativos, Sessões 30d, Revisões pendentes)
  4. **SessoesHojeCard**: lista de compromissos do dia com avatar, nome, horário e chip de status; link "Ver todas" → AgendaPage; toque edita
  5. **AtividadeRecenteCard**: últimos 5 registros de auditoria com ícone por tipo, descrição e tempo relativo ("agora", "5min atrás", "ontem")
- `AgendaInlineWidget` removido do body da Home (agenda completa na tela dedicada)
- FAB mantido (botão "+ Novo paciente" não conflita com ações rápidas)

### Auditoria alimentando o feed de atividade
- `AuditoriaService.observar()` (stream de `BoxEvent`)
- Novos providers: `atividadeRecenteProvider`, `dashboardKpisSessoesProvider`
- Novos registros de auditoria:
  - Paciente cadastrado (`novo_paciente_dialog.dart` — parâmetro opcional `auditoriaService`)
  - Compromisso agendado (`agenda_page.dart`, `agenda_inline_widget.dart`, `home_page.dart._novoCompromissoRapido`)
  - Sessão registrada (`sessao_form_page.dart._salvarSessao`)

### Notas
- 86 testes passando + 7 novos (ConfiguracoesService, trocarPin) = 93 total
- `sessao_form_page_test.dart` tearDownAll: flake de file-lock no Windows (conhecido, não é falha)
- `home_page_test.dart` atualizado para o novo layout (KPI, scroll, boxes de auditoria)
- APK release 65,7MB

## Cores do App
```
Primary:         #2563EB   Azul principal (AppBar, FAB, títulos, ações)
Primary Light:   #DBEAFE   Borda de cards de destaque
Primary BG:      #EFF6FF   Fundo de cards de destaque
Text Heading:    #1E293B   Títulos
Text Body:       #334155   Corpo de texto
Text Secondary:  #475569   Texto secundário
Text Muted:      #64748B   Texto suave
Placeholder:     #94A3B8   Placeholders, tabs inativas
Disabled:        #CBD5E1   Elementos desabilitados
Page BG:         #F7F9FA   Fundo de todas as telas
Card BG:         #F8FAFC   Fundo de cards (PDF)
Surface:         #F1F5F9   Superfícies alternativas
Divider:         #E2E8F0   Separadores e bordas sutis
Success:         #2E7D32   Ativo, realizado, OK
Error:           #D32F2F   Erros
Warning:         #E65100   Pendente de revisão
Warning BG:      #FFF3E0   Fundo de aviso
Danger:          #C62828   Faltou, ação destrutiva
WhatsApp BG:     #25D366   Fundo botão WhatsApp
WhatsApp Text:   #075E54   Texto botão WhatsApp
Scheduled:       #1976D2   Status agendado
Cancelled:       #757575   Cancelado, inativo
```

## Layout da Sessão (após redesenho 08/07/2026)
A tela de sessão foi simplificada:
- **Cabeçalho**: nome em maiúsculo/negrito + "Sessão N" (sem abordagem)
- **Info**: apenas data e horário (sem tema principal, sem humor)
- **Breve relato**: controles de áudio + transcrição + botão IA + relato clínico organizado
- **Síntese clínica**: 1 campo combinado (eventos + evolução + observações)
- **Formulação clínica**: 1 campo combinado (pensamentos + emoções + comportamentos)
- **Intervenções**: 1 campo combinado (intervenções + técnicas)
- **Apontamentos**: 1 campo (renomeado de "Apontamentos do Copiloto")
- Removidos: Tarefas e planos, status card, humor, tema principal

## Comandos

### App Flutter
- `flutter analyze` — análise estática (0 errors, ~17 warnings/infos cosméticos)
- `flutter test` — 74 testes
- `dart run build_runner build` — gerar adapters Hive
- `flutter build web` — build de produção
- `flutter build apk` — build APK Android release (saída: `build/app/outputs/flutter-apk/app-release.apk`)

### Web (Chrome)
- ⚠️ `flutter run -d chrome` atualmente quebrado (debug service timeout)
- Alternativa: `flutter build web` + `python -m http.server 5000` no diretório `build/web`
- **Sempre use porta fixa 5000** para não perder dados do Hive/localStorage

### Backend Local
```bash
cd backend
pip install -r requirements.txt
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### Deploy (Render)
```bash
git add -A
git commit -m "mensagem"
git push origin master
# Deploy automático pelo Render — sem comandos adicionais
```

### Testar API no Render
```bash
# Health check
curl https://mentall-api.onrender.com/health

# Login (obter token JWT)
curl -X POST https://mentall-api.onrender.com/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}'
```

## Observações
- **Produto comercial**: app destinado a publicação nas lojas (Google Play / App Store) — NÃO é projeto acadêmico; o nome da pasta `prontuario_tcc` é legado (TCC = Terapia Cognitivo-Comportamental, abordagem inicial do app)
- Diferencial: `ConfiguracaoAbordagemClinica` adapta o prontuário à abordagem do profissional
- Síntese clínica: OpenAI GPT-4.1 com response_format json_object + temperature 0.3
- Transcrição: OpenAI gpt-4o-mini-transcribe
- Fallback disponível: Google Gemini 2.0 Flash (trocar `IA_MODEL_PROVIDER=gemini`)
- PerfilProfissionalFormPage widget test: bug de `ListView` + `SliverChildListDelegate` + texto longo (>140 chars) no Card. Solução: `tester.view.physicalSize` ampliado
- Estrutura LGPD conforme documento `Arquitetura LGPD do MentAll.txt`
- OpenAPI project keys (`sk-proj-...`) exigem `OPENAI_PROJECT_ID` além da `OPENAI_API_KEY`
