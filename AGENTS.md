# Repository Guidelines (Base Branch)

This `main` branch contains shared configuration and scripts used by all machines. Each machine has its own branch that layers machine-specific changes on top of `main`.

### Branch Structure
| Branch | Machine | OS | Description |
|--------|---------|-----|-------------|
| `main` | - | - | Base configs, shared across all machines |
| `fw13` | Framework 13 (AMD 7840U) | Arch Linux | Primary laptop |
| `fw12` | Framework 12 | Arch Linux | Secondary laptop |
| `wsu` | Workstation | Ubuntu | Ubuntu workstation |
| `wsa` | Workstation | Arch Linux | Arch workstation |

### Workflow for AI Agents
1. **Understand Machine context**: Always check `AGENTS.md` and `SYSTEM-SPECS.md` to know which machine and OS you are on.
2. **Base changes**: If a change applies to ALL machines (e.g., a new common alias), commit it to `main`.
3. **Machine-specific changes**: If a change is specific to hardware or OS (e.g., Ubuntu paths, specific GPU drivers), commit it to the respective machine branch.
4. **Synchronization**: Periodically rebase machine branches onto `main` to pull in shared updates.
5. **Deployment**: Use `./apply-configs.sh` to sync repository configs to the system.
6. **GitHub Interaction**: ALWAYS use the GitHub CLI (`gh`) for authentication and repository operations. Run `gh auth setup-git` to ensure git uses `gh` for credential management. This avoids SSH key issues and ensures smooth interaction across machines.

### Server Operations (Jupyter/Voila + Cloudflare)
- Follow `docs/servers.md` and `docs/notebooks-cloudflare.md` for the canonical setup.
- Jupyter/Voila runs from `notebooks/` via Pixi; launch with:
  - `./notebooks/scripts/run_lab.sh` (JupyterLab)
  - `./notebooks/scripts/run_voila.sh` (Voila)
- Cloudflare Tunnel is managed via `~/.cloudflared/config.yml` and started with:
  - `TUNNEL_NAME=nelli-notebooks ./notebooks/scripts/run_tunnel.sh`
- Access login is Google-based; allowlist is email-based (currently `fmschulz@gmail.com`).
- Jupyter root is `~/dev` by default; override with `JUPYTER_ROOT=/path`.
- Logs:
  - Jupyter: `notebooks/logs/jupyter.log`
  - Voila: `notebooks/logs/voila.log`
  - Tunnel: `~/.cloudflared/nelli-notebooks.log`

## Project Structure
```
├── configs/           # Application configurations
│   ├── bash/         # Shell config (bashrc)
│   ├── hypr/         # Hyprland compositor
│   ├── kitty/        # Terminal + themes
│   ├── waybar/       # Status bar
│   ├── git/          # Git config with delta
│   ├── cargo/        # Rust build config (mold + sccache)
│   ├── claude/       # Claude Code skills, plugins, and settings
│   ├── codex/        # Codex configuration and skills
│   ├── opencode/     # Opencode tool settings
│   └── scripts/      # Helper scripts
├── packages/          # Package lists (pacman/aur)
└── scripts/setup/     # System provisioning scripts (Arch-specific)
```

## Branch + Chezmoi Notes
- Each machine maps to its own git branch.
- Keep machine branches rebased on `main`; do not merge machine branches into each other.
- If using `chezmoi`, set the source to this repo and keep the checked-out branch aligned with the target machine.

## Base Workflow
```bash
# Update base configs
git fetch origin main
git rebase origin/main

# Apply shared configs (machine branches may add extra steps)
./apply-configs.sh
```

---
*This branch is the shared base for machine-specific branches.*
