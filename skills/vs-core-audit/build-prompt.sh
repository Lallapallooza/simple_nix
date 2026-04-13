#!/usr/bin/env bash
# Build a fully-inlined reviewer prompt for vs-core-audit.
#
# Usage:
#   build-prompt.sh <reviewer-type> [lang1 lang2 ...]
#
# Reviewer types:
#   logic-tracer         primary code reviewer; accepts language judgment
#   architecture         structure/pattern reviewer; accepts language judgment
#   caller-perspective   consumer-side reviewer; no language judgment
#   non-code-reviewer    docs/specs/configs/prompts reviewer
#
# Languages (optional; only used by logic-tracer and architecture):
#   rust python cpp go typescript    (unknown langs are skipped silently)
#
# The coordinator must append task-specific context after the
# TASK-SPECIFIC CONTEXT marker on stdout, then pass the whole string as the
# `prompt` parameter of the Agent tool.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$(cd "$SKILL_DIR/../vs-core-_shared" && pwd)"

# shellcheck source=../vs-core-_shared/lib-prompt.sh
source "$SHARED_DIR/lib-prompt.sh"

# If called with --tmp as the first arg, write inlined content to a new temp
# file and print only the path (keeps the orchestrator's context clean -- the
# 40-130KB reference bundle stays in the temp file until the sub-agent Read()s
# it). If --tmp is NOT the first arg, this returns and the script continues
# normally, writing full content to stdout.
handle_tmp_mode "$SKILL_DIR/build-prompt.sh" "vs-audit" "$@"

if [[ $# -lt 1 ]]; then
  echo "usage: $(basename "$0") [--tmp] <reviewer-type> [langs...]" >&2
  exit 2
fi

REVIEWER="$1"
shift

emit_universal

case "$REVIEWER" in
  logic-tracer)
    emit_section "ADVERSARIAL FRAMING"         "$SHARED_DIR/prompts/adversarial-framing.md"
    emit_section "REVIEW METHODOLOGY"          "$SKILL_DIR/references/review-methodology.md"
    emit_section "EVIDENCE STANDARDS"          "$SKILL_DIR/references/evidence-standards.md"
    emit_lang_sections "$@"
    emit_section "ROLE: LOGIC TRACER"          "$SKILL_DIR/prompts/logic-tracer.md"
    ;;
  architecture)
    emit_section "SEVERITY CALIBRATION"        "$SKILL_DIR/references/severity-calibration.md"
    emit_section "EVIDENCE STANDARDS"          "$SKILL_DIR/references/evidence-standards.md"
    emit_lang_sections "$@"
    emit_section "ROLE: ARCHITECTURE REVIEWER" "$SKILL_DIR/prompts/architecture.md"
    ;;
  caller-perspective)
    emit_section "EVIDENCE STANDARDS"          "$SKILL_DIR/references/evidence-standards.md"
    emit_section "ROLE: CALLER-PERSPECTIVE REVIEWER" "$SKILL_DIR/prompts/caller-perspective.md"
    ;;
  non-code-reviewer)
    emit_section "EVIDENCE STANDARDS"          "$SKILL_DIR/references/evidence-standards.md"
    emit_section "SEVERITY CALIBRATION"        "$SKILL_DIR/references/severity-calibration.md"
    emit_section "ARTIFACT METHODOLOGY"        "$SKILL_DIR/references/artifact-methodology.md"
    emit_section "ROLE: NON-CODE REVIEWER"     "$SKILL_DIR/prompts/non-code-reviewer.md"
    ;;
  *)
    echo "build-prompt.sh: unknown reviewer type: $REVIEWER" >&2
    echo "expected one of: logic-tracer architecture caller-perspective non-code-reviewer" >&2
    exit 2
    ;;
esac

emit_task_marker
