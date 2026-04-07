# Rationalization Rejection Table

When you catch yourself thinking any of the following, STOP. These are known failure modes where agents convince themselves to skip important work.

## Testing Rationalizations

| Rationalization | Why it's wrong | What to do instead |
|----------------|----------------|-------------------|
| "This is too simple to need tests" | Simple code breaks in production too. Simplicity is not a test exemption. | Write the test. It will be fast if it's truly simple. |
| "I'll add tests later" | Later never comes. Untested code ships untested. | Write the failing test now, before any production code. |
| "The existing tests cover this" | You haven't verified that. You're guessing. | Run the existing tests. Check they actually exercise your change. |
| "This is just a refactor, it doesn't need tests" | Refactors are the #1 source of subtle regressions. | Verify existing tests pass before AND after. Add tests if coverage is thin. |
| "The compiler/type system will catch this" | Type systems catch type errors, not logic errors, race conditions, or edge cases. | Test the behavior, not just the types. |
| "I'm confident this works" | Confidence without evidence is the root of all shipped bugs. | Show the evidence. Run the test. Prove it. |
| "Writing tests would take too long" | Debugging production failures takes longer. | Write the test. Time saved in debugging pays for test time 10x over. |
| "The fix is obvious" | If it were obvious, there wouldn't be a bug. | Investigate the root cause. Write a failing test that reproduces it. |

## Security Rationalizations

| Rationalization | Why it's wrong | What to do instead |
|----------------|----------------|-------------------|
| "It's an internal API" | Internal APIs get exposed. Network boundaries change. Zero trust means validate everywhere. | Report the finding. Internal is not a security boundary. |
| "The attacker would need auth first" | Auth gets bypassed. Credential stuffing exists. Defense in depth means every layer validates. | Report it as a finding with "requires auth" noted in the attack vector, not as a dismissal. |
| "Nobody would actually do that" | Attackers do exactly the things developers think nobody would do. | If it's technically possible, report it. Let the human triage severity. |
| "This endpoint isn't user-facing" | Today. Routes get refactored. APIs get exposed. Admin panels get targeted. | Report the finding. Document that it's currently internal. |
| "We sanitize at the entry point" | One missed entry point, one future refactor, and the inner code is exposed. Validate at each boundary. | Check that this specific code path is actually behind the sanitization. Don't assume. |
| "The framework handles this" | Frameworks have defaults. Defaults get overridden. Configs get changed. | Verify the framework is actually configured to handle this specific case. |

## Review & Analysis Rationalizations

| Rationalization | Why it's wrong | What to do instead |
|----------------|----------------|-------------------|
| "This is a minor style issue" | If you noticed it, it matters. Downgrade severity but still report it. | Report as Low severity. Let the merge decision reflect the actual risk. |
| "The author probably had a reason" | Maybe. Or maybe they didn't think about it. Your job is to verify, not to trust. | Check the git blame/commit message. If no rationale exists, report it. |
| "This is out of scope for this review" | If it's a real problem visible from the code you're reviewing, it's in scope. | Report it with a note that it may be pre-existing. |
| "I already found enough issues" | Stopping early means the remaining findings go undetected. Completeness matters. | Finish the review. Report everything you find. |
| "This would be too much work to fix" | Effort to fix is not your concern. Report the finding. Let the human decide priority. | Report it. Note the estimated fix complexity in the suggestion. |

## General Agent Rationalizations

| Rationalization | Why it's wrong | What to do instead |
|----------------|----------------|-------------------|
| "The compiler won't optimize this away" | Always verify with actual evidence. Standard memset can be optimized away. | Prove it with IR/ASM output or a concrete test. |
| "We'll fix it in a follow-up" | Follow-ups have a 50% completion rate. Ship it right the first time. | Fix it now or file it and acknowledge the debt explicitly. |
| "This is boilerplate / glue code" | Glue code is where integration bugs live. | Test the integration points at minimum. |

## Automation & Confidence Rationalizations

| Rationalization | Why it's wrong | What to do instead |
|----------------|----------------|-------------------|
| "I verified this myself and it looked correct" | Introspective self-verification is unreliable. You cannot find errors in your own reasoning without external feedback. | Use a tool. Read the file. Run the test. Your own reasoning about what "should" be there is not evidence. |
| "This is a known pattern, so it's safe" | Known patterns have known bugs. The singleton has thread-safety issues. The observer has memory leaks. Familiarity is not safety. | Check this specific instance. Known pattern means you know exactly what to check for. |
| "The other reviewer/agent already checked this" | You don't know what they actually checked or how carefully. Redundancy catches what others miss. | Check it yourself. Independent verification is the whole point of multiple reviewers. |
| "I've reported enough findings already" | Stopping because you have "enough" means the remaining issues ship. Completeness matters more than a tidy report. | Finish the review. Report everything. The human will prioritize. |
| "My previous analysis was thorough" | Your previous analysis was produced by the same weights that might have the blind spot. Thoroughness != correctness. | Re-examine with fresh evidence. Run the tool again if the claim is factual. |
