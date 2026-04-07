---
name: vs-core-debug
description: Systematic debugging with root cause analysis. Use this skill when the user has a bug, test failure, crash, or unexpected behavior and needs to find the root cause. Also use when the user says "debug", "why is this failing", "it's broken", "this doesn't work", "fix this bug", or when a test fails unexpectedly.
---

## Artifact Profile

Read `../vs-core-_shared/prompts/artifact-persistence.md` for the full protocol.

- **stage_name**: debug
- **artifact_filename**: `debug-{session-slug}.md` (e.g., `debug-login-crash.md`)
- **write_cardinality**: multiple
- **upstream_reads**: implement
- **body_format**:
  ```
  ## Debug: [symptom description]
  ### Symptom
  ### Root Cause
  ### Reproduction Steps
  ### Fix
  ### Verification
  ```

# Systematic Debugging

You are a debugger. Your job is to find the root cause before attempting any fix. Read [references/debugging-methodology.md](references/debugging-methodology.md) and [references/investigation-techniques.md](references/investigation-techniques.md) before starting.

## Artifact Flow

1. **Before starting**: Run ARTIFACT_DISCOVERY (see artifact-persistence.md). If no feature context exists and the user indicates this is isolated work, use STANDALONE_FALLBACK -- write to `.spec/_standalone/debug-{slug}.md` instead.
2. **Before Phase 1**: Run UPSTREAM_CONSUMPTION for implement. Include any found `implement.md` as context for understanding expected behavior.
3. **After producing the fix and verification**: Run WRITE_ARTIFACT -- write `debug-{session-slug}.md` to `.spec/{slug}/` (or `_standalone/` if standalone). Because write_cardinality is multiple, derive the session-slug from the current bug's symptom (e.g., `debug-login-crash.md`). If a file with that slug already exists, append `-2`, `-3`, etc.

## How to Dispatch Agents

When this skill says "dispatch" an agent, you MUST:
1. Read the referenced prompt file(s) and any _shared/ files they reference
2. Read `../vs-core-_shared/prompts/trust-boundary.md` (for agents reviewing user content)
3. Create a sub-agent
4. Set the `model` parameter to the specified model (strongest, strong, or fast)
5. **Inline ALL prompt content** into the sub-agent's prompt -- subagents cannot read files from your context

## Phase 1: Reproduce and Scope

Before forming any hypothesis:

1. **Reproduce the failure** -- get the exact error message, stack trace, or incorrect output. If the user hasn't provided reproduction steps, ask or find them.
2. **Isolate the boundary** -- what's the smallest context where this breaks? Strip away everything that isn't necessary. Does it break with simpler input? In isolation or only in combination?
3. **Note what IS working** -- the boundary between working and broken tells you where the bug lives.
4. **Select strategy** based on what you observe:

| Signal | Strategy |
|--------|----------|
| Clear error message + stack trace | Trace the stack: read each frame, find where actual diverges from expected |
| "It was working yesterday" / regression | `git bisect`: binary search through history to find the breaking change |
| Intermittent / timing-dependent | Log analysis, examine ordering assumptions, avoid adding probes that change timing |
| Unfamiliar codebase | Forward reasoning: trace from entry point through the execution path |
| Performance degradation | Profile first, then drill into hotspots -- don't guess at optimization targets |
| Wrong output, no crash | Backward reasoning: start from the wrong value, trace backward to its source |

Strategy is not fixed -- switch when evidence points elsewhere. See debugging-methodology.md topic 9 for shift triggers.

## Phase 2: Hypothesize and Discriminate

Form **at least 2** competing hypotheses about the root cause. A single hypothesis is a fixation trap -- you will seek confirming evidence and ignore contradictions.

For each hypothesis:
1. What evidence would **distinguish** it from the others? Prioritize evidence that discriminates over evidence that confirms.
2. Gather that evidence using investigation techniques (see investigation-techniques.md).
3. After each piece of evidence, update **ALL** hypotheses -- not just the one you're currently investigating.

If all hypotheses are refuted, the bug is not where you think it is. Widen your search -- different module, different layer, different assumption about what "correct" means.

**If investigation stalls** (all hypotheses refuted, or going in circles without converging), dispatch the reflector before continuing. See "Dispatching the Reflector" below.

## Phase 3: Verify Root Cause

Once a hypothesis survives discrimination:
- Can you explain the **infection chain** -- how this specific defect causes this specific failure through a traceable sequence of state changes?
- Can you **predict** what else should fail if this root cause is correct? Check those predictions.
- Is this a one-off mistake or a systemic pattern? Search for the same anti-pattern elsewhere.

## Phase 4: Fix

1. Write a failing test that reproduces the bug
2. Verify it fails for the right reason
3. Implement the minimal fix
4. Verify the test passes
5. Run the full related test suite to check for regressions

**If the fix fails**, dispatch the reflector before retrying.

## Dispatching the Reflector

Dispatch a reflector agent (model: strongest) when:
- A fix attempt fails (test still failing after the fix)
- Investigation stalls (hypotheses exhausted, no convergence)

Read and inline [prompts/reflector.md](prompts/reflector.md) into the agent prompt. Provide:
1. The original bug description
2. The full investigation trace (hypotheses, evidence, what was confirmed/refuted)
3. The failed fix and test output (if a fix was attempted)

The reflector returns a **Diagnosis** (wrong assumption), **Evidence** (what contradicts it), and **Strategy Pivot** (concrete new direction). If it signals an architectural issue, escalate to the user immediately.

## The Root Cause Default

Root cause investigation is the default because it prevents recurrence. Three exceptions:
1. **Active incident** -- production is burning. Stop the bleeding first, investigate after stability is restored.
2. **Code being replaced** -- the module is scheduled for removal or rewrite. A targeted fix is rational.
3. **Investigation cost exceeds recurrence cost** -- the bug is low-severity, unlikely to recur, and the investigation is expensive. Document the decision and move on.

In all three cases, document that root cause was deferred and why.

## Escalation

After 3 failed attempts (fix or investigation), or on architectural escalation signal from the reflector: **STOP.** Present the user with:
- The original bug description
- The investigation summary (what was tried, what was learned)
- The reflector's final Diagnosis and Strategy Pivot
- Your assessment: is this architectural, environmental, or beyond local fix?
