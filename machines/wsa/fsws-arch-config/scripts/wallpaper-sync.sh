#!/bin/bash
# Lightweight wallpaper helper: sets hyprpaper, caches current wallpaper, and generates a blurred copy.
# Keeps the neon theme intact; matugen integration is optional via MATUGEN_RUN=1.

set -euo pipefail
IFS=$'\n\t'

log() { printf "[wallpaper-sync] %s\n" "$*"; }
warn() { printf "[wallpaper-sync] WARN: %s\n" "$*" >&2; }

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/nexus-wallpapers"
mkdir -p "$CACHE_DIR"

CURRENT_FILE="$CACHE_DIR/current_wallpaper"
BLURRED_FILE="$CACHE_DIR/blurred_wallpaper.png"
DEFAULT_WALL="$HOME/Pictures/Wallpapers/nexus-abstract.jpg"

pick_wallpaper() {
    if [[ -n "${1:-}" ]]; then
        echo "$1"; return
    fi
    if [[ -f "$CURRENT_FILE" ]]; then
        echo "$(cat "$CURRENT_FILE")"; return
    fi
    echo "$DEFAULT_WALL"
}

wallpaper=$(pick_wallpaper "${1:-}")
if [[ ! -f "$wallpaper" ]]; then
    warn "Wallpaper not found: $wallpaper"
    exit 1
fi

echo "$wallpaper" > "$CURRENT_FILE"

# Apply wallpaper via hyprpaper IPC (best effort)
if command -v hyprctl >/dev/null 2>&1; then
    hyprctl hyprpaper preload "$wallpaper" >/dev/null 2>&1 || true
    hyprctl hyprpaper wallpaper ",$wallpaper" >/dev/null 2>&1 || true
else
    warn "hyprctl not found; skipping hyprpaper update."
fi

# Generate blurred copy for lock/logout themes if ImageMagick is available
if command -v convert >/dev/null 2>&1; then
    convert "$wallpaper" -resize 40% -blur 0x35 "$BLURRED_FILE" || warn "convert failed to blur wallpaper."
else
    warn "convert not found; blurred wallpaper not generated."
fi

# Optional: run matugen to refresh a palette (disabled by default)
if [[ "${MATUGEN_RUN:-0}" == "1" ]] && command -v matugen >/dev/null 2>&1; then
    matugen image "$wallpaper" -m dark >/dev/null 2>&1 || warn "matugen failed (non-fatal)."
fi

log "Wallpaper applied: $wallpaper"
log "Cache: $CURRENT_FILE"
[[ -f "$BLURRED_FILE" ]] && log "Blurred copy: $BLURRED_FILE"
