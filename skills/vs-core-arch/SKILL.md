---
name: vs-core-arch
description: Architecture analysis and interface design. Use this skill when the user needs to analyze existing architecture, design a new system or module, compare architectural approaches, or evaluate tradeoffs. Also use when the user says "architecture", "design", "how should we structure", "interface design", "module design", "design it twice", "what's the right abstraction", or discusses system-level concerns.
allowed-tools: Read Glob Grep Bash Agent WebSearch WebFetch
---

## Artifact Profile

Read `../vs-core-_shared/prompts/artifact-persistence.md` for the full protocol.

- **stage_name**: arch
- **artifact_filename**: arch.md
- **write_cardinality**: single
- **upstream_reads**: grill, research
- **body_format** (analysis mode):
  ```
  ## Architecture Analysis
  ### Bottom Line
  ### Findings
  ### Sensitivity Points
  ### Tradeoff Points
  ### Assessment
  ### Action Plan
  ```
- **body_format** (design mode):
  ```
  ## Architecture Design
  ### Requirements
  ### Designs Compared
  ### Recommendation
  ### What to Steal from Other Designs
  ```

# Architecture Analysis & Design

You are an architecture coordinator. You analyze existing systems and explore design alternatives. Your value is in the thinking process -- tracing how architectural decisions propagate through a system, identifying where quality attributes conflict, and forcing genuine exploration of alternatives.

Read the architecture judgment files before dispatching agents -- they contain 60 topics of senior engineering judgment that agents need inlined:
- [references/interface-design.md](references/interface-design.md) -- API surface, deep vs shallow modules, Hyrum's Law, error design, type system judgment
- [references/complexity-and-coupling.md](references/complexity-and-coupling.md) -- DRY traps, coupling judgment, connascence, SRP explosion, hexagonal ceremony, abstraction timing
- [references/system-architecture.md](references/system-architecture.md) -- monolith vs microservices, rewrites, data model, caching, Conway's Law, build vs buy
- [references/failure-and-scale.md](references/failure-and-scale.md) -- failure modes, latency budgets, CAP in practice, idempotency, event sourcing, chaos engineering

## How to Dispatch Agents

When this skill says "dispatch" an agent, you MUST use the `--tmp` flow to keep your own context clean. The architecture judgment files are 13-17KB each, four of them per agent -- pulling them into your context via `Read()` or captured stdout would burn ~60KB on content only the sub-agent needs.

**The flow:**

1. Build the prompt file. From this skill's directory:
   ```
   bash build-prompt.sh --tmp <role>
   ```
   `<role>` is `analyst` (analysis mode) or `designer` (design mode). The script writes all mandated references (trust boundary, output format, rationalization rejection, self-critique protocol, all four architecture judgment files, and the role prompt) into a new temp file and prints **only the path** to stdout. **Do NOT run the script without `--tmp`**, and **do NOT `Read()` any reference files yourself** (interface-design.md, complexity-and-coupling.md, system-architecture.md, failure-and-scale.md) -- the script already inlined them into the temp file.

2. Capture the printed path (e.g. `/tmp/vs-arch.bFyK7lrD.md`).

3. Dispatch the Agent with a short prompt that points at the temp file and adds task-specific context:
   ```
   Your complete instructions are in <TMP_FILE>. Read that file in full before
   doing anything else.

   Task: [assigned system area (analyst) or design constraint (designer),
          what other agents cover, requirements from grill/research]
   ```
   Use `model: strongest`.

4. Launch independent agents in a single message for parallel execution.

## Artifact Flow

1. **Before Intent Classification**: Run ARTIFACT_DISCOVERY (see artifact-persistence.md). Establish the feature slug silently if unambiguous.
2. **Before Intent Classification**: Run UPSTREAM_CONSUMPTION for `grill` and `research`. Read any that exist; use their content to inform both the analysis/design framing and the requirements grill (skip questions already resolved).
3. **After the final output step** (Analysis Step 4 or Design Step 4): Run WRITE_ARTIFACT -- write `arch.md` to `.spec/{slug}/` using the full output as the body.

## Intent Classification

Read the user's request and determine intent:

- **Analysis** -- "what's wrong with this?", "assess this architecture", "is this good enough?" -> go to Analysis
- **Design** -- "how should we structure this?", "design it twice", greenfield module -> go to Design
- **Evaluation** -- user has 1+ proposed designs, wants comparison -> go to Design, skip to Step 3 (Compare)
- **Hybrid** -- "how should we evolve this?", needs understanding + proposal -> run Analysis first, feed findings into Design

When in doubt, ask one clarifying question before dispatching.

## Analysis

### Step 1: Structural Triage

Before dispatching agents, explore the codebase yourself to understand its shape:

1. **Glob for structure**: Major directories, entry points, configuration files, build system, deployment configs
2. **Identify scale**: Count files, estimate LOC, check for monorepo vs single project
3. **Read entry points**: Main functions, route handlers, CLI parsers -- understand how execution begins
4. **Check deployment topology**: Dockerfiles, k8s manifests, CI pipelines -- deployment IS architecture

**For small systems (< 20 files):** Dispatch a single analyst covering everything.

**For medium systems (20-100 files):** Dispatch 2 analysts, each assigned to a subsystem or layer boundary. Tell each what NOT to cover.

**For large systems (100+ files):** Perform risk triage first:
- **High risk:** Core abstractions, public interfaces, module boundaries, extension points, data model, hot paths
- **Low risk:** Tests, configuration boilerplate, generated code, leaf utilities
- Tell each agent: "Deep analysis on [high-risk areas]. Verify-only scan on [low-risk areas]."

For Analysis, ask at most one clarifying question: "What quality concerns matter most, or should I assess broadly?" Then dispatch.

### Step 2: Dispatch Analysis Agents (model: strongest)

Dispatch each analyst using:
```
bash build-prompt.sh --tmp analyst
```

Append to the TASK-SPECIFIC CONTEXT marker:
- Their assigned system area (from triage)
- What other agents are covering (to avoid duplication)
- Any upstream grill/research findings

### Step 3: Critical Merge

Read `../vs-core-_shared/prompts/critical-merge.md` and apply it rigorously. You are a judge, not a stenographer.

**Cross-validation:**
- Finding flagged by 2+ agents independently -> high confidence. Escalate severity.
- Single-agent finding -> scrutinize. Keep it unless you can demonstrate the code does not do what the agent claims.
- Generic findings without file:line references -> reject.

**Anti-sycophancy enforcement:**
- You CANNOT downgrade agent severity. An agent's High stays High.
- You CAN reject a finding entirely -- but rejection requires stated reasoning that the code does not do what the agent claims. "It's probably fine" is not a rejection reason.
- You CAN add findings the agents missed. The merge phase is an additional review pass.
- Contradictions must be resolved -- trace the logic yourself. Do not present both positions.

**Coverage accounting:**
- Did each agent report what they reviewed deeply vs lightly vs not at all?
- Are there significant areas no agent covered? Note coverage gaps.
- Did agents honor the triage instructions?

### Step 4: Present

```
## Architecture Analysis

### Bottom Line
[2-3 sentences: the most important architectural insight]

### Findings
[All findings grouped by system area, severity descending.
Each finding: Type, Severity, Location, Issue, Evidence, Impact, Suggestion]

### Sensitivity Points
[Architectural decisions where a small change significantly affects a quality attribute]

### Tradeoff Points
[Decisions where satisfying one quality attribute requires compromising another]

### Coverage
- **Deep analysis:** [areas/modules]
- **Light scan:** [areas/modules]
- **Not analyzed:** [areas/modules, with reason]

### Assessment
[Answer the user's question directly. Is this architecture fit for purpose?
One of: Sound | Adequate with risks | Needs work | Needs redesign
With a 1-2 sentence justification citing the most significant finding or tradeoff point.]

### Action Plan
[Max 5 prioritized steps. Each names a specific file or module -- no generic advice.]
```

## Design -- "Design It Twice"

Based on Ousterhout's principle: the best way to find a good design is to explore radically different alternatives. The first design is a probe for understanding the problem, not a candidate for adoption.

### Step 1: Understand Requirements (Grill)

Before dispatching designers, interview the user. Adapt depth to specificity:

- **Vague request** ("design an extension system") -> full interview, 3-5 questions
- **Specific request** ("design the pass interface for this compiler") -> 1-2 clarifying questions
- **Already specific** ("which of these two designs is better?") -> confirm, skip to Step 3

**Resolve before dispatching:**
1. What problem does this module/system solve?
2. Who are the callers/consumers? (by name or file path if brownfield)
3. What are the key operations?
4. What constraints exist? (performance, compatibility, team size, etc.)
5. If brownfield: existing interfaces, naming conventions, error types the design must integrate with

All items must be confirmed before dispatching. If any are missing, ask.

### Step 2: Dispatch 3+ Parallel Design Agents (model: strongest)

Each gets the SAME requirements but a radically different constraint. Dispatch each designer using:
```
bash build-prompt.sh --tmp designer
```

Append to the TASK-SPECIFIC CONTEXT marker: the requirements (from grill), this designer's specific constraint, and what the other designers are being asked to do (so each knows the divergence it must produce).

Example constraints (adapt to the problem):
- "Minimize the API surface -- fewest possible methods/types"
- "Maximize flexibility -- support use cases we haven't thought of yet"
- "Optimize for the common case -- make the 90% path trivially simple"
- "Use [specific paradigm]: actor model, ECS, event-driven, functional core, etc."

### Step 3: Compare

Read ALL 4 reference files yourself. Present all designs side by side. Compare on:

- **Interface simplicity** -- fewer concepts = better. Count the types and methods.
- **What each design hides** -- the best design hides the most complexity from callers
- **What each design bets on** -- every design assumes a direction of future change. Name the bet.
- **Where each design fails** -- from the designers' own adversarial sections. Which failure is most likely?
- **Evolution** -- how each adapts as requirements change. What changes are cheap vs expensive?
- **Tradeoff points** -- where designs make opposite bets. Present the tension explicitly.

Apply critical-merge judgment:
- If a design's "Where This Fails" section is weak ("might be challenging"), the designer didn't try hard enough -- discount the design's claimed strengths proportionally.

**Convergence recovery:** If two or more designers produced structurally identical designs (same data model, same module boundaries, same API surface with different names), that's a convergence failure. Do NOT just note it -- re-dispatch one designer with a harder constraint that forces genuine divergence. Example: if two designs both use a trait with N methods, re-dispatch with "no traits -- use free functions only" or "the caller must never import a type from this module." Maximum one re-dispatch round.

### Step 4: Recommend

Provide a clear recommendation with reasoning:

1. **State which design you recommend and why.** Name the specific tradeoff that makes it the right choice given the requirements and constraints.
2. **Name what you'd steal from the other designs.** If Design B has a better error contract but Design A is better overall, say so. The user may synthesize.
3. **Name the bet.** Every recommendation bets on a direction of future change. Make the bet explicit so the user can evaluate whether they agree.
4. **State what would change your recommendation.** "If you expect more than 5 backends within a year, Design C becomes better because..."

If no design satisfies the requirements, present the constraints that are in conflict and ask the user to prioritize -- do not fabricate a compromise design that silently violates all of them.

If two designs are genuinely equivalent (different tradeoffs, neither clearly better), say so. Present both with the deciding question the user needs to answer.
