# Repository Guidelines

## Multi-Machine Dotfiles Repository

This repository manages dotfiles and system configurations across multiple machines using a branch-per-machine strategy with chezmoi integration.

### Branch Structure
| Branch | Machine | OS | Description |
|--------|---------|-----|-------------|
| `main` | - | - | Base configs, shared across all machines |
| `fw13` | Framework 13 (AMD 7840U) | Arch Linux | Primary laptop |
| `fw12` | Framework 12 | Arch Linux | Secondary laptop |
| `wsj` | Workstation | Ubuntu | Ubuntu workstation |
| `wsa` | Workstation | Arch Linux | Arch workstation |

### Workflow
1. **Base changes** go to `main` branch
2. **Machine-specific changes** go to respective machine branch
3. To update a machine: `git checkout <machine> && git rebase main`
4. Use chezmoi for applying configs: `chezmoi apply`

## Project Structure & Module Organization
Automation entrypoints sit at the repo root: `setup.sh` provisions a fresh Arch desktop, while `install-prereqs.sh`, `apply-configs.sh`, and `sync-from-nixos.sh` cover narrower flows. Desktop configs live under `configs/` (Hyprland, Waybar, Kitty, Starship, Yazi, Wofi, Mako, Bash) with filenames matching the upstream NixOS profile. Package manifests reside in `packages/aur-packages.txt` and `packages/pacman-packages.txt`; edit those lists before changing installer logic. Reference docs belong in `docs/`, wallpapers in `wallpapers/`, and helper assets in `scripts/` or `configs/scripts/` using lowercase, hyphenated names.

### Key Directories
```
├── configs/           # Application configurations
│   ├── bash/         # Shell config (bashrc)
│   ├── hypr/         # Hyprland compositor
│   ├── kitty/        # Terminal + themes
│   ├── waybar/       # Status bar
│   ├── git/          # Git config with delta
│   ├── cargo/        # Rust build config (mold + sccache)
│   └── scripts/      # Helper scripts
├── packages/          # Package lists (pacman/aur)
├── scripts/setup/     # System provisioning scripts
├── docs/              # Documentation
└── wallpapers/        # Wallpaper images
```

## Build, Test, and Development Commands
Run `./install-prereqs.sh` to prepare a minimal environment, then `./setup.sh` on clean Arch hosts for full provisioning. Use `./apply-configs.sh` to push updated dotfiles without reinstalling packages.

### Chezmoi Commands
```bash
chezmoi init              # Initialize chezmoi
chezmoi add <file>        # Add file to chezmoi management
chezmoi edit <file>       # Edit managed file
chezmoi diff              # Preview changes before applying
chezmoi apply             # Apply all managed configs
chezmoi update            # Pull and apply from remote
```

## Coding Style & Naming Conventions
Bash scripts start with `#!/bin/bash`, `set -e`, and verbose status output. Indent shell code with two spaces inside blocks, reuse the helper pattern found in `setup.sh`, and keep variable names descriptive (`SCRIPT_DIR`, `NEW_THEME`). Config files under `configs/hypr` and related directories rely on four-space indentation inside braces plus uppercase section headers; mirror that structure to keep diffs readable. Quote all paths defensively and avoid introducing trailing whitespace.

## Testing Guidelines
Before committing shell changes, run `bash -n` and `shellcheck` on each touched script. After updating configs, execute `./apply-configs.sh` or copy the file manually, then reload Hyprland via `~/.config/scripts/reload.sh`. Launch Waybar and Kitty directly to confirm they start cleanly, and monitor `journalctl --user -u pipewire` when adjusting audio or video settings. For package updates, dry-run `pacman -S --needed --print-format '%n' $(cat packages/pacman-packages.txt)` in a VM to catch typos.

## Commit & Pull Request Guidelines
Follow Conventional Commits (`feat:`, `fix:`, `chore:`) and keep each commit focused on a single logical change. Reference impacted paths (for example, `configs/hypr/monitors.conf`) in the commit body with a short rationale. When making machine-specific changes, commit to the appropriate branch. Highlight breaking changes and call out any manual follow-up such as service restarts or package removals.

## Security & Configuration Tips
Never embed secrets in tracked files; use local overrides or environment variables instead. Machine-specific secrets should use `~/.secrets` (sourced by bashrc but not tracked). Validate downloaded wallpapers and scripts before syncing to avoid distributing untrusted content.
