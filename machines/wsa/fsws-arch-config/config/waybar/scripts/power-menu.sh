#!/bin/bash
set -euo pipefail

menu() {
    printf "  Lock\n  Switch User\n  Logout\n  Reboot\n  Shutdown"
}

switch_user() {
    # LightDM
    if command -v dm-tool >/dev/null 2>&1; then
        dm-tool switch-to-greeter && return 0
    fi

    # SDDM via system bus (preferred on Arch setups here)
    if systemctl is-active --quiet sddm.service; then
        if command -v busctl >/dev/null 2>&1; then
            # Try seat method first, then manager method
            busctl --system call org.freedesktop.DisplayManager \
                /org/freedesktop/DisplayManager/Seat0 \
                org.freedesktop.DisplayManager.Seat SwitchToGreeter >/dev/null 2>&1 && return 0 || true
            busctl --system call org.freedesktop.DisplayManager \
                /org/freedesktop/DisplayManager \
                org.freedesktop.DisplayManager SwitchToGreeter >/dev/null 2>&1 && return 0 || true
        fi
        if command -v dbus-send >/dev/null 2>&1; then
            dbus-send --system --print-reply \
                --dest=org.freedesktop.DisplayManager \
                /org/freedesktop/DisplayManager/Seat0 \
                org.freedesktop.DisplayManager.Seat.SwitchToGreeter >/dev/null 2>&1 && return 0 || true
            dbus-send --system --print-reply \
                --dest=org.freedesktop.DisplayManager \
                /org/freedesktop/DisplayManager \
                org.freedesktop.DisplayManager.SwitchToGreeter >/dev/null 2>&1 && return 0 || true
        fi
    fi

    # GDM legacy helper if present
    if [ -x /usr/lib/gdm/gdmflexiserver ]; then
        /usr/lib/gdm/gdmflexiserver && return 0
    fi

    # Fallback: lock and inform user
    swaylock || true
    notify-send -u low "Switch User" "Could not trigger greeter; session locked instead." 2>/dev/null || true
    return 1
}

chosen=$(menu | rofi -dmenu -i -theme "$HOME/.config/rofi/launchers/nexus.rasi")

case "${chosen:-}" in
    "  Lock") swaylock ;;
    "  Switch User") switch_user ;;
    "  Logout") hyprctl dispatch exit ;;
    "  Reboot") systemctl reboot ;;
    "  Shutdown") systemctl poweroff ;;
esac
