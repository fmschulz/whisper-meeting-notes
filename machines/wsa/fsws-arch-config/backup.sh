#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════╗
# ║                        NEXUS Configuration Backup Script                    ║
# ╚══════════════════════════════════════════════════════════════════════════╝

set -euo pipefail
IFS=$'\n\t'

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)

print_info "Starting configuration backup..."

# Note: Avoid initializing a new git repo here to prevent conflicts

# Update configuration files from system
print_info "Syncing configuration files..."

# List of configs to backup
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
        print_info "Backing up $config..."
        # Remove existing backup
        rm -rf "$SCRIPT_DIR/config/$config"
        # Copy fresh config
        cp -r "$HOME/.config/$config" "$SCRIPT_DIR/config/"
    else
        print_warning "$config directory not found, skipping..."
    fi
done

# Backup package lists
print_info "Creating package lists..."
mkdir -p "$SCRIPT_DIR/packages"

# Official packages
pacman -Qqen > "$SCRIPT_DIR/packages/arch-packages.txt" 2>/dev/null || true

# AUR packages
pacman -Qqem > "$SCRIPT_DIR/packages/aur-packages.txt" 2>/dev/null || true

# Python packages (if pip is installed)
if command -v pip &> /dev/null; then
    pip freeze > "$SCRIPT_DIR/packages/pip-packages.txt" 2>/dev/null || true
fi

# NPM packages (if npm is installed)
if command -v npm &> /dev/null; then
    npm list -g --depth=0 > "$SCRIPT_DIR/packages/npm-packages.txt" 2>/dev/null || true
fi

# Backup user scripts
if [ -d "$HOME/.local/bin" ]; then
    print_info "Backing up user scripts..."
    mkdir -p "$SCRIPT_DIR/scripts/user"
    cp -r "$HOME/.local/bin/"* "$SCRIPT_DIR/scripts/user/" 2>/dev/null || true
fi

# Backup wallpapers
if [ -d "$HOME/Pictures/Wallpapers" ]; then
    print_info "Backing up wallpapers..."
    mkdir -p "$SCRIPT_DIR/wallpapers"
    cp "$HOME/Pictures/Wallpapers/"*.{jpg,jpeg,png,webp} "$SCRIPT_DIR/wallpapers/" 2>/dev/null || true
fi

# Create backup info file
cat > "$SCRIPT_DIR/backup-info.txt" << EOF
NEXUS Configuration Backup
Date: $(date)
Hostname: $(hostname)
User: $USER
Kernel: $(uname -r)
Hyprland Version: $(hyprctl version | head -n1 2>/dev/null || echo "Not installed")
EOF

# Git operations
cd "$SCRIPT_DIR"

print_info "Committing changes to git..."
git add .
git commit -m "Backup: $BACKUP_DATE - Configuration sync" || print_warning "No changes to commit"

# Check if remote is configured
if git remote | grep -q origin; then
    print_info "Remote repository detected. Pushing changes..."
    git push origin main || git push origin master || print_warning "Could not push to remote"
else
    print_warning "No remote repository configured."
    echo "To add a remote repository, run:"
    echo "  git remote add origin https://github.com/yourusername/fsws-arch-config.git"
    echo "  git branch -M main"
    echo "  git push -u origin main"
fi

print_success "Backup completed successfully!"
print_info "Backup information saved to backup-info.txt"

# Show summary
echo ""
echo "Backup Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
[ -f "$SCRIPT_DIR/packages/arch-packages.txt" ] && echo "✓ $(wc -l < "$SCRIPT_DIR/packages/arch-packages.txt") official packages"
[ -f "$SCRIPT_DIR/packages/aur-packages.txt" ] && echo "✓ $(wc -l < "$SCRIPT_DIR/packages/aur-packages.txt") AUR packages"
[ -d "$SCRIPT_DIR/config" ] && echo "✓ $(ls -1 "$SCRIPT_DIR/config" | wc -l) configurations backed up"
[ -d "$SCRIPT_DIR/wallpapers" ] && echo "✓ $(ls -1 "$SCRIPT_DIR/wallpapers" 2>/dev/null | wc -l) wallpapers"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
