"""Telemetria (Fase 2): presença (heartbeat) e uso (eventos).

LGPD: só entram números — `owner_id`, `device_id` (UUID aleatório do aparelho),
plataforma, versão do app e o **tipo** do evento. Nunca nome de paciente nem
conteúdo clínico. O `tipo` é validado por allowlist.
"""
import logging
import uuid
from datetime import datetime, timezone

from services.db import executar

log = logging.getLogger("mentall.telemetria")

# Allowlist de eventos de uso (sem qualquer conteúdo clínico).
EVENTOS_PERMITIDOS = frozenset({
    "sessao_salva",
    "transcricao",
    "sintese",
    "paciente_criado",
    "contrato_enviado",
    "anamnese_enviada",
})


def registrar_heartbeat(
    owner_id: str,
    device_id: str,
    plataforma: str = "",
    versao_app: str = "",
) -> None:
    """Upsert do dispositivo; atualiza o `ultimo_heartbeat_em` (online/offline)."""
    agora = datetime.now(timezone.utc).isoformat()
    executar(
        "INSERT INTO dispositivos "
        "(device_id, owner_id, plataforma, versao_app, ultimo_heartbeat_em, criado_em) "
        "VALUES (?, ?, ?, ?, ?, ?) "
        "ON CONFLICT(device_id) DO UPDATE SET "
        "owner_id = excluded.owner_id, plataforma = excluded.plataforma, "
        "versao_app = excluded.versao_app, ultimo_heartbeat_em = excluded.ultimo_heartbeat_em",
        (device_id, owner_id, plataforma, versao_app, agora, agora),
    ).commit()


def registrar_evento(owner_id: str, device_id: str, tipo: str) -> bool:
    """Grava um evento de uso. Retorna False se o tipo não está na allowlist."""
    if tipo not in EVENTOS_PERMITIDOS:
        log.warning("Evento de telemetria recusado (tipo nao permitido).")
        return False
    agora = datetime.now(timezone.utc).isoformat()
    executar(
        "INSERT INTO eventos (id, owner_id, device_id, tipo, criado_em) VALUES (?, ?, ?, ?, ?)",
        (str(uuid.uuid4()), owner_id, device_id, tipo, agora),
    ).commit()
    return True
