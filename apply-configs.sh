#!/usr/bin/env bash

# Apply neo-brutalist Hyprland design configs on Arch (no package installs)
# Safe to re-run; copies configs and wallpapers, enables user services.

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

ensure_bashrc_sources_custom() {
  local repo_bashrc="${SCRIPT_DIR}/configs/bash/bashrc"
  local target_bashrc="${HOME}/.config/bash/bashrc"
  local repo_bashrc_local="${SCRIPT_DIR}/configs/bash/bashrc.local"
  local target_bashrc_local="${HOME}/.bashrc.local"

  if [[ ! -f "$repo_bashrc" ]]; then
    warn "Repo bashrc not found at ${repo_bashrc}; skipping shell hook"
    return
  fi

  mkdir -p "${HOME}/.config/bash"
  ln -sf "$repo_bashrc" "$target_bashrc"
  if [[ -f "$repo_bashrc_local" ]]; then
    ln -sf "$repo_bashrc_local" "$target_bashrc_local"
  fi

  local hook
  hook=$(cat <<'EOF'
# BEGIN arch-hyprland-setup
if [ -f "$HOME/.config/bash/bashrc" ]; then
  source "$HOME/.config/bash/bashrc"
fi
# END arch-hyprland-setup
EOF
)

  if [[ ! -f ~/.bashrc ]]; then
    cat >~/.bashrc <<EOF
# ~/.bashrc (managed by arch-hyprland-setup)
$hook
EOF
    ok "Created minimal ${HOME}/.bashrc"
    return
  fi

  if rg -q "managed by arch-hyprland-setup|^# BEGIN arch-hyprland-setup$" ~/.bashrc; then
    cat >~/.bashrc <<EOF
# ~/.bashrc (managed by arch-hyprland-setup)
$hook
EOF
    ok "Rewrote managed ${HOME}/.bashrc"
    return
  fi

  sed -i '/^# BEGIN arch-hyprland-setup$/,/^# END arch-hyprland-setup$/d' ~/.bashrc 2>/dev/null || true
  {
    echo
    echo "$hook"
  } >>~/.bashrc
  ok "Appended arch-hyprland-setup block to ${HOME}/.bashrc"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log "Applying Hyprland design configs (no package installs)"

# Ensure target dirs
mkdir -p ~/.config ~/.local/bin ~/Pictures/wallpapers ~/Pictures/screenshots ~/.config/xdg-desktop-portal

# Copy configs while preserving unmanaged app data
if [[ -d "${SCRIPT_DIR}/configs" ]]; then
  shopt -s dotglob nullglob
  for src in "${SCRIPT_DIR}/configs/"*; do
    name="$(basename "$src")"
    if [[ -d "$src" ]]; then
      if [[ "$name" == "applications" ]]; then
        mkdir -p "${HOME}/.local/share/applications"
        rsync -a --delete "$src/" "${HOME}/.local/share/applications/"
      elif [[ "$name" == "bash" ]]; then
        mkdir -p "${HOME}/.config/bash"
        ln -sf "${SCRIPT_DIR}/configs/bash/bashrc" "${HOME}/.config/bash/bashrc"
      else
        mkdir -p "${HOME}/.config/${name}"
        rsync -a --delete "$src/" "${HOME}/.config/${name}/"
      fi
    else
      rsync -a "$src" "${HOME}/.config/"
    fi
  done
  shopt -u dotglob nullglob
  ok "Configs synced to ~/.config and ~/.local/share (existing app data preserved)"
else
  die "configs/ not found next to this script"
fi

# Make scripts executable
if [[ -d ~/.config/scripts ]]; then
  chmod +x ~/.config/scripts/* || true
  ok "Scripts marked executable"
fi

# Wallpapers
if [[ -d "${SCRIPT_DIR}/wallpapers" ]]; then
  rsync -a "${SCRIPT_DIR}/wallpapers/" ~/Pictures/wallpapers/
  ok "Wallpapers copied"
else
  warn "wallpapers/ not found; skipping"
fi

# Minimal shell integration: source custom bashrc if present
ensure_bashrc_sources_custom

# Note: a child process can't "source" your current shell, so we print the command.
if [[ -n "${BASH_VERSION-}" ]]; then
  ok "Load updated shell config with: source ~/.bashrc"
else
  ok "Load updated shell config by restarting your shell (or: bash -lc 'source ~/.bashrc')"
fi

# Enable key user services if installed
systemctl --user daemon-reload || true
if systemctl --user list-unit-files waybar.service >/dev/null 2>&1; then
  systemctl --user enable waybar.service >/dev/null 2>&1 || warn "Failed to enable waybar.service"
  if [[ -n "${WAYLAND_DISPLAY-}" ]]; then
    systemctl --user start waybar.service >/dev/null 2>&1 || warn "Failed to start waybar.service"
  else
    warn "Skipping starting waybar.service (not in a Wayland session)"
  fi
else
  warn "waybar.service not installed"
fi

systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || warn "PipeWire services not available"

ok "Done. Log out/in or start Hyprland to see changes."

# Install application .desktop overrides if present
if [[ -d "${SCRIPT_DIR}/configs/applications" ]]; then
  mkdir -p ~/.local/share/applications
  rsync -a "${SCRIPT_DIR}/configs/applications/" ~/.local/share/applications/
  # Normalize Exec paths: replace leading ~/ with absolute $HOME so launchers (wofi/GIO)
  # don't discard entries due to unexpanded tildes per the .desktop spec.
  for f in ~/.local/share/applications/*.desktop; do
    [[ -f "$f" ]] || continue
    if grep -qE '^Exec=~/' "$f"; then
      sed -i -E "s|^Exec=~/|Exec=${HOME}/|" "$f"
    fi
  done
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database ~/.local/share/applications >/dev/null 2>&1 || true
  fi
  ok "Application launchers updated in ~/.local/share/applications"
fi
