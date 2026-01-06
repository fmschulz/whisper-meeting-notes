#!/bin/bash
ws() {
	echo "Testing command -v hyprctl..."
	if ! command -v hyprctl >/dev/null 2>&1; then
		echo "ws: hyprctl not found (using command -v)"
	else
		echo "ws: hyprctl found (using command -v)"
	fi

	echo "Testing type hyprctl..."
	if ! type hyprctl >/dev/null 2>&1; then
		echo "ws: hyprctl not found (using type)"
	else
		echo "ws: hyprctl found (using type)"
	fi
}
ws
