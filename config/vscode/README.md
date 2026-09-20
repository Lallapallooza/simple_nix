# VS Code -- Ayu Dark (10-group)

Same palette as kitty, neovim, wayle, rofi, KDE and Hyprland. See the "Theme"
section of the repo README for the shared color roles.

`ayu-dark-10group/` is a local theme extension, not a marketplace install.
`link.sh` symlinks it into `~/.vscode/extensions/`, so editing the theme JSON
and reloading the window (`Ctrl+Shift+P` -> "Developer: Reload Window") applies
changes immediately -- the same live-edit loop as the other configs here.

## Why two color layers

`config/nvim/lua/chadrc.lua` splits syntax highlighting into treesitter groups
plus an `@lsp.type.*` table that adds type-level precision on top. VS Code has
the same split, and the theme maps onto it one-to-one:

| neovim | VS Code | Covers |
|--------|---------|--------|
| `hl_override` / treesitter | `tokenColors` (TextMate) | Files with no language server |
| `hl_add` / `@lsp.type.*`   | `semanticTokenColors`    | rust-analyzer, clangd, basedpyright |

Semantic tokens win over TextMate rules, so a language server's `parameter`
beats the grammar's guess -- exactly the priority order neovim uses.

## settings.json

`settings.json` here is the reference copy. It is **not** symlinked: VS Code
rewrites `~/.config/Code/User/settings.json` whenever a setting changes in the
UI, which would turn every UI tweak into a repo diff. `link.sh` merges these
keys into the live file instead and leaves everything else alone.

Two of those keys are load-bearing rather than cosmetic:

- `window.autoDetectColorScheme` must be `false`. Left on, VS Code follows the
  system light/dark preference and overrides `workbench.colorTheme`.
- `terminal.integrated.minimumContrastRatio` must be `1`. The default of `4.5`
  makes VS Code silently lighten ANSI colors it judges low-contrast, which
  breaks the exact match with `config/kitty/kitty.conf`.
