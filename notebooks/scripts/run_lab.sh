#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PORT_LAB="${PORT_LAB:-8891}"
exec pixi run lab
