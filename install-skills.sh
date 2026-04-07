#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$HOME/.config/vs-core"
CONFIG_FILE="$CONFIG_DIR/config"

echo "vs-core skills installer"
echo "========================"
echo ""

# --- Symlink skills (delegates to link.sh to avoid duplication) ---
"$REPO/link.sh" --skills-only

# --- Update notifications ---
echo ""
read -rp "Enable update notifications? [Y/n] " update_choice || update_choice="Y"
update_choice="${update_choice:-Y}"

mkdir -p "$CONFIG_DIR"

if [[ "$update_choice" =~ ^[Nn]$ ]]; then
  echo "update_check=false" > "$CONFIG_FILE"
  echo "    Update notifications disabled."
else
  echo "update_check=true" > "$CONFIG_FILE"
  echo "repo_path=$REPO" >> "$CONFIG_FILE"
  echo "    Update notifications enabled."
  echo ""
  echo "==> Hook setup (optional, per agent):"
  echo ""
  echo "  Claude Code - add to ~/.claude/settings.json under \"hooks\":"
  echo '    "PreToolUse": [{'
  echo '      "matcher": "Skill",'
  echo '      "hooks": [{"type": "command", "command": "'"$REPO"'/scripts/vs-core-update-check.sh"}]'
  echo '    }]'
  echo ""
  echo "  Codex CLI - add to ~/.codex/hooks.json:"
  echo '    {"event": "SessionStart", "hooks": [{"type": "command", "command": "'"$REPO"'/scripts/vs-core-update-check.sh"}]}'
  echo ""
  echo "  OpenCode - create ~/.config/opencode/plugins/vs-core-update.js:"
  echo '    export const VsCoreUpdate = async ({ $ }) => ({'
  echo '      "session.created": async () => {'
  echo "        await \$\`$REPO/scripts/vs-core-update-check.sh\`"
  echo '      }'
  echo '    })'
fi

echo ""
echo "Done. Skills are ready to use."
