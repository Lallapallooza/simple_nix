#!/usr/bin/env bash
# Replace non-human unicode with ASCII equivalents in markdown files.
# Usage: ./fix-unicode.sh [path...]
# Defaults to current directory if no path given.

set -euo pipefail

paths=("${@:-.}")

# Collect all .md files
mapfile -t files < <(find "${paths[@]}" -name '*.md' -type f)

if (( ${#files[@]} == 0 )); then
  echo "No markdown files found."
  exit 0
fi

total=0
for f in "${files[@]}"; do
  before=$(wc -c < "$f")
  # Em-dash and en-dash -> --
  sed -i 's/—/--/g; s/–/--/g' "$f"
  # Arrows -> ->
  sed -i 's/→/->/g; s/←/<-/g; s/↔/<->/g' "$f"
  # Box-drawing -> -
  sed -i 's/[─═]/-/g; s/[│║]/|/g; s/[╔╗╚╝╠╣╦╩╬]/+/g' "$f"
  # Smart quotes -> straight quotes
  sed -i 's/[""]/"/g' "$f"
  sed -i "s/['']/'/g" "$f"
  # Math symbols
  sed -i 's/≠/!=/g; s/≤/<=/g; s/≥/>=/g; s/≈/~/g; s/×/x/g' "$f"
  # Check marks
  sed -i 's/✓/[x]/g; s/✗/[ ]/g' "$f"
  # Middle dot -> *
  sed -i 's/·/*/g' "$f"
  # Ellipsis -> ...
  sed -i 's/…/.../g' "$f"
  after=$(wc -c < "$f")
  if (( before != after )); then
    diff=$(( before - after ))
    echo "  fixed: $f ($diff bytes changed)"
    total=$(( total + 1 ))
  fi
done

echo ""
echo "Done. $total files modified out of ${#files[@]} scanned."
