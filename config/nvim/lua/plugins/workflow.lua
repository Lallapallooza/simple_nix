-- Workflow plugin specs.

return {
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = require "configs.trouble",
  },
  {
    "stevearc/overseer.nvim",
    cmd = { "OverseerRun", "OverseerToggle", "OverseerOpen", "OverseerClose" },
    opts = require "configs.overseer",
  },
  {
    "nvim-telescope/telescope-fzf-native.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    build = "make",
    cond = function()
      return vim.fn.executable "make" == 1
    end,
    config = function()
      local telescope = require "telescope"

      pcall(telescope.load_extension, "fzf")
    end,
  },
  {
    "nvim-telescope/telescope.nvim",
    opts = function(_, opts)
      local config = require "configs.telescope"
      opts.extensions = vim.tbl_deep_extend("force", opts.extensions or {}, config.extensions or {})
      return opts
    end,
  },
  {
    "rmagatti/auto-session",
    event = { "BufReadPre", "BufNewFile" },
    cmd = "AutoSession",
    opts = require "configs.auto_session",
  },
}
