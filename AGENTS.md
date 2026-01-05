# Repository Guidelines - wsu (Workstation Ubuntu)

## Machine Information

| Property | Value |
|----------|-------|
| **Branch** | `wsu` |
| **Hostname** | jgi-ont |
| **Hardware** | System76 Thelio Mega |
| **CPU** | AMD Ryzen Threadripper PRO 5975WX (32 cores, 64 threads) |
| **GPU** | 2× NVIDIA RTX PRO 6000 Blackwell Max-Q + 1× NVIDIA RTX A6000 |
| **RAM** | 256 GB (251 GiB usable) |
| **Storage** | 4 TB NVMe + 9.1 TB HDD + 2× 27.3 TB HDD |
| **OS** | Ubuntu 22.04.5 LTS |
| **Desktop** | GNOME (Xorg) |

### Workflow for AI Agents
1. **Understand Machine context**: Always check `AGENTS.md` and `SYSTEM-SPECS.md` to know which machine and OS you are on.
2. **Base changes**: If a change applies to ALL machines (e.g., a new common alias), commit it to `main`.
3. **Machine-specific changes**: If a change is specific to hardware or OS (e.g., Ubuntu paths, specific GPU drivers), commit it to the respective machine branch.
4. **Synchronization**: Periodically rebase machine branches onto `main` to pull in shared updates.
5. **Deployment**: Use `./apply-configs.sh` to sync repository configs to the system.
6. **GitHub Interaction**: ALWAYS use the GitHub CLI (`gh`) for authentication and repository operations. Run `gh auth setup-git` to ensure git uses `gh` for credential management. This avoids SSH key issues and ensures smooth interaction across machines.

## Machine-Specific Configuration

### GPU Stack
- **Driver**: NVIDIA 580.95.05
- **CUDA**: 13.0
- **Multi-GPU**: Use `CUDA_VISIBLE_DEVICES` to pin jobs per GPU.

### Monitoring
- **CPU (64 threads)**: `btop` with per-core view (see `configs/btop/btop.conf`).
- **GPU (3 devices)**: `nvtop` for per-GPU utilization + memory.
- **CLI quick checks**: `nvidia-smi -L`, `watch -n 1 nvidia-smi`.

### Ubuntu Notes
- `setup.sh` and `install-prereqs.sh` are Arch-only. Use `apply-configs.sh` selectively for CLI tooling.
- GPU drivers are managed via `ubuntu-drivers` and the NVIDIA repository.

## Branch Workflow

```bash
# Stay updated with base configs
git fetch origin main
git rebase origin/main

# Apply configs after pulling (CLI tooling + configs)
./apply-configs.sh
```

### Branch + Chezmoi Notes
- Each machine maps to its own git branch (e.g., `fw13`, `wsu`).
- Keep machine branches rebased on `main`; do not merge machine branches into each other.
- If using `chezmoi`, set the source to this repo and keep the checked-out branch aligned with the target machine.

## Machine-Specific Files
- `SYSTEM-SPECS.md` - Detailed hardware specs

## Tool Syncing (Claude, Codex, Opencode)
- Core configurations are tracked in `configs/claude/`, `configs/codex/`, and `configs/opencode/`.
- Machine-specific logs, credentials, and project-specific environments are ignored.
- Use `./apply-configs.sh` to deploy the common base of these tools to this machine.

## Testing on This Machine
```bash
# Check GPU status
nvidia-smi

# Validate driver recommendations
ubuntu-drivers devices
```

---
*This branch contains configurations specific to the WSU workstation (Ubuntu).*
*Base configurations are inherited from the `main` branch.*
