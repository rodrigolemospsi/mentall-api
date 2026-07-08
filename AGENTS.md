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
- **Backend:** Python FastAPI (porta 8000), OpenAI GPT-4.1 (síntese) + gpt-4o-mini-transcribe (transcrição)
- **Segurança:** Criptografia AES-256-CBC (encrypt + pointycastle) + autenticação JWT no backend (python-jose + passlib)

## Estrutura

### Flutter App (`lib/`)
```
lib/
├── main.dart                              # Entry point, Hive init, autenticação backend, tema Material 3
├── hive_registrar.g.dart                  # Generated
├── config/
│   └── configuracao_abordagem_clinica.dart # 14 templates de abordagens (inclui Análise do Comportamento)
├── models/
│   ├── enums.dart                          # AbordagemClinica (14), TermoPessoaAtendida, StatusProcessamento, OrigemRelato (6)
│   ├── paciente.dart / .g.dart             # Hive typeId: 1 (10 campos: +email, +dataAtualizacao)
│   ├── perfil_profissional.dart / .g.dart  # Hive typeId: 3 (7 campos: +dataAtualizacao)
│   ├── sessao.dart / .g.dart               # Hive typeId: 2 (30 campos: +transcricaoRevisada)
│   └── lgpd/
│       └── registro_auditoria.dart / .g.dart  # Hive typeId: 10
├── screens/
│   ├── app_start_page.dart                 # Roteamento inicial (verifica PIN + perfil)
│   ├── home_page.dart                      # Lista de pacientes + botão Privacidade
│   ├── login_page.dart                     # Tela de PIN (configurar/desbloquear)
│   ├── paciente_detail_page.dart           # Detalhes + sessões + acesso última sessão ~720 linhas
│   ├── sessao_form_page.dart               # Formulário de sessão ~2090 linhas
│   ├── backup_restore_page.dart            # Export/import JSON (conditional import)
│   ├── backup_restore_page_web.dart        # Web: Blob download + FileUpload
│   ├── backup_restore_page_stub.dart       # Stub não-web (no-op)
│   ├── perfil_profissional_form_page.dart
│   └── lgpd/
│       └── privacidade_seguranca_page.dart  # Tela de Privacidade e Segurança (LGPD)
├── providers/
│   └── service_providers.dart              # 12 providers (inclui EncryptionService, AuthService, AuditoriaService)
├── services/
│   ├── api_client.dart                     # URL base + JWT auth headers estáticos
│   ├── paciente_service.dart               # + criptografia AES nos campos sensíveis
│   ├── perfil_profissional_service.dart    # + criptografia AES
│   ├── sessao_service.dart                 # + criptografia AES (18 campos)
│   ├── backup_service.dart                 # Export/import JSON com novos campos
│   ├── transcricao_relato_service.dart     # Conectado ao backend OpenAI com JWT
│   ├── ia_clinica_service.dart             # Conectado ao backend GPT-4.1 com JWT
│   ├── audio_relato_service.dart           # Gravação web/mobile
│   ├── status_clinico_sessao_service.dart
│   ├── hive_migration_service.dart         # Schema V3
│   ├── encryption_service.dart             # AES-256-CBC (encrypt + pointycastle)
│   ├── auth_service.dart                   # PIN local + JWT backend
│   ├── pdf_export_service.dart             # 5 tipos: sessão, histórico, relatório clínico, síntese revisada, prontuário completo
│   ├── logger.dart                         # Log.erro / Log.info / Log.auditoria
│   └── lgpd/
│       └── auditoria_service.dart          # Registro de eventos LGPD
├── widgets/
│   ├── secao_campos_clinicos_widget.dart   # 5 seções clínicas combinadas (extraído do sessao_form_page)
│   └── lgpd/
│       └── aviso_privacidade_ia_card.dart
```

### Backend Python (`backend/`)
```
backend/
├── main.py                           # FastAPI app (porta 8000), CORS, JWT auth, rotas protegidas
├── .env                              # Chaves de API + JWT_SECRET
├── .env.example                      # Template com variáveis documentadas (inclui JWT)
├── requirements.txt                  # + python-jose[cryptography] + passlib[bcrypt]
├── models/
│   └── schemas.py                    # Pydantic models + LoginRequest/LoginResponse
├── services/
│   ├── ia_clinica.py                 # Síntese clínica (OpenAI GPT-4.1 ou Gemini)
│   └── transcricao.py               # Transcrição de áudio (OpenAI gpt-4o-mini-transcribe)
└── prompts/
    └── abordagens.py                 # 14 abordagens (inclui Análise do Comportamento)
```

## Segurança

### Autenticação
- **Backend**: JWT (python-jose) — rota `POST /auth/login`, endpoints protegidos via `Authorization: Bearer <token>`
- **Flutter**: Autentica automaticamente no backend ao iniciar (`main.dart: _inicializarBackendAuth()`)
- Token JWT armazenado em `static ApiClient.authToken`, enviado em todas as chamadas API

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

## Problemas Conhecidos

### Pendentes
1. **VS Build Tools incompleto**: Windows Desktop workload não instalado — `flutter run -d windows` falha
2. **Web debug service**: `flutter run -d chrome` falha com timeout no WebkitDebugger (Chrome 150 + Flutter 3.44). Workaround: `flutter build web` + `python -m http.server 5000`
3. **Sem migração de schema Hive**: mudanças em modelos quebram dados existentes (schema v3 cobre read-rewrite)
4. **Chave OpenAI exposta no `.env`**: risco de vazamento (não commitada, mas presente em disco)

### Resolvidos
- ~~Segurança: zero autenticação~~ ✅ JWT backend + criptografia AES local
- ~~State management: setState (40x)~~ ✅ 0 setState — 100% Riverpod
- ~~Arquivos enormes~~ ✅ sessao_form_page 2166→2090, campos clínicos extraídos
- ~~Abordagens incompletas~~ ✅ 14 abordagens (inclui Análise do Comportamento)
- ~~Campos ausentes~~ ✅ email, dataNascimento, dataAtualizacao, transcricaoRevisada
- ~~Exportação limitada~~ ✅ 5 tipos de PDF
- ~~Código morto~~ ✅ CampoClinico removido do backend

## Comandos

### App Flutter
- `flutter analyze` — análise estática (0 errors, ~17 warnings/infos cosméticos)
- `flutter test` — 68 testes
- `dart run build_runner build` — gerar adapters Hive
- `flutter build web` — build de produção

### Web (Chrome)
- ⚠️ `flutter run -d chrome` atualmente quebrado (debug service timeout)
- Alternativa: `flutter build web` + `python -m http.server 5000` no diretório `build/web`
- **Sempre use porta fixa 5000** para não perder dados do Hive/localStorage

### Backend
- `cd backend; python -m uvicorn main:app --reload` — iniciar servidor
- `cd backend; pip install -r requirements.txt` — instalar dependências
- Testar auth: `curl -X POST http://localhost:8000/auth/login -H "Content-Type: application/json" -d '{"username":"admin","password":"admin"}'`

## Observações
- Projeto acadêmico (TCC), não pronto para venda
- Diferencial: `ConfiguracaoAbordagemClinica` adapta o prontuário à abordagem do profissional
- Síntese clínica: OpenAI GPT-4.1 com response_format json_object + temperature 0.3
- Transcrição: OpenAI gpt-4o-mini-transcribe
- Fallback disponível: Google Gemini 2.0 Flash (trocar `IA_MODEL_PROVIDER=gemini`)
- PerfilProfissionalFormPage widget test: bug de `ListView` + `SliverChildListDelegate` + texto longo (>140 chars) no Card. Solução: `tester.view.physicalSize` ampliado
- Estrutura LGPD conforme documento `Arquitetura LGPD do MentAll.txt`
