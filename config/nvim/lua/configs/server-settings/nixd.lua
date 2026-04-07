-- nixd server overrides.

return {
  settings = {
    nixd = {
      nixpkgs = {
        expr = "import <nixpkgs> {}",
      },
      formatting = {
        command = { "nixfmt" },
      },
    },
  },
}
