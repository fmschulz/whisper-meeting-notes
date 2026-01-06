#!/usr/bin/env bash
set -euo pipefail

DIR="${WALLPAPER_DIR:-$HOME/Pictures/wallpapers}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-cycle"
INDEX_FILE="$CACHE/index"
FILES=()

if [ ! -d "$DIR" ]; then
  notify-send "Wallpapers" "Directory $DIR not found" -u low >/dev/null 2>&1 || true
  exit 0
fi

mapfile -t FILES < <(find "$DIR" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) | sort)
if [ ${#FILES[@]} -eq 0 ]; then
  notify-send "Wallpapers" "No images found in $DIR" -u low >/dev/null 2>&1 || true
  exit 0
fi

mkdir -p "$CACHE"
current=${FILES[0]}
if [ -f "$INDEX_FILE" ]; then
  saved=$(cat "$INDEX_FILE" 2>/dev/null || echo 0)
  if [[ "$saved" =~ ^[0-9]+$ ]] && [ "$saved" -lt ${#FILES[@]} ]; then
    current=${FILES[$saved]}
  fi
fi

shift_index() {
  local delta=$1
  local idx=${2:-0}
  local total=${#FILES[@]}
  idx=$(( (idx + delta) % total ))
  if [ $idx -lt 0 ]; then
    idx=$((idx + total))
  fi
  echo $idx
}

ensure_daemon() {
  local runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  local display="${WAYLAND_DISPLAY:-wayland-0}"

  # A daemon may already be running for a different WAYLAND_DISPLAY (which creates a
  # different socket). Ensure a socket exists for the current session display.
  if compgen -G "${runtime}/${display}-swww-daemon"*.sock >/dev/null 2>&1; then
    return 0
  fi

  (WAYLAND_DISPLAY="${display}" swww-daemon >/dev/null 2>&1 &)
  sleep 0.5
}

current_index() {
  local target="$1"
  local i
  for i in "${!FILES[@]}"; do
    if [ "${FILES[$i]}" = "$target" ]; then
      echo "$i"
      return 0
    fi
  done
  echo 0
}

op=${1:-next}
case "$op" in
  next)
    ensure_daemon
    base_index=$(current_index "$current")
    new_index=$(shift_index 1 "$base_index")
    ;;
  prev)
    ensure_daemon
    base_index=$(current_index "$current")
    new_index=$(shift_index -1 "$base_index")
    ;;
  random)
    ensure_daemon
    new_index=$(( RANDOM % ${#FILES[@]} ))
    ;;
  set)
    target=${2:-}
    if [ -z "$target" ]; then
      echo "Usage: $0 set <path>" >&2
      exit 1
    fi
    for i in "${!FILES[@]}"; do
      if [ "${FILES[$i]}" = "$target" ]; then
        new_index=$i
        break
      fi
    done
    if [ -z "${new_index:-}" ]; then
      echo "Wallpaper $target not found in $DIR" >&2
      exit 1
    fi
    ensure_daemon
    ;;
  apply|current)
    ensure_daemon
    new_index=$(current_index "$current")
    ;;
  *)
    new_index=$(shift_index 1 0)
    ;;
esac

selected=${FILES[$new_index]}
if command -v swww >/dev/null 2>&1; then
  ensure_daemon
  if ! swww img "$selected" --transition-type grow --transition-duration 1 >/dev/null 2>&1; then
    swww img "$selected" >/dev/null 2>&1 || true
  fi
else
  notify-send "Wallpapers" "swww not installed" -u low >/dev/null 2>&1 || true
fi

echo "$new_index" >"$INDEX_FILE"
