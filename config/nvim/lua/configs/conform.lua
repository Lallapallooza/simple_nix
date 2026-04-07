-- conform.nvim configuration.

local options = {
  formatters_by_ft = {
    lua = { "stylua" },
    python = { "ruff_fix", "ruff_format" },
    rust = { "rustfmt" },
    go = { "goimports" },
    c = { "clang-format" },
    cpp = { "clang-format" },
    typescript = { "prettier" },
    javascript = { "prettier" },
    ["*"] = { "codespell" },
  },
  default_format_opts = {
    lsp_format = "fallback",
  },
}

return options
