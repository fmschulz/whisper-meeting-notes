#!/bin/bash

# Fix Chromium window if it spawned off-screen or with invalid size.
# Centers and resizes the first Chromium/Chrome window it finds.

set -euo pipefail

addr=$(hyprctl -j clients | jq -r '.[] | select(.class|test("Chromium|chromium|Chrome")) | .address' | head -n1)
[[ -z "${addr}" || "${addr}" == "null" ]] && exit 0

hyprctl dispatch focuswindow "address:${addr}" >/dev/null 2>&1 || true
hyprctl dispatch togglefloating >/dev/null 2>&1 || true
hyprctl dispatch resizeactive exact 1200 800 >/dev/null 2>&1 || true
hyprctl dispatch centerwindow >/dev/null 2>&1 || true

