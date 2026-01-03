-- Remote SSH development plugin
-- Connect to remote servers and work with LSP over SSH

return {
  -- Remote SSH - VS Code-like remote development
  {
    "nosduco/remote-sshfs.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    opts = {
      connections = {
        ssh_configs = {
          -- Automatically load hosts from ~/.ssh/config
          vim.fn.expand("~/.ssh/config"),
        },
        -- Pre-configured hosts (add your servers here)
        sshfs_args = {
          "-o reconnect",
          "-o ConnectTimeout=5",
        },
      },
      mounts = {
        base_dir = vim.fn.expand("~/.sshfs/"),
        unmount_on_exit = true,
      },
      handlers = {
        on_connect = {
          change_dir = true,
        },
        on_disconnect = {
          clean_mount_folders = false,
        },
        on_edit = {},
      },
      ui = {
        select_prompts = false,
        confirm = {
          connect = true,
          change_dir = false,
        },
      },
      log = {
        enable = false,
        truncate = false,
        types = {
          all = false,
          util = false,
          handler = false,
          sshfs = false,
        },
      },
    },
    config = function(_, opts)
      require("remote-sshfs").setup(opts)
      require("telescope").load_extension("remote-sshfs")
    end,
    keys = {
      { "<leader>rc", "<cmd>lua require('remote-sshfs.api').connect()<cr>", desc = "SSH Connect" },
      { "<leader>rd", "<cmd>lua require('remote-sshfs.api').disconnect()<cr>", desc = "SSH Disconnect" },
      { "<leader>re", "<cmd>lua require('remote-sshfs.api').edit()<cr>", desc = "SSH Edit Config" },
      { "<leader>rf", "<cmd>Telescope remote-sshfs find_files<cr>", desc = "SSH Find Files" },
      { "<leader>rg", "<cmd>Telescope remote-sshfs live_grep<cr>", desc = "SSH Live Grep" },
      { "<leader>rs", "<cmd>Telescope remote-sshfs ssh_hosts<cr>", desc = "SSH Select Host" },
    },
  },

  -- Which-key integration for remote commands
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>r", group = "remote/ssh", icon = "󰣀" },
      },
    },
  },
}
