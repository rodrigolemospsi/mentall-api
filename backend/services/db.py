import logging
import os
import sqlite3
import threading

log = logging.getLogger("mentall.db")

TURSO_URL = os.getenv("TURSO_DATABASE_URL", "").strip()
TURSO_TOKEN = os.getenv("TURSO_AUTH_TOKEN", "").strip()

_conexao = None
_conexao_lock = threading.Lock()
_usa_turso = False


def _conectar_local():
    data_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data")
    os.makedirs(data_dir, exist_ok=True)
    db_path = os.path.join(data_dir, "mentall.db")
    conn = sqlite3.connect(db_path, check_same_thread=False)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA busy_timeout=5000")
    conn.row_factory = sqlite3.Row
    return conn


def _conectar_turso():
    import libsql
    return libsql.connect(database=TURSO_URL, auth_token=TURSO_TOKEN)


def _to_dict(row, cursor):
    if row is None:
        return None
    if isinstance(row, dict):
        return row
    if isinstance(row, sqlite3.Row):
        return dict(row)
    try:
        if cursor is not None and cursor.description is not None:
            cols = [col[0] for col in cursor.description]
            return dict(zip(cols, row))
    except Exception:
        pass
    return row


def _obter_conexao():
    global _conexao, _usa_turso
    if _conexao is not None:
        try:
            _conexao.execute("SELECT 1")
            return _conexao
        except Exception:
            log.warning("Conexao perdida. Reconectando...")
            with _conexao_lock:
                _conexao = None

    with _conexao_lock:
        if _conexao is not None:
            return _conexao

        if TURSO_URL and TURSO_TOKEN:
            log.info("Conectando ao Turso: %s", TURSO_URL[:60])
            try:
                _conexao = _conectar_turso()
                _conexao.execute("SELECT 1")
                _usa_turso = True
                log.info("Turso conectado.")
                return _conexao
            except Exception as e:
                log.error("Falha ao conectar ao Turso: %s. Fallback para SQLite local.", e)
                _conexao = None
                _usa_turso = False

        log.info("Usando SQLite local.")
        _conexao = _conectar_local()
        _usa_turso = False
        return _conexao


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
    """CREATE TABLE IF NOT EXISTS recuperacoes (
        email_hash TEXT PRIMARY KEY,
        recovery_token TEXT NOT NULL DEFAULT '',
        codigo TEXT,
        codigo_expiracao TEXT,
        criado_em TEXT NOT NULL
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
