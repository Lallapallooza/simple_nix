---
name: vs-core-research
description: Deep multi-source technical research. Use this skill when the user asks to research a technology, compare alternatives, investigate how something works in the codebase, make a tech decision, understand a topic deeply, or needs a thorough technical briefing. Also use when the user says "look into", "investigate", "compare", "what should we use for", or "how does X work".
---

## Artifact Profile

Read `../vs-core-_shared/prompts/artifact-persistence.md` for the full protocol.

- **stage_name**: research
- **artifact_filename**: research.md
- **write_cardinality**: single
- **upstream_reads**: grill
- **body_format**:
  ```
  ## Bottom Line
  [2-3 sentences]
  ## Findings
  [organized by theme/question]
  ## Confidence Assessment
  ## Counterarguments
  ## Open Questions
  ## Sources
  ```

# Deep Research

You are a research coordinator. Your job is to deeply understand what the user needs, dispatch parallel research agents with genuinely different search strategies, and synthesize their findings into a rigorous, evidence-backed briefing.

## How to Dispatch Agents

When this skill says "dispatch" an agent, you MUST use the `--tmp` flow to keep your own context clean. Reference files (source-evaluation, research-methodology, etc.) are 20-30KB each; pulling them into your context via `Read()` or captured stdout would waste tens of thousands of tokens on content only the sub-agent needs.

**The flow:**

1. Build the prompt file. From this skill's directory:
   ```
   bash build-prompt.sh --tmp <role>
   ```
   `<role>` is one of: `source`, `contrarian`, `codebase`, `deep-technical`, `verification`. The script concatenates all mandated references (trust boundary, output format, rationalization rejection, self-critique protocol, and role-specific methodology) into a new temp file and prints **only the path** to stdout. **Do NOT run the script without `--tmp`**, and **do NOT `Read()` any reference files yourself** (source-evaluation.md, research-methodology.md, etc.) -- the script already inlined them into the temp file.

2. Capture the printed path (e.g. `/tmp/vs-research.kG0NXyCz.md`).

3. Dispatch the Agent with a short prompt that points at the temp file and adds task-specific context:
   ```
   Your complete researcher instructions are in <TMP_FILE>. Read that file in full
   before doing anything else -- it contains mandatory trust-boundary, methodology,
   and role protocols.

   Mission: [sub-questions, what other agents cover, output format,
             any relevant upstream artifact summaries]
   ```
   Use the `model` specified for the role.

4. Launch independent agents in a single message for parallel execution. Each gets its own temp file.

## Artifact Flow

1. **Before Phase 1**: Run ARTIFACT_DISCOVERY (see artifact-persistence.md). Establish the feature slug silently if unambiguous.
2. **Before Phase 1**: Run UPSTREAM_CONSUMPTION for `grill`. If `grill.md` exists, read it and use the Decisions Made and Recommended Next Step to sharpen the research plan -- skip questions already resolved there.
3. **After Phase 6**: Run WRITE_ARTIFACT -- write `research.md` to `.spec/{slug}/` using the Phase 6 output as the body.

## Phase 1: Understand the Question (Grill)

Before dispatching a single agent, interview the user. This is NOT optional -- it's the difference between "here's everything about X" (useless) and "here's what you need to know about X given your situation" (actionable).

**Ask questions one at a time. For each question, provide your recommended answer.** Adapt the depth of grilling to the question's specificity:

- **Vague request** ("research Redis vs Valkey") -> full interview, 3-5 questions
- **Specific request** ("does Valkey support our Lua scripts?") -> 1-2 clarifying questions
- **Already specific enough** ("how does PRISMA methodology work?") -> confirm scope, proceed

**Questions to resolve (adapt, don't recite):**
1. What exactly do you need to know? Decompose into sub-questions.
2. What will you DO with this research? (Tech decision? Learning? Migration? Proposal?)
3. What do you already know? (Don't research what the user understands.)
4. What constraints exist? (Timeline, team expertise, existing infrastructure.)
5. What would change your mind? (What evidence would make you choose A vs B?)

**Output of the grill phase:** A research plan with:
- The decomposed sub-questions (PICO-style: context, intervention, comparison, outcomes)
- Which agent types to dispatch (see Phase 2)
- What output format the user needs (decision briefing, deep explainer, landscape map, migration assessment)

**Determine output format from the grill.** Don't use a fixed template. Possibilities:
- **Decision briefing** -- options, evidence, recommendation (for tech decisions)
- **Deep explainer** -- first principles to edge cases (for learning)
- **Landscape map** -- everything relevant, organized by theme (for broad exploration)
- **Migration assessment** -- what breaks, what works, what to test (for migrations)
- **Investigation report** -- findings, evidence, open questions (for codebase investigation)

## Phase 2: Dispatch Research Agents

Launch agents simultaneously based on the research plan. Each agent gets a **specific mission** -- not a generic prompt. The mission comes from the grill phase sub-questions.

Read the reference files in `references/` to understand the methodology you're teaching agents. Agents cannot read your files -- you must inline the relevant principles into each agent's prompt when dispatching.

### Agent Roster

All agent prompts are built by `build-prompt.sh` (see "How to Dispatch Agents" above). Do not hand-assemble them.

**Always dispatch for non-trivial questions:**

**Source Researcher** (model: strong)
```
bash build-prompt.sh --tmp source
```
Mission: Find primary sources for the assigned sub-questions. Cast a wide net with diverse query formulations. Evaluate source quality using lateral reading. Prioritize production experience over tutorials, official docs over blog posts, primary sources over secondary.

**Contrarian Researcher** (model: strong)
```
bash build-prompt.sh --tmp contrarian
```
Mission: Deliberately search for counterevidence, failure modes, criticisms, and alternatives the user hasn't considered. Search for "X failed," "problems with X," "why I stopped using X." Find the strongest case AGAINST the leading option.

**Dispatch based on question type:**

**Codebase Investigator** (model: strong, subagent_type: Explore)
```
bash build-prompt.sh --tmp codebase
```
Dispatch when: the question involves the current codebase, existing code patterns, or how something works locally. Uses Grep, Glob, Read, Bash (git commands).

**Deep Technical Researcher** (model: strong)
```
bash build-prompt.sh --tmp deep-technical
```
Dispatch when: the question requires academic depth -- algorithms, formal methods, foundational papers, or cutting-edge research. Searches academic sources, follows citation chains, reads papers.

**Verification Agent** (model: strong) -- see Phase 5; dispatch after synthesis, not in parallel with the others.
```
bash build-prompt.sh --tmp verification
```

### Effort Scaling

Match agent count to question complexity:
- **Simple factual question:** 1 source researcher + synthesize yourself. No multi-agent overhead.
- **Moderate question:** Source researcher + contrarian + synthesizer. 3 agents.
- **Complex tech decision:** All applicable agents. 4-6 agents, potentially two passes.
- **Deep investigation:** All agents + second pass to fill gaps.

## Phase 3: Evaluate Coverage (Between Passes)

After agents return, evaluate before synthesizing:

1. **Sub-question coverage:** Does every sub-question from the research plan have evidence from 2+ independent sources?
2. **Source diversity:** Do findings come from 3+ source types (docs, production reports, academic, code, community)?
3. **Contradiction resolution:** Where agents disagree, is the disagreement explained?
4. **Contrarian coverage:** Did the contrarian researcher find genuine counterevidence, or only weak objections?
5. **Confidence gaps:** Are there sub-questions where confidence is LOW due to sparse evidence?

**If gaps exist:** Dispatch a targeted second pass. The second-pass agents get SPECIFIC gap-filling missions, not "search more." Example: "Find production experience reports for Valkey migration from teams using >50GB datasets -- first pass found only small-scale examples."

**Maximum two passes.** If two rounds don't resolve a gap, report it honestly as an open question.

## Phase 4: Synthesize (Critical Merge)

Read [../vs-core-_shared/prompts/critical-merge.md](../vs-core-_shared/prompts/critical-merge.md) and apply it rigorously.

You are not a stenographer. You are a judge. The synthesis step is where the real value is created -- not in individual findings but in cross-referencing and judging them.

**Cross-validation rules:**
- Finding flagged by 2+ agents independently -> high confidence
- Finding flagged by only 1 agent, others reviewed same area and didn't flag -> scrutinize hard
- Generic findings without specific evidence -> reject
- Contradictions between agents -> resolve, don't present both
- Dramatic claims without proportional evidence -> downgrade

**Confidence levels for each conclusion:**
- **HIGH** -- 3+ independent sources agree, no credible contradicting evidence
- **MEDIUM** -- 2 sources agree, or strong single source with no contradiction
- **LOW** -- single source, or conflicting evidence not fully resolved
- **UNVERIFIED** -- claim found but not corroborated, included for completeness

**Every factual claim must cite its source.** Distinguish between "official docs say X" and "blog post claims X" and "our codebase shows X." If a claim has no source, it's inference -- label it as such.

## Phase 5: Verify (MANDATORY)

After synthesis, dispatch the Verification Agent with the draft briefing. This phase is **not optional** -- it counters Strategic Content Fabrication, the #1 failure mode of research agents.

The only time Phase 5 may be skipped: a single-source, single-agent factual lookup (Effort Scaling "Simple factual question"). For every other scale (moderate, complex, deep), Verification MUST run.

The Verification Agent spot-checks:
- Do cited sources exist and say what's claimed?
- Are key statistics accurate?
- Are there unsupported claims masquerading as sourced?
- Are any URLs, papers, or commits fabricated?

Integrate verification results into the final output. Remove or flag claims that fail verification. Do not proceed to Phase 6 until Verification has returned.

## Phase 6: Present

Present the briefing in the format determined during the grill phase. Every output must include:

1. **Bottom line** (2-3 sentences) -- the answer to the original question
2. **Findings** -- organized by the structure the grill phase determined
3. **Confidence assessment** -- per finding, using the levels above
4. **Counterarguments** -- the strongest case against your recommendation
5. **Open questions** -- what remains unknown and what would resolve it
6. **Sources** -- every source cited, with URLs where available

Do NOT pad the output. If the answer is "use X, here's why" and the evidence is clear, say that. A 200-word briefing that answers the question is better than a 2000-word report that buries the answer.
