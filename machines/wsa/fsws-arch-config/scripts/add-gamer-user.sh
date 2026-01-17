#!/bin/bash
# Create a new desktop user for gaming, optionally set up a shared Steam library

set -euo pipefail

usage() {
    cat <<EOF
Usage: sudo $(basename "$0") <username> [--sudo] [--share-library <path>]

Options:
  --sudo                 Add the user to the wheel group (sudo access)
  --share-library <dir>  Create a shared Steam library directory and grant
                         access to both the current user and the new user.

Notes:
  - Requires root (run with sudo).
  - Adds user to useful desktop groups: video,input,audio.
  - Does not auto-enable user services; after first login the user can run:
      systemctl --user enable --now gamemoded
EOF
}

require_root() {
    if [[ ${EUID:-} -ne 0 ]]; then
        echo "This command must be run as root (use sudo)." >&2
        exit 1
    fi
}

ensure_pkg() {
    local pkg="$1"
    if ! pacman -Q "$pkg" >/dev/null 2>&1; then
        pacman -S --needed --noconfirm "$pkg"
    fi
}

create_user_if_missing() {
    local user="$1"; shift || true
    if id "$user" >/dev/null 2>&1; then
        echo "User '$user' already exists."
        return 0
    fi
    useradd -m -s /bin/bash "$user"
    echo "Created user '$user' with home directory."
    echo "Set a password now:"
    passwd "$user"
}

add_to_groups() {
    local user="$1"; shift || true
    local groups=(video input audio)
    for g in "${groups[@]}"; do
        getent group "$g" >/dev/null 2>&1 || groupadd "$g"
        usermod -aG "$g" "$user"
    done
}

maybe_add_sudo() {
    local user="$1"; shift || true
    if [[ "${ADD_SUDO:-0}" == "1" ]]; then
        getent group wheel >/dev/null 2>&1 || groupadd wheel
        usermod -aG wheel "$user"
        echo "Added '$user' to wheel (sudo)."
        if ! grep -q '^%wheel' /etc/sudoers; then
            echo "WARNING: wheel not active in sudoers. Consider enabling with visudo." >&2
        fi
    fi
}

setup_shared_library() {
    local newuser="$1"; shift
    local otheruser="${SUDO_USER:-${LOGNAME:-}}"
    local libdir="$1"

    if [[ -z "$libdir" ]]; then
        return 0
    fi

    # Ensure dependencies for ACLs
    ensure_pkg acl

    # Create a shared group and directory
    local grp="steamshare"
    getent group "$grp" >/dev/null 2>&1 || groupadd "$grp"
    usermod -aG "$grp" "$newuser"
    if [[ -n "$otheruser" ]]; then
        id "$otheruser" >/dev/null 2>&1 && usermod -aG "$grp" "$otheruser" || true
    fi

    mkdir -p "$libdir"
    chown root:"$grp" "$libdir"
    chmod 2775 "$libdir"   # setgid so new files inherit group
    setfacl -m g:"$grp":rwx "$libdir"
    setfacl -d -m g:"$grp":rwx "$libdir"

    echo "Shared Steam library prepared at: $libdir"
    echo "Add this folder in Steam (Settings → Storage) for each user."
}

main() {
    require_root
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi

    local user="$1"; shift
    local share_dir=""
    ADD_SUDO=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --sudo)
                ADD_SUDO=1; shift ;;
            --share-library)
                share_dir="${2:-}"; shift 2 ;;
            -h|--help)
                usage; exit 0 ;;
            *)
                echo "Unknown option: $1" >&2; usage; exit 1 ;;
        esac
    done

    create_user_if_missing "$user"
    add_to_groups "$user"
    maybe_add_sudo "$user"
    if [[ -n "$share_dir" ]]; then
        setup_shared_library "$user" "$share_dir"
    fi

    echo "Done. Next steps for $user:"
    echo "  1) Log in graphically (SDDM) so a user session starts."
    echo "  2) Run: systemctl --user enable --now gamemoded"
    echo "  3) Launch Steam; choose or add the shared library if configured."
}

main "$@"

