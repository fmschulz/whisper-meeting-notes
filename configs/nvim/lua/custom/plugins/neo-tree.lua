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
