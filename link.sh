#!/usr/bin/env bash
# Symlink configs that benefit from live editing (change takes effect immediately).
# Files that need Nix interpolation or are small/static use home-manager instead
# (see nixos/home/theming.nix for GTK/KDE, nixos/home/apps.nix for mc).
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
SKILLS_ONLY=false
[[ "${1:-}" == "--skills-only" ]] && SKILLS_ONLY=true

link_skills() {
  echo "==> Symlinking vs-core skills..."
  mkdir -p "$HOME/.claude/skills" "$HOME/.agents/skills"
  local count=0
  for skill_dir in "$REPO"/skills/skills/vs-core-*/; do
    [[ -d "$skill_dir" ]] || continue
    local skill_name
    skill_name="$(basename "$skill_dir")"
    skill_dir="${skill_dir%/}"
    for dest_dir in "$HOME/.claude/skills" "$HOME/.agents/skills"; do
      local dest="$dest_dir/$skill_name"
      local resolved
      resolved="$(cd "$dest_dir" 2>/dev/null && pwd -P || echo "$dest_dir")"
      if [[ "$resolved" == "$REPO/"* || "$resolved" == "$REPO" ]]; then
        echo "    SKIP $dest_dir - resolves into repo tree" >&2
        continue
      fi
      rm -rf "$dest"
      ln -sfn "$skill_dir" "$dest"
    done
    count=$((count + 1))
  done
  echo "    Linked $count skills to ~/.claude/skills/ and ~/.agents/skills/"
}

link_skills

if $SKILLS_ONLY; then exit 0; fi

echo "==> Symlinking editable configs..."
# Replace directory symlinks safely; warn if replacing a real directory
if [[ -d "$HOME/.config/nvim" && ! -L "$HOME/.config/nvim" ]]; then
  echo "    WARNING: $HOME/.config/nvim is a real directory, moving to $HOME/.config/nvim.bak"
  rm -rf "$HOME/.config/nvim.bak"
  mv "$HOME/.config/nvim" "$HOME/.config/nvim.bak"
else
  rm -rf "$HOME/.config/nvim"
fi
ln -sfn "$REPO/config/nvim" "$HOME/.config/nvim"
mkdir -p "$HOME/.config/kitty"
ln -sf "$REPO/config/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
mkdir -p "$HOME/.config/wayle"
ln -sf "$REPO/config/wayle/config.toml" "$HOME/.config/wayle/config.toml"
# Wayle compiles styles/index.scss on top of its built-in stylesheet. Wayle
# recreates this directory with a stock scaffold whenever it is missing, so a
# real directory has to go first -- ln -sfn would nest the link inside it.
if [[ -d "$HOME/.config/wayle/styles" && ! -L "$HOME/.config/wayle/styles" ]]; then
  rm -rf "$HOME/.config/wayle/styles"
fi
ln -sfn "$REPO/config/wayle/styles" "$HOME/.config/wayle/styles"
mkdir -p "$HOME/.config/hypr"
for f in user.lua hypridle.conf hyprlock.conf hyprpaper.conf cheatsheet.sh toggle-layout.sh; do
  ln -sf "$REPO/config/hypr/$f" "$HOME/.config/hypr/$f"
done

echo "==> Symlinking wallpaper..."
mkdir -p "$HOME/Pictures"
if [[ -f "$REPO/wallpapers/wallpaper.png" ]]; then
  ln -sf "$REPO/wallpapers/wallpaper.png" "$HOME/Pictures/wallpaper.png"
else
  echo "    SKIP: wallpapers/wallpaper.png not found (place your wallpaper there)"
fi

echo "==> Symlinking rofi config..."
if [[ -d "$HOME/.config/rofi" && ! -L "$HOME/.config/rofi" ]]; then
  echo "    WARNING: $HOME/.config/rofi is a real directory, moving to $HOME/.config/rofi.bak"
  rm -rf "$HOME/.config/rofi.bak"
  mv "$HOME/.config/rofi" "$HOME/.config/rofi.bak"
else
  rm -rf "$HOME/.config/rofi"
fi
ln -sfn "$REPO/config/rofi" "$HOME/.config/rofi"

echo "==> Symlinking p10k config..."
ln -sf "$REPO/config/p10k/.p10k.zsh" "$HOME/.p10k.zsh"


echo "==> Installing VS Code theme..."
# Not a symlink: VS Code only loads extensions listed in its extensions.json
# manifest, which it writes on install. A symlink here is silently ignored.
"$REPO/config/vscode/install-theme.sh"

# settings.json is NOT symlinked: VS Code rewrites it on every UI settings
# change, which would turn each tweak into a repo diff. Merge our keys in and
# leave the rest of the file alone. Repo values win on conflict.
VSCODE_SETTINGS="$HOME/.config/Code/User/settings.json"
mkdir -p "$(dirname "$VSCODE_SETTINGS")"
[[ -f "$VSCODE_SETTINGS" ]] || echo '{}' > "$VSCODE_SETTINGS"
if merged=$(jq -s '.[0] * .[1]' "$VSCODE_SETTINGS" "$REPO/config/vscode/settings.json" 2>/dev/null); then
  printf '%s\n' "$merged" > "$VSCODE_SETTINGS"
  echo "    Merged theme keys into $VSCODE_SETTINGS"
else
  # jq rejects JSONC; VS Code allows comments in settings.json.
  echo "    SKIP: $VSCODE_SETTINGS is not plain JSON (comments?), apply config/vscode/settings.json by hand" >&2
fi

echo "==> Symlinking clangd config..."
mkdir -p "$HOME/.config/clangd"
ln -sf "$REPO/config/clangd/config.yaml" "$HOME/.config/clangd/config.yaml"

echo "Done."
