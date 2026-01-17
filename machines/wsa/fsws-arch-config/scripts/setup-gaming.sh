#!/bin/bash
# GPU + Steam setup and validation for Arch Linux
# - Detects GPU vendor
# - Ensures multilib is enabled (for Steam/lib32)
# - Installs vendor drivers + Vulkan stacks
# - Installs Steam, Gamescope, Gamemode, MangoHud
# - Validates with vulkaninfo/vkcube and optional Steam launch

set -euo pipefail

LOG_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/gaming-setup-$(date +%Y%m%d_%H%M%S).log"

INFO() { echo -e "\e[36m[INFO]\e[0m $*" | tee -a "$LOG_FILE"; }
WARN() { echo -e "\e[33m[WARN]\e[0m $*" | tee -a "$LOG_FILE"; }
ERR()  { echo -e "\e[31m[ERROR]\e[0m $*" | tee -a "$LOG_FILE"; }

require_arch() {
    if [[ ! -f /etc/arch-release ]]; then
        ERR "This script targets Arch Linux. Aborting."
        exit 1
    fi
}

detect_gpu_vendor() {
    # Prefer fast heuristics; fall back to lspci
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

ensure_multilib_enabled() {
    if ! grep -q "^\s*\[multilib\]" /etc/pacman.conf; then
        # Try to uncomment a standard multilib block
        INFO "Enabling multilib in /etc/pacman.conf"
        sudo sed -i \
            -e '/^#\s*\[multilib\]/,/^#\s*Include/s/^#\s*//' \
            /etc/pacman.conf
        sudo pacman -Sy
    else
        INFO "multilib repo is already enabled"
    fi
}

install_common_tools() {
    INFO "Installing Vulkan tools (vulkaninfo/vkcube) and demos"
    if ! sudo pacman -S --needed --noconfirm vulkan-tools mesa-demos vulkan-icd-loader lib32-vulkan-icd-loader; then
        WARN "Package download failed; refreshing pacman DB and retrying"
        sudo pacman -Syy
        if ! sudo pacman -S --needed --noconfirm vulkan-tools mesa-demos vulkan-icd-loader lib32-vulkan-icd-loader; then
            WARN "Retry failed; continuing without optional vulkan-tools/mesa-demos"
        fi
    fi
}

install_gpu_stack() {
    local vendor="$1"
    ensure_multilib_enabled
    install_common_tools
    case "$vendor" in
        nvidia)
            INFO "Installing NVIDIA proprietary driver + Vulkan"
            # dkms variant works across kernels; fallback to non-dkms if desired
            sudo pacman -S --needed --noconfirm nvidia-dkms nvidia-utils lib32-nvidia-utils opencl-nvidia || true
            ;;
        amd)
            INFO "Installing AMD Mesa stack + Vulkan"
            # Ensure LLVM runtime present (required by RADV)
            sudo pacman -S --needed --noconfirm llvm-libs lib32-llvm-libs || true
            sudo pacman -S --needed --noconfirm mesa lib32-mesa xf86-video-amdgpu \
                vulkan-radeon lib32-vulkan-radeon \
                vulkan-mesa-layers lib32-vulkan-mesa-layers || true
            ;;
        intel)
            INFO "Installing Intel Mesa stack + Vulkan"
            sudo pacman -S --needed --noconfirm llvm-libs lib32-llvm-libs || true
            sudo pacman -S --needed --noconfirm mesa lib32-mesa vulkan-intel lib32-vulkan-intel \
                intel-media-driver vulkan-mesa-layers lib32-vulkan-mesa-layers || true
            ;;
        *)
            WARN "Unknown GPU vendor; installing generic Mesa + Vulkan"
            sudo pacman -S --needed --noconfirm mesa lib32-mesa vulkan-icd-loader lib32-vulkan-icd-loader || true
            ;;
    esac
}

install_steam_stack() {
    ensure_multilib_enabled
    INFO "Installing Steam + Gamescope + Gamemode + MangoHud"
    sudo pacman -S --needed --noconfirm steam gamescope gamemode lib32-gamemode mangohud lib32-mangohud || true
    # Enable user gamemoded for automatic optimizations
    if systemctl --user --quiet is-enabled gamemoded 2>/dev/null; then
        INFO "gamemoded user service already enabled"
    else
        systemctl --user enable --now gamemoded || {
            WARN "Could not enable gamemoded (likely running with sudo)"
            echo "Run as your desktop user: systemctl --user enable --now gamemoded" | tee -a "$LOG_FILE"
        }
    fi
}

test_vulkan() {
    INFO "Collecting Vulkan driver info"
    if command -v vulkaninfo >/dev/null 2>&1; then
        vulkaninfo --summary | tee -a "$LOG_FILE" || true
    else
        WARN "vulkaninfo not found"
    fi
    INFO "Attempting to run vkcube (press Ctrl+C to exit)"
    if command -v vkcube >/dev/null 2>&1; then
        INFO "Launching vkcube in a Gamescope session for isolation"
        if command -v gamescope >/dev/null 2>&1; then
            gamescope -w 800 -h 600 -- vkcube || WARN "vkcube (gamescope) exited with non-zero status"
        else
            vkcube || WARN "vkcube exited with non-zero status"
        fi
    else
        WARN "vkcube not found (vulkan-tools)"
    fi
}

test_steam() {
    if ! command -v steam >/dev/null 2>&1; then
        ERR "Steam not installed"
        return 1
    fi
    INFO "Launching Steam silently; log in if prompted"
    INFO "Close Steam after it finishes first-time setup."
    STEAM_FORCE_DESKTOPUI_SCALING=1 steam -silent || WARN "Steam exited with non-zero status"
}

usage() {
    cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  detect           Print detected GPU vendor
  install-drivers  Enable multilib and install GPU + Vulkan stack
  install-steam    Install Steam, Gamescope, Gamemode, MangoHud
  test-vulkan      Run vulkaninfo summary and vkcube
  test-steam       Launch Steam for a smoke test
  all              Full flow: drivers -> steam -> test-vulkan

Notes:
  - Requires sudo for package installation.
  - Logs are written to: $LOG_FILE
  - For NVIDIA, this installs proprietary driver (nvidia-dkms + utils).
EOF
}

main() {
    require_arch
    local cmd="${1:-}"
    case "$cmd" in
        detect)
            local v; v=$(detect_gpu_vendor)
            INFO "Detected GPU vendor: $v"
            ;;
        install-drivers)
            local v; v=$(detect_gpu_vendor)
            INFO "Detected GPU vendor: $v"
            install_gpu_stack "$v"
            ;;
        install-steam)
            install_steam_stack
            ;;
        test-vulkan)
            test_vulkan
            ;;
        test-steam)
            test_steam
            ;;
        all)
            local v; v=$(detect_gpu_vendor)
            INFO "Detected GPU vendor: $v"
            install_gpu_stack "$v"
            install_steam_stack
            test_vulkan
            ;;
        -h|--help|help|*)
            usage
            ;;
    esac
}

main "$@"
