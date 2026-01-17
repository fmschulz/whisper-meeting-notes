#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$SCRIPT_DIR"
LCD_DIR="$REPO_ROOT/thermalright-lcd-control"

case "${1:-}" in
    start)
        echo "Starting Thermalright Display Controller..."
        cd "$LCD_DIR"

        # Check if already running
        if pgrep -f "service.py" > /dev/null; then
            echo "Controller already running"
            exit 0
        fi

        # Ensure config exists
        mkdir -p /tmp/thermalright-config
        cp resources/config/config_320320.yaml /tmp/thermalright-config/ 2>/dev/null || \
        cat > /tmp/thermalright-config/config_320320.yaml << 'EOF'
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
EOF

        # Start controller
        python3 src/thermalright_lcd_control/service.py --config /tmp/thermalright-config &
        PID=$!

        sleep 2
        if ps -p $PID > /dev/null; then
            echo "✓ Display controller started (PID: $PID)"
        else
            echo "Failed to start controller"
            exit 1
        fi
        ;;

    stop)
        echo "Stopping display controller..."
        pkill -f "service.py" || true
        echo "Controller stopped"
        ;;

    restart)
        $0 stop
        sleep 2
        $0 start
        ;;

    status)
        if pgrep -f "service.py" > /dev/null; then
            PID=$(pgrep -f "service.py")
            echo "Display controller is running (PID: $PID)"
            ps aux | grep "[s]ervice.py"
        else
            echo "Display controller is not running"
        fi
        ;;

    reset-usb)
        echo "Resetting USB display..."
        USB_INFO=$(lsusb | grep "87ad:70db" || true)
        if [ -z "$USB_INFO" ]; then
            echo "Display not found!"
            exit 1
        fi
        echo "Found: $USB_INFO"
        echo "Please unplug and replug the USB cable manually"
        echo "Then run: $0 restart"
        ;;

    *)
        echo "Usage: $0 {start|stop|restart|status|reset-usb}"
        exit 1
        ;;
esac
