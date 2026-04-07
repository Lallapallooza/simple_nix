-- Standalone .rs files: start rust-analyzer in detached mode.
-- For Cargo projects, the global rust_analyzer config handles it.
local root = vim.fs.root(0, { "Cargo.toml", "rust-project.json" })
if root then return end

local bufname = vim.api.nvim_buf_get_name(0)
if bufname == "" then return end

vim.defer_fn(function()
  -- Detach the global rust_analyzer from this buffer
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0, name = "rust_analyzer" })) do
    vim.lsp.buf_detach_client(0, client.id)   -- TODO: replace with client:buf_detach(0) when available
  end

  vim.lsp.start({
    name = "rust_analyzer_standalone",
    handlers = {
      ["window/showMessage"] = function(_, result, ...)
        -- Suppress "Failed to discover workspace" noise in standalone mode
        if result and result.message and result.message:match("Failed to discover workspace") then
          return
        end
        vim.lsp.handlers["window/showMessage"](_, result, ...)
      end,
    },
    cmd = { "rust-analyzer" },
    root_dir = vim.fs.dirname(bufname),
    init_options = {
      detachedFiles = { bufname },
    },
    settings = {
      ["rust-analyzer"] = {
        checkOnSave = false,
        cargo = { buildScripts = { enable = false } },
        procMacro = { enable = false },
      },
    },
  })
end, 500)
