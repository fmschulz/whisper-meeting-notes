#!/usr/bin/env bash

# Sync Arch Hyprland configs from a live NixOS/Home‑Manager setup.
# Strategy: copy rendered configs from ~/.config (resolving symlinks)
# and wallpapers from this repo. Run this on the NixOS machine after HM switch.

set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
log() { echo -e "${BLUE}▶${NC} $*"; }
ok() { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
die() {
  echo -e "${RED}✖${NC} $*"
  exit 1
}

SRC_HOME=${SRC_HOME:-"$HOME"}
SRC_CONFIG="$SRC_HOME/.config"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
DEST_ARCH_DIR="$REPO_ROOT/arch-hyprland-setup"
DEST_CONFIG_DIR="$DEST_ARCH_DIR/configs"

if [[ ! -d "$SRC_CONFIG" ]]; then
  die "Source config directory not found: $SRC_CONFIG"
fi

log "Syncing from $SRC_CONFIG to $DEST_CONFIG_DIR"
mkdir -p "$DEST_CONFIG_DIR"

# Components to sync from live HM-managed ~/.config
components=(
  hypr
  waybar
  kitty
  starship
  yazi
  mako
  wofi
  scripts
)

for comp in "${components[@]}"; do
  if [[ -d "$SRC_CONFIG/$comp" ]]; then
    mkdir -p "$DEST_CONFIG_DIR/$comp"
    rsync -a --delete --copy-links "$SRC_CONFIG/$comp/" "$DEST_CONFIG_DIR/$comp/"
    ok "Synced $comp"
  else
    warn "Skipping $comp (not found at $SRC_CONFIG/$comp)"
  fi
done

# Bash config is maintained in repo under home-manager/config/bashrc
if [[ -f "$REPO_ROOT/home-manager/config/bashrc" ]]; then
  mkdir -p "$DEST_CONFIG_DIR/bash"
  cp "$REPO_ROOT/home-manager/config/bashrc" "$DEST_CONFIG_DIR/bash/bashrc"
  ok "Updated bash/bashrc from repo"
else
  warn "home-manager/config/bashrc not found in repo"
fi

# Wallpapers from repo to arch setup
if [[ -d "$REPO_ROOT/home-manager/wallpapers" ]]; then
  mkdir -p "$DEST_ARCH_DIR/wallpapers"
  rsync -a "$REPO_ROOT/home-manager/wallpapers/" "$DEST_ARCH_DIR/wallpapers/"
  ok "Synced wallpapers"
else
  warn "home-manager/wallpapers not found in repo"
fi

ok "Sync complete. Review diffs and commit changes."
