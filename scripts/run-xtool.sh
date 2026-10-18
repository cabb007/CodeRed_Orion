#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for tool in python3 swift xtool; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Missing %s. Follow docs/XTOOL_WINDOWS.md first.\n' "$tool" >&2
        exit 1
    fi
done
python3 scripts/prepare_xtool.py
exec xtool dev "$@"
