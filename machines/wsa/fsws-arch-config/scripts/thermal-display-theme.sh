#!/bin/bash
set -euo pipefail

# Theme helper for the Thermalright LCD controller config used by start-thermalright-display.sh
# Lets you set a single color (e.g. orange) for all text/metrics and restart the service.
#
# Usage:
#   scripts/thermal-display-theme.sh set-color ff8800   # set orange and restart
#   scripts/thermal-display-theme.sh restart            # just restart controller
#   scripts/thermal-display-theme.sh stop|start|status

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LCD_DIR="$REPO_ROOT/thermalright-lcd-control"
CFG_DIR="/tmp/thermalright-config"
CFG_FILE="$CFG_DIR/config_320320.yaml"

ensure_cfg() {
    mkdir -p "$CFG_DIR"
    if [[ ! -f "$CFG_FILE" ]]; then
        if [[ -f "$LCD_DIR/resources/config/config_320320.yaml" ]]; then
            cp "$LCD_DIR/resources/config/config_320320.yaml" "$CFG_FILE"
        else
            cat > "$CFG_FILE" <<'EOF'
display_resolution: "320x320"
display_orientation: 0
background_type: solid_color
background_color: "#000000"
theme_preset: 1
metrics:
  cpu_temp: true
  cpu_usage: true
  gpu_temp: true
  gpu_usage: true
  ram_usage: true
update_interval: 2
text:
  enabled: true
  position: [10, 10]
  font_size: 18
  color: '#FFFFFFFF'
EOF
        fi
    fi
}

set_color() {
    local hex="$1"
    # Normalize: add leading # and alpha FF
    local up="${hex#\#}"
    if [[ ${#up} -eq 6 ]]; then
        up="${up}FF"
    fi
    ensure_cfg
    # Replace all color: lines with the new value
    sed -i -E "s/color:\s*'#?[0-9A-Fa-f]{6,8}'/color: '#${up^^}'/g" "$CFG_FILE"
}

start_ctrl() {
    pkill -f "src/thermalright_lcd_control/service.py" 2>/dev/null || true
    cd "$LCD_DIR"
    python3 src/thermalright_lcd_control/service.py --config "$CFG_DIR" &
    sleep 2
}

case "${1:-}" in
    set-color)
        [[ -n "${2:-}" ]] || { echo "Usage: $0 set-color <hex>"; exit 1; }
        set_color "$2"
        start_ctrl
        echo "Applied color #${2} and restarted LCD controller"
        ;;
    start)
        ensure_cfg
        start_ctrl
        echo "LCD controller started"
        ;;
    stop)
        pkill -f "src/thermalright_lcd_control/service.py" 2>/dev/null || true
        echo "LCD controller stopped"
        ;;
    restart)
        ensure_cfg
        start_ctrl
        echo "LCD controller restarted"
        ;;
    status)
        if pgrep -f "src/thermalright_lcd_control/service.py" >/dev/null; then
            echo "LCD controller running"
        else
            echo "LCD controller not running"
        fi
        ;;
    *)
        echo "Usage: $0 {set-color <hex>|start|stop|restart|status}"
        exit 1
        ;;
esac

