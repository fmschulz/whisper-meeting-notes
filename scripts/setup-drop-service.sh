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

if [[ -z "${PIXIBIN}" ]]; then
  echo "pixi executable not found. Install pixi from https://pixi.sh first." >&2
  exit 1
fi

echo "[1/4] Installing/updating Pixi GPU environment…"
"${PIXIBIN}" install -e gpu

echo "[2/4] Writing systemd unit to ${UNIT_PATH}"
mkdir -p "${UNIT_DIR}"
cat > "${UNIT_PATH}" <<EOF
[Unit]
Description=Meeting Notes Drop Service
After=network-online.target tailscaled.service
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${PROJECT_ROOT}
Environment=CUDA_VISIBLE_DEVICES=1
Environment=DROP_SERVER_PORT=8040
Environment=DROP_MAX_WORKERS=1
Environment=DROP_SERVER_HOST=127.0.0.1
Environment=DROP_SERVER_PATH=/meeting-notes
ExecStart=${PIXIBIN} run --environment gpu -- python -m meeting_notes.drop_service --port 8040 --workers 1 --serve-path /meeting-notes
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

echo "[3/4] Reloading systemd user units and (re)starting ${UNIT_NAME}"
systemctl --user daemon-reload
systemctl --user enable --now "${UNIT_NAME}"

echo "[4/4] Configuring Tailscale Serve (/meeting-notes → http://127.0.0.1:8040)"
tailscale serve --yes --https=443 off >/dev/null 2>&1 || true
tailscale serve --yes --bg --https=443 --set-path=/meeting-notes http://127.0.0.1:8040

echo "Done."
echo "Check status with: systemctl --user status ${UNIT_NAME}"
echo "Verify Tailscale route: tailscale serve status"
