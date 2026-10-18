#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/prepare_xtool.py
python3 scripts/check_artwork_simulator.py
