# Neovim (Kickstart Modular) Setup

This follows the approach from:
- `https://gauranshmathur.site/a-fully-fledged-neovim-setup/`
- base config: `https://github.com/dam9000/kickstart-modular.nvim`

This repo also tracks the resulting Neovim config in `configs/nvim/` so it can be applied/backed up like the other dotfiles.

## Install (Arch)

`neovim` is included in `packages/pacman-packages.txt`.

If you want to install manually:
```bash
sudo pacman -S --needed neovim git ripgrep fd unzip gcc make wl-clipboard
```

## Apply the repo-tracked config

Run:
```bash
./apply-configs.sh
nvim
```

The first `nvim` start will install plugins via `lazy.nvim`.

## (Optional) Re-generate from upstream Kickstart

If you want to re-create the config from upstream Kickstart and then version it here:

```bash
./scripts/setup/install-neovim-kickstart.sh --appname nvim --force
./scripts/sync-nvim-to-repo.sh
```

## File browser / file tree

- Oil (buffer-style file browser): `<Space>pv` or `:Oil`
- Neo-tree (sidebar file tree): `<Space>e`

## Treesitter note (important)

Kickstart expects the legacy `nvim-treesitter.configs` API. The installer pins `nvim-treesitter` to the `master` branch for compatibility.

## Login / language servers

Kickstart uses `lazy.nvim` for plugins and `mason.nvim` for installing LSP servers/tools.

Inside Neovim:
- `:Lazy` to see plugin status
- `:Mason` to install language servers (pick what you need, e.g. `lua_ls`, `pyright`, `rust_analyzer`, `ts_ls`)
