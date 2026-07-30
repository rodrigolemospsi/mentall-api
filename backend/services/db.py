import logging
import os
import sqlite3
from functools import lru_cache

log = logging.getLogger("mentall.db")

TURSO_URL = os.getenv("TURSO_DATABASE_URL", "")
TURSO_TOKEN = os.getenv("TURSO_AUTH_TOKEN", "")


def _row_factory(cursor, row):
    return dict(zip([col[0] for col in cursor.description], row))


def _conectar_local() -> sqlite3.Connection:
    data_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data")
    os.makedirs(data_dir, exist_ok=True)
    db_path = os.path.join(data_dir, "mentall.db")
    conn = sqlite3.connect(db_path, check_same_thread=False)
    conn.row_factory = _row_factory
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA busy_timeout=5000")
    return conn


def _conectar_turso() -> sqlite3.Connection:
    import libsql

    conn = libsql.connect(
        database=TURSO_URL,
        auth_token=TURSO_TOKEN,
    )
    conn.row_factory = _row_factory
    return conn


@lru_cache(maxsize=1)
def _obter_conexao() -> sqlite3.Connection:
    if TURSO_URL and TURSO_TOKEN:
        log.info("Conectando ao Turso: %s", TURSO_URL[:60])
        return _conectar_turso()
    log.info("Turso nao configurado. Usando SQLite local.")
    return _conectar_local()


def _criar_tabelas() -> None:
    conn = _obter_conexao()
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS contratos (
            token TEXT PRIMARY KEY,
            dados TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pendente',
            owner_id TEXT NOT NULL DEFAULT '',
            criado_em TEXT NOT NULL,
            aceito_em TEXT,
            nome_aceite TEXT
        );

        CREATE TABLE IF NOT EXISTS anamneses (
            token TEXT PRIMARY KEY,
            template_json TEXT NOT NULL,
            owner_id TEXT NOT NULL DEFAULT '',
            status TEXT NOT NULL DEFAULT 'pendente',
            respostas TEXT,
            criado_em TEXT NOT NULL,
            respondido_em TEXT,
            dados_extra TEXT NOT NULL DEFAULT '{}'
        );

        CREATE TABLE IF NOT EXISTS lembretes (
            id TEXT PRIMARY KEY,
            compromisso_id TEXT NOT NULL,
            telefone TEXT NOT NULL DEFAULT '',
            mensagem TEXT NOT NULL DEFAULT '',
            horario_envio TEXT NOT NULL,
            canal TEXT NOT NULL DEFAULT 'whatsapp',
            status TEXT NOT NULL DEFAULT 'pendente',
            owner_id TEXT NOT NULL DEFAULT '',
            criado_em TEXT NOT NULL,
            enviado_em TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_contratos_owner ON contratos(owner_id);
        CREATE INDEX IF NOT EXISTS idx_anamneses_owner ON anamneses(owner_id);
        CREATE INDEX IF NOT EXISTS idx_lembretes_owner ON lembretes(owner_id);
    """)
    conn.commit()
    log.info("Tabelas verificadas/criadas com sucesso.")


def reset_cache() -> None:
    _obter_conexao.cache_clear()
    _criar_tabelas()


_criar_tabelas()
