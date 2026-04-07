-- LSP server registration and overrides.

local nvchad_lsp = require "nvchad.configs.lspconfig"

nvchad_lsp.defaults()

-- Re-enable semantic tokens (NvChad disables them for all servers).
-- Our color scheme relies on @lsp.type.* highlights for proper differentiation.
vim.lsp.config("*", { on_init = function() end })

local servers = {
  "clangd",
  "bashls",
  "ts_ls",
  "rust_analyzer",
  "gopls",
  "cmake",
  "kotlin_ls",
  "basedpyright",
  "ruff",
  -- tblgen_lsp_server and mlir_lsp_server are not in nixpkgs.
  -- Build them from the LLVM project source tree, then add to this list
  -- with a server-settings/ file pointing cmd to your build output:
  --   return { cmd = { "/path/to/llvm-project/build/bin/tblgen-lsp-server" } }
}

for _, server in ipairs(servers) do
  -- Keep server-specific config optional so most servers can stay on defaults.
  local ok, settings = pcall(require, "configs.server-settings." .. server)
  if ok then
    vim.lsp.config(server, settings)
  end
end

vim.lsp.enable(servers)
