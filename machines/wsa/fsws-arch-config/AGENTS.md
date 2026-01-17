# Repository Guidelines

## Project Structure & Module Organization
- Root scripts: `install.sh`, `backup.sh`, `restore.sh`, utility scripts in `scripts/`.
- Desktop config: `config/` (Hyprland, Waybar, Rofi, Kitty, themes).
- LLM stack: `docker/llm-stack.yml` and helpers in `scripts/manage-llm.sh`.
- Device control: `thermalright-lcd-control/` (vendored project with its own Makefile/README).
- Docs and assets: `README.md`, `docs/`, logs in `logs/`.

## Build, Test, and Development Commands
- Run full setup: `./install.sh` (Arch Linux + Hyprland + tools). Requires `sudo`.
- Backup/restore configs: `./backup.sh` / `./restore.sh`.
- Manage LLM services: `./scripts/manage-llm.sh start|stop|pull-model <name>`.
- Compose LLM stack directly: `docker compose -f docker/llm-stack.yml up -d`.
- Reload configs during dev: `hyprctl reload` (after editing `config/hypr/*`), `killall waybar && waybar &` for Waybar.

## Coding Style & Naming Conventions
- Bash scripts: shebang `#!/bin/bash`, `set -euo pipefail` preferred; 4-space indent; functions `lower_snake_case`; constants UPPER_SNAKE_CASE.
- JSON/CSS/Conf: 2-space indent; trailing commas avoided; validate with `jq` where applicable.
- Filenames: kebab-case for scripts, e.g., `fix-case-fans.sh`; keep scripts executable.
- Linting/formatting: prefer `shellcheck` and `shfmt` (if available) before committing.

## Testing Guidelines
- Bash syntax check: `bash -n scripts/*.sh`.
- Static analysis: `shellcheck scripts/*.sh`.
- Waybar config check: `jq . config/waybar/config` (or `config.json` if present).
- Smoke test: apply targeted changes, then `hyprctl reload` and verify UI; attach screenshots for visual changes.

## Commit & Pull Request Guidelines
- Commits: concise, imperative mood (e.g., “Add Hyprland tweaks”, “Fix Waybar CPU module”). Group related changes.
- PRs must include:
  - Clear description of what/why; reference issues if applicable.
  - Affected paths (e.g., `config/waybar/*`, `scripts/*`).
  - Screenshots or recordings for visual/UI tweaks.
  - Manual test notes (commands run, environments tested).

## Security & Configuration Tips
- Avoid committing secrets, tokens, or machine-specific IDs. Use placeholders in examples.
- Prefer user-scoped configs; do not write to system paths unless required by `install.sh`.
- When touching `thermalright-lcd-control/`, follow its README/Makefile; do not diverge from upstream structure.
- Changes that require `sudo` must document why and the exact commands impacted.
