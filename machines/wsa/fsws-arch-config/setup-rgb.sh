#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# RGB Setup Script for Corsair devices on AMD system
echo "=== Setting up RGB Control for Corsair Devices ==="

# 1. Load i2c kernel modules
echo "Loading i2c kernel modules..."
sudo modprobe i2c-dev
sudo modprobe i2c-piix4

# 2. Add user to i2c group
echo "Adding user to i2c group..."
sudo usermod -a -G i2c "$USER"

# 3. Make modules load on boot
echo "Configuring modules to load on boot..."
echo "i2c-dev" | sudo tee /etc/modules-load.d/i2c-dev.conf
echo "i2c-piix4" | sudo tee /etc/modules-load.d/i2c-piix4.conf

# 4. Set up udev rules for USB access
echo "Setting up udev rules for Corsair devices..."
sudo tee /etc/udev/rules.d/60-openrgb.rules << 'EOF'
# Corsair devices
SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", MODE="0666", GROUP="users"

# Generic USB access for RGB devices
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0666", GROUP="users"

# I2C access
KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0666"
EOF

# 5. Reload udev rules
echo "Reloading udev rules..."
sudo udevadm control --reload-rules
sudo udevadm trigger

# 6. Check for Corsair devices
echo ""
echo "Checking for Corsair devices..."
lsusb | grep -i corsair || echo "No Corsair USB devices found via lsusb"

echo ""
echo "Checking liquidctl..."
sudo liquidctl list

echo ""
echo "=== Setup Complete ==="
echo "Please:"
echo "1. Log out and log back in (or reboot) for group changes to take effect"
echo "2. Then run: openrgb"
echo "3. If devices are still not detected, try running OpenRGB as root once: sudo openrgb"
echo ""
echo "For Corsair iCUE devices, you might also need to:"
echo "- Install ckb-next from AUR: yay -S ckb-next"
echo "- Or use OpenCorsairLink: yay -S opencorsairlink-git"
