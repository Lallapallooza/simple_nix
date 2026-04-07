#!/usr/bin/env bash
# vs-core update check — run from agent hooks to notify about available updates.
# Reads config from ~/.config/vs-core/config. No-ops if update_check=false.
# Rate-limited: checks at most once every 6 hours.
set -euo pipefail

CONFIG_FILE="$HOME/.config/vs-core/config"
LAST_CHECK_FILE="$HOME/.config/vs-core/last_check"
CHECK_INTERVAL=21600  # 6 hours in seconds

# No-op if config missing or updates disabled
[[ -f "$CONFIG_FILE" ]] || exit 0
grep -q "^update_check=true$" "$CONFIG_FILE" || exit 0

# Rate limit: skip if checked recently
if [[ -f "$LAST_CHECK_FILE" ]]; then
  last_check="$(cat "$LAST_CHECK_FILE" 2>/dev/null)" || last_check=0
  now="$(date +%s)"
  if (( now - last_check < CHECK_INTERVAL )); then
    exit 0
  fi
fi

# Get repo path from config
repo_path="$(grep "^repo_path=" "$CONFIG_FILE" | cut -d= -f2-)"
[[ -d "$repo_path/.git" ]] || exit 0

# Fetch quietly, compare
git -C "$repo_path" fetch --quiet 2>/dev/null || exit 0
date +%s > "$LAST_CHECK_FILE" 2>/dev/null || true

local_head="$(git -C "$repo_path" rev-parse HEAD 2>/dev/null)" || exit 0
remote_head="$(git -C "$repo_path" rev-parse '@{u}' 2>/dev/null)" || exit 0

if [[ "$local_head" != "$remote_head" ]]; then
  behind="$(git -C "$repo_path" rev-list --count HEAD..'@{u}' 2>/dev/null)" || behind="some"
  if [[ "$behind" != "0" ]]; then
    echo "vs-core skills: ${behind} update(s) available. Run: git -C \"$repo_path\" pull"
  fi
fi
