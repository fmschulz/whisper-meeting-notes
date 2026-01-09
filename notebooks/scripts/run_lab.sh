#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PORT_LAB="${PORT_LAB:-8891}"
export JUPYTER_ROOT="${JUPYTER_ROOT:-/clusterfs/jgi/scratch/science/mgs/nelli/}"
exec pixi run lab
