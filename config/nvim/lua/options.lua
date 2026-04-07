-- Editor options and small UX autocommands.

require "nvchad.options"

local api = vim.api
local fn = vim.fn
local opt = vim.opt

local backupdir = fn.stdpath "data" .. "/backup"
local undodir = fn.stdpath "data" .. "/undotree"

fn.mkdir(backupdir, "p")
fn.mkdir(undodir, "p")

opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldenable = false
opt.relativenumber = true

opt.backup = true
opt.writebackup = true
opt.backupdir = backupdir

opt.undofile = true
opt.undodir = undodir

local filetype_group = api.nvim_create_augroup("UserFiletypes", { clear = true })
api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
  group = filetype_group,
  pattern = "*.mlir",
  callback = function()
    -- Some MLIR files do not get detected correctly by default.
    vim.bo.filetype = "mlir"
  end,
})

opt.clipboard = ""

local view_state = {}
local view_group = api.nvim_create_augroup("UserViewState", { clear = true })

api.nvim_create_autocmd("BufLeave", {
  group = view_group,
  callback = function()
    -- Remember the current window view per buffer when jumping between files.
    local bufnr = api.nvim_get_current_buf()
    view_state[bufnr] = fn.winsaveview()
  end,
})

api.nvim_create_autocmd("BufEnter", {
  group = view_group,
  callback = function()
    local bufnr = api.nvim_get_current_buf()
    if view_state[bufnr] then
      -- Restore cursor/scroll position when re-entering the buffer.
      fn.winrestview(view_state[bufnr])
    end
  end,
})
