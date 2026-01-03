-- Terminal integration

return {
  -- Toggleterm - better terminal management
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    opts = {
      size = function(term)
        if term.direction == "horizontal" then
          return 15
        elseif term.direction == "vertical" then
          return vim.o.columns * 0.4
        end
      end,
      open_mapping = [[<c-\>]],
      hide_numbers = true,
      shade_terminals = true,
      shading_factor = 2,
      start_in_insert = true,
      insert_mappings = true,
      terminal_mappings = true,
      persist_size = true,
      persist_mode = true,
      direction = "float",
      close_on_exit = true,
      shell = vim.o.shell,
      float_opts = {
        border = "curved",
        winblend = 0,
      },
    },
    keys = {
      { "<C-\\>", "<cmd>ToggleTerm<cr>", desc = "Toggle Terminal" },
      { "<leader>tt", "<cmd>ToggleTerm direction=float<cr>", desc = "Float Terminal" },
      { "<leader>th", "<cmd>ToggleTerm direction=horizontal<cr>", desc = "Horizontal Terminal" },
      { "<leader>tv", "<cmd>ToggleTerm direction=vertical<cr>", desc = "Vertical Terminal" },
      { "<leader>tg", "<cmd>lua _LAZYGIT_TOGGLE()<cr>", desc = "LazyGit" },
      { "<leader>tb", "<cmd>lua _BTOP_TOGGLE()<cr>", desc = "btop" },
    },
    config = function(_, opts)
      require("toggleterm").setup(opts)

      -- Custom terminals
      local Terminal = require("toggleterm.terminal").Terminal

      -- LazyGit
      local lazygit = Terminal:new({
        cmd = "lazygit",
        dir = "git_dir",
        direction = "float",
        float_opts = {
          border = "curved",
        },
        on_open = function(term)
          vim.cmd("startinsert!")
          vim.api.nvim_buf_set_keymap(term.bufnr, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })
        end,
      })

      function _LAZYGIT_TOGGLE()
        lazygit:toggle()
      end

      -- btop
      local btop = Terminal:new({
        cmd = "btop",
        direction = "float",
        float_opts = {
          border = "curved",
        },
      })

      function _BTOP_TOGGLE()
        btop:toggle()
      end
    end,
  },

  -- Which-key integration
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>t", group = "terminal", icon = "" },
      },
    },
  },
}
