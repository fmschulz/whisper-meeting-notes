#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="$SCRIPT_DIR/../packages"

echo "=== Package Snapshot ==="

# Generate current state
pacman -Qeqn | sort > "$PACKAGES_DIR/pacman-packages.txt.new"
pacman -Qeqm | sort > "$PACKAGES_DIR/aur-packages.txt.new"

# Show changes
echo "Official package changes:"
diff "$PACKAGES_DIR/pacman-packages.txt" "$PACKAGES_DIR/pacman-packages.txt.new" || true

echo -e "\nAUR package changes:"
diff "$PACKAGES_DIR/aur-packages.txt" "$PACKAGES_DIR/aur-packages.txt.new" || true

read -p "Update package lists? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    mv "$PACKAGES_DIR/pacman-packages.txt.new" "$PACKAGES_DIR/pacman-packages.txt"
    mv "$PACKAGES_DIR/aur-packages.txt.new" "$PACKAGES_DIR/aur-packages.txt"
    echo "Updated!"
else
    rm -f "$PACKAGES_DIR/"*.new
    echo "Cancelled"
fi
