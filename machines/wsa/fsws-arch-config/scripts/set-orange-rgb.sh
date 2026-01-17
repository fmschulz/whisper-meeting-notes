#!/bin/bash
set -euo pipefail

# Force all detected RGB devices to a static orange color
# - Uses OpenRGB for motherboard/strip/fan LEDs
# - Uses liquidctl for Mjolnir cooler/controller LEDs (if supported)
#
# Requirements: openrgb, liquidctl

ORANGE_HEX="${1:-ff8800}"

log() { printf '[nexus-rgb] %s\n' "$*"; }

require_tools() {
    local have_any=0
    if command -v openrgb >/dev/null 2>&1; then
        have_any=1
    else
        log "openrgb not found (install: sudo pacman -S openrgb)"
    fi
    if command -v liquidctl >/dev/null 2>&1; then
        have_any=1
    else
        log "liquidctl not found (install: sudo pacman -S liquidctl)"
    fi
    if [[ $have_any -eq 0 ]]; then
        log "No supported RGB tools available; nothing to do."
        exit 0
    fi
}

normalize_hex() {
    local h="${1#\#}"
    # Pad to 6 chars, ignore alpha if given
    h=${h:0:6}
    if [[ -z "$h" || ${#h} -lt 6 ]]; then
        h="ffa500"
    fi
    echo "${h^^}"
}

apply_openrgb() {
    command -v openrgb >/dev/null 2>&1 || return 0
    # Ensure any running OpenRGB instances don't keep effects changing
    pkill -f '^openrgb( |$)' 2>/dev/null || true
    # Apply using hex color; first try setting color directly, then fall back to static mode
    local HEX
    HEX=$(normalize_hex "$ORANGE_HEX")
    openrgb -c "$HEX" --noautoconnect || \
    openrgb -m static -c "$HEX" --noautoconnect || \
    log "OpenRGB apply failed (permissions/devices). Tried HEX: #$HEX"
}

apply_liquidctl() {
    # Apply fixed color to Thermaltake Mjolnir (if exposed via liquidctl)
    if command -v liquidctl >/dev/null 2>&1; then
        sudo -n true 2>/dev/null || log "sudo may prompt: allowing liquidctl to set LED color"
        liquidctl list >/dev/null 2>&1 || true
        sudo liquidctl --match mjolnir set led color fixed "$ORANGE_HEX" 2>/dev/null || true
        sudo liquidctl --match thermaltake set led color fixed "$ORANGE_HEX" 2>/dev/null || true
    fi
}

require_tools
log "Setting static RGB color to #$ORANGE_HEX"
apply_openrgb
apply_liquidctl
log "Done. If colors still change, disable any vendor daemons or OpenRGB auto-profiles."
