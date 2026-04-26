#!/usr/bin/env bash
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"

echo "==> Generating hardware config..."
# Write to temp file first to avoid truncating the existing config on failure
_hw_tmp=$(mktemp)
_install_ok=false
trap 'rm -f "$_hw_tmp"; $_install_ok || git -C "$REPO" reset nixos/hardware-configuration.nix 2>/dev/null || true' EXIT
sudo nixos-generate-config --show-hardware-config > "$_hw_tmp"
mv "$_hw_tmp" "$REPO/nixos/hardware-configuration.nix"
# Nix flakes in git repos only see tracked files; stage it temporarily so nixos-rebuild can find it
git -C "$REPO" add -f nixos/hardware-configuration.nix

echo "==> Rebuilding NixOS..."
_hostname=$(nix eval --raw -f "$REPO/nixos/host.nix" hostname 2>/dev/null || hostname)
sudo nixos-rebuild switch -L --flake "$REPO/nixos#$_hostname"

# Ensure new packages are in PATH for the current session
export PATH="/run/current-system/sw/bin:$PATH"

echo "==> Symlinking configs..."
"$REPO/link.sh"

# Unstage hardware-configuration.nix so it stays gitignored
git -C "$REPO" reset nixos/hardware-configuration.nix 2>/dev/null || true

_install_ok=true
