-- Local autocommands and user commands.

local api = vim.api
local fn = vim.fn

require "nvchad.autocmds"

api.nvim_create_user_command("DotfilesCheatsheet", function()
  local path = fn.stdpath "config" .. "/CHEATSHEET.md"
  vim.cmd.edit(fn.fnameescape(path))
end, {
  desc = "Open the local Neovim cheat sheet",
})
