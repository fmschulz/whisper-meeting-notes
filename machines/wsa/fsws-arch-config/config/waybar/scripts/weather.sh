#!/bin/bash

# Weather script for Waybar - Berkeley, CA
# Uses wttr.in API for weather data

# Berkeley, California coordinates
LOCATION="Berkeley"

# Get weather data
weather_data=$(curl -s "wttr.in/$LOCATION?format=%c%t")

if [ -z "$weather_data" ]; then
    echo "☁️ N/A"
else
    # Get detailed weather for tooltip
    tooltip=$(curl -s "wttr.in/$LOCATION?format=%l:+%c+%t+%h+%w")

    # Output JSON format for Waybar
    echo "{\"text\":\"$weather_data\", \"tooltip\":\"$tooltip\", \"class\":\"weather\"}"
fi
