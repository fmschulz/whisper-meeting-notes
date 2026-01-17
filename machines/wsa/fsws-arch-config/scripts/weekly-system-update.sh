#!/bin/bash
# Automated weekly system update for Arch (pacman) with optional AUR support.
# - Runs non-interactively and logs to journal (view with: journalctl -u weekly-system-update.service)
# - Skips if pacman DB is locked (another update in progress)
# - Optional AUR updates when UPDATE_AUR=true and yay/paru available

set -euo pipefail

readonly LOG_TAG="[weekly-system-update]"
readonly STATE_DIR="/var/lib/weekly-system-update"
readonly LAST_RUN_FILE="$STATE_DIR/last_run"
readonly MIN_INTERVAL_SECONDS=$((24 * 3600))

log() {
    echo "$(date -Is) ${LOG_TAG} $*"
}

is_locked() {
    [[ -e /var/lib/pacman/db.lck ]]
}

update_pacman() {
    log "Starting pacman full system sync/upgrade..."
    # Refresh DBs then upgrade. Non-interactive for timer use.
    sudo pacman -Syyu --noconfirm --needed
    log "pacman update completed."
}

update_aur_if_enabled() {
    # Only update AUR if explicitly enabled.
    local enable_aur=${UPDATE_AUR:-false}
    if [[ "$enable_aur" != "true" ]]; then
        log "AUR updates disabled (set UPDATE_AUR=true to enable)."
        return 0
    fi

    if command -v paru >/dev/null 2>&1; then
        log "Updating AUR packages via paru..."
        paru -Syu --noconfirm --batchinstall || log "paru update encountered issues (continuing)."
        return 0
    fi

    if command -v yay >/dev/null 2>&1; then
        log "Updating AUR packages via yay..."
        yay -Syu --noconfirm --sudoloop || log "yay update encountered issues (continuing)."
        return 0
    fi

    log "No AUR helper found (paru/yay). Skipping AUR updates."
}

main() {
    # Throttle to max once per MIN_INTERVAL_SECONDS
    mkdir -p "$STATE_DIR" 2>/dev/null || true
    if [[ -f "$LAST_RUN_FILE" ]]; then
        local last now
        last=$(cat "$LAST_RUN_FILE" 2>/dev/null || echo 0)
        now=$(date +%s)
        if (( now - last < MIN_INTERVAL_SECONDS )); then
            log "Last run was <24h ago; skipping (throttle)."
            exit 0
        fi
    fi

    if is_locked; then
        log "pacman DB lock present; skipping (another update in progress)."
        exit 0
    fi

    # Basic reachability check (avoid running offline). Non-fatal.
    if ! ping -c1 -W2 archlinux.org >/dev/null 2>&1; then
        log "Network check failed; skipping this run."
        exit 0
    fi

    update_pacman
    update_aur_if_enabled
    date +%s > "$LAST_RUN_FILE" 2>/dev/null || true
    log "Weekly system update finished."
}

main "$@"
