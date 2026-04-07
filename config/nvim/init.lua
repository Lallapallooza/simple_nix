-- Neovim bootstrap and plugin loading.

local fn = vim.fn
local opt = vim.opt
local uv = vim.uv

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.base46_cache = fn.stdpath "data" .. "/base46/"
vim.g.mapleader = " "

-- LSP semantic tokens at default priority (125) so they override treesitter.
-- We clear @lsp.type.variable so it doesn't flatten everything to fg --
-- treesitter's more specific captures (parameter, member, builtin) show through.

local lazypath = fn.stdpath "data" .. "/lazy/lazy.nvim"

if not uv.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  fn.system { "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath }
end

opt.rtp:prepend(lazypath)

local lazy_config = require "configs.lazy"
local lazy = require "lazy"

lazy.setup({
  {
    "NvChad/NvChad",
    lazy = false,
    branch = "v2.5",
    import = "nvchad.plugins",
  },

  { import = "plugins" },
}, lazy_config)

dofile(vim.g.base46_cache .. "defaults")
dofile(vim.g.base46_cache .. "statusline")

require "options"
require "autocmds"

vim.schedule(function()
  require "mappings"
end)
