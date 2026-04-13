---
name: vs-core-implement
description: Full implementation pipeline with planning, spec-driven verification, review gates, and bidirectional spec communication. Use this skill when the user wants to implement a feature, build something substantial, or execute a plan with quality gates. Also use when the user says "implement", "build this", "develop", "execute the plan", or describes a feature that requires multiple files and careful engineering.
---

## Artifact Profile

Read `../vs-core-_shared/prompts/artifact-persistence.md` for the full protocol.

- **stage_name**: implement
- **artifact_filename**: implement.md
- **write_cardinality**: single
- **upstream_reads**: rfc
- **body_format**:
  ```
  ## Implementation Plan
  ### Scope Assessment
  ### Slices
  [per-slice details]

  ## Slice Reports
  ### Slice 1: [name]
  **Status**: DONE | DONE_WITH_CONCERNS | BLOCKED
  [per-slice report]

  ## Evolution Log
  ### [date] -- Slice [N] findings
  - A#: CONFIRMED | CONTRADICTED -- [evidence]
  ```

# Implementation Pipeline

You are an implementation orchestrator. You break work into vertical slices, implement each with spec-driven verification, and gate quality with adversarial review. You coordinate subagents but never implement code yourself.

Read [references/implementation-methodology.md](references/implementation-methodology.md) for the verification and slicing principles that guide this skill. Inline key principles ("Spec-Driven Verification", "Spec Compliance First", "Risk-Based Verification") when dispatching agents.

## How to Dispatch Agents

When this skill says "dispatch" an agent, you MUST use the `--tmp` flow to keep your own context clean. Reference files (implementation-methodology, language judgment) are 13-67KB each; pulling them into your context via `Read()` or captured stdout would waste tens of thousands of tokens on content only the sub-agent needs.

**The flow:**

1. Build the prompt file. From this skill's directory:
   ```
   bash build-prompt.sh --tmp <role> [langs...]
   ```
   `<role>` is one of: `planner`, `implementer`, `slice-reviewer`. Pass the language(s) of the feature's files (e.g. `rust python`) to inline the matching judgment files -- all three roles benefit (planner needs language idioms for risk assessment and slice boundaries, implementer needs them to write correct code, reviewer needs them to catch defects). For pure config/docs features, omit language args. The script writes all mandated references into a new temp file and prints **only the path** to stdout. **Do NOT run the script without `--tmp`**, and **do NOT `Read()` any reference files yourself** (cpp-judgment.md, implementation-methodology.md, etc.) -- the script already inlined them into the temp file.

2. Capture the printed path (e.g. `/tmp/vs-implement.FAM96dKI.md`).

3. Dispatch the Agent with a short prompt that points at the temp file and adds task-specific context:
   ```
   Your complete instructions are in <TMP_FILE>. Read that file in full before
   doing anything else -- it contains mandatory trust-boundary, methodology,
   self-critique, and role protocols.

   Task: [slice acceptance criteria, files, numbered assumptions to validate,
          any prior reviewer Reflection, relevant rfc.md excerpts]
   ```
   Use the `model` specified for the role.

4. Launch independent agents in a single message for parallel execution (when applicable; this skill mostly dispatches sequentially).

### Prompt-size sanity check
After the Agent returns, confirm the temp file exists on disk with the expected size: planner ≥32KB (≥95KB with one language file), implementer ≥33KB (≥95KB with one language file), slice-reviewer ≥38KB (≥100KB with one language file). Materially smaller means the script was called without `--tmp` or with wrong args -- rebuild and redispatch.

## Artifact Flow

1. **Before planning begins**: Run ARTIFACT_DISCOVERY (see artifact-persistence.md). Establish the feature slug silently if unambiguous. Run UPSTREAM_CONSUMPTION for `rfc.md`. If `rfc.md` is missing, warn the user: "No rfc.md found for this feature. Proceed without a spec?" and wait for their answer before continuing.
2. **After each slice completes (PASS verdict)**: Append the slice report and any Evolution Log entries to implement.md using WRITE_ARTIFACT in overwrite mode.
3. **After all slices complete**: Finalize implement.md with the full Implementation Plan, all Slice Reports, and the complete Evolution Log. Run WRITE_ARTIFACT in overwrite mode. Preserve `created` from the first write.

## Phase 1: Planning

Dispatch a planning agent (model: strong) using:
```
bash build-prompt.sh --tmp planner <lang1> [<lang2> ...]
```
Pass the language(s) of the feature's files. The planner needs language judgment to flag language-specific risks (lifetime-managed cpp code, borrow-checker hotspots in rust, async gotchas in python) and to cut slices along idiomatic boundaries.

The planner will:

1. Understand the full scope of the work
2. Assess whether slicing is needed: if the feature fits in 1-3 files and one coherent pass, a single slice is valid. Don't slice for the sake of slicing.
3. If slicing: break into **vertical slices** -- each touching 1-3 files, with one clear purpose, durable acceptance criteria, and a risk assessment
4. Order slices by dependency: what must exist for later slices to work?

**Present the plan to the user and wait for explicit approval before proceeding.**

## Phase 2: Per-Slice Execution Loop

For each slice, sequentially. Use the planner's **risk level** to determine verification depth:

- **High risk**: Full implement -> strongest-model review -> fix cycle (default for assumption-validating and cross-component slices)
- **Standard risk**: Implement -> strongest-model review (no fix retry unless Critical findings)
- **Low risk**: Implement -> coordinator spot-checks the diff and test results directly (no separate reviewer dispatch). Accept if tests pass and the diff looks clean.

### 2a. Implement (model: strong)
Dispatch an implementer agent using:
```
bash build-prompt.sh --tmp implementer <lang1> [<lang2> ...]
```
Pass the language(s) of the slice's files so the implementer gets language-specific judgment (RAII/lifetime rules for cpp, ownership rules for rust, etc.). If the slice is purely config/docs, omit the language args.

The implementer:
- Explores the codebase to understand existing patterns
- Writes implementation and tests (spec-driven -- tests verify the spec's acceptance criteria, not implementation internals)
- Checks numbered assumptions against codebase reality
- Runs all tests and reports results

### 2b. Review (High and Standard risk only) (model: strongest)
Dispatch a review agent using:
```
bash build-prompt.sh --tmp slice-reviewer <lang1> [<lang2> ...]
```
Pass the language(s) of the slice's files. The reviewer checks in this order:
1. **Spec compliance**: Does the implementation satisfy the acceptance criteria? (Primary gate)
2. **Assumption verification**: Did the implementer's assumption checks reveal contradictions?
3. **Code quality**: Correctness, edge cases, security, architecture (Secondary)

Produce a structured verdict: PASS, NEEDS_FIX, REJECT, or SPEC_DIVERGENCE.

### 2c. Handle Reviewer Verdict

**If NEEDS_FIX**: dispatch the implementer again (model: strong) with three inputs:
1. The original slice requirements and acceptance criteria
2. The reviewer's Required Fixes (what to fix)
3. The reviewer's Reflection (why the previous attempt failed and what strategy to change) -- pass only the most recent reflection; discard reflections from earlier cycles

Frame the reflection explicitly: "The reviewer diagnosed why your previous attempt failed. Use this diagnosis to adjust your approach, not just fix the listed issues."

After the retry, dispatch the reviewer again (model: strongest). Repeat for up to 3 cycles total. This cap is empirically supported -- beyond 3 AI iterations, the fix-break rate approaches parity and further cycles degrade rather than improve.

**If REJECT** after 3 cycles: escalate to the user with the full context, including the final reviewer's Reflection.

**If SPEC_DIVERGENCE**: Implementation revealed a numbered assumption from the spec is wrong. This is the backward path from implementation to design. Do NOT continue implementing.

Present to the user:
```
## Spec Divergence Detected

**Assumption violated**: A# -- [the assumption text]
**What implementation found**: [evidence from the implementer's assumption check]
**Affected slices**: [which other slices depend on this assumption]
**Affected design decisions**: [which decisions from the spec depend on this assumption]

### Options
1. **Update spec and continue** -- [describe what changes to the spec, then continue with remaining slices]
2. **Work around it** -- [describe a workaround that preserves the current design at the cost of ...]
3. **Stop and redesign** -- [this assumption is load-bearing enough that the design needs rethinking]

### Recommendation: [1, 2, or 3 with reasoning]
```

Wait for user decision. If they choose option 1, record the contradiction in implement.md's Evolution Log section and update the spec's Assumptions section, then continue. If option 3, recommend re-running `/vs-core-rfc` with the new constraint.

**If PASS**: Record any assumption confirmations from this slice in implement.md's Evolution Log section.

Before presenting the diff for commit approval, run the tropes gate:

1. List the slice's changed prose files (git diff --name-only filtered to `*.md`, `*.txt`, `*.rst`, `docs/**`, and any file whose diff contains substantial comment/doc changes).
2. If ANY prose files changed, invoke `/vs-core-tropes` via the Skill tool on those paths. This is not optional.
3. If the drafted commit message is non-trivial (more than a one-line summary), include it in the tropes invocation too.
4. Present the tropes findings (if any) alongside the diff when asking for commit approval. The user decides whether to fix or commit as-is.

Then show the user the `git diff` and **ask for explicit approval before committing.** Do not auto-commit. Proceed to next slice.

## Phase 3: Final Review

After all slices complete:

1. **Update spec status**: If the work originated from a `/vs-core-rfc` spec, update the spec's Status from "Proposed" to "Validated" -- all slices completed and implement.md's Evolution Log records any divergences.

2. Use the Skill tool to invoke `/vs-core-audit` on the entire changeset. Address any Critical or High findings before presenting the final result.
