# Google Calendar — Fase 2A (OAuth no aparelho)

**Versão:** 1.0 · **Data:** 21/10/2026 · **Status:** implementado e conectado em Testing.
**Escopo:** psicólogo individual, agenda local-first, Android primeiro. Sem backend de agenda e sem
teleconsulta.

## 1. Decisão e arquitetura

- **OAuth no aparelho**, via `google_sign_in` + `googleapis`, com a ponte
  `extension_google_sign_in_as_googleapis_auth`. O token fica no aparelho; **não há token no backend**.
- O app escreve no **calendário escolhido pelo profissional**. A agenda local continua sendo a fonte
  de verdade; o Google é uma cópia externa.
- **Sem sincronização com o app fechado**: o sync ocorre ao criar/editar/excluir/cancelar/reagendar
  e no botão “Sincronizar agora”. **Não há sync automático ao abrir a Agenda** (fica para a etapa seguinte).

## 2. Configuração Google Cloud

| Item | Valor |
|---|---|
| Projeto | `938362319829` |
| Android client | package `com.mentall.app` + SHA-1 de debug `B6:38:41:F4:A9:1C:85:3A:09:0D:08:1B:5F:0A:73:E2:A4:94:21:F7`; **não é usado no fluxo** (o Android reconhece por package + SHA-1) |
| Web client | usado como **`serverClientId`** no `GoogleSignIn.initialize` |
| Scopes | `https://www.googleapis.com/auth/calendar.events.owned` e `https://www.googleapis.com/auth/calendar.calendarlist.readonly` |
| Consent screen | **External / Testing**, com o Gmail do dono como **test user** |
| Client IDs | em `lib/config/google_calendar_config.dart`; podem ser trocados por `--dart-define` (`GOOGLE_SERVER_CLIENT_ID` / `GOOGLE_ANDROID_CLIENT_ID`) |

> O login **funcionou no aparelho** em Testing. O erro “Acesso bloqueado: o app MentAll PRO não
> concluiu o processo de verificação do Google” era o **portão de verificação** (app em produção/sem
> verificação ou conta fora dos test users), não bug do app.

## 3. Comportamento e privacidade

- O app cria/atualiza/exclui eventos **apenas no calendário do profissional**.
- **Não envia `attendees`**; usa `sendUpdates: 'none'`. **O calendário do paciente não muda** e ele
  não recebe convite.
- Resumo: **“Sessão”** para sessões; **título** para evento geral. **Sem nome, e-mail, telefone ou
  conteúdo clínico do paciente por padrão** (se o profissional digitar um nome no título do evento
  geral, esse texto vai para o Google).
- `location` recebe a **sala/local**; descrição fica vazia.
- `extendedProperties.private` recebe `mentall_compromisso_id` para reconciliar.
- Desconectar **não apaga** os eventos já criados no Google; o profissional pode removê-los lá.
- Google é subprocessador/transferência internacional. A integração é **opcional** e só ocorre após
  o profissional conectar a conta.

## 4. Regras de sincronização

- Criar → `events.insert`; editar → `events.update`; excluir/cancelar → `events.delete`.
- **404/410** na edição → recria o evento; na exclusão → ignora e limpa o vínculo local.
- Falha de rede/API **não bloqueia** o salvamento local; o erro aparece na tela de integração.
- Recorrência: cada ocorrência é um evento; hoje o sync acompanha **todas as ocorrências geradas**
  (até 52 ocorrências/180 dias). Limitar a janela a 90 dias fica pendente.
- Cancelar remove o evento do Google; “Reagendar” recria/atualiza quando necessário.
- Sem sync com o app fechado; sem importação de eventos ocupados do Google (etapa seguinte).

## 5. Modelo, backup e LGPD

- `Compromisso` ganhou `googleEventId`, `googleCalendarId` e `googleSyncedAt` (Hive 22–24), com
  defaults para registros antigos.
- Backup exporta/importa esses campos.
- Preferências: `google_calendar_ativo`, `google_calendar_id`,
  `google_calendar_auto_sync` e `google_calendar_ultimo_sync` no `app_config`.
- LGPD atualizada em `docs/lgpd/03,04,05,06,09` e `_base_factual.md`; textos de
  privacidade/termos no app.

## 6. Arquivos principais

- `lib/config/google_calendar_config.dart`
- `lib/services/google_calendar_api.dart` (interface e modelos)
- `lib/services/google_calendar_google_api.dart` (Google real)
- `lib/services/google_calendar_service.dart` (sync)
- `lib/screens/google_calendar_page.dart`
- `lib/screens/configuracoes_page.dart` (Integrações)
- `lib/providers/service_providers.dart`
- `lib/screens/agenda_page.dart` e `home_page.dart` (gatilhos)
- `lib/models/compromisso.dart` (+ `.g.dart`)
- `lib/services/configuracoes_service.dart` e `backup_service.dart`

## 7. Verificação

- `flutter analyze --no-pub`: **No issues found!**
- `flutter test --no-pub`: **314/314**.
- `flutter build apk --release`: OK (~48 s).
- APK de teste: `MentAllPRO-v1.0.52.apk` (`1.0.52+53`, ~77 MB), sha256
  `5c5736e35c3088f05e17a5f1d90d1b1e101d8d733de0c9a280eefbc2c11bec8d` (debug signing).
- Testes novos: `google_calendar_service_test` (6) e `google_calendar_page_test` (1).

## 8. Verificação do Google (sair de Testing)

**Causa do bloqueio:** o app usa scopes **sensitive** (`calendar.events.owned`,
`calendar.calendarlist.readonly`). Em **Testing**, só os test users conseguem autorizar. Em
**Production**, o Google exige a verificação dos scopes.

**Prazo oficial:** **3–5 dias úteis** após a submissão completa
([Sensitive scope verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification)).
Na prática, reserve **1–3 semanas**, incluindo preparação e possíveis idas e voltas.

**Pré-requisitos:**
1. Homepage pública com descrição do app e links para política de privacidade e termos **no mesmo
   domínio**.
2. Política de privacidade pública explicando como o app usa dados do Google.
3. Domínio verificado no **Google Search Console**.
4. Branding correto na tela de consentimento (nome, logo, e-mail de suporte).
5. **Vídeo em inglês**, não listado no YouTube, mostrando o fluxo de autorização e o uso do Calendar.
6. Justificativa de cada scope e por que um escopo mais estreito não serve.
7. Submissão no **Verification Center** do Google Cloud.

**Bloqueio atual:** `mentallpro.com.br` está com a página **“Em construção!”**. Sem homepage e
política públicas e funcionais, a verificação não passa. Isso é conteúdo/tempo, não dinheiro.

> Os escopos usados são **sensitive**, não **restricted**; portanto não exigem o security assessment
> (CASA). A verificação é gratuita.

## 9. Custos e cotas

- API **gratuita** no uso normal: **10.000 req/min por projeto**, **600 req/min por usuário** e
  **1.000.000 req/dia por projeto**.
- Abaixo do limite diário não há cobrança; acima disso o Google **planeja cobrar em 2026** (detalhes
  ainda não publicados).
- Verificação **gratuita**; não há custo por evento criado.
- O volume do MentAll (dezenas de milhares/mês) fica muito abaixo das cotas.

## 10. Troubleshooting

| Sintoma | Causa provável | Ação |
|---|---|---|
| “Acesso bloqueado: app não concluiu verificação” | App em Production/sem verificação ou conta fora dos test users | Voltar para **Testing** e adicionar o Gmail; ou concluir a verificação |
| `clientConfigurationError` | SHA-1/package errados | Conferir `com.mentall.app` + SHA-1 do APK instalado |
| Conecta, mas evento não aparece | Calendário escolhido diferente ou auto-sync desligado | Conferir seletor/“Sincronizar agora” |
| Evento com hora errada | Fuso do aparelho/calendário | Conferir fuso do Google Calendar; o app envia UTC |
| Evento duplicado | Evento apagado no Google e recriado | 404/410 recria de propósito; limpar duplicata manualmente |

## 11. Pendências

- Testar no aparelho o fluxo completo: criar/editar/excluir, evento geral e desconectar.
- Adicionar o SHA-1 do **keystore de release** (ou Play App Signing) e concluir a **verificação**.
- iOS adiado (bundle atual `com.example.prontuarioTcc`).
- Importar eventos ocupados do Google (conflitos) e sync ao abrir a Agenda — etapa seguinte.
- Limitar a sincronização de recorrência a uma janela de 90 dias.
- **2B (confirmação global pelo wuzapi)** depois da 2A; em produção ainda depende dos secrets do
  wuzapi no Fly.
- Nada foi commitado.

## 12. Referências

- [Calendar API — usage limits](https://developers.google.com/workspace/calendar/api/guides/quota)
- [Sensitive scope verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification)
- [Google Sign-In for Android](https://pub.dev/packages/google_sign_in_android)
- [googleapis](https://pub.dev/packages/googleapis) · [bridge](https://pub.dev/packages/extension_google_sign_in_as_googleapis_auth)
