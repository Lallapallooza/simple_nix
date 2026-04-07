# Self-Critique (Mandatory Before Completion)

Before submitting your result, you must verify your own work. Unverified work is unacceptable.

## Why This Protocol Exists

LLMs cannot reliably self-correct reasoning without external feedback -- introspective verification ("based on my output, I believe...") degrades accuracy below baseline (Huang et al., ICLR 2024). Tool-grounded verification works because the feedback comes from outside the model's belief distribution (CRITIC, ICLR 2024). This is why every factual claim below requires a tool result, not self-assessment.

## Step 1: Generate 5 Verification Questions

Create 5 questions specific to this task that would expose gaps, errors, or missed requirements. Each question must target a concrete, checkable claim in your output -- not vague impressions.

Good questions name specific things: a function, a file, a test, a config key, a code path. Bad questions are abstract ("Is the code correct?" "Did I cover everything?").

Each question should restate the relevant part of the original task -- this anchors verification against the actual requirements rather than your assumptions about them.

## Step 2: Tool-Grounded Verification (CRITIC Protocol)

For each question, you MUST attempt verification with tools BEFORE answering. The tool result IS the evidence. Your own reasoning about what should be there is not evidence.

### Verification rules

**Factual claims MUST be tool-verified.** A factual claim is any assertion about the state of code, files, tests, or configuration -- things that exist or do not exist, handle or do not handle, pass or do not pass. Use Grep, Read, Glob, or Bash to check. If the tool confirms the claim, mark PASS. If it contradicts, mark FAIL and note what you found.

**Strategic judgments do NOT require tool verification.** A strategic judgment is advice or assessment that cannot be falsified by reading a file -- e.g., "this abstraction is too leaky" or "the design over-indexes on the happy path." For these, skip tool use and mark UNVERIFIABLE.

**Claims with both a factual premise and a strategic judgment: verify the fact, leave the judgment.** If you claim "the error handler is too permissive because it catches all exceptions," verify that it catches all exceptions (factual), and leave the assessment of whether that is too permissive (strategic) as UNVERIFIABLE.

**If no tool can reach a factual claim**, mark it UNVERIFIABLE. Do NOT substitute introspection ("based on my output, I believe..."). Tool-less self-verification on factual claims degrades correctness below baseline -- this is why the protocol exists.

**If you are verifying claims against provided text** (e.g., you received an investigation trace, test output, or design document as input rather than reading codebase files): cite the specific passage directly in the Tool Result Summary column and mark PASS/FAIL based on whether you can quote the supporting text. No tool invocation is needed for text already in your context -- direct citation IS the evidence.

### Output format

| # | Question | Tool Used | Tool Result Summary | Verdict |
|---|----------|-----------|---------------------|---------|
| 1 | ... | Grep / Read / Glob / Bash / UNVERIFIABLE | [what the tool returned] | PASS / FAIL / UNVERIFIABLE |
| 2 | ... | | | |
| 3 | ... | ... | ... | ... |
| 4 | ... | ... | ... | ... |
| 5 | ... | ... | ... | ... |

### Examples

**Good -- tool-grounded verification:**

Question: "Does `parse_config` handle missing keys without crashing?"
Action: `Grep pattern="parse_config" path="src/"` -- found definition in `src/config.rs:44`. Then `Read file_path="src/config.rs" offset=44 limit=30` -- confirmed `unwrap_or_default()` is used on all key lookups.
Verdict: PASS. Tool result: `unwrap_or_default()` at lines 48, 51, 55.

---

**Bad -- introspective self-answering (do not do this):**

Question: "Does `parse_config` handle missing keys without crashing?"
Action: [none]
Verdict: PASS. Based on my implementation above, I designed it to use safe defaults.

This is forbidden. "Based on my output" is not evidence. Run the tool.

---

**Edge case -- factual premise plus strategic judgment:**

Question: "Is the retry logic too aggressive given the rate limits?"

The factual premise: does the retry logic exist and what does it do?
Action: `Grep pattern="retry" path="src/"` -- found `src/client.rs:102`. `Read` confirms 5 retries with 100ms fixed delay.
Factual verdict: PASS -- retry logic confirmed at `src/client.rs:102-115`, 5 retries, 100ms fixed delay.

The strategic judgment: whether 5 retries at 100ms is "too aggressive" given the rate limits.
Verdict: UNVERIFIABLE -- this requires knowledge of the upstream rate limit policy, which is not in the codebase. Do not self-answer.

---

**UNVERIFIABLE -- no tool path exists:**

Question: "Is the module boundary between auth and billing appropriate for future scaling?"
Action: No tool can verify architectural fitness for hypothetical future requirements.
Verdict: UNVERIFIABLE. Note: if this judgment is important, flag it as a review comment rather than treating it as a verification failure.

## Step 3: Revise If Needed

If ANY question yields FAIL:
1. STOP -- do not submit incomplete work
2. FIX -- address the specific gap identified by the tool result
3. RE-VERIFY -- run the same tool check again to confirm the fix
4. Update the verdict in the table above to PASS with the new tool result

UNVERIFIABLE items do not block submission. FAIL items do.
