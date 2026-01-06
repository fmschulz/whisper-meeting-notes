#!/bin/bash

# Start Chromium after cleaning up stale profile locks.
# Prevents "profile is in use on another computer" errors when the hostname
# changed or the previous session crashed.

set -euo pipefail

CHROMIUM_BIN="${CHROMIUM_BIN:-/usr/bin/chromium}"
PROFILE_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/chromium"
LOCKS=("SingletonLock" "SingletonCookie" "SingletonSocket")
USER_NAME="${USER:-$(id -un)}"
WAYLAND_DISPLAY_CURRENT="${WAYLAND_DISPLAY:-}"

# Compose Wayland/X11 flags conservatively. Prefer Wayland when available,
# but let Chromium auto-detect in edge cases to avoid hard failures.
PLATFORM_FLAGS=()
if [[ "${XDG_SESSION_TYPE:-}" == "wayland" || -n "${WAYLAND_DISPLAY:-}" ]]; then
  PLATFORM_FLAGS+=("--ozone-platform-hint=auto")
  PLATFORM_FLAGS+=("--enable-features=UseOzonePlatform,WaylandWindowDecorations")
fi

# Prefer software GL when no GPU is present or when explicitly requested.
# This helps pages like Google Maps that need WebGL on machines without
# a discrete/integrated GPU or inside VMs.
GPU_FLAGS=()
FORCE_SW_GL=${CHROMIUM_FORCE_SOFTWARE_GL:-0}
if [[ "${FORCE_SW_GL}" == "1" || ! -d "/dev/dri" ]]; then
  GPU_FLAGS+=("--use-gl=swiftshader")
  GPU_FLAGS+=("--disable-features=Vulkan")
  GPU_FLAGS+=("--ignore-gpu-blocklist")
  export LIBGL_ALWAYS_SOFTWARE=1
fi

# If Chromium is already running, ensure it belongs to this Wayland session.
# If it is bound to a different WAYLAND_DISPLAY (stale session), terminate it
# so a new instance can start.
#
# Use the *oldest* chromium process as the browser process; newer ones are often
# renderers/utilities which may not carry a stable WAYLAND_DISPLAY.
if running_pid=$(pgrep -u "${USER_NAME}" -o -x chromium 2>/dev/null || true); [[ -n "${running_pid}" ]]; then
  if [[ -n "${WAYLAND_DISPLAY_CURRENT}" ]]; then
    running_wayland_display=$(
      tr '\0' '\n' </proc/"${running_pid}"/environ 2>/dev/null | awk -F= '$1=="WAYLAND_DISPLAY"{print $2; exit}'
    )
    if [[ -n "${running_wayland_display}" && "${running_wayland_display}" != "${WAYLAND_DISPLAY_CURRENT}" ]]; then
      pkill -u "${USER_NAME}" -f "(^|/)(chromium|chrome)( |$)" >/dev/null 2>&1 || true
      sleep 0.2
    else
      exec "${CHROMIUM_BIN}" "${PLATFORM_FLAGS[@]}" "${GPU_FLAGS[@]}" "$@"
    fi
  else
    exec "${CHROMIUM_BIN}" "${PLATFORM_FLAGS[@]}" "${GPU_FLAGS[@]}" "$@"
  fi
fi

# Remove stale lock artifacts if they exist.
for f in "${LOCKS[@]}"; do
  rm -f "${PROFILE_DIR}/${f}"
done

# Log stderr to a file when launched from a desktop entry (usually no TTY)
# for easier debugging if launch appears to do nothing.
LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/chromium-launch.log"

	if [[ -t 2 ]]; then
	  exec "${CHROMIUM_BIN}" "${PLATFORM_FLAGS[@]}" "${GPU_FLAGS[@]}" "$@"
	else
	  {
	    printf '[%s] Launch: %s %s %s %s\n' \
	      "$(date +'%F %T')" \
	      "${CHROMIUM_BIN}" \
	      "${PLATFORM_FLAGS[*]}" \
	      "${GPU_FLAGS[*]}" \
	      "$*"
	  } >>"${LOG_FILE}" 2>/dev/null || true
	  exec "${CHROMIUM_BIN}" "${PLATFORM_FLAGS[@]}" "${GPU_FLAGS[@]}" "$@" 2>>"${LOG_FILE}"
	fi
