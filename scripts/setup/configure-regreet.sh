#!/bin/bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run this script with sudo (root)." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Defaults
TARGET_USER=${SUDO_USER:-$(logname)}
RESTART=0
INSTALL=0

in_active_wayland_session() {
  if [[ -n "${WAYLAND_DISPLAY:-}" ]] || [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    return 0
  fi
  if command -v loginctl >/dev/null 2>&1 && [[ -n "${XDG_SESSION_ID:-}" ]]; then
    loginctl show-session "$XDG_SESSION_ID" -p Type 2>/dev/null | grep -qi 'Type=wayland' && return 0
  fi
  return 1
}

# Parse args: --restart / --no-restart / --user NAME or positional NAME
while (( $# )); do
  case "${1:-}" in
    --restart)
      RESTART=1
      ;;
    --no-restart)
      RESTART=0
      ;;
    --install)
      INSTALL=1
      ;;
    --no-install)
      INSTALL=0
      ;;
    --user)
      shift
      TARGET_USER=${1:-$TARGET_USER}
      ;;
    --help|-h)
      echo "Usage: sudo $(basename "$0") [--restart] [--user USER]" >&2
      exit 0
      ;;
    *)
      # Treat first non-flag as user
      TARGET_USER=${1}
      ;;
  esac
  shift || true
done

if in_active_wayland_session && (( RESTART )); then
  echo "You are in an active Wayland session; refusing to stop/start greetd. Omit --restart and apply from a TTY later." >&2
  exit 2
fi
GREETER_USER="greeter"
RUNTIME_UID="950"

step() {
  printf '▶ %s\n' "$1"
}

if (( INSTALL )); then
  step "Ensuring greetd/regreet dependencies are installed"
  pacman -S --needed --noconfirm greetd greetd-regreet seatd cage
else
  step "Skipping package install (use --install to install greetd/regreet/seatd)"
fi

if (( RESTART )); then
  step "Stopping greetd and seatd"
  systemctl disable --now greetd.service || true
  systemctl disable --now seatd.service || true
else
  step "Will not stop services (use --restart to apply immediately)"
fi

step "Preparing greeter runtime directories"
install -d -m 755 -o "$GREETER_USER" -g "$GREETER_USER" /var/lib/greetd
for rel in .cache .config .local/share; do
  install -d -m 700 -o "$GREETER_USER" -g "$GREETER_USER" "/var/lib/greetd/$rel"
done
install -d -m 700 -o "$GREETER_USER" -g "$GREETER_USER" "/run/user/$RUNTIME_UID"

step "Writing /etc/greetd/config.toml"
install -d -m 755 /etc/greetd
cat >/etc/greetd/config.toml <<'GREETD_CFG'
[terminal]
vt = 1
switch = true

[default_session]
# Limit sessions to Wayland by setting SESSION_DIRS/XDG_DATA_DIRS for ReGreet
command = "/usr/bin/env SESSION_DIRS=/usr/share/wayland-sessions XDG_DATA_DIRS=/usr/share/wayland-sessions:/usr/share /usr/bin/cage -s -- /usr/bin/regreet --config /etc/greetd/regreet.toml --style /etc/greetd/regreet.css"
user = "greeter"

[default_session.env]
HOME = "/var/lib/greetd"
XDG_CACHE_HOME = "/var/lib/greetd/.cache"
XDG_CONFIG_HOME = "/var/lib/greetd/.config"
XDG_DATA_HOME = "/var/lib/greetd/.local/share"
XDG_RUNTIME_DIR = "/run/user/950"
WAYLAND_DISPLAY = "wayland-0"
GREETD_CFG

step "Installing Hyprland session wrapper"
install -d -m 755 /usr/local/bin
cat >/usr/local/bin/hyprland-session.sh <<'WRAP'
#!/bin/bash
set -euo pipefail
set -o pipefail

LOGFILE="$HOME/.local/share/hyprland-launch.log"
mkdir -p "$(dirname "$LOGFILE")"
{
  echo "=== Hyprland launch $(date) ==="
  env | sort
  echo "---"
} >> "$LOGFILE" 2>&1

export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=Hyprland
# Ensure runtime dir (usually set by pam_systemd)
if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
  export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi
# Optional safety toggles for troublesome GPUs; uncomment if needed:
# export WLR_RENDERER_ALLOW_SOFTWARE=1
# export WLR_NO_HARDWARE_CURSORS=1

# Log both to a file and to journald for easier debugging
/usr/bin/dbus-run-session /usr/bin/Hyprland 2>&1 \
  | /usr/bin/tee -a "$LOGFILE" \
  | /usr/bin/systemd-cat -t hyprland-greetd
WRAP
chmod +x /usr/local/bin/hyprland-session.sh

step "Writing Hyprland wayland-session entry"
install -d -m 755 /usr/share/wayland-sessions
cat >/usr/share/wayland-sessions/hyprland.desktop <<'DESK'
[Desktop Entry]
Name=Hyprland
Comment=Hyprland Wayland session
Exec=/usr/local/bin/hyprland-session.sh
Type=Application
DesktopNames=Hyprland
DESK

step "Writing /etc/greetd/regreet.toml"
cat >/etc/greetd/regreet.toml <<REGREET_TOML
[session]
# Launch Hyprland via wrapper that logs to ~/.local/share
command = "/usr/local/bin/hyprland-session.sh"
user = "$TARGET_USER"

[env]
XDG_SESSION_TYPE = "wayland"
XDG_CURRENT_DESKTOP = "Hyprland"

[commands]
reboot = [ "systemctl", "reboot" ]
poweroff = [ "systemctl", "poweroff" ]
REGREET_TOML

step "Deploying regreet stylesheet"
if [[ -f "$REPO_ROOT/configs/greetd/regreet.css" ]]; then
  install -m 644 "$REPO_ROOT/configs/greetd/regreet.css" /etc/greetd/regreet.css
fi

step "Ensuring seat group membership"
if ! id -nG "$TARGET_USER" | grep -qw seat; then
  usermod -aG seat "$TARGET_USER"
fi
if ! id -nG "$GREETER_USER" | grep -qw seat; then
  usermod -aG seat "$GREETER_USER"
fi

# Also ensure input/video groups for DRM/evdev access when using seatd
for grp in input video; do
  if ! id -nG "$TARGET_USER" | grep -qw "$grp"; then
    usermod -aG "$grp" "$TARGET_USER"
  fi
  if ! id -nG "$GREETER_USER" | grep -qw "$grp"; then
    usermod -aG "$grp" "$GREETER_USER"
  fi
done

if (( RESTART )); then
  step "Re-enabling seatd and greetd"
  systemctl enable --now seatd.service
  systemctl reset-failed greetd.service || true
  systemctl enable --now greetd.service

  step "Setting graphical.target as default"
  systemctl set-default graphical.target
  printf '\nRegreet configured and applied. Switch to greeter (VT1).\n'
else
  printf '\nRegreet configured. To apply safely from a TTY run:\n'
  printf '  sudo systemctl restart seatd greetd\n\n'
fi
