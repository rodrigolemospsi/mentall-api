"""Migra os dados do Turso para o SQLite persistente do volume do Fly.

Executar DENTRO da máquina (enquanto os secrets do Turso ainda existem):
    python /app/scripts/migrar_turso_para_sqlite.py

Lê do ambiente: TURSO_DATABASE_URL, TURSO_AUTH_TOKEN, SQLITE_PATH.
Seguro para reexecutar: cria só o que falta e usa INSERT OR REPLACE.
"""
import os
import sqlite3
import sys

TABELAS_IGNORADAS = {"sqlite_sequence"}


def _colunas(cursor) -> list[str]:
    return [linha[1] for linha in cursor.fetchall()]


def main() -> int:
    destino = os.getenv("SQLITE_PATH", "").strip()
    url = os.getenv("TURSO_DATABASE_URL", "").strip()
    token = os.getenv("TURSO_AUTH_TOKEN", "").strip()
    if not destino:
        print("ERRO: SQLITE_PATH não definido no ambiente")
        return 1
    if not url or not token:
        print("ERRO: TURSO_DATABASE_URL/TURSO_AUTH_TOKEN ausentes no ambiente")
        return 1

    diretorio = os.path.dirname(os.path.abspath(destino))
    os.makedirs(diretorio, exist_ok=True)
    print(f"origem : Turso ({url.split('://', 1)[-1][:45]}...)")
    print(f"destino: {destino}")

    import libsql

    origem = libsql.connect(database=url, auth_token=token)
    alvo = sqlite3.connect(destino)
    alvo.execute("PRAGMA journal_mode=WAL")
    alvo.execute("PRAGMA busy_timeout=10000")
    alvo.row_factory = sqlite3.Row

    objetos = origem.execute(
        "SELECT type, name, sql FROM sqlite_master WHERE sql IS NOT NULL "
        "AND name NOT LIKE 'sqlite_%' AND type IN ('table','index') "
        "ORDER BY CASE type WHEN 'table' THEN 0 ELSE 1 END, name"
    ).fetchall()
    tabelas = [(o[0], o[1], o[2]) for o in objetos if o[0] == "table"]
    indices = [(o[0], o[1], o[2]) for o in objetos if o[0] == "index"]

    existentes = {
        r[0] for r in alvo.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
    }
    criadas = 0
    for _, nome, sql in tabelas:
        if nome in TABELAS_IGNORADAS or nome in existentes:
            continue
        alvo.execute(sql)
        criadas += 1
    alvo.commit()
    print(f"tabelas criadas no destino: {criadas} (de {len(tabelas)})")

    total = 0
    for _, nome, _ in tabelas:
        if nome in TABELAS_IGNORADAS:
            continue
        colunas = _colunas(origem.execute(f"PRAGMA table_info({nome})"))
        if not colunas:
            print(f"  AVISO: tabela {nome} sem colunas, ignorada")
            continue
        linhas = origem.execute(f"SELECT * FROM {nome}").fetchall()
        if linhas:
            marcadores = ", ".join("?" for _ in colunas)
            alvo.executemany(
                f"INSERT OR REPLACE INTO {nome} ({', '.join(colunas)}) VALUES ({marcadores})",
                [tuple(linha) for linha in linhas],
            )
        alvo.commit()
        total += len(linhas)

    existentes_idx = {
        r[0] for r in alvo.execute("SELECT name FROM sqlite_master WHERE type='index'").fetchall()
    }
    criados_idx = 0
    for _, nome, sql in indices:
        if nome in existentes_idx:
            continue
        try:
            alvo.execute(sql)
            criados_idx += 1
        except sqlite3.OperationalError as exc:
            print(f"  AVISO: índice {nome} não criado: {exc}")
    alvo.commit()
    print(f"índices criados: {criados_idx} (de {len(indices)})")

    alvo.execute("PRAGMA wal_checkpoint(TRUNCATE)")
    alvo.commit()

    print("\nverificação de contagens:")
    ok = True
    for _, nome, _ in tabelas:
        if nome in TABELAS_IGNORADAS:
            continue
        origem_n = origem.execute(f"SELECT COUNT(*) FROM {nome}").fetchone()[0]
        alvo_n = alvo.execute(f"SELECT COUNT(*) FROM {nome}").fetchone()[0]
        if origem_n != alvo_n:
            ok = False
            print(f"  DIF {nome}: origem={origem_n} destino={alvo_n}")
        else:
            print(f"  OK  {nome}: {origem_n}")
    alvo.close()

    print(f"\n{total} linha(s) copiada(s) para {destino}")
    if not ok:
        print("ERRO: contagens divergentes — NÃO remova o Turso ainda")
        return 1
    print("MIGRAÇÃO OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
