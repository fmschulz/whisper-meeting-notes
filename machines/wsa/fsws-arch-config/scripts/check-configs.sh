#!/bin/bash
# Lightweight config validation helpers for Waybar/Hyprland.

set -euo pipefail

print_info() { printf "[INFO] %s\n" "$*"; }
print_warn() { printf "[WARN] %s\n" "$*"; }

check_waybar() {
    local cfg="config/waybar/config"
    local cfg_json="config/waybar/config.json"
    if command -v jq >/dev/null 2>&1; then
        if [[ -f "$cfg" ]]; then
            print_info "Validating $cfg"
            jq . "$cfg" >/dev/null
        elif [[ -f "$cfg_json" ]]; then
            print_info "Validating $cfg_json"
            jq . "$cfg_json" >/dev/null
        else
            print_warn "Waybar config not found."
        fi
    else
        print_warn "jq not installed; skipping Waybar validation."
    fi
}

check_hypr() {
    if command -v hyprctl >/dev/null 2>&1; then
        print_info "Running hyprctl check"
        if ! hyprctl check >/dev/null 2>&1; then
            print_warn "Hyprland check reported issues (ensure Hyprland session is active)."
        fi
    else
        print_warn "hyprctl not found; skipping Hyprland check."
    fi
}

check_waybar
check_hypr
