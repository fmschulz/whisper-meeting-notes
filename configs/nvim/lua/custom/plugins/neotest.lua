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
