#!/bin/bash
# Cycle to a random wallpaper and sync Hyprpaper/blur cache.

set -euo pipefail
IFS=$'\n\t'

WALL_DIR="${WALL_DIR:-$HOME/Pictures/Wallpapers}"

log() { printf "[wallpaper-cycle] %s\n" "$*"; }
err() { printf "[wallpaper-cycle] ERROR: %s\n" "$*" >&2; }

mapfile -t wallpapers < <(find "$WALL_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort)

if [[ ${#wallpapers[@]} -eq 0 ]]; then
    err "No wallpapers found in $WALL_DIR"
    exit 1
fi

pick="${wallpapers[$((RANDOM % ${#wallpapers[@]}))]}"

# Locate the sync script (prefer installed, fallback to repo-relative)
sync_script="${WALLPAPER_SYNC:-$HOME/.local/bin/wallpaper-sync.sh}"
if [[ ! -x "$sync_script" ]]; then
    repo="${FSWS_REPO:-$HOME/fsws-arch-config}"
    candidate="$repo/scripts/wallpaper-sync.sh"
    [[ -x "$candidate" ]] && sync_script="$candidate"
fi

if [[ ! -x "$sync_script" ]]; then
    err "wallpaper-sync.sh not found (looked for $sync_script)."
    exit 1
fi

log "Applying wallpaper: $pick"
"$sync_script" "$pick"

# Print JSON for Waybar if desired
printf '{"text": "%s"}\n' "$(basename "$pick")"
