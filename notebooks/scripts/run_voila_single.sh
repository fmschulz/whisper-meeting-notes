#!/usr/bin/env bash
set -euo pipefail

NOTEBOOK_PATH="${1:-}"
if [[ -z "$NOTEBOOK_PATH" ]]; then
  echo "Usage: $0 /path/to/notebook.ipynb"
  exit 1
fi

cd "$(dirname "$0")/.."
export PORT_VOILA="${PORT_VOILA:-8866}"
exec bash -lc "voila \"$NOTEBOOK_PATH\" --ip=127.0.0.1 --port=${PORT_VOILA} --no-browser"
