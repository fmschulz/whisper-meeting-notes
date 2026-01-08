#!/usr/bin/env bash
set -euo pipefail
exec cloudflared tunnel run "${TUNNEL_NAME:?set TUNNEL_NAME}"
