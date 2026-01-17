# Simple helpers for linting/formatting shell scripts

SHELL := bash

# Track only repo files and exclude vendored subtree
SH_FILES := $(shell git ls-files '*.sh' | grep -v '^thermalright-lcd-control/' || true)

.PHONY: help lint fmt fmt-check tools check-waybar check-json user-notifier user-orange-rgb rgb-udev tt-probe clean-user-dir

help:
	@echo "Targets:"
	@echo "  lint       - Run shellcheck on shell scripts"
	@echo "  fmt        - Format scripts in-place with shfmt"
	@echo "  fmt-check  - Show diffs if formatting changes are needed"
	@echo "  tools      - Install shellcheck and shfmt (Arch)"
	@echo "  check-waybar - Validate Waybar JSON config with jq"
	@echo "  check-json - Validate all repo JSON files with jq"
	@echo "  user-notifier - Install user update-notifier + enable timer (no sudo)"
	@echo "  user-orange-rgb - Install orange RGB script + enable user service"
	@echo "  rgb-udev   - Install permissive udev rules for Thermaltake/Corsair + hidraw"
	@echo "  tt-probe    - Run Thermaltake LCD probe and collect logs"
	@echo "  clean-user-dir - Remove empty scripts/user directory if present"
	@echo ""
	@echo "Files matched:"; echo "$(SH_FILES)" | tr ' ' '\n' | sed '/^$$/d' | sed 's/^/  - /'

lint:
	@if ! command -v shellcheck >/dev/null 2>&1; then \
		echo "shellcheck not found. Install: sudo pacman -S shellcheck"; \
		exit 0; \
	fi
	@[ -n "$(SH_FILES)" ] && shellcheck -x $(SH_FILES) || echo "No .sh files to lint."

fmt:
	@if ! command -v shfmt >/dev/null 2>&1; then \
		echo "shfmt not found. Install: sudo pacman -S shfmt"; \
		exit 0; \
	fi
	@[ -n "$(SH_FILES)" ] && shfmt -w -i 4 -ci -sr $(SH_FILES) || echo "No .sh files to format."

fmt-check:
	@if ! command -v shfmt >/dev/null 2>&1; then \
		echo "shfmt not found. Install: sudo pacman -S shfmt"; \
		exit 0; \
	fi
	@[ -n "$(SH_FILES)" ] && shfmt -d -i 4 -ci -sr $(SH_FILES) || echo "No .sh files to check."

tools:
	@echo "Installing shellcheck and shfmt (Arch Linux)..."
	@if command -v pacman >/dev/null 2>&1; then \
		sudo pacman -S --needed --noconfirm shellcheck shfmt jq; \
	else \
		echo "pacman not found; install shellcheck/shfmt manually for your distro."; \
	fi

check-waybar:
	@if ! command -v jq >/dev/null 2>&1; then \
		echo "jq not found. Install: sudo pacman -S jq"; \
		exit 1; \
	fi
	@if [ -f config/waybar/config ]; then \
		jq . config/waybar/config >/dev/null && echo "Waybar config OK (config)"; \
	elif [ -f config/waybar/config.json ]; then \
		jq . config/waybar/config.json >/dev/null && echo "Waybar config OK (config.json)"; \
	else \
		echo "No Waybar config found"; \
		exit 1; \
	fi

check-json:
	@if ! command -v jq >/dev/null 2>&1; then \
		echo "jq not found. Install: sudo pacman -S jq"; \
		exit 1; \
	fi
	@find . -type f -name '*.json' -print -exec sh -c 'jq . "$1" >/dev/null && echo OK: "$1" || echo FAIL: "$1"' _ {} \;

user-notifier:
	@mkdir -p $$HOME/.config/systemd/user
	@cp systemd/user/update-notifier.{service,timer} $$HOME/.config/systemd/user/
	@install -m 0755 scripts/update-notifier.sh $$HOME/.local/bin/update-notifier.sh
	@systemctl --user daemon-reload
	@systemctl --user enable --now update-notifier.timer
	@echo "User notifier installed and timer enabled. Logs: journalctl --user -u update-notifier.service"

user-orange-rgb:
	@mkdir -p $$HOME/.config/systemd/user $$HOME/.local/bin
	@install -m 0755 scripts/set-orange-rgb.sh $$HOME/.local/bin/set-orange-rgb.sh
	@cp systemd/user/nexus-orange-rgb.service $$HOME/.config/systemd/user/
	@systemctl --user daemon-reload
	@systemctl --user enable --now nexus-orange-rgb.service
	@echo "Orange RGB service enabled. Adjust color: $$HOME/.local/bin/set-orange-rgb.sh <hex>"

rgb-udev:
	@echo "Installing extra udev rules (requires sudo)..."
	@sudo bash -c 'cat > /etc/udev/rules.d/61-rgb-extra.rules <<\'EOF\''
	@echo '# Extra rules for RGB device access (Thermaltake, Corsair)'
	@echo 'SUBSYSTEMS=="usb", ATTRS{idVendor}=="264a", MODE="0666", GROUP="users"'
	@echo 'SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", MODE="0666", GROUP="users"'
	@echo 'KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0666", GROUP="users"'
	@sudo bash -c 'echo EOF >> /etc/udev/rules.d/61-rgb-extra.rules'
	@sudo udevadm control --reload-rules
	@sudo udevadm trigger
	@echo "Installed /etc/udev/rules.d/61-rgb-extra.rules"
	@echo "Note: If OpenRGB warns about duplicate 60-openrgb.rules, consider removing your local /etc/udev/rules.d/60-openrgb.rules"
	@echo "Unplug/replug USB devices and rerun: ~/.local/bin/set-orange-rgb.sh ffa500"

tt-probe:
	@bash scripts/tt-lcd-probe.sh

clean-user-dir:
	@rmdir scripts/user 2>/dev/null || true
