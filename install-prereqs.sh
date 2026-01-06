#!/usr/bin/env bash

# Minimal prerequisites installer for Arch-based systems.
# Installs only what's needed to run apply-configs.sh and launch the desktop.

set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
log() { echo -e "${BLUE}▶${NC} $*"; }
ok() { echo -e "${GREEN}✓${NC} $*"; }
die() {
  echo -e "${RED}✖${NC} $*"
  exit 1
}

if [[ $EUID -eq 0 ]]; then
  die "Run as a regular user (sudo will be used as needed)."
fi

PKGS=(
  hyprland
  waybar
  wofi
  kitty
  mako
  swww
  grim
  slurp
  wl-clipboard
  cliphist
  brightnessctl
  playerctl
  pavucontrol
  pipewire
  pipewire-pulse
  pipewire-alsa
  wireplumber
  noto-fonts
  noto-fonts-emoji
  ttf-jetbrains-mono-nerd
  bibata-cursor-theme
  xdg-desktop-portal-hyprland
)

log "Refreshing package database"
sudo pacman -Syu --noconfirm

log "Installing prerequisites (${#PKGS[@]} packages)"
sudo pacman -S --needed --noconfirm "${PKGS[@]}"

ok "Prerequisites installed. You can now run ./apply-configs.sh"
