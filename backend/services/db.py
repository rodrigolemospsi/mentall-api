import logging
import os
import sqlite3
from functools import lru_cache

log = logging.getLogger("mentall.db")

TURSO_URL = os.getenv("TURSO_DATABASE_URL", "").strip()
TURSO_TOKEN = os.getenv("TURSO_AUTH_TOKEN", "").strip()


def _conectar_local():
    data_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data")
    os.makedirs(data_dir, exist_ok=True)
    db_path = os.path.join(data_dir, "mentall.db")
    conn = sqlite3.connect(db_path, check_same_thread=False)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA busy_timeout=5000")
    return conn


def _conectar_turso():
    import libsql
    return libsql.connect(database=TURSO_URL, auth_token=TURSO_TOKEN)


def _to_dict(row, cursor):
    if row is None:
        return None
    if isinstance(row, dict):
        return row
    try:
        if cursor.description is None:
            return row
        cols = [col[0] for col in cursor.description]
        return dict(zip(cols, row))
    except Exception:
        return row


@lru_cache(maxsize=1)
def _obter_conexao():
    if TURSO_URL and TURSO_TOKEN:
        log.info("Conectando ao Turso: %s", TURSO_URL[:60])
        return _conectar_turso()
    log.info("Turso nao configurado. Usando SQLite local.")
    return _conectar_local()


def executar(sql: str, params=()):
    conn = _obter_conexao()
    cursor = conn.execute(sql, params)
    return _CursorWrapper(cursor, conn)


class _CursorWrapper:
    def __init__(self, cursor, connection):
        self._cursor = cursor
        self._connection = connection

    @property
    def rowcount(self):
        return self._cursor.rowcount

    def fetchone(self):
        row = self._cursor.fetchone()
        return _to_dict(row, self._cursor)

    def fetchall(self):
        rows = self._cursor.fetchall()
        return [_to_dict(r, self._cursor) for r in rows]

    def commit(self):
        self._connection.commit()

    def executescript(self, sql: str):
        for stmt in sql.split(";"):
            stmt = stmt.strip()
            if stmt:
                self._cursor = self._connection.execute(stmt)
        return self


def reset_cache():
    _obter_conexao.cache_clear()


_tabelas = [
    """CREATE TABLE IF NOT EXISTS contratos (
        token TEXT PRIMARY KEY,
        dados TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pendente',
        owner_id TEXT NOT NULL DEFAULT '',
        criado_em TEXT NOT NULL,
        aceito_em TEXT,
        nome_aceite TEXT
    )""",
    """CREATE TABLE IF NOT EXISTS anamneses (
        token TEXT PRIMARY KEY,
        template_json TEXT NOT NULL,
        owner_id TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'pendente',
        respostas TEXT,
        criado_em TEXT NOT NULL,
        respondido_em TEXT,
        dados_extra TEXT NOT NULL DEFAULT '{}'
    )""",
    """CREATE TABLE IF NOT EXISTS lembretes (
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
    )""",
]

_indices = [
    "CREATE INDEX IF NOT EXISTS idx_contratos_owner ON contratos(owner_id)",
    "CREATE INDEX IF NOT EXISTS idx_anamneses_owner ON anamneses(owner_id)",
    "CREATE INDEX IF NOT EXISTS idx_lembretes_owner ON lembretes(owner_id)",
]

try:
    conn = _obter_conexao()
    for sql in _tabelas + _indices:
        conn.execute(sql)
    conn.commit()
    log.info("Tabelas verificadas/criadas com sucesso.")
except Exception as e:
    log.exception("Erro ao criar tabelas: %s", e)
    raise
