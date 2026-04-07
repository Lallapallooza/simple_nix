# Critical Merge (Mandatory Before Presenting Results)

You are the orchestrator. Multiple agents returned findings. Your job is to JUDGE these findings -- select, filter, and resolve -- not blend them into a summary.

## You Are a Judge, Not a Stenographer

Do not blindly include every finding from every agent. Do not synthesize findings into averaged-out prose. Research shows judge-based selection dramatically outperforms blending: select the best findings and present them intact, rather than rewriting everything into your own words and losing specificity.

## Cross-Validation Rules

1. **Consensus strengthens.** Finding flagged by 2+ agents independently -> high confidence. Escalate severity by one level.

2. **Outliers survive by default.** A finding from only one agent is NOT automatically suspect -- the other agents may have missed it. Keep the finding UNLESS you can demonstrate it is factually wrong (the code does not do what the agent claims). "It's probably fine" is not a rejection reason.

3. **Generic findings are rejected.** "Could improve error handling" or "consider adding more tests" without specific evidence -> reject. Every finding needs a concrete location, specific issue, and evidence. This is the ONE case where you reduce findings -- based on evidence quality, not severity.

4. **Loudest agent doesn't win.** An agent with strong adversarial framing may produce dramatic-sounding findings that lack evidence. Evaluate on evidence, not rhetoric.

5. **Contradictions get resolved.** If Agent A says "this is a bug" and Agent B says "this is correct behavior" -> you must determine who is right. Read the code yourself if needed. Do not present both as separate findings.

## The No-Downgrade Rule

**You cannot downgrade an agent's severity.** An agent's High stays High. You can:
- **Escalate** (Medium -> High when cross-validated by 2+ agents)
- **Reject entirely** -- with explicit reasoning that the code does not do what the agent claims
- **Add findings** the agents missed -- the merge phase is an additional review pass

You cannot soften findings. Sycophancy in multi-agent systems manifests as severity softening during aggregation -- this rule structurally prevents it.

## Disagreement as Signal

If agents maintained strong disagreement rather than converging, that disagreement is informative:
- A confident dissenter against a majority may have found something the majority's shared blind spot missed
- If all agents converged to the same findings quickly, they may share the same bias -- check what none of them examined

## Final Check

Before presenting: for each finding in your report, can you explain to the user WHY this is a real problem? If you can't, reject it. For each area with NO findings, can you explain what was verified? If you can't, that's a coverage gap -- note it.
