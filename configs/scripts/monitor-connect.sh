#!/bin/bash
# Monitor connection script for Hyprland

# Get available monitors
monitors=$(hyprctl monitors | grep "Monitor" | awk '{print $2}')

echo "Available monitors:"
echo "$monitors"

# Auto-configure monitors
hyprctl reload

# Restart waybar to fix duplication issues
pkill -x waybar || true
waybar &

# Set wallpaper on all monitors
if command -v swww >/dev/null 2>&1; then
	swww img ~/Pictures/wallpapers/wp0.png
fi

echo "Monitor configuration updated!"
