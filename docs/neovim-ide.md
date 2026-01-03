# Neovim IDE Guide

A powerful LazyVim-based Neovim configuration with full IDE capabilities, SSH remote development, and a modern aesthetic design.

## Quick Start

```bash
# Install dependencies
sudo pacman -S neovim lazygit ripgrep fd sshfs

# Create symlink (setup.sh does this automatically)
ln -sf ~/arch-hyprland-setup/configs/nvim ~/.config/nvim

# Launch Neovim - plugins will auto-install on first run
nvim
```

## Key Features

- **Full IDE**: LSP, completion, syntax highlighting, diagnostics
- **Remote SSH**: VS Code-like remote development over SSH
- **Git Integration**: LazyGit, gitsigns, diff views
- **Fuzzy Finding**: Telescope for files, grep, symbols
- **Modern UI**: Catppuccin theme with neo-brutalist accents
- **Terminal**: Integrated terminal with lazygit and btop

---

## Essential Keybindings

### Leader Key: `<Space>`

### Navigation

| Key | Action |
|-----|--------|
| `<Space>ff` | Find files |
| `<Space>fg` | Live grep (search text) |
| `<Space>fb` | List buffers |
| `<Space>fr` | Recent files |
| `<Space>e` | Toggle file explorer (Neo-tree) |
| `<C-h/j/k/l>` | Navigate between windows |
| `<S-h>` / `<S-l>` | Previous/Next buffer |

### Code Actions (LSP)

| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `gr` | Go to references |
| `gI` | Go to implementation |
| `K` | Hover documentation |
| `<Space>ca` | Code actions |
| `<Space>cr` | Rename symbol |
| `<Space>cf` | Format code |
| `[d` / `]d` | Previous/Next diagnostic |
| `<Space>cd` | Show diagnostic float |

### Git

| Key | Action |
|-----|--------|
| `<Space>tg` | Open LazyGit |
| `<Space>gj` | Next hunk |
| `<Space>gk` | Previous hunk |
| `<Space>gs` | Stage hunk |
| `<Space>gr` | Reset hunk |
| `<Space>gp` | Preview hunk |
| `<Space>gb` | Blame line |

### SSH Remote Development

| Key | Action |
|-----|--------|
| `<Space>rc` | SSH Connect |
| `<Space>rd` | SSH Disconnect |
| `<Space>rs` | Select SSH Host |
| `<Space>rf` | SSH Find Files |
| `<Space>rg` | SSH Live Grep |
| `<Space>re` | Edit SSH Config |

### Terminal

| Key | Action |
|-----|--------|
| `<C-\>` | Toggle floating terminal |
| `<Space>tt` | Float terminal |
| `<Space>th` | Horizontal terminal |
| `<Space>tv` | Vertical terminal |
| `<Space>tg` | LazyGit |
| `<Space>tb` | btop |
| `<Esc><Esc>` | Exit terminal mode |

### File Explorer (Neo-tree)

| Key | Action |
|-----|--------|
| `<Space>e` | Toggle explorer |
| `<CR>` or `l` | Open file |
| `h` | Close folder |
| `v` | Open in vertical split |
| `s` | Open in horizontal split |
| `a` | Add file/folder |
| `d` | Delete |
| `r` | Rename |
| `c` | Copy |
| `m` | Move |
| `y` | Copy name |
| `Y` | Copy path |

### Windows & Buffers

| Key | Action |
|-----|--------|
| `<Space>w` | Save file |
| `<Space>q` | Quit |
| `<Space>bd` | Delete buffer |
| `<C-Up/Down>` | Resize height |
| `<C-Left/Right>` | Resize width |
| `<Space>-` | Split horizontal |
| `<Space>\|` | Split vertical |

### Editing

| Key | Action |
|-----|--------|
| `gcc` | Toggle line comment |
| `gc` (visual) | Toggle selection comment |
| `<A-j>` / `<A-k>` | Move line up/down |
| `<` / `>` (visual) | Indent left/right |
| `cs"'` | Change surrounding `"` to `'` |
| `ds"` | Delete surrounding `"` |
| `ysiw"` | Surround word with `"` |

### Search & Replace

| Key | Action |
|-----|--------|
| `<Space>sr` | Search and replace |
| `<Space>sw` | Search word under cursor |
| `<Space>st` | Search TODO comments |
| `<Esc>` | Clear search highlight |

---

## SSH Remote Development

Connect to remote servers and work with full LSP support over SSH.

### Setup

1. Add your hosts to `~/.ssh/config`:
   ```
   Host nelli
       HostName 100.115.144.119
       User fmschulz

   Host perlmutter
       HostName perlmutter.nersc.gov
       User fschulz
   ```

2. Connect in Neovim:
   - Press `<Space>rs` to select a host
   - Or `<Space>rc` to connect

3. Once connected:
   - `<Space>rf` - Find files on remote
   - `<Space>rg` - Search text on remote
   - LSP works automatically

### How It Works

- Uses SSHFS to mount remote directories locally
- LSP servers run on your local machine
- Files are edited over the SSHFS mount
- Changes are saved directly to the remote server

---

## Plugin Overview

### Core
- **LazyVim** - Base configuration and plugin management
- **lazy.nvim** - Fast plugin manager with lazy loading

### LSP & Completion
- **nvim-lspconfig** - LSP configuration
- **mason.nvim** - LSP/DAP/linter installer
- **nvim-cmp** - Completion engine
- **conform.nvim** - Formatting
- **nvim-lint** - Linting

### Editor
- **neo-tree.nvim** - File explorer
- **telescope.nvim** - Fuzzy finder
- **gitsigns.nvim** - Git integration
- **nvim-surround** - Surround text objects
- **nvim-autopairs** - Auto-close brackets
- **Comment.nvim** - Easy commenting
- **todo-comments.nvim** - Highlight TODOs

### UI
- **catppuccin** - Colorscheme
- **lualine.nvim** - Status line
- **bufferline.nvim** - Buffer tabs
- **noice.nvim** - Better UI for messages
- **nvim-notify** - Notifications
- **which-key.nvim** - Keybinding hints
- **dashboard-nvim** - Start screen

### Terminal & Remote
- **toggleterm.nvim** - Terminal integration
- **remote-sshfs.nvim** - SSH remote development

---

## Language Support

Pre-configured LSP servers for:

| Language | LSP Server | Formatter | Linter |
|----------|------------|-----------|--------|
| Python | pyright | black, ruff | ruff |
| Rust | rust-analyzer | rustfmt | - |
| Go | gopls | gofumpt | - |
| TypeScript | typescript-language-server | prettier | eslint |
| JavaScript | typescript-language-server | prettier | eslint |
| Lua | lua_ls | stylua | - |
| JSON | json-lsp | prettier | - |
| YAML | yaml-language-server | prettier | - |
| HTML/CSS | html-lsp, css-lsp | prettier | - |
| Docker | dockerfile-language-server | - | - |
| Bash | bash-language-server | shfmt | - |
| Markdown | marksman | prettier | markdownlint |

### Installing Additional LSP Servers

```vim
:Mason
```

Browse and install additional servers interactively.

---

## Customization

### Adding Plugins

Create a new file in `~/.config/nvim/lua/plugins/`:

```lua
-- ~/.config/nvim/lua/plugins/myplugin.lua
return {
  {
    "author/plugin-name",
    opts = {
      -- configuration
    },
  },
}
```

### Changing Colorscheme

Edit `~/.config/nvim/lua/plugins/colorscheme.lua`:

```lua
{
  "LazyVim/LazyVim",
  opts = {
    colorscheme = "tokyonight",  -- or "catppuccin"
  },
}
```

### Adding Keybindings

Edit `~/.config/nvim/lua/config/keymaps.lua`:

```lua
local map = vim.keymap.set
map("n", "<leader>xx", ":SomeCommand<CR>", { desc = "Description" })
```

---

## Tips & Tricks

### Quick Actions

- **Format file**: `<Space>cf`
- **Rename variable**: `<Space>cr` (works across files)
- **Find all references**: `gr`
- **Jump to definition**: `gd`
- **Show signature help**: `<C-k>` in insert mode

### Efficient Navigation

1. Use `<Space>ff` for files, not the tree
2. Use `<Space>fg` to search code
3. Use `<Space>fs` to jump to symbols
4. Use `gd` and `<C-o>` to jump and return

### Working with Git

1. `<Space>tg` opens LazyGit (full git UI)
2. Use `]c` and `[c` to jump between hunks
3. `<Space>gp` to preview a hunk before staging

### SSH Workflow

1. Open Neovim locally
2. `<Space>rs` to select and connect to server
3. Use `<Space>rf` to find files on remote
4. Edit with full LSP support
5. `<Space>rd` to disconnect when done

---

## Troubleshooting

### Plugins Not Loading
```vim
:Lazy sync
```

### LSP Not Working
```vim
:LspInfo
:Mason
```

### Check Health
```vim
:checkhealth
```

### Reset Configuration
```bash
rm -rf ~/.local/share/nvim
rm -rf ~/.local/state/nvim
rm -rf ~/.cache/nvim
nvim  # Reinstalls everything
```

---

## Resources

- [LazyVim Documentation](https://lazyvim.github.io/)
- [Neovim Documentation](https://neovim.io/doc/)
- [Catppuccin Theme](https://github.com/catppuccin/nvim)
- [Telescope Keymaps](https://github.com/nvim-telescope/telescope.nvim#default-mappings)
