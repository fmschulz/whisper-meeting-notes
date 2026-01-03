#!/bin/bash
# Auto-connect and promote Bluetooth audio devices at session start

set -e

DEVICES=(
  "7C:96:D2:89:1C:B4" # Klipsch One II
)

log() {
  echo "[bluetooth-autoconnect] $*"
}

wait_for_bluetoothd() {
  for _ in {1..10}; do
    if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
      return 0
    fi
    sleep 1
  done
  log "Bluetooth service not ready after 10s"
  return 1
}

ensure_trusted() {
  local mac=$1
  if bluetoothctl info "$mac" 2>/dev/null | grep -q "Trusted: yes"; then
    return 0
  fi

  log "Trusting $mac"
  bluetoothctl trust "$mac" >/dev/null 2>&1 || true
}

connect_device() {
  local mac=$1

  for attempt in {1..3}; do
    bluetoothctl connect "$mac" >/dev/null 2>&1 || true
    sleep 1

    if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
      log "Connected $mac"
      return 0
    fi
    log "Retrying connection to $mac (attempt $attempt)"
  done

  log "Failed to connect to $mac"
  return 1
}

card_ready() {
  local card_name=$1
  pactl list cards short | awk -v card="$card_name" '$2 == card {found=1} END {exit found ? 0 : 1}'
}

set_best_profile() {
  local card_name=$1
  local profiles=(
    "a2dp-sink-aptx_ll"
    "a2dp-sink"
    "a2dp-sink-sbc_xq"
    "a2dp-sink-sbc"
  )

  for profile in "${profiles[@]}"; do
    if pactl set-card-profile "$card_name" "$profile" >/dev/null 2>&1; then
      log "Set $card_name to $profile"
      return 0
    fi
  done

  log "Unable to set A2DP profile on $card_name"
  return 1
}

promote_sink() {
  local mac=$1
  local sink_pattern="bluez_output.${mac//:/_}"
  local sink_name

  sink_name=$(pactl list short sinks | awk -v pattern="$sink_pattern" '$2 ~ "^" pattern {print $2; exit}')
  if [[ -z $sink_name ]]; then
    log "No sink found for $mac"
    return 1
  fi

  pactl set-default-sink "$sink_name"
  pactl list short sink-inputs | awk '{print $1}' | xargs -r -I{} pactl move-sink-input {} "$sink_name"
  log "Default sink set to $sink_name"
}

wait_for_bluetoothd || exit 0

for device in "${DEVICES[@]}"; do
  ensure_trusted "$device"

  if ! connect_device "$device"; then
    continue
  fi

  card_name="bluez_card.${device//:/_}"

  for _ in {1..5}; do
    if card_ready "$card_name"; then
      set_best_profile "$card_name" || true
      promote_sink "$device" || true
      break
    fi
    sleep 1
  done
done
