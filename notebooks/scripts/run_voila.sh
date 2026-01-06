#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PORT_VOILA="${PORT_VOILA:-8866}"
exec pixi run voila
