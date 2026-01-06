#!/usr/bin/env bash

# Ubuntu-specific maintenance for the WSU workstation.
set -euo pipefail

log() { echo "[$(date +%Y-%m-%dT%H:%M:%S%z)] $*"; }

log "Updating apt package lists"
sudo apt update

log "Upgrading apt packages"
sudo apt -y upgrade

log "Removing unused packages"
sudo apt -y autoremove

log "Cleaning apt cache"
sudo apt -y autoclean

if command -v flatpak >/dev/null 2>&1; then
  log "Updating Flatpak packages"
  flatpak update -y
fi

if command -v snap >/dev/null 2>&1; then
  log "Refreshing snap packages"
  sudo snap refresh
fi

log "WSU maintenance complete"
