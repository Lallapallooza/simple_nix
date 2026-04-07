# Review Methodology

How expert reviewers actually read and evaluate artifacts. Not a checklist -- a decision framework for each situation a reviewer encounters, written for an agent that can pattern-match but hasn't yet internalized when a pattern is a real finding and when it's noise.

Every topic is a judgment call that expert reviewers make intuitively. The goal is to make that intuition explicit and transferable.

---

## The Adversarial Default

### 1. Code Is Guilty Until Proven Innocent

The default stance is rejection. Code does not earn approval by the absence of detected problems -- it earns approval by the presence of verified correctness. This is the opposite of how LLMs naturally operate: models trained on human feedback gravitate toward approval because approval is rewarded during training (Anthropic, "Towards Understanding Sycophancy," 2023).

**What this means in practice:** When you read a function and nothing jumps out, your instinct is "looks fine." That instinct is wrong. "Looks fine" means you haven't traced the logic yet. A function is correct when you can explain WHY it's correct -- what invariants it maintains, what edge cases it handles, what contracts it fulfills. If you can't articulate the correctness argument, you haven't reviewed it.

**The Linux kernel standard:** Patches are rejected by default. The burden is on the patch author to demonstrate that the patch is correct, necessary, and consistent with the surrounding code. Subsystem maintainers routinely reject patches that "look fine" because the author couldn't justify design choices when asked. (kernel.org, "Submitting Patches")

**The smell:** You've read a file and have no findings. You conclude it's correct. But you can't explain what the function on line 47 does with a null input, or whether the lock on line 83 is released on the error path. You haven't reviewed -- you've skimmed.

**The signal:** For every section you review, you can state what you verified and how. "Lines 40-65: the retry loop correctly bounds at 3 attempts, the backoff is exponential, and the error is propagated after exhaustion. Verified by tracing both the success and failure paths." That's review.

### 2. Three Reading Strategies -- Choose by Purpose

Expert reviewers don't read code top-to-bottom. They choose a reading strategy based on what they're looking for. Research on code comprehension (arxiv 2503.21455, March 2025) confirms that experts build multi-layer mental models: specification (what problem is solved), implementation (how), and annotation (connecting the two).

**Control-flow reading:** Follow the execution order -- entry point, branches, loops, function calls, returns. Best for finding logic errors, unreachable code, incorrect branching. Use this when the question is "does this do what it claims?"

**Data-flow reading:** Follow how data moves -- where variables are assigned, how they're transformed, where they're consumed. Best for finding security vulnerabilities (untrusted data reaching a sink), resource leaks (allocated but not freed), and state corruption (variable modified unexpectedly). Use this when the question is "what happens to this data?"

**Trace-based reading:** Step through execution like a debugger, with concrete inputs. Pick specific test cases (happy path, empty input, boundary value, concurrent access) and walk through what happens. Best for finding subtle bugs that emerge from specific input combinations. Use this when control-flow and data-flow analysis both say "looks fine" but you suspect something is wrong.

**The expert move:** Use all three. Control-flow first (is the logic structure sound?), then data-flow (does data move safely?), then trace-based (does it actually work for these specific inputs?). Each strategy catches different bug classes.

**The smell:** You're reading code top-to-bottom, line by line, at uniform depth. You find typos and style issues but miss the logic bug on line 147 that only manifests when the input is empty AND the connection times out.

### 3. Context Before Code

Before reading a single line of implementation, build context. This is what the research (arxiv 2503.21455) calls the "specification layer" of the mental model.

**Read in this order:**
1. The PR title, description, and linked issues -- what problem is being solved?
2. Test files -- what behavior is expected? Tests are executable specifications.
3. The module's public interface -- what contract does this code fulfill?
4. The actual implementation -- now you can evaluate whether it fulfills the contract.

**Why this order matters:** If you read implementation first, you evaluate "does this code look reasonable?" If you read the spec first, you evaluate "does this code satisfy the requirements?" The second question catches bugs the first one misses -- the code can look perfectly reasonable while solving the wrong problem.

**The kernel standard:** Every patch must have a commit message that explains WHY the change exists. Patches with unclear justification are rejected before the code is reviewed. "Why" is more important than "what." (kernel.org, "Submitting Patches")

**The smell:** You start reviewing the diff immediately without reading the PR description or understanding the feature context. You evaluate code in isolation from its purpose.

---

## Logic Tracing

### 4. Trace Every Branch, Not Just the Happy Path

The happy path is the path the author tested. The bug is on the path the author didn't test. Expert reviewers systematically trace all paths -- including error paths, early returns, exception handlers, and fallback logic.

**The discipline:** For every conditional (`if`, `match`, `switch`, ternary), ask: "What happens on the other branch?" For every function call, ask: "What if this fails?" For every loop, ask: "What if the collection is empty? What if it has one element? What if it has a million?"

**Concrete technique -- the branch table:** For each function under review, enumerate all execution paths. For a function with three conditionals, there are up to 8 paths (2³). Most functions have 3-5 meaningful paths. Trace each one. If you can't trace a path, that's a finding -- the code is too complex.

**The HECR insight:** Huang & Madeira (JSS 2024) found that training reviewers on cognitive error patterns improved defect detection by ~400%. The most productive error patterns to watch for:

- **Boundary errors:** Off-by-one in loops, comparisons (< vs <=), array indices, range calculations
- **State errors:** Variable used before initialization, stale state after a failed operation, state not reset between iterations
- **Null/empty errors:** Dereferencing after a null check that took a different branch, empty collection methods that return unexpected defaults
- **Type errors:** Implicit conversions that lose precision, signed/unsigned comparison, floating-point equality
- **Concurrency errors:** Read-modify-write without synchronization, check-then-act (TOCTOU), lock ordering violations

**The smell:** You find zero bugs in a 200-line function. Either it's genuinely perfect (unlikely) or you only traced the happy path.

### 5. Invariants and Contracts

An invariant is a condition that must always be true. A contract is what a function promises to its callers. Expert reviewers think in terms of these abstractions, not just "does this line look right."

**Loop invariants:** For every loop, identify what must be true at the start of each iteration and after the loop terminates. If the invariant isn't maintained, the loop is buggy. If you can't identify the invariant, the loop is too complex or incorrectly structured.

Formal check: (1) Does the precondition establish the invariant? (2) Does the loop body preserve it? (3) Does the loop make progress toward termination? (4) Does invariant + termination imply the postcondition?

**Function contracts:** What does this function promise? What does it require? If the function takes a list, does it handle empty lists? If it returns a result, does it guarantee non-null? If it modifies state, does it document what state changes?

**Cross-function contracts:** When function A calls function B, does A satisfy B's preconditions? Does A correctly handle all of B's possible return values, including errors? This is where most subtle bugs hide -- the contract between caller and callee is implicit and violated.

**The smell:** You review each function in isolation. The bug is in how two functions interact -- function A assumes B never returns null, but B's error path returns null. Neither function is buggy in isolation; the contract between them is broken.

### 6. Concurrency Is a Separate Review Pass

Concurrent code requires a different mental model than sequential code. The most common concurrency bugs (80% are data races -- arxiv 2312.14479, 2023) are invisible to sequential logic tracing.

**The concurrency checklist:**
- **Shared mutable state:** Every variable accessed from multiple threads must have explicit synchronization. If you see shared state without a lock, mutex, or atomic operation, that's a finding.
- **Check-then-act (TOCTOU):** Any pattern where a condition is checked and then acted upon is a race condition if another thread can change the condition between the check and the act. File existence checks, permission checks, null checks followed by dereference -- all TOCTOU candidates.
- **Lock ordering:** If code acquires multiple locks, does it always acquire them in the same order? Different ordering = deadlock potential.
- **Lock scope:** Is the critical section as small as possible? Is the lock released on ALL paths, including error paths?
- **Atomicity gaps:** Multi-step operations on concurrent collections -- each step is atomic but the sequence is not. "Check if key exists, then insert" is not atomic.
- **Memory ordering:** On weakly-ordered architectures (ARM, RISC-V), reads and writes can be reordered. Does the code use appropriate memory fences or atomic orderings?

**The signal for deeper concurrency review:** Any of: `async`, `await`, `spawn`, `thread`, `lock`, `mutex`, `atomic`, `channel`, `Arc`, `Rc`, shared references across thread boundaries, global mutable state, event handlers that can fire concurrently.

**The smell:** You review async code using sequential logic tracing and find no bugs. The bug is a race condition between two handlers that modify the same state.

### 7. Security Is Data-Flow Tracing with a Threat Model

Security review is not a separate checklist -- it's data-flow tracing where the data is controlled by an attacker. The OWASP methodology: identify entry points -> trace data through processing -> verify validation at trust boundaries -> check sinks.

**Trust boundaries are the key concept:** Where does untrusted input enter? Where does it cross into a privileged context? Every boundary crossing must have validation. If untrusted data reaches a SQL query, a shell command, an HTML template, or a file path without validation, that's a finding.

**The ICSE 2021 finding (Paul et al.):** Security defects that span multiple directories are significantly more likely to escape review. This means security review must trace data flow across module boundaries, not just within a single file.

**Attack chain construction:** Don't just find a vulnerability -- trace the path an attacker would take. "User input on line 23 flows to `db.query()` on line 89 without sanitization. An attacker could inject SQL via the `name` parameter." This is a finding. "There might be a SQL injection issue" is not.

---

## Cognitive Error Patterns

### 8. The HECR Approach -- Review by Error Mode

Huang & Madeira (JSS 2024) demonstrated that reviewers trained on specific human cognitive error patterns detected ~400% more true positives with ~33% fewer false positives. The method: instead of asking "is this code correct?" ask "what cognitive error could have produced a bug here?"

**High-yield cognitive error patterns for code:**

**Omission errors** -- the developer forgot something:
- Missing error handling on a function that can fail
- Missing null/bounds check before access
- Missing lock acquisition before shared state access
- Missing cleanup in an error path (resource leak)
- Missing test for an edge case
- Missing validation at a trust boundary

**Commission errors** -- the developer did something wrong:
- Wrong operator (< vs <=, && vs ||, = vs ==)
- Wrong variable (copy-paste with incomplete rename)
- Wrong order (operations that must happen in sequence done out of order)
- Wrong type (implicit conversion loses information)
- Wrong default (zero, empty string, or null when a meaningful default is needed)

**Repetition errors** -- the developer did something right once but wrong on repetition:
- Copy-pasted code with one instance not updated
- Consistent pattern broken in one location
- Error handling correct in 4 of 5 branches, wrong in the 5th

**Interference errors** -- two correct things that are wrong together:
- Two features that work individually but conflict when combined
- A refactoring that's correct locally but breaks a distant assumption
- A performance optimization that invalidates a correctness invariant

**The smell:** You're looking for bugs by reading code. Look for error patterns instead -- the bugs follow the patterns.

### 9. The "What Changed?" Discipline

For code review (as opposed to code audit), the diff is the primary artifact. Expert reviewers don't just read the new code -- they understand what CHANGED and what the change implies.

**Questions for every hunk in a diff:**
- What behavior did this change? Not just "what code changed" but what OBSERVABLE behavior is different.
- What else depends on the old behavior? Hyrum's Law: every observable behavior has dependents, whether intended or not.
- Did this change an implicit contract? If a function previously always returned sorted results and now doesn't, every caller that assumed sorting is broken.
- Did this change error behavior? If a function previously threw on invalid input and now returns a default, callers that catch the exception now silently get wrong data.
- Is the change complete? If you changed how errors are handled in function A, did you change it in functions B and C that follow the same pattern?

**The kernel standard:** "Each logically separate change should be submitted as a separate patch." If a diff contains multiple logical changes, that's a finding (Scope type). It obscures what changed and makes review unreliable. (kernel.org, "Submitting Patches")

---

## Review Depth Calibration

### 10. Not Every Line Deserves the Same Depth

The Cisco case study (Cohen, 2006) found optimal review rate at under 500 LOC/hour, with effectiveness degrading sharply above that. The implication: if the diff is 2,000 lines, you cannot review every line at expert depth.

**Risk-based triage:** Focus maximum adversarial depth on:
- Security boundaries (authentication, authorization, input validation, cryptographic operations)
- Concurrency (shared state, locks, async coordination)
- Error handling (the paths the author tested least)
- Public API changes (backwards compatibility, contract changes)
- Complex logic (high cyclomatic complexity, nested conditionals)
- State management (anything that modifies persistent state, database operations, file system writes)

**Lighter coverage for:**
- Formatting changes, renames, import reordering
- Straightforward additions following established patterns
- Test boilerplate (but NOT test assertions -- those get full depth)
- Documentation-only changes (unless reviewing docs specifically)

**Transparency requirement:** The review must explicitly state what received deep review and what received light coverage. A verdict without coverage transparency is incomplete.

### 11. The "Explain It Back" Test

If you cannot explain what a piece of code does in plain language, you haven't understood it. And if you haven't understood it, you cannot have reviewed it.

**For every non-trivial function:** After reading, pause and articulate: "This function does X by doing Y, handling Z edge cases, and assuming W." If you can't, that's either a reviewability finding (the code is unclear) or you need to trace the logic more carefully.

**The kernel standard for reviewability:** A PR that needs the author to explain it is a PR with insufficient context. The code and its commit message must make the case for the change on their own. If the reviewer needs external explanation, that's a Critical finding -- not a question to ask the author.

### 12. The "What If This Is Wrong?" Test

For every assertion you make about the code ("this handles null correctly"), ask: "What if I'm wrong?" What evidence would I need to see to confirm this? Can I trace to the specific line?

This is the Millikan Rule applied to code review: apply identical scrutiny to your confidence as to your doubt. If you'd spend 5 minutes investigating a suspected bug, spend 5 minutes verifying a suspected correctness claim.

**The smell:** You're certain a function is correct, but you can't point to the specific line that handles the edge case you're worried about. Your certainty is based on "it looks like it should work" not "I can see that it handles this case at line 73."
