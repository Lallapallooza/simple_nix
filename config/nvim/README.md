# Neovim config

NvChad-based config for everyday editing with a bias toward C/C++/MLIR/TableGen and Python.

## Layout

- `init.lua` - bootstraps Lazy, loads NvChad, then loads local config
- `lua/options.lua` - editor options, backup/undo dirs, MLIR filetype detection, view restore
- `lua/autocmds.lua` - local user commands and autocommands
- `lua/mappings.lua` - repo-local keymaps and `:Format`
- `lua/plugins/*.lua` - Lazy plugin specs grouped by domain
- `lua/configs/*.lua` - plugin options/setup
- `lua/configs/server-settings/*.lua` - per-LSP overrides
- `CHEATSHEET.md` - quick daily reference, opened with `:DotfilesCheatsheet`

## Plugin groups

- `plugins/editor.lua` - formatting, Treesitter, flash, resize mode, markdown preview
- `plugins/files.lua` - file tree
- `plugins/lsp.lua` - LSP, signature help, Lspsaga, Lua dev support
- `plugins/workflow.lua` - Trouble, Overseer, Telescope extras, sessions

## Local behavior

- `:Format` formats the whole buffer or the selected range
- formatting uses `stylua`, `ruff_fix`, `ruff_format`, `rustfmt`, `goimports`, `clang-format`, `prettier`, and `codespell` (LSP fallback for unconfigured filetypes)
- enabled LSP servers: `clangd`, `bashls`, `ts_ls`, `rust_analyzer`, `gopls`, `cmake`, `tblgen_lsp_server`, `mlir_lsp_server`, `basedpyright`, `ruff`
- `*.mlir` files are forced to `mlir` filetype
- undo and backup files live under Neovim's data directory
- clipboard sync is intentionally disabled by default (`opt.clipboard = ""`)

## Maintenance

```bash
nvim --headless "+Lazy! sync" "+qa"
stylua config/nvim
```

## External tools

- required: `nvim` 0.11+, `git`, `ripgrep`
- useful: `make`, `stylua`, `tree-sitter`, `codespell`, `ruff`, `rustfmt`, `goimports`, `prettier`, `basedpyright`, `clangd`, `gopls`, `typescript-language-server`, `typescript`, `rust-analyzer`, `cmake-language-server`, `bash-language-server`
- optional / project-specific: `tblgen_lsp_server`, `mlir_lsp_server`
