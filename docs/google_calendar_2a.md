# Google Calendar — Fase 2A (OAuth no aparelho)

**Versão:** 1.1 · **Data:** 30/10/2026 · **Status:** implementado, testado no aparelho (Android 15)
e com a **verificação de escopos submetida ao Google em 29/10/2026** — em análise (4–6 semanas).
**Escopo:** psicólogo individual, agenda local-first, Android primeiro. Sem backend de agenda e sem
teleconsulta.

> **Mudanças da v1.0 (21/10) para a v1.1 (30/10):** o app OAuth saiu de Testing e foi publicado em
> Production; a marca foi verificada e publicada; o fluxo foi testado ponta a ponta em aparelho
> (emulador Android 15) com consentimento real; a verificação de acesso aos dados foi submetida.
> As seções §2, §7, §8, §10 e §11 foram atualizadas. O código já está na `master` (commit
> `e33e47b`, linha 2.0.x, tag `v2.0.4`).

## 1. Decisão e arquitetura

- **OAuth no aparelho**, via `google_sign_in` + `googleapis`, com a ponte
  `extension_google_sign_in_as_googleapis_auth`. O token fica no aparelho; **não há token no backend**.
- O app escreve no **calendário escolhido pelo profissional**. A agenda local continua sendo a fonte
  de verdade; o Google é uma cópia externa.
- **Sem sincronização com o app fechado**: o sync ocorre ao criar/editar/excluir/cancelar/reagendar
  e no botão “Sincronizar agora”. **Não há sync automático ao abrir a Agenda** (fica para a etapa seguinte).
- Em produção, a autorização de escopos sensíveis fica restrita aos **test users** até a aprovação da
  verificação (§8). Por isso a integração é **opt-in e desligada por padrão**, e o primeiro envio é
  condicionado à aprovação (decisão 0.8 do checklist — ver memo de 30/10).

## 2. Configuração Google Cloud

| Item | Valor |
|---|---|
| Projeto | `psicologo online` — ID `psicologo-online-401021`, número `938362319829` |
| Android client | package `com.mentall.app` + SHA-1 de debug `B6:38:41:F4:A9:1C:85:3A:09:0D:08:1B:5F:0A:73:E2:A4:94:21:F7`; **não é usado no fluxo** (o Android reconhece por package + SHA-1). **Falta** o SHA-1 do upload key de release (`C2:E5:…:B5:62`) e o do Play App Signing — cadastrar **após a aprovação** (§8) |
| Web client | `938362319829-r59tc67bbc8h1m82ugtvkpqd8qj64a1d.apps.googleusercontent.com`, usado como **`serverClientId`** no `GoogleSignIn.initialize` |
| Scopes | `https://www.googleapis.com/auth/calendar.events.owned` e `https://www.googleapis.com/auth/calendar.calendarlist.readonly` |
| Consent screen | **External / Production** (publicado em 29/10/2026); marca **verificada e publicada**; verificação de acesso aos dados **em análise** |
| Test users (enquanto a análise corre) | `rodrigolemosba@gmail.com` e `mentallpro.demo@gmail.com` |
| Client IDs | em `lib/config/google_calendar_config.dart`; podem ser trocados por `--dart-define` (`GOOGLE_SERVER_CLIENT_ID` / `GOOGLE_ANDROID_CLIENT_ID`) |

> O login **funcionou no aparelho** em Testing e depois em Production com test user. O erro
> “Acesso bloqueado: o app MentAll PRO não concluiu o processo de verificação do Google” era o
> **portão de verificação** (app em produção/sem verificação ou conta fora dos test users), não bug
> do app.

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
- Data Safety/App Privacy: a linha do Calendar (dados de calendário — opcional) está nos rascunhos
  de `docs/lojas/DATA_SAFETY_E_APP_PRIVACY.md`; só entra na ficha se a integração estiver visível
  no build enviado (decisão 0.8).

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

- `flutter analyze --no-pub`: **No issues found!** (29/10/2026).
- `flutter test --no-pub`: **355/355** (29/10/2026; o número 314/314 era do commit inicial da 2A).
- Build atual: **APK/AAB 2.0.4+64** (28/10/2026), com upload key de produção e tag `v2.0.4`.
- **Teste no aparelho (29/10/2026):** emulador **Android 15 Google Play** (AVD `mentall-play`,
  GMS 26.42), consentimento real em inglês com os dois escopos, criação e verificação de evento no
  Google Calendar e exclusão sincronizada. Evidências daquele dia no workspace do agente:
  `prova_consentimento_gcal.png`, `prova_evento_no_gcal.png` e o vídeo de verificação
  (`Video_Verificacao_Google_Calendar_MentAll_PRO.mp4`).
- Atenção: **GMS antigo (Android 14, 23.18)** quebra o `authorizeScopes` do `google_sign_in` v7 no
  emulador — ver §10.
- Testes da integração: `google_calendar_service_test` (6) e `google_calendar_page_test` (1).

## 8. Verificação do Google (sair de Testing)

**Status: verificação submetida em 29/10/2026 — “O acesso aos dados do seu app está em análise”
(Trust & Safety do Google).** O app OAuth está em **Production** e a **marca foi verificada e
publicada**. Prazo informado pelo Google: **primeiro e-mail em 3–5 dias úteis** (≈ 3–5/11/2026) e
**análise de 4–6 semanas**.

**Pré-requisitos — todos concluídos:**

1. Homepage pública com descrição do app e links para Política e Termos **no mesmo domínio**
   (`mentallpro.com.br`, site v2 de 24/10).
2. Política de privacidade e Termos públicos em `/privacidade/` e `/termos/`.
3. Domínio verificado no **Google Search Console** (TXT `google-site-verification=QPJVFX5…` no apex
   — **não remover**).
4. Branding correto na tela de consentimento, **verificado e publicado**.
5. **Vídeo em inglês**, não listado no YouTube: <https://youtu.be/xLN8L-xkRR8> (3:08 — consentimento,
   criação e exclusão de evento).
6. Justificativa de cada escopo (992/1000) e link do vídeo salvos em **Acesso a dados**.
7. Questionário de verificação respondido e **submissão confirmada no Verification Center**.

**Enquanto a análise corre:**

- Monitorar `rodrigolemosba@gmail.com` e `contato@mentallpro.com.br`; o Trust & Safety pode pedir
  informações complementares — responder rápido evita pausa.
- **Não alterar branding** (nome, logo, links da tela de consentimento) durante a verificação.
- Não apagar os takes/vídeos locais até a aprovação (caso o Google peça reenvio).

**Depois da aprovação:**

1. Cadastrar o **SHA-1 do upload key de release** (`C2:E5:…:B5:62`) e o **SHA-1 do Play App Signing**
   no client Android `com.mentall.app` (Clientes → MentAll PRO → editar).
2. Testar o build de **release** com o Calendar (o fluxo OAuth precisa funcionar com a assinatura de
   release).
3. Atualizar o checklist de publicação (0.8/0.9) e o Data Safety/App Privacy (se o Calendar estiver
   visível no build enviado).
4. Se o app já estiver publicado, o aviso de “app não verificado” desaparece após a aprovação.

**Se for rejeitada:** ler o motivo no e-mail/Verification Center, corrigir e **re-submeter**; o vídeo
e os takes continuam válidos para reenvio.

> Os escopos usados são **sensitive**, não **restricted**; portanto não exigem o security assessment
> (CASA). A verificação é gratuita.
> Referência: [Sensitive scope verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification).

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
| “Acesso bloqueado: app não concluiu verificação” | Escopos sensíveis sem verificação aprovada, ou conta fora dos test users | Usar uma das 2 contas de teste até a aprovação (§8); não é bug do app |
| `clientConfigurationError` | SHA-1/package errados | Conferir `com.mentall.app` + SHA-1 do APK instalado (debug e, no futuro, release/Play App Signing) |
| `Failed to parse BeginGetCustomCredentialOption` / `No credential available` no emulador | GMS antigo (Android 14, 23.18) — `authorizeScopes` do google_sign_in v7 exige GMS novo | Usar imagem **Android 15 Google Play** (GMS ≥ 26), não Android 14 |
| `invalid_token` após reconectar na mesma conta | Cache de autorização inválido | Remover a Conta Google do aparelho e adicionar de novo (limpar dados do app não resolve) |
| Conecta, mas evento não aparece | Calendário escolhido diferente ou auto-sync desligado | Conferir seletor/“Sincronizar agora” |
| Evento com hora errada | Fuso do aparelho/calendário | Conferir fuso do Google Calendar; o app envia UTC |
| Evento duplicado | Evento apagado no Google e recriado | 404/410 recria de propósito; limpar duplicata manualmente |

## 11. Pendências

- [x] Testar no aparelho o fluxo completo: criar/editar/excluir, evento geral e desconectar
      (29/10/2026, emulador Android 15; consentimento, criação, verificação e exclusão).
- [x] Publicar o app OAuth em Production, verificar/publicar a marca e submeter a verificação de
      acesso aos dados (29/10/2026).
- [ ] **Após a aprovação:** cadastrar SHA-1 de release + Play App Signing no client Android e testar
      o build de release (§8).
- [ ] **Após a aprovação:** atualizar checklist 0.8/0.9 e Data Safety/App Privacy se o Calendar
      entrar no build enviado.
- [ ] **Decisão 0.8:** flag de build para esconder a integração caso o envio aconteça antes da
      aprovação (`--dart-define=GOOGLE_CALENDAR_VISIVEL=false` — ver memo `DECISOES_0.8_0.6_0.7_2026-10-30.md`).
- [ ] iOS: criar client OAuth de iOS, registrar URL scheme e testar **ou** esconder a integração no
      iOS (item 4.9 do checklist; depende da decisão 0.8). Bundle iOS ainda `com.example.prontuarioTcc`.
- [ ] Importar eventos ocupados do Google (conflitos) e sync ao abrir a Agenda — etapa seguinte.
- [ ] Limitar a sincronização de recorrência a uma janela de 90 dias.
- [ ] **2B (confirmação global pelo wuzapi)** depois da 2A; em produção ainda depende dos secrets do
      wuzapi no Fly.
- [x] Código commitado na `master` (commit `e33e47b`, linha 2.0.x, tag `v2.0.4`); este documento
      atualizado em 30/10/2026.

## 12. Referências

- [Calendar API — usage limits](https://developers.google.com/workspace/calendar/api/guides/quota)
- [Sensitive scope verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification)
- [Google Sign-In for Android](https://pub.dev/packages/google_sign_in_android)
- [googleapis](https://pub.dev/packages/googleapis) · [bridge](https://pub.dev/packages/extension_google_sign_in_as_googleapis_auth)
