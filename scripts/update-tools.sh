#!/usr/bin/env bash
set -euo pipefail

# -- Configuration -----------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="${SCRIPT_DIR}/../nixos"
OVERLAY_FILE="${FLAKE_DIR}/overlays/cli-tools.nix"
FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

# -- State -------------------------------------------------------------
DRY_RUN=false
TOOL_FILTER=""
UPDATED=()
SKIPPED=()
FAILED=()
UP_TO_DATE=()

# -- Argument parsing --------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --tool)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --tool requires a value"; exit 2
      fi
      TOOL_FILTER="$2"; shift 2 ;;
    *)         echo "Unknown argument: $1"; exit 2 ;;
  esac
done

# -- Helpers -----------------------------------------------------------

should_update() {
  local name="$1"
  [[ -z "$TOOL_FILTER" || "$TOOL_FILTER" == "$name" ]]
}

get_overlay_value() {
  local var="$1"
  sed -n "s/^  ${var} = \"\(.*\)\";$/\1/p" "$OVERLAY_FILE"
}

sedi() {
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

set_overlay_value() {
  local var="$1" value="$2"
  if $DRY_RUN; then
    echo "  [dry-run] would set ${var} = \"${value}\""
  else
    sedi "s|^  ${var} = \".*\";$|  ${var} = \"${value}\";|" "$OVERLAY_FILE"
  fi
}

version_gt() {
  [[ "$1" == "$2" ]] && return 1
  local IFS=.
  local -a a=($1) b=($2)
  local i max=$(( ${#a[@]} > ${#b[@]} ? ${#a[@]} : ${#b[@]} ))
  for (( i=0; i<max; i++ )); do
    local ai=${a[i]:-0} bi=${b[i]:-0}
    (( ai > bi )) && return 0
    (( ai < bi )) && return 1
  done
  return 1
}

github_api_curl() {
  local url="$1"
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    curl -sf -H "Authorization: Bearer $GITHUB_TOKEN" "$url"
  else
    curl -sf "$url"
  fi
}

# Compute source hash for a URL (instant, no build).
# For archives that will be unpacked (fetchzip/fetchFromGitHub), use --unpack.
prefetch_src_hash() {
  local url="$1" unpack="${2:-true}"
  if [[ "$unpack" == "true" ]]; then
    nix store prefetch-file --json --unpack "$url" 2>/dev/null | jq -r '.hash'
  else
    nix store prefetch-file --json "$url" 2>/dev/null | jq -r '.hash'
  fi
}

# Extract a FOD hash by building a single package from the flake.
# The package has a fake dep hash → nix build fails with "got: sha256-REAL".
# FRAGILE: relies on nix's error message format. If nix changes the "got:" line,
# this returns empty and the caller reverts (safe failure, but blocks updates).
# Usage: extract_fod_hash <package-attr>
extract_fod_hash() {
  local pkg="$1"
  echo "  extracting dep hash via nix build (downloads deps only, no compilation)..." >&2
  local output
  output=$(nix build "${FLAKE_DIR}#${pkg}" --no-link 2>&1 || true)
  local hash
  hash=$(echo "$output" | sed -n 's/.*got:[[:space:]]*\(sha256-[A-Za-z0-9+/=]*\).*/\1/p' | head -1 || true)
  if [[ -z "$hash" ]]; then
    echo "  nix build output (last 20 lines):" >&2
    echo "$output" | tail -20 >&2
  fi
  echo "$hash"
}

# -- Per-tool update functions -----------------------------------------
# All tools follow the same pattern:
#   1. Check latest version
#   2. Compute source hash via prefetch_src_hash (instant)
#   3. Write version + src hash + fake dep hash to overlay
#   4. Extract real dep hash via extract_fod_hash (downloads deps, ~1-5 min)
#   5. Write real dep hash — or revert on failure

update_claude_code() {
  local name="claude-code"
  echo "-- $name ----------------------------------"

  local current
  current=$(get_overlay_value claudeCodeVersion)
  echo "  current: ${current}"

  local latest
  latest=$(curl -sf "https://registry.npmjs.org/@anthropic-ai/claude-code/latest" | jq -r '.version' || true)
  if [[ -z "$latest" || "$latest" == "null" ]]; then
    echo "  FAILED: could not fetch latest version"
    FAILED+=("$name")
    return
  fi
  echo "  latest:  ${latest}"

  if ! version_gt "$latest" "$current"; then
    echo "  up to date"
    UP_TO_DATE+=("$name")
    return
  fi

  echo "  updating ${current} → ${latest}"

  local src_url="https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${latest}.tgz"

  echo "  computing source hash..."
  local src_hash
  src_hash=$(prefetch_src_hash "$src_url" true || true)
  if [[ -z "$src_hash" ]]; then
    echo "  FAILED: could not compute source hash"
    FAILED+=("$name")
    return
  fi
  echo "  src hash: ${src_hash}"

  # Save originals for revert
  local orig_version="$current"
  local orig_src_hash; orig_src_hash=$(get_overlay_value claudeCodeSrcHash)
  local orig_dep_hash; orig_dep_hash=$(get_overlay_value claudeCodeNpmDepsHash)

  # Write new version + src hash + fake dep hash
  set_overlay_value claudeCodeVersion "$latest"
  set_overlay_value claudeCodeSrcHash "$src_hash"
  set_overlay_value claudeCodeNpmDepsHash "$FAKE_HASH"

  if $DRY_RUN; then
    echo "  [dry-run] skipping dep hash extraction"
    set_overlay_value claudeCodeVersion "$orig_version"
    set_overlay_value claudeCodeSrcHash "$orig_src_hash"
    set_overlay_value claudeCodeNpmDepsHash "$orig_dep_hash"
    echo "  UPDATE AVAILABLE: ${current} → ${latest}"
    return
  fi

  local real_hash
  real_hash=$(extract_fod_hash claude-code)

  if [[ -n "$real_hash" ]]; then
    set_overlay_value claudeCodeNpmDepsHash "$real_hash"
    echo "  dep hash: ${real_hash}"
    echo "  UPDATED: ${current} → ${latest}"
    UPDATED+=("$name")
  else
    echo "  FAILED: could not extract dep hash, reverting"
    set_overlay_value claudeCodeVersion "$orig_version"
    set_overlay_value claudeCodeSrcHash "$orig_src_hash"
    set_overlay_value claudeCodeNpmDepsHash "$orig_dep_hash"
    FAILED+=("$name (hash extraction failed)")
  fi
}

update_gemini_cli() {
  local name="gemini-cli"
  echo "-- $name ----------------------------------"

  local current
  current=$(get_overlay_value geminiCliVersion)
  echo "  current: ${current}"

  local latest
  latest=$(github_api_curl "https://api.github.com/repos/google-gemini/gemini-cli/releases/latest" | jq -r '.tag_name' | sed 's/^v//' || true)
  if [[ -z "$latest" || "$latest" == "null" ]]; then
    echo "  FAILED: could not fetch latest version"
    FAILED+=("$name")
    return
  fi
  echo "  latest:  ${latest}"

  if ! version_gt "$latest" "$current"; then
    echo "  up to date"
    UP_TO_DATE+=("$name")
    return
  fi

  echo "  updating ${current} → ${latest}"

  local src_url="https://github.com/google-gemini/gemini-cli/archive/refs/tags/v${latest}.tar.gz"

  echo "  computing source hash..."
  local src_hash
  src_hash=$(prefetch_src_hash "$src_url" true || true)
  if [[ -z "$src_hash" ]]; then
    echo "  FAILED: could not compute source hash"
    FAILED+=("$name")
    return
  fi
  echo "  src hash: ${src_hash}"

  local orig_version="$current"
  local orig_src_hash; orig_src_hash=$(get_overlay_value geminiCliSrcHash)
  local orig_dep_hash; orig_dep_hash=$(get_overlay_value geminiCliNpmDepsHash)

  set_overlay_value geminiCliVersion "$latest"
  set_overlay_value geminiCliSrcHash "$src_hash"
  set_overlay_value geminiCliNpmDepsHash "$FAKE_HASH"

  if $DRY_RUN; then
    echo "  [dry-run] skipping dep hash extraction"
    set_overlay_value geminiCliVersion "$orig_version"
    set_overlay_value geminiCliSrcHash "$orig_src_hash"
    set_overlay_value geminiCliNpmDepsHash "$orig_dep_hash"
    echo "  UPDATE AVAILABLE: ${current} → ${latest}"
    return
  fi

  local real_hash
  real_hash=$(extract_fod_hash gemini-cli)

  if [[ -n "$real_hash" ]]; then
    set_overlay_value geminiCliNpmDepsHash "$real_hash"
    echo "  dep hash: ${real_hash}"
    echo "  UPDATED: ${current} → ${latest}"
    UPDATED+=("$name")
  else
    echo "  FAILED: could not extract dep hash, reverting"
    set_overlay_value geminiCliVersion "$orig_version"
    set_overlay_value geminiCliSrcHash "$orig_src_hash"
    set_overlay_value geminiCliNpmDepsHash "$orig_dep_hash"
    FAILED+=("$name (hash extraction failed)")
  fi
}

update_opencode() {
  local name="opencode"
  echo "-- $name ----------------------------------"

  local current
  current=$(get_overlay_value opencodeVersion)
  echo "  current: ${current}"

  local latest
  latest=$(github_api_curl "https://api.github.com/repos/anomalyco/opencode/releases/latest" | jq -r '.tag_name' | sed 's/^v//' || true)
  if [[ -z "$latest" || "$latest" == "null" ]]; then
    echo "  FAILED: could not fetch latest version"
    FAILED+=("$name")
    return
  fi
  echo "  latest:  ${latest}"

  if ! version_gt "$latest" "$current"; then
    echo "  up to date"
    UP_TO_DATE+=("$name")
    return
  fi

  echo "  updating ${current} → ${latest}"

  local src_url="https://github.com/anomalyco/opencode/archive/refs/tags/v${latest}.tar.gz"

  echo "  computing source hash..."
  local src_hash
  src_hash=$(prefetch_src_hash "$src_url" true || true)
  if [[ -z "$src_hash" ]]; then
    echo "  FAILED: could not compute source hash"
    FAILED+=("$name")
    return
  fi
  echo "  src hash: ${src_hash}"

  local orig_version="$current"
  local orig_src_hash; orig_src_hash=$(get_overlay_value opencodeSrcHash)
  local orig_dep_hash; orig_dep_hash=$(get_overlay_value opencodeNodeModulesHash)

  set_overlay_value opencodeVersion "$latest"
  set_overlay_value opencodeSrcHash "$src_hash"
  set_overlay_value opencodeNodeModulesHash "$FAKE_HASH"

  if $DRY_RUN; then
    echo "  [dry-run] skipping dep hash extraction"
    set_overlay_value opencodeVersion "$orig_version"
    set_overlay_value opencodeSrcHash "$orig_src_hash"
    set_overlay_value opencodeNodeModulesHash "$orig_dep_hash"
    echo "  UPDATE AVAILABLE: ${current} → ${latest}"
    return
  fi

  local real_hash
  real_hash=$(extract_fod_hash opencode)

  if [[ -n "$real_hash" ]]; then
    set_overlay_value opencodeNodeModulesHash "$real_hash"
    echo "  dep hash: ${real_hash}"
    echo "  UPDATED: ${current} → ${latest}"
    UPDATED+=("$name")
  else
    echo "  FAILED: could not extract dep hash, reverting"
    set_overlay_value opencodeVersion "$orig_version"
    set_overlay_value opencodeSrcHash "$orig_src_hash"
    set_overlay_value opencodeNodeModulesHash "$orig_dep_hash"
    FAILED+=("$name (hash extraction failed)")
  fi
}

update_codex() {
  local name="codex"
  echo "-- $name ----------------------------------"

  local current
  current=$(get_overlay_value codexVersion)
  echo "  current: ${current}"

  local latest
  latest=$(github_api_curl "https://api.github.com/repos/openai/codex/releases" \
    | jq -r '[.[] | select(.tag_name | test("^rust-v[0-9]+\\.[0-9]+\\.[0-9]+$"))][0].tag_name' \
    | sed 's/^rust-v//' || true)
  if [[ -z "$latest" || "$latest" == "null" ]]; then
    echo "  FAILED: could not fetch latest version"
    FAILED+=("$name")
    return
  fi
  echo "  latest:  ${latest}"

  if ! version_gt "$latest" "$current"; then
    echo "  up to date"
    UP_TO_DATE+=("$name")
    return
  fi

  echo "  updating ${current} → ${latest}"

  local src_url="https://github.com/openai/codex/archive/refs/tags/rust-v${latest}.tar.gz"

  echo "  computing source hash..."
  local src_hash
  src_hash=$(prefetch_src_hash "$src_url" true || true)
  if [[ -z "$src_hash" ]]; then
    echo "  FAILED: could not compute source hash"
    FAILED+=("$name")
    return
  fi
  echo "  src hash: ${src_hash}"

  # Check for librusty_v8 version change
  echo "  checking rusty_v8 version..."
  local tmpdir
  tmpdir=$(mktemp -d)

  if ! curl -sLf "$src_url" | tar xz -C "$tmpdir" 2>/dev/null; then
    echo "  FAILED: could not download source archive"
    rm -rf "$tmpdir"
    FAILED+=("$name")
    return
  fi

  local cargo_lock
  cargo_lock=$(find "$tmpdir" -path "*/codex-rs/Cargo.lock" | head -1)

  local current_v8_version
  current_v8_version=$(get_overlay_value codexLibrustyV8Version)
  local new_v8_version=""

  if [[ -n "$cargo_lock" && -f "$cargo_lock" ]]; then
    new_v8_version=$(awk '/^\[\[package\]\]/{found=0} /^name = "v8"/{found=1} found && /^version = /{gsub(/"/, "", $3); print $3; exit}' "$cargo_lock")
    echo "  rusty_v8: current=${current_v8_version} new=${new_v8_version}"
  else
    echo "  WARN: could not find Cargo.lock, skipping v8 version check"
  fi

  rm -rf "$tmpdir"

  # Save overlay snapshot for revert
  local overlay_backup
  overlay_backup=$(cat "$OVERLAY_FILE")

  # Write version + src hash
  set_overlay_value codexVersion "$latest"
  set_overlay_value codexSrcHash "$src_hash"

  # Update librusty_v8 platform hashes if version changed
  if [[ -n "$new_v8_version" && "$new_v8_version" != "$current_v8_version" ]]; then
    echo "  rusty_v8 version changed: ${current_v8_version} → ${new_v8_version}"
    set_overlay_value codexLibrustyV8Version "$new_v8_version"

    local -A platform_map=(
      [x86_64-linux]="x86_64-unknown-linux-gnu"
      [aarch64-linux]="aarch64-unknown-linux-gnu"
      [x86_64-darwin]="x86_64-apple-darwin"
      [aarch64-darwin]="aarch64-apple-darwin"
    )

    for nix_platform in x86_64-linux aarch64-linux x86_64-darwin aarch64-darwin; do
      local rust_target="${platform_map[$nix_platform]}"
      local v8_url="https://github.com/denoland/rusty_v8/releases/download/v${new_v8_version}/librusty_v8_release_${rust_target}.a.gz"
      echo "    prefetching ${nix_platform}..."
      local plat_hash
      plat_hash=$(prefetch_src_hash "$v8_url" false || true)
      if [[ -z "$plat_hash" ]]; then
        echo "    FAILED: could not prefetch ${nix_platform}, reverting"
        echo "$overlay_backup" > "$OVERLAY_FILE"
        FAILED+=("$name")
        return
      fi
      echo "    ${nix_platform}: ${plat_hash}"
      if ! $DRY_RUN; then
        sedi "/codexLibrustyV8Hashes/,/};/ s|${nix_platform} = \"sha256-[^\"]*\";|${nix_platform} = \"${plat_hash}\";|" "$OVERLAY_FILE"
      fi
    done
  else
    echo "  rusty_v8 version unchanged"
  fi

  # Set fake cargo dep hash
  set_overlay_value codexCargoHash "$FAKE_HASH"

  if $DRY_RUN; then
    echo "  [dry-run] skipping dep hash extraction"
    echo "$overlay_backup" > "$OVERLAY_FILE"
    echo "  UPDATE AVAILABLE: ${current} → ${latest}"
    return
  fi

  local real_hash
  real_hash=$(extract_fod_hash codex)

  if [[ -n "$real_hash" ]]; then
    set_overlay_value codexCargoHash "$real_hash"
    echo "  dep hash: ${real_hash}"
    echo "  UPDATED: ${current} → ${latest}"
    UPDATED+=("$name")
  else
    echo "  FAILED: could not extract dep hash, reverting"
    echo "$overlay_backup" > "$OVERLAY_FILE"
    FAILED+=("$name (hash extraction failed)")
  fi
}

# -- Main --------------------------------------------------------------

if [[ ! -f "$OVERLAY_FILE" ]]; then
  echo "ERROR: overlay file not found: ${OVERLAY_FILE}"
  exit 2
fi

echo "Overlay: ${OVERLAY_FILE}"
echo "Dry run: ${DRY_RUN}"
if [[ -n "$TOOL_FILTER" ]]; then
  echo "Tool filter: ${TOOL_FILTER}"
fi
echo ""

if should_update claude-code; then update_claude_code; else SKIPPED+=(claude-code); fi
echo ""

if should_update gemini-cli; then update_gemini_cli; else SKIPPED+=(gemini-cli); fi
echo ""

if should_update opencode; then update_opencode; else SKIPPED+=(opencode); fi
echo ""

if should_update codex; then update_codex; else SKIPPED+=(codex); fi
echo ""

# -- Summary -----------------------------------------------------------
echo "============================================"
echo "Summary"
echo "============================================"

if [[ ${#UPDATED[@]} -gt 0 ]]; then
  echo "  Updated:     ${UPDATED[*]}"
fi
if [[ ${#UP_TO_DATE[@]} -gt 0 ]]; then
  echo "  Up to date:  ${UP_TO_DATE[*]}"
fi
if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo "  Failed:      ${FAILED[*]}"
fi
if [[ ${#SKIPPED[@]} -gt 0 ]]; then
  echo "  Skipped:     ${SKIPPED[*]}"
fi

if [[ ${#FAILED[@]} -gt 0 ]]; then
  exit 2   # failures occurred (even if some tools updated)
elif [[ ${#UPDATED[@]} -gt 0 ]]; then
  exit 0   # all requested updates applied
else
  exit 1   # everything up to date
fi
