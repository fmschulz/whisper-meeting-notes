#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════╗
# ║                       Hardware Control Script - RGB & Cooling               ║
# ╚══════════════════════════════════════════════════════════════════════════╝

set -euo pipefail
IFS=$'\n\t'

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_help() {
    cat << EOF
╔══════════════════════════════════════════════════════════════════════════╗
║                     NEXUS Hardware Control Manager                        ║
║                   Corsair 400D & Mjolnir Cooler Control                  ║
╚══════════════════════════════════════════════════════════════════════════╝

Usage: $(basename "$0") [COMMAND] [OPTIONS]

Commands:
  status           Show current hardware status
  rgb [mode]       Set RGB lighting mode
  fan [profile]    Set fan profile
  pump [speed]     Set pump speed (20-100%)
  temp             Show temperature sensors
  monitor          Real-time monitoring
  preset [name]    Apply preset configuration
  save [name]      Save current config as preset
  help            Show this help message

RGB Modes:
  nexus           Cyberpunk theme (purple/cyan pulse)
  rainbow         Rainbow wave effect
  breathing       Breathing effect
  static [color]  Static color
  off             Turn off RGB

Fan Profiles:
  silent          Quiet operation (30-60%)
  balanced        Balanced noise/cooling (35-75%)
  performance     Maximum cooling (40-100%)
  custom          Custom curve

Presets:
  gaming          High performance for gaming
  quiet           Silent operation
  work            Balanced for productivity
  showcase        Maximum RGB effects

Examples:
  $(basename "$0") status              # Show all hardware status
  $(basename "$0") rgb nexus           # Set cyberpunk RGB theme
  $(basename "$0") fan performance     # Set performance fan profile
  $(basename "$0") pump 75             # Set pump to 75%
  $(basename "$0") preset gaming       # Apply gaming preset

EOF
}

check_tools() {
    local missing_tools=()

    command -v liquidctl &> /dev/null || missing_tools+=("liquidctl")
    command -v openrgb &> /dev/null || missing_tools+=("openrgb")
    command -v sensors &> /dev/null || missing_tools+=("lm_sensors")

    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_info "Install on Arch: sudo pacman -S openrgb liquidctl lm_sensors"
        exit 1
    fi
}

show_status() {
    print_info "Hardware Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Liquid cooler status
    print_info "Liquid Cooler Status:"
    sudo liquidctl status 2>/dev/null || print_warning "No liquid cooler detected"

    echo ""

    # Temperature sensors
    print_info "Temperature Sensors:"
    sensors | grep -E "Core|temp" | grep -v "crit"

    echo ""

    # Fan speeds
    print_info "Fan Speeds:"
    sensors | grep -i "fan"

    echo ""

    # RGB status
    print_info "RGB Devices:"
    if pgrep openrgb > /dev/null; then
        echo "OpenRGB is running"
    else
        echo "OpenRGB is not running"
    fi
}

set_rgb_mode() {
    local mode="$1"

    print_info "Setting RGB mode: $mode"

    case "$mode" in
        nexus)
            # Cyberpunk theme - purple/cyan pulse
            cat > /tmp/nexus-rgb.orp << 'EOF'
{
    "ProfileName": "NEXUS Cyberpunk",
    "Controllers": {
        "Corsair": {
            "Mode": "Pulse",
            "Speed": 2,
            "Direction": "Forward",
            "Colors": ["#b967ff", "#01cdfe", "#05ffa1"]
        }
    }
}
EOF
            openrgb --profile /tmp/nexus-rgb.orp &
            sudo liquidctl --match mjolnir set led color pulse b967ff 01cdfe --speed slower
            ;;

        rainbow)
            openrgb --mode "Rainbow Wave" --speed 2 &
            sudo liquidctl --match mjolnir set led color rainbow --speed normal
            ;;

        breathing)
            openrgb --mode "Breathing" --color b967ff --speed 2 &
            sudo liquidctl --match mjolnir set led color breathing b967ff --speed slower
            ;;

        static)
            local color="${2:-b967ff}"
            openrgb --mode "Direct" --color "$color" &
            sudo liquidctl --match mjolnir set led color fixed "$color"
            ;;

        off)
            openrgb --mode "Direct" --color 000000 &
            sudo liquidctl --match mjolnir set led color off
            ;;

        *)
            print_error "Unknown RGB mode: $mode"
            exit 1
            ;;
    esac

    print_success "RGB mode set!"
}

set_fan_profile() {
    local profile="$1"

    print_info "Setting fan profile: $profile"

    case "$profile" in
        silent)
            # Silent operation
            sudo liquidctl --match mjolnir set fan speed 25 30 30 40 35 50 40 60 50 80
            ;;

        balanced)
            # Balanced noise/cooling
            sudo liquidctl --match mjolnir set fan speed 30 60 35 65 40 75 45 85 50 100
            ;;

        performance)
            # Maximum cooling
            sudo liquidctl --match mjolnir set fan speed 40 70 45 80 50 90 55 95 60 100
            ;;

        custom)
            print_info "Enter custom fan curve (temp:speed pairs)"
            echo "Example: 30:40 40:60 50:80 60:100"
            read -p "Fan curve: " curve
            sudo liquidctl --match mjolnir set fan speed $curve
            ;;

        *)
            print_error "Unknown fan profile: $profile"
            exit 1
            ;;
    esac

    print_success "Fan profile set!"
}

set_pump_speed() {
    local speed="$1"

    if [ -z "$speed" ]; then
        print_error "Please specify pump speed (20-100)"
        exit 1
    fi

    if [ "$speed" -lt 20 ] || [ "$speed" -gt 100 ]; then
        print_error "Pump speed must be between 20 and 100"
        exit 1
    fi

    print_info "Setting pump speed to ${speed}%"
    sudo liquidctl --match mjolnir set pump speed "$speed"
    print_success "Pump speed set!"
}

show_temps() {
    print_info "Temperature Monitoring"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # CPU temperatures
    echo "CPU Temperatures:"
    sensors | grep -E "Package|Core" | awk '{printf "  %-20s %s\n", $1, $2}'

    echo ""

    # GPU temperature (if available)
    if command -v nvidia-smi &> /dev/null; then
        echo "GPU Temperature:"
        nvidia-smi --query-gpu=name,temperature.gpu --format=csv,noheader | awk '{printf "  %-20s %s°C\n", $1, $2}'
    elif command -v rocm-smi &> /dev/null; then
        echo "GPU Temperature:"
        rocm-smi -t
    fi

    echo ""

    # Liquid temperature
    echo "Liquid Temperature:"
    sudo liquidctl status | grep -i "liquid" || echo "  Not available"
}

monitor_hardware() {
    print_info "Starting hardware monitoring (Ctrl+C to stop)..."

    while true; do
        clear
        cat << EOF
╔══════════════════════════════════════════════════════════════════════════╗
║                         NEXUS Hardware Monitor                            ║
╚══════════════════════════════════════════════════════════════════════════╝

$(date)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF

        # Temperatures
        echo "TEMPERATURES:"
        sensors | grep -E "Package|Core|fan" | sed 's/^/  /'

        echo ""

        # Liquid cooler
        echo "LIQUID COOLER:"
        sudo liquidctl status 2>/dev/null | sed 's/^/  /' || echo "  Not detected"

        echo ""

        # GPU
        if command -v nvidia-smi &> /dev/null; then
            echo "GPU STATUS:"
            nvidia-smi --query-gpu=name,temperature.gpu,fan.speed,power.draw --format=csv,noheader | sed 's/^/  /'
        fi

        sleep 2
    done
}

apply_preset() {
    local preset="$1"

    print_info "Applying preset: $preset"

    case "$preset" in
        gaming)
            set_rgb_mode "nexus"
            set_fan_profile "performance"
            set_pump_speed 80
            print_success "Gaming preset applied!"
            ;;

        quiet)
            set_rgb_mode "breathing"
            set_fan_profile "silent"
            set_pump_speed 40
            print_success "Quiet preset applied!"
            ;;

        work)
            set_rgb_mode "static" "01cdfe"
            set_fan_profile "balanced"
            set_pump_speed 60
            print_success "Work preset applied!"
            ;;

        showcase)
            set_rgb_mode "rainbow"
            set_fan_profile "balanced"
            set_pump_speed 70
            print_success "Showcase preset applied!"
            ;;

        *)
            print_error "Unknown preset: $preset"
            exit 1
            ;;
    esac
}

save_preset() {
    local name="$1"

    if [ -z "$name" ]; then
        print_error "Please specify a preset name"
        exit 1
    fi

    local preset_file="$HOME/.config/nexus-hardware-presets/${name}.conf"
    mkdir -p "$HOME/.config/nexus-hardware-presets"

    print_info "Saving current configuration as preset: $name"

    # Save current settings
    cat > "$preset_file" << EOF
# NEXUS Hardware Preset: $name
# Created: $(date)

# Get current status and save
$(sudo liquidctl status)
EOF

    print_success "Preset saved to: $preset_file"
}

# Initialize OpenRGB if not running
init_openrgb() {
    if ! pgrep openrgb > /dev/null; then
        print_info "Starting OpenRGB server..."
        openrgb --server &
        sleep 2
    fi
}

# Main command handler
check_tools

case "$1" in
    status)
        show_status
        ;;
    rgb)
        init_openrgb
        set_rgb_mode "$2" "$3"
        ;;
    fan)
        set_fan_profile "$2"
        ;;
    pump)
        set_pump_speed "$2"
        ;;
    temp)
        show_temps
        ;;
    monitor)
        monitor_hardware
        ;;
    preset)
        init_openrgb
        apply_preset "$2"
        ;;
    save)
        save_preset "$2"
        ;;
    help|--help|-h|"")
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
