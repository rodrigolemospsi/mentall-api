# Avisos de e-mail (novo e-mail + SLA comercial)

> Atualizado em 26/10/2026. Memória geral: `MEMORIA_ALERTAS_EMAIL_E_CUSTOS.md`.

## 1. Aviso imediato de novo e-mail (somente `contato@`)

**Regra atual:** apenas `contato@mentallpro.com.br` gera aviso. As outras caixas
(`rodrigo@`, `suporte@`, `anderson@`) são monitoradas, mas ficam em silêncio.
Configurável em `EMAIL_ALERTA_SOMENTE_CAIXAS`.

A cada **90 s** (`EMAIL_NOVO_INTERVALO_SEGUNDOS`) o backend consulta as caixas via
IMAP (somente leitura de cabeçalhos) e compara o UID mais alto com o último visto.
Ao chegar mensagem nova:

1. **WhatsApp:** sai pelo número **19** (instância WuzAPI exclusiva de avisos) e
   chega no número **75** (`EMAIL_ALERTA_WHATSAPP`). A instância dos lembretes
   (número 75) não é alterada.
2. **Web Push** no PWA do painel (se algum dispositivo estiver inscrito).
3. **E-mail de aviso** para `EMAIL_NOVO_ALERTA_EMAIL` (opcional).

A mensagem traz **caixa, remetente, assunto e data**, com link para o
**webmail** (`https://mail.mentallpro.com.br/webmail/`), nunca para o painel.
O corpo nunca é lido (fetch usa `BODY.PEEK[HEADER.FIELDS ...]`).

Estado por caixa em `email_alertas_estado` (UIDVALIDITY + último UID), no banco
persistente do volume `/data` do Fly. A primeira execução cria a linha de base
sem notificar o histórico.

### Conectar/verificar o número 19 (remetente dos avisos)

Página: **`/admin/email/avisos/wpp19`** (papel admin). Ela mostra o status e,
se necessário, um QR Code para parear o WhatsApp do número 19
(WhatsApp → Aparelhos conectados → Conectar aparelho).

- O QR é servido por rota same-origin (`/admin/email/avisos/wpp19/qr.png`),
  porque o CSP do painel bloqueia imagens `data:`.
- Alternativa: botão **“Prefiro usar código de pareamento”** gera um código de
  8 dígitos para digitar no celular do 19.
- Token da instância de avisos: `alerta:wuzapi_token` em `email_alertas_estado`
  ou `ALERTA_WUZAPI_TOKEN` no ambiente.
- Número do remetente: `EMAIL_ALERTA_REMETENTE_NUMERO=5519981887176`.

## 2. Web Push no painel

- Chaves VAPID nos secrets do Fly (`VAPID_PRIVATE_KEY_B64`, `VAPID_PUBLIC_KEY`,
  `VAPID_SUBJECT`).
- Ativação: `/admin/email` → seção “Aviso imediato de novo e-mail” →
  **Ativar notificações neste dispositivo** (repetir por dispositivo).
- No iPhone, o painel precisa estar instalado na tela de início.
- Inscrições na tabela `push_subscriptions`.

## 3. SLA de e-mail em horário comercial

O SLA de primeira resposta e o backlog de “sem resposta há +24h” contam apenas
horas dentro da janela de atendimento (America/Sao_Paulo):

- **Segunda a sexta:** 8h–18h.
- **Sábado:** 8h–13h.
- **Domingo:** fechado.
- Fora da janela (noite, madrugada, sábado à tarde e domingo) o relógio para.

SLA por caixa (em **horas úteis**): `contato@` 24h, `suporte@` 4h,
`financeiro@` 24h. 24h úteis ≈ 3 dias úteis; 4h úteis = meio dia útil.
O “Tempo médio de resposta” do painel também é em minutos úteis.

**Ignorados nas métricas** (continuam na caixa, mas não geram pendência):
- remetentes automáticos: DMARC, postmaster, mailer-daemon, no-reply, bounce,
  automated;
- cabeçalhos `Auto-Submitted` ou `Precedence: bulk/list/junk`;
- e-mails internos `@mentallpro.com.br`.

Configuração: `MAIL_SLA_INICIO_HORA=8`, `MAIL_SLA_FIM_HORA=18`,
`MAIL_SLA_SABADO_INICIO_HORA=8`, `MAIL_SLA_SABADO_FIM_HORA=13`.

## 4. Onde ver no painel

- `/admin/email`: cards “Fora do SLA”, “Sem resposta há +24h”, tempo médio útil,
  tabelas por caixa/endereço e a seção de avisos.
- Saúde do painel (`/admin`): “X e-mail(s) fora do SLA (horário comercial)” ou
  “ok, sem pendências”.
- Alerta de SLA por WhatsApp (legado `email_alertas`): resumo quando há
  violações, com cooldown de 6h.

## 5. Variáveis de ambiente (nomes)

```
EMAIL_ALERTA_SOMENTE_CAIXAS=contato@mentallpro.com.br
EMAIL_ALERTA_WHATSAPP=5575992298347
EMAIL_ALERTA_WHATSAPP_POR_CAIXA={"contato@mentallpro.com.br":"5575992298347"}
EMAIL_ALERTA_REMETENTE_NUMERO=5519981887176
EMAIL_NOVO_INTERVALO_SEGUNDOS=90
MAIL_WEBMAIL_URL=https://mail.mentallpro.com.br/webmail/
EMAIL_NOVO_ALERTA_EMAIL=...          # opcional
MAIL_SLA_INICIO_HORA=8
MAIL_SLA_FIM_HORA=18
MAIL_SLA_SABADO_INICIO_HORA=8
MAIL_SLA_SABADO_FIM_HORA=13
VAPID_PRIVATE_KEY_B64=...            # secret
VAPID_PUBLIC_KEY=...                 # secret
VAPID_SUBJECT=mailto:dpo@mentallpro.com.br
```

## 6. Arquivos

- `services/email_novos.py` — polling IMAP, formatação e envio pelos canais.
- `services/push.py` — inscrições e envio Web Push.
- `services/wuzapi_alertas.py` — instância de avisos (número 19), QR/código e envio.
- `services/email_metricas.py` — janela comercial, filtro de automáticos/internos.
- `services/email_alertas.py`, `services/saude.py` — alertas e status.
- `main.py` — rotas `/admin/email/avisos/*`, `/admin/push/*` e lifespan.
- `admin_ui.py` — seção de avisos, página de conexão e rótulos.
- `static/admin/sw.js` e `static/admin/painel.js` — service worker e ativação.
