"""Renderização server-side do painel do dono (Fase 3).

Sem JavaScript inline (só HTML/CSS + formulários) — mais simples e seguro.
Todos os valores dinâmicos passam por `html.escape` (anti-XSS).
"""
import html
import math
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

# O backend grava tudo em UTC (correto para armazenar); o painel exibe no
# horário de Brasília (o dono lê pelo PC no Brasil).
_FUSO_BRASILIA = ZoneInfo("America/Sao_Paulo")


def _esc(valor) -> str:
    return html.escape(str(valor if valor is not None else ""))


def _para_brasilia(iso) -> datetime | None:
    if not iso:
        return None
    try:
        dt = datetime.fromisoformat(str(iso))
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(_FUSO_BRASILIA)


def _quando(iso) -> str:
    dt = _para_brasilia(iso)
    if dt is None:
        return "-"
    return _esc(dt.strftime("%d/%m/%Y %H:%M"))


def _visto_ha(iso) -> str:
    """Tempo relativo desde o último heartbeat (contexto para online/offline)."""
    dt = _para_brasilia(iso)
    if dt is None:
        return "-"
    segundos = (datetime.now(timezone.utc) - dt.astimezone(timezone.utc)).total_seconds()
    if segundos < 90:
        return "agora"
    minutos = int(segundos // 60)
    if minutos < 60:
        return f"há {minutos} min"
    horas = minutos // 60
    if horas < 24:
        return f"há {horas} h"
    return f"há {horas // 24} d"


_ESTILO = """
  *{box-sizing:border-box}
  body{font-family:system-ui,-apple-system,sans-serif;margin:0;background:#F7F9FA;color:#1E293B}
  header{background:#8806CE;color:#fff;padding:14px 24px;display:flex;justify-content:space-between;align-items:center}
  header h1{font-size:18px;margin:0}
  header form{margin:0}
  header button{background:rgba(255,255,255,.18);color:#fff;border:0;border-radius:8px;padding:8px 14px;cursor:pointer}
  main{max-width:1000px;margin:0 auto;padding:24px}
  .cards{display:flex;gap:16px;flex-wrap:wrap;margin-bottom:24px}
  .card{background:#fff;border:1px solid #E2E8F0;border-radius:12px;padding:16px 20px;min-width:170px}
  .card .n{font-size:28px;font-weight:700;color:#8806CE}
  .card .l{font-size:13px;color:#475569}
  h2{font-size:15px;color:#475569;margin:24px 0 8px}
  table{width:100%;border-collapse:collapse;background:#fff;border:1px solid #E2E8F0;border-radius:12px;overflow:hidden}
  th,td{text-align:left;padding:10px 12px;border-bottom:1px solid #E2E8F0;font-size:14px}
  th{background:#F1F5F9;font-size:12px;color:#475569;text-transform:uppercase}
  .on{color:#2E7D32;font-weight:600}.off{color:#94A3B8}
  .pill{display:inline-block;background:#F1F5F9;border-radius:999px;padding:2px 10px;margin:2px 4px 2px 0;font-size:13px}
  form.busca{margin:8px 0 12px;display:flex;gap:8px}
  form.busca input{flex:1;padding:9px;border:1px solid #CBD5E1;border-radius:8px}
  form.busca button{background:#8806CE;color:#fff;border:0;border-radius:8px;padding:9px 16px;cursor:pointer}
  .pager{margin:16px 0;display:flex;gap:16px;align-items:center;font-size:14px}
  a{color:#8806CE}
  form.login{max-width:360px;margin:80px auto;background:#fff;border:1px solid #E2E8F0;border-radius:12px;padding:24px}
  form.login input{width:100%;padding:10px;margin:6px 0 14px;border:1px solid #CBD5E1;border-radius:8px}
  form.login button{width:100%;background:#8806CE;color:#fff;border:0;border-radius:8px;padding:11px;font-size:15px;cursor:pointer}
  .erro{color:#D32F2F;margin:0 0 12px}
"""


def pagina_login(erro: str = "") -> str:
    bloco_erro = f'<p class="erro">{_esc(erro)}</p>' if erro else ""
    return f"""<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>MentAll PRO — Painel</title><style>{_ESTILO}</style></head>
<body>
<form class="login" method="post" action="/admin/login">
  <h2 style="margin-top:0;color:#8806CE;font-size:20px">Painel do dono</h2>
  {bloco_erro}
  <label>E-mail</label>
  <input type="text" name="email" autocomplete="username" required>
  <label>Senha</label>
  <input type="password" name="senha" autocomplete="current-password" required>
  <button type="submit">Entrar</button>
</form>
</body></html>"""


def _linha_usuario(u: dict) -> str:
    estado = ('<span class="on">online</span>' if u["online"]
              else '<span class="off">offline</span>')
    aparelho = " ".join(p for p in [_esc(u.get("aparelho")), _esc(u.get("versao_app"))] if p)
    return (
        "<tr>"
        f"<td>{_esc(u.get('email'))}</td>"
        f"<td>{_esc(u.get('nome'))}</td>"
        f"<td>{_esc(u.get('plano'))}</td>"
        f"<td>{_esc(u.get('role'))}</td>"
        f"<td>{_esc(u.get('status'))}</td>"
        f"<td>{aparelho or '-'}</td>"
        f"<td>{estado}</td>"
        f"<td>{_visto_ha(u.get('ultimo_hb'))}</td>"
        f"<td>{_quando(u.get('ultimo_acesso_em'))}</td>"
        "</tr>"
    )


def pagina_dashboard(kpis: dict, pagina: dict, busca: str = "") -> str:
    aparelhos = "".join(
        f'<span class="pill">{_esc(p)}: {int(n)}</span>' for p, n in kpis["aparelhos"]
    ) or '<span class="off">nenhum</span>'
    eventos = "".join(
        f'<span class="pill">{_esc(t)}: {int(n)}</span>' for t, n in kpis["eventos_por_tipo"]
    ) or '<span class="off">nenhum</span>'

    linhas = "".join(_linha_usuario(u) for u in pagina["usuarios"]) or (
        '<tr><td colspan="9" class="off">Nenhum psicólogo encontrado.</td></tr>'
    )

    total = pagina["total"]
    limite = pagina["limite"]
    pag = pagina["pagina"]
    total_paginas = max(1, math.ceil(total / limite))
    busca_esc = _esc(busca)
    anterior = (f'<a href="/admin?pagina={pag - 1}&busca={busca_esc}">&larr; Anterior</a>'
                if pag > 1 else '<span class="off">&larr; Anterior</span>')
    proxima = (f'<a href="/admin?pagina={pag + 1}&busca={busca_esc}">Próxima &rarr;</a>'
               if pag < total_paginas else '<span class="off">Próxima &rarr;</span>')

    return f"""<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>MentAll PRO — Painel</title><style>{_ESTILO}</style></head>
<body>
<header>
  <h1>MentAll PRO — Painel</h1>
  <form method="post" action="/admin/logout"><button type="submit">Sair</button></form>
</header>
<main>
  <div class="cards">
    <div class="card"><div class="n">{int(kpis["total_usuarios"])}</div><div class="l">Psicólogos</div></div>
    <div class="card"><div class="n">{int(kpis["online_agora"])}</div><div class="l">Online agora</div></div>
    <div class="card"><div class="n">&mdash;</div><div class="l">Receita do mês</div></div>
  </div>

  <h2>Aparelhos</h2>
  <div>{aparelhos}</div>

  <h2>Uso por tipo de evento</h2>
  <div>{eventos}</div>

  <h2>Psicólogos ({total})</h2>
  <form class="busca" method="get" action="/admin">
    <input type="text" name="busca" placeholder="Buscar por e-mail ou nome" value="{busca_esc}">
    <button type="submit">Buscar</button>
  </form>
  <table>
    <thead><tr>
      <th>E-mail</th><th>Nome</th><th>Plano</th><th>Papel</th><th>Status</th>
      <th>Aparelho</th><th>Presença</th><th>Visto</th><th>Último acesso</th>
    </tr></thead>
    <tbody>{linhas}</tbody>
  </table>
  <div class="pager">
    {anterior}
    <span>Página {pag} de {total_paginas}</span>
    {proxima}
  </div>
</main>
</body></html>"""
