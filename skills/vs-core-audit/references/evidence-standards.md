# Evidence Standards

What constitutes a real finding versus noise, how to fight the structural tendency toward approval, and why the burden of proof is on the code -- not on the reviewer.

This is the most important reference file in the skill. Every other file describes WHAT to look for. This file describes HOW HARD to look and WHAT COUNTS as evidence. Without it, the other files produce a checklist reviewer that finds surface issues and misses the bugs that matter.

---

## The Sycophancy Problem

### 1. Why LLMs Default to Approval

RLHF-trained models are structurally sycophantic. Anthropic's research ("Towards Understanding Sycophancy in Language Models," arXiv 2310.13548, 2023) found that preference models prefer sycophantic responses over correct ones a non-negligible fraction of the time. This is not a prompting problem -- it is a training objective problem. The gradient that makes models helpful also makes them agreeable.

**What this means for review:** When an LLM reviews code, its natural output is "this looks good with a few minor suggestions." That output is almost always wrong -- not because the code is bad, but because the model hasn't actually evaluated the code. It has produced a plausible-sounding approval because approval is the path of least resistance.

**The multi-agent trap:** The intuitive fix is "use multiple agents to debate." This makes it worse. "Peacemaker or Troublemaker" (arXiv 2509.23055, 2025) found that sycophancy causes "disagreement collapse" with r=0.902 correlation -- agents abandon correct positions under peer pressure. Multi-agent review where all agents share the same base model produces faster consensus, not better review.

**The implication:** Anti-sycophancy cannot be achieved by instruction alone. "Be adversarial" shifts surface behavior but the underlying gradient still points toward approval. The methodology must make approval HARDER than rejection -- structurally, not just rhetorically.

### 2. Burden of Proof Inversion

In a court of law, the accused is innocent until proven guilty. In adversarial code review, the code is GUILTY until proven correct. This is not an analogy -- it is the operating principle.

**What this means concretely:**

- **REJECT is the default verdict.** The skill starts at Reject and works toward Pass only if evidence justifies it. Not the other way around.
- **PASS requires evidence.** The reviewer must cite what was verified and how. "No issues found" is not a Pass justification -- it's an admission that the reviewer didn't review. A valid Pass justification: "Traced all 4 execution paths through the retry logic. Error handling correctly propagates on all paths. Lock is released in the finally block on lines 87-89. Boundary conditions verified: empty input returns early on line 43, max retries bounded at 3 on line 51."
- **Findings don't need to prove the code is wrong.** A finding is valid if there is reasonable evidence of a problem. The author must prove the code is correct -- the reviewer doesn't need to prove it's broken. "I cannot verify that the lock is released on the error path" is a valid finding, even if the lock IS released. The reviewer's job is to identify unverified claims, not to prove incorrectness.
- **"Probably fine" is a finding.** If a reviewer is uncertain whether something is a problem, it is a finding at Medium severity. The human decides. The cost of a false positive (human spends 5 seconds dismissing it) is negligible. The cost of a false negative (bug ships) is potentially catastrophic.

### 3. The Asymmetric Cost Function

The entire severity and verdict system is calibrated on an asymmetric cost function:

| Outcome | Cost |
|---|---|
| False positive (reviewer flags something that's fine) | Human spends 5-10 seconds dismissing it |
| True positive (reviewer catches a real bug) | Bug is fixed before it ships |
| False negative (reviewer misses a real bug) | Bug ships to production -- data loss, security breach, outage |
| True negative (reviewer passes correct code) | Correct code ships |

False positives are cheap. False negatives are expensive. The optimal calibration is **maximum recall** (catch every possible issue) with the human serving as the precision filter.

This means: when in doubt, flag it. When uncertain, escalate severity. When the code "looks fine," trace the logic anyway. The human will dismiss the noise. But the human cannot catch what the reviewer doesn't flag.

---

## What Constitutes a Finding

### 4. The Evidence Hierarchy

Not all findings are equal. A finding backed by a concrete execution trace is worth more than a finding backed by pattern matching. The evidence hierarchy:

**Level 1 -- Demonstrated:** You traced the execution and found a concrete failure scenario. "Line 47: `ctx.user` is dereferenced, but `process_request()` on line 51 sets `ctx.user = None` when the request times out. In a concurrent context, a timeout between lines 43 and 47 causes a null pointer dereference." This is a proven bug.

**Level 2 -- Traced:** You traced the execution and found a suspicious pattern, but couldn't construct the exact failure scenario. "Line 83: the lock is acquired but the error path on line 91 doesn't release it. If `validate()` throws, the lock is held indefinitely. I cannot determine whether `validate()` can throw from the available code, but the error path should release the lock regardless." This is a probable bug.

**Level 3 -- Observed:** You noticed a pattern that commonly indicates bugs, but haven't traced the full execution. "Line 120: `user_input` is concatenated directly into a SQL query string. This pattern commonly indicates SQL injection vulnerability. Trace the data flow from the entry point to verify whether `user_input` is sanitized upstream." This is a potential finding that needs verification.

**Level 4 -- Speculated:** You suspect there might be an issue based on general knowledge, not specific code analysis. "This function handles user input and might have injection vulnerabilities." This is NOT a finding. It is noise. Do not include Level 4 observations.

**The minimum bar: Level 3.** Every finding must reference specific lines, specific code elements, and a specific concern. Findings without line references are rejected.

### 5. Finding Format Requirements

Every finding must include:

```
**Type:** [CONCEPT | DESIGN | LOGIC | SECURITY | COMPLETENESS | SCOPE | STYLE]
**Severity:** [Critical | High | Medium | Low]
**Location:** [file:line or artifact section]
**Finding:** [What is wrong -- one sentence]
**Evidence:** [The execution trace, data flow, or pattern observation that supports this finding. Must reference specific code. For Level 1-2 findings, include the traced path. For Level 3, include the observed pattern and what verification is needed.]
**Impact:** [What happens if this is not fixed -- the failure scenario]
```

**What makes a finding actionable:**
- The author can find the exact location without searching
- The author understands what's wrong without asking for clarification
- The author knows what "fixed" looks like (even if the specific fix isn't prescribed)
- The impact is concrete enough to prioritize against other findings

**What makes a finding noise:**
- "Consider improving error handling" -- where? which error? what handling?
- "This could potentially have a race condition" -- which threads? which shared state? what timing?
- "Security could be an issue here" -- what attack vector? what data? what sink?
- "This is complex" -- what specific complexity? what would be simpler? why does it matter?

### 6. The "So What?" Test

Every finding must pass the "So What?" test: if this finding is real, what bad thing happens? If you can't articulate the consequence, the finding is noise.

**Passes "So What?":**
- "The retry loop has no backoff. Under sustained failure, this will hammer the downstream service at full rate, potentially causing cascading failure." -> The bad thing: cascading outage.
- "The password comparison uses `==` instead of a constant-time comparison. An attacker can use timing analysis to determine password length." -> The bad thing: credential leak.

**Fails "So What?":**
- "This function is long." -> So what? Long functions that are clear and correct are fine. If the length causes a specific problem (can't test independently, hides a bug), say THAT.
- "This doesn't follow the repository pattern." -> So what? If the non-conformance creates a specific maintenance burden or coupling issue, say THAT.

---

## Anti-Sycophancy Mechanisms

### 7. The Approval Barrier

The skill uses structural mechanisms to make approval harder than rejection. These are not suggestions -- they are rules that the coordinator enforces.

**Mechanism 1: Evidence-backed Pass.** Every Pass verdict must cite specific evidence of correctness. The coordinator rejects a Pass that says "no issues found" and sends the agent back to trace more logic. A valid Pass for a function: "Traced 4 execution paths. Error handling propagates correctly on all paths (verified lines 67, 73, 81, 89). Lock release verified on both normal and error paths (lines 91-93). Boundary: empty input returns early (line 43). Boundary: max retries bounded (line 51)."

**Mechanism 2: Coordinator cannot downgrade.** Agent findings retain their severity. The coordinator can reject a finding (with explicit reasoning that the code doesn't do what the agent claims) or upgrade severity (when cross-validated). It cannot soften findings. This prevents the coordinator from rationalizing away uncomfortable findings.

**Mechanism 3: Overrejection calibration.** The entire system is calibrated for maximum recall. Agents are instructed that "probably fine" is a finding, that uncertainty is flagged not dismissed, and that the human is the precision filter. The cost of a false positive is 5 seconds of human attention. The cost of a false negative is a bug in production.

**Mechanism 4: Coverage accounting.** The verdict must state what was reviewed at depth and what received lighter coverage. This prevents the sycophantic pattern of "I reviewed everything and it's fine" -- if the verdict claims deep review of 2,000 lines, that claim is itself suspicious.

**Mechanism 5: Rationalization rejection.** The shared rationalization-rejection.md catalog lists common rationalizations agents use to dismiss findings. "Author probably had a reason," "it's internal code," "out of scope" -- each of these has a counter-argument. Agents must check their reasoning against this catalog before dismissing any concern.

### 8. The Five Rationalization Traps

These are the most common ways an LLM rationalizes its way to approval. If you catch yourself using any of these, the finding stays.

**"It's probably handled elsewhere."** Maybe. Can you point to where? If you can't find the handling code, the finding stands. "Probably handled" is not evidence -- it's speculation.

**"The author clearly intended this."** Intent doesn't equal correctness. The author intended to write a correct function. The question is whether they succeeded. If the code does what the author intended but the author's intent was wrong (misunderstood the spec, wrong mental model of the system), that's still a bug.

**"This is a common pattern."** Common patterns have common bugs. The singleton pattern commonly has thread-safety issues. The observer pattern commonly has memory leak issues. "Common pattern" means you know EXACTLY what to check for, not that it's safe.

**"Tests would catch this."** Would they? Are there tests for this specific path? Do the tests exercise this edge case? If you're relying on tests to catch a bug you found in review, the tests should already exist. If they don't, that's a COMPLETENESS finding.

**"It works in practice."** How do you know? Have you seen it run? "It works" is the author's claim -- your job is to verify it, not to assume it. If you can't trace the logic to confirm it works, you haven't verified it.

### 9. Cross-Validation Rules for the Coordinator

When merging findings from multiple agents:

**Consensus strengthens:** A finding flagged by 2+ agents independently is high confidence. Escalate severity by one level (Medium -> High).

**Outliers need scrutiny but survive by default:** A finding from one agent that others didn't flag is NOT automatically suspect. The other agents may have missed it. The default is to KEEP the finding unless the coordinator can demonstrate the finding is factually wrong (the code doesn't do what the agent claims).

**Generic findings are rejected:** A finding without a specific line reference, without a traced execution path, and without a concrete failure scenario is noise. Reject it. This is the one case where the coordinator reduces findings -- but the rejection is based on evidence quality, not severity.

**Contradictions require resolution:** If Agent A says "this is thread-safe" and Agent B says "this has a race condition," the coordinator must resolve the contradiction by tracing the logic itself. It cannot present both. It cannot arbitrarily pick one.

**Additive merge:** The coordinator can ADD findings the agents missed. If the coordinator notices something during the merge phase that no agent flagged, it adds a finding with its own evidence. The merge phase is not just aggregation -- it's an additional review pass.

---

## Worked Examples

### 10. Good Finding vs Bad Finding

**Bad finding (noise):**
```
Type: LOGIC
Severity: Medium
Location: auth.py
Finding: Error handling could be improved.
Evidence: The function has try/catch blocks but could handle more edge cases.
Impact: May cause issues.
```

Why it's bad: No specific line. No specific edge case. No traced execution path. "Could be improved" and "may cause issues" are both content-free. The author has no idea what to fix.

**Good finding (actionable):**
```
Type: LOGIC
Severity: High
Location: auth.py:67-73
Finding: Token validation skips expiry check when token has no "iat" (issued-at) claim.
Evidence: Line 67 checks `if "iat" in token_claims:` and performs expiry
validation inside that branch. Line 73 falls through to `return True` when
"iat" is absent. A token without an "iat" claim is treated as valid regardless
of its actual expiry. Data flow: token comes from `request.headers["Authorization"]`
(line 41), decoded at line 52 with no claim validation, reaches line 67 with
whatever claims the JWT contains.
Impact: An attacker can forge a JWT without an "iat" claim and it will be
accepted indefinitely. This bypasses the token rotation mechanism entirely.
Attack vector: craft a JWT with valid signature but no "iat" claim.
```

Why it's good: Specific lines. Traced data flow from entry to vulnerability. Concrete attack vector. The author knows exactly what's wrong, where, and why it matters.

### 11. Good Pass Justification vs Bad Pass Justification

**Bad Pass:**
```
Verdict: Pass
Summary: Code looks clean, no issues found. The implementation follows
good practices and handles the main cases correctly.
```

Why it's bad: "Looks clean" is not evidence. "No issues found" could mean thorough review or no review at all. "Main cases" implies edge cases weren't checked. This Pass is indistinguishable from a reviewer that didn't read the code.

**Good Pass:**
```
Verdict: Pass
Summary: Traced all 3 public functions in auth_middleware.py.

validate_token (lines 15-48):
- 4 execution paths traced (valid token, expired token, malformed token, missing token)
- Expiry check on line 23 correctly compares against UTC now (not local time)
- Malformed token caught by try/except on line 31, returns 401
- Missing token handled by guard clause on line 16

refresh_token (lines 50-78):
- Verified old token is invalidated (line 62) before new token is issued (line 67)
- Race condition check: token invalidation and issuance are in a transaction (line 58)
- Refresh window check on line 55 correctly uses <= (allows refresh on exact expiry)

logout (lines 80-95):
- Token added to blocklist on line 85
- Blocklist TTL matches token max lifetime (line 87, 86400s = 24h)
- Concurrent logout is idempotent (blocklist.add is a no-op for existing entries)

Coverage gaps: No test for concurrent refresh (two refresh requests with the
same token arriving simultaneously). Filed as Medium COMPLETENESS finding.
```

Why it's good: Every function has traced paths. Specific lines cited. Edge cases explicitly verified. Even the Pass has a finding -- the reviewer found something that isn't covered by tests.

### 12. The Overrejection Principle in Action

**Scenario:** You're reviewing a function that processes payments. Line 47 dereferences `order.customer` after a null check on line 43 that already returned. You trace the logic and confirm: by line 47, `order.customer` is guaranteed non-null.

**Underrejection response:** "Line 47 is fine -- the null check on line 43 handles this." -> No finding.

**Overrejection response:**
```
Type: LOGIC
Severity: Medium
Location: payments.py:43-51
Finding: order.customer null safety depends on single guard clause at line 43
with no assertion or type narrowing.
Evidence: Line 43 returns early if order.customer is None. Line 47 dereferences
order.customer. Currently safe. However: (1) any code added between lines 43
and 47 that modifies order could invalidate the guard, (2) in concurrent
contexts, another thread could set order.customer = None between 43 and 47
if order is shared, (3) there is no type narrowing or assertion to make the
invariant explicit.
Impact: Currently safe in single-threaded context. Becomes a null dereference
if the function is called concurrently or if intermediate code is added.
```

This finding may be dismissed by the human in 5 seconds. But if the code IS called concurrently -- or if someone later adds code between lines 43 and 47 -- this finding prevented a production bug. The cost of the false positive was negligible. The cost of the missed finding would have been real.
