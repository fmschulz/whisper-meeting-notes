# NEXUS - Futuristic Hyprland Configuration

A stunning cyberpunk-themed Hyprland setup for Arch Linux with comprehensive automation and user-friendly features.

![](https://img.shields.io/badge/Platform-Arch_Linux-1793d1?style=for-the-badge&logo=archlinux)
![](https://img.shields.io/badge/WM-Hyprland-00a8ff?style=for-the-badge)
![](https://img.shields.io/badge/Theme-Cyberpunk-b967ff?style=for-the-badge)

## ✨ Features

- **Futuristic Design**: Cyberpunk-inspired theme with neon colors and smooth animations
- **Modern CLI Tools**: Replaces traditional Unix commands with modern alternatives (bat, eza, ripgrep, etc.)
- **AI/LLM Stack**: Complete Docker setup for Ollama, vLLM, llama.cpp, and more
- **Hardware Control**: RGB lighting and liquid cooling management for Corsair 400D & Mjolnir
- **Container Ready**: Docker, Podman, and Apptainer for containerized workflows
- **VPN Integration**: Tailscale for secure networking
- **Complete Environment**: Pre-configured Hyprland, Waybar, Rofi, and more
- **Smart Automation**: One-click installation and backup scripts
- **User-Friendly**: All essential features configured out-of-the-box
- **Performance Optimized**: Smooth animations with hardware acceleration
- **Gaming Ready**: Steam and gaming optimizations included

## 🎨 Color Palette

- Neon Purple: `#b967ff`
- Neon Cyan: `#01cdfe`
- Electric Blue: `#05ffa1`
- Deep Purple: `#2d1b69`
- Dark Background: `#0d0221`

## 📦 Included Software

### Core Components
- **Window Manager**: Hyprland with custom animations
- **Status Bar**: Waybar with comprehensive modules
- **App Launcher**: Rofi with cyberpunk theme
- **Terminal**: Kitty & Alacritty
- **Notifications**: Dunst

### Applications
- **Browser**: Firefox with Betterfox
- **Development**: VSCode, Neovim, Codeium
- **Media**: VLC, Spotify, Audacity
- **Documents**: Zathura (PDF), IMV (Images)
- **Productivity**: Obsidian, Btop
- **Gaming**: Steam with GameMode
- **Package Manager**: Pixi for Python

### Modern CLI Tools
- **bat** → cat (with syntax highlighting)
- **eza** → ls (with icons and git integration)
- **ripgrep** → grep (faster and more intuitive)
- **fd** → find (simpler and faster)
- **sd** → sed (intuitive find and replace)
- **dust** → du (better disk usage)
- **bottom** → top/htop (resource monitor)
- **zoxide** → cd (smarter directory navigation)
- **delta** → diff (better git diffs)
- **mcfly** → ctrl-r (intelligent command history)
- **gh** → GitHub CLI for PRs, issues, repos
- **glow** → Terminal markdown renderer
- **rich-cli** → Pretty print anything
- **frogmouth** → Terminal markdown viewer
- **textual** → Terminal UI framework

### AI/LLM Stack
- **Ollama**: Local LLM inference
- **vLLM**: High-performance inference server
- **llama.cpp**: CPU/GPU inference for GGUF models
- **LocalAI**: OpenAI-compatible API
- **Open WebUI**: Web interface for LLMs
- **Jupyter Lab**: ML experimentation environment

### Container Platforms
- **Docker**: Industry-standard containerization
- **Podman**: Rootless Docker alternative
- **Apptainer**: HPC/Scientific computing containers

## 🚀 Installation

### Complete One-Command Install

```bash
# Clone the repository
git clone https://github.com/fmschulz/arch-cyber-fsws.git
cd arch-cyber-fsws

# Run the complete installation (includes EVERYTHING)
chmod +x install.sh
./install.sh
```

**✨ One Script - Complete Setup!** The install.sh includes:
- ✅ Hyprland & Wayland components
- ✅ Modern CLI tools (50+ replacements)
- ✅ DuckDB database engine
- ✅ SDDM login manager with cyberpunk theme
- ✅ Audio system with conflict resolution
- ✅ Container platforms (Docker, Podman)
- ✅ Python TUI tools via pipx
- ✅ Tailscale VPN
- ✅ AI/LLM tools (Ollama)
- ✅ Gaming stack (GPU drivers + Vulkan + Steam)
- ✅ All configurations and themes

No additional scripts needed!

## ⌨️ Key Bindings

### Essential Shortcuts

| Key Combination | Action |
|-----------------|--------|
| `Super + Return` | Open Terminal |
| `Super + Space` / `Super + D` | App Launcher |
| `Super + Q` | Close Window |
| `Super + Shift + Q` | Exit Hyprland |
| `Super + F` | Fullscreen |
| `Super + V` | Toggle Floating |
| `Super + [1-9]` | Switch Workspace |
| `Super + Shift + [1-9]` | Move to Workspace |

### Window Management

| Key Combination | Action |
|-----------------|--------|
| `Super + H/J/K/L` | Move Focus (Vim keys) |
| `Super + Up/Down` | Move Focus |
| `Super + Left/Right` | Switch Workspace (Prev/Next) |
| `Super + Shift + H/J/K/L` | Move Window |
| `Super + Ctrl + H/J/K/L` | Resize Window |
| `Super + Mouse` | Move/Resize Window |

### Media Controls

| Key | Action |
|-----|--------|
| `Volume Up/Down` | Adjust Volume |
| `Mute` | Toggle Mute |
| `Play/Pause` | Media Control |
| `Brightness Up/Down` | Adjust Brightness |

### Screenshots

| Key Combination | Action |
|-----------------|--------|
| `Print` | Screenshot Area to Clipboard |
| `Shift + Print` | Full Screenshot to Clipboard |
| `Super + Print` | Screenshot Area to File |

## 🎨 Customization

### Changing Colors

Edit the color variables in:
- `config/hypr/hyprland.conf` - Window borders and effects
- `config/waybar/style.css` - Status bar colors
- `config/rofi/launchers/nexus.rasi` - App launcher theme

### Adding Wallpapers

1. Place wallpapers in `~/Pictures/Wallpapers/`
2. Edit `~/.config/hypr/hyprpaper.conf`:
```conf
preload = ~/Pictures/Wallpapers/your-wallpaper.jpg
wallpaper = ,~/Pictures/Wallpapers/your-wallpaper.jpg
```

### Waybar Modules

Customize modules in `config/waybar/config` (JSON):
- Add/remove modules from the arrays
- Configure module settings
- Adjust positioning

## 🔧 Backup & Restore

### Create Backup
```bash
./backup.sh
```

### Restore from Backup
```bash
./restore.sh
```

## 🔄 Weekly Update Notifications (optional)

Notify-only workflow (recommended): checks weekly and on terminal open if the system hasn’t been updated for 7 days, then sends a desktop notification.

Requirements:
- `pacman-contrib` (for `checkupdates`)
- `libnotify` + a notification daemon (e.g., `dunst`) for desktop toast

Components:
- `scripts/update-notifier.sh` → installed to `~/.local/bin/update-notifier.sh` by `restore.sh`
- User units: `systemd/user/update-notifier.service`, `systemd/user/update-notifier.timer`
- System units (optional, root): `systemd/weekly-system-update.service`, `systemd/weekly-system-update.timer`

Enable weekly notifications (user-level, no sudo):

```bash
# Ensure the script exists
[[ -x ~/.local/bin/update-notifier.sh ]] || cp scripts/update-notifier.sh ~/.local/bin/update-notifier.sh && chmod +x ~/.local/bin/update-notifier.sh

# Install user units
mkdir -p ~/.config/systemd/user
cp systemd/user/update-notifier.* ~/.config/systemd/user/

# Enable timer in user session
systemctl --user daemon-reload
systemctl --user enable --now update-notifier.timer

# Inspect logs
journalctl --user -u update-notifier.service
```

Enable weekly notifications (system-wide, requires sudo):

```bash
sudo install -m 0755 scripts/update-notifier.sh /usr/local/sbin/update-notifier.sh
sudo cp systemd/weekly-system-update.service /etc/systemd/system/
sudo cp systemd/weekly-system-update.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now weekly-system-update.timer

# Inspect logs
journalctl -u weekly-system-update.service
```

Terminal-open notifications:
- Bash startup (`config/shell/bashrc`) invokes `~/.local/bin/update-notifier.sh` for interactive shells with a 12h minimum interval when the last update is ≥ 7 days.

## 📁 Project Structure

```
arch-cyber-fsws/
├── config/
│   ├── hypr/           # Hyprland configuration
│   ├── waybar/         # Status bar config & scripts
│   ├── rofi/           # App launcher themes
│   ├── shell/          # Shell templates (e.g., bashrc)
│   └── starship.toml   # Shell prompt config
├── scripts/
│   ├── hardware-control.sh  # RGB & cooling management
│   ├── manage-llm.sh        # AI/LLM Docker management
│   ├── rich-utils.py        # Terminal utilities
│   ├── setup-betterfox.sh   # Firefox optimization
│   └── setup-slurm-tailscale.sh # Minimal Slurm + Tailscale setup (Arch)
├── docker/
│   └── llm-stack.yml   # AI services compose file
├── docs/
│   └── cluster-setup.md # Slurm + Tailscale detailed guide
├── install.sh          # Complete unified installer
├── backup.sh           # Configuration backup
├── restore.sh          # Configuration restore
└── README.md           # This file
```

## 🐛 Troubleshooting

### Common Issues

**Waybar not showing:**
```bash
killall waybar
waybar &
```

**Screen tearing:**
- Enable VRR in `hyprland.conf`
- Check GPU drivers

## 🧬 HPC: Slurm + Tailscale

This repo includes a minimal Slurm setup (no accounting by default) with Tailscale SSH for easy multi-node clusters.

Quick start (Arch Linux, requires sudo):

```bash
# Controller node
sudo ./scripts/setup-slurm-tailscale.sh \
  --role controller \
  --cluster-name fsnet \
  --hostname <controller-hostname> \
  --tags tag:slurm-controller,tag:slurm-node \
  --authkey tskey-XXXXXXXXXXXXXXXX

# Worker node(s)
sudo ./scripts/setup-slurm-tailscale.sh \
  --role node \
  --cluster-name fsnet \
  --controller <controller-hostname> \
  --hostname <node-hostname> \
  --tags tag:slurm-node \
  --authkey tskey-XXXXXXXXXXXXXXXX
```

Verify:
- `sinfo` shows nodes and partitions
- `srun -N1 hostname` returns a node hostname
- `systemctl status slurmctld` (controller) and `systemctl status slurmd` (nodes) are active

Accounting (optional): See `docs/cluster-setup.md` for enabling MariaDB and `slurmdbd`.

Full guide and networking rules: `docs/cluster-setup.md`.

**Bluetooth not working:**
```bash
sudo systemctl enable --now bluetooth
```

**App launcher not opening:**
- Ensure `rofi-wayland` is installed
- Check keybinding in `hyprland.conf`

## 📚 Resources

- [Hyprland Wiki](https://wiki.hyprland.org/)
- [Waybar Documentation](https://github.com/Alexays/Waybar/wiki)
- [Rofi Themes](https://github.com/adi1090x/rofi)
- [Arch Wiki](https://wiki.archlinux.org/)

## 🤝 Contributing

Feel free to submit issues and pull requests to improve this configuration!

## 🤖 AI/LLM Management

### Start LLM Services
```bash
./scripts/manage-llm.sh start        # Start all services
./scripts/manage-llm.sh start ollama # Start specific service
```

### Pull Models
```bash
./scripts/manage-llm.sh pull-model llama2
./scripts/manage-llm.sh pull-model mistral
./scripts/manage-llm.sh list-models
```

### Access Web Interfaces
- **Ollama API**: http://localhost:11434
- **vLLM API**: http://localhost:8000
- **LocalAI**: http://localhost:8080
- **Text Gen WebUI**: http://localhost:7860
- **Open WebUI**: http://localhost:3000
- **Jupyter Lab**: http://localhost:8888 (token: nexus2024)

## 🌈 Hardware Control

### RGB Lighting Control
```bash
./scripts/hardware-control.sh rgb nexus      # Cyberpunk theme
./scripts/hardware-control.sh rgb rainbow    # Rainbow effect
./scripts/hardware-control.sh rgb static b967ff  # Static purple
```

### Cooling Management
```bash
./scripts/hardware-control.sh fan performance  # Max cooling
./scripts/hardware-control.sh fan balanced     # Balanced mode
./scripts/hardware-control.sh fan silent       # Quiet operation
./scripts/hardware-control.sh pump 75          # Set pump to 75%
```

### Presets
```bash
./scripts/hardware-control.sh preset gaming    # Gaming mode
./scripts/hardware-control.sh preset quiet     # Silent mode
./scripts/hardware-control.sh preset work      # Productivity
./scripts/hardware-control.sh monitor          # Real-time monitoring
```

## 🎮 Gaming & GPU Setup

Use the helper to detect your GPU, install the right drivers/Vulkan stack, and validate Steam readiness.

```bash
# Detect vendor (nvidia | amd | intel)
./scripts/setup-gaming.sh detect

# Install vendor drivers + Vulkan + 32-bit multilib support
./scripts/setup-gaming.sh install-drivers

# Install Steam, Gamescope, Gamemode, MangoHud
./scripts/setup-gaming.sh install-steam

# Run Vulkan tests (vulkaninfo summary + vkcube)
./scripts/setup-gaming.sh test-vulkan

# Smoke test Steam startup (GUI)
./scripts/setup-gaming.sh test-steam
```

Notes:
- This script enables the pacman multilib repo (required for Steam/lib32) and logs to `logs/`.
- Hyprland has VRR enabled by default (`vrr = 1` in `config/hypr/hyprland.conf`).
- Gamemode user service is enabled for auto optimizations.

## 🔧 Modern CLI Aliases

After installation, these aliases are available:

```bash
# File operations
ls → eza          # Better ls with icons
ll → eza -l       # Long format with details
cat → bat         # Syntax highlighting
find → fd         # Faster, simpler find
grep → rg         # Ripgrep - faster grep

# System monitoring
top → btm         # Better resource monitor
ps → procs        # Modern process viewer
du → dust         # Visual disk usage
df → duf          # Better df output

# Development
diff → delta      # Better diffs
cd → z           # Smart directory jumping
curl → curlie    # Better curl with colors

# Container management
d → docker       # Docker shortcut
dc → docker-compose
lzd → lazydocker # Docker TUI
pod → podman     # Podman shortcut

# Git & GitHub
lg → lazygit     # Git TUI
gui → gitui      # Alternative Git TUI
gh-pr → gh pr create  # Create PR
gh-issues → gh issue list  # List issues

# Rich Terminal Tools
md → frogmouth   # Markdown viewer
json → rich      # Pretty JSON
browse → browsr  # File browser TUI
api → posting    # API testing TUI
chat → elia      # ChatGPT TUI
```

## 🎨 Rich Terminal Utilities

Enhanced terminal experience with the `rich-utils` command:

```bash
# System information dashboard
./scripts/rich-utils.py sysinfo

# Live system monitoring
./scripts/rich-utils.py monitor

# View files with syntax highlighting
./scripts/rich-utils.py view file.py

# Display directory tree
./scripts/rich-utils.py tree

# Run commands with progress display
./scripts/rich-utils.py run "command1" "command2"

# Display NEXUS color palette
./scripts/rich-utils.py colors
```

## 🔐 Tailscale VPN

After installation, authenticate Tailscale:
```bash
sudo tailscale up
```

Access your machines securely from anywhere with Tailscale's mesh VPN.

## 📜 License

This configuration is open source and available under the MIT License.

---

**Enjoy your futuristic Hyprland experience with modern tools and AI capabilities!** 🚀
