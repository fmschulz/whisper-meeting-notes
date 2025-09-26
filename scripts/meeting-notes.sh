#!/bin/bash

# Thin wrapper around `uv run` so moderators can launch transcription quickly.
# Usage: meeting-notes.sh <audio-file> [output-file]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
UV_PYTHON_VERSION="${UV_PYTHON_VERSION:-3.12}"
TORCH_VARIANT="${UV_TORCH_VARIANT:-auto}"
TORCH_SPEC="${UV_TORCH_SPEC:-torch==2.5.1}"

if ! command -v uv >/dev/null 2>&1; then
  echo "uv is required. Install via \"pip install uv\" or your package manager." >&2
  exit 1
fi

echo "Ensuring dependencies are in sync (first run will download models)…"
uv sync --project "${PROJECT_ROOT}" --python "${UV_PYTHON_VERSION}" --frozen 2>/dev/null \
  || uv sync --project "${PROJECT_ROOT}" --python "${UV_PYTHON_VERSION}"

ensure_torch() {
  local desired_variant="${TORCH_VARIANT}"

  if [[ "${desired_variant}" == "auto" ]]; then
    if command -v nvidia-smi >/dev/null 2>&1; then
      desired_variant="cu124"
    else
      desired_variant="cpu"
    fi
    echo "Auto-selecting Torch variant: ${desired_variant}"
  fi

  case "${desired_variant}" in
    cpu)
      torch_index="https://download.pytorch.org/whl/cpu"
      ;;
    cu124)
      torch_index="https://download.pytorch.org/whl/cu124"
      ;;
    none)
      return 0
      ;;
    *)
      echo "Unknown UV_TORCH_VARIANT='${desired_variant}'. Supported: auto, cpu, cu124, none." >&2
      exit 1
      ;;
  esac

  current_variant=$(uv run --project "${PROJECT_ROOT}" --python "${UV_PYTHON_VERSION}" python - <<'PY'
try:
    import torch
except Exception:
    print("missing")
else:
    print("cuda" if torch.version.cuda else "cpu")
PY
  )
  current_variant=$(printf '%s' "${current_variant}" | tr -d '\r\n')

  if [[ "${desired_variant}" == "cpu" && "${current_variant}" == "cpu" ]]; then
    return 0
  fi

  if [[ "${desired_variant}" == "cu124" && "${current_variant}" == "cuda" ]]; then
    return 0
  fi

  echo "Installing Torch (${desired_variant})…"
  uv run --project "${PROJECT_ROOT}" --python "${UV_PYTHON_VERSION}" \
    pip install --no-deps --upgrade "${TORCH_SPEC}" --index-url "${torch_index}"
}

ensure_torch

if [[ -n "${HF_TOKEN:-}" ]]; then
  echo "HF_TOKEN detected – diarisation will be enabled."
else
  echo "HF_TOKEN not set – transcript will use a single default speaker (export HF_TOKEN to enable diarisation)."
fi

uv run --project "${PROJECT_ROOT}" --python "${UV_PYTHON_VERSION}" meeting-notes "$@"
