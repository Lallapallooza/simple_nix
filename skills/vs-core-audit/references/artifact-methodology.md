# Artifact Review Methodology

How to review non-code artifacts with the same rigor as code. Each artifact type has its own quality criteria, failure modes, and evidence standards. A prompt is not code. An RFC is not a PR. Reviewing them with code-review methodology produces useless findings.

This file is loaded by the Non-code Reviewer agent. The coordinator tells the agent which artifact type is being reviewed; the agent uses the relevant section.

---

## Architecture / Design Documents

### What makes an architecture document good or bad

A good architecture document makes the reader confident that the author understands the problem space well enough to make the right trade-offs. A bad architecture document either papers over hard problems or solves easy problems at length while ignoring hard ones.

Mozilla's architecture review process (Firefox Browser Architecture) distinguishes two review types:
- **Roadmap Review:** Should this be done at all? Does the problem justify the solution?
- **Design Review:** Should it be done this way? Are the trade-offs correct?

Both questions must be answered. A technically excellent design that solves the wrong problem is worse than no design.

### Review criteria

**Problem understanding (Critical if missing):**
- Does the document define the problem precisely? Not "we need better performance" but "query latency exceeds SLA at P99 when table size exceeds 10M rows because the current index strategy requires a full scan on the `status` column."
- Is the problem statement falsifiable? Could you verify that the proposed solution actually solves it?
- Does the document distinguish the problem from the proposed solution? Many design docs are really proposals dressed as problem statements.

**Alternatives analysis (High if missing):**
- Were alternatives considered? At least 2-3 approaches should be evaluated.
- Is the comparison honest? Does the document steelman the alternatives, or does it set up strawmen?
- Why was this approach chosen over the alternatives? The reasoning must be explicit and testable.
- What would change the recommendation? If the assumptions are wrong, which alternative becomes better?

**Trade-off transparency (High if superficial):**
- Every design decision has costs. Does the document name them?
- Performance vs. maintainability? Consistency vs. availability? Simplicity vs. flexibility?
- Are the trade-offs appropriate for the project's actual constraints (scale, team size, timeline)?

**Failure mode analysis (Critical if absent):**
- What happens when this design fails? Not "it won't fail" -- every design fails under some conditions.
- Are the failure modes recoverable? Can the system degrade gracefully?
- Is there a data recovery story? What happens to user data if the worst case occurs?
- Does the design acknowledge the blast radius of its decisions?

**Feasibility signals:**
- Can this be built incrementally, or does it require a big-bang deployment?
- Does the design fight the existing architecture, or extend it naturally?
- Are there dependencies on teams, services, or infrastructure that don't exist yet?

**The Uchoa finding (ICSME 2020):** Architecture review that raises concerns without actionable verdicts actually INCREASES design degradation. Every architecture finding must include a specific recommendation: "this design should use X instead of Y because Z." Open-ended "have you considered...?" questions without a recommendation are worse than silence.

---

## API Designs

### What makes an API design good or bad

A good API is hard to misuse. A bad API has a "right" way to use it that isn't obvious, requires reading the source code to understand, or has edge cases that behave differently from what the name suggests.

### Review criteria

**Consistency (High if violated):**
- Do similar operations have similar interfaces? If `getUser(id)` returns a User, does `getOrder(id)` return an Order? Or does one throw and the other return null?
- Are naming conventions consistent across the API? (`getUserById` vs `fetchUser` vs `user_get` in the same API is a finding.)
- Do error responses follow a consistent format?
- Are pagination, filtering, and sorting mechanisms consistent across all list endpoints?

**Usability -- Cognitive Dimensions framework (Piccioni & Furia, ESEM 2013):**
- **Visibility:** Can the consumer discover what's available without reading source code?
- **Consistency:** Do similar things work similarly?
- **Error-proneness:** Is it easy to use the API incorrectly? (The "pit of success" principle: correct usage should be the easy path.)
- **Premature commitment:** Must the consumer make irreversible decisions early? (Constructor-required parameters force commitment before the consumer knows what they need.)
- **Abstraction level:** Is the API at the right level? Too low (consumer builds everything) vs too high (consumer can't customize)?

**Breaking changes (Critical if unmanaged):**
- Does this change break existing consumers?
- If it does: is there a migration path? Deprecation period? Version bump?
- Hyrum's Law: any observable behavior has dependents. Even "internal" behavior changes can break consumers.

**Contract completeness (High if missing):**
- What does every endpoint return for error cases? Not just the happy path.
- What are the rate limits, size limits, timeout behaviors?
- Is the API idempotent where it should be? What happens if a request is retried?
- What are the authentication and authorization requirements per endpoint?

**The Stripe standard:** Stripe reviews every API change with cross-functional governance. The test: can a new developer build a working integration from the API documentation alone, without asking anyone? If not, the API has a completeness or usability gap.

---

## Test Suites

### What makes a test suite good or bad

A good test suite catches bugs when they're introduced. A bad test suite passes regardless of whether the code is correct -- it creates confidence without providing safety.

### Review criteria

**Assertion quality (Critical if absent):**
- Does every test have assertions? A test that runs code without asserting outcomes is theater.
- Do assertions verify behavior (what the code DOES) or implementation (HOW it does it)? Implementation-coupled tests break on refactors without catching bugs.
- Are assertions specific? `assert result != null` is weak. `assert result.status == "COMPLETED" && result.items.length == 3` is specific.
- Watch for "mocked to green" -- tests where so much is mocked that the test can't fail regardless of the implementation.

**Coverage -- the mutation testing mindset:**
- Don't ask "does this code have a test?" Ask "if I introduced a bug here, would a test fail?"
- Missing tests for error paths are the most common gap. The happy path is tested; the error path is not.
- Boundary conditions: empty input, single element, maximum size, negative values, null/None.
- State transitions: does the test verify the state BEFORE and AFTER the operation? Or just after?

**Test independence (High if violated):**
- Tests must be independent -- order of execution must not matter.
- Shared mutable state between tests is a finding.
- Tests that pass in isolation but fail in a suite (or vice versa) indicate coupling.

**The Spadini finding (ICSE 2019):** Reviewing test code before production code (Test-Driven Review) finds more test bugs. When reviewing a test suite, read the tests FIRST and predict what the implementation should look like. Then compare. Discrepancies reveal either test gaps or implementation bugs.

**Test names and clarity (Medium):**
- Does the test name describe the scenario, not the implementation? `test_expired_token_returns_401` is clear. `test_validate` is not.
- Can you understand what the test verifies without reading the implementation?

---

## Technical Documentation

### What makes documentation good or bad

Good documentation lets a reader accomplish their goal without external help. Bad documentation is either wrong, incomplete, or organized for the writer rather than the reader.

### Review criteria

**Accuracy -- consistency with implementation (Critical if divergent):**
- Does the documentation match the current code? This is the #1 documentation failure mode.
- Are code examples correct and runnable? Out-of-date code examples are worse than no examples -- they teach the wrong thing.
- Are API parameters, return types, and error codes accurate?
- The hierarchy of truth: Code > tests > runtime behavior > documentation. If docs and code disagree, the docs are wrong unless the code has a bug.

**Completeness -- task coverage:**
- Can the reader complete the task the documentation describes? If following the docs requires undocumented steps, that's a finding.
- Are prerequisites stated? Dependencies, environment requirements, access permissions.
- Are error cases documented? Not just "run this command" but "if this command fails, here's what to check."

**Audience calibration:**
- Who is the reader? Developer? Operator? End user? The same information requires different framing.
- Does the documentation assume knowledge it shouldn't? Jargon without definition. Abbreviations without expansion. References to internal systems that external readers don't know about.

**Structure:**
- Can the reader find what they need without reading everything? (Scannability)
- Is information organized by task (what the reader wants to DO) or by system component (how the author thinks)?
- Are related topics linked?

---

## Prompts / AI Skills

### What makes a prompt effective or ineffective

No peer-reviewed methodology exists for prompt review (as of 2026). This section synthesizes practitioner frameworks (Patronus AI, Portkey, Maxim AI) with the skill suite's own experience building and reviewing prompts.

### Review criteria

**Clarity of purpose (Critical if ambiguous):**
- Does the prompt clearly state what the agent should DO? Not just its identity ("you are a helpful assistant") but its task and output.
- Is the success condition explicit? The agent should be able to determine whether it has succeeded or failed.
- Is there a single interpretation of the prompt, or could the agent reasonably read it two ways?

**Effectiveness for the target model:**
- Does the prompt fight the model's natural behavior or work with it? (Asking an LLM to "never make mistakes" is fighting; structuring output to catch mistakes is working with it.)
- Are instructions ordered by importance? Models attend more to the beginning and end of prompts.
- Is the prompt testable? Can you give it an input and objectively evaluate whether the output is correct?

**Failure mode coverage:**
- What happens with edge case inputs? Empty input, very long input, adversarial input, input in a different language.
- What happens when the model is uncertain? Does the prompt instruct it to flag uncertainty or to guess?
- What are the known failure modes of the task? Does the prompt address them?

**Reference material quality (if present):**
- Is the reference material delta from what the model already knows? (Generic content the model already has is wasted tokens.)
- Is the reference material organized for retrieval (the agent will scan, not read sequentially)?
- Does the reference material contain actionable judgment (when to do X vs Y) or just facts?
- Are worked examples included for complex tasks? Worked examples are the highest-leverage prompt element.

**Anti-patterns:**
- **Instruction overload:** More instructions != better output. Instructions that contradict each other or that the model can't follow simultaneously create inconsistency.
- **Vague superlatives:** "Be very thorough," "provide comprehensive analysis," "ensure highest quality" -- these are content-free. Replace with specific criteria.
- **Identity without methodology:** "You are an expert security reviewer" without explaining HOW to review security produces pattern-matching, not expert review.

---

## Configuration

### What makes configuration correct or dangerous

Configuration review is the least-studied artifact type and generates the most unhelpful review comments (Bosu et al., MSR 2015). The problem: reviewers lack reference points for configuration files because the "correct" value is often context-dependent.

### Review criteria

**Security (Critical if violated):**
- Are credentials, secrets, tokens, or API keys present in the configuration? Even in "internal" config.
- Are default credentials still in place?
- Are network-facing settings secure? (Open ports, disabled TLS, permissive CORS, debug mode in production.)
- Are file permissions correct? (World-readable secret files.)

**Correctness -- does it do what it claims?**
- Do the values match the intended environment? (Production config pointing at staging database is a Critical finding.)
- Are feature flags set correctly for the target environment?
- Do timeout values make sense? (A 1ms timeout on a network call. A 1-hour timeout on a health check.)
- Are resource limits set? (No memory limit on a container. No connection pool limit on a database client.)

**Idempotency:**
- Can this configuration be applied multiple times without side effects?
- Does applying this config create resources that aren't cleaned up on reapplication?

**Blast radius:**
- What does this config affect? A change to IAM permissions affects every service using that role.
- Is the scope of the change appropriate? A config change that affects all environments when only staging was intended is a Critical finding.
- Are there rollback instructions? If this config causes a problem, how do you undo it?

**Consistency:**
- Does this configuration match the conventions of other config files in the project?
- Are there contradictory settings? (Feature enabled in one file, disabled in another.)
- Are there deprecated options being used?

---

## RFCs / Proposals

### Review criteria

Apply the Architecture/Design Document criteria above, plus:

**Scope appropriateness:**
- Is the RFC scope proportional to the problem? A 50-page RFC for a configuration change is over-engineered. A 2-paragraph RFC for a database migration is under-specified.
- Does the RFC scope match its claimed audience? An RFC "for the team" that requires company-wide changes is misscoped.

**Assumption transparency:**
- Are all assumptions explicit and numbered? Implicit assumptions are the #1 source of RFC-to-implementation divergence.
- Are assumptions testable? "We assume traffic will stay below 10K QPS" is testable. "We assume the team will have time" is not.

**Implementation path:**
- Is there a path from RFC to implementation? Can a developer read this and know what to build?
- Are there decision points that will need resolution during implementation? Are they identified?
- What is the rollback strategy if the implementation reveals the design is wrong?
