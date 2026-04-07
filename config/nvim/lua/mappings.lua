-- Local keymaps and user commands.

require "nvchad.mappings"

local api = vim.api
local map = vim.keymap.set

local function grep_in_directory(dir)
  local builtin = require "telescope.builtin"

  builtin.live_grep {
    search_dirs = { dir },
  }
end

local function current_buffer_directory()
  local name = api.nvim_buf_get_name(0)
  if name == "" then
    return vim.fn.getcwd()
  end

  return vim.fs.dirname(name)
end

local function tree_or_buffer_directory()
  if vim.bo.filetype == "NvimTree" then
    local ok, tree_api = pcall(require, "nvim-tree.api")
    if ok then
      local node = tree_api.tree.get_node_under_cursor()
      if node and node.absolute_path then
        if node.nodes ~= nil then
          return node.absolute_path
        end
        return vim.fs.dirname(node.absolute_path)
      end
    end
  end

  return current_buffer_directory()
end

local function save_named_session()
  vim.ui.input({ prompt = "Session name: " }, function(input)
    local name = input and vim.trim(input) or ""
    if name == "" then
      return
    end

    require("auto-session").save_session(name, { show_message = true })
  end)
end

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

api.nvim_create_user_command("Format", function(args)
  local conform = require "conform"
  local range = nil
  if args.count ~= -1 then
    -- Mirror visual selection bounds into conform's expected range shape.
    local end_line = api.nvim_buf_get_lines(0, args.line2 - 1, args.line2, true)[1]
    range = {
      start = { args.line1, 0 },
      ["end"] = { args.line2, end_line:len() },
    }
  end
  conform.format { async = true, lsp_format = "fallback", range = range }
end, { range = true })

map("v", "<", "<gv", { desc = "Indent left and keep selection", silent = true })
map("v", ">", ">gv", { desc = "Indent right and keep selection", silent = true })

map("v", "<leader>y", '"+y', { desc = "Yank to system clipboard" })
map("n", "<leader>p", '"+p', { desc = "Paste from system clipboard" })

map("n", "<leader>F", function()
  require("conform").format { async = true }
end, { desc = "Format entire file" })

map("v", "<leader>F", ":<C-u>'<,'>Format<CR>", { desc = "Format selected range", silent = true })

map("n", "<leader>ah", "<cmd>ClangdSwitchSourceHeader<CR>", { desc = "Toggle header / source" })
map("n", "<leader>hc", "<cmd>DotfilesCheatsheet<CR>", { desc = "Open cheat sheet" })

map("n", "<leader>xx", function()
  require("trouble").toggle "diagnostics"
end, { desc = "Trouble diagnostics" })
map("n", "<leader>xq", function()
  require("trouble").toggle "quickfix"
end, { desc = "Trouble quickfix" })
map("n", "<leader>xl", function()
  require("trouble").toggle "loclist"
end, { desc = "Trouble location list" })
map("n", "<leader>xs", function()
  require("trouble").toggle "symbols"
end, { desc = "Trouble symbols" })
map("n", "<leader>xr", function()
  require("trouble").toggle "lsp_references"
end, { desc = "Trouble references" })

map("n", "<leader>or", "<cmd>OverseerRun<CR>", { desc = "Run task" })
map("n", "<leader>ot", "<cmd>OverseerToggle<CR>", { desc = "Toggle task list" })

map("n", "<leader>gj", function()
  require("gitsigns").next_hunk()
end, { desc = "Git: Next hunk" })
map("n", "<leader>gk", function()
  require("gitsigns").prev_hunk()
end, { desc = "Git: Previous hunk" })
map("n", "<leader>gp", function()
  require("gitsigns").preview_hunk()
end, { desc = "Git: Preview hunk" })
map("n", "<leader>gs", function()
  require("gitsigns").stage_hunk()
end, { desc = "Git: Stage hunk" })
map("n", "<leader>gr", function()
  require("gitsigns").reset_hunk()
end, { desc = "Git: Reset hunk" })
map("n", "<leader>gb", function()
  require("gitsigns").blame_line { full = true }
end, { desc = "Git: Blame line" })

map("n", "<leader>fR", "<cmd>Telescope resume<CR>", { desc = "Telescope resume" })
map("n", "<leader>fG", "<cmd>Telescope live_grep additional_args=function() return { '--hidden', '--no-ignore' } end<CR>", { desc = "Telescope live grep all" })
map("n", "<leader>fW", function()
  local builtin = require "telescope.builtin"

  builtin.grep_string { search = vim.fn.expand "<cword>" }
end, { desc = "Telescope grep current word" })
map("n", "<leader>fd", function()
  grep_in_directory(current_buffer_directory())
end, { desc = "Telescope grep current dir" })
map("n", "<leader>fD", function()
  grep_in_directory(tree_or_buffer_directory())
end, { desc = "Telescope grep tree dir" })

map("n", "<leader>wr", "<cmd>AutoSession search<CR>", { desc = "Restore/search sessions" })
map("n", "<leader>ws", "<cmd>AutoSession save<CR>", { desc = "Save latest session" })
map("n", "<leader>wn", save_named_session, { desc = "Save named session" })
map("n", "<leader>wd", "<cmd>AutoSession deletePicker<CR>", { desc = "Delete session" })
map("n", "<leader>wa", "<cmd>AutoSession toggle<CR>", { desc = "Toggle session autosave" })
