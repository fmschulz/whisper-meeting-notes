#!/bin/bash
# Configure and launch the Pixi-backed drop service on the workstation.
# This installs the GPU environment, writes the systemd unit, and wires
# Tailscale Serve to expose /meeting-notes.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
UNIT_NAME="meeting-notes-drop.service"
UNIT_DIR="${HOME}/.config/systemd/user"
UNIT_PATH="${UNIT_DIR}/${UNIT_NAME}"
PIXIBIN="${PIXI_BIN:-$(command -v pixi 2>/dev/null || true)}"
CUDNN_DEFAULT="${HOME}/.local/cudnn8/lib"
SERVE_PATH="${DROP_SERVICE_SERVE_PATH:-/meeting-notes}"

if [[ "${SERVE_PATH}" != /* ]]; then
  SERVE_PATH="/${SERVE_PATH}"
fi

if [[ -z "${PIXIBIN}" ]]; then
  echo "pixi executable not found. Install pixi from https://pixi.sh first." >&2
  exit 1
fi

if [[ -n "${DROP_SERVICE_CUDA_VISIBLE_DEVICES:-}" ]]; then
  CUDA_DEVICE="${DROP_SERVICE_CUDA_VISIBLE_DEVICES}"
else
  if ! CUDA_DEVICE="$("${PIXIBIN}" run --environment gpu -- python - <<'PY'
import warnings
warnings.filterwarnings("ignore")
import torch

SUPPORTED_MAX = 90
selected = None
for idx in range(torch.cuda.device_count()):
    major, minor = torch.cuda.get_device_capability(idx)
    capability = major * 10 + minor
    if capability <= SUPPORTED_MAX:
        selected = idx
        break

if selected is not None:
    print(selected, end="")
PY
)"; then
    CUDA_DEVICE=""
  fi
  CUDA_DEVICE="$(printf '%s' "${CUDA_DEVICE}" | tr -d '[:space:]')"
  if [[ -z "${CUDA_DEVICE}" ]]; then
    CUDA_DEVICE="0"
  fi
fi

if [[ -n "${CUDNN_COMPAT_DIR:-}" ]]; then
  CUDNN_DIR="${CUDNN_COMPAT_DIR}"
elif [[ -d "${CUDNN_DEFAULT}" ]]; then
  CUDNN_DIR="${CUDNN_DEFAULT}"
else
  CUDNN_DIR=""
fi

echo "[1/4] Installing/updating Pixi GPU environment…"
"${PIXIBIN}" install -e gpu

if [[ -n "${CUDNN_DIR}" ]]; then
echo "[2/4] Writing systemd unit to ${UNIT_PATH} (CUDA_VISIBLE_DEVICES=${CUDA_DEVICE}, CUDNN_COMPAT_DIR=${CUDNN_DIR})"
else
  echo "[2/4] Writing systemd unit to ${UNIT_PATH} (CUDA_VISIBLE_DEVICES=${CUDA_DEVICE})"
  echo "      Hint: place cuDNN libs under ${CUDNN_DEFAULT} or export CUDNN_COMPAT_DIR before running this helper."
fi
mkdir -p "${UNIT_DIR}"
cat > "${UNIT_PATH}" <<EOF
[Unit]
Description=Meeting Notes Drop Service
After=network-online.target tailscaled.service
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${PROJECT_ROOT}
Environment=CUDA_VISIBLE_DEVICES=${CUDA_DEVICE}
$(if [[ -n "${CUDNN_DIR}" ]]; then printf 'Environment=CUDNN_COMPAT_DIR=%s\n' "${CUDNN_DIR}"; fi)
Environment=DROP_SERVER_PORT=8040
Environment=DROP_MAX_WORKERS=1
Environment=DROP_SERVER_HOST=127.0.0.1
Environment=DROP_SERVER_PATH=${SERVE_PATH}
ExecStart=${PIXIBIN} run --environment gpu -- python -m meeting_notes.drop_service --port 8040 --workers 1 --serve-path ${SERVE_PATH}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

echo "[3/4] Reloading systemd user units and (re)starting ${UNIT_NAME}"
systemctl --user daemon-reload
systemctl --user enable --now "${UNIT_NAME}"

echo "[4/4] Configuring Tailscale Serve (${SERVE_PATH} → http://127.0.0.1:8040)"
tailscale serve --yes --https=443 off >/dev/null 2>&1 || true
tailscale serve --yes --bg --https=443 --set-path=${SERVE_PATH} http://127.0.0.1:8040

REMOTE_ENDPOINT_FILE="${PROJECT_ROOT}/.remote-http-endpoint"
serve_base="$(tailscale serve status 2>/dev/null | head -n1 | awk '{print $1}')"
if [[ "${serve_base}" == https://* ]]; then
  remote_endpoint="${serve_base%/}${SERVE_PATH}"
  printf '%s\n' "${remote_endpoint}" > "${REMOTE_ENDPOINT_FILE}"
  echo "Saved default remote HTTP endpoint to ${REMOTE_ENDPOINT_FILE}"
else
  echo "Warning: unable to detect Tailscale serve URL; set REMOTE_HTTP_ENDPOINT manually if needed." >&2
fi

echo "Done."
echo "Check status with: systemctl --user status ${UNIT_NAME}"
echo "Verify Tailscale route: tailscale serve status"
