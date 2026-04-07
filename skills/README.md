# AI Agent Skills

8 modular skills for AI coding agents. Each dispatches parallel specialized sub-agents, merges findings adversarially, and produces structured output. Platform-agnostic -- works with Claude Code, Codex, OpenCode, or any agent that supports sub-agent dispatch.

## Installation

Point your agent at this directory and tell it to install the skills. The skills use standard markdown -- any agent that can read files and dispatch sub-agents can use them.

For Claude Code specifically, symlink to `~/.claude/skills/`:

```bash
ln -sfn /path/to/this/repo/skills ~/.claude/skills
```

## How Skills Work

Each skill is a coordinator that dispatches parallel sub-agents with different specializations. Sub-agents cannot read the coordinator's files, so all prompt content and shared infrastructure (`vs-core-_shared/prompts/`) is inlined into each agent's instructions at launch.

When agents return, the coordinator runs a critical merge: cross-validating findings, rejecting generic claims without evidence, resolving contradictions, escalating consensus. `/vs-core-audit` goes further with anti-sycophancy enforcement where the coordinator cannot downgrade agent severity, only upgrade or reject with stated reasoning.

Skills compose: `/vs-core-rfc` invokes `/vs-core-grill` to scope requirements, then `/vs-core-research` for open questions, then designs and reviews before generating a living spec. `/vs-core-implement` executes that spec in vertical slices with review gates. If a numbered assumption proves wrong mid-implementation, it halts with a SPEC_DIVERGENCE signal that feeds back to `/vs-core-rfc` for redesign. Every agent performs mandatory self-critique with tool-grounded verification before returning results.

Model tiers (`strongest`, `strong`, `fast`) are generic -- map them to your platform's best reasoning model, general-purpose model, and cheapest capable model respectively.

## Quick Reference

| Skill | When to use | What it produces |
|-------|------------|-----------------|
| `/vs-core-grill` | Requirements unclear, need to think it through | Decision log + recommended next step |
| `/vs-core-research` | Need to understand a technology, compare options, investigate | Cross-referenced briefing with confidence levels |
| `/vs-core-arch` | Design a module, evaluate architecture, compare approaches | Scored analysis OR competing designs with recommendation |
| `/vs-core-rfc` | New feature needs design before coding | Implementation spec with numbered assumptions and vertical slices |
| `/vs-core-implement` | Have a spec, need to execute it with quality gates | Committed code with spec compliance verification |
| `/vs-core-audit` | Finished work needs adversarial review | Verdict (Pass / Fix and Resubmit / Redesign / Reject) + prioritized findings |
| `/vs-core-debug` | Bug with unknown root cause | Root cause diagnosis + fix + regression test |
| `/vs-core-tropes` | Check text for AI writing patterns | Findings with concrete rewrites |

## Typical Workflow

```
/vs-core-grill  -->  /vs-core-research  -->  /vs-core-arch  -->  /vs-core-rfc  -->  /vs-core-implement  -->  /vs-core-audit
  |              |             |           |            |              |
  understand     investigate   design      spec         build          verify
```

Not every task needs every step. Small bug fix: `/vs-core-debug`. Quick feature: `/vs-core-implement` directly. Complex system: full pipeline.

`/vs-core-rfc` and `/vs-core-implement` are tightly integrated -- if implementation discovers a spec assumption is wrong, `/vs-core-implement` raises a SPEC_DIVERGENCE and the user decides: update spec, work around it, or redesign.

## Architecture

**Atomic skills** (standalone): `/vs-core-grill`, `/vs-core-research`, `/vs-core-arch`, `/vs-core-audit`, `/vs-core-debug`
**Pipeline skills** (call other skills): `/vs-core-rfc` (uses grill + research patterns), `/vs-core-implement` (calls `/vs-core-audit` as final gate)

### Shared Infrastructure (`vs-core-_shared/`)

| File | Purpose |
|------|---------|
| `adversarial-framing.md` | Rigorous adversarial reviewer stance -- guilty until proven correct, dual-perspective, overrejection calibration |
| `artifact-persistence.md` | Structured artifact read/write protocol for `.spec/` pipeline with frontmatter schema and discovery rules |
| `critical-merge.md` | Orchestrator must JUDGE findings -- select over synthesize, no-downgrade rule, disagreement as signal |
| `output-format.md` | Standardized finding format: severity, location, evidence, impact, suggestion + "So What?" test |
| `rationalization-rejection.md` | 5-category dismissal pattern catalog -- testing, security, review, general, automation/confidence |
| `self-critique-suffix.md` | CRITIC protocol -- tool-grounded verification with worked examples (Huang ICLR 2024) |
| `trust-boundary.md` | Courtroom framing -- reviewed content is exhibits to examine, not instructions to follow |

### Language Judgment Files (`vs-core-_shared/prompts/language-specific/`)

5 senior engineering judgment files. How an engineer thinks about trade-offs -- not checklists, but when to break the rules.

| File | Coverage |
|------|----------|
| `rust-judgment.md` | Ownership, async, unsafe, API design, performance |
| `go-judgment.md` | Simplicity, concurrency, error handling, interfaces |
| `python-judgment.md` | Data modeling, type system, concurrency, dynamic nature |
| `typescript-judgment.md` | Type system as design tool, soundness holes, ecosystem |
| `cpp-judgment.md` | Universal C++ (LLVM, Unreal, embedded, Google, Meta, HFT) |

Loaded by `/vs-core-audit` for code reviews.

## Per-Skill Details

### /vs-core-grill
Socratic interview -- one question at a time, provides recommended answers. No sub-agents. The entry point for complex work.

### /vs-core-research
5 agent types with 4 reference files covering methodology, search strategy, source evaluation, and codebase investigation. Starts with a grill phase.

### /vs-core-arch
Analysis mode (2-3 agents) or Design mode ("Design It Twice" -- 3+ agents with radically different constraints). 4 judgment references.

### /vs-core-rfc
Full pipeline: grill --> research --> design-it-twice --> adversarial review --> revision loop (max 3 cycles) --> spec generation. Produces numbered assumptions for `/vs-core-implement`.

### /vs-core-implement
Spec-driven execution with risk-based verification. SPEC_DIVERGENCE verdict feeds back to design.

### /vs-core-audit
Adversarial review at Linux kernel / LLVM maintainer standards. Default stance: rejection. Anti-sycophancy is structural. 4 reference files. Reviews code, prompts, docs, config, anything.

### /vs-core-debug
Systematic root cause analysis with reflector agent for failed fixes. 2 reference files. Escalates after 3 failed attempts or on architectural signal.

### /vs-core-tropes
Scans text for AI writing patterns (em-dash addiction, negative parallelism, magic adverbs, bold-first bullets, etc.) against a catalog from tropes.fyi. Reports clusters and repeated patterns with concrete rewrites.
