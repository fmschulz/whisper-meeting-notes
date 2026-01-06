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
