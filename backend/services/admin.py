"""Consultas do painel do dono (Fase 3).

LGPD: só números (contagens, plano, aparelho, presença). Nenhuma tabela
consultada aqui contém dado clínico.
"""
import logging
import re
import uuid
from datetime import datetime, timedelta, timezone

from services.db import executar

log = logging.getLogger("mentall.admin")

# Janela de presença. O app envia heartbeat no boot, a cada 60s em primeiro
# plano, ao pausar e ao retomar. Uma janela maior que o intervalo cobre o caso
# em que o Android suspende o app (tela apagada / troca de app) — antes eram
# 5 min e o usuário aparecia offline mesmo com o app aberto.
ONLINE_JANELA_MINUTOS = 10


def _limite_online_iso() -> str:
    return (datetime.now(timezone.utc) - timedelta(minutes=ONLINE_JANELA_MINUTOS)).isoformat()


def kpis() -> dict:
    total = executar("SELECT COUNT(*) AS c FROM usuarios").fetchone()["c"]
    limite = _limite_online_iso()
    online = executar(
        "SELECT COUNT(DISTINCT owner_id) AS c FROM dispositivos WHERE ultimo_heartbeat_em >= ?",
        (limite,),
    ).fetchone()["c"]
    aparelhos = [
        (r["plataforma"], r["c"])
        for r in executar(
            "SELECT plataforma, COUNT(*) AS c FROM dispositivos "
            "GROUP BY plataforma ORDER BY c DESC"
        ).fetchall()
    ]
    eventos = [
        (r["tipo"], r["c"])
        for r in executar(
            "SELECT tipo, COUNT(*) AS c FROM eventos GROUP BY tipo ORDER BY c DESC"
        ).fetchall()
    ]
    return {
        "total_usuarios": total,
        "online_agora": online,
        "aparelhos": aparelhos,
        "eventos_por_tipo": eventos,
    }


ORDENACOES_USUARIOS = {
    "criado_desc": "u.criado_em DESC",
    "criado_asc": "u.criado_em ASC",
    "acesso_desc": "u.ultimo_acesso_em DESC",
    "email_asc": "u.email ASC",
}


def _where_usuarios(busca="", status="", plano="", online="", versao=""):
    """Monta WHERE/params dos filtros do painel (Fase 5A.2)."""
    condicoes = ["(u.email LIKE ? OR u.nome LIKE ?)"]
    params = [f"%{(busca or '').strip()}%", f"%{(busca or '').strip()}%"]
    if status:
        condicoes.append("u.status = ?")
        params.append(status)
    if plano:
        condicoes.append("u.plano = ?")
        params.append(plano)
    if versao:
        condicoes.append(
            "EXISTS (SELECT 1 FROM dispositivos dv WHERE dv.owner_id = u.id AND dv.versao_app = ?)"
        )
        params.append(versao)
    if online in ("1", "0"):
        limite = _limite_online_iso()
        if online == "1":
            condicoes.append(
                "EXISTS (SELECT 1 FROM dispositivos dh WHERE dh.owner_id = u.id "
                "AND dh.ultimo_heartbeat_em >= ?)"
            )
        else:
            condicoes.append(
                "NOT EXISTS (SELECT 1 FROM dispositivos dh WHERE dh.owner_id = u.id "
                "AND dh.ultimo_heartbeat_em >= ?)"
            )
        params.append(limite)
    return " AND ".join(condicoes), params


def _ordem_usuarios(ordenar: str) -> str:
    return ORDENACOES_USUARIOS.get((ordenar or "").strip().lower(), ORDENACOES_USUARIOS["criado_desc"])


def listar_usuarios(
    pagina: int = 1,
    limite: int = 25,
    busca: str = "",
    status: str = "",
    plano: str = "",
    online: str = "",
    versao: str = "",
    ordenar: str = "criado_desc",
) -> dict:
    """Lista paginada de psicólogos com filtros, em UMA consulta (sem N+1)."""
    pagina = max(1, int(pagina))
    limite = max(1, min(100, int(limite)))
    offset = (pagina - 1) * limite
    where, params = _where_usuarios(busca, status, plano, online, versao)

    total = executar(
        f"SELECT COUNT(*) AS c FROM usuarios u WHERE {where}", tuple(params)
    ).fetchone()["c"]

    linhas = executar(
        "SELECT u.id, u.email, u.nome, u.plano, u.role, u.status, u.criado_em, "
        "u.ultimo_acesso_em, d.plataforma, d.versao_app, d.ultimo_heartbeat_em "
        "FROM usuarios u LEFT JOIN dispositivos d ON d.device_id = ("
        "  SELECT device_id FROM dispositivos WHERE owner_id = u.id "
        "  ORDER BY ultimo_heartbeat_em DESC LIMIT 1) "
        f"WHERE {where} ORDER BY {_ordem_usuarios(ordenar)} LIMIT ? OFFSET ?",
        tuple(params) + (limite, offset),
    ).fetchall()

    limite_online = _limite_online_iso()
    usuarios = []
    for row in linhas:
        ultimo_hb = row["ultimo_heartbeat_em"]
        usuarios.append({
            "id": row["id"],
            "email": row["email"],
            "nome": row["nome"],
            "plano": row["plano"],
            "role": row["role"],
            "status": row["status"],
            "criado_em": row["criado_em"],
            "ultimo_acesso_em": row["ultimo_acesso_em"],
            "online": bool(ultimo_hb and ultimo_hb >= limite_online),
            "ultimo_hb": ultimo_hb,
            "aparelho": row["plataforma"] or "",
            "versao_app": row["versao_app"] or "",
        })

    return {"total": total, "pagina": pagina, "limite": limite, "usuarios": usuarios}


def exportar_usuarios(
    busca: str = "",
    status: str = "",
    plano: str = "",
    online: str = "",
    versao: str = "",
    ordenar: str = "criado_desc",
    limite_maximo: int = 5000,
) -> list[dict]:
    """Linhas da listagem (sem paginação) para exportação CSV."""
    where, params = _where_usuarios(busca, status, plano, online, versao)
    linhas = executar(
        "SELECT u.email, u.nome, u.plano, u.role, u.status, u.criado_em, u.ultimo_acesso_em, "
        "d.plataforma, d.versao_app, d.ultimo_heartbeat_em "
        "FROM usuarios u LEFT JOIN dispositivos d ON d.device_id = ("
        "  SELECT device_id FROM dispositivos WHERE owner_id = u.id "
        "  ORDER BY ultimo_heartbeat_em DESC LIMIT 1) "
        f"WHERE {where} ORDER BY {_ordem_usuarios(ordenar)} LIMIT ?",
        tuple(params) + (max(1, int(limite_maximo)),),
    ).fetchall()
    return [dict(linha) for linha in linhas]


def _contar_n(sql: str, params=()) -> int:
    linha = executar(sql, params).fetchone()
    return int(linha["n"]) if linha else 0


def kpis_operacionais() -> dict:
    """Contagens operacionais do painel (Fase 5A).

    LGPD: só números e metadados de status — nenhum conteúdo clínico.
    """
    agora = datetime.now(timezone.utc)
    desde_7d = (agora - timedelta(days=7)).isoformat()
    desde_30d = (agora - timedelta(days=30)).isoformat()

    versoes = [
        ((r["versao_app"] or "desconhecida"), int(r["n"]))
        for r in executar(
            "SELECT versao_app, COUNT(*) AS n FROM dispositivos "
            "WHERE versao_app <> '' GROUP BY versao_app ORDER BY n DESC LIMIT 3"
        ).fetchall()
    ]
    return {
        "novos_7d": _contar_n("SELECT COUNT(*) AS n FROM usuarios WHERE criado_em >= ?", (desde_7d,)),
        "novos_30d": _contar_n("SELECT COUNT(*) AS n FROM usuarios WHERE criado_em >= ?", (desde_30d,)),
        "usuarios_ativos": _contar_n("SELECT COUNT(*) AS n FROM usuarios WHERE status = 'ativo'"),
        "usuarios_pendentes": _contar_n("SELECT COUNT(*) AS n FROM usuarios WHERE status = 'pendente'"),
        "contratos_aceitos": _contar_n("SELECT COUNT(*) AS n FROM contratos WHERE status = 'aceito'"),
        "contratos_pendentes": _contar_n("SELECT COUNT(*) AS n FROM contratos WHERE status = 'pendente'"),
        "anamneses_respondidas": _contar_n(
            "SELECT COUNT(*) AS n FROM anamneses WHERE status = 'respondido'"
        ),
        "anamneses_pendentes": _contar_n(
            "SELECT COUNT(*) AS n FROM anamneses WHERE status = 'pendente'"
        ),
        "lembretes_enviados": _contar_n("SELECT COUNT(*) AS n FROM lembretes WHERE status = 'enviado'"),
        "lembretes_entregues": _contar_n(
            "SELECT COUNT(*) AS n FROM lembretes WHERE entregue_em IS NOT NULL"
        ),
        "lembretes_lidos": _contar_n("SELECT COUNT(*) AS n FROM lembretes WHERE lido_em IS NOT NULL"),
        "lembretes_falhas": _contar_n("SELECT COUNT(*) AS n FROM lembretes WHERE status = 'falha'"),
        "lembretes_pendentes": _contar_n("SELECT COUNT(*) AS n FROM lembretes WHERE status = 'pendente'"),
        "versoes": versoes,
    }


def opcoes_filtros() -> dict:
    """Valores distintos para os selects de filtro do painel."""

    def distintos(sql: str) -> list:
        try:
            return [str(r["v"]) for r in executar(sql).fetchall() if r["v"]]
        except Exception:
            log.exception("Falha ao carregar opções de filtro")
            return []

    return {
        "status": distintos("SELECT DISTINCT status AS v FROM usuarios ORDER BY v"),
        "planos": distintos("SELECT DISTINCT plano AS v FROM usuarios ORDER BY v"),
        "versoes": distintos(
            "SELECT DISTINCT versao_app AS v FROM dispositivos "
            "WHERE versao_app <> '' ORDER BY v DESC LIMIT 12"
        ),
    }


def registrar_auditoria(ator: str, acao: str, alvo: str = "", detalhe: str = "", ip: str = "") -> None:
    """Registra uma ação administrativa do painel (responsabilização/LGPD)."""
    try:
        executar(
            "INSERT INTO admin_auditoria (id, ator, acao, alvo, detalhe, ip, criado_em) "
            "VALUES (?, ?, ?, ?, ?, ?, ?)",
            (
                uuid.uuid4().hex,
                (ator or "")[:160],
                (acao or "")[:80],
                (alvo or "")[:200],
                (detalhe or "")[:400],
                (ip or "")[:64],
                datetime.now(timezone.utc).isoformat(),
            ),
        ).commit()
    except Exception:
        log.exception("Falha ao registrar auditoria administrativa")


def listar_auditoria(limite: int = 10, alvo: str = "") -> list[dict]:
    """Últimas ações administrativas (todas ou de um alvo específico)."""
    try:
        limite = max(1, min(100, int(limite)))
        if alvo:
            return executar(
                "SELECT ator, acao, alvo, detalhe, criado_em FROM admin_auditoria "
                "WHERE alvo = ? ORDER BY criado_em DESC LIMIT ?",
                (alvo, limite),
            ).fetchall()
        return executar(
            "SELECT ator, acao, alvo, detalhe, criado_em FROM admin_auditoria "
            "ORDER BY criado_em DESC LIMIT ?",
            (limite,),
        ).fetchall()
    except Exception:
        log.exception("Falha ao ler auditoria administrativa")
        return []


def detalhar_usuario(usuario_id: str) -> dict | None:
    """Metadados operacionais do usuário — sem conteúdo clínico (LGPD)."""
    usuario = executar(
        "SELECT id, email, nome, plano, role, status, criado_em, ultimo_acesso_em "
        "FROM usuarios WHERE id = ?",
        (usuario_id,),
    ).fetchone()
    if usuario is None:
        return None

    dispositivos = executar(
        "SELECT plataforma, versao_app, ultimo_heartbeat_em, criado_em FROM dispositivos "
        "WHERE owner_id = ? ORDER BY ultimo_heartbeat_em DESC",
        (usuario_id,),
    ).fetchall()
    limite_online = _limite_online_iso()
    ultimo_hb = dispositivos[0]["ultimo_heartbeat_em"] if dispositivos else None

    eventos_por_tipo = [
        (r["tipo"], int(r["n"]))
        for r in executar(
            "SELECT tipo, COUNT(*) AS n FROM eventos WHERE owner_id = ? "
            "GROUP BY tipo ORDER BY n DESC",
            (usuario_id,),
        ).fetchall()
    ]
    eventos_recentes = executar(
        "SELECT tipo, criado_em FROM eventos WHERE owner_id = ? "
        "ORDER BY criado_em DESC LIMIT 10",
        (usuario_id,),
    ).fetchall()

    def contar(tabela: str, status: str) -> int:
        return _contar_n(
            f"SELECT COUNT(*) AS n FROM {tabela} WHERE owner_id = ? AND status = ?",
            (usuario_id, status),
        )

    wuzapi = executar(
        "SELECT conectado FROM wuzapi_instancias WHERE owner_id = ?", (usuario_id,)
    ).fetchone()

    return {
        "usuario": usuario,
        "online": bool(ultimo_hb and ultimo_hb >= limite_online),
        "dispositivos": dispositivos,
        "eventos_por_tipo": eventos_por_tipo,
        "eventos_recentes": eventos_recentes,
        "contratos": {
            "aceitos": contar("contratos", "aceito"),
            "pendentes": contar("contratos", "pendente"),
        },
        "anamneses": {
            "respondidas": contar("anamneses", "respondido"),
            "pendentes": contar("anamneses", "pendente"),
        },
        "lembretes": {
            "enviados": contar("lembretes", "enviado"),
            "entregues": _contar_n(
                "SELECT COUNT(*) AS n FROM lembretes WHERE owner_id = ? AND entregue_em IS NOT NULL",
                (usuario_id,),
            ),
            "lidos": _contar_n(
                "SELECT COUNT(*) AS n FROM lembretes WHERE owner_id = ? AND lido_em IS NOT NULL",
                (usuario_id,),
            ),
            "falhas": contar("lembretes", "falha"),
            "pendentes": contar("lembretes", "pendente"),
        },
        "wuzapi_conectado": bool(wuzapi["conectado"]) if wuzapi else None,
        "auditoria": listar_auditoria(limite=10, alvo=usuario["email"]),
    }


STATUS_USUARIO_PERMITIDOS = ("ativo", "suspenso")
_PLANO_VALIDO = re.compile(r"^[a-z0-9][a-z0-9_-]{1,29}$")


def definir_status_usuario(usuario_id: str, status: str) -> bool:
    """Ativa/suspende a conta. Suspensa não loga (nem no app nem no painel)."""
    if status not in STATUS_USUARIO_PERMITIDOS:
        raise ValueError("Status inválido.")
    cur = executar("UPDATE usuarios SET status = ? WHERE id = ?", (status, usuario_id))
    cur.commit()
    return cur.rowcount == 1


def definir_plano_usuario(usuario_id: str, plano: str) -> bool:
    """Troca o plano do usuário (campo livre controlado — cobrança virá depois)."""
    plano = (plano or "").strip().lower()
    if not _PLANO_VALIDO.match(plano):
        raise ValueError("Plano inválido (use letras minúsculas, números, - ou _).")
    cur = executar("UPDATE usuarios SET plano = ? WHERE id = ?", (plano, usuario_id))
    cur.commit()
    return cur.rowcount == 1


PAPEIS_USUARIO_PERMITIDOS = ("admin", "financeiro", "suporte", "user")


def definir_papel_usuario(usuario_id: str, papel: str) -> bool:
    """Troca o papel do usuário (RBAC do painel). Só admin chega aqui."""
    papel = (papel or "").strip().lower()
    if papel not in PAPEIS_USUARIO_PERMITIDOS:
        raise ValueError("Papel inválido.")
    cur = executar("UPDATE usuarios SET role = ? WHERE id = ?", (papel, usuario_id))
    cur.commit()
    return cur.rowcount == 1


def revogar_sessoes_app(usuario_id: str) -> int:
    """Encerra todas as sessões do app do usuário (incrementa token_version)."""
    from services.usuarios import incrementar_token_version

    return incrementar_token_version(usuario_id)


STATUS_LEMBRETE_VALIDOS = ("pendente", "enviado", "falha", "cancelado")
DIAS_FALHA_ANTIGA = 7


def _mascarar_telefone(valor: str) -> str:
    """Mascara o telefone (PII): mantém só os 4 últimos dígitos."""
    texto = str(valor or "").strip()
    if len(texto) <= 4:
        return "****"
    return "*" * (len(texto) - 4) + texto[-4:]


def resumo_lembretes() -> dict:
    """Contagens de lembretes para o painel (uma única consulta)."""
    agora = datetime.now(timezone.utc).isoformat()
    limite_7d = (datetime.now(timezone.utc) - timedelta(days=DIAS_FALHA_ANTIGA)).isoformat()
    linha = executar(
        "SELECT "
        "(SELECT COUNT(*) FROM lembretes) AS total, "
        "(SELECT COUNT(*) FROM lembretes WHERE status = 'pendente') AS pendentes, "
        "(SELECT COUNT(*) FROM lembretes WHERE status = 'enviado') AS enviados, "
        "(SELECT COUNT(*) FROM lembretes WHERE status = 'falha') AS falhas, "
        "(SELECT COUNT(*) FROM lembretes WHERE status = 'cancelado') AS cancelados, "
        "(SELECT COUNT(*) FROM lembretes WHERE status = 'pendente' AND horario_envio < ?) AS atrasados, "
        "(SELECT COUNT(*) FROM lembretes WHERE status = 'falha' AND horario_envio >= ?) AS falhas_recentes, "
        "(SELECT COUNT(*) FROM lembretes WHERE status = 'falha' AND horario_envio < ?) AS falhas_antigas",
        (agora, limite_7d, limite_7d),
    ).fetchone()
    return {chave: int(linha[chave] or 0) for chave in linha.keys()}


def listar_lembretes_painel(status: str = "", limite: int = 50) -> list[dict]:
    """Lembretes para o painel — só metadados (LGPD: nunca seleciona `mensagem`)."""
    status = (status or "").strip().lower()
    if status not in STATUS_LEMBRETE_VALIDOS:
        status = ""
    limite = max(1, min(200, int(limite)))
    linhas = executar(
        "SELECT l.id, l.compromisso_id, l.telefone, l.horario_envio, l.canal, l.status, "
        "l.tentativas, l.ultima_tentativa_em, l.enviado_em, l.entregue_em, l.lido_em, "
        "COALESCE(u.email, '') AS dono_email "
        "FROM lembretes l LEFT JOIN usuarios u ON u.id = l.owner_id "
        "WHERE (? = '' OR l.status = ?) "
        "ORDER BY l.horario_envio DESC LIMIT ?",
        (status, status, limite),
    ).fetchall()
    itens = []
    for linha in linhas:
        item = dict(linha)
        item["telefone"] = _mascarar_telefone(item.get("telefone"))
        itens.append(item)
    return itens


def reenviar_lembrete(lembrete_id: str) -> bool:
    """Recoloca um lembrete falho/cancelado na fila, para envio imediato."""
    agora = datetime.now(timezone.utc).isoformat()
    cur = executar(
        "UPDATE lembretes SET status = 'pendente', horario_envio = ?, tentativas = 0, "
        "ultima_tentativa_em = NULL "
        "WHERE id = ? AND status IN ('falha', 'cancelado')",
        (agora, lembrete_id),
    )
    cur.commit()
    return (cur.rowcount or 0) == 1


def arquivar_lembrete(lembrete_id: str) -> bool:
    """Arquiva (soft-cancel) um lembrete falho/pendente."""
    cur = executar(
        "UPDATE lembretes SET status = 'cancelado' "
        "WHERE id = ? AND status IN ('falha', 'pendente')",
        (lembrete_id,),
    )
    cur.commit()
    return (cur.rowcount or 0) == 1


def arquivar_falhas_antigas(dias: int = DIAS_FALHA_ANTIGA) -> int:
    """Arquiva falhas com horário anterior à janela indicada. Retorna o total."""
    limite = (datetime.now(timezone.utc) - timedelta(days=max(1, int(dias)))).isoformat()
    cur = executar(
        "UPDATE lembretes SET status = 'cancelado' "
        "WHERE status = 'falha' AND horario_envio < ?",
        (limite,),
    )
    cur.commit()
    return cur.rowcount or 0
