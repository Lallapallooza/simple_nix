# Specification Methodology & Judgment

A decision framework for writing specifications that actually help implementation, not a template. Each topic is how a senior engineer thinks about the trade-off, written for someone who can write prose but hasn't yet internalized when a spec helps, when it hurts, and what level of detail hits the sweet spot.

---

## The Core Insight -- Why Specs Exist

### 1. Specification Catches Design Errors That Testing Cannot

AWS used TLA+ on 10 large distributed systems (S3, DynamoDB, EBS) and found bugs in every one -- bugs that "passed unnoticed through extensive design reviews, code reviews, and testing." The key finding: "The code faithfully implements the intended design, but the design fails to correctly handle a particular 'rare' scenario" (Newcombe et al., CACM 2015).

Cleanroom Software Engineering delivered 10x defect reductions across multiple IBM projects spanning 34K--107K LOC (Mills, Dyer, Linger, IEEE Software 1987). Fagan code inspections achieved 82% defect detection efficiency (Fagan, IBM Systems Journal 1976).

**The implication:** The most dangerous class of software errors are wrong designs, not wrong implementations. An AI agent that implements a wrong design will do so faithfully and completely. Specification is the only intervention that catches these errors before implementation begins.

**The smell:** You're writing a spec that describes HOW to implement something. That spec catches zero design errors -- it's an implementation manual. The value is in specifying WHAT the system should do and WHY, then validating whether those constraints are internally consistent and survivable.

### 2. The Boehm Curve Is Dead -- But Design Errors Are Still Expensive

The famous 1:5:10:50:100 cost multipliers (Boehm, 1981) came from 1970s TRW waterfall projects. Menzies et al. (2017, Empirical Software Engineering, 171 projects) found no evidence for the exponential cost-of-change curve in modern development. Boehm himself acknowledged in 2004 that no data existed for agile contexts.

**But design-level errors remain disproportionately costly** regardless of methodology. Fixing a wrong data model is expensive not because change is inherently expensive but because the wrong model contaminates everything built on top of it. The cost is proportional to how much code assumed the wrong design, not to when the error was discovered.

**The judgment:** Don't justify specification with "it's cheaper to fix bugs early." Justify it with "a wrong design will be faithfully implemented by every subsequent step, and the damage compounds with each step that builds on the wrong foundation."

---

## Specification Granularity -- The Critical Variable

### 3. Spec the What and Why, Never the How

A 2026 study (arxiv 2602.11988) across Claude Code, Codex, and Qwen found that LLM-generated context files -- structured specification documents -- decreased task success by ~2% while increasing costs 20--23%. The mechanism: agents follow specification instructions rather than solve problems. When those two objectives conflict, instruction-following wins.

**The critical caveat:** This studied procedural specs ("use pytest, build with make"), not design-level specs (architecture, contracts, acceptance criteria). Procedural specs harm AI agents. Design-level specs help them -- by constraining the design space without constraining the implementation path.

**The rule:** A specification should answer: What problem are we solving? What are the constraints? What contracts must hold? What are the acceptance criteria? It should NOT answer: What functions to write, what variable names to use, what libraries to import, how to structure the implementation.

**The smell:** Your spec has code snippets, file paths, or function signatures. You've crossed from specification into implementation. The agent will follow your implementation rather than find the best one.

**The signal:** Your spec could be handed to a competent engineer who uses a completely different language and framework, and they could still build a correct system from it. The design decisions are captured; the implementation decisions are left open.

### 4. The Google Design Doc Principle -- Tradeoffs, Not Implementation

Malte Ubl (ex-Google tech lead): "Documents that merely describe implementation without discussing tradeoffs are 'implementation manuals' and signal you should have just written the code." Google design docs focus on: context (why now?), goals and non-goals (what's in/out of scope?), the design with alternatives considered, and cross-cutting concerns (security, privacy, observability).

**What's absent:** Code structure, function signatures, class hierarchies, internal data flow. These are implementation decisions that belong to the implementer.

**The decision criteria for whether to spec at all** (adapted from Google): Write a spec when you answer yes to 3+ of: (1) you're uncertain about the correct design, (2) senior engineering input would help, (3) the design is contentious enough to warrant consensus, (4) cross-cutting concerns need explicit attention, (5) the system will be maintained by others. If fewer than 3: just write the code.

### 5. Overspecification -- The 1,300-Line Antipattern

A developer using GitHub's spec-kit reported generating 1,300 lines of specification for displaying the current date in a time-tracking app (marmelab, November 2025). AWS Kiro produced 5,000 LOC where 800 sufficed. This is the overspecification failure mode: the spec becomes harder to read than the code would be.

**The test:** If your spec is longer than the code it's specifying, something is wrong. Either the spec includes implementation detail (see Topic 3), or the problem is simple enough that specification is overhead rather than leverage.

**The exception:** Specs for distributed systems, concurrent algorithms, or security-critical components can legitimately be longer than the code, because the spec captures reasoning about failure modes and invariants that are invisible in the code.

---

## The Living Spec -- Specification as Ongoing Activity

### 6. Specs Are Not Finished When Implementation Begins

Lehman's Law I ("Continuing Change"): systems must continually be adapted. Requirements volatility research confirms that a significant fraction of specification change is learning -- implementation reveals what the spec got wrong. The EuroPLoP 2017 paper identifies three patterns in continuous development: specs created at iteration start, specs evolving during iteration, and spec refactoring at iteration end.

**The practical implication:** A spec that cannot be updated during implementation is a waterfall artifact. The spec must have a mechanism for recording what implementation learned. This is the "evolution log" -- a section of the spec that captures assumption violations, design adjustments, and new constraints discovered during implementation.

**The failure mode:** Spec rot. The spec says one thing, the code does another, and nobody updates either. The spec becomes fiction. To prevent this, the spec must be structured so that updates are cheap and natural -- not a rewrite, but an amendment.

### 7. Numbered Assumptions -- The Backward-Path Trigger

Every spec contains assumptions: "the API supports batch operations," "latency will be under 50ms," "the data model is append-only." These assumptions are almost never made explicit. When implementation discovers an assumption is wrong, there's no mechanism to trace back to which design decision depended on it.

**The practice:** Number every assumption in the spec. For each assumption, note which design decisions depend on it. During implementation, when an assumption is violated, the numbered reference tells you exactly which design decisions are now invalidated.

**Example:**
```
### Assumptions
A1. The auth service supports token refresh without re-authentication.
    Depends on: Slice 2 (session management), Slice 4 (background sync)
A2. Database supports upsert operations.
    Depends on: Slice 1 (data model), Slice 3 (conflict resolution)
```

When the implementer discovers A1 is false, they know slices 2 and 4 need re-examination. Without this structure, the assumption violation is discovered in slice 2 and nobody realizes slice 4 is also affected.

### 8. The TC39 Model -- Spec Is Not Final Until Implementation Validates It

TC39's process is the most rigorous implementation-as-validation model documented. Stage 3 means "design complete; changes only from implementation feedback." Stage 4 requires two independent shipping implementations passing Test262 acceptance tests. The spec is finalized only after implementation proves it works.

**The adaptation for AI workflows:** The spec starts as "proposed." After each slice completes successfully, the assumptions it validated are marked as confirmed. After all slices complete and the evolution log shows no unresolved design-level changes, the spec status moves to "validated." This is not bureaucracy -- it's the mechanism that prevents spec rot by making the spec's status reflect reality.

---

## Design Decisions -- ADR-Style Recording

### 9. Record Decisions, Not Just Designs

Michael Nygard's Architecture Decision Records (2011): 1--2 page documents with five sections: Title, Context, Decision, Status, Consequences. Stored in version control. Never deleted -- superseded decisions link to replacements.

**Why this matters for specs:** A spec that says "we chose approach A" without recording why approach B was rejected will be re-litigated when the next person reads it. The rejected alternatives and the reasoning behind rejecting them are as valuable as the chosen design.

**The format for spec design decisions:**
```
### Decision: [title]
**Context:** [what forces are at play]
**Decision:** [what we chose]
**Alternatives considered:** [what we rejected and why]
**Consequences:** [what follows from this choice -- both good and bad]
**Assumptions:** [which numbered assumptions this depends on]
```

### 10. The RFC Perverse Incentive -- Decision Authority Must Be Explicit

Jacob Kaplan-Moss (Django core dev, 2023): RFC processes are "document-discuss" without "decide." Engineers write deliberately long RFCs to suppress objections. Nick Cameron (Rust compiler team, 2022): key decision-makers delay engagement until Final Comment Period; 54 RFCs from 2020+ remain open.

**The fix:** Every adversarial review must have an explicit decision mechanism. The coordinator (the /vs-core-rfc orchestrator) is the decision authority. Reviewers provide findings; the coordinator judges them using critical merge. Findings that don't survive scrutiny are rejected. This is not consensus-seeking -- it's evidence-based judgment.

**The smell:** The review cycle loops indefinitely because every reviewer raises new concerns and no one has authority to say "this concern is valid but low-severity, we proceed." That's the Rust RFC failure mode.

---

## Antipatterns -- What Goes Wrong

### 11. Analysis Paralysis -- The Spec That Prevents Building

The Standish Group CHAOS data shows 59% failure rate for waterfall (max upfront spec) vs. 11% for agile (min upfront spec). Correlation, not causation, but the direction is consistent. Thoughtworks advocates specifying only three things before the first sprint: domain model, architecture shape, and UI skeleton.

**The test:** If you've been designing for longer than it would take to build a spike and learn from it, you're in analysis paralysis. A spike is a time-boxed throwaway implementation that answers specific technical questions. It's cheaper than a perfect spec because it produces empirical evidence rather than theoretical predictions.

**When to spike instead of spec:** When the primary uncertainty is technical feasibility, not design direction. "Can we achieve 10ms latency with this architecture?" is a spike question. "Should we use event sourcing or CRUD?" is a design question. Specs answer design questions; spikes answer feasibility questions. The current /vs-core-rfc already has a feasibility reviewer -- that reviewer should recommend spikes when feasibility is uncertain rather than trying to answer feasibility questions from first principles.

### 12. Spec Rot -- The Document That Lies

Every engineering organization that writes specs reports the same failure: specs diverge from reality during implementation and nobody updates them. The spec becomes fiction that actively misleads future readers.

**The structural cause:** Updating the spec is extra work with no immediate benefit to the person doing the work. The spec served its purpose (getting the design reviewed) and is now a maintenance burden.

**The structural fix:** Make the spec useful during implementation, not just before it. Numbered assumptions that implementation checks against. An evolution log that records what changed and why. Acceptance criteria that become test descriptions. When the spec is a living tool rather than a historical artifact, keeping it current has immediate value.

### 13. The Second System Effect -- Overdesigning From Experience

Brooks (1975): designers who built a successful first system tend to overdesign the second, adding every feature they wished they'd had. The same applies to specs: engineers who were burned by underspecification tend to overspecify the next project, producing the 1,300-line spec for a date display.

**The counter:** Scope the spec to the current problem, not to every problem you've ever had. Non-goals are as important as goals. Every spec should have an explicit "Out of Scope" section that names things you deliberately chose not to address. This prevents scope creep in the spec itself.

### 14. Specification Theater -- Following the Form Without the Substance

Feynman's "Cargo Cult Science" applies to specs: following the template (sections, headings, review steps) without the substance (genuine design thinking, real alternatives considered, honest uncertainty). The FINDER benchmark found that 18.95% of AI research agent failures involve "plausible but unsupported content" -- the same failure mode applies to AI-generated specs.

**The test:** For each design decision in the spec, can you articulate why the alternative was rejected? If you can't, the decision wasn't actually made -- the spec just picked something and justified it post-hoc. A spec with one well-reasoned decision is more valuable than a spec with ten decisions that were never actually deliberated.
