-- clangd server overrides.

-- Grey out inactive preprocessor regions (#ifdef blocks where condition is false).
-- clangd sends textDocument/inactiveRegions notifications; Neovim doesn't handle
-- them natively, so we register a custom handler.

local ns = vim.api.nvim_create_namespace("clangd_inactive_regions")

vim.lsp.handlers["textDocument/inactiveRegions"] = function(_err, result, ctx)
  if not result or not result.regions then return end

  local bufnr = vim.uri_to_bufnr(result.textDocument.uri)
  if not vim.api.nvim_buf_is_valid(bufnr) then return end

  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  for _, region in ipairs(result.regions) do
    for line = region.start.line, region["end"].line do
      vim.api.nvim_buf_set_extmark(bufnr, ns, line, 0, {
        end_col = 0,
        end_row = line + 1,
        hl_group = "ClangdInactiveRegion",
        hl_eol = true,
        priority = 200,
      })
    end
  end
end

-- Subtle background tint so syntax colors are preserved but region is visibly dimmed.
vim.api.nvim_set_hl(0, "ClangdInactiveRegion", { fg = "#3d4046" })

return {
  cmd = {
    "clangd",
    "--clang-tidy",
    "--background-index",
    "--completion-style=detailed",
    "--enable-config",
    "--all-scopes-completion",
    "--fallback-style=llvm",
    "--log=error",
  },
  init_options = {
    clangdFileStatus = true,
    usePlaceholders = true,
    completeUnimported = true,
    semanticHighlighting = true,
  },
  capabilities = {
    textDocument = {
      inactiveRegionsCapabilities = {
        inactiveRegions = true,
      },
    },
  },
}
