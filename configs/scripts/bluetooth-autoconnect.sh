#!/bin/bash
# Auto-connect trusted bluetooth audio devices on login
# Add device MAC addresses to DEVICES array

DEVICES=(
    "7C:96:D2:89:1C:B4"  # Klipsch One II
)

# Wait for bluetooth to be ready
sleep 3

for device in "${DEVICES[@]}"; do
    # Check if device is trusted and try to connect
    if bluetoothctl info "$device" 2>/dev/null | grep -q "Trusted: yes"; then
        echo "Attempting to connect to $device..."
        bluetoothctl connect "$device" 2>/dev/null
    fi
done
