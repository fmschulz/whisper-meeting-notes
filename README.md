# Controlcenter

Central repo for syncing Linux configs across machines with machine-specific branches.

## Branch Model

- `main`: shared, machine-agnostic settings only.
- Machine branches (`fw13`, `fw12`, `wsu`, `wsa`) layer device/OS-specific changes on top.

## What Belongs in `main`

Only configs that are portable across machines, for example:

- Shared terminal tooling config (e.g., `configs/kitty`, `configs/starship`)
- Editor/CLI defaults that apply everywhere
- Shared scripts that don’t depend on OS/hardware paths
- Shared skill/config folders (e.g., `configs/claude`, `configs/codex`, `configs/opencode`)
- Wallpapers (optional)

Anything tied to a specific OS, GPU, monitor layout, or device goes into the machine branch.

## Current State

`main` intentionally contains placeholders only. Populate shared configs later; machine branches carry the real settings.

## Chezmoi (Recommended)

If using `chezmoi`, set this repo as the source and check out the branch matching the machine.

## Workflow

- Make shared changes on `main`.
- Make machine-specific changes on the matching branch.
- Periodically rebase machine branches onto `main`.

See `AGENTS.md` for full rules and branch guidance.
