# Memória: Alertas de e-mail, SLA comercial e painel de custos

> Criado em: 26/10/2026 · Última atualização: 26/10/2026
> Contexto: backend em produção no Fly (`mentall-api`), banco SQLite persistente no volume `/data`
> (não usa Turso em produção; o Turso é usado pelo backend local de desenvolvimento).

## 1. Correção crítica: ordem de carregamento do `.env`

**Sintoma:** backend subia em SQLite efêmero local ("Turso indisponível") mesmo com credenciais válidas.
**Causa:** `services/db.py` lia `TURSO_*` no import, mas `main.py` chamava `load_dotenv()` depois dos imports.
**Correção (já em produção e local):**
- `main.py`: `load_dotenv()` movido para **antes** dos imports de `admin_ui`/`services.*`.
- `services/db.py`: credenciais Turso lidas em tempo de execução (`_config_turso()` / `_allow_sqlite_fallback()`), com retry real.
**Arquivos:** `backend/main.py`, `backend/services/db.py`.

## 2. Painel de custos (Fase 1) — em produção

- Página: **`/admin/custos`** (papéis `admin` e `financeiro`), link "Custos" no menu do painel.
- Mede: custo de IA por tokens/áudio (estimativa via tabela de preços), infra **Magalu Cloud** via
  Consumption API (valor faturado real), custos fixos cadastráveis e orçamento mensal.
- Unit economics: preço do plano, custo por profissional ativo, custo por transcrição, margem.
- Sync Magalu: automático no start e a cada **6 h** (thread), idempotente por dia, últimos 7 dias.
- Tabelas: `custos_uso`, `precos_provedor`, `custos_fixos`, `custos_sync_estado`.
- Instrumentação: `services/ia_clinica.py` (tokens de DeepSeek/OpenAI/Gemini) e
  `services/transcricao.py` (duração via verbose_json, com fallbacks).
- Env na Fly: `MAGALU_CONSUMPTION_API_KEY` (chave com escopo `tally-consumption-api`),
  `CUSTOS_ORCAMENTO_MENSAL_BRL=300`, `CUSTOS_PRECO_MENSAL_BRL=79.90`, `CUSTOS_CAMBIO_USD_BRL=5.40`.
- Validação em produção (26/10): sync Magalu ok, 7 registros, **R$ 12,57** (19–25/10).
- Doc: `backend/docs/PAINEL_CUSTOS.md`.

## 3. Aviso imediato de novo e-mail (só `contato@`)

- **Regra atual:** somente `contato@mentallpro.com.br` gera aviso
  (`EMAIL_ALERTA_SOMENTE_CAIXAS`). Demais caixas são monitoradas, mas silenciosas.
- **Remetente:** instância WuzAPI **exclusiva de avisos**, conectada ao número **19**
  (`mentall-alertas-email`, JID `5519981887176@s.whatsapp.net`). Não interfere na instância
  principal dos lembretes (número 75).
- **Destinatário:** **+55 75 99229-8347** (`EMAIL_ALERTA_WHATSAPP` + rota por caixa).
- **Canais:** WhatsApp (19 → 75), Web Push no PWA do painel e e-mail opcional
  (`EMAIL_NOVO_ALERTA_EMAIL`).
- **Mensagem:** caixa, remetente, assunto, data e link para o **webmail**
  (`https://mail.mentallpro.com.br/webmail/`), nunca link do painel.
- **Verificação:** IMAP a cada **90 s** (`EMAIL_NOVO_INTERVALO_SEGUNDOS`), estado por caixa em
  `email_alertas_estado` (UIDVALIDITY + último UID). Primeira execução cria baseline sem notificar.
- **Pareamento do 19:** página `/admin/email/avisos/wpp19` (admin), com QR servido por rota
  same-origin (`/admin/email/avisos/wpp19/qr.png` — o CSP bloqueia `data:` URI) e alternativa por
  código de pareamento. Token da instância de avisos fica em `email_alertas_estado`
  (`alerta:wuzapi_token`) e/ou `ALERTA_WUZAPI_TOKEN`.
- **Testes (26/10):** envio 19→75 ok; aviso completo ok (`whatsapp: true`); falha de número no
  formato de 13 dígitos resolvida com variante sem o 9º dígito.
- Doc: `backend/docs/AVISOS_EMAIL.md`.

## 4. SLA de e-mail em horário comercial

- **Janela contada (America/Sao_Paulo):** segunda a sexta **8h–18h**; sábado **8h–13h**;
  domingo fechado. Fora da janela o relógio do SLA para.
- **SLA por caixa (horas úteis):** `contato@` 24h, `suporte@` 4h, `financeiro@` 24h.
  (24h úteis ≈ 3 dias úteis; 4h úteis = meio dia útil.)
- "Tempo médio de resposta" passou a ser em **minutos úteis**.
- "Sem resposta há +24h" também usa **24 horas úteis**.
- **E-mails ignorados nas métricas:** automáticos (DMARC, postmaster, mailer-daemon, no-reply,
  bounce, `Auto-Submitted`, `Precedence: bulk/list/junk`) e internos `@mentallpro.com.br`.
  Continuam na caixa, mas não contam como pendência.
- Env: `MAIL_SLA_INICIO_HORA=8`, `MAIL_SLA_FIM_HORA=18`,
  `MAIL_SLA_SABADO_INICIO_HORA=8`, `MAIL_SLA_SABADO_FIM_HORA=13`.
- Validação em produção (26/10): **fora do SLA 0**, **sem resposta +24h 0**,
  saúde do e-mail **ok**, 2 automáticos ignorados.
- Arquivo principal: `backend/services/email_metricas.py`; mensagens em `backend/services/saude.py`
  e `backend/services/email_alertas.py`.

## 5. Infra e segredos (Fly, sem valores)

- App: `mentall-api` (região gru), domínio `mentall-api.fly.dev`, admin via Caddy em
  `admin.mentallpro.com.br` (VPS Magalu → Fly).
- Banco: SQLite persistente no volume `mentall_data` em `/data/mentall.db`
  (`SQLITE_PATH=/data/mentall.db`, `ALLOW_SQLITE_FALLBACK=false`).
- Secrets usados nesta entrega: `VAPID_PRIVATE_KEY_B64`, `VAPID_PUBLIC_KEY`, `VAPID_SUBJECT`,
  `MAIL_WEBMAIL_URL` (default no código), `EMAIL_ALERTA_WHATSAPP`,
  `EMAIL_ALERTA_WHATSAPP_POR_CAIXA`, `EMAIL_ALERTA_SOMENTE_CAIXAS`,
  `EMAIL_ALERTA_REMETENTE_NUMERO`, `MAGALU_CONSUMPTION_API_KEY`.
- WuzAPI: instância `mentall-alertas-email` (avisos, número 19) + instância `mentall-80d19e38`
  (lembretes, número 75). `WUZAPI_BASE_URL=https://wuzapi.mentallpro.com.br`.

## 6. Arquivos alterados/criados

**Criados**
- `backend/services/custos.py`
- `backend/services/email_novos.py`
- `backend/services/push.py`
- `backend/services/wuzapi_alertas.py`
- `backend/docs/PAINEL_CUSTOS.md`
- `backend/docs/AVISOS_EMAIL.md`
- `MEMORIA_ALERTAS_EMAIL_E_CUSTOS.md` (este arquivo)

**Alterados**
- `backend/main.py` (load_dotenv antes dos imports; rotas de custos/avisos/push; metering no app)
- `backend/services/db.py` (tabelas novas + leitura lazy do Turso)
- `backend/services/email_metricas.py` (janela comercial, filtro automáticos/internos)
- `backend/services/email_alertas.py`, `backend/services/saude.py` (textos)
- `backend/services/ia_clinica.py`, `backend/services/transcricao.py` (custo por uso)
- `backend/admin_ui.py` (página de custos, seção de avisos, página QR, rótulos)
- `backend/static/admin/painel.js`, `backend/static/admin/sw.js` (Web Push)
- `backend/requirements.txt` (`pywebpush`)

## 7. Pendências / próximos passos

1. **Commit** dessas mudanças (hoje estão sem commit; produção já roda o código).
2. Push do painel: nenhum dispositivo inscrito ainda — ativar em `/admin/email`.
3. SLA: avaliar se 24h úteis para `contato@` é o desejado (hoje equivale a ~3 dias úteis).
4. Conciliar preços de IA reais com a fatura (tabela `precos_provedor` é estimativa).
5. Custos: Fase 2 (PTAX diário, edição de preços na tela, importação de faturas, Costs API OpenAI)
   e Fase 3 (alertas de orçamento por e-mail/WhatsApp, projeção e picos).
