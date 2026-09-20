#!/usr/bin/env bash
set -euo pipefail

# Install/update claude-code and codex natively into ~/.local/bin.
# These tools release too often to package in nix (an OS rebuild per bump);
# ~/.local/bin is already on PATH via home-manager sessionPath.
#
#   claude  Anthropic's official installer. Self-updates after the first
#           install, so this script only needs to run once.
#   codex   npm package (vendors static musl binaries, runs on NixOS
#           unpatched). npm's default prefix is the read-only nix store,
#           so --prefix ~/.local routes the bin to ~/.local/bin. No
#           self-updater; rerun this script to update.
#
# Usage: install-ai-tools.sh [claude|codex]   (default: both)

BIN_DIR="${HOME}/.local/bin"
TOOL_FILTER="${1:-}"

should_install() {
  [[ -z "$TOOL_FILTER" || "$TOOL_FILTER" == "$1" ]]
}

install_claude() {
  echo "-- claude-code ----------------------------"
  if [[ -x "${BIN_DIR}/claude" ]]; then
    echo "  installed: $("${BIN_DIR}/claude" --version 2>/dev/null || echo '?')"
    claude update
    echo "  claude updated"
    return
  fi
  curl -fsSL https://claude.ai/install.sh | bash
  echo "  installed: $("${BIN_DIR}/claude" --version 2>/dev/null || echo '?')"
}

install_codex() {
  echo "-- codex ----------------------------------"

  local latest
  latest=$(npm view @openai/codex version 2>/dev/null || true)
  if [[ -z "$latest" ]]; then
    echo "  ERROR: could not fetch latest version from npm"; return 1
  fi

  local current=""
  if [[ -x "${BIN_DIR}/codex" ]]; then
    current=$("${BIN_DIR}/codex" --version 2>/dev/null | grep -o '[0-9.]*[0-9]' | head -1 || true)
  fi
  if [[ "$current" == "$latest" ]]; then
    echo "  up to date: ${current}"
    return
  fi
  echo "  installing: ${current:-none} -> ${latest}"

  npm install -g --prefix "${HOME}/.local" "@openai/codex@${latest}"
  echo "  installed: $("${BIN_DIR}/codex" --version 2>/dev/null || echo '?')"
}

if should_install claude; then install_claude; fi
if should_install codex; then install_codex; fi
