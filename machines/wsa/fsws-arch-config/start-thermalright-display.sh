#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

echo "=== Starting Thermalright Display Controller ==="
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$SCRIPT_DIR"
LCD_DIR="$REPO_ROOT/thermalright-lcd-control"
cd "$LCD_DIR"

# Kill any existing instances
pkill -f "service.py" 2>/dev/null

# Create proper config directory structure
mkdir -p /tmp/thermalright-config
cp resources/config/config_320320.yaml /tmp/thermalright-config/

# Copy backgrounds to avoid missing file errors
sudo mkdir -p /usr/share/thermalright-lcd-control/themes/backgrounds
sudo cp -r resources/themes/backgrounds/* /usr/share/thermalright-lcd-control/themes/backgrounds/ 2>/dev/null || true

# Start the service with the config DIRECTORY
echo "Starting display service..."
python3 src/thermalright_lcd_control/service.py --config /tmp/thermalright-config &

sleep 2

# Check if running
if pgrep -f "service.py" > /dev/null; then
    echo ""
    echo "✓ Display controller is running!"
    echo "Your display should now show CPU temp, usage, and system stats."
    echo ""
    echo "To stop: pkill -f 'service.py'"
else
    echo "Failed to start. Trying with resources/config directory..."
    python3 src/thermalright_lcd_control/service.py --config resources/config &
    sleep 2
    if pgrep -f "service.py" > /dev/null; then
        echo "✓ Running with default config!"
    else
        echo "ERROR: Could not start the display controller"
        echo "Check error messages above"
    fi
fi
