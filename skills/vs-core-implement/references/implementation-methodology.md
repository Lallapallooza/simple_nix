# Implementation Methodology & Judgment

A decision framework for executing a specification into verified code, not a process checklist. Each topic is how a senior engineer thinks about the trade-off, written for someone who can write code but hasn't yet internalized when to slice, how to verify, and what to do when the spec is wrong.

---

## Verification -- What Actually Works

### 1. Why Not Strict TDD for AI Agents

Fucci et al. (2016, ESEM, 39 professionals, multi-site blind analysis) found that test-first ordering has no significant effect on code quality (p=.82), productivity (p=.83), or testing effort (p=.27). The active ingredients in TDD-like benefits are **granularity** (fine-grained steps) and **uniformity** (steady work rhythm) -- not the test-first sequence itself.

For AI agents specifically, strict TDD has a structural problem: LLMs generate complete function implementations in one pass. There is no "design conversation" with the test -- the agent already has a mental model before writing anything. Forcing test-first changes output order without changing the internal representation.

**The oracle problem:** When the same agent generates both code and tests, the tests inherit the same conceptual errors. A test that passes because it encodes the implementation's incorrect assumption is worse than no test -- it creates false confidence. This is empirically documented: Mathews et al. (2024) showed that LLM-generated tests improve pass rates when provided as INPUT (spec-as-tests), but degrade when the LLM writes both sides.

**What this means for /vs-core-implement:** Don't enforce test-first ordering. Instead, require that every acceptance criterion from the spec has a corresponding test, and that tests verify behaviors described in the spec -- not implementation internals.

### 2. Spec-Driven Verification -- Tests as Formalized Spec

The evidence supports a different verification model: tests as formalized specification, not as design drivers.

Mathews et al. (2024, arXiv:2402.13521) found that providing tests as specification input improved pass rates by 8-30 percentage points across multiple frontier models. TiCoder (Fakhoury et al., 2024, IEEE TSE) found 46% absolute improvement when tests formalize human intent. Both studies show tests working as SPECIFICATION -- clarifying what the code should do -- not as TDD constraints.

**The practice:** Each slice's acceptance criteria (from the spec) become test targets. The implementer writes tests that verify the spec's stated behaviors. Tests can be written alongside or after implementation -- the order doesn't matter. What matters:
1. Every acceptance criterion has a test
2. Tests verify against the SPEC, not implementation internals
3. All tests pass before the slice is reported done
4. Existing tests in the codebase don't break (regression check)

**The smell:** The implementer writes a test that checks "function returns list of length 3" because the implementation happens to return 3 items. That's testing an implementation detail. The spec says "returns all matching items" -- the test should set up known data and verify the right items come back.

### 3. The Oracle Problem -- When Tests Lie

When the same agent writes both code and tests, they can be wrong together. The agent misunderstands the spec, writes code that implements the misunderstanding, and writes a test that verifies the misunderstanding. All tests pass. The implementation is wrong.

**Countermeasures:**
- The reviewer is a DIFFERENT model (strongest vs strong) with a fresh context -- reducing shared blind spots
- The reviewer checks against the SPEC's acceptance criteria, not just the tests -- the spec is the oracle, not the implementer's tests
- Property-based testing (when applicable) catches invariant violations that example-based tests miss. PBT showed 23-37% gains over example-based TDD (arxiv:2506.18315) specifically because properties are harder to get circularly wrong than individual test cases.

**The judgment:** Tests are necessary but not sufficient. Spec compliance is the primary gate. Code quality is secondary. The reviewer must answer "does this implement what the spec says?" before asking "is this code good?"

---

## The Review Loop -- Convergence vs. Oscillation

### 4. The Oscillation Problem -- Review Rounds Both Fix and Break

IEEE-ISTAS 2025 (400 code samples, 40 rounds): 37.6% increase in critical vulnerabilities after 5 AI iterations. The mechanism: each review-fix round fixes the flagged issue but may break something the reviewer didn't check. After 3+ rounds, the fix-break rate approaches parity -- you're churning, not converging.

Self-Refine (Madaan et al., NeurIPS 2023) converges in 2-4 iterations. Beyond that, returns are negligible or negative.

**The rule:** Maximum 3 consecutive AI iterations before human review. This is not arbitrary -- it's the empirically supported boundary between convergence and oscillation.

**Why the implementer/reviewer split helps:** Yang et al. (2025, EMNLP) modeled review loops as Markov chains. Oscillation occurs when the reviewer flags correct content as incorrect. A separate model (different architecture, fresh context) is less likely to share the implementer's blind spots, increasing the probability of convergence.

**Why the split can hurt:** The reviewer doesn't have the implementer's full context. It may flag things as incorrect because it doesn't understand the local reasoning. This is why the Reflection section exists -- it explains WHY the implementer was wrong, so the next attempt corrects the root cause rather than just fixing the symptoms.

### 5. Spec Compliance First, Code Quality Second

Obra's two-stage review pattern: (1) Did it build the right thing? (spec compliance) (2) Did it build it right? (code quality). The first question gates the second -- there's no point polishing code that implements the wrong behavior.

**For the slice reviewer:** Check acceptance criteria satisfaction FIRST. If the implementation doesn't satisfy the spec, that's a NEEDS_FIX or REJECT regardless of code quality. Only check code quality after confirming spec compliance.

**The smell:** The reviewer spends 80% of its output discussing code style and error handling, then mentions in passing that the implementation doesn't actually satisfy acceptance criterion #2. Priorities are inverted.

---

## Slicing -- When and How

### 6. Vertical Slicing as the Default

A vertical slice is a thin end-to-end cut through all layers that delivers one piece of observable behavior. Each slice:
- Touches 1-3 files maximum
- Has one clear purpose (one behavior, one endpoint, one component)
- Has durable acceptance criteria (describe behaviors, not file paths)
- Is independently testable

**Why vertical, not horizontal:** Horizontal slicing (build all models, then all services, then all handlers) defers integration to the end. Vertical slicing verifies integration at each step. For AI agents, where each step is a fresh context, verifying integration early prevents the "works in isolation, fails in context" problem.

### 7. When Not to Slice

Slicing has costs: context handoff between slices is lossy, the planner must decompose correctly upfront, and each slice boundary is a potential amnesia event.

**Don't slice when:**
- The entire feature fits in 1-3 files and can be implemented in one pass
- The feature is algorithmically complex and decomposition would lose coherence (you can't build half an algorithm)
- The inter-slice dependencies are so tight that each slice would need the full context of all prior slices

**Do slice when:**
- The feature spans 4+ files or multiple subsystems
- There are natural dependency boundaries (data model -> API -> UI)
- Verification at intermediate points would catch design-level errors early

The planner makes this judgment. A plan with a single slice is valid.

### 8. Risk-Based Verification Weighting

Not every slice deserves the same verification depth. High-risk slices (new data model, cross-component contracts, security-relevant logic) warrant the full implement -> review -> fix cycle. Low-risk slices (UI wiring, configuration, straightforward CRUD) may pass with a lighter review.

**The risk factors:**
- Does this slice establish a contract that other slices depend on? (High risk)
- Does this slice touch security, authentication, or data integrity? (High risk)
- Does this slice validate a numbered assumption from the spec? (High risk -- assumption violation changes everything)
- Is this slice a straightforward application of an established pattern? (Lower risk)

The planner should annotate each slice with a risk assessment. The coordinator can decide whether to dispatch a full strongest-model review or accept the implementer's self-report for low-risk slices.

---

## The Feedback Arc -- When the Spec Is Wrong

### 9. Detecting Spec Divergence During Implementation

The implementer -- not the reviewer -- is in the best position to detect spec divergence, because the implementer is the one who discovers that an assumption doesn't hold while trying to build on it. The reviewer catches it later, after code has been written on a false foundation.

**Signals that an assumption is wrong (not just that the implementation is wrong):**
- The codebase doesn't have the API/capability the spec assumes
- The data model doesn't support the operation the spec requires
- A performance constraint from the spec is physically impossible with the current architecture
- Two spec requirements conflict when you try to implement both

**Signals that the implementation is wrong (not the spec):**
- Tests fail because the implementation has a bug
- The implementation doesn't match the acceptance criteria
- The code is structurally unsound

The implementer must distinguish these. An assumption check ("A1: CONFIRMED / CONTRADICTED") forces explicit evaluation rather than silent workarounds.

### 10. The Sunk Cost Trap -- Redesign vs. Push Through

The primary driver of pushing through with a bad design is the sunk cost fallacy: "we've already built slices 1-3, we can't throw that away." The correct framework: evaluate future cost of each option ignoring past investment.

**Redesign when:**
- The violated assumption affects multiple remaining slices or design decisions
- The workaround would introduce a permanent architectural compromise
- The cost of redesign is less than the cost of maintaining the workaround long-term

**Work around when:**
- The violation is localized to one slice
- The workaround is clean and doesn't create hidden coupling
- The cost of redesigning outweighs the cost of the workaround (rare, but real for near-complete features)

**The user decides.** The implementer and reviewer provide the diagnosis. The coordinator presents options with reasoning. The user makes the call. Never make a redesign decision autonomously -- the user has context about priorities, timelines, and acceptable tradeoffs that the agent doesn't.

---

## Context Management

### 11. Context Isolation Per Task Is Non-Negotiable

Every successful AI coding tool independently converges on fresh-context subagents per task: Obra, Roo Code, Claude Code, OpenAI Codex. The reason: context rot. Long-running agent sessions progressively lose coherence as the context fills with stale intermediate reasoning.

**The practice:** Each implementer dispatch gets only: (1) the slice requirements and acceptance criteria, (2) relevant context from the codebase (files to read, patterns to follow), (3) the reviewer's reflection if this is a retry. It does NOT get the full conversation history, other slices' implementations, or prior review output beyond the most recent reflection.

**The smell:** The implementer's output references decisions from a previous slice's implementation. That's context bleed -- the implementer should have gotten that context from the spec, not from another agent's output.

### 12. One Feature Per Session

Anthropic explicitly calls this "critical" for long-running agents. Implementing multiple features in one session leads to cross-contamination, premature completion declarations, and progressively worse code quality.

For /vs-core-implement: one invocation = one feature (or one spec from /vs-core-rfc). If the user wants to implement multiple features, they should invoke /vs-core-implement separately for each.

---

## Test Quality -- What Survives

### 13. Mutation Testing Mindset

For every assertion, ask: "What code change would make this test fail?" If the answer is "nothing reasonable," the test is too weak.

Strong assertions verify specific values, not just absence of errors:
- `assert_eq!(result, 42)` catches calculation changes
- `assert!(err.to_string().contains("timeout"))` checks error type AND message
- `assert_eq!(events.len(), 3)` with known setup data catches missing/extra events

Weak assertions pass for anything:
- `assert!(result.is_ok())` passes for ANY ok value
- `assert!(!list.is_empty())` passes for any non-empty list

### 14. Edge Cases to Always Test

- Empty input (empty string, empty list, zero)
- Boundary values (0, 1, -1, MAX, MIN)
- Null/None/nil where applicable
- Error conditions (invalid input, network failure, permission denied)
- The specific edge cases called out in the spec's acceptance criteria
