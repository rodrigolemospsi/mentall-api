# MentAll PRO 2.1.0 — Google Calendar

**Versão:** 2.1.0+70 · **Data:** 02/11/2026 · **Plataforma:** Android (APK/AAB)

## Novidades

- **Google Calendar disponível** para todos os profissionais (a integração ficou oculta nos builds
  de release anteriores até a **verificação OAuth do Google ser aprovada em 01/11/2026**).
- Conectar a conta Google em **Configurações → Integrações → Google Calendar** e escolher o
  calendário; o app cria, atualiza e exclui os eventos dos compromissos (sem convidados e sem nome
  de paciente por padrão).
- Eventos já criados no Google **não** são apagados ao desconectar.
- Sincronização manual (“Sincronizar agora”) e ao criar/editar/cancelar/reagendar compromissos.
- Demais melhorias das versões 2.0.7–2.0.9: anamnese com criptografia ponta-a-ponta, contrato com
  assinatura eletrônica e evidências, documentos fiscais (declaração, comprovante, informe e arquivo
  do Receita Saúde em lote).

## Requisitos / observações

- Necessário conta Google no aparelho e aceitar os escopos
  `calendar.events.owned` + `calendar.calendarlist.readonly`.
- Os eventos são gravados no calendário escolhido pelo profissional; o app não lê os demais eventos.
- Tokens do Google ficam **somente no aparelho** (sem backend de agenda).
- Quem estiver no build **debugsign** deve atualizar com `MentAllPRO-v2.1.0-debugsign.apk` (mesma
  assinatura). O build de produção (`-release.apk`, upload key) exige migração única com
  backup/restauração (ver `docs/google_calendar_2a.md` §8).

## Artefatos

| Arquivo | SHA-256 |
|---|---|
| `MentAllPRO-v2.1.0-release.apk` (upload key) | `9256b756b03b6597cf5e113158d2864ddcf99a60987f5b4693026bc39198bcd5` |
| `MentAllPRO-v2.1.0-debugsign.apk` (debug key) | `a8afa855c47c0b5d47d98fd41202c89b4069055e630d676d30aa44dc62bf80f9` |
| `MentAllPRO-v2.1.0.aab` (Play) | `12182ddd650fefb3baa8f71e842d262c133dd743633db49a00c5a8bf241cdb45` |

## Pendências desta versão

- Concluir o teste do fluxo OAuth completo na assinatura de release (consentimento, criar/editar/
  excluir evento, desconectar) numa conta Google válida.
- Atualizar o formulário **Data Safety** da Play Store com “Calendar events” no mesmo envio
  (detalhes em `docs/lojas/DATA_SAFETY_E_APP_PRIVACY.md` §2.2/§6).
- Cadastrar o SHA-1 do **Play App Signing** quando publicar na Play Store.
