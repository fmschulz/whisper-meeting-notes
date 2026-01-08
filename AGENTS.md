# Repository Guidelines - dori (No-Sudo Machine)

## Machine Information

| Property | Value |
|----------|-------|
| **Branch** | `dori` |
| **Hostname** | TBD |
| **Hardware** | TBD |
| **CPU** | TBD |
| **GPU** | TBD |
| **RAM** | TBD |
| **Storage** | TBD |
| **OS** | TBD |
| **Desktop** | TBD |
| **Constraints** | No sudo access |

### Workflow for AI Agents
1. **Understand Machine context**: Always check `AGENTS.md` and `SYSTEM-SPECS.md` to know which machine and OS you are on.
2. **Base changes**: If a change applies to ALL machines (e.g., a new common alias), commit it to `main`.
3. **Machine-specific changes**: If a change is specific to hardware or OS (e.g., Ubuntu paths, specific GPU drivers), commit it to the respective machine branch.
4. **Synchronization**: Periodically rebase machine branches onto `main` to pull in shared updates.
5. **Deployment**: Use `./apply-configs.sh` to sync repository configs to the system.
6. **GitHub Interaction**: ALWAYS use the GitHub CLI (`gh`) for authentication and repository operations. Run `gh auth setup-git` to ensure git uses `gh` for credential management.

### Local Constraints
- **No sudo**: prefer user-level installs (cargo, pixi/conda, standalone binaries in `~/.local/bin`).
