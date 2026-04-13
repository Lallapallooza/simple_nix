#!/usr/bin/env bash
# Build a fully-inlined agent prompt for vs-core-rfc.
#
# Usage:
#   build-prompt.sh <role>
#
# Roles:
#   designer            Phase 3: one "design it twice" designer
#   adversarial-design  Phase 4: adversarial design reviewer
#   feasibility         Phase 4: feasibility reviewer (assumption checker)
#   revision-designer   Phase 4 revision loop: revise design based on merged findings
#
# Note: /vs-core-rfc invokes /vs-core-grill and /vs-core-research via the Skill
# tool (not as sub-agents). Only Phase 3-4 agents use this script.
#
# The coordinator appends task-specific context after the TASK-SPECIFIC CONTEXT marker.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$(cd "$SKILL_DIR/../vs-core-_shared" && pwd)"

# shellcheck source=../vs-core-_shared/lib-prompt.sh
source "$SHARED_DIR/lib-prompt.sh"

handle_tmp_mode "$SKILL_DIR/build-prompt.sh" "vs-rfc" "$@"

if [[ $# -lt 1 ]]; then
  echo "usage: $(basename "$0") [--tmp] <role>" >&2
  exit 2
fi

ROLE="$1"
shift

emit_universal

case "$ROLE" in
  designer)
    emit_section "SPEC METHODOLOGY"              "$SKILL_DIR/references/spec-methodology.md"
    emit_section "ROLE: DESIGNER"                "$SKILL_DIR/prompts/designer.md"
    ;;
  adversarial-design)
    emit_section "ADVERSARIAL FRAMING"           "$SHARED_DIR/prompts/adversarial-framing.md"
    emit_section "SPEC METHODOLOGY"              "$SKILL_DIR/references/spec-methodology.md"
    emit_section "ROLE: ADVERSARIAL DESIGN REVIEWER" "$SKILL_DIR/prompts/adversarial-design.md"
    ;;
  feasibility)
    emit_section "SPEC METHODOLOGY"              "$SKILL_DIR/references/spec-methodology.md"
    emit_section "ROLE: FEASIBILITY REVIEWER"    "$SKILL_DIR/prompts/feasibility.md"
    ;;
  revision-designer)
    emit_section "SPEC METHODOLOGY"              "$SKILL_DIR/references/spec-methodology.md"
    emit_section "ROLE: REVISION DESIGNER"       "$SKILL_DIR/prompts/revision-designer.md"
    ;;
  *)
    echo "build-prompt.sh: unknown role: $ROLE" >&2
    echo "expected one of: designer adversarial-design feasibility revision-designer" >&2
    exit 2
    ;;
esac

emit_task_marker
