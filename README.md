# Arch Linux Hyprland Setup

A complete Arch Linux setup with a neo-brutalist Hyprland environment, including automated system maintenance and backup.

## Quick Start

1. **Run the setup script** (as a regular user, not root):
   ```bash
   cd arch-hyprland-setup
   chmod +x setup.sh
   ./setup.sh
   ```

   Or, if you already have packages installed and only want to apply the design configs:
   ```bash
   chmod +x apply-configs.sh
   ./apply-configs.sh
   ```

2. **Reboot and log in via ReGreet** (greetd will present the login screen automatically)

3. **Enjoy your neo-brutalist Hyprland setup!**

## What's Included

### Core Desktop Environment
- **Hyprland**: Wayland compositor with VFR/VRR optimizations
- **Kitty**: Terminal with 8 neo-brutalist color themes
- **Waybar**: Status bar with neo-brutalist styling
- **Starship**: Shell prompt with custom theme
- **Yazi**: File manager with custom keybindings
- **Mako**: Notification daemon
- **Wofi**: Application launcher
- **Swww**: Wallpaper daemon with cycling support

### System Performance & Maintenance
- **Memory optimization**: Tuned swappiness for high-RAM systems
- **Journal limits**: Capped at 500MB with 1-month retention
- **Pacman cache cleanup**: Weekly automated cleanup (keeps 2 versions)
- **Power management**: Auto power-saver on battery (Framework laptop optimized)
- **Backup automation**: Daily rsync backup over Tailscale
- **Cache cleanup**: Weekly browser/app cache cleanup

### Additional Tools
- Development tools: Git, Docker, Python, Node.js, Rust, Go
- Media tools: MPV, ImageMagick, FFmpeg
- System monitoring: btop, htop, fastfetch
- Modern CLI replacements: eza, bat, ripgrep, fd, zoxide

## Directory Structure

```
arch-hyprland-setup/
├── setup.sh                 # Main installation script
├── apply-configs.sh         # Config-only updates
├── install-prereqs.sh       # Minimal prerequisites
├── sync-from-nixos.sh       # Sync from NixOS host
├── sync-to-repo.sh          # Sync live configs back to repo
├── configs/                 # All configuration files
│   ├── hypr/               # Hyprland configuration
│   ├── kitty/              # Kitty terminal + themes
│   ├── waybar/             # Status bar configuration
│   ├── starship/           # Prompt configuration
│   ├── scripts/            # Custom scripts (including maintenance)
│   ├── systemd/user/       # User timers (backup, cache-cleanup)
│   └── ...                 # Other app configs
├── packages/               # Package lists
│   ├── pacman-packages.txt     # Official repo packages
│   ├── pacman-packages-amd.txt # AMD-specific packages
│   ├── aur-packages.txt        # AUR packages
│   └── aur-packages-amd.txt    # AMD-specific AUR packages
├── scripts/setup/          # System setup scripts (run with sudo)
│   ├── configure-system-performance.sh  # sysctl, journal, paccache
│   ├── configure-sleep.sh               # Sleep mode configuration
│   ├── configure-usb-automount.sh       # USB automount rules
│   └── configure-regreet.sh             # Login manager setup
├── wallpapers/             # Wallpaper files
├── docs/                   # Documentation
│   ├── keybindings.md
│   └── troubleshooting.md
└── android/                # Android recording app
```

## System Maintenance

### Automated Timers

The setup enables these systemd timers:

| Timer | Schedule | Description |
|-------|----------|-------------|
| `paccache.timer` | Weekly | Cleans pacman cache (keeps 2 versions) |
| `backup.timer` | Daily | Rsync backup over Tailscale |
| `cache-cleanup.timer` | Sunday 3AM | Cleans browser/app caches |

Check timer status:
```bash
systemctl --user list-timers
systemctl list-timers  # system timers
```

### Manual Commands

```bash
# System health check
health                    # or ~/.config/scripts/system-health.sh

# Manual cache cleanup
cleanup                   # or ~/.config/scripts/cache-cleanup.sh

# Manual backup
~/.config/scripts/backup.sh

# Remove orphan packages
pacman -Qtdq | sudo pacman -Rns -

# Check for updates
checkupdates
```

### Backup Configuration

Edit `~/.config/scripts/backup.sh` to configure:
- `BACKUP_HOST`: Tailscale IP of backup server (default: 100.115.144.119)
- `BACKUP_USER`: SSH user on backup server
- `BACKUP_PATH`: Destination path on backup server
- `SOURCES`: Directories to backup
- `EXCLUDES`: Patterns to exclude

View backup logs:
```bash
cat ~/.local/state/backup.log
```

## Performance Tuning

### What's Configured

| Setting | Value | Why |
|---------|-------|-----|
| `vm.swappiness` | 10 | Reduces swap usage on high-RAM systems |
| `vm.vfs_cache_pressure` | 50 | Keeps more filesystem cache in RAM |
| `misc.vfr` | true | Variable frame rate (reduces GPU usage when idle) |
| `misc.vrr` | 1 | Variable refresh rate for compatible monitors |

### Power Profiles

Power profiles auto-switch on AC/battery:
- **Plugged in**: `balanced`
- **On battery**: `power-saver`

Manual control:
```bash
powerprofilesctl list
powerprofilesctl set power-saver
```

## Sync Scripts

### Sync FROM NixOS (if dual-booting)
```bash
./sync-from-nixos.sh
```
Copies rendered configs from NixOS Home-Manager to this repo.

### Sync TO repo (after making changes)
```bash
./sync-to-repo.sh
```
Copies live `~/.config` changes back to repo for committing.

### Package snapshot
```bash
./scripts/package-snapshot.sh
```
Updates package lists to match currently installed packages.

## Keybindings

| Key | Action |
|-----|--------|
| `Super+Return` | Open terminal |
| `Super+D` | Application launcher |
| `Super+Q` | Close window |
| `Super+F` | Toggle fullscreen |
| `Super+V` | Toggle floating |
| `Super+1-9` | Switch workspace |
| `Super+Shift+1-9` | Move window to workspace |
| `Super+W` | Next wallpaper |
| `Super+C` | Clipboard history |
| `Ctrl+Alt+1-8` | Switch Kitty theme |

See `docs/keybindings.md` for the complete list.

## Troubleshooting

### Timers not running
```bash
# Check if timers are enabled
systemctl --user list-timers

# Enable if missing
systemctl --user enable --now backup.timer cache-cleanup.timer
```

### Backup failing
```bash
# Check if host is reachable
ping 100.115.144.119

# Check Tailscale status
tailscale status

# View backup log
cat ~/.local/state/backup.log
```

### Power profile not switching
```bash
# Check udev rule exists
cat /etc/udev/rules.d/99-power-profile-switch.rules

# Reload rules
sudo udevadm control --reload-rules
```

See `docs/troubleshooting.md` for more solutions.

## Manual System Configuration

If you need to re-run just the system configuration (requires sudo):
```bash
sudo bash scripts/setup/configure-system-performance.sh $USER
```

This configures:
- `/etc/sysctl.d/99-arch-performance.conf` - Memory tuning
- `/etc/systemd/journald.conf.d/size.conf` - Journal limits
- `/etc/systemd/system/paccache.{service,timer}` - Cache cleanup
- `/etc/udev/rules.d/99-power-profile-switch.rules` - Power auto-switch

## License

Personal configuration - use at your own risk.
