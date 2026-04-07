# Severity Calibration

How to classify findings by type and severity across all artifact types. Not a lookup table -- a judgment framework for the hard cases where a finding could be Critical or Medium depending on context.

The overrejection principle applies throughout: when in doubt, escalate severity. A human reviews the findings and can downgrade. A missed Critical ships to production.

---

## Finding Types

Every finding has a type that determines what the author must DO. Severity determines urgency; type determines response.

### 1. CONCEPT -- Wrong Direction

The artifact solves the wrong problem, adds unwanted capability, or moves the project in a direction it shouldn't go. The implementation quality is irrelevant -- a perfect implementation of the wrong thing is still wrong.

**When to use:** The feature shouldn't exist. The approach contradicts project goals. The PR adds scope nobody asked for. The RFC proposes solving a problem that doesn't exist.

**Author response:** Argue the direction is correct, find a different approach, or abandon.

**Common in non-code artifacts:** An RFC that proposes the wrong architecture. A prompt that optimizes for the wrong outcome. Documentation that explains a deprecated workflow.

**The calibration trap:** Reviewers avoid CONCEPT findings because they feel personal -- "you built the wrong thing" is harder to say than "you have a bug on line 47." But CONCEPT findings save the most work when caught early.

### 2. DESIGN -- Wrong Structure

The goal is right but the structural approach is wrong. Wrong abstraction, wrong layer, wrong coupling, wrong data model. Fixing individual lines won't help -- the architecture needs rethinking.

**When to use:** The code works but fights the existing architecture. The abstraction doesn't earn its complexity. The coupling creates dependencies that will cause pain. The data model doesn't fit the access patterns.

**Author response:** Rethink structure, rewrite with different architectural choices.

**Distinguishing DESIGN from LOGIC:** DESIGN is "you chose the wrong approach" -- LOGIC is "you chose the right approach but got the details wrong." If fixing every line-level bug would still leave the code structurally wrong, it's DESIGN. If fixing the specific bugs would make the code correct, it's LOGIC.

**Linus's standard:** Code that works but is unmaintainable, that creates an abstraction nobody needs, or that adds `#ifdef` spaghetti is rejected at the DESIGN level. "I'd rather have a straightforward 20-line function than a 'clever' 5-line one that nobody can read." (kernel.org, various LKML threads)

### 3. LOGIC -- Correctness Defect

The design is sound but the implementation has bugs. Wrong algorithm, missing edge case, incorrect conditional, off-by-one, null dereference, resource leak, race condition.

**When to use:** The approach is right. The structure is right. But THIS LINE does the wrong thing.

**Author response:** Fix the specific defects. The structure stays.

**Subcategories for precision:**
- **Functional:** Missing or incorrectly implemented behavior
- **Boundary:** Off-by-one, overflow, underflow, empty/max/negative input handling
- **State:** Stale state, uninitialized variable, state not reset between iterations
- **Resource:** Memory leak, connection leak, file handle leak, lock not released
- **Concurrency:** Data race, TOCTOU, deadlock, lock ordering violation

### 4. SECURITY -- Threat Model Violation

A vulnerability that an attacker could exploit. Not a theoretical concern -- a plausible attack vector must exist or be constructible.

**When to use:** Untrusted input reaches a dangerous sink without validation. Authentication or authorization is bypassable. Secrets are exposed. Cryptographic operations use weak algorithms or parameters.

**Author response:** May need architecture change (not just a line fix) if the trust boundaries are wrong.

**Distinguishing SECURITY from LOGIC:** A null pointer dereference is LOGIC. A null pointer dereference triggered by user-controlled input that crashes the service is SECURITY (denial of service). The difference is whether an attacker can trigger the condition.

**Evidence requirement:** Security findings must include an attack vector -- HOW an attacker exploits this, not just THAT it's vulnerable. "Line 47: user input in `request.params.name` reaches `db.query()` on line 89 without sanitization. An attacker sends `'; DROP TABLE users; --` as the name parameter, causing SQL injection." That's a finding. "There might be SQL injection" is noise.

### 5. COMPLETENESS -- Required Element Missing

Something that should be there isn't. Missing error handling, missing tests, missing validation, missing documentation, missing edge case handling.

**When to use:** The code does what it does correctly, but it doesn't do enough. No tests for the error path. No validation on public API input. No documentation for a breaking change.

**Author response:** Add what's missing.

**Calibration:** Completeness findings can be any severity. Missing error handling on a database write in production code is High. Missing a docstring on an internal helper is Low. Missing authentication on a public endpoint is Critical (and also SECURITY).

### 6. SCOPE -- Belongs Elsewhere

The code may be fine but it's in the wrong place, against the wrong branch, too large to review atomically, or mixes unrelated concerns.

**When to use:** The PR modifies code outside its stated purpose. The diff is 3,000 lines mixing a refactor with a feature. The change targets the wrong branch. The commit bundles unrelated fixes.

**Author response:** Split, retarget, or remove unrelated changes.

**The kernel standard:** "Each logically separate change should be submitted as a separate patch." This is not a style preference -- it's a review effectiveness requirement. A diff that bundles multiple concerns cannot be reviewed reliably. (kernel.org)

### 7. STYLE -- Convention Violation

The code works, the design is fine, but it doesn't match the project's conventions. Wrong naming, wrong formatting, inconsistent patterns, non-idiomatic constructs.

**When to use:** The finding is about consistency and readability, not correctness or design.

**Author response:** Mechanical fix. Follow the convention.

**Calibration:** Style is almost always Low or Medium. The exception: if the style violation creates ambiguity that could cause bugs (e.g., misleading variable names, confusing control flow formatting), escalate to High.

**The Linux kernel gate:** Style violations are rejected before functional review begins. `checkpatch.pl` failures are not debatable. This is a pre-filter: if you can't follow the style guide, the reviewers won't read your logic.

---

## Severity Levels

### Critical

**Definition:** The artifact has a defect that will cause data loss, security breach, service outage, or incorrect results in production. Alternatively: the artifact cannot be understood from its own content (reviewability failure).

**Evidence requirement:** Must demonstrate the failure scenario concretely. "This WILL cause X when Y happens" with specific line references and execution trace.

**Examples across artifact types:**
- Code: SQL injection via unsanitized user input with a constructible attack vector
- Code: Data race on a shared counter in a payment processing path
- Architecture: The proposed design has no path for data recovery after a failure
- Prompt/Skill: The prompt instructs the agent to do something that will produce wrong results for a common input class
- Config: Production credentials exposed in a public repository
- API: Breaking change to a public API with no migration path
- Tests: Tests pass but don't actually verify the behavior they claim to verify (assertion-free tests, mocked-to-green)

**Reviewability Critical:** If ANY agent cannot understand what the artifact does from the artifact itself, that's Critical. Don't ask the author to explain -- flag it. A PR that needs external explanation has failed the most basic quality bar.

### High

**Definition:** The artifact has a defect that will cause incorrect behavior, performance degradation, or maintenance problems under realistic conditions. Not immediately catastrophic, but will cause pain.

**Evidence requirement:** Must describe the scenario where the problem manifests. "When X happens (which occurs in production scenario Y), this will Z."

**Examples:**
- Code: Unhandled error path that causes silent data corruption in a non-critical feature
- Code: O(n²) algorithm in a path that handles user-facing requests (not catastrophic, but will degrade)
- Architecture: Coupling that will force changes in 5 files for every feature addition
- Prompt: The prompt sometimes produces confidently wrong output for edge case inputs
- Config: A timeout set too low that will cause intermittent failures under load
- Tests: Test covers the happy path but misses the error path that has a bug

### Medium

**Definition:** The artifact has an issue that reduces quality but doesn't cause incorrect behavior under normal conditions. Will cause confusion, complicate maintenance, or degrade developer experience.

**Evidence requirement:** Must explain WHY this is a problem, not just THAT it deviates from a standard.

**Examples:**
- Code: Unnecessary complexity that makes the function harder to understand
- Code: Missing validation that currently can't be triggered but will be exploitable after a planned refactor
- Architecture: A design decision that works now but will be hard to change later
- Prompt: Ambiguous instruction that could be interpreted two ways (currently both produce acceptable output)
- Config: A setting that works but uses a deprecated option
- Tests: Adequate coverage but test names don't describe what they verify

### Low

**Definition:** Minor issue that doesn't affect behavior, performance, or maintainability significantly. Worth noting but not worth blocking.

**Evidence requirement:** Just identify it. No failure scenario needed.

**Examples:**
- Code: Non-idiomatic construct that works correctly
- Code: Comment that's slightly outdated
- Prompt: Wording that could be clearer but conveys the right meaning
- Config: Inconsistent formatting
- Tests: Test that verifies behavior correctly but could be more readable

---

## Severity Escalation Rules

These rules encode the overrejection principle. When in doubt, escalate.

### Automatic Escalation

- **"Probably fine" -> Medium.** If you're uncertain whether something is a problem, it's a finding. The human decides. Never dismiss uncertainty.
- **Multiple Medium findings in the same area -> High.** Three Medium LOGIC findings in one function suggest the function is undertested or poorly understood. The cluster is worse than the sum.
- **Any finding in security-sensitive code -> escalate one level.** A Medium LOGIC finding in an authentication function is High. A High finding is Critical.
- **Cross-module findings -> escalate one level.** A bug that spans module boundaries is harder to fix and more likely to escape testing. (Paul et al., ICSE 2021: security defects spanning directories escape significantly more often.)
- **Finding in code without tests -> escalate one level.** The finding can't be verified by running tests, which means it's more likely to be real and less likely to be caught later.

### Cannot Downgrade

The coordinator cannot downgrade agent-assigned severity. It can:
- **Upgrade** severity (Medium -> High) when cross-validated by multiple agents
- **Reject** a finding entirely with stated reasoning (the code doesn't do what the agent claims)
- **NOT soften** a finding (High -> Medium) to achieve a more favorable verdict

This is the structural anti-sycophancy mechanism at the coordinator level. The path of least resistance must be to keep findings, not to dismiss them.

---

## Severity by Artifact Type -- Calibration Guide

Different artifact types have different severity profiles. A missing edge case in code is different from a missing edge case in documentation.

### Code
Follow the standard severity definitions above. Code findings are the best-calibrated because the failure scenarios are concrete and traceable.

### Architecture / Design Documents
- Critical: The design has a structural flaw that would require rewriting the implementation (wrong data model, impossible consistency guarantee, missing failure recovery)
- High: The design omits a significant concern (no scaling strategy, no migration path, missing security model)
- Medium: The design is viable but suboptimal (could be simpler, creates unnecessary coupling)
- Low: The design is fine but unclear in places

### Prompts / AI Skills
- Critical: The prompt will produce wrong results for a common input class, or instructs the agent to do something harmful
- High: The prompt has ambiguity that will cause inconsistent behavior, or misses a significant failure mode
- Medium: The prompt works but could be more effective (weak framing, missing edge cases, unclear output format)
- Low: The prompt works but has style issues

### Configuration
- Critical: Security exposure (credentials, open ports, disabled auth), data loss risk (missing backups, wrong retention)
- High: Performance problem (wrong resource limits, missing timeouts), incorrect behavior (wrong feature flags, wrong environment targeting)
- Medium: Non-optimal settings (conservative timeouts, unnecessary features enabled)
- Low: Formatting, naming, comments

### Tests
- Critical: Tests pass but don't verify what they claim (assertion-free, mocked to green, testing implementation not behavior)
- High: Missing test coverage for a code path that has bugs or handles sensitive operations
- Medium: Tests are correct but brittle, coupled to implementation details, or have unclear assertions
- Low: Test naming, organization, readability

### API Designs
- Critical: Breaking change with no migration path, security vulnerability in the API contract, inconsistency that will cause client bugs
- High: Usability issue that will cause widespread misuse, missing error responses, ambiguous behavior
- Medium: Naming inconsistency, missing convenience methods, suboptimal pagination
- Low: Documentation gaps, style inconsistency
