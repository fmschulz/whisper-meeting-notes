#!/bin/bash
# Toggle hypridle inhibitor.

set -euo pipefail

if command -v hyprctl >/dev/null 2>&1; then
    state=$(hyprctl getoption general:idle_inhibit_v2 2>/dev/null | awk '/int:/ {print $2}')
    if [[ "$state" == "0" ]]; then
        hyprctl keyword general:idle_inhibit_v2 1
        echo '{"text":""}'
    else
        hyprctl keyword general:idle_inhibit_v2 0
        echo '{"text":""}'
    fi
else
    echo '{"text":""}'
fi
