import logging
import os
import sqlite3
import threading
import time

log = logging.getLogger("mentall.db")

TURSO_URL = os.getenv("TURSO_DATABASE_URL", "").strip()
TURSO_TOKEN = os.getenv("TURSO_AUTH_TOKEN", "").strip()

_conexao = None
_conexao_lock = threading.Lock()
_usa_turso = False
_turso_ultima_tentativa = 0.0
TURSO_RECONNECT_INTERVAL = 60.0


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


def _tentar_conectar_turso():
    """Tenta conectar ao Turso. Retorna a conexao ou None em caso de falha."""
    try:
        conn = _conectar_turso()
        conn.execute("SELECT 1")
        log.info("Turso conectado.")
        return conn
    except Exception as e:
        log.error("Falha ao conectar ao Turso: %s", e)
        return None


def _criar_tabelas(conn) -> None:
    for sql in _tabelas + _indices:
        conn.execute(sql)
    conn.commit()
    log.info("Tabelas verificadas/criadas com sucesso.")


def _obter_conexao():
    global _conexao, _usa_turso, _turso_ultima_tentativa

    if _conexao is not None:
        try:
            _conexao.execute("SELECT 1")
            if not _usa_turso and TURSO_URL and TURSO_TOKEN:
                agora = time.time()
                if agora - _turso_ultima_tentativa >= TURSO_RECONNECT_INTERVAL:
                    _turso_ultima_tentativa = agora
                    log.warning("Em fallback SQLite local. Tentando reconectar ao Turso...")
                    nova = _tentar_conectar_turso()
                    if nova is not None:
                        with _conexao_lock:
                            _conexao = nova
                            _usa_turso = True
                        log.info("Reconectado ao Turso. Dados persistidos novamente.")
            return _conexao
        except Exception:
            log.warning("Conexao perdida. Reconectando...")
            with _conexao_lock:
                _conexao = None

    with _conexao_lock:
        if _conexao is not None:
            return _conexao

        _turso_ultima_tentativa = time.time()
        if TURSO_URL and TURSO_TOKEN:
            log.info("Conectando ao Turso: %s", TURSO_URL[:60])
            nova = _tentar_conectar_turso()
            if nova is not None:
                _conexao = nova
                _usa_turso = True
                return _conexao

        log.critical(
            "ATENCAO: Turso indisponivel. Usando SQLite local (efemero). "
            "Os dados NAO persistirao entre reinicios. Verifique a conexao com o Turso."
        )
        _conexao = _conectar_local()
        _usa_turso = False
        _criar_tabelas(_conexao)
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
        enviado_em TEXT,
        tentativas INTEGER NOT NULL DEFAULT 0,
        ultima_tentativa_em TEXT,
        mensagem_id TEXT,
        entregue_em TEXT,
        lido_em TEXT
    )""",
    """CREATE TABLE IF NOT EXISTS recuperacoes (
        email_hash TEXT PRIMARY KEY,
        recovery_token TEXT NOT NULL DEFAULT '',
        codigo_hash TEXT,
        codigo_expiracao TEXT,
        tentativas INTEGER NOT NULL DEFAULT 0,
        bloqueio_ate TEXT,
        criado_em TEXT NOT NULL
    )""",
    """CREATE TABLE IF NOT EXISTS usuarios (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        nome TEXT NOT NULL DEFAULT '',
        plano TEXT NOT NULL DEFAULT 'gratis',
        status TEXT NOT NULL DEFAULT 'pendente',
        criado_em TEXT NOT NULL,
        ultimo_acesso_em TEXT,
        email_verificacao_token_hash TEXT,
        email_verificacao_expiracao TEXT
    )""",
    """CREATE TABLE IF NOT EXISTS wuzapi_instancias (
        owner_id TEXT PRIMARY KEY,
        wuzapi_token TEXT NOT NULL DEFAULT '',
        wuzapi_user_id INTEGER DEFAULT 0,
        conectado INTEGER NOT NULL DEFAULT 0,
        atualizado_em TEXT NOT NULL
    )""",
]

_indices = [
    "CREATE INDEX IF NOT EXISTS idx_contratos_owner ON contratos(owner_id)",
    "CREATE INDEX IF NOT EXISTS idx_anamneses_owner ON anamneses(owner_id)",
    "CREATE INDEX IF NOT EXISTS idx_lembretes_owner ON lembretes(owner_id)",
    "CREATE INDEX IF NOT EXISTS idx_wuzapi_instancias_owner ON wuzapi_instancias(owner_id)",
]

try:
    conn = _obter_conexao()
    _criar_tabelas(conn)
except Exception as e:
    log.exception("Erro ao criar tabelas: %s", e)
    raise


def _colunas(tabela: str) -> set:
    try:
        rows = executar(f"PRAGMA table_info({tabela})").fetchall()
        return {r["name"] for r in rows}
    except Exception:
        return set()


def _garantir_coluna(tabela: str, coluna: str, tipo: str) -> None:
    if coluna not in _colunas(tabela):
        executar(f"ALTER TABLE {tabela} ADD COLUMN {coluna} {tipo}").commit()
        log.info("Migracao: coluna %s.%s adicionada.", tabela, coluna)


# Migracoes incrementais (para bancos ja existentes)
_garantir_coluna("usuarios", "email_verificacao_token_hash", "TEXT")
_garantir_coluna("usuarios", "email_verificacao_expiracao", "TEXT")
_garantir_coluna("recuperacoes", "codigo_hash", "TEXT")
_garantir_coluna("recuperacoes", "tentativas", "INTEGER NOT NULL DEFAULT 0")
_garantir_coluna("recuperacoes", "bloqueio_ate", "TEXT")
_garantir_coluna("lembretes", "tentativas", "INTEGER NOT NULL DEFAULT 0")
_garantir_coluna("lembretes", "ultima_tentativa_em", "TEXT")
_garantir_coluna("lembretes", "mensagem_id", "TEXT")
_garantir_coluna("lembretes", "entregue_em", "TEXT")
_garantir_coluna("lembretes", "lido_em", "TEXT")
