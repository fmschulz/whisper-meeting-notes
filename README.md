# Neo‑Brutalist Arch Hyprland Setup

Automates a full Arch Linux desktop install (Hyprland + Waybar + Kitty + Wofi + PipeWire + greetd/ReGreet), and tracks the dotfiles in `configs/` so you can re-apply them or back them up to GitHub.

## Quick Start

Full install (packages + configs + services):
```bash
chmod +x setup.sh
./setup.sh
```

Config-only (no package installs):
```bash
chmod +x apply-configs.sh
./apply-configs.sh
```

Minimal dependencies only (for `apply-configs.sh`):
```bash
chmod +x install-prereqs.sh
./install-prereqs.sh
```

## How Config Sync Works

`./apply-configs.sh` syncs each top-level folder in `configs/` into `~/.config/<name>/` (and `configs/applications/` into `~/.local/share/applications/`) using `rsync`. Re-running it is expected and will overwrite tracked config files.

## Neovim

This repo tracks a Kickstart-based Neovim config in `configs/nvim/`. After `./apply-configs.sh`:
```bash
nvim
```

Notes:
- First start installs plugins via `lazy.nvim`.
- File tree: `<Space>e` (Neo-tree). File browser: `<Space>pv` (`:Oil`).

If you modify `~/.config/nvim` and want to sync it back into the repo:
```bash
./scripts/sync-nvim-to-repo.sh
```

## Repo Layout

- `setup.sh`: end-to-end provisioning (packages + configs + services).
- `apply-configs.sh`: rsyncs repo-tracked configs into `~/.config` and `~/.local/share/applications`.
- `install-prereqs.sh`: minimal packages needed for `apply-configs.sh`.
- `scripts/setup/`: privileged one-off system setup helpers (greetd/ReGreet, sleep tuning, etc.).
- `configs/`: tracked dotfiles (Hyprland, Waybar, Kitty, Neovim, PipeWire, systemd user units, scripts, …).
- `packages/`: package manifests (`pacman-*.txt`, `aur-*.txt`).
- `docs/`: troubleshooting, keybindings, Neovim notes.
- `wallpapers/`: curated wallpapers (kept reasonably small; avoid adding huge media blobs).

Tracked config folders (high level):
- `configs/hypr/`, `configs/waybar/`, `configs/kitty/`, `configs/wofi/`, `configs/mako/`
- `configs/nvim/` (Kickstart-based Neovim)
- `configs/pipewire/` (PipeWire/WirePlumber tweaks)
- `configs/kanshi/` (multi-monitor profiles)
- `configs/systemd/user/` (user services/timers)
- `configs/scripts/` (launcher + maintenance scripts)
- `configs/applications/` (desktop entry overrides)

## Sync From NixOS (optional)

If you maintain the “source of truth” on NixOS/Home‑Manager:
```bash
chmod +x sync-from-nixos.sh
./sync-from-nixos.sh
```

## Maintenance (systemd timers)

Some maintenance is implemented as user services/timers under `configs/systemd/user/`. After applying configs you can inspect:
```bash
systemctl --user list-timers
```

## Large Files

This repo intentionally avoids committing big binary blobs (AppImages, ISOs, videos, archives). `wallpapers/` is kept, but wallpapers should stay reasonably small.
