# Repository Guidelines (Base Branch)

This `main` branch contains shared configuration and scripts used by all machines. Each machine has its own branch that layers machine-specific changes on top of `main`.

## Branch + Chezmoi Notes
- Each machine maps to its own git branch (e.g., `fw13`, `wsu`).
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
