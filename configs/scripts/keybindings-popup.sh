#!/bin/bash

# Show Hyprland keybindings in a scrollable popup (yad/zenity fallback to less)

set -euo pipefail

render_section() {
  local title="$1"
  local rows="$2"

  printf '%s\n' "$title"
  printf '%s\n' "$(printf '%*s' "${#title}" '' | tr ' ' '-')"
  column -t -s '|' <<<"$rows"
  printf '\n'
}

build_keybindings_text() {
  local launch window nav workspaces resize monitors screenshots media themes kitty mouse

  launch="$(cat <<'EOF'
Super + Return|Open terminal (Kitty)
Super + E|File manager (Dolphin)
Super + D|Application launcher (Wofi)
Super + C|Clipboard history
Super + Alt + L|Lock screen
Super + Alt + P|Power menu
Super + Alt + R|Reload Hyprland config
Super + M|Exit Hyprland
EOF
)"

  window="$(cat <<'EOF'
Super + Q|Kill active window
Super + V|Toggle floating
Super + P|Toggle pseudo-tiling
Super + J|Toggle split direction
Super + F|Toggle fullscreen
EOF
)"

  nav="$(cat <<'EOF'
Super + ←/→/↑/↓|Focus window
Super + Alt + ←/→/↑/↓|Swap window with neighbor
Super + Ctrl + ←/→/↑/↓|Resize active window
EOF
)"

  workspaces="$(cat <<'EOF'
Super + ←/→|Previous/next workspace
Super + 1-9,0|Switch to workspace 1-10
Super + Shift + ←/→|Move window to previous/next workspace
Super + Shift + 1-9,0|Move window to workspace 1-10
Super + S|Toggle special workspace
Super + Shift + S|Move window to special workspace
Super + Shift + ↑|Workspace overview
Super + Shift + Space|Workspace notes menu
Super + Shift + N|Workspace notes menu
EOF
)"

  resize="$(cat <<'EOF'
Super + R|Enter/exit resize mode (use arrows or h/j/k/l)
Super + Shift + H|Reduce width by 50%
Super + Shift + V|Reduce height by 50%
Super + Ctrl + H|Double width
Super + Ctrl + V|Double height
Super + Shift + C|Center floating window
EOF
)"

  monitors="$(cat <<'EOF'
Super + .|Focus next monitor
Super + ,|Focus previous monitor
Super + Ctrl + M|Monitor connection script
EOF
)"

  screenshots="$(cat <<'EOF'
Print|Screenshot selection → clipboard
Super + Print|Screenshot full screen → clipboard
Super + Shift + Print|Screenshot selection → file
EOF
)"

  media="$(cat <<'EOF'
XF86AudioRaiseVolume|Volume up
XF86AudioLowerVolume|Volume down
XF86AudioMute|Toggle mute
XF86AudioMicMute|Toggle microphone
XF86MonBrightnessUp|Brightness up
XF86MonBrightnessDown|Brightness down
XF86AudioPlay/Pause|Play/pause media
XF86AudioNext/Prev|Next/previous track
EOF
)"

  themes="$(cat <<'EOF'
Super + W|Next wallpaper
Super + Shift + W|Previous wallpaper
Super + Ctrl + W|Random wallpaper
Super + T|Cycle VS Code themes
Super + Shift + T|VS Code dark theme
Super + Ctrl + T|VS Code light theme
EOF
)"

  kitty="$(cat <<'EOF'
Ctrl + Shift + T|New tab
Ctrl + Shift + Q|Close tab
Ctrl + Shift + Enter|New window/split
Ctrl + Shift + W|Close window/split
Ctrl + Shift + Left/Right|Previous/next tab
Ctrl + Shift + [/]|Previous/next split
Ctrl + Alt + 1-8|Kitty theme 1-8 (Yellow, Blue, Purple, Green, Orange, Black, Dark Grey, White)
EOF
)"

  mouse="$(cat <<'EOF'
Super + Left Drag|Move window
Super + Right Drag|Resize window
Super + Scroll|Switch workspaces
EOF
)"

  {
    printf '%s\n' "HYPRLAND KEYBINDINGS"
    printf '%s\n\n' "===================="
    render_section "Launchers & system" "$launch"
    render_section "Window management" "$window"
    render_section "Navigation" "$nav"
    render_section "Workspaces" "$workspaces"
    render_section "Resize & layout" "$resize"
    render_section "Monitors" "$monitors"
    render_section "Screenshots" "$screenshots"
    render_section "Media & brightness" "$media"
    render_section "Wallpapers & themes" "$themes"
    render_section "Kitty tabs & themes" "$kitty"
    render_section "Mouse actions" "$mouse"
  }
}

show_with_yad() {
  command -v yad >/dev/null 2>&1 || return 1
  printf '%s' "$1" | yad --center --title="Hyprland Keybindings" --width=900 --height=720 --text-info --wrap --margins=16 --fontname="JetBrains Mono 11" --button=gtk-close:0
}

show_with_zenity() {
  command -v zenity >/dev/null 2>&1 || return 1
  printf '%s' "$1" | zenity --text-info --title="Hyprland Keybindings" --width=900 --height=720 --font="JetBrains Mono 11" --ok-label="Close"
}

main() {
  local payload
  payload="$(build_keybindings_text)"

  show_with_yad "$payload" && exit 0
  show_with_zenity "$payload" && exit 0

  if command -v less >/dev/null 2>&1; then
    printf '%s\n' "$payload" | less -R
  else
    printf '%s\n' "$payload"
  fi
}

main "$@"
