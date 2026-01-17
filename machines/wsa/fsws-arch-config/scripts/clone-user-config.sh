#!/bin/bash
# Clone NEXUS desktop configs from one user to another.
# Requires root to write into the destination user's home.

set -euo pipefail

readonly LOG_TAG="[clone-user-config]"

info() { echo "$(date -Is) ${LOG_TAG} INFO: $*"; }
warn() { echo "$(date -Is) ${LOG_TAG} WARN: $*" >&2; }
err()  { echo "$(date -Is) ${LOG_TAG} ERROR: $*" >&2; }

usage() {
    cat <<EOF
Usage: sudo $(basename "$0") <from_user> <to_user> [--dry-run] [--include-shell]

Copies NEXUS-related configs so Waybar/Hyprland/keybindings/themes match.

Copies (if present):
  ~/.config/{hypr,waybar,rofi,kitty,dunst}
  ~/.config/{starship.toml,modern-aliases.sh}
  ~/.config/gtk-3.0/settings.ini and gtk-4.0/settings.ini
  ~/.local/bin/update-notifier.sh
  ~/Pictures/Wallpapers/*
  ~/.bashrc (overwrites; backup created) when --include-shell is provided

Notes:
  - Requires root to write into the destination user's home.
  - Creates backups in the destination as ~/.config-backup-<timestamp>.
  - Use --dry-run to preview without copying.
EOF
}

require_root() {
    if [[ ${EUID:-} -ne 0 ]]; then
        err "Must run as root (use sudo)."
        exit 1
    fi
}

user_home() {
    local u="$1"
    local h
    h=$(getent passwd "$u" | cut -d: -f6)
    [[ -n "$h" ]] || { err "Cannot resolve home for user $u"; exit 1; }
    echo "$h"
}

copy_item() {
    local src="$1" dst="$2" owner="$3" dry="$4"
    if [[ ! -e "$src" ]]; then
        return 0
    fi
    local dst_dir
    dst_dir=$(dirname "$dst")
    if [[ "$dry" == "1" ]]; then
        info "DRY-RUN: copy $src -> $dst"
        return 0
    fi
    mkdir -p "$dst_dir"
    if command -v rsync >/dev/null 2>&1; then
        # Copy with symlinks dereferenced so destination gets real files
        rsync -aL --delete "$src" "$dst" 2>/dev/null || rsync -aL "$src" "$dst"
    else
        # Fallback: cp -a (no delete)
        if [[ -d "$src" ]]; then
            cp -aL "$src" "$dst_dir/"
        else
            cp -aL "$src" "$dst"
        fi
    fi
    chown -R "$owner":"$owner" "$dst_dir" || true
}

backup_if_exists() {
    local path="$1" owner="$2" dry="$3" now
    now=$(date +%Y%m%d_%H%M%S)
    if [[ -e "$path" ]]; then
        local base
        base=$(basename "$path")
        local bdir
        bdir="$(dirname "$path")/.config-backup-$now"
        if [[ "$dry" == "1" ]]; then
            info "DRY-RUN: backup $path -> $bdir/$base"
            return 0
        fi
        mkdir -p "$bdir"
        cp -a "$path" "$bdir/" 2>/dev/null || true
        chown -R "$owner":"$owner" "$bdir" || true
    fi
}

parse_args() {
    local opt
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) dry_run=1 ;;
            --include-shell) include_shell=1 ;;
            *) break ;;
        esac
        shift
    done
    from_user="${1:-}"
    to_user="${2:-}"
}

main() {
    local opt
    local from_user to_user
    local dry_run=0 include_shell=0

    parse_args "$@"

    if [[ -z "$from_user" || -z "$to_user" ]]; then
        usage; exit 1
    fi

    require_root

    local src_home dst_home owner
    src_home=$(user_home "$from_user")
    dst_home=$(user_home "$to_user")
    owner="$to_user"

    info "Cloning configs from $from_user ($src_home) -> $to_user ($dst_home)" 
    [[ "$dry_run" == "1" ]] && warn "Dry-run: no changes will be made"

    # Create target base dirs
    [[ "$dry_run" == "1" ]] || mkdir -p "$dst_home/.config" "$dst_home/.local/bin"

    # Backup key paths in destination
    backup_if_exists "$dst_home/.config/hypr" "$owner" "$dry_run"
    backup_if_exists "$dst_home/.config/waybar" "$owner" "$dry_run"
    backup_if_exists "$dst_home/.config/rofi" "$owner" "$dry_run"
    backup_if_exists "$dst_home/.config/kitty" "$owner" "$dry_run"
    backup_if_exists "$dst_home/.config/dunst" "$owner" "$dry_run"
    backup_if_exists "$dst_home/.bashrc" "$owner" "$dry_run"

    # Copy directories
    copy_item "$src_home/.config/hypr" "$dst_home/.config/" "$owner" "$dry_run"
    copy_item "$src_home/.config/waybar" "$dst_home/.config/" "$owner" "$dry_run"
    copy_item "$src_home/.config/rofi" "$dst_home/.config/" "$owner" "$dry_run"
    copy_item "$src_home/.config/kitty" "$dst_home/.config/" "$owner" "$dry_run"
    copy_item "$src_home/.config/dunst" "$dst_home/.config/" "$owner" "$dry_run"

    # Copy files
    copy_item "$src_home/.config/starship.toml" "$dst_home/.config/starship.toml" "$owner" "$dry_run"
    copy_item "$src_home/.config/modern-aliases.sh" "$dst_home/.config/modern-aliases.sh" "$owner" "$dry_run"
    copy_item "$src_home/.config/gtk-3.0/settings.ini" "$dst_home/.config/gtk-3.0/settings.ini" "$owner" "$dry_run"
    copy_item "$src_home/.config/gtk-4.0/settings.ini" "$dst_home/.config/gtk-4.0/settings.ini" "$owner" "$dry_run"
    copy_item "$src_home/.local/bin/update-notifier.sh" "$dst_home/.local/bin/update-notifier.sh" "$owner" "$dry_run"
    copy_item "$src_home/Pictures/Wallpapers" "$dst_home/Pictures/" "$owner" "$dry_run"

    # Copy bashrc last (overwrites) when requested
    if [[ "$include_shell" == "1" ]]; then
        copy_item "$src_home/.bashrc" "$dst_home/.bashrc" "$owner" "$dry_run"
    fi

    info "Done. You may need to re-login as $to_user to apply shell changes."
}

main "$@"
