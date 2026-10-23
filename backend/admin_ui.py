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


_PWA_HEAD = (
    '<meta name="theme-color" content="#8806CE">'
    '<link rel="manifest" href="/admin/manifest.webmanifest">'
    '<link rel="apple-touch-icon" href="/admin/apple-touch-icon.png">'
    '<link rel="icon" type="image/png" href="/admin/icon-192.png">'
    '<script src="/admin/painel.js" defer></script>'
)

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
<title>MentAll PRO — Painel</title><style>{_ESTILO}</style>{_PWA_HEAD}</head>
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
        f'<td><a href="/admin/usuarios/{_esc(u.get("id"))}">{_esc(u.get("email"))}</a></td>'
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


def _pill_saude(item: dict) -> str:
    estado = item.get("estado") or "info"
    rotulo = {"ok": "ok", "atencao": "atenção", "erro": "erro", "info": "info"}.get(estado, estado)
    ms = f" · {int(item['ms'])} ms" if item.get("ms") is not None else ""
    return (
        f'<span class="pill saude-{_esc(estado)}" title="{_esc(item.get("detalhe"))}">'
        f'{_esc(item.get("nome"))}: {_esc(rotulo)}{_esc(ms)}</span>'
    )


def _secao_saude(saude: list | None) -> str:
    if not saude:
        return ""
    pills = "".join(_pill_saude(item) for item in saude)
    problemas = sum(1 for item in saude if item.get("estado") in ("erro", "atencao"))
    resumo = (
        '<span class="on">tudo certo</span>'
        if problemas == 0
        else f'<span class="erro">{problemas} ponto(s) de atenção</span>'
    )
    return f"""
  <h2>Saúde do sistema — {resumo}</h2>
  <div>{pills}</div>"""


def _secao_operacao(extras: dict | None) -> str:
    if not extras:
        return ""
    grupos = [
        (
            "Contratos",
            [(f"aceitos: {extras['contratos_aceitos']}", ""),
             (f"pendentes: {extras['contratos_pendentes']}", "")],
        ),
        (
            "Anamneses",
            [(f"respondidas: {extras['anamneses_respondidas']}", ""),
             (f"pendentes: {extras['anamneses_pendentes']}", "")],
        ),
        (
            "Lembretes",
            [(f"enviados: {extras['lembretes_enviados']}", ""),
             (f"entregues: {extras['lembretes_entregues']}", ""),
             (f"lidos: {extras['lembretes_lidos']}", ""),
             (f"falhas: {extras['lembretes_falhas']}", "on" if extras["lembretes_falhas"] else "off"),
             (f"pendentes: {extras['lembretes_pendentes']}", "")],
        ),
    ]
    blocos = []
    for titulo, itens in grupos:
        pills = "".join(
            f'<span class="pill{(" " + classe) if classe in ("on", "off") else ""}">{_esc(txt)}</span>'
            for txt, classe in itens
        )
        blocos.append(f"<div><span class='dica'>{_esc(titulo)}</span><br>{pills}</div>")
    versoes = extras.get("versoes") or []
    if versoes:
        pills = "".join(
            f'<span class="pill">{_esc(versao)}: {int(total)}</span>' for versao, total in versoes
        )
        blocos.append(f"<div><span class='dica'>Versões do app</span><br>{pills}</div>")
    return f"""
  <h2>Operação</h2>
  <div class="cards" style="gap:20px;flex-wrap:wrap">{''.join(blocos)}</div>"""


def _querystring(filtros: dict, pagina: int | None = None) -> str:
    pares = []
    for chave in ("busca", "status", "plano", "online", "versao", "ordenar"):
        valor = (filtros or {}).get(chave) or ""
        if valor and not (chave == "ordenar" and valor == "criado_desc"):
            pares.append(f"{chave}={_esc(valor)}")
    if pagina is not None:
        pares.append(f"pagina={int(pagina)}")
    return "&".join(pares)


def _opcoes_select(nome: str, opcoes: list, valor_atual: str, rotulo_todos: str) -> str:
    itens = [f'<option value="">{_esc(rotulo_todos)}</option>']
    for valor in opcoes:
        selecionado = " selected" if str(valor) == str(valor_atual) else ""
        itens.append(f'<option value="{_esc(valor)}"{selecionado}>{_esc(valor)}</option>')
    return f'<select name="{nome}" aria-label="{nome}">{"".join(itens)}</select>'


def _form_filtros(filtros: dict, opcoes: dict | None) -> str:
    opcoes = opcoes or {}
    ordenacoes = [
        ("criado_desc", "Mais recentes"), ("criado_asc", "Mais antigos"),
        ("acesso_desc", "Último acesso"), ("email_asc", "E-mail (A-Z)"),
    ]
    opcoes_ordenacao = "".join(
        f'<option value="{valor}"{" selected" if filtros.get("ordenar") == valor else ""}>{_esc(rotulo)}</option>'
        for valor, rotulo in ordenacoes
    )
    online = filtros.get("online") or ""
    opcoes_online = (
        '<option value="">Todos</option>'
        f'<option value="1"{" selected" if online == "1" else ""}>Online agora</option>'
        f'<option value="0"{" selected" if online == "0" else ""}>Offline</option>'
    )
    qs = _querystring(filtros)
    link_csv = "/admin/usuarios.csv" + (("?" + qs) if qs else "")
    return f"""
  <form class="filtros" method="get" action="/admin">
    <input type="text" name="busca" placeholder="Buscar por e-mail ou nome" value="{_esc(filtros.get('busca'))}">
    {_opcoes_select("status", opcoes.get("status") or [], filtros.get("status"), "Status (todos)")}
    {_opcoes_select("plano", opcoes.get("planos") or [], filtros.get("plano"), "Plano (todos)")}
    {_opcoes_select("versao", opcoes.get("versoes") or [], filtros.get("versao"), "Versão (todas)")}
    <select name="online">{opcoes_online}</select>
    <select name="ordenar">{opcoes_ordenacao}</select>
    <button type="submit">Filtrar</button>
    <a class="btn secundario" href="/admin">Limpar</a>
    <a class="btn secundario" href="{_esc(link_csv)}">Exportar CSV</a>
  </form>"""


def _secao_auditoria(auditoria: list | None) -> str:
    if not auditoria:
        return ""
    linhas = "".join(
        "<tr>"
        f"<td>{_quando(item.get('criado_em'))}</td>"
        f"<td>{_esc(item.get('ator'))}</td>"
        f"<td>{_esc(item.get('acao'))}</td>"
        f"<td>{_esc(item.get('alvo'))}</td>"
        f"<td>{_esc(item.get('detalhe'))}</td>"
        "</tr>"
        for item in auditoria
    )
    return f"""
  <h2>Últimas ações administrativas</h2>
  <table>
    <thead><tr><th>Quando</th><th>Quem</th><th>Ação</th><th>Alvo</th><th>Detalhe</th></tr></thead>
    <tbody>{linhas}</tbody>
  </table>"""


def pagina_dashboard(
    kpis: dict,
    pagina: dict,
    filtros: dict | None = None,
    extras: dict | None = None,
    saude: list | None = None,
    opcoes: dict | None = None,
    auditoria: list | None = None,
    pode_email: bool = True,
) -> str:
    """Dashboard do dono: KPIs, saúde, operação, filtros/CSV e lista de psicólogos."""
    filtros = filtros or {}
    extras = extras or {}
    aparelhos = "".join(
        f'<span class="pill">{_esc(p)}: {int(n)}</span>' for p, n in kpis["aparelhos"]
    ) or '<span class="off">nenhum</span>'
    eventos = "".join(
        f'<span class="pill">{_esc(t)}: {int(n)}</span>' for t, n in kpis["eventos_por_tipo"]
    ) or '<span class="off">nenhum</span>'

    linhas = "".join(_linha_usuario(u) for u in pagina["usuarios"]) or (
        '<tr><td colspan="9" class="off">Nenhum psicólogo encontrado com esses filtros.</td></tr>'
    )

    total = pagina["total"]
    limite = pagina["limite"]
    pag = pagina["pagina"]
    total_paginas = max(1, math.ceil(total / limite))
    qs_anterior = _querystring(filtros, pag - 1)
    qs_proxima = _querystring(filtros, pag + 1)
    anterior = (f'<a href="/admin?{qs_anterior}">&larr; Anterior</a>'
                if pag > 1 else '<span class="off">&larr; Anterior</span>')
    proxima = (f'<a href="/admin?{qs_proxima}">Próxima &rarr;</a>'
               if pag < total_paginas else '<span class="off">Próxima &rarr;</span>')

    pendentes = int(extras.get("usuarios_pendentes", 0) or 0)
    card_pendentes = (
        f'<div class="card{" alerta" if pendentes else ""}">'
        f'<div class="n">{pendentes}</div><div class="l">Contas pendentes</div></div>'
    )
    card_novos = (
        f'<div class="card"><div class="n">{int(extras.get("novos_7d", 0) or 0)}</div>'
        f'<div class="l">Novos (7 dias)</div></div>'
    )

    return f"""<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>MentAll PRO — Painel</title><style>{_ESTILO}</style>{_PWA_HEAD}</head>
<body>
{_cabecalho_painel(pode_email=pode_email)}
<main>
  <div class="cards">
    <div class="card"><div class="n">{int(kpis["total_usuarios"])}</div><div class="l">Psicólogos</div></div>
    <div class="card"><div class="n">{int(kpis["online_agora"])}</div><div class="l">Online agora</div></div>
    {card_novos}
    {card_pendentes}
  </div>
{_secao_saude(saude)}
{_secao_operacao(extras)}
  <h2>Aparelhos</h2>
  <div>{aparelhos}</div>

  <h2>Uso por tipo de evento</h2>
  <div>{eventos}</div>

  <h2>Psicólogos ({total})</h2>
  {_form_filtros(filtros, opcoes)}
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
{_secao_auditoria(auditoria)}
</main>
</body></html>"""


# ---------------------------------------------------------------------------
# E-mail (Mailu) — Fase 4 do painel (22/10/2026)
# ---------------------------------------------------------------------------

# CSS adicional desta seção (o _ESTILO original continua valendo)
_ESTILO += """
  nav{margin-left:auto;margin-right:20px;display:flex;gap:16px;align-items:center}
  nav a{color:rgba(255,255,255,.78);text-decoration:none;font-size:14px;padding-bottom:2px}
  nav a.nav-on{color:#fff;font-weight:700;border-bottom:2px solid #fff}
  .ok-box{background:#E8F5E9;border:1px solid #A5D6A7;color:#1B5E20;border-radius:10px;padding:12px 16px;margin:0 0 16px}
  .erro-box{background:#FFEBEE;border:1px solid #EF9A9A;color:#B71C1C;border-radius:10px;padding:12px 16px;margin:0 0 16px}
  .aviso-box{background:#FFF8E1;border:1px solid #FFE082;color:#6D4C00;border-radius:10px;padding:12px 16px;margin:0 0 16px}
  .credencial{background:#F3E5F5;border:1px solid #CE93D8;border-radius:12px;padding:14px 18px;margin:0 0 18px}
  .credencial code{font-size:16px;background:#fff;padding:3px 8px;border-radius:6px;border:1px solid #E1BEE7}
  .grid2{display:grid;grid-template-columns:1fr 1fr;gap:18px;align-items:start}
  @media(max-width:820px){.grid2{grid-template-columns:1fr}}
  form.card-form{background:#fff;border:1px solid #E2E8F0;border-radius:12px;padding:16px 20px;margin-bottom:22px;display:flex;gap:12px;flex-wrap:wrap;align-items:flex-end}
  form.card-form label{font-size:12px;color:#475569;display:flex;flex-direction:column;gap:4px;text-transform:none;letter-spacing:0}
  form.card-form input,form.card-form select{padding:9px;border:1px solid #CBD5E1;border-radius:8px;font-size:14px}
  form.card-form button,.btn{background:#8806CE;color:#fff;border:0;border-radius:8px;padding:9px 16px;cursor:pointer;font-size:14px;text-decoration:none}
  form.acoes{display:inline;margin:0}
  form.acoes button{background:#F1F5F9;color:#334155;border:1px solid #CBD5E1;border-radius:8px;padding:5px 10px;font-size:13px;cursor:pointer;margin:1px}
  form.acoes button.perigo{background:#FFEBEE;color:#B71C1C;border-color:#EF9A9A}
  .pill-on{background:#E8F5E9;color:#1B5E20}
  .pill-off{background:#FFEBEE;color:#B71C1C}
  .dica{color:#64748B;font-size:13px;margin:6px 0 0}
  .vazio{color:#94A3B8;font-size:14px}
  .saude-ok{background:#E8F5E9;color:#1B5E20}
  .saude-atencao{background:#FFF8E1;color:#6D4C00}
  .saude-erro{background:#FFEBEE;color:#B71C1C}
  .saude-info{background:#F1F5F9;color:#475569}
  .card.alerta .n{color:#B71C1C}
"""


def _nav(ativo: str = "psicologos", pode_email: bool = True) -> str:
    """Navegação do painel (server-side, sem JS)."""
    itens = [("Psicólogos", "/admin", "psicologos")]
    if pode_email:
        itens.append(("E-mail", "/admin/email", "email"))
        itens.append(("Lembretes", "/admin/lembretes", "lembretes"))
    itens.append(("Segurança", "/admin/seguranca", "seguranca"))
    partes = []
    for rotulo, href, chave in itens:
        classe = ' class="nav-on"' if chave == ativo else ""
        partes.append(f'<a href="{href}"{classe}>{_esc(rotulo)}</a>')
    return "<nav>" + "".join(partes) + "</nav>"


def _alertas(msg: str = "", erro: str = "") -> str:
    bloco = ""
    if msg:
        bloco += f'<div class="ok-box">{_esc(msg)}</div>'
    if erro:
        bloco += f'<div class="erro-box">{_esc(erro)}</div>'
    return bloco


def _cabecalho_email() -> str:
    return (
        "<header>"
        "<h1>MentAll PRO — Painel</h1>"
        + _nav("email")
        + '<form method="post" action="/admin/logout"><button type="submit">Sair</button></form>'
        "</header>"
    )


def _linha_caixa(c: dict) -> str:
    estado = (
        '<span class="pill pill-on">ativa</span>'
        if c.get("ativo")
        else '<span class="pill pill-off">desativada</span>'
    )
    papel = ' <span class="pill">admin</span>' if c.get("admin") else ""
    cota = f"{c['cota_gb']:.0f} GB" if c.get("cota_gb") else "ilimitada"
    email = _esc(c.get("email"))

    acoes = (
        '<form class="acoes" method="post" action="/admin/email/senha">'
        f'<input type="hidden" name="email" value="{email}">'
        '<button type="submit">Nova senha</button>'
        "</form>"
    )
    if c.get("admin"):
        acoes += '<span class="dica"> · conta administrativa protegida</span>'
    else:
        termo = "Desativar" if c.get("ativo") else "Ativar"
        valor = "0" if c.get("ativo") else "1"
        acoes += (
            '<form class="acoes" method="post" action="/admin/email/status">'
            f'<input type="hidden" name="email" value="{email}">'
            f'<input type="hidden" name="ativo" value="{valor}">'
            f'<button type="submit">{termo}</button>'
            "</form>"
            '<form class="acoes" method="get" action="/admin/email/excluir">'
            f'<input type="hidden" name="email" value="{email}">'
            '<button type="submit" class="perigo">Excluir</button>'
            "</form>"
        )
    return (
        "<tr>"
        f"<td>{email}{papel}</td>"
        f"<td>{_esc(c.get('nome')) or '-'}</td>"
        f"<td>{_esc(cota)}</td>"
        f"<td>{estado}</td>"
        f"<td>{acoes}</td>"
        "</tr>"
    )


def _linha_alias(a: dict) -> str:
    email = _esc(a.get("email"))
    destinos = _esc(", ".join(a.get("destinos") or []))
    return (
        "<tr>"
        f"<td>{email}</td>"
        f"<td>{destinos}</td>"
        "<td>"
        '<form class="acoes" method="post" action="/admin/email/alias/excluir">'
        f'<input type="hidden" name="email" value="{email}">'
        '<button type="submit" class="perigo">Excluir</button>'
        "</form>"
        "</td>"
        "</tr>"
    )


def pagina_email(
    caixas: list,
    aliases: list,
    dominio: str,
    configurado: bool = True,
    msg: str = "",
    erro: str = "",
    credenciais: tuple | None = None,
) -> str:
    """Página de administração das caixas de e-mail (Fase 4)."""
    bloco_credencial = ""
    if credenciais:
        email, senha = credenciais
        bloco_credencial = (
            '<div class="credencial">'
            "<strong>Guarde a senha agora — ela não será exibida novamente.</strong><br>"
            f"<span class='dica'>Endereço:</span> <code>{_esc(email)}</code><br>"
            f"<span class='dica'>Senha inicial:</span> <code>{_esc(senha)}</code>"
            '<p class="dica">A pessoa deve trocar a senha no primeiro acesso ao webmail.</p>'
            "</div>"
        )

    if not configurado:
        estado = (
            '<div class="aviso-box"><strong>Integração não configurada.</strong> '
            "Defina <code>MAILU_API_URL</code> e <code>MAILU_API_TOKEN</code> nos secrets do backend "
            "para gerenciar as caixas por aqui.</div>"
        )
    else:
        estado = ""

    opcoes_cota = "".join(
        f'<option value="{g}"{" selected" if g == 3 else ""}>{g} GB</option>' for g in (1, 2, 3, 5)
    )
    caixas_ativas = [c for c in caixas if c.get("ativo")]
    opcoes_destino = "".join(
        f'<option value="{_esc(c["email"])}">{_esc(c["email"])}</option>' for c in caixas_ativas
    )
    if not opcoes_destino:
        opcoes_destino = '<option value="">(nenhuma caixa ativa)</option>'

    linhas_caixas = "".join(_linha_caixa(c) for c in caixas) or (
        '<tr><td colspan="5" class="vazio">Nenhuma caixa cadastrada.</td></tr>'
    )
    linhas_aliases = "".join(_linha_alias(a) for a in aliases) or (
        '<tr><td colspan="3" class="vazio">Nenhum endereço extra.</td></tr>'
    )

    return f"""<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>MentAll PRO — E-mail</title><style>{_ESTILO}</style>{_PWA_HEAD}</head>
<body>
{_cabecalho_email()}
<main>
  <h2 style="font-size:18px;color:#1E293B;margin-top:0">E-mail — caixas @{_esc(dominio)}</h2>
  {_alertas(msg, erro)}
  {bloco_credencial}
  {estado}

  <div class="cards">
    <div class="card"><div class="n">{len(caixas)}</div><div class="l">Caixas</div></div>
    <div class="card"><div class="n">{sum(1 for c in caixas if c.get('ativo'))}</div><div class="l">Ativas</div></div>
    <div class="card"><div class="n">{len(aliases)}</div><div class="l">Endereços extras</div></div>
  </div>

  <div class="grid2">
    <div>
      <h2>Caixas</h2>
      <table>
        <thead><tr><th>E-mail</th><th>Nome</th><th>Cota</th><th>Status</th><th>Ações</th></tr></thead>
        <tbody>{linhas_caixas}</tbody>
      </table>
      <p class="dica">O acesso ao e-mail é pelo webmail ou por app (IMAP/SMTP) com a senha da caixa.</p>
    </div>
    <div>
      <h2>Nova caixa</h2>
      <form class="card-form" method="post" action="/admin/email/criar">
        <label>Endereço <span class="dica">(antes do @)</span>
          <input type="text" name="prefixo" required maxlength="30" placeholder="anderson" autocomplete="off">
        </label>
        <label>Nome de exibição
          <input type="text" name="nome" maxlength="100" placeholder="Anderson Lemos" autocomplete="off">
        </label>
        <label>Cota
          <select name="cota_gb">{opcoes_cota}</select>
        </label>
        <button type="submit">Criar caixa</button>
      </form>

      <h2>Endereços extras (aliases)</h2>
      <table>
        <thead><tr><th>Endereço</th><th>Encaminha para</th><th>Ações</th></tr></thead>
        <tbody>{linhas_aliases}</tbody>
      </table>
      <form class="card-form" method="post" action="/admin/email/alias/criar">
        <label>Endereço <span class="dica">(antes do @)</span>
          <input type="text" name="prefixo" required maxlength="30" placeholder="financeiro" autocomplete="off">
        </label>
        <label>Encaminhar para
          <select name="destino_email">{opcoes_destino}</select>
        </label>
        <button type="submit">Criar endereço</button>
      </form>
      <p class="dica">Contato@, financeiro@, dmarc@ etc. são encaminhados para uma caixa existente.</p>
    </div>
  </div>
</main>
</body></html>"""


def pagina_confirmar_exclusao(caixa: dict) -> str:
    """Confirmação de exclusão de caixa (sem JS: exige o POST com confirmar=sim)."""
    email = _esc(caixa.get("email"))
    nome = _esc(caixa.get("nome")) or "-"
    return f"""<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>MentAll PRO — Excluir caixa</title><style>{_ESTILO}</style>{_PWA_HEAD}</head>
<body>
{_cabecalho_email()}
<main>
  <h2 style="font-size:18px;color:#1E293B">Excluir caixa de e-mail</h2>
  <div class="erro-box">
    <strong>Esta ação remove a caixa {email} ({nome}) e o acesso ao e-mail.</strong>
    As mensagens que já foram enviadas/recebidas ficam no servidor apenas enquanto a
    manutenção de dados permitir — não há como desfazer pelo painel.
  </div>
  <form method="post" action="/admin/email/excluir">
    <input type="hidden" name="email" value="{email}">
    <input type="hidden" name="confirmar" value="sim">
    <button class="btn" style="background:#B71C1C" type="submit">Confirmar exclusão</button>
    <a class="btn" style="background:#F1F5F9;color:#334155;border:1px solid #CBD5E1" href="/admin/email">Cancelar</a>
  </form>
</main>
</body></html>"""


def _cabecalho_painel(ativo: str = "psicologos", pode_email: bool = True) -> str:
    """Cabeçalho comum das páginas do painel (nav + sair)."""
    return (
        "<header><h1>MentAll PRO — Painel</h1>"
        + _nav(ativo, pode_email=pode_email)
        + '<form method="post" action="/admin/logout"><button type="submit">Sair</button></form>'
        + "</header>"
    )


_ESTILO += """
  form.filtros{display:flex;gap:8px;flex-wrap:wrap;align-items:center;margin:0 0 14px;background:#fff;border:1px solid #E2E8F0;border-radius:12px;padding:12px 14px}
  form.filtros input,form.filtros select{padding:8px;border:1px solid #CBD5E1;border-radius:8px;font-size:13px;background:#fff}
  form.filtros button{background:#8806CE;color:#fff;border:0;border-radius:8px;padding:8px 14px;cursor:pointer;font-size:13px}
  .btn.secundario{background:#F1F5F9;color:#334155;border:1px solid #CBD5E1;font-size:13px;padding:8px 12px;border-radius:8px;text-decoration:none;display:inline-block}
  .voltar{font-size:13px;color:#8806CE;text-decoration:none}
  .grid-cards{display:flex;gap:12px;flex-wrap:wrap;margin:0 0 18px}
  .grid-cards .card .n{font-size:20px}
  .acoes-linha{display:flex;gap:14px;flex-wrap:wrap;align-items:flex-end;background:#fff;border:1px solid #E2E8F0;border-radius:12px;padding:14px 16px;margin:0 0 20px}
  .acoes-linha form{margin:0;display:flex;gap:8px;align-items:flex-end}
  .acoes-linha label{font-size:12px;color:#475569;display:flex;flex-direction:column;gap:4px}
  .acoes-linha input,.acoes-linha select{padding:8px;border:1px solid #CBD5E1;border-radius:8px;font-size:13px}
  .acoes-linha button{background:#8806CE;color:#fff;border:0;border-radius:8px;padding:8px 14px;cursor:pointer;font-size:13px}
  .acoes-linha button.perigo{background:#B71C1C}
  .nota-lgpd{font-size:12px;color:#64748B;margin:0 0 16px}
"""


def _cartao(rotulo: str, valor, destaque: bool = False) -> str:
    classe = "card alerta" if destaque else "card"
    return (
        f'<div class="{classe}"><div class="n">{_esc(valor if valor not in (None, "") else "-")}</div>'
        f'<div class="l">{_esc(rotulo)}</div></div>'
    )


def _tabela_dispositivos(dispositivos: list) -> str:
    if not dispositivos:
        return '<p class="off">Nenhum dispositivo registrado.</p>'
    linhas = "".join(
        "<tr>"
        f"<td>{_esc(d.get('plataforma')) or '-'}</td>"
        f"<td>{_esc(d.get('versao_app')) or '-'}</td>"
        f"<td>{_quando(d.get('ultimo_heartbeat_em'))}</td>"
        f"<td>{_quando(d.get('criado_em'))}</td>"
        "</tr>"
        for d in dispositivos
    )
    return f"""<table>
    <thead><tr><th>Plataforma</th><th>Versão</th><th>Último contato</th><th>Registrado em</th></tr></thead>
    <tbody>{linhas}</tbody>
  </table>"""


def _tabela_eventos(eventos_por_tipo: list, eventos_recentes: list) -> str:
    pills = "".join(
        f'<span class="pill">{_esc(tipo)}: {int(total)}</span>' for tipo, total in eventos_por_tipo
    ) or '<span class="off">nenhum</span>'
    recentes = "".join(
        f"<tr><td>{_esc(item.get('tipo'))}</td><td>{_quando(item.get('criado_em'))}</td></tr>"
        for item in eventos_recentes
    )
    corpo = (
        f"""<table>
    <thead><tr><th>Evento</th><th>Quando</th></tr></thead>
    <tbody>{recentes}</tbody>
  </table>"""
        if eventos_recentes
        else ""
    )
    return f"<div>{pills}</div>{corpo}"


def pagina_usuario(
    detalhe: dict,
    msg: str = "",
    erro: str = "",
    pode_acoes: bool = True,
    pode_email: bool = True,
) -> str:
    """Detalhe do usuário no painel — só metadados operacionais (LGPD)."""
    usuario = detalhe["usuario"]
    email = _esc(usuario.get("email"))
    ident = _esc(usuario.get("id"))
    status = (usuario.get("status") or "").lower()
    online = detalhe.get("online")
    wuzapi = detalhe.get("wuzapi_conectado")

    cards = "".join(
        [
            _cartao("Status", status, destaque=status != "ativo"),
            _cartao("Plano", usuario.get("plano")),
            _cartao("Papel", usuario.get("role")),
            _cartao("Sessões do app revogadas", int(usuario.get("token_version") or 0)),
            _cartao("Criado em", _quando(usuario.get("criado_em"))),
            _cartao("Último acesso", _quando(usuario.get("ultimo_acesso_em"))),
            _cartao("Presença", "online" if online else "offline"),
            _cartao(
                "WhatsApp",
                "conectado" if wuzapi else ("desconectado" if wuzapi is False else "sem instância"),
            ),
        ]
    )

    botoes_status = ""
    if status == "ativo":
        botoes_status = (
            f'<form method="post" action="/admin/usuarios/{ident}/acao">'
            '<input type="hidden" name="acao" value="suspender">'
            '<button class="perigo" type="submit">Suspender conta</button></form>'
        )
    elif status == "suspenso":
        botoes_status = (
            f'<form method="post" action="/admin/usuarios/{ident}/acao">'
            '<input type="hidden" name="acao" value="reativar">'
            '<button type="submit">Reativar conta</button></form>'
        )

    reenviar_confirmacao = ""
    if status == "pendente":
        reenviar_confirmacao = (
            f'<form method="post" action="/admin/usuarios/{ident}/acao">'
            '<input type="hidden" name="acao" value="reenviar_confirmacao">'
            '<button type="submit">Reenviar confirmação</button></form>'
        )

    papel_atual = (usuario.get("role") or "user").lower()
    opcoes_papel = "".join(
        f'<option value="{valor}"{" selected" if valor == papel_atual else ""}>{rotulo}</option>'
        for valor, rotulo in (
            ("admin", "admin"),
            ("financeiro", "financeiro"),
            ("suporte", "suporte"),
            ("user", "user (app somente)"),
        )
    )
    acoes = ""
    if pode_acoes:
        acoes = f"""
  <h2>Ações</h2>
  <div class="acoes-linha">
    {botoes_status}
    {reenviar_confirmacao}
    <form method="post" action="/admin/usuarios/{ident}/acao">
      <input type="hidden" name="acao" value="plano">
      <label>Plano
        <input type="text" name="plano" maxlength="30" value="{_esc(usuario.get('plano'))}" autocomplete="off">
      </label>
      <button type="submit">Salvar plano</button>
    </form>
    <form method="post" action="/admin/usuarios/{ident}/acao">
      <input type="hidden" name="acao" value="papel">
      <label>Papel no RBAC
        <select name="papel">{opcoes_papel}</select>
      </label>
      <button type="submit">Salvar papel</button>
    </form>
    <form method="post" action="/admin/usuarios/{ident}/acao">
      <input type="hidden" name="acao" value="encerrar_sessoes_app">
      <button class="perigo" type="submit">Encerrar sessões do app</button>
    </form>
  </div>"""
    else:
        acoes = (
            '<h2>Ações</h2><div class="seg-box" style="margin:0 0 18px">'
            "<p>Seu papel permite apenas visualizar esta conta. "
            "Suspender, trocar plano e reenviar confirmação exigem administrador.</p></div>"
        )

    contagens = "".join(
        [
            _cartao("Contratos aceitos", detalhe["contratos"]["aceitos"]),
            _cartao("Contratos pendentes", detalhe["contratos"]["pendentes"]),
            _cartao("Anamneses respondidas", detalhe["anamneses"]["respondidas"]),
            _cartao("Anamneses pendentes", detalhe["anamneses"]["pendentes"]),
            _cartao("Lembretes enviados", detalhe["lembretes"]["enviados"]),
            _cartao("Lembretes entregues", detalhe["lembretes"]["entregues"]),
            _cartao("Lembretes lidos", detalhe["lembretes"]["lidos"]),
            _cartao("Lembretes falhas", detalhe["lembretes"]["falhas"], destaque=bool(detalhe["lembretes"]["falhas"])),
            _cartao("Lembretes pendentes", detalhe["lembretes"]["pendentes"]),
        ]
    )

    auditoria = ""
    if detalhe.get("auditoria"):
        linhas = "".join(
            "<tr>"
            f"<td>{_quando(item.get('criado_em'))}</td>"
            f"<td>{_esc(item.get('ator'))}</td>"
            f"<td>{_esc(item.get('acao'))}</td>"
            f"<td>{_esc(item.get('detalhe'))}</td>"
            "</tr>"
            for item in detalhe["auditoria"]
        )
        auditoria = f"""
  <h2>Ações administrativas nesta conta</h2>
  <table>
    <thead><tr><th>Quando</th><th>Quem</th><th>Ação</th><th>Detalhe</th></tr></thead>
    <tbody>{linhas}</tbody>
  </table>"""

    return f"""<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>MentAll PRO — {email}</title><style>{_ESTILO}</style>{_PWA_HEAD}</head>
<body>
{_cabecalho_painel(pode_email=pode_email)}
<main>
  <a class="voltar" href="/admin">&larr; Voltar ao painel</a>
  <h2 style="font-size:18px;color:#1E293B;margin:10px 0 6px">{email}</h2>
  <p class="nota-lgpd">Metadados operacionais apenas — nenhum conteúdo clínico aparece no painel (LGPD).</p>
  {_alertas(msg, erro)}
  <div class="grid-cards">{cards}</div>
{acoes}
  <h2>Dados vinculados (status)</h2>
  <div class="grid-cards">{contagens}</div>
  <h2>Dispositivos ({len(detalhe.get('dispositivos') or [])})</h2>
  {_tabela_dispositivos(detalhe.get("dispositivos") or [])}
  <h2>Eventos</h2>
  {_tabela_eventos(detalhe.get("eventos_por_tipo") or [], detalhe.get("eventos_recentes") or [])}
{auditoria}
</main>
</body></html>"""


_ESTILO += """
  .seg-grid{display:flex;gap:14px;flex-wrap:wrap;margin:0 0 18px}
  .seg-box{background:#fff;border:1px solid #E2E8F0;border-radius:12px;padding:16px 20px;min-width:200px}
  .seg-box h3{margin:0 0 8px;font-size:14px;color:#475569}
  .seg-box p{margin:0 0 10px;font-size:13px;color:#64748B}
  .segredo{font-family:ui-monospace,Menlo,monospace;font-size:15px;background:#F8FAFC;border:1px dashed #CBD5E1;border-radius:8px;padding:8px 10px;display:inline-block;word-break:break-all}
  .codigos{display:flex;gap:10px;flex-wrap:wrap;margin:10px 0}
  .codigos code{background:#F3E5F5;border:1px solid #CE93D8;border-radius:6px;padding:6px 10px;font-size:15px}
  form.seg-form{display:flex;gap:10px;align-items:flex-end;flex-wrap:wrap;background:#fff;border:1px solid #E2E8F0;border-radius:12px;padding:14px 16px;margin:0 0 16px}
  form.seg-form label{font-size:12px;color:#475569;display:flex;flex-direction:column;gap:4px}
  form.seg-form input{padding:9px;border:1px solid #CBD5E1;border-radius:8px;font-size:15px;letter-spacing:2px;width:130px}
  form.seg-form button{background:#8806CE;color:#fff;border:0;border-radius:8px;padding:9px 16px;cursor:pointer;font-size:14px}
  form.seg-form button.perigo{background:#B71C1C}
  .tela-2fa{max-width:420px;margin:70px auto;background:#fff;border:1px solid #E2E8F0;border-radius:12px;padding:26px}
  .tela-2fa h2{margin-top:0;color:#8806CE;font-size:20px}
  .tela-2fa input{width:100%;padding:12px;margin:8px 0 14px;border:1px solid #CBD5E1;border-radius:8px;font-size:22px;letter-spacing:6px;text-align:center}
  .tela-2fa button{width:100%;background:#8806CE;color:#fff;border:0;border-radius:8px;padding:12px;font-size:15px;cursor:pointer}
"""


def pagina_2fa_login(erro: str = "") -> str:
    """Segunda etapa do login (código do app autenticador)."""
    bloco_erro = f'<p class="erro">{_esc(erro)}</p>' if erro else ""
    return f"""<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>MentAll PRO — Verificação em 2 etapas</title><style>{_ESTILO}</style>{_PWA_HEAD}</head>
<body>
<form class="tela-2fa" method="post" action="/admin/2fa">
  <h2>Verificação em 2 etapas</h2>
  {bloco_erro}
  <p class="dica">Digite o código de 6 dígitos do seu aplicativo autenticador.</p>
  <input type="text" name="codigo" inputmode="numeric" pattern="[0-9A-Za-z ]{6,12}"
         maxlength="12" autocomplete="one-time-code" autofocus required>
  <button type="submit">Confirmar</button>
  <p class="dica" style="margin-top:12px">Sem o app? Use um dos códigos de recuperação que você salvou.</p>
</form>
</body></html>"""


def pagina_seguranca(
    ator: str,
    papel: str,
    seg_estado: dict,
    idle_min: int,
    msg: str = "",
    erro: str = "",
) -> str:
    """Página de segurança da conta administrativa (2FA + sessões)."""
    status_2fa = (
        '<span class="pill saude-ok">ativo</span>'
        if seg_estado.get("ativo")
        else '<span class="pill saude-atencao">desativado</span>'
    )
    pendente = (
        '<p class="dica">Você iniciou a ativação e ainda não confirmou o código.</p>'
        if seg_estado.get("pendente")
        else ""
    )
    if seg_estado.get("ativo"):
        bloco_2fa = f"""
    <form class="seg-form" method="post" action="/admin/seguranca/desativar">
      <label>Código atual (app ou recuperação)
        <input type="text" name="codigo" inputmode="numeric" maxlength="12" autocomplete="one-time-code" required>
      </label>
      <button type="submit" class="perigo">Desativar 2FA</button>
    </form>
    <p class="dica">Códigos de recuperação restantes: <strong>{int(seg_estado.get('backup_restantes', 0))}</strong>.
    Ao ativar novamente, novos códigos são gerados.</p>"""
    else:
        bloco_2fa = f"""{pendente}
    <form method="post" action="/admin/seguranca/ativar" style="margin:0">
      <button class="btn" type="submit">Ativar verificação em 2 etapas</button>
    </form>
    <p class="dica">Recomendado: protege o painel mesmo se a senha for descoberta.</p>"""

    return f"""<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>MentAll PRO — Segurança</title><style>{_ESTILO}</style>{_PWA_HEAD}</head>
<body>
{_cabecalho_painel("seguranca")}
<main>
  <h2 style="font-size:18px;color:#1E293B;margin-top:0">Segurança da conta administrativa</h2>
  {_alertas(msg, erro)}
  <p class="nota-lgpd">Conta: <strong>{_esc(ator)}</strong> · papel: {_esc(papel)}</p>

  <div class="seg-grid">
    <div class="seg-box">
      <h3>Verificação em 2 etapas (TOTP)</h3>
      <p>Status: {status_2fa}</p>
      {bloco_2fa}
    </div>
    <div class="seg-box">
      <h3>Sessões</h3>
      <p>Este painel expira automaticamente após <strong>{idle_min} min</strong> sem uso
      (ao mexer no painel o tempo reinicia).</p>
      <form method="post" action="/admin/logout-todos" style="margin:0">
        <button class="btn secundario" type="submit">Sair de todos os dispositivos</button>
      </form>
      <p class="dica">Encerra também este navegador — você precisará entrar de novo.</p>
    </div>
  </div>
</main>
</body></html>"""


def pagina_2fa_ativar(ator: str, segredo: str, uri: str, erro: str = "") -> str:
    """Passo 2 da ativação: mostra o segredo e pede o primeiro código."""
    bloco_erro = f'<p class="erro">{_esc(erro)}</p>' if erro else ""
    return f"""<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>MentAll PRO — Ativar 2FA</title><style>{_ESTILO}</style>{_PWA_HEAD}</head>
<body>
{_cabecalho_painel("seguranca")}
<main>
  <h2 style="font-size:18px;color:#1E293B;margin-top:0">Ativar verificação em 2 etapas</h2>
  {bloco_erro}
  <p class="nota-lgpd">Conta: <strong>{_esc(ator)}</strong></p>
  <div class="seg-grid">
    <div class="seg-box" style="flex:1">
      <h3>1. Adicione ao seu aplicativo autenticador</h3>
      <p>Use o Google Authenticator, Microsoft Authenticator, 1Password, Bitwarden ou similar.
      Digite a chave abaixo <strong>manualmente</strong> (ou use o link otpauth):</p>
      <p class="segredo">{_esc(segredo)}</p>
      <p class="dica">Link: <a href="{_esc(uri)}">abrir no app autenticador</a></p>
    </div>
    <div class="seg-box">
      <h3>2. Confirme o código gerado</h3>
      <form class="seg-form" method="post" action="/admin/seguranca/confirmar">
        <label>Código de 6 dígitos
          <input type="text" name="codigo" inputmode="numeric" maxlength="8" autocomplete="one-time-code" required>
        </label>
        <button type="submit">Confirmar e ativar</button>
      </form>
      <p class="dica">Se o código falhar, confira o relógio do celular (deve estar automático).</p>
    </div>
  </div>
</main>
</body></html>"""


def pagina_2fa_backup(codigos: list[str]) -> str:
    """Mostra os códigos de recuperação UMA vez."""
    itens = "".join(f"<code>{_esc(c)}</code>" for c in codigos)
    return f"""<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>MentAll PRO — Códigos de recuperação</title><style>{_ESTILO}</style>{_PWA_HEAD}</head>
<body>
{_cabecalho_painel("seguranca")}
<main>
  <h2 style="font-size:18px;color:#1E293B;margin-top:0">2FA ativado — guarde os códigos de recuperação</h2>
  <div class="aviso-box">
    <strong>Estes códigos aparecem apenas uma vez.</strong> Cada um vale para um único acesso,
    caso você perca o celular. Guarde em local seguro (gerenciador de senhas ou papel).
  </div>
  <div class="codigos">{itens}</div>
  <p><a class="btn" href="/admin/seguranca">Voltar para Segurança</a></p>
</main>
</body></html>"""


def pagina_sem_permissao(recurso: str = "") -> str:
    detalhe = f" ({_esc(recurso)})" if recurso else ""
    return f"""<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>MentAll PRO — Sem permissão</title><style>{_ESTILO}</style>{_PWA_HEAD}</head>
<body>
{_cabecalho_painel()}
<main>
  <h2 style="font-size:18px;color:#B71C1C">Sem permissão{detalhe}</h2>
  <p class="nota-lgpd">Seu papel não permite acessar esta área. Fale com o administrador do painel.</p>
  <p><a class="btn" href="/admin">Voltar ao painel</a></p>
</main>
</body></html>"""


# CSS responsivo (Fase 5E): celular/tablet + rolagem horizontal de tabelas.
_ESTILO += """
  .rolagem{overflow-x:auto;-webkit-overflow-scrolling:touch;margin:0 0 12px}
  @media (max-width: 760px){
    header{flex-wrap:wrap;gap:10px;padding:12px 14px}
    header h1{font-size:16px}
    nav{margin:0;gap:10px;flex-wrap:wrap}
    header form{margin-left:auto}
    main{padding:14px}
    .cards{gap:10px}
    .card{min-width:140px;padding:12px 14px}
    .card .n{font-size:22px}
    h2{margin:18px 0 6px}
    table{font-size:12px}
    th,td{padding:7px 8px}
    form.filtros{gap:6px;padding:10px}
    form.filtros input,form.filtros select,form.filtros button,.btn.secundario{width:100%}
    .acoes-linha{flex-direction:column;align-items:stretch}
    .acoes-linha form{flex-wrap:wrap}
    .pager{flex-wrap:wrap;gap:8px}
    .grid-cards .card{flex:1 1 45%}
    .segredo{font-size:13px}
    .tela-2fa{margin:30px auto;padding:20px}
  }
"""


_ESTILO += """
  .btn.pequeno{padding:5px 10px;font-size:12px;border-radius:6px;background:#8806CE;color:#fff;border:0;cursor:pointer}
  .btn.secundario.pequeno{background:#F1F5F9;color:#334155;border:1px solid #CBD5E1}
"""


def _linha_lembrete(item: dict) -> str:
    status = (item.get("status") or "").strip()
    classes = {
        "falha": "saude-erro",
        "pendente": "saude-atencao",
        "enviado": "saude-ok",
        "cancelado": "saude-info",
    }
    pill = f'<span class="pill {classes.get(status, "saude-info")}">{_esc(status)}</span>'
    acoes = ""
    if status in ("falha", "cancelado"):
        acoes += (
            f'<form method="post" action="/admin/lembretes/{_esc(item.get("id"))}/acao" '
            'style="display:inline"><input type="hidden" name="acao" value="reenviar">'
            '<button type="submit" class="btn pequeno">Reenviar</button></form> '
        )
    if status in ("falha", "pendente"):
        acoes += (
            f'<form method="post" action="/admin/lembretes/{_esc(item.get("id"))}/acao" '
            'style="display:inline"><input type="hidden" name="acao" value="arquivar">'
            '<button type="submit" class="btn pequeno secundario">Arquivar</button></form>'
        )
    return (
        "<tr>"
        f"<td>{_quando(item.get('horario_envio'))}</td>"
        f"<td>{_esc(item.get('dono_email')) or '-'}</td>"
        f"<td>{pill}</td>"
        f"<td>{_esc(item.get('tentativas') or 0)}</td>"
        f"<td>{_quando(item.get('ultima_tentativa_em'))}</td>"
        f"<td>{_esc(item.get('telefone'))}</td>"
        f"<td>{acoes or '-'}</td>"
        "</tr>"
    )


def pagina_lembretes(
    resumo: dict,
    lembretes: list,
    filtro_status: str = "",
    msg: str = "",
    erro: str = "",
) -> str:
    """Lembretes do WhatsApp no painel — só metadados (LGPD)."""
    cards = "".join(
        [
            _cartao("Total", resumo.get("total", 0)),
            _cartao("Pendentes", resumo.get("pendentes", 0)),
            _cartao("Enviados", resumo.get("enviados", 0)),
            _cartao("Falhas", resumo.get("falhas", 0), destaque=bool(resumo.get("falhas"))),
            _cartao("Falhas (7 dias)", resumo.get("falhas_recentes", 0), destaque=bool(resumo.get("falhas_recentes"))),
            _cartao("Falhas antigas", resumo.get("falhas_antigas", 0)),
            _cartao("Atrasados", resumo.get("atrasados", 0), destaque=bool(resumo.get("atrasados"))),
            _cartao("Cancelados", resumo.get("cancelados", 0)),
        ]
    )

    opcoes = [("", "Todos")] + [
        ("pendente", "Pendentes"),
        ("enviado", "Enviados"),
        ("falha", "Falhas"),
        ("cancelado", "Cancelados"),
    ]
    opcoes_html = "".join(
        f'<option value="{valor}"{" selected" if valor == filtro_status else ""}>{_esc(rotulo)}</option>'
        for valor, rotulo in opcoes
    )

    linhas = "".join(_linha_lembrete(item) for item in lembretes) or (
        '<tr><td colspan="7" class="off">Nenhum lembrete com esse filtro.</td></tr>'
    )
    pode_arquivar = resumo.get("falhas_antigas", 0) > 0

    return f"""<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>MentAll PRO — Lembretes</title><style>{_ESTILO}</style>{_PWA_HEAD}</head>
<body>
{_cabecalho_painel("lembretes")}
<main>
  <h2 style="font-size:18px;color:#1E293B;margin-top:0">Lembretes do WhatsApp</h2>
  <p class="nota-lgpd">Metadados apenas — o conteúdo da mensagem não aparece no painel (LGPD).
  Telefones aparecem mascarados.</p>
  {_alertas(msg, erro)}
  <div class="grid-cards">{cards}</div>

  <form class="filtros" method="get" action="/admin/lembretes">
    <select name="status">{opcoes_html}</select>
    <button type="submit">Filtrar</button>
    <a class="btn secundario" href="/admin/lembretes">Limpar</a>
  </form>

  {'<form method="post" action="/admin/lembretes/arquivar-antigas" style="margin:0 0 14px"><button type="submit" class="btn secundario">Arquivar falhas antigas (' + str(resumo.get("falhas_antigas", 0)) + ')</button></form>' if pode_arquivar else ''}

  <table>
    <thead><tr>
      <th>Horário</th><th>Dono</th><th>Status</th><th>Tentativas</th>
      <th>Última tentativa</th><th>Telefone</th><th>Ações</th>
    </tr></thead>
    <tbody>{linhas}</tbody>
  </table>
</main>
</body></html>"""
