# TODO — WhatsApp (wuzapi) por profissional

## Fase 1 — Backend
- [ ] Testes RED de `services/wuzapi_admin.py` (provisionar, parear, status,
      desconectar, fail-closed sem admin token, re-provisionar em conta nova).
- [ ] Implementar `backend/services/wuzapi_admin.py`.
- [ ] Schemas + endpoints `/wuzapi/*` em `backend/main.py`.
- [ ] `tests/run_isolated.py` verde; `flutter analyze` (app) sem regressão.

## Fase 2 — App
- [ ] `lib/services/wuzapi_service.dart` + testes.
- [ ] `lib/screens/whatsapp_conexao_page.dart` (status, codigo, QR, teste, desconectar).
- [ ] Entrada em Configurações > "Agenda e lembretes".
- [ ] Widget tests; `flutter test` verde.

## Fase 3 — Infra (quando a VPS for contratada)
- [ ] Provisionar VPS BR + wuzapi + volume + TLS `wuzapi.mentallpro.com.br`.
- [ ] Secrets no Fly: `WUZAPI_BASE_URL`, `WUZAPI_ADMIN_TOKEN`.
- [ ] Verificação ponta a ponta no aparelho (parear + lembrete real).
