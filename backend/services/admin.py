"""Consultas do painel do dono (Fase 3).

LGPD: só números (contagens, plano, aparelho, presença). Nenhuma tabela
consultada aqui contém dado clínico.
"""
import logging
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


def listar_usuarios(pagina: int = 1, limite: int = 25, busca: str = "") -> dict:
    pagina = max(1, int(pagina))
    limite = max(1, min(100, int(limite)))
    offset = (pagina - 1) * limite
    termo = f"%{(busca or '').strip()}%"

    total = executar(
        "SELECT COUNT(*) AS c FROM usuarios WHERE email LIKE ? OR nome LIKE ?",
        (termo, termo),
    ).fetchone()["c"]

    linhas = executar(
        "SELECT id, email, nome, plano, role, status, criado_em, ultimo_acesso_em "
        "FROM usuarios WHERE email LIKE ? OR nome LIKE ? "
        "ORDER BY criado_em DESC LIMIT ? OFFSET ?",
        (termo, termo, limite, offset),
    ).fetchall()

    limite_online = _limite_online_iso()
    usuarios = []
    for row in linhas:
        dev = executar(
            "SELECT plataforma, versao_app, ultimo_heartbeat_em FROM dispositivos "
            "WHERE owner_id = ? ORDER BY ultimo_heartbeat_em DESC LIMIT 1",
            (row["id"],),
        ).fetchone()
        ultimo_hb = dev["ultimo_heartbeat_em"] if dev else None
        usuarios.append({
            **row,
            "online": bool(ultimo_hb and ultimo_hb >= limite_online),
            "ultimo_hb": ultimo_hb,
            "aparelho": (dev["plataforma"] if dev else "") or "",
            "versao_app": (dev["versao_app"] if dev else "") or "",
        })

    return {"total": total, "pagina": pagina, "limite": limite, "usuarios": usuarios}
