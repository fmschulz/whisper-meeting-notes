# Modern Terminal Tools

This repo favors modern, cross-platform CLI tools. The shared bashrc maps common commands to these tools when they are installed.

## Core replacements

- `eza` → `ls`
- `bat` → `cat`
- `rg` (ripgrep) → `grep`
- `fd` → `find`
- `dust` → `du`
- `duf` → `df`
- `procs` → `ps`
- `btm` (bottom) → `top`/`htop`
- `sd` → `sed`

## Productivity tools

- `fzf`: fuzzy finder (pairs well with `rg`/`fd`)
- `zoxide`: smarter `cd`
- `atuin`: synced shell history + fuzzy search
- `starship`: fast, cross-shell prompt
- `direnv`: per-directory env loading
- `vivid`: better `LS_COLORS`
- `tealdeer` (`tldr`): concise man pages
- `just`: task runner
- `hyperfine`: benchmarking
- `tokei`: code stats

## Utility tools

- `ouch`: unified archive tool
- `hexyl`: hex viewer
- `xh`: HTTP client
- `choose`: fast field selector
- `grex`: regex generator

## Ubuntu notes

On Ubuntu, the packages are named `batcat` and `fdfind`. The shared bashrc maps them to `bat` and `fd` automatically.

## How this is wired

`configs/bash/bashrc` in `main` is a minimal shared bashrc that provides these aliases and integrations.
Machine branches can extend it via `~/.bashrc.local` or replace it entirely.
