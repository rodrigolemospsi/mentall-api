# MentAll — Prontuário Clínico com IA

## Projeto
App Flutter para prontuário clínico adaptado à abordagem terapêutica do profissional (TCC, Psicanálise, ACT, DBT, etc.), com assistência de IA para transcrição e análise de sessões.

## Stack
- **Framework:** Flutter (SDK ^3.12.2)
- **Linguagem:** Dart / Python (backend)
- **Estado:** `setState` puro (sem Riverpod/BLoC/Provider ainda)
- **Banco local:** Hive CE (hive_ce + hive_ce_flutter + hive_ce_generator)
- **Áudio:** record + audioplayers + path_provider
- **Geração de código:** build_runner + hive_ce_generator
- **Backend:** Python FastAPI (porta 8000), OpenAI GPT-4.1 (síntese) + gpt-4o-mini-transcribe (transcrição)

## Estrutura

### Flutter App (`lib/`)
```
lib/
├── main.dart                         # Entry point, Hive init, tema Material 3
├── hive_registrar.g.dart             # Generated
├── config/
│   └── configuracao_abordagem_clinica.dart  # 11 templates de abordagens
├── models/
│   ├── paciente.dart / .g.dart       # Hive typeId: 1
│   ├── perfil_profissional.dart / .g.dart # Hive typeId: 3
│   ├── sessao.dart / .g.dart         # Hive typeId: 2 (29 campos)
│   └── prontuario.dart / .g.dart     # Hive typeId: 0 — NÃO USADO (dead code)
├── screens/
│   ├── app_start_page.dart           # Roteamento inicial
│   ├── home_page.dart                # Lista de pacientes (790 linhas)
│   ├── paciente_detail_page.dart     # Detalhes + sessões (1135 linhas)
│   ├── sessao_form_page.dart         # Formulário de sessão (2253 linhas!)
│   ├── backup_restore_page.dart      # Export/import JSON (conditional import)
│   ├── backup_restore_page_web.dart  # Web: Blob download + FileUpload
│   ├── backup_restore_page_stub.dart # Stub não-web (no-op)
│   └── perfil_profissional_form_page.dart
├── services/
│   ├── paciente_service.dart
│   ├── perfil_profissional_service.dart
│   ├── sessao_service.dart
│   ├── backup_service.dart           # Export/import JSON de todas as boxes Hive
│   ├── transcricao_relato_service.dart  # Conectado ao backend OpenAI
│   ├── ia_clinica_service.dart          # Conectado ao backend GPT-4.1
│   ├── audio_relato_service.dart
│   └── status_clinico_sessao_service.dart
├── widgets/
│   └── ... (componentes reutilizáveis)
```

### Backend Python (`backend/`)
```
backend/
├── main.py                           # FastAPI app (porta 8000), CORS, rotas
├── .env                              # Chaves de API + config do modelo
├── .env.example                      # Template com variáveis documentadas
├── requirements.txt                  # fastapi, uvicorn, openai, google-genai, etc.
├── models/
│   └── schemas.py                    # Pydantic models (SinteseRequest, SinteseResponse, etc.)
├── services/
│   ├── ia_clinica.py                 # Síntese clínica (OpenAI GPT-4.1 ou Gemini)
│   └── transcricao.py               # Transcrição de áudio (OpenAI gpt-4o-mini-transcribe)
└── prompts/
    └── abordagens.py                 # PROMPT_UNIVERSAL + PROMPTS_ABORDAGEM (13 abordagens)
```

## Backend — Configuração

### Variáveis de ambiente (`.env`)
```
OPENAI_API_KEY=sk-...               # Para transcrição e síntese (padrão)
GEMINI_API_KEY=...                   # Fallback se IA_MODEL_PROVIDER=gemini
IA_MODEL_PROVIDER=openai             # "openai" (padrão) ou "gemini"
IA_MODEL=gpt-4.1                     # Modelo: gpt-4.1, gpt-4o, gemini-2.0-flash, etc.
HOST=0.0.0.0
PORT=8000
```

### Prompt da IA (2 camadas)
1. **`PROMPT_UNIVERSAL`** — regras éticas, linguagem prudente, formato de 8 pontos (vale para todas as abordagens)
2. **`PROMPTS_ABORDAGEM`** — instruções específicas por abordagem (observar / sugerir / evitar)

Montagem final: `UNIVERSAL + ESPECÍFICO + DADOS SESSÃO + MATERIAL CLÍNICO + INSTRUÇÕES JSON`

## Problemas Conhecidos (Pendências)
1. **Segurança:** zero autenticação, zero criptografia — dados clínicos em texto puro
2. **Testes:** 52 testes (modelos + serviços + status clínico)
3. ~~**Código morto:** `novo_prontuario_page.dart` e `models/prontuario.dart` (typeId 0)~~ ✅ Removido
4. **Arquivos enormes:** `sessao_form_page.dart` (2253 linhas), `paciente_detail_page.dart` (1135)
5. **State management:** `setState` puro, sem reatividade eficiente
6. ~~**Erros engolidos:** `catch (_)` sem logging por toda parte~~ ✅ Corrigido (`Log` + captura nomeada em 11 pontos)
7. ~~**IA:** stubs não conectadas a API real~~ ✅ Conectado (GPT-4.1 + gpt-4o-mini-transcribe)
8. ~~**Backup/Sync:** zero — risco de perda total de dados~~ ✅ Implementado (`BackupService` + UI em `backup_restore_page`)
9. ~~**Deprecações:** 34 warnings de APIs obsoletas no `flutter analyze`~~ ✅ Corrigido (3 info restantes)
10. ~~**Branding:** `pubspec.yaml` diz "A new Flutter project."~~ ✅ Descrição atualizada
11. **Sem migração de schema Hive:** mudanças em modelos quebram dados existentes
12. **`flutter analyze`:** 3 info `use_build_context_synchronously` (não críticos)
13. **Chave OpenAI exposta no `.env`:** risco de vazamento (não commitada, mas presente em disco)
14. **Web: perda de dados Hive:** `flutter run -d chrome` sorteia porta aleatória a cada execução; `localStorage` é isolado por porta. Sempre usar `--web-port 5000`. IndexedDB não soluciona (mesmo isolamento por origem + `read()` síncrono do Hive)

## Comandos

### App Flutter
- `flutter analyze` — análise estática (0 warnings)
- `flutter test` — 52 testes
- `dart run build_runner build` — gerar adapters Hive
- `flutter build [apk|ios|web|windows|macos|linux]`

### Web (Chrome)
- `flutter run -d chrome --web-port 5000` — **sempre use porta fixa** para não perder dados do Hive/localStorage
- `flutter build web` — build de produção (porta fixa = dados persistem)

### Backend
- `cd backend; python -m uvicorn main:app --reload` — iniciar servidor
- `cd backend; pip install -r requirements.txt` — instalar dependências

## Observações
- Projeto acadêmico (TCC), não pronto para venda
- Diferencial: `ConfiguracaoAbordagemClinica` adapta o prontuário à abordagem do profissional
- Síntese clínica: OpenAI GPT-4.1 com response_format json_object + temperature 0.3
- Transcrição: OpenAI gpt-4o-mini-transcribe
- Fallback disponível: Google Gemini 2.0 Flash (trocar `IA_MODEL_PROVIDER=gemini`)
- Potencial comercial moderado-alto, mas precisa de 6–12 meses de engenharia
- Prioridades futuras: refatorar arquivos gigantes, segurança, state management
