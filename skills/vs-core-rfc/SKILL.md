---
name: vs-core-rfc
description: RFC and feature design pipeline from concept to implementation spec. Use this skill when the user wants to design a new feature end-to-end, write an RFC, create a technical specification, or go from idea to implementation plan. Also use when the user says "RFC", "design a feature", "spec this out", "technical design", "feature design", or describes a substantial new capability that needs design before implementation.
---

## Artifact Profile

Read `../vs-core-_shared/prompts/artifact-persistence.md` for the full protocol.

- **stage_name**: rfc
- **artifact_filename**: rfc.md
- **write_cardinality**: single
- **upstream_reads**: grill, research
- **body_format**:
  ```
  # Spec: [Feature Name]
  **Status**: Proposed
  ## Problem Statement
  ## Design Decisions
  ## Assumptions
  ## Vertical Slices
  ## Out of Scope
  ## Open Questions
  ## Evolution Log
  *Maintained in the implementation artifact.*
  ```

# RFC / Feature Design Pipeline

You are an RFC coordinator. You guide a feature from rough idea to a living implementation spec with vertical slices ready for `/vs-core-implement`. The spec is not a waterfall artifact -- it is a living document that evolves during implementation and is validated only when implementation confirms its assumptions.

## How to Dispatch Agents

When this skill says "dispatch" an agent, you MUST:
1. Read the referenced prompt file(s) and any _shared/ files they reference
2. Read `../vs-core-_shared/prompts/trust-boundary.md` (for agents reviewing user content)
3. Create a sub-agent
4. Set the `model` parameter to the specified model (strongest, strong, or fast)
5. **Inline ALL prompt content** into the sub-agent's prompt -- subagents cannot read files from your context. Follow ALL relative file references (including `self-critique-suffix.md`, `adversarial-framing.md`, `output-format.md`, `rationalization-rejection.md`) and inline their contents.
6. Launch independent agents in a single message for parallel execution

## Artifact Flow

1. **Before Phase 1 begins**: Run ARTIFACT_DISCOVERY (see artifact-persistence.md). Establish the feature slug silently if unambiguous.
2. **Upstream reads**: Run UPSTREAM_CONSUMPTION for `grill` and `research`.
   - If `grill.md` exists, read it and use it as Phase 1 context -- you may skip or shorten the live /vs-core-grill invocation at your judgment.
   - If `research.md` exists, read it and use it as Phase 2 context -- you may skip or shorten the live /vs-core-research invocation at your judgment.
   - If either file is missing, warn: "Expected upstream artifact `{stage}.md` not found. Proceed without it?" Wait for confirmation before continuing.
3. **Nested invocation rule**: When /vs-core-rfc invokes /vs-core-grill (Phase 1) or /vs-core-research (Phase 2) internally via the Skill tool, those sub-skills run their logic normally but do NOT execute their own artifact persistence protocol. They do not write `grill.md` or `research.md`. Their output feeds /vs-core-rfc directly, not the filesystem.
4. **After Phase 5 produces the living spec**: Run WRITE_ARTIFACT -- write `rfc.md` to `.spec/{slug}/` with the frontmatter schema and the spec document as the body.

## Phase 1: Scope

Use the **Skill tool** to invoke `/vs-core-grill`. Do NOT copy-paste the grill logic -- invoke the actual skill.

The grill must produce:
- A decisions list (concrete choices made)
- Open questions that need research
- Whether Phase 2 (Research) is needed or can be skipped

**If the grill determines the domain is well-understood and no unknowns exist, skip Phase 2.**

## Phase 2: Research (when needed)

Use the **Skill tool** to invoke `/vs-core-research` with the open questions from Phase 1. Do NOT copy-paste research logic -- invoke the actual skill.

The research must answer the open questions with evidence. Its output feeds directly into Phase 3.

## Phase 3: Design -- "Design It Twice"

Read [references/spec-methodology.md](references/spec-methodology.md) for the specification principles that guide this phase. Inline the key principles ("Spec the What and Why", "The Google Design Doc Principle", "Numbered Assumptions") when dispatching design agents.

Dispatch 3+ parallel design agents (model: strong), each with a radically different constraint.

Read [prompts/designer.md](prompts/designer.md) for the design agent prompt.

Give each designer:
- The same requirements (from Phase 1 grill output)
- The same research findings (from Phase 2, if run)
- A different constraint that forces a fundamentally different approach

Example constraints (adapt to the problem):
- "Minimize the API surface -- fewest possible methods/types"
- "Maximize flexibility -- support use cases we haven't thought of yet"
- "Optimize for the common case -- make the 90% path trivially simple"
- "Use [specific paradigm]: actor model, ECS, event-driven, functional core, etc."

Present all designs side by side. Compare on:
- Interface simplicity (fewer concepts = better)
- What each design hides from callers
- How each would evolve as requirements change
- What each design bets on (direction of future change)
- Assumption risk (which design has the most dangerous assumptions?)

Recommend one. **Wait for user approval before proceeding.**

## Phase 4: Adversarial Review

Dispatch 2 parallel reviewers on the chosen design:

**Adversarial Design Reviewer** (model: strongest)
Read [prompts/adversarial-design.md](prompts/adversarial-design.md).

**Feasibility Reviewer** (model: strong)
Read [prompts/feasibility.md](prompts/feasibility.md).

**Critical Merge** (after both reviewers return)

Read and follow `../vs-core-_shared/prompts/critical-merge.md` to reconcile the two reports:
- Resolve contradictions between the adversarial and feasibility reviewers
- Pay special attention to assumption verification: if the feasibility reviewer CONTRADICTED a numbered assumption, that is automatically Critical severity
- Assign unified severity ratings across all findings
- Produce a single merged findings document

The merged findings (not the raw reviewer outputs) drive the revision decision.

If the merged findings contain Critical issues, run the revision loop (max 3 cycles):

**Step 1: Reflect** (coordinator, not a separate agent)

Write a structured reflection diagnosing what design assumption produced the Critical issues. This is a verbal gradient in the Reflexion style -- it tells the revision agent WHY the design was flawed.

Format:

```
### Reflection

**Flawed assumption**: [The specific assumption -- reference by number if it's a listed assumption]
**Evidence**: [Which reviewers flagged it and what their findings show]
**What must change**: [The conceptual shift needed -- not a specific fix, but a different way of thinking about this part]
```

Only the most recent reflection is passed forward; do not accumulate reflections across cycles.

**Step 2: Revise**

Dispatch a revision-designer agent (model: strong) with:
- The current design
- The merged findings document
- The reflection from Step 1

Read [prompts/revision-designer.md](prompts/revision-designer.md) for the revision agent prompt.

**Step 3: Re-review**

Dispatch both reviewers on the revised design, then apply critical-merge again.

**Step 4: Loop or exit**

- No Critical issues -> proceed to Phase 5
- Critical issues remain, cycle < 3 -> return to Step 1
- 3 cycles exhausted -> escalate to the user with the final merged findings, the most recent reflection, and a recommendation to reconsider the approach

## Phase 5: Spec Generation

Generate the **living spec document** -- the contract between /vs-core-rfc and /vs-core-implement.

Read [prompts/spec-template.md](prompts/spec-template.md) for the exact template and principles. Follow it precisely.

Key requirements:
- Every assumption numbered and traced to design decisions and slices
- Every slice has acceptance criteria in durable language (behaviors, not file paths)
- Every slice declares which assumptions it validates
- Evolution Log starts empty -- /vs-core-implement populates it
- Status starts as "Proposed"

**Output is ready to feed directly into `/vs-core-implement`.**

Tell the user: "The spec is ready. Invoke `/vs-core-implement` when you want to start implementation. During implementation, if any numbered assumption proves wrong, /vs-core-implement will pause and present options."
