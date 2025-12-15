#!/bin/bash

# Arch Linux Hyprland Setup Script
# Extracted from NixOS configuration for neo-brutalist Hyprland environment
# Run as regular user (not root)

set -e # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Neo-brutalist banner
echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║${NC}  ${PURPLE}▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄${NC}  ${YELLOW}║${NC}"
echo -e "${YELLOW}║${NC}  ${PURPLE}█${NC} ${CYAN}ARCH LINUX HYPRLAND SETUP${NC} ${PURPLE}█${NC}                        ${YELLOW}║${NC}"
echo -e "${YELLOW}║${NC}  ${PURPLE}█${NC} ${GREEN}Neo-Brutalist Theme${NC} ${PURPLE}█${NC}                              ${YELLOW}║${NC}"
echo -e "${YELLOW}║${NC}  ${PURPLE}▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀${NC}  ${YELLOW}║${NC}"
echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
echo

# Check if running as root
if [[ $EUID -eq 0 ]]; then
  echo -e "${RED}❌ This script should NOT be run as root!${NC}"
  echo -e "${YELLOW}Please run as your regular user account.${NC}"
  exit 1
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${BLUE}🚀 Starting Arch Linux Hyprland setup...${NC}"
echo

# Function to print step headers
print_step() {
  echo -e "${PURPLE}▶ $1${NC}"
}

# Function to check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Username (used for some setup steps)
USER_NAME=$(whoami)

# Detect if we are currently in a Wayland/Hyprland desktop session
in_active_wayland_session() {
  if [[ -n "${WAYLAND_DISPLAY:-}" ]] || [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    return 0
  fi
  # Fallback: check loginctl session type if available
  if command -v loginctl >/dev/null 2>&1 && [[ -n "${XDG_SESSION_ID:-}" ]]; then
    if loginctl show-session "$XDG_SESSION_ID" -p Type 2>/dev/null | grep -qi 'Type=wayland'; then
      return 0
    fi
  fi
  return 1
}

# Read newline-separated package names from a file into the provided array ref.
read_package_file() {
  local file=$1
  local -n target=$2

  while IFS= read -r line || [[ -n $line ]]; do
    [[ -z ${line//[[:space:]]/} ]] && continue
    [[ ${line} =~ ^# ]] && continue
    target+=("$line")
  done <"$file"
}

# Best-effort detection for AMD systems (GPU or CPU string match).
is_amd_system() {
  if command -v lspci >/dev/null 2>&1; then
    if lspci -nn | grep -qiE 'VGA.*AMD|Display.*AMD|Advanced Micro Devices'; then
      return 0
    fi
  fi

  if grep -qi 'AMD' /proc/cpuinfo 2>/dev/null; then
    return 0
  fi

  return 1
}

# Best-effort detection for Intel (GPU or CPU string match).
is_intel_system() {
  if command -v lspci >/dev/null 2>&1; then
    if lspci -nn | grep -qiE 'VGA.*Intel|Display.*Intel|Intel Corporation'; then
      return 0
    fi
  fi

  if grep -qi 'GenuineIntel' /proc/cpuinfo 2>/dev/null; then
    return 0
  fi

  return 1
}

# Update system
print_step "Updating system packages"
sudo pacman -Syu --noconfirm

# Install base-devel if not present (needed for AUR)
print_step "Installing base development tools"
sudo pacman -S --needed --noconfirm base-devel git

# Install yay AUR helper if not present
if ! command_exists yay; then
  print_step "Installing yay AUR helper"
  cd /tmp
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm
  cd "$SCRIPT_DIR"
else
  echo -e "${GREEN}✓ yay already installed${NC}"
fi

amd_profile=0
intel_profile=0
if is_amd_system; then
  amd_profile=1
  echo -e "${BLUE}ℹ Detected AMD hardware; including AMD-specific package sets.${NC}"
elif is_intel_system; then
  intel_profile=1
  echo -e "${BLUE}ℹ Detected Intel hardware; including Intel-specific package sets.${NC}"
fi

# Install official packages
print_step "Installing official repository packages"
if [[ -f "packages/pacman-packages.txt" ]]; then
  pacman_packages=()
  read_package_file "packages/pacman-packages.txt" pacman_packages

  if (( amd_profile )) && [[ -f "packages/pacman-packages-amd.txt" ]]; then
    echo -e "${GREEN}✓ Adding packages/pacman-packages-amd.txt${NC}"
    read_package_file "packages/pacman-packages-amd.txt" pacman_packages
  fi
  if (( intel_profile )) && [[ -f "packages/pacman-packages-intel.txt" ]]; then
    echo -e "${GREEN}✓ Adding packages/pacman-packages-intel.txt${NC}"
    read_package_file "packages/pacman-packages-intel.txt" pacman_packages
  fi

  if ((${#pacman_packages[@]})); then
    readarray -t pacman_packages < <(printf '%s\n' "${pacman_packages[@]}" | awk '!seen[$0]++')
    sudo pacman -S --needed --noconfirm "${pacman_packages[@]}"
  fi
else
  echo -e "${RED}❌ packages/pacman-packages.txt not found${NC}"
  exit 1
fi

# Install AUR packages
print_step "Installing AUR packages"
if [[ -f "packages/aur-packages.txt" ]]; then
  aur_packages=()
  read_package_file "packages/aur-packages.txt" aur_packages

  if (( amd_profile )) && [[ -f "packages/aur-packages-amd.txt" ]]; then
    echo -e "${GREEN}✓ Adding packages/aur-packages-amd.txt${NC}"
    read_package_file "packages/aur-packages-amd.txt" aur_packages
  fi
  if (( intel_profile )) && [[ -f "packages/aur-packages-intel.txt" ]]; then
    echo -e "${GREEN}✓ Adding packages/aur-packages-intel.txt${NC}"
    read_package_file "packages/aur-packages-intel.txt" aur_packages
  fi

  if ((${#aur_packages[@]})); then
    readarray -t aur_packages < <(printf '%s\n' "${aur_packages[@]}" | awk '!seen[$0]++')
    yay -S --needed --noconfirm "${aur_packages[@]}"
  fi
else
  echo -e "${YELLOW}⚠ packages/aur-packages.txt not found, skipping AUR packages${NC}"
fi

# Ensure Codex CLI and Microsoft VS Code are installed
print_step "Setting up Codex CLI and Microsoft VS Code"
if command_exists yay; then
  if pacman -Qi openai-codex-bin >/dev/null 2>&1; then
    echo -e "${GREEN}✓ openai-codex-bin already installed${NC}"
  elif [[ -x /usr/bin/codex ]] && ! pacman -Qo /usr/bin/codex >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Found existing /usr/bin/codex not owned by a package; skipping openai-codex-bin install${NC}"
  else
    yay -S --needed --noconfirm openai-codex-bin
  fi

  if pacman -Qi visual-studio-code-bin >/dev/null 2>&1; then
    echo -e "${GREEN}✓ visual-studio-code-bin already installed${NC}"
  else
    yay -S --needed --noconfirm visual-studio-code-bin
  fi
else
  echo -e "${YELLOW}⚠ Skipping Codex and VS Code installation because yay is unavailable${NC}"
fi

# Create necessary directories
print_step "Creating configuration directories"
mkdir -p ~/.config
mkdir -p ~/.local/share
mkdir -p ~/.local/bin
mkdir -p ~/Pictures/wallpapers
mkdir -p ~/Pictures/screenshots

# Copy configurations
print_step "Installing configuration files"
if [[ -d "configs" ]]; then
  shopt -s dotglob nullglob
  for src in "${SCRIPT_DIR}/configs/"*; do
    name="$(basename "$src")"
    if [[ -d "$src" ]]; then
      if [[ "$name" == "applications" ]]; then
        mkdir -p "${HOME}/.local/share/applications"
        rsync -a --delete "$src/" "${HOME}/.local/share/applications/"
      else
        mkdir -p "${HOME}/.config/${name}"
        rsync -a --delete "$src/" "${HOME}/.config/${name}/"
      fi
    else
      rsync -a "$src" "${HOME}/.config/"
    fi
  done
  shopt -u dotglob nullglob
  echo -e "${GREEN}✓ Configuration files copied to ~/.config and ~/.local/share${NC}"
else
  echo -e "${RED}❌ configs directory not found${NC}"
  exit 1
fi

# Make scripts executable
print_step "Setting up scripts"
if [[ -d ~/.config/scripts ]]; then
  chmod +x ~/.config/scripts/*
  echo -e "${GREEN}✓ Scripts made executable${NC}"
fi

# Copy wallpapers
print_step "Installing wallpapers"
if [[ -d "wallpapers" ]]; then
  cp wallpapers/* ~/Pictures/wallpapers/
  echo -e "${GREEN}✓ Wallpapers copied${NC}"
else
  echo -e "${YELLOW}⚠ wallpapers directory not found${NC}"
fi

# Set up shell configuration
print_step "Setting up shell configuration"
if [[ -f ~/.config/bash/bashrc ]]; then
  # Backup existing bashrc
  if [[ -f ~/.bashrc ]]; then
    cp ~/.bashrc ~/.bashrc.backup
    echo -e "${YELLOW}⚠ Backed up existing ~/.bashrc to ~/.bashrc.backup${NC}"
  fi

  # Create new bashrc that sources our config
  cat >~/.bashrc <<'EOF'
# Arch Linux Hyprland Setup - Custom bashrc
# Minimal ~/.bashrc; all customizations live in ~/.config/bash/bashrc
# (including PATH, aliases, prompt, and optional ~/.secrets)
if [ -f ~/.config/bash/bashrc ]; then
    source ~/.config/bash/bashrc
fi
EOF
  echo -e "${GREEN}✓ Shell configuration set up${NC}"
fi

# Enable and start services
print_step "Enabling system services"
systemctl --user enable --now pipewire pipewire-pulse wireplumber
systemctl --user enable xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
systemctl --user enable --now waybar 2>/dev/null || true
sudo systemctl enable bluetooth
sudo systemctl enable NetworkManager
sudo systemctl enable --now systemd-timesyncd
sudo timedatectl set-ntp true || true
sudo systemctl enable --now tailscaled

# Configure suspend mode
print_step "Configuring sleep mode"
sudo bash "$SCRIPT_DIR/scripts/setup/configure-sleep.sh"

# Configure USB automount for USB-C sticks
print_step "Configuring USB automount"
sudo bash "$SCRIPT_DIR/scripts/setup/configure-usb-automount.sh" "$USER_NAME"

# Set up fonts
print_step "Refreshing font cache"
fc-cache -fv

# Create desktop entry for Hyprland (if using a display manager)
print_step "Setting up Hyprland desktop entry"
sudo mkdir -p /usr/share/wayland-sessions
sudo tee /usr/share/wayland-sessions/hyprland.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=Hyprland
Comment=Hyprland Wayland session
Exec=/usr/bin/systemd-cat -t hyprland-session /usr/bin/dbus-run-session /usr/bin/Hyprland
Type=Application
DesktopNames=Hyprland
EOF

# Configure greetd with regreet theme
print_step "Configuring greetd login"
if in_active_wayland_session; then
  echo -e "${YELLOW}⚠ Active Wayland session detected. Skipping greetd reconfiguration to avoid terminating your session.${NC}"
  echo -e "${YELLOW}  To apply greeter settings later, run:${NC}"
  echo -e "    sudo bash \"$SCRIPT_DIR/scripts/setup/configure-regreet.sh\" \"$USER_NAME\""
  echo -e "${YELLOW}  Then restart greeter from a TTY: sudo systemctl restart seatd greetd${NC}"
else
  sudo bash "$SCRIPT_DIR/scripts/setup/configure-regreet.sh" "$USER_NAME"
fi

# Configure system performance (sysctl, journal, paccache timer, power profile)
print_step "Configuring system performance and maintenance"
sudo bash "$SCRIPT_DIR/scripts/setup/configure-system-performance.sh" "$USER_NAME"

# Enable user maintenance timers (backup, cache cleanup)
print_step "Enabling user maintenance timers"
if [[ -d ~/.config/systemd/user ]]; then
    systemctl --user daemon-reload
    systemctl --user enable backup.timer cache-cleanup.timer 2>/dev/null || true
    echo -e "${GREEN}✓ Backup and cache-cleanup timers enabled${NC}"
    echo -e "${YELLOW}  Note: Start timers after reboot or run: systemctl --user start backup.timer cache-cleanup.timer${NC}"
fi

echo
echo -e "${GREEN}🎉 Installation completed successfully!${NC}"
echo
echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║${NC}                        ${CYAN}NEXT STEPS${NC}                           ${YELLOW}║${NC}"
echo -e "${YELLOW}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${YELLOW}║${NC} 1. ${GREEN}Reboot your system${NC}                                    ${YELLOW}║${NC}"
echo -e "${YELLOW}║${NC} 2. ${GREEN}Log in via regreet (greetd) to start Hyprland${NC}        ${YELLOW}║${NC}"
echo -e "${YELLOW}║${NC} 3. ${GREEN}Press Super+Return to open terminal${NC}                  ${YELLOW}║${NC}"
echo -e "${YELLOW}║${NC} 4. ${GREEN}Press Super+D to open application launcher${NC}           ${YELLOW}║${NC}"
echo -e "${YELLOW}║${NC} 5. ${GREEN}Check docs/keybindings.md for all shortcuts${NC}          ${YELLOW}║${NC}"
echo -e "${YELLOW}║${NC} 6. ${GREEN}Set up Tailscale: sudo bash scripts/setup/setup-tailscale.sh${NC} ${YELLOW}║${NC}"
echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${BLUE}📚 Documentation:${NC}"
echo -e "   • Keybindings: ${SCRIPT_DIR}/docs/keybindings.md"
echo -e "   • Troubleshooting: ${SCRIPT_DIR}/docs/troubleshooting.md"
echo
echo -e "${PURPLE}🎨 Theme switching:${NC}"
echo -e "   • Kitty themes: Ctrl+Alt+1-8"
echo -e "   • Wallpapers: Super+W, Super+Shift+W, Super+Ctrl+W"
echo
echo -e "${CYAN}Enjoy your neo-brutalist Hyprland setup! 🚀${NC}"
