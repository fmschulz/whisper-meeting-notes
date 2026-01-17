#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

echo "=== Resetting and Starting Thermalright Display ==="

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$SCRIPT_DIR"
LCD_DIR="$REPO_ROOT/thermalright-lcd-control"

# Kill any existing controller
echo "Stopping existing controller..."
pkill -f "service.py" 2>/dev/null
sleep 2

# Reset the USB device to force display to reinitialize
echo "Resetting USB display device..."
# Find the USB bus and device number for 87ad:70db
USB_INFO=$(lsusb | grep "87ad:70db" | sed -E 's/Bus ([0-9]+) Device ([0-9]+).*/\1 \2/')
if [ ! -z "$USB_INFO" ]; then
    BUS=$(echo $USB_INFO | cut -d' ' -f1)
    DEV=$(echo $USB_INFO | cut -d' ' -f2)
    echo "Found display on Bus $BUS Device $DEV"

    # Try to reset using usbreset if available
    if command -v usbreset &> /dev/null; then
        sudo usbreset /dev/bus/usb/$BUS/$DEV 2>/dev/null && echo "USB reset completed"
    else
        echo "Installing usbreset..."
        sudo pacman -S usbutils --noconfirm --needed
    fi

    # Alternative reset method using sysfs
    echo "Performing power cycle..."
    echo "0" | sudo tee /sys/bus/usb/devices/*/authorized 2>/dev/null | grep -q "87ad:70db" && sleep 2
    echo "1" | sudo tee /sys/bus/usb/devices/*/authorized 2>/dev/null | grep -q "87ad:70db"
fi

sleep 3

# Start the controller
cd "$LCD_DIR"

# Create a minimal working config
mkdir -p /tmp/thermalright-config
cat > /tmp/thermalright-config/config_320320.yaml << 'EOF'
# Minimal config for ChiZhu Tech display
display_resolution: "320x320"
display_orientation: 0
background_type: solid_color
background_color: "#000000"
theme_preset: 1

# Metrics to display
metrics:
  cpu_temp: true
  cpu_usage: true
  cpu_freq: true
  gpu_temp: true
  gpu_usage: true
  ram_usage: true

# Update settings
update_interval: 1
brightness: 100

# Font settings
global_font:
  family: "Arial"
  size: 24
  color: "#FFFFFF"
EOF

# Copy backgrounds to expected location
sudo mkdir -p /usr/share/thermalright-lcd-control/themes/backgrounds
sudo cp -r resources/themes/backgrounds/* /usr/share/thermalright-lcd-control/themes/backgrounds/ 2>/dev/null || true

echo "Starting display controller..."
python3 src/thermalright_lcd_control/service.py --config /tmp/thermalright-config &
PID=$!

sleep 3

if ps -p $PID > /dev/null; then
    echo ""
    echo "✓ Display controller started (PID: $PID)"
    echo ""
    echo "IMPORTANT: If display still shows logo only:"
    echo "1. Unplug the USB cable from the display"
    echo "2. Wait 5 seconds"
    echo "3. Plug it back in"
    echo "4. The display should now show system stats"
    echo ""
    echo "To stop: pkill -f 'service.py'"
else
    echo "ERROR: Controller failed to start"
fi
