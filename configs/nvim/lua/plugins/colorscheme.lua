-- Colorscheme configuration
-- Neo-brutalist inspired with modern aesthetics

return {
  -- Catppuccin - elegant and modern
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "mocha", -- latte, frappe, macchiato, mocha
      background = {
        light = "latte",
        dark = "mocha",
      },
      transparent_background = false,
      term_colors = true,
      styles = {
        comments = { "italic" },
        conditionals = { "italic" },
        functions = { "bold" },
        keywords = { "bold" },
      },
      color_overrides = {
        mocha = {
          -- Neo-brutalist accent colors
          yellow = "#FFBE0B",   -- Primary yellow
          peach = "#FB5607",    -- Orange
          pink = "#FF006E",     -- Pink/Magenta
          blue = "#3A86FF",     -- Blue
          green = "#06FFA5",    -- Mint green
        },
      },
      integrations = {
        cmp = true,
        gitsigns = true,
        nvimtree = true,
        telescope = true,
        treesitter = true,
        notify = true,
        mini = true,
        native_lsp = {
          enabled = true,
          underlines = {
            errors = { "undercurl" },
            hints = { "undercurl" },
            warnings = { "undercurl" },
            information = { "undercurl" },
          },
        },
        indent_blankline = {
          enabled = true,
          colored_indent_levels = false,
        },
        which_key = true,
        mason = true,
        noice = true,
        lsp_trouble = true,
        dashboard = true,
      },
    },
  },

  -- Tokyo Night - clean and modern
  {
    "folke/tokyonight.nvim",
    priority = 1000,
    opts = {
      style = "night",
      transparent = false,
      terminal_colors = true,
      styles = {
        comments = { italic = true },
        keywords = { bold = true },
        functions = { bold = true },
      },
      on_colors = function(colors)
        -- Neo-brutalist accents
        colors.hint = "#06FFA5"
        colors.warning = "#FFBE0B"
        colors.error = "#FF006E"
        colors.info = "#3A86FF"
      end,
    },
  },

  -- Set default colorscheme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
}
