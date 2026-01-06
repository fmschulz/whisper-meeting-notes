# Controlcenter Configs

Shared Linux configuration repo with machine-specific branches layered on top of `main`.

## Branches

- `main`: shared configs and scripts
- `fw13`: Framework 13 (Arch)
- `fw12`: Framework 12 (Arch)
- `wsu`: Ubuntu workstation
- `wsa`: Arch workstation

## Quick Start

Apply tracked configs (no package installs):
```bash
./apply-configs.sh
```

Install minimal deps required by `apply-configs.sh`:
```bash
./install-prereqs.sh
```

Provision a full Arch setup (packages + configs + services):
```bash
./setup.sh
```

## Repo Layout

- `configs/`: dotfiles (Hyprland, Waybar, Kitty, Bash, Git, etc.)
- `packages/`: package manifests (pacman/aur and machine-specific lists)
- `scripts/`: helpers and provisioning scripts (`scripts/setup/` for privileged tasks)
- `docs/`: notes and troubleshooting
- `wallpapers/`: curated wallpapers

See `AGENTS.md` for workflow rules and branch guidance.
