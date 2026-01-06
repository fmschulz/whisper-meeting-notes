#!/bin/bash
set -euo pipefail

step() {
  printf '▶ %s\n' "$1"
}

warn() {
  printf '⚠ %s\n' "$1" >&2
}

die() {
  printf '✖ %s\n' "$1" >&2
  exit 1
}

APPNAME="nvim-kickstart"
KEEP_GIT=0
FORCE=0

while (( $# )); do
  case "${1:-}" in
    --appname)
      shift
      APPNAME="${1:-}"
      ;;
    --keep-git)
      KEEP_GIT=1
      ;;
    --force)
      FORCE=1
      ;;
    --help|-h)
      cat <<EOF
Usage: $(basename "$0") [--appname NAME] [--keep-git] [--force]

Installs kickstart-modular.nvim into ~/.config/NAME (default: ${APPNAME})
and adds the plugins/keymaps referenced by:
  https://gauranshmathur.site/a-fully-fledged-neovim-setup/

Notes:
- Use --appname nvim to overwrite ~/.config/nvim (NOT recommended).
- Without --keep-git, the cloned repo's .git/ is removed so you can version your own dotfiles cleanly.
EOF
      exit 0
      ;;
    *)
      die "Unknown arg: $1 (use --help)"
      ;;
  esac
  shift || true
done

if [[ $EUID -eq 0 ]]; then
  die "Run as a regular user (not root)."
fi

if ! command -v git >/dev/null 2>&1; then
  die "git not found (install it first)."
fi

if ! command -v nvim >/dev/null 2>&1; then
  warn "nvim not found yet; installing config anyway (install 'neovim' to use it)."
fi

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/${APPNAME}"

if [[ -e "$CONFIG_DIR" ]]; then
  if (( FORCE )); then
    step "Removing existing config dir: $CONFIG_DIR"
    rm -rf "$CONFIG_DIR"
  else
    die "Config dir already exists: $CONFIG_DIR (use --force to replace)"
  fi
fi

step "Cloning kickstart-modular.nvim into $CONFIG_DIR"
git clone --depth 1 https://github.com/dam9000/kickstart-modular.nvim.git "$CONFIG_DIR"

if (( ! KEEP_GIT )); then
  step "Removing upstream .git so you can version your own config"
  rm -rf "$CONFIG_DIR/.git"
fi

step "Pinning nvim-treesitter to legacy API (compat with kickstart config)"
# Upstream nvim-treesitter has a new incompatible rewrite on the default branch.
# Kickstart expects the legacy `nvim-treesitter.configs` module, so pin to `master`.
if [[ -f "$CONFIG_DIR/lua/kickstart/plugins/treesitter.lua" ]]; then
  if ! rg -q "branch\\s*=\\s*'master'" "$CONFIG_DIR/lua/kickstart/plugins/treesitter.lua"; then
    sed -i "/'nvim-treesitter\\/nvim-treesitter',/a\\
    branch = 'master',\\
" "$CONFIG_DIR/lua/kickstart/plugins/treesitter.lua"
  fi
fi

step "Enabling custom plugin imports (lua/custom/plugins/*.lua)"
sed -i -E "s/^([[:space:]]*)--[[:space:]]*\\{[[:space:]]*import[[:space:]]*=[[:space:]]*'custom\\.plugins'[[:space:]]*\\},/\\1{ import = 'custom.plugins' },/" \
  "$CONFIG_DIR/lua/lazy-plugins.lua"

step "Adding plugins from the blog (oil/harpoon/fugitive/trouble/undotree/neogen/neotest)"
mkdir -p "$CONFIG_DIR/lua/custom/plugins" "$CONFIG_DIR/lua/custom"

cat >"$CONFIG_DIR/lua/custom/plugins/oil.lua" <<'LUA'
return {
  {
    'stevearc/oil.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {},
  },
}
LUA

cat >"$CONFIG_DIR/lua/custom/plugins/neo-tree.lua" <<'LUA'
return {
  {
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons',
      'MunifTanjim/nui.nvim',
    },
    opts = {
      filesystem = {
        filtered_items = { hide_dotfiles = false, hide_gitignored = true },
        follow_current_file = { enabled = true },
      },
      window = {
        position = 'left',
        width = 32,
        mappings = {
          ['<2-LeftMouse>'] = 'open',
        },
      },
    },
  },
}
LUA

cat >"$CONFIG_DIR/lua/custom/plugins/harpoon.lua" <<'LUA'
return {
  {
    'ThePrimeagen/harpoon',
    dependencies = { 'nvim-lua/plenary.nvim' },
  },
}
LUA

cat >"$CONFIG_DIR/lua/custom/plugins/fugitive.lua" <<'LUA'
return {
  { 'tpope/vim-fugitive' },
}
LUA

cat >"$CONFIG_DIR/lua/custom/plugins/trouble.lua" <<'LUA'
return {
  {
    'folke/trouble.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {},
  },
}
LUA

cat >"$CONFIG_DIR/lua/custom/plugins/undotree.lua" <<'LUA'
return {
  { 'mbbill/undotree' },
}
LUA

cat >"$CONFIG_DIR/lua/custom/plugins/neogen.lua" <<'LUA'
return {
  {
    'danymat/neogen',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    opts = {},
  },
}
LUA

cat >"$CONFIG_DIR/lua/custom/plugins/neotest.lua" <<'LUA'
return {
  {
    'nvim-neotest/neotest',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
      'nvim-neotest/nvim-nio',
      'nvim-neotest/neotest-python',
      'nvim-neotest/neotest-go',
    },
    config = function()
      local adapters = {}
      local ok_py, neotest_python = pcall(require, 'neotest-python')
      if ok_py then
        table.insert(adapters, neotest_python({}))
      end
      local ok_go, neotest_go = pcall(require, 'neotest-go')
      if ok_go then
        table.insert(adapters, neotest_go({}))
      end
      require('neotest').setup({ adapters = adapters })
    end,
  },
}
LUA

step "Adding keymaps (lua/custom/keymaps.lua) and loading them"
cat >"$CONFIG_DIR/lua/custom/keymaps.lua" <<'LUA'
-- Oil
vim.keymap.set('n', '<leader>pv', '<CMD>Oil<CR>', { desc = 'Oil: open parent directory' })

-- Neo-tree (file tree)
vim.keymap.set('n', '<leader>e', '<CMD>Neotree toggle<CR>', { desc = 'Neo-tree: toggle' })

-- Harpoon
local ok_mark, mark = pcall(require, 'harpoon.mark')
local ok_ui, ui = pcall(require, 'harpoon.ui')
if ok_mark and ok_ui then
  vim.keymap.set('n', '<leader>a', mark.add_file, { desc = 'Harpoon: add file' })
  vim.keymap.set('n', '<C-u>', ui.toggle_quick_menu, { desc = 'Harpoon: quick menu' })

  vim.keymap.set('n', '<C-j>', function() ui.nav_file(1) end, { desc = 'Harpoon: file 1' })
  vim.keymap.set('n', '<C-k>', function() ui.nav_file(2) end, { desc = 'Harpoon: file 2' })
  vim.keymap.set('n', '<C-l>', function() ui.nav_file(3) end, { desc = 'Harpoon: file 3' })
  vim.keymap.set('n', '<C-;>', function() ui.nav_file(4) end, { desc = 'Harpoon: file 4' })
end

-- UndoTree
vim.keymap.set('n', '<leader>u', vim.cmd.UndotreeToggle, { desc = 'UndoTree: toggle' })

-- Trouble
vim.keymap.set('n', '<leader>tt', function() require('trouble').toggle() end, { desc = 'Trouble: toggle' })
vim.keymap.set('n', '[t', function() require('trouble').next({ skip_groups = true, jump = true }) end, { desc = 'Trouble: next' })
vim.keymap.set('n', ']t', function() require('trouble').previous({ skip_groups = true, jump = true }) end, { desc = 'Trouble: prev' })

-- Neotest
vim.keymap.set('n', '<leader>tc', function() require('neotest').run.run() end, { desc = 'Neotest: run nearest' })
vim.keymap.set('n', '<leader>tf', function() require('neotest').run.run(vim.fn.expand('%')) end, { desc = 'Neotest: run file' })

-- Neogen
vim.keymap.set('n', '<leader>nf', function() require('neogen').generate({ type = 'func' }) end, { desc = 'Neogen: doc func' })
vim.keymap.set('n', '<leader>nt', function() require('neogen').generate({ type = 'type' }) end, { desc = 'Neogen: doc type' })

-- Fugitive
vim.keymap.set('n', '<leader>gs', '<CMD>Git<CR>', { desc = 'Git: status (Fugitive)' })
vim.keymap.set('n', '<leader>gp', '<CMD>Git push<CR>', { desc = 'Git: push' })
vim.keymap.set('n', '<leader>gP', '<CMD>Git pull --rebase<CR>', { desc = 'Git: pull --rebase' })
LUA

if ! grep -Fq "pcall(require, 'custom.keymaps')" "$CONFIG_DIR/lua/keymaps.lua"; then
  sed -i "/^-- vim: ts=2/ i\\
\\
-- Load custom keymaps (added by arch-hyprland-setup)\\
pcall(require, 'custom.keymaps')\\
" "$CONFIG_DIR/lua/keymaps.lua"
fi

step "Done"
cat <<EOF

Start with:
  NVIM_APPNAME='${APPNAME}' nvim

Then inside Neovim:
  :Lazy
  :Mason

If you later want this as your default:
  mv ~/.config/${APPNAME} ~/.config/nvim
EOF
