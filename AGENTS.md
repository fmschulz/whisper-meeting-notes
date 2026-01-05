# Repository Guidelines - fw13 (Framework Laptop 13)

## Machine Information

| Property | Value |
|----------|-------|
| **Branch** | `fw13` |
| **Hostname** | fsfw |
| **Hardware** | Framework Laptop 13 (AMD Ryzen 7040 Series) |
| **CPU** | AMD Ryzen 7 7840U (8 cores, 16 threads) |
| **GPU** | AMD Radeon 780M (integrated) |
| **RAM** | 96 GB DDR5 |
| **Storage** | 2 TB WD_BLACK SN850X NVMe |
| **OS** | Arch Linux (rolling) |
| **Desktop** | Hyprland (Wayland) |

## Machine-Specific Configuration

### Hardware Optimizations
- **Power Management**: Framework-optimized power profiles (power-saver on battery)
- **Display**: Variable Refresh Rate (VRR) enabled
- **Fingerprint**: fprintd enabled for login
- **Firmware**: fwupd enabled for BIOS updates

### GPU Configuration
```bash
# AMD GPU environment variables (in bashrc)
export LIBVA_DRIVER_NAME=radeonsi
export AMD_VULKAN_ICD=RADV
```

### Monitor Configuration
This laptop uses a single high-DPI display. External monitors are configured in `configs/hypr/hyprland.conf`.

## Branch Workflow

```bash
# Stay updated with base configs
git fetch origin main
git rebase origin/main

# Apply configs after pulling
./apply-configs.sh
# or with chezmoi:
chezmoi apply
```

### Branch + Chezmoi Notes
- Each machine maps to its own git branch (e.g., `fw13`, `wsu`).
- Keep machine branches rebased on `main`; do not merge machine branches into each other.
- If using `chezmoi`, set the source to this repo and keep the checked-out branch aligned with the target machine.

## Machine-Specific Files
- `SYSTEM-SPECS.md` - Detailed hardware specs
- `configs/hypr/hyprland.conf` - Monitor layout for this machine
- `packages/pacman-packages-amd.txt` - AMD-specific packages

## Tool Syncing (Claude, Codex, Opencode)
- Core configurations are tracked in `configs/claude/`, `configs/codex/`, and `configs/opencode/`.
- Machine-specific logs, credentials, and project-specific environments are ignored.
- Use `./apply-configs.sh` to deploy the common base of these tools to this machine.

## Testing on This Machine
```bash
# Reload Hyprland after config changes
~/.config/scripts/reload.sh

# Check system health
health

# Monitor power usage
powerprofilesctl list
powertop
```

---
*This branch contains configurations specific to the Framework 13 laptop (fw13).*
*Base configurations are inherited from the `main` branch.*
