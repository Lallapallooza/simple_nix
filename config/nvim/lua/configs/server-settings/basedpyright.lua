-- basedpyright server overrides.

return {
  root_markers = {
    "pyrightconfig.json",
    "pyproject.toml",
    "setup.py",
    "setup.cfg",
    "requirements.txt",
    "Pipfile",
    ".git",
  },
  settings = {
    basedpyright = {
      analysis = {
        autoSearchPaths = true,
        diagnosticMode = "openFilesOnly",
      },
    },
    python = {
      analysis = {
        exclude = {
          "**/.git",
          "**/__pycache__",
          "**/.venv",
          "**/node_modules",
          "**/build",
          "**/dist",
          "**/third_party",
          "**/externals",
          "**/dependencies",
        },
        ignore = {
          "**/.git",
          "**/__pycache__",
          "**/.venv",
          "**/node_modules",
          "**/build",
          "**/dist",
          "**/third_party",
          "**/externals",
          "**/dependencies",
        },
      },
    },
  },
}
