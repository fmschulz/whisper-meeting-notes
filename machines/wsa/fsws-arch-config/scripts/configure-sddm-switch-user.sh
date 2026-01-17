#!/bin/bash
# Ensure SDDM greeter shows user selection instead of forcing last user.
# - Sets ForceLastUser=false in sugar-candy theme config (if present)
# - Ensures SDDM Users section does not hide users
# - Disables any lingering autologin bits (optional prompt)

set -euo pipefail

require_root() {
    if [[ ${EUID:-} -ne 0 ]]; then
        echo "Run as root: sudo $0" >&2
        exit 1
    fi
}

write_users_conf() {
    mkdir -p /etc/sddm.conf.d
    cat >/etc/sddm.conf.d/90-nexus-users.conf <<'EOF'
[Users]
MaximumUid=60000
MinimumUid=1000
# Show all users (do not hide list)
HideUsers=
RememberLastUser=true
RememberLastSession=true
EOF
    echo "Wrote /etc/sddm.conf.d/90-nexus-users.conf"
}

patch_sugar_candy_theme() {
    local theme_dir="/usr/share/sddm/themes/sugar-candy"
    local cfg="$theme_dir/theme.conf"
    if [[ -d "$theme_dir" ]]; then
        echo "Configuring sugar-candy theme at $cfg"
        install -d -m 0755 "$theme_dir"
        if [[ ! -f "$cfg" ]]; then
            touch "$cfg"
        fi
        # Ensure [General] section exists and ForceLastUser=false
        if ! grep -q '^\[General\]' "$cfg"; then
            echo "[General]" >> "$cfg"
        fi
        if grep -q '^ForceLastUser=' "$cfg"; then
            sed -i 's/^ForceLastUser=.*/ForceLastUser=false/' "$cfg"
        else
            printf '\nForceLastUser=false\n' >> "$cfg"
        fi
        # Some sugar-candy forks support ShowUserList; safe to add
        if ! grep -q '^ShowUserList=' "$cfg"; then
            printf 'ShowUserList=true\n' >> "$cfg"
        fi
    else
        echo "sugar-candy theme not found; skipping theme config"
    fi
}

maybe_disable_autologin() {
    # If an autologin config exists, offer to disable it
    local autologin_conf="/etc/sddm.conf.d/autologin.conf"
    if [[ -f "$autologin_conf" ]] && grep -q '^User=' "$autologin_conf"; then
        echo "Autologin appears enabled in $autologin_conf"
        read -r -p "Disable autologin now? [y/N] " ans
        if [[ "${ans,,}" == "y" ]]; then
            sed -i 's/^User=.*/# User=/' "$autologin_conf"
            sed -i 's/^Session=.*/# Session=/' "$autologin_conf"
            echo "Autologin disabled."
        else
            echo "Leaving autologin as-is."
        fi
    fi
}

main() {
    require_root
    write_users_conf
    patch_sugar_candy_theme
    maybe_disable_autologin
    echo "Done. Restart the display manager to apply: sudo systemctl restart sddm"
}

main "$@"

