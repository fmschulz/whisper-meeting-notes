#!/bin/bash
set -euo pipefail

# Probe Thermaltake LCD/ARGB USB devices and collect diagnostics for driver work.
#
# Usage: scripts/tt-lcd-probe.sh [vendor_hex]
# Default vendor: 264a (Thermaltake)

VENDOR="${1:-264a}"
OUTDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)/logs/tt-probe-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTDIR"

log() { echo "[tt-probe] $*"; }

log "Writing probe output to: $OUTDIR"

{
  echo "== uname -a =="; uname -a; echo
  echo "== lsusb (matching vendor ${VENDOR}) =="; lsusb | grep -i "${VENDOR}\|thermaltake\|lcd\|display" || true; echo
  echo "== lsusb -t =="; lsusb -t; echo
} > "$OUTDIR/summary.txt" 2>&1 || true

# Detailed USB descriptor (requires sudo for full verbosity on some systems)
sudo lsusb -d ${VENDOR}: -v > "$OUTDIR/lsusb-v.txt" 2>&1 || true

# usb-devices full dump
usb-devices > "$OUTDIR/usb-devices.txt" 2>&1 || true

# HID raw nodes and udev info
{
  echo "== hidraw nodes ==";
  ls -l /dev/hidraw* 2>/dev/null || true
  for n in /dev/hidraw*; do
    [[ -e "$n" ]] || continue
    echo; echo "== udevadm info for $n ==";
    udevadm info -a -n "$n" 2>/dev/null | sed -n '1,120p'
  done
} > "$OUTDIR/hidraw-udev.txt" 2>&1 || true

# liquidctl detection
{
  echo "== liquidctl list =="; liquidctl list || true
} > "$OUTDIR/liquidctl.txt" 2>&1 || true

# OpenRGB device list
{
  echo "== openrgb --list-devices =="; 
  if command -v openrgb >/dev/null 2>&1; then
    openrgb --list-devices 2>&1 || openrgb --list 2>&1 || true
  else
    echo "openrgb not installed"
  fi
} > "$OUTDIR/openrgb.txt" 2>&1 || true

# Recent kernel messages around USB
dmesg | tail -n 400 > "$OUTDIR/dmesg-tail.txt" 2>&1 || true

log "Probe complete. Please share the files in $OUTDIR for analysis."

