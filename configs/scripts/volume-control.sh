#!/bin/bash

# Ensure volume keys adjust the active sink. Prefer the internal codec when it
# isn't suspended so laptop speakers/headphones keep working even with a dock.

set -euo pipefail

INTERNAL_SINK="alsa_output.pci-0000_c1_00.6.analog-stereo"
STEP="${2:-5}"
if ! [[ $STEP =~ ^[0-9]+$ ]]; then
  STEP=5
fi
DEFAULT_TARGET="@DEFAULT_SINK@"

if command -v pactl >/dev/null 2>&1; then
  if pactl list sinks short | awk '{print $2}' | grep -qx "$INTERNAL_SINK"; then
    state=$(pactl list sinks | awk -v name="$INTERNAL_SINK" '
      $0 ~ "^\tName: "name"$" {found=1; next}
      found && $0 ~ "^\tState: " {gsub("\r", "", $2); print $2; exit}
    ')
    if [[ -n ${state:-} && $state != "SUSPENDED" ]]; then
      pactl set-default-sink "$INTERNAL_SINK" >/dev/null
      DEFAULT_TARGET="$INTERNAL_SINK"
    fi
  fi
else
  echo "pactl is required but not available" >&2
  exit 1
fi

case "${1:-}" in
  up)
    pactl set-sink-volume "$DEFAULT_TARGET" "+${STEP}%"
    ;;
  down)
    pactl set-sink-volume "$DEFAULT_TARGET" "-${STEP}%"
    ;;
  mute)
    pactl set-sink-mute "$DEFAULT_TARGET" toggle
    ;;
  *)
    echo "Usage: $0 {up|down|mute} [step-percent]" >&2
    exit 1
    ;;
esac
