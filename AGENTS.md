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
- **Segurança:** Criptografia AES-256-CBC com PBKDF2-HMAC-SHA256 (100k iterações, pointycastle) + IV aleatório por registro + autenticação JWT no backend (python-jose + passlib)

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
│   ├── paciente.dart / .g.dart             # Hive typeId: 1 (12 campos: +email, +dataAtualizacao, +fotoBase64)
│   ├── perfil_profissional.dart / .g.dart  # Hive typeId: 3 (10 campos: +fotoBase64)
│   ├── sessao.dart / .g.dart               # Hive typeId: 2 (31 campos: +transcricaoRevisada, +artigosSugeridos)
│   ├── compromisso.dart / .g.dart          # Hive typeId: 4 (17 campos: +canalLembrete)
│   ├── contrato_terapeutico.dart / .g.dart # Hive typeId: 5 (9 campos)
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
│   ├── configuracoes_page.dart             # Configurações (PIN, agenda, IA, servidor)
│   ├── agenda_page.dart                    # Agenda completa (Dia/Semana/Mês) ~1190 linhas
│   ├── pacientes_page.dart                 # Lista dedicada de pacientes (Ativos/Arquivados)
│   └── lgpd/
│       ├── privacidade_seguranca_page.dart  # Tela de Privacidade e Segurança (LGPD)
│       ├── politica_privacidade_page.dart   # Política de Privacidade
│       └── termos_uso_page.dart             # Termos de Uso
├── providers/
│   └── service_providers.dart              # 12 providers (Stream com async* para emitir valor inicial)
├── services/
│   ├── api_client.dart                     # URL dinâmica via Hive + credenciais no Hive + ensureAuthenticated() + timeout 120s
│   ├── paciente_service.dart               # + criptografia AES nos campos sensíveis + cascade delete
│   ├── perfil_profissional_service.dart    # + criptografia AES
│   ├── sessao_service.dart                 # + criptografia AES (19 campos) + cache próximo número
│   ├── compromisso_service.dart            # CRUD de compromissos + recorrência + cancelamento de lembretes
│   ├── lembrete_service.dart               # Agendamento de notificações locais + envio ao backend (WhatsApp/SMS)
│   ├── backup_service.dart                 # Export/import JSON com exclusão de áudio grande + O(1) import
│   ├── transcricao_relato_service.dart     # Lê arquivo .m4a e converte Base64 (mobile) + JWT auto-auth
│   ├── ia_clinica_service.dart             # Conectado ao backend GPT-4.1 + pseudonimização + retry 5xx
│   ├── audio_relato_service.dart           # Gravação web (WAV/Base64) + mobile (M4A/arquivo)
│   ├── status_clinico_sessao_service.dart
│   ├── hive_migration_service.dart         # Schema V3
│   ├── encryption_service.dart             # PBKDF2-HMAC-SHA256 (100k iterações) + IV aleatório por registro
│   ├── auth_service.dart                   # PIN local + JWT backend (credenciais no Hive)
│   ├── pdf_export_service.dart             # 5 tipos + contrato: sessão, histórico, relatório, síntese, prontuário
│   ├── contrato_service.dart               # CRUD contratos + comunicação com backend
│   ├── configuracoes_service.dart          # Preferências (duração, lembretes, IA, tema, canal)
│   ├── logger.dart                         # Log.erro / Log.info / Log.auditoria + persistência em Hive+arquivo
│   └── lgpd/
│       ├── auditoria_service.dart          # Registro de eventos LGPD
│       └── pdf_arquitetura_lgpd_service.dart
├── widgets/
  │   ├── home_dashboard.dart                # Dashboard da Home (5 seções: saudação, ações, KPIs, sessões, atividade)
  │   ├── agenda_inline_widget.dart          # Agenda inline (Dia/Semana/Mês) ~640 linhas
  │   ├── compromisso_form_dialog.dart       # Diálogo de criação/edição de compromisso
  │   ├── novo_paciente_dialog.dart          # Diálogo de cadastro de paciente
  │   ├── paciente_card_home.dart            # Card de paciente na lista (avatar, status, WhatsApp)
  │   ├── paciente_resumo_card.dart          # Card de resumo na ficha do paciente (+ status contrato)
  │   ├── sessao_card.dart                   # Card de sessão na lista
  │   ├── sessao_audio_controls.dart         # Controles de áudio extraídos do SessaoFormPage
  │   ├── sessao_artigos_sugeridos.dart      # Card de artigos sugeridos extraído do SessaoFormPage
  │   ├── secao_campos_clinicos_widget.dart   # 4 seções clínicas simplificadas
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
├── templates/
│   └── contrato.html                  # Página HTML do Acordo Terapêutico (patient-facing)
├── services/
│   ├── ia_clinica.py                 # Síntese clínica (OpenAI/DeepSeek/Gemini) + busca de artigos (OpenAlex > SciELO RSS > rerank IA > links)
│   ├── transcricao.py               # Transcrição (gpt-4o-mini-transcribe, modelo configurável via TRANSCRICAO_MODEL)
│   ├── contrato_service.py          # Armazenamento de contratos (token único + aceite)
│   └── lembrete_service.py          # Scheduler de lembretes WhatsApp/SMS (asyncio + Twilio/Meta)
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
7. **Localização PT-BR**: `cancelText`/`confirmText` customizados nos 7 `showDatePicker`/`showTimePicker` ainda pendentes (labels padrão agora em PT-BR via `flutter_localizations`, mas custom labels não implementados).
8. **Faltam acentos/diacríticos**: `compromisso_form_dialog.dart` e `agenda_page.dart` com diversos textos sem acentuação (e.g. "Nao repete", "Ate", "Padrao", "sessao", "Amanha", "Proximo", "mes").
9. **Tema escuro (cores hardcoded)**: 88 ocorrências de `Colors.white`/`Colors.black` hardcoded + 92 cores hex fixas. `MentAllColors` criado como extensão do `BuildContext` com `ColorScheme`, mas migração das cores hardcoded ainda incompleta (apenas login, sessao_form, perfil_form, paciente_detail e lgpd/* foram migrados).

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
  - ~~App crash no launch (tela preta)~~ ✅ MainActivity.kt movido para pacote `com.mentall.app` correspondente ao namespace (22/07/2026)
  - ~~flutter_localizations + intl em dev_dependencies~~ ✅ movidos para dependencies (22/07/2026)
  - ~~Tema escuro (infra do MaterialApp)~~ ✅ darkTheme, themeMode com ColorScheme.fromSeed, toggle no ConfiguracoesService (22/07/2026)
  - ~~Localização PT-BR (base flutter_localizations)~~ ✅ supportedLocales, locale, delegates no MaterialApp (22/07/2026)
  - ~~Criptografia fraca (XOR simples)~~ ✅ PBKDF2-HMAC-SHA256 100k iterações + IV aleatório por registro + migração legado (22/07/2026)
  - ~~Remover PIN sem descriptografar dados~~ ✅ services descriptografam antes de limpar chave (22/07/2026)
  - ~~usesCleartextTraffic=true global~~ ✅ network_security_config restrito a redes locais (22/07/2026)
  - ~~Credenciais backend hardcoded~~ ✅ lidas do app_config via AuthService._username/_password (22/07/2026)

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

## Correções e Funcionalidades (18/07/2026) — SESSÃO 2

### Redesign da Home (inspiração PsiLuz)
- Novo widget `lib/widgets/home_dashboard.dart` com 5 seções:
  1. **SaudaçãoResumoHome**: "Boa tarde, Dr. Fulano!" + "Você tem N sessões hoje"
  2. **AcoesRapidasHome**: 3 botões tons-de-azul (Agendar, Novo paciente, Nova sessão)
  3. **KpiCardsHome**: 2×2 cards linkáveis (Hoje → Agenda, Pacientes → PacientesPage, Sessões → Agenda, Revisões → 1º paciente pendente)
  4. **SessoesHojeCard**: lista de compromissos do dia com avatar, nome, horário e chip de status; link "Ver todas" → AgendaPage; toque edita
  5. **AtividadeRecenteCard**: últimos 5 registros de auditoria com nome do paciente + link para ficha; "Rodrigo - Síntese gerada por IA"
- `AgendaInlineWidget` removido do body da Home
- Botão "Nova sessão": abre picker de paciente (se 1 paciente, vai direto) → `SessaoFormPage`

### Pacientes em página dedicada
- Nova `lib/screens/pacientes_page.dart` com abas Ativos/Arquivados (com contadores) e ações de arquivar/restaurar
- KPI "Pacientes (N)" na Home → navega para `PacientesPage`
- Home simplificada: removido `DefaultTabController` + `TabBar` + `TabBarView` + `_ListaPacientes`; só dashboard + FAB
- `NestedScrollView` + `ClampingScrollPhysics` (resolvido overscroll cinza + scroll "preso" nos pacientes)

### Fix: botões de ação da Agenda
- `_CompromissoCard`: `InkWell` de edição movido para área superior; botões de ação (`TextButton` Realizado, Faltou, Cancelar, Remover, Reagendar) fora do `InkWell` — não são mais interceptados
- `CompromissoService.marcarComoRealizado/Cancelado/Faltou/remover`: try-catch no `cancelarLembrete` para não bloquear a operação se notificação falhar

### UI
- Login: apenas `logo_mentall.png` (removido ícone circular duplicado); campo PIN com `keyboardType: TextInputType.number`
- FAB removido da Home (ações rápidas no topo substituem)

### Testes
- `home_page_test.dart`: removido teste "deve listar pacientes quando existem" (lista migrou para PacientesPage)
- 4/4 testes da Home passando

### Notas
- 93 testes passando; 4 warnings cosméticos de métodos não usados na Home (arquivar/restaurar herdados da versão antiga)
- `sessao_form_page_test.dart` tearDownAll: flake conhecido
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

## Correções e Funcionalidades (20/07/2026) — SESSÃO 1

### Splash Screen
- Ao abrir o app, exibe a logo MentAll (`logo_mentall.png` tema claro / `logo_mentall_escuro.png` tema escuro) centralizada por 3 segundos
- Fade-out de 500ms com `AnimationController` + `TickerProviderStateMixin` no `AppStartPage`
- Após splash: tela de bloqueio (se PIN ativo), perfil (primeiro uso) ou Home
- Testes atualizados com `pump(Duration(seconds: 3))` + `pump(Duration(milliseconds: 600))`

### Fix: foregroundColor hardcoded `Colors.white` → `context.corOnPrimaria`
- **login_page.dart**: botão de bloqueio/desbloqueio estava com `foregroundColor: context.corTextoHeading` (`onSurface`) — no tema claro dava texto escuro sobre botão azul (ilegível); corrigido para `corOnPrimaria`
- **sessao_form_page.dart**: 4 botões (Transcrever, Gerar síntese, Marcar como revisado, Salvar) + spinners — `Colors.white` → `corOnPrimaria`
- **perfil_profissional_form_page.dart**: AppBar + botão Salvar + spinner
- **paciente_detail_page.dart**: AppBar + botão Nova sessão
- **lgpd/politica_privacidade_page.dart** + **termos_uso_page.dart**: AppBar + scaffold `Colors.white` → `cs.surface`/`cs.primary`/`cs.onPrimary`
- Adicionado `corOnError` (`cs.onError`) ao `MentAllColors` e aplicado na tela de erro do `sessao_form_page.dart`

### Notas
- 69 testes passando (2 do app_start atualizados); analyze: 26 issues (todos preexistentes, sem novos erros)
- APK release 69.3MB

## Novas Funcionalidades e Correções (22/07/2026) — SESSÃO 1

### Fix crítico: App não abria (tela preta e crash imediato)
- Causa raiz: namespace alterado de `com.example.prontuario_tcc` para `com.mentall.app` no `build.gradle.kts`, mas `MainActivity.kt` permaneceu no pacote antigo (`com.example.prontuario_tcc`). `AndroidManifest.xml` declara `android:name=".MainActivity"` que resolve para `com.mentall.app.MainActivity` — classe não encontrada → `ClassNotFoundException` → crash imediato.
- Correção: `MainActivity.kt` movido para `android/app/src/main/kotlin/com/mentall/app/` e package atualizado para `com.mentall.app`.
- `flutter_localizations` e `intl` estavam em `dev_dependencies` — movidos para `dependencies` (causava warning `depend_on_referenced_packages` e seria excluído do tree-shaking em release).

### Tema escuro (dark mode)
- `MentAllApp` convertido de `StatelessWidget` para `ConsumerWidget` — assiste `configuracoesServiceProvider` + `configuracoesRevisaoProvider`
- Método `_criarTema(Brightness)` gera `ThemeData` via `ColorScheme.fromSeed` (claro e escuro)
- `themeMode: temaEscuro ? ThemeMode.dark : ThemeMode.light` — controlado pelo toggle `temaEscuro` no `ConfiguracoesService`
- `ThemeData` usa `colorScheme` (não mais cores hardcoded): `scaffoldBackgroundColor`, `appBarTheme`, `floatingActionButtonTheme`, `inputDecorationTheme`, `cardTheme`, `filledButtonTheme`
- Card elevation ajustado: light=1, dark=4

### Utilitário MentAllColors (cores por contexto)
- Novo arquivo `lib/utils/mentall_colors.dart` — extensão `MentAllColors` no `BuildContext`
- Propriedades: `corPrimaria`, `corOnPrimaria`, `corFundo`, `corSuperficie`, `corCard`, `corContainerPrimario`
- Textos: `corTextoHeading`, `corTextoBody` (0.87), `corTextoSecondary` (0.6), `corTextoMuted` (0.5), `corTextoPlaceholder` (0.38), `corTextoDisabled` (0.25)
- Status: `corSuccess`, `corError`, `corOnError`, `corWarning`, `corDanger`, `corScheduled`, `corCancelled`
- WhatsApp: `corWhatsAppBg` (#25D366), `corWhatsAppText` (#075E54)
- Divisores e bordas via `outlineVariant`; AppBar via `surface`/`primary`
- **Nota**: cores hardcoded (88x `Colors.white`/`Colors.black` + 92 hex fixas) ainda não foram todas migradas para `MentAllColors` — migração incremental nos arquivos modificados (login, sessao_form, perfil_form, paciente_detail, lgpd/*)

### Localização PT-BR (flutter_localizations)
- `MaterialApp` agora declara `supportedLocales: [Locale('pt', 'BR')]` e `locale: Locale('pt', 'BR')`
- Delegates: `GlobalMaterialLocalizations`, `GlobalWidgetsLocalizations`, `GlobalCupertinoLocalizations`
- `intl: ^0.20.2` adicionado como dependência direta
- Pickers de data/hora agora exibem texto em português (Cancelar/OK em vez de Cancel/OK)
- **Nota**: `cancelText`/`confirmText` customizados nos 7 `showDatePicker`/`showTimePicker` ainda pendentes

### Criptografia: PBKDF2-HMAC-SHA256 + IV aleatório por registro
- **KDF**: `_derivarChavePBKDF2()` usando `KeyDerivator('SHA-256/HMAC/PBKDF2')` com 100k iterações (substitui XOR simples legado)
- **Salt**: 32 bytes (antes 16)
- **Verification hash**: prefixo `v2:` para distinguir versões (legado sem prefixo)
- **IV aleatório por registro**: `criptografar()` gera `IV.fromSecureRandom(16)` por chamada; output prefixado com `2:iv:base64:cipher:base64` (formato com marker de versão)
- **Descriptografia**: detecta prefixo `2:` → extrai IV do ciphertext; fallback para IV global legado; fallback para texto puro (compatível com dados antigos)
- **Migração automática**: ao desbloquear com KDF v2, tenta fallback legado (`_tentarDesbloquearLegacy`) e re-protege a chave no novo formato (`_atualizarChaveProtegida`)
- **`trocarPin()`**: re-protege chave AES mestra com novo PIN (não gera chave nova — preserva dados existentes)
- **`removerPin()`**: agora chama `removerCriptografiaExistente()` nos services (`PacienteService`, `SessaoService`, `PerfilProfissionalService`) antes de limpar — descriptografa dados antes de remover a chave
- **`AuthService`**: recebe referências a `PacienteService`, `SessaoService`, `PerfilProfissionalService` para `removerPin()`; credenciais (`username`/`password`) lidas do `app_config` (não mais hardcoded `admin`/`admin`)

### Segurança de rede (Android)
- `usesCleartextTraffic="false"` no `AndroidManifest.xml` (antes `true` global)
- `network_security_config.xml`: permite cleartext apenas para `localhost`, `127.0.0.1`, `192.168.0.x` e `192.168.1.x` (desenvolvimento local)
- Produção usa HTTPS (`https://mentall-api.onrender.com`) — sem tráfego cleartext

### Contrato Terapêutico (Acordo Terapêutico)
- Novo modelo `ContratoTerapeutico` (Hive typeId 5, 9 campos): id, pacienteId, token, dataCriacao, dataEnvio, dataAceite, status, nomeAceite, url
- Hive box `contratos` aberta no `main()` junto com as demais
- `ContratoService`: criar contrato via `POST /contratos` (backend gera token único + URL), enviar link ao paciente, verificar status (`GET /contratos/{token}/status`), listar pendentes
- Provider: `contratoServiceProvider` + `contratoPorPacienteProvider` (StreamProvider.family)
- Backend: novo `services/contrato_service.py` (armazenamento em JSON, token único, página HTML de aceite em `templates/contrato.html`)

### Lembretes (backend)
- Novo `backend/services/lembrete_service.py`: scheduler de lembretes WhatsApp/SMS (asyncio + Twilio/Meta)
- `backend/requirements.txt` atualizado com dependências de lembretes

### Logo e identidade visual
- Novas logos: `logo_mentall_claro.png` (tema claro), `logo_mentall_escuro.png` (tema escuro), `logo_mentall_home.png` (launcher)
- Launcher icons regenerados com `logo_mentall_home.png` (todos os drawables e mipmaps atualizados)

### Web
- `web/manifest.json` atualizado para "MentAll"

### Notas
- Build APK debug: 162.7 MB (~12 min)
- APK debug compila e roda sem crash (validado com `flutter build apk --debug`)
- ~60 arquivos modificados (alterações incrementais nos últimos dias, não commitadas)
- `ContratoTerapeuticoAdapter` registrado no `hive_registrar.g.dart` (gerado via build_runner)

- **Produto comercial**: app destinado a publicação nas lojas (Google Play / App Store) — NÃO é projeto acadêmico; o nome da pasta `prontuario_tcc` é legado (TCC = Terapia Cognitivo-Comportamental, abordagem inicial do app)
- Diferencial: `ConfiguracaoAbordagemClinica` adapta o prontuário à abordagem do profissional
- Síntese clínica: OpenAI GPT-4.1 com response_format json_object + temperature 0.3
- Transcrição: OpenAI gpt-4o-mini-transcribe
- Fallback disponível: Google Gemini 2.0 Flash (trocar `IA_MODEL_PROVIDER=gemini`)
- PerfilProfissionalFormPage widget test: bug de `ListView` + `SliverChildListDelegate` + texto longo (>140 chars) no Card. Solução: `tester.view.physicalSize` ampliado
- Estrutura LGPD conforme documento `Arquitetura LGPD do MentAll.txt`
- OpenAPI project keys (`sk-proj-...`) exigem `OPENAI_PROJECT_ID` além da `OPENAI_API_KEY`
