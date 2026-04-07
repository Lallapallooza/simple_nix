-- lspsaga configuration and attach-time keymaps.

local M = {}
local api = vim.api
local keymap = vim.keymap.set
local lsp = vim.lsp

M.opts = {
  lightbulb = {
    enable = false,
    sign = false,
    virtual_text = false,
    enable_in_insert = false,
  },
  rename = {
    in_select = false,
  },
}

function M.setup_keymaps()
  local group = api.nvim_create_augroup("UserLspsagaKeymaps", { clear = true })
  api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(args)
      local client = lsp.get_client_by_id(args.data.client_id)
      if not client then
        return
      end

      local map = function(mode, lhs, rhs, desc)
        keymap(mode, lhs, rhs, {
          buffer = args.buf,
          silent = true,
          desc = desc,
        })
      end

      -- Only expose mappings for capabilities the attached server actually supports.
      if client.server_capabilities.renameProvider then
        map("n", "<leader>lr", "<cmd>Lspsaga rename<CR>", "LSP: Rename")
      end
      if client.server_capabilities.codeActionProvider then
        map({ "n", "v" }, "<leader>la", "<cmd>Lspsaga code_action<CR>", "LSP: Code Action")
      end
      if client.server_capabilities.definitionProvider then
        map("n", "<leader>ld", "<cmd>Lspsaga goto_definition<CR>", "LSP: Go to Definition")
      end
      if client.server_capabilities.typeDefinitionProvider then
        map("n", "<leader>lt", "<cmd>Lspsaga goto_type_definition<CR>", "LSP: Go to Type Definition")
      end
      if client.server_capabilities.hoverProvider then
        map("n", "<leader>lh", "<cmd>Lspsaga hover_doc<CR>", "LSP: Hover Documentation")
      end
      if client.server_capabilities.documentSymbolProvider then
        map("n", "<leader>lo", "<cmd>Lspsaga outline<CR>", "LSP: Document Outline")
      end
      if client.server_capabilities.implementationProvider then
        map("n", "<leader>li", "<cmd>Lspsaga goto_implementation<CR>", "LSP: Go to Implementation")
      end
      if client.server_capabilities.referencesProvider then
        map("n", "<leader>lR", "<cmd>Lspsaga finder<CR>", "LSP: References Finder")
      end

      map("n", "<leader>ls", "<cmd>Lspsaga show_cursor_diagnostics<CR>", "LSP: Show Cursor Diagnostics")
      map("n", "<leader>lS", "<cmd>Lspsaga show_line_diagnostics<CR>", "LSP: Show Line Diagnostics")
      map("n", "<leader>lj", "<cmd>Lspsaga diagnostic_jump_next<CR>", "LSP: Next Diagnostic")
      map("n", "<leader>lk", "<cmd>Lspsaga diagnostic_jump_prev<CR>", "LSP: Previous Diagnostic")
    end,
  })
end

return M
