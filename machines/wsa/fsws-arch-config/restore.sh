#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════╗
# ║                        NEXUS Configuration Restore Script                   ║
# ╚══════════════════════════════════════════════════════════════════════════╝

set -euo pipefail
IFS=$'\n\t'

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
RESTORE_DATE=$(date +%Y%m%d_%H%M%S)

cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════╗
║                        NEXUS Configuration Restore                        ║
║                      Restore Your Hyprland Environment                    ║
╚══════════════════════════════════════════════════════════════════════════╝
EOF

print_warning "This will restore your NEXUS configuration from this repository."
print_warning "Your current configurations will be backed up before restore."
echo ""
read -p "Do you want to continue? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Restore cancelled."
    exit 0
fi

if ! command -v pacman >/dev/null 2>&1; then
    print_error "pacman not found. This restore script is intended for Arch systems."
    exit 1
fi

# Create backup of current configs
print_info "Creating backup of current configurations..."
BACKUP_DIR="$HOME/.config-backup-$RESTORE_DATE"
mkdir -p "$BACKUP_DIR"

configs=(
    "hypr"
    "waybar"
    "rofi"
    "kitty"
    "alacritty"
    "dunst"
    "gtk-3.0"
    "gtk-4.0"
)

for config in "${configs[@]}"; do
    if [ -d "$HOME/.config/$config" ]; then
        print_info "Backing up existing $config..."
        cp -r "$HOME/.config/$config" "$BACKUP_DIR/"
    fi
done

print_success "Current configs backed up to: $BACKUP_DIR"

# Restore package installations
if [ -f "$SCRIPT_DIR/packages/arch-packages.txt" ]; then
    mapfile -t _arch_pkgs < "$SCRIPT_DIR/packages/arch-packages.txt"
    if [ "${#_arch_pkgs[@]}" -gt 0 ]; then
        print_info "Installing official packages..."
        sudo pacman -S --needed --noconfirm "${_arch_pkgs[@]}" || print_warning "Some packages failed to install"
    fi
fi

if [ -f "$SCRIPT_DIR/packages/aur-packages.txt" ] && command -v yay &> /dev/null; then
    mapfile -t _aur_pkgs < "$SCRIPT_DIR/packages/aur-packages.txt"
    if [ "${#_aur_pkgs[@]}" -gt 0 ]; then
        print_info "Installing AUR packages..."
        yay -S --needed --noconfirm "${_aur_pkgs[@]}" || print_warning "Some AUR packages failed to install"
    fi
elif [ -f "$SCRIPT_DIR/packages/aur-packages.txt" ]; then
    print_warning "AUR package list present but no yay found; skipping AUR install."
fi

# Restore configurations
print_info "Restoring configuration files..."

for config in "${configs[@]}"; do
    if [ -d "$SCRIPT_DIR/config/$config" ]; then
        print_info "Restoring $config..."
        rm -rf "$HOME/.config/$config"
        cp -r "$SCRIPT_DIR/config/$config" "$HOME/.config/"
    fi
done

# Restore wallpapers
if [ -d "$SCRIPT_DIR/wallpapers" ] && [ "$(ls -A $SCRIPT_DIR/wallpapers 2>/dev/null)" ]; then
    print_info "Restoring wallpapers..."
    mkdir -p "$HOME/Pictures/Wallpapers"
    cp "$SCRIPT_DIR/wallpapers/"* "$HOME/Pictures/Wallpapers/" 2>/dev/null || true
fi

# Restore user scripts (compat: legacy user scripts directory)
if [ -d "$SCRIPT_DIR/scripts/user" ] && [ "$(ls -A $SCRIPT_DIR/scripts/user 2>/dev/null)" ]; then
    print_info "Restoring user scripts (legacy)..."
    mkdir -p "$HOME/.local/bin"
    cp "$SCRIPT_DIR/scripts/user/"* "$HOME/.local/bin/" 2>/dev/null || true
    chmod +x "$HOME/.local/bin/"* 2>/dev/null || true
fi

# Install update-notifier as user command
if [ -f "$SCRIPT_DIR/scripts/update-notifier.sh" ]; then
    print_info "Installing update-notifier (user)"
    mkdir -p "$HOME/.local/bin"
    install -m 0755 "$SCRIPT_DIR/scripts/update-notifier.sh" "$HOME/.local/bin/update-notifier.sh"
fi

# Install wallpaper-sync helper
if [ -f "$SCRIPT_DIR/scripts/wallpaper-sync.sh" ]; then
    print_info "Installing wallpaper-sync (user)"
    mkdir -p "$HOME/.local/bin"
    install -m 0755 "$SCRIPT_DIR/scripts/wallpaper-sync.sh" "$HOME/.local/bin/wallpaper-sync.sh"
fi

# Restore GTK settings
if [ -f "$SCRIPT_DIR/config/gtk-3.0/settings.ini" ]; then
    print_info "Restoring GTK settings..."
    mkdir -p "$HOME/.config/gtk-3.0"
    cp "$SCRIPT_DIR/config/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/"
fi

# Set up Waybar scripts
print_info "Setting up Waybar scripts..."
mkdir -p "$HOME/.config/waybar/scripts"

# Copy waybar scripts if they exist
if [ -d "$SCRIPT_DIR/config/waybar/scripts" ]; then
    cp "$SCRIPT_DIR/config/waybar/scripts/"* "$HOME/.config/waybar/scripts/" 2>/dev/null || true
    chmod +x "$HOME/.config/waybar/scripts/"* 2>/dev/null || true
fi

# Enable services
print_info "Enabling system services..."
sudo systemctl enable --now NetworkManager 2>/dev/null || true
sudo systemctl enable --now bluetooth 2>/dev/null || true

# Create necessary directories
print_info "Creating necessary directories..."
mkdir -p "$HOME/Pictures/Screenshots"
mkdir -p "$HOME/Documents"
mkdir -p "$HOME/Downloads"
mkdir -p "$HOME/Videos"
mkdir -p "$HOME/Music"

# Install fonts if not present
if ! fc-list | grep -q "JetBrains"; then
    print_info "Installing missing fonts..."
    sudo pacman -S --needed --noconfirm ttf-jetbrains-mono-nerd ttf-font-awesome 2>/dev/null || true
fi

# Reload font cache
print_info "Updating font cache..."
fc-cache -fv &>/dev/null

# Set executable permissions on scripts
chmod +x "$SCRIPT_DIR/"*.sh 2>/dev/null || true
chmod +x "$SCRIPT_DIR/scripts/"*.sh 2>/dev/null || true

print_success "Configuration restore completed!"

# Show summary
echo ""
echo "Restore Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ Configurations restored to ~/.config/"
echo "✓ Previous configs backed up to: $BACKUP_DIR"
[ -d "$HOME/Pictures/Wallpapers" ] && echo "✓ Wallpapers restored"
[ -d "$HOME/.local/bin" ] && echo "✓ User scripts restored"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

print_info "Post-restore steps:"
echo "1. Log out and log back in with Hyprland session"
echo "2. Run 'waybar' if it doesn't start automatically"
echo "3. Configure your personal wallpaper if needed"
echo "4. Set up Firefox with Betterfox: ./scripts/setup-betterfox.sh"
echo ""
print_info "Your NEXUS environment has been restored!"
