#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════╗
# ║              NEXUS Hyprland Setup - Unified Installation Script             ║
# ║                     Complete Arch Linux Configuration                       ║
# ║                         ALL-IN-ONE INSTALLER v2.0                          ║
# ╚══════════════════════════════════════════════════════════════════════════╝

set -euo pipefail
IFS=$'\n\t'

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print colored output
print_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Helper functions (multilib + GPU/Steam stack)
enable_multilib() {
    if ! grep -q "^\s*\[multilib\]" /etc/pacman.conf; then
        print_info "Enabling multilib repository in /etc/pacman.conf"
        sudo sed -i -e '/^#\s*\[multilib\]/,/^#\s*Include/s/^#\s*//' /etc/pacman.conf || true
        sudo pacman -Syy
    else
        print_info "multilib repository already enabled"
    fi
}

detect_gpu_vendor() {
    if command -v nvidia-smi >/dev/null 2>&1; then
        echo nvidia
        return 0
    fi
    local line
    line=$(lspci -nnk | grep -E "VGA|3D|Display" | head -n1 || true)
    case "$line" in
        *NVIDIA*) echo nvidia;;
        *AMD*|*ATI*) echo amd;;
        *Intel*) echo intel;;
        *) echo unknown;;
    esac
}

install_vulkan_tools() {
    print_info "Installing Vulkan tools and loaders"
    if ! sudo pacman -S --needed --noconfirm vulkan-icd-loader lib32-vulkan-icd-loader vulkan-tools mesa-demos; then
        print_warning "Retrying Vulkan tools after refreshing package databases"
        sudo pacman -Syy
        sudo pacman -S --needed --noconfirm vulkan-icd-loader lib32-vulkan-icd-loader vulkan-tools mesa-demos || true
    fi
}

install_gpu_stack() {
    local vendor="$1"
    enable_multilib
    install_vulkan_tools
    case "$vendor" in
        nvidia)
            print_info "Installing NVIDIA driver + utils"
            sudo pacman -S --needed --noconfirm nvidia-dkms nvidia-utils lib32-nvidia-utils opencl-nvidia || true
            ;;
        amd)
            print_info "Installing AMD Mesa + Vulkan (RADV)"
            sudo pacman -S --needed --noconfirm llvm-libs lib32-llvm-libs || true
            sudo pacman -S --needed --noconfirm mesa lib32-mesa xf86-video-amdgpu \
                vulkan-radeon lib32-vulkan-radeon \
                vulkan-mesa-layers lib32-vulkan-mesa-layers || true
            ;;
        intel)
            print_info "Installing Intel Mesa + Vulkan"
            sudo pacman -S --needed --noconfirm llvm-libs lib32-llvm-libs || true
            sudo pacman -S --needed --noconfirm mesa lib32-mesa vulkan-intel lib32-vulkan-intel \
                intel-media-driver vulkan-mesa-layers lib32-vulkan-mesa-layers || true
            ;;
        *)
            print_warning "Unknown GPU vendor; installing generic Mesa + Vulkan"
            sudo pacman -S --needed --noconfirm mesa lib32-mesa || true
            ;;
    esac
}

install_steam_stack() {
    enable_multilib
    print_info "Installing Steam + Gamescope + Gamemode + MangoHud"
    sudo pacman -S --needed --noconfirm steam gamescope gamemode lib32-gamemode mangohud lib32-mangohud || print_warning "Some gaming packages may not be available"
    # Attempt to enable gamemoded for current user
    if systemctl --user --quiet is-enabled gamemoded 2>/dev/null; then
        print_info "gamemoded user service already enabled"
    else
        systemctl --user enable --now gamemoded 2>/dev/null || print_warning "Could not enable gamemoded (ensure a user systemd session is active)"
    fi
}

# ASCII Art Banner
cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║    ███╗   ██╗███████╗██╗  ██╗██╗   ██╗███████╗                        ║
║    ████╗  ██║██╔════╝╚██╗██╔╝██║   ██║██╔════╝                        ║
║    ██╔██╗ ██║█████╗   ╚███╔╝ ██║   ██║███████╗                        ║
║    ██║╚██╗██║██╔══╝   ██╔██╗ ██║   ██║╚════██║                        ║
║    ██║ ╚████║███████╗██╔╝ ██╗╚██████╔╝███████║                        ║
║    ╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝                        ║
║                                                                          ║
║              Futuristic Hyprland Environment Setup v2.0                 ║
║                         UNIFIED INSTALLER                               ║
╚══════════════════════════════════════════════════════════════════════════╝
EOF

sleep 2

# Check if running on Arch Linux
if [ ! -f /etc/arch-release ]; then
    print_error "This script is designed for Arch Linux only!"
    exit 1
fi

# Update system
print_info "Updating system packages..."
sudo pacman -Syu --noconfirm

# Ensure pacman multilib repository is enabled early
enable_multilib

# Install essential packages
print_info "Installing essential packages..."
sudo pacman -S --needed --noconfirm \
    base-devel \
    git \
    wget \
    curl \
    unzip \
    cmake \
    meson \
    ninja

# ━━━━━━━━━━━━━━━━━━━━━ SECTION 1: CORE HYPRLAND ━━━━━━━━━━━━━━━━━━━━━

print_info "Installing Hyprland and core Wayland components..."
sudo pacman -S --needed --noconfirm \
    hyprland \
    xdg-desktop-portal-hyprland \
    qt5-wayland \
    qt6-wayland \
    waybar \
    rofi-wayland \
    dunst \
    swaylock \
    swayidle \
    wl-clipboard \
    cliphist \
    grim \
    slurp \
    hyprpaper \
    polkit-kde-agent \
    xdg-utils

# Terminal and shell
print_info "Installing terminal emulators and shells..."
sudo pacman -S --needed --noconfirm \
    kitty \
    alacritty \
    zsh \
    fish \
    starship

# Fonts
print_info "Installing fonts..."
sudo pacman -S --needed --noconfirm \
    ttf-jetbrains-mono-nerd \
    ttf-font-awesome \
    ttf-firacode-nerd \
    ttf-nerd-fonts-symbols \
    noto-fonts \
    noto-fonts-emoji \
    noto-fonts-cjk

# File managers and utilities
print_info "Installing file managers and system utilities..."
sudo pacman -S --needed --noconfirm \
    dolphin \
    ranger \
    thunar \
    thunar-volman \
    gvfs \
    gvfs-mtp \
    tumbler \
    ffmpegthumbnailer \
    btop \
    htop \
    neofetch \
    fastfetch

# Network and bluetooth tools
print_info "Installing network and bluetooth management tools..."
sudo pacman -S --needed --noconfirm \
    networkmanager \
    network-manager-applet \
    bluez \
    bluez-utils \
    blueman \
    nm-connection-editor

# Enable services
print_info "Enabling essential services..."
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth

# ━━━━━━━━━━━━━━━━━━━━━ SECTION 2: AUDIO (WITH CONFLICT RESOLUTION) ━━━━━━━━━━━━━━━━━━━━━

print_info "Installing audio management tools..."

# Handle potential jack2 conflict
if pacman -Qi jack2 &> /dev/null; then
    print_warning "Removing jack2 to avoid conflicts with pipewire-jack..."
    sudo pacman -Rdd --noconfirm jack2 2>/dev/null || true
fi

sudo pacman -S --needed --noconfirm \
    pipewire \
    pipewire-alsa \
    pipewire-pulse \
    pipewire-jack \
    wireplumber \
    pavucontrol \
    playerctl \
    pamixer

# ━━━━━━━━━━━━━━━━━━━━━ SECTION 3: MODERN CLI TOOLS ━━━━━━━━━━━━━━━━━━━━━

print_info "Installing modern CLI replacements..."

# Core modern tools including GitHub CLI
sudo pacman -S --needed --noconfirm \
    bat \
    eza \
    fd \
    ripgrep \
    sd \
    dust \
    bottom \
    procs \
    hyperfine \
    tokei \
    git-delta \
    zoxide \
    fzf \
    jq \
    yq \
    httpie \
    curlie \
    dog \
    duf \
    ncdu \
    just \
    watchexec \
    tealdeer \
    github-cli \
    glow

# ━━━━━━━━━━━━━━━━━━━━━ SECTION 4: DATABASE TOOLS (INCLUDING DUCKDB) ━━━━━━━━━━━━━━━━━━━━━

print_info "Installing database tools..."
sudo pacman -S --needed --noconfirm \
    postgresql-libs \
    sqlite

# Install yay AUR helper if not present
if ! command -v yay &> /dev/null; then
    print_info "Installing yay AUR helper..."
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm
    cd -
    rm -rf /tmp/yay
fi

# Install DuckDB from AUR
print_info "Installing DuckDB..."
yay -S --needed --noconfirm duckdb-bin || yay -S --needed --noconfirm duckdb || {
    print_warning "DuckDB not found in AUR, installing via direct download..."
    wget -q https://github.com/duckdb/duckdb/releases/latest/download/duckdb_cli-linux-amd64.zip -O /tmp/duckdb.zip
    unzip -q /tmp/duckdb.zip -d /tmp/
    sudo mv /tmp/duckdb /usr/local/bin/
    sudo chmod +x /usr/local/bin/duckdb
}

# Install modern AUR tools
print_info "Installing AUR modern tools..."
yay -S --needed --noconfirm \
    mcfly \
    gitui \
    lazygit \
    lazydocker \
    ctop \
    broot \
    xh \
    choose \
    grex || print_warning "Some AUR tools may not be available"

# ━━━━━━━━━━━━━━━━━━━━━ SECTION 5: DEVELOPMENT TOOLS ━━━━━━━━━━━━━━━━━━━━━

print_info "Installing development tools..."
sudo pacman -S --needed --noconfirm \
    neovim \
    code \
    nodejs \
    npm \
    python \
    python-pip \
    python-pipx

# ━━━━━━━━━━━━━━━━━━━━━ SECTION 6: CONTAINER PLATFORMS ━━━━━━━━━━━━━━━━━━━━━

print_info "Installing container runtimes..."

# Docker
print_info "Installing Docker..."
sudo pacman -S --needed --noconfirm \
    docker \
    docker-compose \
    docker-buildx

sudo systemctl enable docker
sudo usermod -aG docker $USER

# Podman
print_info "Installing Podman..."
sudo pacman -S --needed --noconfirm \
    podman \
    podman-compose \
    buildah \
    skopeo

# Container management tools
sudo pacman -S --needed --noconfirm \
    dive \
    crane || true

# ━━━━━━━━━━━━━━━━━━━━━ SECTION 7: RICH TERMINAL TOOLS ━━━━━━━━━━━━━━━━━━━━━

print_info "Installing Python package management..."
pipx ensurepath

# Install Python TUI applications using pipx
print_info "Installing Python TUI applications..."
for app in rich-cli frogmouth textual browsr toolong posting dolphie elia pywhat litecli pgcli mycli iredis httpie; do
    pipx install $app 2>/dev/null || print_warning "$app already installed or not available"
done

# Install terminal enhancement tools from AUR
yay -S --needed --noconfirm \
    slides \
    vhs \
    charm-gum || print_warning "Some enhancement tools may not be available"

# ━━━━━━━━━━━━━━━━━━━━━ SECTION 8: VPN & NETWORKING ━━━━━━━━━━━━━━━━━━━━━

print_info "Installing Tailscale VPN..."
sudo pacman -S --needed --noconfirm tailscale
sudo systemctl enable --now tailscaled

# ━━━━━━━━━━━━━━━━━━━━━ SECTION 9: AI/LLM TOOLS ━━━━━━━━━━━━━━━━━━━━━

print_info "Setting up AI/LLM tools..."

# Ollama
print_info "Installing Ollama..."
curl -fsSL https://ollama.ai/install.sh | sh || print_warning "Ollama installation failed"

# Create AI directory
mkdir -p ~/AI

# ━━━━━━━━━━━━━━━━━━━━━ SECTION 10: MEDIA & PRODUCTIVITY ━━━━━━━━━━━━━━━━━━━━━

print_info "Installing media players and productivity tools..."
sudo pacman -S --needed --noconfirm \
    vlc \
    mpv \
    audacity \
    spotify-launcher

# Documents and images
print_info "Installing document and image viewers..."
sudo pacman -S --needed --noconfirm \
    zathura \
    zathura-pdf-mupdf \
    imv \
    feh \
    gwenview

# Gaming (drivers + Vulkan + Steam)
print_info "Setting up gaming stack (GPU drivers + Vulkan + Steam)"
GPU_VENDOR="$(detect_gpu_vendor)"
print_info "Detected GPU vendor: ${GPU_VENDOR}"
install_gpu_stack "$GPU_VENDOR"
install_steam_stack

# Brightness control
print_info "Installing brightness control..."
sudo pacman -S --needed --noconfirm brightnessctl

# GTK themes and icons
print_info "Installing themes and icons..."
sudo pacman -S --needed --noconfirm \
    papirus-icon-theme \
    breeze-gtk \
    lxappearance \
    qt5ct \
    kvantum

# ━━━━━━━━━━━━━━━━━━━━━ SECTION 11: LOGIN MANAGER (SDDM) ━━━━━━━━━━━━━━━━━━━━━

print_info "Installing SDDM display manager..."
sudo pacman -S --needed --noconfirm sddm qt5-graphicaleffects qt5-quickcontrols2 qt5-svg

# Install SDDM themes
print_info "Installing SDDM themes..."
yay -S --needed --noconfirm sddm-sugar-candy-git || true

# Configure SDDM with cyberpunk theme
print_info "Configuring SDDM theme..."
sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/theme.conf > /dev/null << 'EOL'
[Theme]
Current=sugar-candy
CursorTheme=Breeze_Snow
Font=JetBrainsMono Nerd Font

[General]
Numlock=on

[Users]
MaximumUid=60000
MinimumUid=1000
EOL

# Configure sugar-candy theme with cyberpunk colors if it exists
if [ -d /usr/share/sddm/themes/sugar-candy ]; then
    sudo tee /usr/share/sddm/themes/sugar-candy/theme.conf > /dev/null << 'EOL'
[General]
Background="Backgrounds/Mountain.jpg"
MainColor="#b967ff"
AccentColor="#01cdfe"
BackgroundColor="#0d0221"
PlaceholderColor="#a0a0c0"
IconColor="#05ffa1"
FontColor="#e0e0ff"
Font="JetBrainsMono Nerd Font"
HeaderText="NEXUS SYSTEM"
EOL
fi

# Enable SDDM
sudo systemctl enable sddm

# ━━━━━━━━━━━━━━━━━━━━━ SECTION 12: AUR PACKAGES ━━━━━━━━━━━━━━━━━━━━━

print_info "Installing additional AUR packages..."
yay -S --needed --noconfirm \
    hyprshot \
    wlogout \
    swww \
    grimblast-git || print_warning "Some AUR packages may not be available"

# Obsidian
print_info "Installing Obsidian..."
yay -S --needed --noconfirm obsidian

# Pixi package manager
print_info "Installing Pixi..."
curl -fsSL https://pixi.sh/install.sh | bash || print_warning "Pixi installation failed"

# ━━━━━━━━━━━━━━━━━━━━━ SECTION 13: CONFIGURATION FILES ━━━━━━━━━━━━━━━━━━━━━

print_info "Setting up configuration files..."
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Create necessary directories
mkdir -p ~/.config
mkdir -p ~/.local/share
mkdir -p ~/Pictures/Screenshots
mkdir -p ~/Pictures/Wallpapers

# Backup existing configs if they exist
for config in hypr waybar rofi dunst kitty; do
    if [ -d "$HOME/.config/$config" ]; then
        print_warning "Backing up existing $config config..."
        mv "$HOME/.config/$config" "$HOME/.config/${config}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
done

# Create symbolic links or copy configurations
if [ -d "$SCRIPT_DIR/config" ]; then
    ln -sf "$SCRIPT_DIR/config/hypr" "$HOME/.config/hypr"
    ln -sf "$SCRIPT_DIR/config/waybar" "$HOME/.config/waybar"
    ln -sf "$SCRIPT_DIR/config/rofi" "$HOME/.config/rofi"

    # Copy starship config
    if [ -f "$SCRIPT_DIR/config/starship.toml" ]; then
        cp "$SCRIPT_DIR/config/starship.toml" "$HOME/.config/starship.toml"
    fi
fi

# ━━━━━━━━━━━━━━━━━━━━━ SECTION 14: SHELL CONFIGURATION ━━━━━━━━━━━━━━━━━━━━━

print_info "Configuring shell aliases and environment..."

# Create modern aliases file
cat > ~/.config/modern-aliases.sh << 'EOF'
# Modern CLI Aliases
alias cat='bat --paging=never'
alias ls='eza --icons --group-directories-first'
alias ll='eza -l --icons --group-directories-first'
alias la='eza -la --icons --group-directories-first'
alias lt='eza --tree --icons'
alias find='fd'
alias grep='rg'
alias sed='sd'
alias du='dust'
alias df='duf'
alias top='btm'
alias ps='procs'
alias dig='dog'
alias cd='z'

# Git shortcuts
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias lg='lazygit'

# Docker shortcuts
alias d='docker'
alias dc='docker-compose'
alias lzd='lazydocker'

# Initialize tools
eval "$(zoxide init bash)"
eval "$(starship init bash)"
EOF

# Add to bashrc if not already there
if ! grep -q "modern-aliases.sh" ~/.bashrc; then
    cat >> ~/.bashrc << 'EOF'

# NEXUS Modern CLI Setup
if [ -f ~/.config/modern-aliases.sh ]; then
    source ~/.config/modern-aliases.sh
fi
EOF
fi

# ━━━━━━━━━━━━━━━━━━━━━ SECTION 15: WALLPAPERS & THEMES ━━━━━━━━━━━━━━━━━━━━━

print_info "Downloading sample wallpapers..."
WALLPAPERS=(
    "https://w.wallhaven.cc/full/gp/wallhaven-gpl3k3.png"
    "https://w.wallhaven.cc/full/4g/wallhaven-4gwp97.png"
    "https://w.wallhaven.cc/full/yx/wallhaven-yxmk6k.jpg"
)
NAMES=(
    "cyberpunk-city.jpg"
    "neon-abstract.jpg"
    "tech-grid.jpg"
)

for i in "${!WALLPAPERS[@]}"; do
    if wget -q --timeout=10 "${WALLPAPERS[$i]}" -O ~/Pictures/Wallpapers/"${NAMES[$i]}" 2>/dev/null; then
        print_success "Downloaded ${NAMES[$i]}"
        break
    fi
done

# Configure hyprpaper
cat > "$HOME/.config/hypr/hyprpaper.conf" << 'EOL'
preload = ~/Pictures/Wallpapers/cyberpunk-city.jpg
wallpaper = ,~/Pictures/Wallpapers/cyberpunk-city.jpg
ipc = off
EOL

# Set up GTK theme
print_info "Configuring GTK theme..."
mkdir -p "$HOME/.config/gtk-3.0"
mkdir -p "$HOME/.config/gtk-4.0"
cat > "$HOME/.config/gtk-3.0/settings.ini" << 'EOL'
[Settings]
gtk-theme-name=Breeze-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=JetBrains Mono 11
gtk-cursor-theme-name=Breeze_Snow
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_BOTH
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=1
gtk-menu-images=1
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=1
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintfull
gtk-xft-rgba=rgb
EOL

cp "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"

# ━━━━━━━━━━━━━━━━━━━━━ SECTION 16: FINAL SETUP ━━━━━━━━━━━━━━━━━━━━━

# Create Waybar scripts
print_info "Creating Waybar helper scripts..."
mkdir -p "$HOME/.config/waybar/scripts"

cat > "$HOME/.config/waybar/scripts/mediaplayer.py" << 'SCRIPT'
#!/usr/bin/env python3
import json
import subprocess
import sys

try:
    output = subprocess.check_output(['playerctl', 'metadata', '--format', '{"text": "{{artist}} - {{title}}", "tooltip": "{{playerName}} : {{artist}} - {{title}}", "alt": "{{status}}", "class": "{{status}}"}'], universal_newlines=True)
    json_output = json.loads(output)
    json_output['text'] = json_output['text'][:40] + '...' if len(json_output['text']) > 40 else json_output['text']
    print(json.dumps(json_output))
except:
    print('{"text": "", "tooltip": "No media playing"}')
    sys.exit(0)
SCRIPT
chmod +x "$HOME/.config/waybar/scripts/mediaplayer.py"

# Install Steam-in-Gamescope launcher script to user's bin
print_info "Installing Steam Gamescope launcher"
mkdir -p "$HOME/.local/bin"
if [ -f "$SCRIPT_DIR/scripts/steam-gamescope.sh" ]; then
    install -m 0755 "$SCRIPT_DIR/scripts/steam-gamescope.sh" "$HOME/.local/bin/steam-gamescope"
fi

# Install custom application desktop entries
print_info "Installing custom application launchers"
mkdir -p "$HOME/.local/share/applications"
if [ -f "$SCRIPT_DIR/config/applications/steam-gamescope.desktop" ]; then
    install -m 0644 "$SCRIPT_DIR/config/applications/steam-gamescope.desktop" "$HOME/.local/share/applications/steam-gamescope.desktop"
fi

# ━━━━━━━━━━━━━━━━━━━━━ INSTALLATION COMPLETE ━━━━━━━━━━━━━━━━━━━━━

print_success "NEXUS Installation Complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                    Installation Summary                    "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Hyprland and Wayland components"
echo "✅ Modern CLI tools with aliases"
echo "✅ DuckDB database engine"
echo "✅ SDDM login manager with cyberpunk theme"
echo "✅ Container platforms (Docker, Podman)"
echo "✅ Python TUI applications"
echo "✅ Tailscale VPN"
echo "✅ AI/LLM tools (Ollama)"
echo "✅ Media and productivity applications"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_info "Next steps:"
echo "  1. Log out and select Hyprland session from SDDM"
echo "  2. Press Super+Return to open terminal"
echo "  3. Press Super+Space to launch applications"
echo "  4. Run 'source ~/.bashrc' to load aliases now"
echo "  5. Authenticate Tailscale: sudo tailscale up"
echo "  6. Test DuckDB: duckdb"
echo ""
echo "Optional:"
echo "  • RGB Control: ./scripts/hardware-control.sh preset gaming"
echo "  • LLM Services: ./scripts/manage-llm.sh start"
echo ""
print_success "Welcome to NEXUS - Your Futuristic Desktop! 🚀"
