#!/usr/bin/env bash
set -euo pipefail

# Power menu (wofi) for Hyprland.

options=$(
  cat <<'EOF'
Lock
Sleep
Logout
Reboot
Shutdown
EOF
)

choice=$(
  printf '%s\n' "$options" | wofi --dmenu \
    --prompt "Power" \
    --style ~/.config/wofi/power-menu.css \
    --width 240 \
    --height 300 \
    --lines 5 \
    --cache-file /dev/null
)

[[ -z "${choice:-}" ]] && exit 0

case "$choice" in
  Lock) hyprlock ;;
  Sleep) systemctl suspend ;;
  Logout) hyprctl dispatch exit ;;
  Reboot) systemctl reboot ;;
  Shutdown) systemctl poweroff ;;
esac

