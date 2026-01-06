#!/bin/bash

# Configure systemd sleep mode based on available kernel options.
# Prefers deep (S3) when firmware exposes it, otherwise falls back to s2idle (S0ix).

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "configure-sleep.sh must be run as root" >&2
  exit 1
fi

MEM_SLEEP_FILE=/sys/power/mem_sleep
TARGET_DIR=/etc/systemd/sleep.conf.d
TARGET_FILE=${TARGET_DIR}/arch-hyprland.conf

if [[ ! -r ${MEM_SLEEP_FILE} ]]; then
  echo "Cannot read ${MEM_SLEEP_FILE}; leaving sleep configuration unchanged." >&2
  exit 0
fi

if grep -qw deep "${MEM_SLEEP_FILE}"; then
  mode=deep
else
  mode=s2idle
fi

mkdir -p "${TARGET_DIR}"

cat >"${TARGET_FILE}" <<EOF_CONF
[Sleep]
SuspendState=mem
SuspendMode=${mode}
EOF_CONF

chmod 644 "${TARGET_FILE}"

if [[ ${mode} == deep ]]; then
  echo "Configured SuspendMode=deep (S3)."
  echo "If suspend fails, ensure BIOS Standby is set to Linux to keep S3 exposed."
else
  echo "Configured SuspendMode=s2idle (S0ix)."
  echo "Firmware does not expose deep sleep; switch BIOS Standby to Linux if S3 is desired."
fi
