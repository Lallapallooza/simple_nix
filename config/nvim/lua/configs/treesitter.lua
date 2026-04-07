-- Treesitter configuration (nvim-treesitter v2).

return {
  highlight = {
    enable = true,
  },
  install = {
    "vim", "lua", "vimdoc", "html", "css",
    "c", "cpp", "nix", "mlir", "llvm", "tablegen",
    "python", "rust", "go", "typescript", "javascript",
    "bash", "json", "toml", "yaml", "markdown", "markdown_inline",
  },
}
