-- nvim-tree configuration.

return {
  filters = {
    custom = { ".git" },
    exclude = { ".gitignore" },
  },
  view = {
    adaptive_size = true,
  },
  sync_root_with_cwd = false,
  respect_buf_cwd = false,
  prefer_startup_root = true,
  update_focused_file = {
    enable = true,
    update_root = true,
  },
  git = { ignore = true },
}
