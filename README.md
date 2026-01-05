# Arch Linux Hyprland Setup

A complete Arch Linux setup with a neo-brutalist Hyprland environment, including automated system maintenance and backup.

## Quick Start

1. **Run the setup script** (as a regular user, not root):
   ```bash
   cd controlcenter
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
  - Modules: workspaces, clock, cpu, memory, temperature, disk, backlight, bluetooth, network, battery, updates indicator, idle inhibitor, power menu
  - Click-to-manage for bluetooth, brightness scroll, calendar navigation
- **Starship**: Shell prompt with custom theme
- **Yazi**: File manager with custom keybindings
- **Mako**: Notification daemon
- **Wofi**: Application launcher (+ power menu)
- **Swww**: Wallpaper daemon with cycling support
- **Hyprlock**: Lock screen (Super+L)
- **ReGreet/greetd**: Login manager

### System Performance & Maintenance
- **Memory optimization**: Tuned swappiness for high-RAM systems
- **Journal limits**: Capped at 500MB with 1-month retention
- **Pacman cache cleanup**: Weekly automated cleanup (keeps 2 versions)
- **Power management**: Auto power-saver on battery (Framework laptop optimized)
- **Backup automation**: Daily rsync backup over Tailscale
- **Cache cleanup**: Weekly browser/app cache cleanup

### Neovim IDE
- **LazyVim** based configuration with full IDE features
- LSP support for Python, Rust, Go, TypeScript, and more
- SSH remote development via remote-sshfs
- Catppuccin theme with neo-brutalist accents
- See `docs/neovim-ide.md` for full guide

### Additional Tools
- Development tools: Git, Docker, Python, Node.js, Rust, Go
- AI & Agent Tools: Claude Code, Codex, Opencode (managed via repo)
- Media tools: MPV, ImageMagick, FFmpeg
- System monitoring: btop, htop, fastfetch
- Modern CLI replacements: See [Modern CLI Tools](#modern-cli-tools) section below

## Directory Structure

```
controlcenter/
├── setup.sh                 # Main installation script
├── apply-configs.sh         # Config-only updates
├── install-prereqs.sh       # Minimal prerequisites
├── sync-from-nixos.sh       # Sync from NixOS host
├── sync-to-repo.sh          # Sync live configs back to repo
├── configs/                 # All configuration files
│   ├── bash/               # Bash configuration (single source of truth)
│   ├── hypr/               # Hyprland + hyprlock configuration
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
│   ├── neovim-ide.md       # Neovim IDE guide
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
| `Super+L` | Lock screen (hyprlock) |
| `Super+F` | Toggle fullscreen |
| `Super+V` | Toggle floating |
| `Super+1-9` | Switch workspace |
| `Super+Shift+1-9` | Move window to workspace |
| `Super+W` | Next wallpaper |
| `Super+C` | Clipboard history |
| `Ctrl+Alt+1-8` | Switch Kitty theme |

See `docs/keybindings.md` for the complete list.

## Modern CLI Tools

This setup replaces traditional Unix tools with faster Rust/Go alternatives. All are aliased automatically in bashrc.

### File Operations

| Tool | Replaces | Description |
|------|----------|-------------|
| **eza** | ls | Modern ls with icons, git status, tree view |
| **bat** | cat | Syntax highlighting, line numbers, git integration |
| **fd** | find | Intuitive syntax, respects .gitignore, 5x faster |
| **sd** | sed | Simpler regex find/replace syntax |
| **ouch** | tar/zip/etc | Universal archive tool (compress/decompress) |

```bash
# eza - list files with git status
ll                        # detailed list with git status
lt                        # tree view (2 levels)
eza --tree --level=3      # deeper tree

# bat - view files with syntax highlighting
bat script.sh             # syntax highlighted view
bat -A file.txt           # show invisible characters
bat --diff file.txt       # show git diff inline

# fd - find files fast
fd "\.py$"                # find Python files
fd -e rs -x wc -l         # find .rs files, count lines each
fd config --type d        # find directories named "config"

# sd - simple find/replace
sd 'foo' 'bar' file.txt   # replace foo with bar
sd -s 'func()' 'fn()' .   # literal string replace (no regex)
echo "hello" | sd 'l' 'L' # works with pipes

# ouch - universal archives
ouch d archive.tar.gz     # decompress any format
ouch c file1 file2 out.zip # compress to any format
ouch l archive.7z         # list contents
```

### Search & Navigation

| Tool | Replaces | Description |
|------|----------|-------------|
| **ripgrep (rg)** | grep | Fastest grep, respects .gitignore |
| **fzf** | - | Fuzzy finder for files, history, everything |
| **zoxide** | cd | Smarter cd that learns your habits |
| **atuin** | Ctrl+R | Synced shell history with fuzzy search |

```bash
# ripgrep - search file contents
rg "TODO"                 # search for TODO in all files
rg -t py "import"         # search only Python files
rg -l "error"             # list files containing "error"
rg --replace 'new' 'old'  # preview replacements

# fzf - fuzzy find anything
Ctrl+R                    # fuzzy search command history
Ctrl+T                    # fuzzy find files to insert
Alt+C                     # fuzzy cd into directory
vim $(fzf)                # open fzf-selected file in vim

# zoxide - smart directory jumping
z projects                # jump to most-used "projects" dir
z doc arch                # jump to dir matching "doc" AND "arch"
zi                        # interactive selection with fzf

# atuin - synced shell history
Ctrl+R                    # fuzzy search all shell history
atuin search "git push"   # search specific commands
atuin stats               # shell usage statistics
```

### System Monitoring

| Tool | Replaces | Description |
|------|----------|-------------|
| **bottom (btm)** | htop/top | Modern system monitor with graphs |
| **procs** | ps | Colorful process viewer with search |
| **dust** | du | Intuitive disk usage visualization |
| **duf** | df | Better disk free display |
| **bandwhich** | nethogs | Per-process bandwidth monitor |

```bash
# bottom - system monitor
btm                       # full TUI (aliased to 'top' and 'htop')
btm --basic               # simplified view
btm -b                    # battery widget

# procs - process viewer
procs                     # colorful process list (aliased to 'ps')
procs --sortd cpu         # sort by CPU descending
procs --tree              # process tree view
procs firefox             # filter by name

# dust - disk usage
dust                      # visualize current directory
dust -d 2 /home           # depth 2, specific path
dust -r                   # reverse order (smallest first)

# duf - disk free
duf                       # all mounted filesystems (aliased to 'df')
duf /home                 # specific mount point
duf --only local          # only local filesystems
```

### Git Enhancements

| Tool | Replaces | Description |
|------|----------|-------------|
| **lazygit** | git CLI | Full TUI for git operations |
| **delta** | diff | Side-by-side diffs with syntax highlighting |
| **tokei** | cloc | Fast code statistics |

```bash
# lazygit - git TUI
lazygit                   # full git interface
# Press ? for help, space to stage, c to commit, P to push

# delta - configured as git pager automatically
git diff                  # side-by-side colored diff
git show HEAD             # syntax highlighted commit
git log -p                # patches with highlighting

# tokei - code statistics
tokei                     # stats for current project
tokei src/                # specific directory
tokei --files             # per-file breakdown
```

### Developer Tools

| Tool | Replaces | Description |
|------|----------|-------------|
| **just** | make | Modern command runner with simpler syntax |
| **hyperfine** | time | Statistical benchmarking tool |
| **tealdeer (tldr)** | man | Simplified, practical man pages |
| **glow** | - | Render markdown in terminal |
| **hexyl** | xxd/hexdump | Colorful hex viewer |
| **vivid** | LS_COLORS | Generate better file colors |
| **xh** | curl (for APIs) | HTTPie-like, fast HTTP client |
| **grex** | - | Generate regex from examples |

```bash
# just - command runner (alias: j)
j build                   # run "build" recipe from justfile
j --list                  # show available recipes
just test --verbose       # run with arguments

# hyperfine - benchmarking
hyperfine 'fd -e py'      # benchmark single command
hyperfine 'rg foo' 'grep foo'  # compare two commands
hyperfine -w 3 'cmd'      # 3 warmup runs first

# tldr - quick help (aliased to 'man')
tldr tar                  # practical tar examples
tldr git-rebase           # common git rebase usage
gman tar                  # original man page (alias)

# glow - markdown viewer
glow README.md            # render markdown beautifully
glow -p README.md         # pager mode

# hexyl - hex viewer
hex binary_file           # colorful hex dump
hexyl -n 256 file         # first 256 bytes

# xh - HTTP client
xh GET httpbin.org/get    # simple GET request
xh POST api.com/data name=value  # POST with JSON
xh -d api.com/file        # download file

# grex - regex generator
grex 'foo' 'foobar'       # generates: foo(bar)?
grex -r 'test1' 'test2'   # with repetition detection
```

### Build Performance (Rust)

The setup includes optimizations for Rust development:

| Tool | Purpose |
|------|---------|
| **mold** | 10-20x faster linker than ld |
| **sccache** | Compiler cache for faster rebuilds |

These are configured automatically in `~/.cargo/config.toml`:
```bash
# First build: normal speed
cargo build

# Subsequent builds: much faster (sccache hits)
cargo build

# Check sccache stats
sccache --show-stats
```

### Tool Aliases Quick Reference

```bash
# File operations
ls → eza                  # with icons and git status
cat → bat                 # with syntax highlighting
find → fd                 # intuitive and fast
sed → sd                  # simpler syntax

# Search
grep → rg                 # ripgrep with smart-case

# Navigation
cd → z                    # zoxide smart jump

# System
top/htop → btm           # bottom system monitor
ps → procs               # colorful process list
du → dust                # visual disk usage
df → duf                 # better disk free

# Documentation
man → tldr               # simplified man pages

# Access originals with 'g' prefix
gls, gcat, gfind, ggrep, gman, gsed
```

## AI & Agent Tools

This repository manages configurations, skills, and plugins for various AI agent tools to ensure a consistent experience across machines.

| Tool | Config Location | Managed Content |
|------|-----------------|-----------------|
| **Claude Code** | `~/.claude/` | Skills, plugins, core settings, tools |
| **Codex** | `~/.codex/` | Shared skills, configuration |
| **Opencode** | `~/.config/opencode/` | Core tool settings and JSON configs |

### Syncing
- **Sensitive data** (.credentials.json, auth.json, session logs) is **EXCLUDED** from the repository for security.
- Running `./apply-configs.sh` will automatically sync the managed parts of these directories from the repo to your home directory.
- For new machines, these tools will have your core skills and plugins ready after the first apply.

### Key Managed Files
- `configs/claude/skills/`: Custom agent skills and tool definitions.
- `configs/claude/plugins/`: Installed marketplaces and plugins.
- `configs/codex/config.toml`: Global codex behavior settings.
- `configs/opencode/opencode.json`: Opencode agent parameters.


## Waybar Modules

| Module | Function | Interaction |
|--------|----------|-------------|
| 😴/☕ Idle Inhibitor | Prevent sleep | Click to toggle |
| 📦 Updates | Pending pacman updates | Click to upgrade |
| 🧠 CPU | CPU usage % | Hover for details |
| 🐏 Memory | RAM usage % | Click for GB view |
| 🌡️ Temperature | CPU temp | - |
| 💽 Disk | /home usage | Right-click for ncdu |
| 🌕 Backlight | Screen brightness | Scroll to adjust |
| 🔊 Audio | Volume level | Click for pavucontrol |
| 󰂯 Bluetooth | Connection status | Click for blueman |
| 📶 Network | WiFi/Ethernet | Click for wifi menu |
| 🔋 Battery | Charge level | Click for time remaining |
| ⏻ Power | Power menu | Lock/Sleep/Reboot/Shutdown |

## Bash Configuration

The bash configuration lives in `configs/bash/bashrc` - this is the single source of truth.

`~/.bashrc` is just a minimal loader that sources the repo file:
```bash
if [[ -f "$HOME/controlcenter/configs/bash/bashrc" ]]; then
    source "$HOME/controlcenter/configs/bash/bashrc"
fi
```

This ensures all bash customizations are version-controlled in the repo.

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
