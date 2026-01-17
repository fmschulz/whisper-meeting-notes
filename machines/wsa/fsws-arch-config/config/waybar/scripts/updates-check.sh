#!/bin/bash
# Minimal updates checker: pacman and yay/paru if available. Outputs JSON for Waybar.

set -euo pipefail

count=0

num() {
    # strip non-digits; default to 0
    local v
    v=$(echo "$1" | tr -cd '0-9')
    echo "${v:-0}"
}

if command -v checkupdates >/dev/null 2>&1; then
    pac=$(checkupdates 2>/dev/null | wc -l 2>/dev/null || echo 0)
    count=$((count + $(num "$pac")))
fi

if command -v yay >/dev/null 2>&1; then
    aur=$(yay -Qu --aur 2>/dev/null | wc -l 2>/dev/null || echo 0)
    count=$((count + $(num "$aur")))
elif command -v paru >/dev/null 2>&1; then
    aur=$(paru -Qu --aur 2>/dev/null | wc -l 2>/dev/null || echo 0)
    count=$((count + $(num "$aur")))
fi

printf '{"text":"%s"}\n' "$count"
