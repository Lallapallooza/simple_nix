#!/usr/bin/env bash
# Check markdown files for non-human unicode (AI writing tell).
# Usage: ./check-unicode.sh [path...]
# Defaults to current directory if no path given.

set -euo pipefail

paths=("${@:-.}")

# Characters that no human types on a regular keyboard.
# Em-dash, en-dash, arrows, box-drawing, smart quotes, math symbols, check marks.
# Using hex escapes to avoid shell quoting issues with unicode.
pattern=$'\xe2\x80\x94|\xe2\x80\x93|\xe2\x86\x92|\xe2\x86\x90|\xe2\x86\x94|\xe2\x94\x80|\xe2\x95\x90|\xe2\x95\x91|\xe2\x95\x94|\xe2\x95\x97|\xe2\x95\x9a|\xe2\x95\x9d|\xe2\x95\xa0|\xe2\x95\xa3|\xe2\x95\xa6|\xe2\x95\xa9|\xe2\x95\xac|\xe2\x94\x82|\xe2\x80\x9c|\xe2\x80\x9d|\xe2\x80\x98|\xe2\x80\x99|\xe2\x9c\x93|\xe2\x9c\x97|\xe2\x89\xa0|\xe2\x89\xa4|\xe2\x89\xa5|\xe2\x89\x88|\xc3\x97|\xc2\xb7|\xe2\x80\xa6'

total=0
declare -A char_counts

while IFS= read -r line; do
  file="${line%%:*}"
  rest="${line#*:}"
  lineno="${rest%%:*}"
  content="${rest#*:}"

  while IFS= read -r ch; do
    [[ -z "$ch" ]] && continue
    char_counts["$ch"]=$(( ${char_counts["$ch"]:-0} + 1 ))
    total=$(( total + 1 ))
  done < <(echo "$content" | grep -oP "$pattern")

done < <(grep -rPn "$pattern" --include='*.md' "${paths[@]}" 2>/dev/null || true)

if (( total == 0 )); then
  echo "Clean -- no non-human unicode found."
  exit 0
fi

# Per-file counts
echo "=== Files with non-human unicode ==="
echo ""
grep -rPc "$pattern" --include='*.md' "${paths[@]}" 2>/dev/null \
  | grep -v ':0$' \
  | sort -t: -k2 -rn \
  | head -30
echo ""

# Character breakdown
echo "=== Character counts ==="
echo ""
for ch in "${!char_counts[@]}"; do
  printf "%6d  %s\n" "${char_counts[$ch]}" "$ch"
done | sort -rn
echo ""

# Replacements cheat sheet
echo "=== Suggested replacements ==="
echo ""
cat <<'REPLACEMENTS'
  em-dash/en-dash  ->  --
  arrows           ->  ->
  box-drawing      ->  -
  smart quotes     ->  " or '
  not-equal        ->  !=
  less-equal       ->  <=
  greater-equal    ->  >=
  multiplication   ->  x
  ellipsis         ->  ...
REPLACEMENTS
echo ""
echo "Total: $total non-human unicode characters found."
exit 1
