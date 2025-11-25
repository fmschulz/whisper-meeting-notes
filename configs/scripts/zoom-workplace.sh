#!/bin/bash
# Launch Zoom Workplace with sane defaults under Hyprland. Force XWayland unless
# explicitly overridden so dropdown menus and device pickers stay usable.

set -euo pipefail

if [[ ${ZOOM_FORCE_WAYLAND:-0} -eq 1 ]]; then
  export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-GNOME}"
  export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland}"
  export SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-wayland}"
  export CLUTTER_BACKEND="${CLUTTER_BACKEND:-wayland}"
else
  export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-Unity}"
  export QT_QPA_PLATFORM="xcb"
  export SDL_VIDEODRIVER="x11"
  export CLUTTER_BACKEND="x11"
  export XDG_SESSION_TYPE="x11"
  export GDK_BACKEND="x11"
fi

exec /usr/bin/zoom "$@"
