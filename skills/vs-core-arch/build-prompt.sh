#!/usr/bin/env bash
# Build a fully-inlined agent prompt for vs-core-arch.
#
# Usage:
#   build-prompt.sh <role>
#
# Roles:
#   analyst     Analysis-mode agent (reviews existing architecture)
#   designer    Design-mode agent (produces one design in a "design it twice" round)
#
# Both roles receive all four judgment files -- analysts and designers both
# need the full vocabulary (interface, coupling, system, failure/scale).
#
# The coordinator appends task-specific context after the TASK-SPECIFIC CONTEXT marker.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$(cd "$SKILL_DIR/../vs-core-_shared" && pwd)"

# shellcheck source=../vs-core-_shared/lib-prompt.sh
source "$SHARED_DIR/lib-prompt.sh"

handle_tmp_mode "$SKILL_DIR/build-prompt.sh" "vs-arch" "$@"

if [[ $# -lt 1 ]]; then
  echo "usage: $(basename "$0") [--tmp] <role>" >&2
  exit 2
fi

ROLE="$1"
shift

emit_universal

emit_arch_judgment() {
  emit_section "INTERFACE DESIGN"         "$SKILL_DIR/references/interface-design.md"
  emit_section "COMPLEXITY AND COUPLING"  "$SKILL_DIR/references/complexity-and-coupling.md"
  emit_section "SYSTEM ARCHITECTURE"      "$SKILL_DIR/references/system-architecture.md"
  emit_section "FAILURE AND SCALE"        "$SKILL_DIR/references/failure-and-scale.md"
}

case "$ROLE" in
  analyst)
    emit_arch_judgment
    emit_section "ROLE: ANALYST"  "$SKILL_DIR/prompts/analyst.md"
    ;;
  designer)
    emit_arch_judgment
    emit_section "ROLE: DESIGNER" "$SKILL_DIR/prompts/designer.md"
    ;;
  *)
    echo "build-prompt.sh: unknown role: $ROLE" >&2
    echo "expected one of: analyst designer" >&2
    exit 2
    ;;
esac

emit_task_marker
