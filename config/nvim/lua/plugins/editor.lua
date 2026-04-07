-- Editing plugin specs.

return {
  {
    "stevearc/conform.nvim",
    opts = require "configs.conform",
  },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = require "configs.gitsigns",
  },
  {
    "nvim-treesitter/nvim-treesitter",
    config = function()
      local cfg = require "configs.treesitter"
      require("nvim-treesitter").setup { highlight = cfg.highlight }
      -- v2 dropped ensure_installed; install() is async and a no-op
      -- for already-installed parsers.
      require("nvim-treesitter").install(cfg.install)
    end,
  },
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = require "configs.flash",
    keys = {
      {
        "s",
        mode = { "n", "x", "o" },
        function()
          local flash = require "flash"

          flash.jump()
        end,
        desc = "Flash",
      },
      {
        "S",
        mode = "n",
        function()
          require("flash").treesitter({ jump = { pos = "start" } })
        end,
        desc = "Flash Treesitter (jump)",
      },
      {
        "S",
        mode = { "x", "o" },
        function()
          require("flash").treesitter()
        end,
        desc = "Flash Treesitter (select)",
      },
      {
        "r",
        mode = "o",
        function()
          local flash = require "flash"

          flash.remote()
        end,
        desc = "Remote Flash",
      },
      {
        "R",
        mode = { "o", "x" },
        function()
          local flash = require "flash"

          flash.treesitter_search()
        end,
        desc = "Treesitter Search",
      },
      {
        "<c-s>",
        mode = { "c" },
        function()
          local flash = require "flash"

          flash.toggle()
        end,
        desc = "Toggle Flash Search",
      },
    },
  },
  {
    "m4xshen/hardtime.nvim",
    event = "VeryLazy",
    dependencies = { "MunifTanjim/nui.nvim" },
    opts = require "configs.hardtime",
  },
  {
    "rcarriga/nvim-notify",
    event = "VeryLazy",
    opts = require "configs.notify",
  },
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = function()
      vim.fn["mkdp#util#install"]()
    end,
  },
}
