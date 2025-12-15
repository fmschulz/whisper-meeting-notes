#!/bin/bash

# Start Chromium after cleaning up stale profile locks.
# Prevents "profile is in use on another computer" errors when the hostname
# changed or the previous session crashed.

set -euo pipefail

CHROMIUM_BIN="${CHROMIUM_BIN:-/usr/bin/chromium}"
PROFILE_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/chromium"
LOCKS=("SingletonLock" "SingletonCookie" "SingletonSocket")

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

# If Chromium is already running for this user, just exec into it without
# touching locks to avoid corruption.
if pgrep -u "${USER}" -f "(^|/)(chromium|chrome)( |$)" >/dev/null 2>&1; then
  exec "${CHROMIUM_BIN}" "${PLATFORM_FLAGS[@]}" "${GPU_FLAGS[@]}" "$@"
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
