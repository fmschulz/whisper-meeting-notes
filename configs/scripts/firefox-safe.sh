#!/bin/bash
set -euo pipefail

FIREFOX_BIN="${FIREFOX_BIN:-/usr/lib/firefox/firefox}"
USER_NAME="${USER:-$(id -un)}"
WAYLAND_DISPLAY_CURRENT="${WAYLAND_DISPLAY:-}"

if [[ -n "${WAYLAND_DISPLAY_CURRENT}" ]]; then
  if running_pid=$(pgrep -u "${USER_NAME}" -n -f "(^|/)(firefox)( |$)" 2>/dev/null); then
    running_wayland_display=$(
      tr '\0' '\n' </proc/"${running_pid}"/environ 2>/dev/null | awk -F= '$1=="WAYLAND_DISPLAY"{print $2; exit}'
    )
    if [[ -n "${running_wayland_display}" && "${running_wayland_display}" != "${WAYLAND_DISPLAY_CURRENT}" ]]; then
      pkill -u "${USER_NAME}" -f "(^|/)(firefox)( |$)" >/dev/null 2>&1 || true
      sleep 0.2
    fi
  fi
fi

exec env MOZ_ENABLE_WAYLAND=1 "${FIREFOX_BIN}" "$@"

