#!/bin/bash
# Wrapper do backend para launchd / uso manual
cd "$(dirname "$0")"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
unset PYTHONHOME PYTHONPATH 2>/dev/null
exec ./.venv/bin/python -u -m uvicorn main:app --host 0.0.0.0 --port 8000
