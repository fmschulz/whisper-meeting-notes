#!/bin/bash
# Simple cliphist wrapper for menu actions.

set -euo pipefail

ACTION="${1:-menu}" # menu | delete | wipe

case "$ACTION" in
    menu)
        cliphist list | rofi -dmenu | cliphist decode | wl-copy
        ;;
    delete)
        cliphist list | rofi -dmenu | cliphist delete
        ;;
    wipe)
        cliphist wipe
        ;;
    *)
        echo "Usage: $0 [menu|delete|wipe]" >&2
        exit 1
        ;;
esac
