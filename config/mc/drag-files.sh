#!/usr/bin/env bash
# Offer MC's selection as a Kitty drag, including to sandboxed Discord.
set -euo pipefail

files=("$@")

if command -v flatpak >/dev/null 2>&1 && flatpak info com.discordapp.Discord >/dev/null 2>&1; then
  files=()
  for path in "$@"; do
    # The portal exposes the selected item under a path visible both inside and
    # outside Discord's sandbox. Access is read-only and lasts for this session;
    # keep it after the drop because Discord reads attachments asynchronously.
    exported=$(flatpak document-export --unique --transient \
      --app=com.discordapp.Discord --allow-read -- "$path")
    files+=("$exported")
  done
fi

exec kitten dnd --exit-on drag-finish,esc-key -- "${files[@]}"
