#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Sync config directories
for comp in hypr waybar kitty starship yazi mako wofi scripts bash hypridle; do
    if [[ -d "$HOME/.config/$comp" ]]; then
        rsync -av --delete "$HOME/.config/$comp/" "$SCRIPT_DIR/configs/$comp/"
        echo "Synced: $comp"
    fi
done

# Sync systemd user services
if [[ -d "$HOME/.config/systemd/user" ]]; then
    mkdir -p "$SCRIPT_DIR/configs/systemd/user"
    rsync -av "$HOME/.config/systemd/user/"*.{service,timer} "$SCRIPT_DIR/configs/systemd/user/" 2>/dev/null || true
    echo "Synced: systemd/user"
fi

echo -e "\nDone. Review with: cd $SCRIPT_DIR && git diff"
