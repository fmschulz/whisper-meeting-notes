#!/bin/bash
# Setup helper for Tailscale sign-in
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run this script with sudo (root)." >&2
  exit 1
fi

TARGET_USER=${SUDO_USER:-$(logname)}

echo "▶ Ensuring tailscaled is enabled and running"
systemctl enable --now tailscaled

echo "▶ Checking Tailscale status"
if tailscale status 2>/dev/null | grep -q "Logged out"; then
  echo
  echo "Tailscale is not logged in. Choose one of the following:"
  echo "  1) Interactive login:"
  echo "     sudo tailscale up --ssh --operator=$TARGET_USER"
  echo "  2) Headless with auth key:"
  echo "     sudo TS_AUTHKEY=tskey-xxxx tailscale up --ssh --authkey=env:TS_AUTHKEY --operator=$TARGET_USER"
  echo
  exit 0
else
  echo "Tailscale appears to be logged in. It will reconnect on boot."
fi

