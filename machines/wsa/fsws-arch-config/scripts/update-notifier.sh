#!/bin/bash
# Notify-only updater for Arch: checks when the last system update occurred
# and, if stale (>= STALE_DAYS), runs `checkupdates` and sends a desktop
# notification. Intended to be called by systemd timer and on terminal open.

set -euo pipefail

# Configurable via env
STALE_DAYS=${STALE_DAYS:-7}
NOTIFY_MIN_INTERVAL_HOURS=${NOTIFY_MIN_INTERVAL_HOURS:-12}
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/nexus-update-notifier"
LAST_NOTIFY_FILE="$STATE_DIR/last_notify"

log() { printf '%s %s\n' "$(date -Is)" "$*"; }

supports_notify() { command -v notify-send >/dev/null 2>&1; }
supports_checkupdates() { command -v checkupdates >/dev/null 2>&1; }

last_update_epoch() {
    local log_file="/var/log/pacman.log"
    [[ -r "$log_file" ]] || { echo 0; return; }
    # Try to find a recent transaction marker; fallback to last upgrade entry.
    local ts
    ts=$(grep -E "(full system upgrade|upgraded |installed )" "$log_file" | tail -n1 | sed -E 's/^\[([^]]+)\].*$/\1/') || true
    [[ -n "${ts:-}" ]] || { echo 0; return; }
    # Handle "YYYY-MM-DD HH:MM" and "YYYY-MM-DDTHH:MM" formats
    ts=${ts/T/ }
    date -d "$ts" +%s 2>/dev/null || echo 0
}

main() {
    # Compute staleness
    local now last days_since
    now=$(date +%s)
    last=$(last_update_epoch)
    if [[ "$last" -eq 0 ]]; then
        days_since=999
    else
        days_since=$(( (now - last) / 86400 ))
    fi

    # Rate-limit terminal spam
    mkdir -p "$STATE_DIR"
    local min_interval=$(( NOTIFY_MIN_INTERVAL_HOURS * 3600 ))
    if [[ -f "$LAST_NOTIFY_FILE" ]]; then
        local last_notify
        last_notify=$(cat "$LAST_NOTIFY_FILE" 2>/dev/null || echo 0)
        if (( now - last_notify < min_interval )); then
            exit 0
        fi
    fi

    # Only proceed if older than threshold
    if (( days_since < STALE_DAYS )); then
        exit 0
    fi

    # Ensure checkupdates exists
    if ! supports_checkupdates; then
        log "checkupdates not found (install pacman-contrib). Skipping notification."
        exit 0
    fi

    # Run checkupdates (do not fail if none)
    local updates
    updates=$(checkupdates 2>/dev/null || true)
    local count
    count=$(wc -l <<<"$updates")
    if (( count <= 0 )); then
        # No updates available; still update timestamp to avoid repeat spam.
        date +%s > "$LAST_NOTIFY_FILE"
        exit 0
    fi

    local title="Updates available: ${count} package(s)"
    local body="System not updated in ${days_since} day(s).\nRun: sudo pacman -Syu"

    if supports_notify; then
        notify-send -u normal -a "NEXUS" "$title" "$body"
    fi

    # Also print to stdout for terminal usage
    printf "\n\e[36m[NEXUS]\e[0m %s\n%s\n\n" "$title" "$body"

    date +%s > "$LAST_NOTIFY_FILE"
}

main "$@"
