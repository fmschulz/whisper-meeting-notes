#!/bin/bash
# Betterfox installation script
firefox_profile=$(find ~/.mozilla/firefox -maxdepth 1 -type d -name "*.default-release" | head -n 1)
if [ -n "$firefox_profile" ]; then
    echo "Installing Betterfox to profile: $firefox_profile"
    curl -s https://raw.githubusercontent.com/yokoffing/Betterfox/main/user.js > "$firefox_profile/user.js"
    echo "Betterfox installed successfully!"
else
    echo "Firefox profile not found. Please run Firefox once and try again."
fi
