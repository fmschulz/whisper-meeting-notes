# Troubleshooting Guide

## Common Issues and Solutions

### Installation Issues

#### Package Installation Fails
```bash
# Update package databases
sudo pacman -Syu

# Clear package cache if needed
sudo pacman -Scc

# For AUR packages, rebuild yay
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay && makepkg -si
```

#### Missing Dependencies
```bash
# Install base development tools
sudo pacman -S base-devel git

# Install missing dependencies manually
sudo pacman -S <package-name>
```

#### Personal App Configs Missing After running ./apply-configs.sh
1. Earlier revisions of the script mirrored the entire ~/.config tree and deleted unmanaged app data. Restore the affected directory from backup if you have one available (e.g. `~/.config/chromium`).
2. Re-run the latest `./apply-configs.sh`; it now syncs only the tracked config folders and preserves personal app data for Chromium, Firefox, VS Code, Obsidian, and others.

### Hyprland Issues

#### Hyprland Won't Start
1. Check if you're using a compatible GPU driver:
   ```bash
   lspci | grep VGA
   # For AMD: install mesa, vulkan-radeon
   # For NVIDIA: install nvidia, nvidia-utils
   ```

2. Check Hyprland logs:
   ```bash
   journalctl --user -u hyprland -f
   ```

3. Try starting from TTY:
   ```bash
   # Switch to TTY (Ctrl+Alt+F2)
   Hyprland
   ```

#### Hyprland Boots to a Console Login
1. Ensure the graphical target is enabled:
   ```bash
   sudo systemctl set-default graphical.target
   ```
2. Install and enable a display manager (e.g. `greetd`, `sddm`, or `gdm`). Example with greetd:
   ```bash
   sudo pacman -S greetd tuigreet
   sudo systemctl enable --now greetd.service
   ```
   Set the default session to Hyprland by editing `/etc/greetd/config.toml`:
   ```toml
   [terminal]
   vt = 1

   [default_session]
   command = "Hyprland"
   user = "<your-username>"
   ```
3. Prefer starting Hyprland from a display manager rather than `~/.bash_profile` so user services (Waybar, nm-applet, blueman-applet) can launch automatically.
4. If you already ran the setup script, greetd + regreet should be installed and enabled; verify with `sudo systemctl status greetd` and ensure `/etc/greetd/regreet.css` exists.

#### Black Screen on Login
1. Check if all required packages are installed:
   ```bash
   pacman -Q hyprland waybar kitty wofi
   ```

2. Reset Hyprland config:
   ```bash
   mv ~/.config/hypr/hyprland.conf ~/.config/hypr/hyprland.conf.backup
   cp /path/to/arch-hyprland-setup/configs/hypr/hyprland.conf ~/.config/hypr/
   ```

#### Window Rules Not Working
1. Check window class names:
   ```bash
   hyprctl clients
   ```

2. Update window rules in `~/.config/hypr/hyprland.conf`

### Audio Issues

#### No Audio Output
1. Check PipeWire status:
   ```bash
   systemctl --user status pipewire pipewire-pulse
   ```

2. Restart audio services:
   ```bash
   systemctl --user restart pipewire pipewire-pulse wireplumber
   ```

3. Check audio devices:
   ```bash
   wpctl status
   pactl list sinks
   ```

#### Audio Crackling
1. Increase buffer size in PipeWire config
2. Check for conflicting audio systems:
   ```bash
   pulseaudio --check -v  # Should show "not running"
   ```

#### Volume Keys Do Nothing
1. The media-key binds call `~/.config/scripts/volume-control.sh`, which now uses `wpctl` by default (PipeWire) and falls back to `pactl` if available. Ensure PipeWire is running:
   ```bash
   systemctl --user status pipewire pipewire-pulse wireplumber
   ```
2. Test the script directly and watch Waybar volume change:
   ```bash
   ~/.config/scripts/volume-control.sh up
   ~/.config/scripts/volume-control.sh down
   ~/.config/scripts/volume-control.sh mute
   ```
3. Verify Hyprland sees the key symbols by pressing them while running:
   ```bash
   wev   # Look for XF86Audio* events
   ```

#### Volume Keys Change The Wrong Output
1. The script adjusts `@DEFAULT_AUDIO_SINK@`. If the wrong device changes, set the correct one as default in `pavucontrol` (Playback/Output Devices → right-click → Set as fallback) or via:
   ```bash
   wpctl status           # note the sink ID you want
   wpctl set-default <ID> # e.g., 48
   ```

#### Zoom Very Quiet While System Sounds Are Loud
1. Check Zoom’s stream volume specifically in `pavucontrol` → Playback (it may be low even if the sink is at 100–150%).
2. Disable “flat volumes” so one quiet app doesn’t drag the whole sink down. This repo ships a drop‑in at `~/.config/pipewire/pipewire-pulse.conf.d/10-disable-flat-volumes.conf`.
   - Apply configs, then restart audio:
     ```bash
     ./apply-configs.sh
     systemctl --user restart pipewire pipewire-pulse wireplumber
     ```
3. Ensure Zoom outputs to the same default sink shown in Waybar (check via the “Output Device” dropdown in Zoom’s audio settings or in `pavucontrol`).

### Display Issues

#### Wrong Resolution/Scaling
1. Check available monitors:
   ```bash
  hyprctl monitors
  ```

### Apps

#### Chromium: "Profile in use on another computer"
Chromium stores lock artifacts in the profile directory and ties them to the current hostname. If your hostname changes (e.g., DHCP assigns a transient FQDN), Chromium may think the profile is in use elsewhere.

Fix now (one‑off):
1. Ensure no Chromium is running:
   ```bash
   pgrep -fa chromium || true
   ```
2. Remove stale lock files and relaunch:
   ```bash
   rm -f ~/.config/chromium/SingletonLock ~/.config/chromium/SingletonCookie ~/.config/chromium/SingletonSocket
   chromium
   ```

Fix permanently (recommended):
- Use the bundled launcher that auto‑cleans stale locks:
  - Desktop entry uses `~/.config/scripts/chromium-safe.sh`.
  - Re‑apply configs if needed:
    ```bash
    ./apply-configs.sh
    ```
- Set a static hostname so it doesn’t flip with networks:
  ```bash
  sudo hostnamectl set-hostname framework12
  hostnamectl   # should now show a Static hostname
  ```
  If your transient hostname still changes and triggers the error, configure your network stack not to override the kernel hostname (e.g., NetworkManager hostname updates) or keep using the safe launcher above.

2. Update monitor config in `~/.config/hypr/hyprland.conf`:
   ```
   monitor = eDP-1,1920x1080@60,0x0,1.0
   ```

#### Multiple Monitor Issues
1. Use monitor connection script:
   ```bash
   ~/.config/scripts/monitor-connect.sh
   ```

2. Check display configuration:
   ```bash
   wlr-randr
   ```

#### Clamshell Mode (Docked)
1. Tell systemd-logind to ignore the lid switch while docked so the laptop stays awake:
   ```bash
   sudo mkdir -p /etc/systemd/logind.conf.d
   printf "[Login]
HandleLidSwitch=ignore
HandleLidSwitchDocked=ignore
" | sudo tee /etc/systemd/logind.conf.d/ignore-lid.conf
   sudo systemctl restart systemd-logind
   ```

2. Re-run `./apply-configs.sh` (or copy manually) so `~/.config/scripts/clamshell-mode.sh` is present and executable. Hyprland auto-starts it via `exec-once` and you can confirm with:
   ```bash
   ps -C clamshell-mode.sh
   ```

#### Cursor Hard to See on Bright Terminals
1. Kitty defaults to switching the pointer to a thin I-beam while hovering text. Apply the updated config (or add these lines manually) so an arrow is used instead:
   ```conf
   default_pointer_shape arrow
   pointer_shape_when_grabbed arrow
   pointer_shape_when_dragging arrow arrow
   ```
2. Re-run `./apply-configs.sh` or apply on the fly:
   ```bash
   kitty @ set-config default_pointer_shape=arrow pointer_shape_when_grabbed=arrow pointer_shape_when_dragging="arrow arrow"
   ```

3. Close the lid. All workspaces assigned to the internal panel move to the focused external display and the internal panel is disabled. Reopening the lid re-enables the panel and returns those workspaces.

### Productivity Apps

#### Zoom Workplace Setup
1. Ensure `zoom` is listed in `packages/aur-packages.txt`, then install via `yay -S zoom` or rerun `./install-prereqs.sh` to pull AUR updates.
2. Launch Zoom through `~/.config/scripts/zoom-workplace.sh` so Wayland-friendly environment variables are set. You can create a launcher with `Exec=~/.config/scripts/zoom-workplace.sh` if you prefer a menu entry.
3. For screen sharing, verify the PipeWire portal stack is running:
   ```bash
   systemctl --user status xdg-desktop-portal xdg-desktop-portal-wlr
   ```
   Restart them after installing Zoom if sharing fails:
   ```bash
   systemctl --user restart xdg-desktop-portal xdg-desktop-portal-wlr
   ```
4. Zoom still offers an XWayland fallback. If the Wayland session misbehaves, run `QT_QPA_PLATFORM=xcb ~/.config/scripts/zoom-workplace.sh` to force the legacy path.

### Theme Issues

#### Kitty Themes Not Working
1. Check if remote control is enabled:
   ```bash
   grep "allow_remote_control" ~/.config/kitty/kitty.conf
   ```

2. Test theme switching manually:
   ```bash
   kitty @ set-colors ~/.config/kitty/themes/Neo-Brutalist-Blue.conf
   ```

#### Waybar Not Showing
1. Check Waybar status:
   ```bash
   pgrep waybar
   ```

2. Restart Waybar:
   ```bash
   pkill waybar && waybar &
   ```

3. Check Waybar logs:
   ```bash
   waybar -l debug
   ```

### Network Issues

#### Slow loads in browsers (YouTube takes minutes)

If some sites (especially YouTube / YouTube Music) hang for a long time before loading, it can be caused by proxy auto-detection (WPAD) timing out.

Quick check from a terminal:

```bash
curl --max-time 3 http://wpad/wpad.dat
```

If that command spends multiple seconds “Resolving” and then times out, disable proxy auto-detection:

- **Firefox**: Settings → Network Settings → set **No proxy** (or disable “Auto-detect proxy settings for this network”).
- **Electron YouTube Music app**: this repo ships `configs/youtube-music-flags.conf` with `--no-proxy-server` to skip proxy auto-detection.

#### WiFi Not Working
1. Check NetworkManager status:
   ```bash
   sudo systemctl status NetworkManager
   ```

2. Enable NetworkManager:
   ```bash
   sudo systemctl enable --now NetworkManager
   ```

3. Use nmcli for connection:
   ```bash
   nmcli device wifi list
   nmcli device wifi connect "SSID" password "password"
   ```

#### Bluetooth Issues
1. Check Bluetooth service:
   ```bash
   sudo systemctl status bluetooth
   ```

2. Enable Bluetooth:
   ```bash
   sudo systemctl enable --now bluetooth
   ```

3. Use bluetoothctl:
   ```bash
   bluetoothctl
   power on
   scan on
   ```

### Performance Issues

#### High CPU Usage
1. Check running processes:
   ```bash
   htop
   ```

2. Disable animations temporarily:
   ```bash
   # Add to hyprland.conf
   animations {
       enabled = false
   }
   ```

#### Memory Issues
1. Check memory usage:
   ```bash
   free -h
   ```

2. Enable zram swap:
   ```bash
   sudo systemctl enable --now systemd-zram-setup@zram0.service
   ```

### Application Issues

#### VS Code Theme Switching Not Working
1. Check if jq is installed:
   ```bash
   pacman -Q jq
   ```

2. Check VS Code settings file:
   ```bash
   ls -la ~/.config/Code/User/settings.json
   ```

#### File Manager Issues
1. For Dolphin issues, install KDE de
