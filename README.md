# Controlcenter

Central repo for syncing Linux configs across machines with machine-specific branches.

## How This Repo Is Organized

- `main` = shared, machine-agnostic settings only.
- Machine branches (`fw13`, `fw12`, `wsu`, `wsa`) layer device/OS-specific changes on top.

This keeps hardware- or OS-specific files out of `main` while still letting us share common tooling and defaults.

## What Belongs in `main`

Only configs that are truly portable across machines, for example:

- Shared terminal tooling config (e.g., `configs/kitty`, `configs/starship`)
- Editor/CLI defaults that apply everywhere
- Common scripts that don’t depend on OS/hardware paths
- Shared skill/config folders (e.g., `configs/claude`, `configs/codex`, `configs/opencode`)
- Wallpapers (optional)

Anything tied to a specific OS, GPU, monitor layout, or device goes into the machine branch.

## Chezmoi (Recommended)

If using `chezmoi`, set this repo as the source and check out the branch matching the machine.

## Workflow

- Make shared changes on `main`.
- Make machine-specific changes on the matching branch.
- Periodically rebase machine branches onto `main`.

See `AGENTS.md` for full rules and branch guidance.
