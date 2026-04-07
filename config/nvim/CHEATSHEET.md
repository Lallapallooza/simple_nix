# Neovim cheat sheet

Daily reference for this config.

- Leader: `<Space>`
- Open this file: `:DotfilesCheatsheet`
- NvChad defaults still apply; use `:WhichKey` and `:Telescope keymaps` to explore them

## Commands

```vim
:Lazy
:Lazy sync
:Mason
:NvimTreeToggle
:NvimTreeFocus
:Format
:'<,'>Format
:DotfilesCheatsheet
:OverseerRun
:OverseerToggle
:AutoSession search
:AutoSession save
:AutoSession toggle
:ClangdSwitchSourceHeader
```

## Editing

```text
;                 enter command-line mode
jk                leave insert mode
< / >             reindent visual selection and keep it selected
<leader>y         yank visual selection to system clipboard
<leader>p         paste from system clipboard
<leader>F         format file
<leader>F         format selected range in visual mode
<leader>hc        open this cheat sheet
```

## LSP

These mappings appear after an LSP attaches to the current buffer.

```text
<leader>lr        rename symbol
<leader>la        code action
<leader>ld        go to definition
<leader>lt        go to type definition
<leader>lh        hover documentation
<leader>lo        document outline
<leader>li        go to implementation
<leader>lR        find references
<leader>ls        cursor diagnostics
<leader>lS        line diagnostics
<leader>lj        next diagnostic
<leader>lk        previous diagnostic
<leader>ah        switch source/header with clangd
```

## Git

```text
<leader>gj        next hunk
<leader>gk        previous hunk
<leader>gp        preview hunk
<leader>gs        stage hunk
<leader>gr        reset hunk
<leader>gb        blame line
```

## Search

```text
<leader>fR        resume last Telescope search
<leader>fG        live grep all (hidden + ignored)
<leader>fW        grep current word
<leader>fd        grep in current file's directory
<leader>fD        grep in NvimTree root or file's directory
```

## Trouble

```text
<leader>xx        diagnostics
<leader>xq        quickfix
<leader>xl        location list
<leader>xs        symbols
<leader>xr        references
```

## Tasks and sessions

```text
<leader>or        run task
<leader>ot        toggle task list
<leader>wr        session search
<leader>ws        save session
<leader>wn        save named session
<leader>wd        delete session
<leader>wa        toggle session autosave
```

## Maintenance

```bash
nvim --headless "+Lazy! sync" "+qa"
stylua config/nvim
```
