#!/bin/bash
# VS Code theme switching script

# Define themes
THEMES=(
  "Default Dark+"
  "Default Light+"
  "Monokai"
  "Solarized Dark"
  "Solarized Light"
  "GitHub Dark"
  "GitHub Light"
  "One Dark Pro"
)

# Get current theme or set default
CURRENT_THEME_FILE="$HOME/.config/vscode-current-theme"
if [[ -f "$CURRENT_THEME_FILE" ]]; then
  CURRENT_INDEX=$(cat "$CURRENT_THEME_FILE")
else
  CURRENT_INDEX=0
fi

case "$1" in
  "cycle")
    # Cycle to next theme
    CURRENT_INDEX=$(((CURRENT_INDEX + 1) % ${#THEMES[@]}))
    ;;
  "dark")
    CURRENT_INDEX=0 # Default Dark+
    ;;
  "light")
    CURRENT_INDEX=1 # Default Light+
    ;;
  *)
    echo "Usage: $0 {cycle|dark|light}"
    echo "Current theme: ${THEMES[$CURRENT_INDEX]}"
    exit 1
    ;;
esac

# Save current index
echo "$CURRENT_INDEX" >"$CURRENT_THEME_FILE"

# Get theme name
THEME_NAME="${THEMES[$CURRENT_INDEX]}"

# Apply theme using VS Code CLI
if command -v code >/dev/null 2>&1; then
  code --install-extension ms-vscode.theme-defaults 2>/dev/null || true

  # Create settings.json update
  VSCODE_SETTINGS="$HOME/.config/Code/User/settings.json"

  if [[ -f "$VSCODE_SETTINGS" ]]; then
    # Update existing settings
    jq --arg theme "$THEME_NAME" '.["workbench.colorTheme"] = $theme' "$VSCODE_SETTINGS" >"${VSCODE_SETTINGS}.tmp" && mv "${VSCODE_SETTINGS}.tmp" "$VSCODE_SETTINGS"
  else
    # Create new settings file
    mkdir -p "$(dirname "$VSCODE_SETTINGS")"
    echo "{\"workbench.colorTheme\": \"$THEME_NAME\"}" >"$VSCODE_SETTINGS"
  fi

  echo "VS Code theme changed to: $THEME_NAME"

  # Send notification
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "VS Code Theme" "Changed to: $THEME_NAME" -t 2000
  fi
else
  echo "VS Code not found!"
  exit 1
fi
