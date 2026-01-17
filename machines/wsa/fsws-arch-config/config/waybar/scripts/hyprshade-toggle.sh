#!/bin/bash
# Toggle hyprshade shaders; defaults to "blue-light-filter".

set -euo pipefail

shader="${1:-blue-light-filter}"

if command -v hyprshade >/dev/null 2>&1; then
    if hyprshade current | grep -q "$shader"; then
        hyprshade disable "$shader"
    else
        hyprshade enable "$shader"
    fi
else
    echo "hyprshade not found" >&2
fi
