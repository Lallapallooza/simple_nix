# Investigation Techniques

A decision framework for choosing and applying debugging techniques. Each technique has a purpose, a failure mode, and a signal for when to switch. The order here reflects a rough decision tree -- start with the technique that matches your bug signal, switch when evidence points elsewhere.

---

### 1. Backward Tracing -- From Symptom to Source

Start at the wrong output and trace backward: where did this value come from? What function produced it? What were that function's inputs? Were those inputs correct? Continue until you find the first incorrect value in the chain.

**When to use:** Wrong output, unexpected null, incorrect computation -- any bug where you can see the wrong result and ask "where did this come from?"

**The key move:** At each step, check BOTH the value AND the control flow that led to this path. A correct function called with wrong inputs produces a wrong result that looks like a bug in the function. Don't stop at the first wrong value -- trace to the first wrong value that was produced from CORRECT inputs. That's the defect.

**When it fails:** The chain is too long (deep call stacks with many intermediate transformations). The wrong value was produced asynchronously or via side effects not visible in the call graph. For these, switch to state inspection at key checkpoints instead of exhaustive backward tracing.

**For concurrency bugs:** Backward tracing is unreliable when the infection chain crosses thread boundaries. The value was correct when written but stale when read -- the "defect" is a missing synchronization point, not a wrong computation. Check ordering assumptions before tracing values.

### 2. Forward Tracing -- From Entry to Failure

Start at the suspected entry point and trace forward through the execution path: what does the code actually do with this input? Read each function in execution order, tracking state changes.

**When to use:** Unfamiliar codebase where you don't know what "correct" looks like. Complex initialization sequences. Code where reading top-to-bottom reveals the logic faster than tracing backward from the failure.

**The key move:** Predict what each function should return BEFORE reading it. If the actual behavior matches your prediction, move on. If it doesn't, you've found either the bug or a gap in your mental model -- both are valuable.

**When it fails:** The execution path is too long or branches unpredictably. You spend 30 minutes tracing through correct code because the bug is near the end. Forward tracing is exhaustive -- it doesn't prioritize. Switch to binary search or boundary analysis to narrow scope first.

### 3. Binary Search -- Divide and Conquer

Split the problem space in half. Check state at the midpoint. If correct, the bug is in the second half. If incorrect, the first half. Repeat.

**Two forms:**

**Temporal binary search (git bisect):** For regressions -- "it was working, now it isn't." `git bisect` automates binary search through commit history. O(log N): ~7 tests for 100 commits, ~14 for 16,000. `git bisect run <test-script>` fully automates when you have a machine-checkable test. Start `git bisect start`, mark `git bisect bad` (current broken state), mark `git bisect good <commit>` (last known working state).

**Spatial binary search (state inspection at midpoints):** For data pipelines, initialization sequences, or long computation chains. Check state at the midpoint of the pipeline. Correct? Bug is downstream. Incorrect? Bug is upstream. Halves the search space with each check.

**When it fails:** The bug is an interaction between two changes that are individually correct. Git bisect finds the second change, not the first -- and the "fix" may be in the first. Also fails for non-deterministic bugs where the same commit passes and fails unpredictably.

### 4. Differential Analysis -- What Changed?

Compare the broken state to a working state. The difference contains the cause.

**Three axes of comparison:**
- **Code diff:** `git log --oneline -20`, `git diff HEAD~5`, `git diff main...HEAD`. What code changed? Focus on logic changes, not formatting.
- **Environment diff:** Different config, different dependencies, different OS version, different data. "Works on my machine" bugs live here.
- **Data diff:** Same code, different input produces different results. What's different about the failing input?

**When to use:** Something changed and the system broke. The diff narrows the search space to what's different. Most effective when the change is recent and small.

**The trap:** Large diffs. A 500-line diff makes differential analysis noisy -- too many changes to reason about. Combine with binary search (git bisect) to narrow the diff to a single commit. Also fails when the bug was latent and the "change" merely exposed it -- the diff shows the trigger, not the defect.

**For configuration bugs:** Compare the broken environment's config to a working one, layer by layer. Log what enters and exits each component boundary. Configuration bugs are invisible to code review -- the code is correct, the environment is wrong.

### 5. Boundary Analysis -- What Works vs What Doesn't

Systematically map the boundary between working and broken inputs, configurations, or code paths. The boundary itself IS the diagnosis.

**When to use:** The bug affects some cases but not others. Some inputs work, some don't. Some users see it, others don't. Some environments fail, others succeed.

**The key move:** Find the simplest pair of cases where one works and one doesn't, differing by as little as possible. If input "abc" works but "abcd" fails, the bug is in how the code handles the fourth character (or length > 3). If user A sees the bug and user B doesn't, what differs in their state?

**When it fails:** The boundary is multi-dimensional -- the bug requires a specific combination of conditions that can't be reduced to a single variable. For these, use pairwise testing: vary one dimension at a time while holding others constant.

### 6. Slicing -- Narrowing to Relevant Code

A slice is the subset of code that can affect a specific variable at a specific point. Weiser (IEEE TSE 1984) showed that programmers naturally perform mental slicing -- narrowing attention to code relevant to the failing output.

**When to use:** Large codebase, complex function, many possible paths. Slicing answers: "Of these 500 lines, which ones can possibly affect the value I'm investigating?" Everything else is irrelevant to this bug.

**How to slice manually:** Start from the incorrect value. Identify all assignments to that variable. For each assignment, identify the conditions that control whether it executes. For each condition, identify what determines its value. This backward transitive closure is your slice.

**When it fails:** The slice is too large -- in complex programs, backward slicing from an output can include most of the program. Dynamic slicing (considering only the actual execution path, not all possible paths) is much more precise but requires execution traces.

**The insight from research:** Bohme et al. (EMSE 2021) found dynamic slicing is 8 percentage points more effective than spectrum-based fault localization on 457 real bugs. Slicing works because it directly maps the infection chain -- it follows data and control flow, which is what the infection follows.

### 7. Error Message Interpretation -- Reading What the System Tells You

Stack traces, error codes, assertion messages, and log output are the system's own diagnosis. Read them carefully before investigating.

**The stack trace tells you three things:** Where the failure was detected (top frame), what called it (middle frames), and what initiated the operation (bottom frame). The bug is often NOT at the top frame -- the top frame detected the failure, but the defect is usually in a middle or bottom frame that passed bad data up.

**Error messages lie:** "Connection refused" might mean the server is down, or the firewall blocked it, or you're connecting to the wrong port, or DNS resolved to the wrong host. Don't trust the message's implied cause -- verify the actual condition.

**Log patterns matter more than individual log lines:** A single error log is a symptom. The sequence of logs leading up to it is the story. Look for: what was the last successful operation? What changed between the last success and the first failure? Are there warnings before the error that indicate degradation?

**When it fails:** The error message is misleading or too generic ("internal server error," "something went wrong"). Or the failure is silent -- wrong output with no error. In these cases, error messages can't help. Switch to state inspection or backward tracing.

### 8. State Inspection -- Actual vs Expected at Each Step

At each step of the failing operation, compare actual state to expected state. The first point where they diverge is either the defect or the infection point closest to the defect.

**When to use:** You have a theory about what the code should do, and you need to verify where reality diverges from the theory. This is the most general technique -- it works for any bug where you can observe state.

**The key move:** Write down what you EXPECT the state to be BEFORE checking. Then check. The prediction forces you to articulate your mental model, which often reveals the wrong assumption before you even inspect the state.

**How to inspect:** Add targeted logging or assertions at key points. Use a debugger to set breakpoints at state transitions. For data transformations, log input and output of each stage. For API calls, log request and response.

**When it fails:** The state space is too large to inspect exhaustively. Concurrency bugs where state changes between your inspection points. State that's correct at inspection time but wrong at use time (TOCTOU -- time-of-check-to-time-of-use). For these, narrow with slicing first, then inspect the reduced state space.

**For performance bugs:** State inspection means profiling. Don't guess where the bottleneck is -- measure. Flamegraphs (Brendan Gregg) visualize CPU time per function as stacked horizontal bars. Width = time. The widest bar is the bottleneck. Profile first, optimize the measured hotspot, profile again to verify. The sequence is: measure -> hypothesize -> fix -> measure. Never optimize without measurement.
