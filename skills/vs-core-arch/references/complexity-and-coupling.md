# Complexity, Coupling & Abstraction

A decision framework for managing complexity in software systems. Each topic is how a staff engineer thinks about the trade-off -- when the textbook advice is right, when it's wrong, and how to tell the difference.

---

## Abstraction Judgment

### 1. DRY as a Trap -- The Wrong Abstraction Cycle

Sandi Metz identified the destructive cycle: Programmer A extracts duplication. Programmer B has a new requirement that "almost fits," adds a parameter and conditional. Programmer C adds another. The abstraction now has 5 parameters and 8 conditional branches. Nobody understands it, but sunk-cost drives the team to keep patching.

**Metz's prescription:** "When the abstraction is wrong, the fastest way forward is back." Inline the code into every caller. Delete the unused paths per caller. Now you can see what's genuinely shared. Duplication is a carrying cost (maintenance on N copies). Abstraction is a coupling cost (coordination on N callers). For code that changes rarely, duplication costs nothing. For code that changes frequently in different directions, abstraction costs everything.

**The supply-chain dimension:** Rob Pike's Go proverb: "A little copying is better than a little dependency." Every dependency is a bet on continued alignment of priorities, no breaking changes, no security compromises. Copy small utilities (< 1 day to write). Depend on large frameworks (months of domain expertise). Ken Thompson's "Reflections on Trusting Trust" (1983) demonstrated that a compromised compiler can inject backdoors that survive source code audits -- the foundational insight behind supply chain security.

**The smell:** Your shared function has parameters named `skipValidation`, `isLegacy`, or `options`. Or: you've extracted a utility and your first change adds an `if` to handle caller differences. The copies were diverging -- put them back.

### 2. Abstraction Timing -- Beyond the Rule of Three

The Rule of Three says: abstract on the third occurrence. But three occurrences mean nothing if the instances are diverging. The actual test has three parts:

**Convergence test:** Are the instances becoming more similar, or accumulating differences? Three microservices all parse dates from external APIs. They share `parseDateFlexible()`. Then one API switches to Unix timestamps, another uses ISO 8601, the third uses locale-specific formats. Three instances of "parse a date" were three different problems.

**Stability test:** Has the interface between shared code and callers been stable for 2-3 change cycles? If the function signature changes every sprint, the boundary is in the wrong place.

**Comprehension test:** Can a new team member read the abstraction without reading all callers? If understanding requires knowing the usage sites, nothing has been abstracted.

**The smell:** You're about to extract a shared function and you can already imagine the first `if` for caller differences. Wait.

### 3. The Abstraction Inversion -- When Clean Layers Make Callers Work Harder

An abstraction inversion happens when your "clean" layer hides something the caller actually needs, forcing workarounds. A framework hides connection pooling but doesn't expose `TCP_NODELAY`. The 5% of callers who need low-latency streaming must fight the abstraction -- monkey-patching, reflection, or abandoning the framework.

**The judgment:** Every abstraction bets about what callers care about. Getting this bet wrong is worse than not abstracting, because the wrong abstraction actively prevents solving the problem. The counter-risk: exposing too much creates coupling in the other direction.

**The signal:** Callers use reflection, type-casting, or "escape hatches" to reach through your abstraction. Your bet was wrong about what to hide.

### 4. The Cost of Abstraction Nobody Measures

Three hidden costs that never appear in architecture evaluations:

**Cognitive load:** A request traverses 7 layers. "Why is this slow?" requires tracing all of them. **Onboarding time:** A new developer must understand the abstraction before the feature. **Debug distance:** Files opened to trace a bug -- each layer adds 1-3 files. A 7-layer architecture means 7-21 files per bug.

**The smell:** A new team member's first PR takes 3 weeks because they spent 2 weeks understanding the layering. Your architecture is serving itself, not your team.

### 5. Simple vs Easy -- Why Familiarity Is Not Simplicity

Rich Hickey's distinction: "Simple" (Latin simplex, one fold/braid) means not interleaved with other things. "Easy" (adjacens, lying near) means familiar. These are orthogonal. Rails scaffolding: easy but complex. Functional programming for OOP programmers: simple but hard.

**The engineering sin:** Choosing easy over simple because it feels productive now. The familiar library that complects six concerns is easy to start and impossible to untangle later.

**John Carmack's parallel insight:** "A large fraction of the flaws in software development are due to programmers not fully understanding all the possible states their code may execute in." Immutability reduces state space. Carmack: "I am a full const nazi nowadays" -- not for performance, but because `const` makes the compiler find state mutation bugs.

**The signal:** You're choosing a library because "we already know it." Ask: "does this braid together concerns we'll later need to separate?"

---

## Coupling Judgment

### 6. When Coupling Is Acceptable -- The Coupling That Ships

The "wrong" coupling that ships in 2 weeks beats the "right" abstraction that ships in 8.

**Acceptable when:** Components change together for the same business reason. Same team, same deployment. System is in discovery mode -- premature decoupling crystallizes wrong boundaries. System lifetime is short enough that coupling won't compound.

**Unacceptable when:** Components change for different reasons. Different teams with different release cycles. Coupling crosses a network boundary -- that's permanent coupling with added failure modes.

**The judgment:** The cost of coupling is proportional to the rate of change of coupled components. Two components changing once a year: tightly coupled at near-zero cost. Two components changing daily in different directions: decouple or drown.

**The smell:** You're building an abstraction layer "so we can decouple later." If you don't know when "later" is, you're paying now for a benefit that may never arrive.

### 7. Connascence in Practice -- Which Forms Actually Bite

Connascence (Page-Jones) has 9 levels. In practice, three cause most production bugs:

**Connascence of Timing:** `time.sleep(2)` to "wait for" another operation. Under load, 2 seconds isn't enough. Fix: explicit synchronization -- semaphores, completion channels, await.

**Connascence of Value:** "If you change X, also update Y" comments. Fix: derive the dependent value. `RANGE_END = RANGE_START + RANGE_SIZE - 1` instead of two constants.

**Connascence of Algorithm:** Producer hashes SHA-256, consumer must hash SHA-256. When one side changes, the system silently breaks. Fix: single source of truth.

**The forms that matter less:** Connascence of Name (automated rename) and Type (caught by compilers). Spend design effort on the dynamic forms that testing and static analysis miss.

**The signal:** Tests pass but production fails intermittently. Check for CoTiming -- sleep-based synchronization that works on your machine but races under load.

### 8. SRP-Driven Class Explosion -- When Decomposition Increases Complexity

SRP is about cohesion around a reason to change, not minimizing lines per file. Splitting a 200-line service into 12 classes (validator, mapper, repository, factory, handler, DTO, event, publisher) spreads complexity across 12 files with 12 import chains.

**The judgment:** SRP should reduce coordination cost, not increase it. A 300-line class doing one business operation well is better than 12 classes doing it incoherently. The counter-signal: when components genuinely change independently for different reasons, decomposition IS correct.

**The smell:** Adding a field to a form touches 4+ files. A new team member can't trace a request path without a debugger.

### 9. Hexagonal Architecture for CRUD Apps -- When Ceremony Exceeds Value

Hexagonal earns its complexity only when business logic is the hard part. For CRUD with 80% data shuttling and 20% validation, interfaces for every repository, DTOs at every boundary, and mappers between layers add 3-5x code surface with near-zero return.

**The judgment:** Count plumbing-to-logic ratio. If it exceeds 3:1, your architecture serves itself. If your domain model is isomorphic to your database schema, hexagonal is ceremony without benefit. Hexagonal earns its cost for complex domain logic, multiple input channels, or genuine testing-without-infrastructure requirements.

**The smell:** Your domain entity and ORM model have the same fields, and a mapper converts between them. That mapper is 100% overhead, 0% value.

### 10. Design Patterns as Premature Complexity

A 3-branch `if/else` is almost always clearer than a Strategy pattern with 3 implementations, a factory, and an interface. Patterns should be recognized in existing code, not applied proactively.

**The judgment:** If you can explain a function by reading top-to-bottom in 30 seconds, a pattern makes it worse. Patterns pay off when the growth trajectory is clear (4 branches going to 20), not when the current state has 3 branches.

**The smell:** Strategy/Factory for fewer than 5 variants. Observer with 2 observers. Abstract Factory with one concrete factory.

### 11. The God Object That Works

An orchestrator coordinating a multi-step workflow has a single responsibility: orchestrating. It touches many things -- that's different from knowing too much.

**The real question:** If I split this, will I need distributed transactions or event choreography to maintain correctness? If yes, the god object is cheaper and more reliable. The order fulfillment god object: 500 lines, single transaction, zero network partition failures. The decomposed version: 2,000 lines across 4 services requiring a saga coordinator -- a distributed god object with more failure modes. The counter-signal: when the object exceeds one person's working memory or multiple teams need independent ownership, it must die.

**The signal:** Splitting requires a saga layer. You're replacing one coordinator with another plus network unreliability.

---

## Module Design

### 12. Module Boundaries -- Data Ownership vs Team vs Deployment

Three forces pull boundaries in different directions:

**Data ownership:** Group code that reads and writes the same data. Minimizes distributed transactions. The service that writes owns the data -- not necessarily the service that "logically" owns the entity.

**Team ownership:** Conway's Law means these boundaries form whether you design them or not.

**Deployment units:** Components with different scaling needs should be separate -- otherwise you pay 10x compute for everything.

**The tension:** When forces conflict, team ownership wins for organizational effectiveness, data ownership wins for correctness, deployment wins for operational cost. Pick the right priority for your current bottleneck.

**The smell:** A boundary that satisfies team ownership but splits data ownership. You now need distributed transactions where you previously had a join.

### 13. Eliminate Special Cases Through Better Representation

Linus Torvalds's "good taste" principle. The linked list deletion example: "bad taste" special-cases the head node. "Good taste" uses `**head` and the general code handles the head naturally.

**The deeper principle:** Special cases smell of wrong representation. When you write `if (isFirstElement)` or `if (isEdgeCase)`, ask: is there a representation where this case isn't special? The cost: finding the better representation takes time, and sometimes the special case is genuinely special.

**The signal:** A function where the `else` branch is longer than `if`. The "special" case is the common case -- your representation is backwards.

### 14. Conceptual Integrity -- When to Sacrifice It

Fred Brooks: "It is better to have a system omit certain anomalous features, but reflect one set of design ideas, than one that contains many good but independent and uncoordinated ideas." Unix's "everything is a file" is a single unifying idea.

**The judgment:** A system designed by one mind is more coherent than one designed by committee, even if the committee is smarter. But conceptual integrity is not a religion -- when a genuinely superior pattern emerges, a planned migration beats indefinite adherence to the old pattern. The key: migrate, don't accumulate. A codebase with 3 paradigms is incoherent. A codebase migrating from old to new is evolving.

**The smell:** The same concept implemented three different ways, each reflecting whoever built that module. That's not diversity -- it's incoherence.

### 15. TDD Can Produce Worse Architecture

TDD is inherently bottom-up. It builds a bush, not a tree. Tests coupled to implementation create a "test cage" that punishes refactoring -- the opposite of TDD's goal.

**The scenario:** A team TDDs a payment system. Six months in, aggregate boundaries are wrong. Refactoring means rewriting 400 tests asserting internal state. The team lives with the wrong model because the test suite multiplied the cost of change. What you lose without TDD: regression safety, design feedback.

**The judgment:** TDD works within known architectural boundaries. It works terribly to discover those boundaries. Design the architecture first (even roughly), then TDD within it. If mocking setup exceeds 50% of test line count, you're testing abstraction boundaries, not business logic.

### 16. Fix Now vs Live With It

Not all technical debt is equal. The campground rule can harm when it turns every PR into a refactoring expedition.

**Fix now:** Debt in the change path -- you're about to modify this code, and debt makes it risky. Fixing is part of the work.

**Live with it:** Debt in stable code nobody will touch for months. Theoretical until someone needs to change it.

**Never fix:** Debt in code being replaced. Refactoring the deprecation path is pure waste.

**The smell:** A Jira epic called "tech debt sprint" with 40 tickets nobody works on. The debt that matters is in your change path -- fix it inline.

### 17. Architecture Decision Records -- When They Work vs Theater

ADRs work when they're one page and capture what you rejected and why. They fail as mandatory templates for every decision.

**When ADRs earn their cost:** Infrastructure choices invisible to future team members. Contentious decisions -- recording rejected alternatives prevents re-litigation after turnover.

**When ADRs become theater:** Mandatory for every decision. Bloated. Retroactive compliance paperwork. Managers forcing reuse decisions on teams whose use case doesn't fit.

**The judgment by team size:** At 3, overhead -- everyone was in the room. At 30, how decisions propagate. At 300, the only way architectural intent survives turnover.
