# WSU Workstation Setup (Ubuntu 22.04)

This branch (`wsu`) represents the System76 Thelio Mega workstation running Ubuntu 22.04.5 LTS. It tracks the shared CLI/tooling configs plus workstation-specific notes for GPUs and Ubuntu setup.

## Quick Start (WSU)

1. **Clone and switch to the workstation branch**
   ```bash
   git clone <repo-url> controlcenter
   cd controlcenter
   git checkout wsu
   ```

2. **Apply shared configs (CLI tooling + dotfiles)**
   ```bash
   ./apply-configs.sh
   ```
   This copies tool configs (Git, Neovim, Claude/Codex/Opencode) and wallpapers. Hyprland configs are present but unused on GNOME.

3. **Sync local changes back to the repo (optional)**
   ```bash
   ./sync-to-repo.sh
   ```

## Ubuntu-Specific Setup

### GPU Drivers + CUDA
- Check recommended drivers:
  ```bash
  ubuntu-drivers devices
  ```
- Verify GPU stack:
  ```bash
  nvidia-smi
  nvidia-smi -L
  ```
- Pin jobs to specific GPUs when running multi-GPU workloads:
  ```bash
  CUDA_VISIBLE_DEVICES=0 <command>
  ```

### Notes
- `setup.sh` and `install-prereqs.sh` are Arch-only; do not use them on Ubuntu.
- GNOME is the default desktop on this machine; Hyprland configs are kept for cross-machine parity.

### Terminal Tooling Parity (fw13 baseline)
These are the shared terminal tools expected by the configs in this repo:

- Core CLI: `git`, `curl`, `wget`, `jq`, `yq`, `ripgrep`, `fzf`, `fd`, `bat`, `eza`
- Shell UX: `starship`, `zoxide`, `atuin`
- Git helpers: `git-delta`, `lazygit`, `gh`
- TUI tools: `yazi`, `btop`, `fastfetch`
- Utilities: `tldr` (tealdeer), `fd`, `rg`, `just`

Ubuntu install notes (use apt where available, otherwise install from upstream releases or `cargo`):
```bash
sudo apt update
sudo apt install -y git curl wget jq ripgrep fzf fd-find bat btop gh

# Ubuntu provides fdfind/batcat; add symlinks for expected command names.
mkdir -p ~/.local/bin
ln -sf "$(command -v fdfind)" ~/.local/bin/fd
ln -sf "$(command -v batcat)" ~/.local/bin/bat

# Rust-based tools not in apt for 22.04 (pick what you need).
cargo install eza zoxide starship atuin git-delta tealdeer just yazi-fm yazi-cli
```

## Machine Documentation

- `AGENTS.md` captures branch intent and workstation notes.
- `SYSTEM-SPECS.md` lists detailed hardware and GPU stack info.

---
*This branch represents the WSU workstation setup. Base configs are inherited from `main`.*
