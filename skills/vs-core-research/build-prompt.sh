#!/usr/bin/env bash
# Build a fully-inlined researcher prompt for vs-core-research.
#
# Usage:
#   build-prompt.sh <role>
#
# Roles:
#   source              primary source researcher (wide-net, lateral reading)
#   contrarian          counterevidence hunter, failure-mode searcher
#   codebase            codebase investigator (dispatched with subagent_type: Explore)
#   deep-technical      academic-depth researcher (papers, citations)
#   verification        post-synthesis fact-checker (MANDATORY except for single-source trivial queries)
#
# The coordinator appends task-specific context after the TASK-SPECIFIC CONTEXT marker.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$(cd "$SKILL_DIR/../vs-core-_shared" && pwd)"

# shellcheck source=../vs-core-_shared/lib-prompt.sh
source "$SHARED_DIR/lib-prompt.sh"

handle_tmp_mode "$SKILL_DIR/build-prompt.sh" "vs-research" "$@"

if [[ $# -lt 1 ]]; then
  echo "usage: $(basename "$0") [--tmp] <role>" >&2
  exit 2
fi

ROLE="$1"
shift

emit_universal

case "$ROLE" in
  source)
    emit_section "SOURCE EVALUATION"    "$SKILL_DIR/references/source-evaluation.md"
    emit_section "SEARCH STRATEGY"      "$SKILL_DIR/references/search-strategy.md"
    emit_section "ROLE: SOURCE RESEARCHER" "$SKILL_DIR/prompts/source-researcher.md"
    ;;
  contrarian)
    emit_section "RESEARCH METHODOLOGY" "$SKILL_DIR/references/research-methodology.md"
    emit_section "SOURCE EVALUATION"    "$SKILL_DIR/references/source-evaluation.md"
    emit_section "ROLE: CONTRARIAN RESEARCHER" "$SKILL_DIR/prompts/contrarian-researcher.md"
    ;;
  codebase)
    emit_section "CODEBASE INVESTIGATION" "$SKILL_DIR/references/codebase-investigation.md"
    emit_section "ROLE: CODEBASE INVESTIGATOR" "$SKILL_DIR/prompts/codebase-investigator.md"
    ;;
  deep-technical)
    emit_section "SEARCH STRATEGY"      "$SKILL_DIR/references/search-strategy.md"
    emit_section "SOURCE EVALUATION"    "$SKILL_DIR/references/source-evaluation.md"
    emit_section "ROLE: DEEP TECHNICAL RESEARCHER" "$SKILL_DIR/prompts/deep-technical-researcher.md"
    ;;
  verification)
    emit_section "SOURCE EVALUATION"    "$SKILL_DIR/references/source-evaluation.md"
    emit_section "ROLE: VERIFICATION AGENT" "$SKILL_DIR/prompts/verification-agent.md"
    ;;
  *)
    echo "build-prompt.sh: unknown role: $ROLE" >&2
    echo "expected one of: source contrarian codebase deep-technical verification" >&2
    exit 2
    ;;
esac

emit_task_marker
