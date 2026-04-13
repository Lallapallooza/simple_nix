#!/usr/bin/env bash
# Build a fully-inlined agent prompt for vs-core-implement.
#
# Usage:
#   build-prompt.sh <role> [lang1 lang2 ...]
#
# Roles:
#   planner         Phase 1: break feature into vertical slices
#   implementer     Phase 2a: implements one slice
#   slice-reviewer  Phase 2b: reviews one slice
#
# Languages (optional; used by all three roles):
#   rust python cpp go typescript    (unknown langs are skipped silently)
#
# The planner accepts language args because risk assessment, slice boundaries,
# and acceptance-criteria phrasing all depend on language idioms (lifetime
# rules in cpp, borrow checker in rust, async traps in python, etc.).
#
# The coordinator appends task-specific context after the TASK-SPECIFIC CONTEXT marker.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$(cd "$SKILL_DIR/../vs-core-_shared" && pwd)"

# shellcheck source=../vs-core-_shared/lib-prompt.sh
source "$SHARED_DIR/lib-prompt.sh"

handle_tmp_mode "$SKILL_DIR/build-prompt.sh" "vs-implement" "$@"

if [[ $# -lt 1 ]]; then
  echo "usage: $(basename "$0") [--tmp] <role> [langs...]" >&2
  exit 2
fi

ROLE="$1"
shift

emit_universal

case "$ROLE" in
  planner)
    emit_section "IMPLEMENTATION METHODOLOGY" "$SKILL_DIR/references/implementation-methodology.md"
    emit_lang_sections "$@"
    emit_section "ROLE: PLANNER"              "$SKILL_DIR/prompts/planner.md"
    ;;
  implementer)
    emit_section "IMPLEMENTATION METHODOLOGY" "$SKILL_DIR/references/implementation-methodology.md"
    emit_lang_sections "$@"
    emit_section "ROLE: IMPLEMENTER"          "$SKILL_DIR/prompts/implementer.md"
    ;;
  slice-reviewer)
    emit_section "ADVERSARIAL FRAMING"        "$SHARED_DIR/prompts/adversarial-framing.md"
    emit_section "IMPLEMENTATION METHODOLOGY" "$SKILL_DIR/references/implementation-methodology.md"
    emit_lang_sections "$@"
    emit_section "ROLE: SLICE REVIEWER"       "$SKILL_DIR/prompts/slice-reviewer.md"
    ;;
  *)
    echo "build-prompt.sh: unknown role: $ROLE" >&2
    echo "expected one of: planner implementer slice-reviewer" >&2
    exit 2
    ;;
esac

emit_task_marker
