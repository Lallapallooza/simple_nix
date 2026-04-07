-- hardtime configuration.

return {
  hint = true,
  notification = true,
  timeout = 5000,
  disabled_filetypes = {
    "NvimTree",
    "TelescopePrompt",
    "Trouble",
    "help",
    "lazy",
    "mason",
    "oil",
    "qf",
    "terminal",
    "toggleterm",
  },
  disabled_buftypes = {
    "nofile",
    "prompt",
    "quickfix",
    "terminal",
  },
  max_time = 1200,
  max_count = 3,
  restriction_mode = "block",
  restricted_keys = {
    h = false,
    j = false,
    k = false,
    l = false,
  },
  disabled_keys = {
    ["<Up>"] = false,
    ["<Down>"] = false,
    ["<Left>"] = false,
    ["<Right>"] = false,
  },
  callback = function(text)
    require("notify")(text, vim.log.levels.WARN, {
      title = "Hardtime",
      timeout = 5000,
      render = "wrapped-compact",
    })
  end,
}
