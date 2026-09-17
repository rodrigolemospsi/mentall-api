"""Run unittest without dotenv, network, or an on-disk application database.

Usage (from backend): .venv/bin/python -B tests/run_isolated.py [test_module ...]
No ASGI lifespan/server is started by this runner.
"""
import builtins
import io
import os
from pathlib import Path
import socket
import sqlite3
import sys
import types
import unittest
from contextlib import ExitStack
from unittest.mock import patch


def main():
    backend = Path(__file__).resolve().parents[1]
    sys.path[:0] = [str(backend), str(backend / "tests")]
    sys.dont_write_bytecode = True
    connect = sqlite3.connect
    file_open = builtins.open
    io_open = io.open
    makedirs = os.makedirs

    def memory_connect(database, *args, **kwargs):
        kwargs.pop("uri", None)
        return connect(":memory:", *args, **kwargs)

    def deny(*args, **kwargs):
        raise AssertionError("Network forbidden by isolated test runner")

    def safe_open(original):
        def guarded(file, *args, **kwargs):
            if isinstance(file, (str, bytes, os.PathLike)):
                name = Path(os.fsdecode(file)).name
                if name == ".env" or name.startswith(".env.") or name.endswith((".db", ".sqlite", ".sqlite3")):
                    raise AssertionError("Real secrets/database file access forbidden")
            return original(file, *args, **kwargs)
        return guarded

    def safe_makedirs(name, *args, **kwargs):
        if Path(name).resolve() == backend / "data":
            return
        return makedirs(name, *args, **kwargs)

    dotenv = types.ModuleType("dotenv")
    dotenv.load_dotenv = lambda *a, **kw: False
    dotenv.dotenv_values = lambda *a, **kw: {}
    dotenv.find_dotenv = lambda *a, **kw: ""
    with ExitStack() as stack:
        stack.enter_context(patch.dict(os.environ, {
            "JWT_SECRET": "isolated-test-secret-not-for-production-0000",
            "APP_PASSWORD_HASH": "invalid-test-hash",
            "APP_USER_ID": "isolated-admin",
            "PYTHONDONTWRITEBYTECODE": "1",
        }, clear=True))
        stack.enter_context(patch.dict(sys.modules, {"dotenv": dotenv}))
        for target, replacement in (
            ("sqlite3.connect", memory_connect),
            ("os.makedirs", safe_makedirs),
            ("builtins.open", safe_open(file_open)),
            ("io.open", safe_open(io_open)),
            ("socket.socket.connect", deny),
            ("socket.socket.connect_ex", deny),
            ("socket.create_connection", deny),
            ("socket.getaddrinfo", deny),
        ):
            stack.enter_context(patch(target, replacement))
        loader = unittest.TestLoader()
        suite = (loader.loadTestsFromNames(sys.argv[1:]) if sys.argv[1:]
                 else loader.discover(str(backend / "tests")))
        result = unittest.TextTestRunner(verbosity=2).run(suite)
        return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(main())
