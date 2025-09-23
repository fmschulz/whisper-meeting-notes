#!/bin/bash
# Launch Zoom Workplace with Wayland-friendly defaults under Hyprland

set -euo pipefail

export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-GNOME}"
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland}"
export SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-wayland}"
export CLUTTER_BACKEND="${CLUTTER_BACKEND:-wayland}"

exec zoom "$@"
