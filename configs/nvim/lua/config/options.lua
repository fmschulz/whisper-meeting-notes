-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

local opt = vim.opt

-- General
opt.autowrite = true
opt.clipboard = "unnamedplus"  -- Sync with system clipboard
opt.confirm = true
opt.cursorline = true
opt.mouse = "a"
opt.number = true
opt.relativenumber = true
opt.scrolloff = 8
opt.signcolumn = "yes"
opt.termguicolors = true
opt.wrap = false

-- Indentation
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- Splits
opt.splitbelow = true
opt.splitright = true

-- Performance
opt.lazyredraw = false
opt.updatetime = 200
opt.timeoutlen = 300

-- Undo
opt.undofile = true
opt.undolevels = 10000

-- Completion
opt.completeopt = "menu,menuone,noselect"
opt.pumheight = 10

-- Kitty terminal compatibility
if vim.env.TERM == "xterm-kitty" then
  vim.cmd([[autocmd UIEnter * if v:event.chan ==# 0 | call chansend(v:stderr, "\x1b[>1u") | endif]])
  vim.cmd([[autocmd UILeave * if v:event.chan ==# 0 | call chansend(v:stderr, "\x1b[<1u") | endif]])
end

-- Enable undercurl in Kitty
vim.cmd([[let &t_Cs = "\e[4:3m"]])
vim.cmd([[let &t_Ce = "\e[4:0m"]])
