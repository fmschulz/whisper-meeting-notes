#!/bin/bash
set -euo pipefail

# Launch Steam wrapped with Gamescope + Gamemode + MangoHud
# Usage: scripts/steam-gamescope.sh [extra gamescope args]

GAMESCOPE_ARGS=("-f")
if [[ $# -gt 0 ]]; then
    GAMESCOPE_ARGS=("$@")
fi

export MANGOHUD=${MANGOHUD:-1}

if command -v gamescope >/dev/null 2>&1; then
    exec gamemoderun gamescope "${GAMESCOPE_ARGS[@]}" -- steam
else
    exec MANGOHUD=1 gamemoderun steam
fi

