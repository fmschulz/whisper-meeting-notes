# Dori Setup (No Sudo)

This branch (`dori`) represents a no-sudo Linux environment. It tracks shared CLI/tooling configs plus user-level install notes for modern command line tools.

## Quick Start (Dori)

1. **Clone and switch to the dori branch**
   ```bash
   git clone <repo-url> controlcenter
   cd controlcenter
   git checkout dori
   ```

2. **Apply shared configs (CLI tooling + dotfiles)**
   ```bash
   ./apply-configs.sh
   ```
   This copies tool configs (Git, Neovim, Claude/Codex/Opencode) and wallpapers.

3. **Install modern CLI tools (no sudo)**
   See `docs/dori-tools.md` and `packages/cargo-tools.txt`.

## Notes

- This machine does not have sudo; prefer user-level installs in `~/.local/bin` or `~/.cargo/bin`.
- Replace `~/.bashrc` with `configs/bash/bashrc` or source it from `.bashrc`.
