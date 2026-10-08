# Plano — WhatsApp (wuzapi) por profissional

## Objetivo
Cada profissional conecta o próprio WhatsApp dentro do app (por **código de
pareamento**, com **QR** como alternativa) e vê o **status** (conectado /
desconectado). Os lembretes automáticos voltam a funcionar — hoje quebrados
porque o backend de produção não tem `WUZAPI_BASE_URL` configurado.

## Decisões de arquitetura
- Backend no Fly (`gru`); **wuzapi em VPS dedicada no Brasil**, 24/7.
- **Uma instância por profissional** (tabela `wuzapi_instancias`, chave `owner_id`).
- Segredos só no backend; o **app nunca fala com o wuzapi**.
- Assinar **apenas `ReadReceipt`** (entrega/leitura) — o conteúdo das conversas
  dos pacientes não chega ao backend.
- Subdomínio `wuzapi.mentallpro.com.br`.
- Risco de ban do WhatsApp não-oficial: **aceito** nesta fase.

## Contrato de API (backend, JWT, escopado por owner)
- `GET  /wuzapi/status`        -> `{sucesso, configurado, conectado, logado, numero, erro}`
- `POST /wuzapi/parear`        -> `{sucesso, codigo, erro}`  (body `{telefone}`)
- `GET  /wuzapi/qr`            -> `{sucesso, qr_code, erro}` (data URI base64)
- `POST /wuzapi/desconectar`   -> `{sucesso, mensagem, erro}` (body `{logout}`)
- `POST /wuzapi/testar`        -> `{sucesso, mensagem, erro}` (body `{telefone}`)

## Fase 1 — Backend (agora, testável contra o wuzapi local)
- `backend/services/wuzapi_admin.py`: `garantir_instancia`, `status`,
  `parear`, `qr`, `desconectar`, `testar`. Fail-closed sem admin token/base URL.
- `backend/models/schemas.py`: request/response de pareamento, QR e desconexão.
- `backend/main.py`: endpoints; telefone mascarado em log; rate limit.
- `/wuzapi/config` mantido por compatibilidade (deprecado).

## Fase 2 — App (agora)
- `lib/services/wuzapi_service.dart` (chama o backend via `ApiClient`).
- `lib/screens/whatsapp_conexao_page.dart`: status; conectar (código de
  pareamento + polling); QR alternativo; teste; desconectar.
- Entrada em `lib/screens/configuracoes_page.dart` > "Agenda e lembretes".

## Fase 3 — Infra (quando a VPS for contratada)
- VPS BR (1-2 vCPU / 1-2 GB / SSD / backup), Docker + wuzapi, volume da sessão,
  Caddy/TLS no `wuzapi.mentallpro.com.br`, firewall só para o backend.
- DNS A `wuzapi` -> IP da VPS; secrets no Fly: `WUZAPI_BASE_URL`,
  `WUZAPI_ADMIN_TOKEN`.

## Riscos e mitigações
| Risco | Impacto | Mitigação |
|---|---|---|
| Ban do WhatsApp não-oficial | Alto | Aceito; caminho de escala = WhatsApp Business API |
| Perder o disco da VPS (sessão) | Médio | Backup automático; profissional re-pareia |
| API de admin exposta | Alto | Firewall; só o backend alcança o wuzapi |
| Conta nova não envia (owner órfão) | Médio | `garantir_instancia` cria sob demanda; a tela mostra e permite reconectar |

## Critérios de aceite
- Profissional pareia o próprio número pelo app (mesmo celular, via código).
- Lembrete agendado é enviado; app mostra entregue/lido.
- Trocar de conta não deixa mudo em silêncio: a tela mostra "Desconectado".
- Nenhum token no app; telefone mascarado em log.
- `flutter analyze` limpo e suítes Flutter/backend verdes.

## Questões em aberto
- Mensagem de teste: para o próprio número conectado (padrão adotado).
- Confirmar hostname `wuzapi.mentallpro.com.br` na implantação.
