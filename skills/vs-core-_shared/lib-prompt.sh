# Shared plumbing for skill-specific build-prompt.sh scripts.
#
# Source this from a skill's build-prompt.sh AFTER setting:
#   SKILL_DIR   -- absolute path to the skill directory (contains build-prompt.sh)
#   SHARED_DIR  -- absolute path to vs-core-_shared
#
# Then call emit_universal, emit_section, emit_lang_sections, emit_task_marker
# to compose the sub-agent prompt on stdout. All sections are concatenated
# verbatim -- no summarization, no truncation.

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "lib-prompt: missing reference file: $1" >&2
    exit 3
  fi
}

emit_section() {
  local title="$1"
  local path="$2"
  require_file "$path"
  local rel="${path#"$SKILL_DIR/"}"
  rel="${rel#"$SHARED_DIR/"}"
  printf '\n\n========== %s ==========\n(source: %s)\n\n' "$title" "$rel"
  cat "$path"
}

# Sections every dispatching skill needs: trust boundary, output format,
# rationalization rejection, self-critique. Keep this list in sync across
# skills -- if a skill genuinely doesn't need one, call emit_section directly
# instead of emit_universal.
emit_universal() {
  emit_section "TRUST BOUNDARY"            "$SHARED_DIR/prompts/trust-boundary.md"
  emit_section "OUTPUT FORMAT"             "$SHARED_DIR/prompts/output-format.md"
  emit_section "RATIONALIZATION REJECTION" "$SHARED_DIR/prompts/rationalization-rejection.md"
  emit_section "SELF-CRITIQUE PROTOCOL"    "$SHARED_DIR/prompts/self-critique-suffix.md"
}

# Emit one JUDGMENT section per name whose judgment file exists. Names map to
# files at $SHARED_DIR/prompts/language-specific/${name}-judgment.md. Pass
# language names (rust, python, cpp, go, typescript) and/or universal names
# (perf for performance-sensitive work). Unknown names are skipped silently
# (consistent with skip-when-no-match policy in vs-core-audit SKILL.md Step 1b).
emit_lang_sections() {
  local name f
  for name in "$@"; do
    f="$SHARED_DIR/prompts/language-specific/${name}-judgment.md"
    if [[ -f "$f" ]]; then
      emit_section "JUDGMENT: ${name}" "$f"
    fi
  done
}

emit_task_marker() {
  cat <<'EOF'


========== TASK-SPECIFIC CONTEXT ==========
(The coordinator appends scope, files to review, and focus areas below.)

EOF
}

# --tmp mode handler. Each skill's build-prompt.sh should call this right
# after computing SKILL_DIR, passing:
#   $1  absolute path to the calling script (use "$SKILL_DIR/build-prompt.sh")
#   $2  short prefix for mktemp (e.g. "vs-audit")
#   $@  remaining user args (pass with "$@" from the caller)
#
# If the first user arg is "--tmp", this function writes the script's normal
# output to a fresh temp file, prints only the path, and exits. Otherwise it
# returns so the script continues in normal (stdout) mode.
handle_tmp_mode() {
  local self="$1"
  local prefix="$2"
  shift 2
  if [[ "${1:-}" == "--tmp" ]]; then
    shift
    local tmp_file
    tmp_file=$(mktemp -t "${prefix}.XXXXXXXX.md")
    "$self" "$@" > "$tmp_file"
    echo "$tmp_file"
    exit 0
  fi
}
