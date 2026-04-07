-- auto-session configuration.

local home = vim.fn.expand "~"

return {
  auto_save = true,
  auto_restore = false,
  suppressed_dirs = {
    home .. "/",
    home .. "/Downloads",
    "/",
  },
  session_lens = {
    picker = "telescope",
    load_on_setup = false,
  },
}
