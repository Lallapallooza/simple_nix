# Research Methodology & Epistemology

A decision framework for conducting rigorous research, not a checklist. Each topic is how a senior researcher thinks about the trade-off, written for someone who knows how to search but hasn't yet internalized when to stop, when to doubt, and when good enough is better than complete.

All research advice is context-dependent: what's right for a tech decision is wrong for a literature survey, what's right under time pressure is wrong for a regulatory filing. Calibrate every topic against your question, stakes, and time budget.

---

## Decomposition & Question Design

### 1. Decompose Before Searching -- The PICO Principle

The Cochrane Collaboration's PICO framework (Population, Intervention, Comparison, Outcomes) works beyond medicine. Any research question maps to: What context? What specific thing? Compared to what? Measured how?

"Should we use Redis or Valkey?" decomposes to: for our 50GB Lua-heavy workload (P), migrating to Valkey (I), compared to staying on Redis (C), measured by compatibility, performance, and maintenance burden (O). Each component becomes a separate sub-question with its own search strategy.

**Why decomposition works:** It prevents the "boil the ocean" failure where you search for everything about a topic and drown in results. Each sub-question has a tractable answer. Cochrane deliberately searches only P + I + Study Type, dropping C and O from search terms to maximize recall -- the comparison and outcomes are applied during screening, not during search.

**The smell:** You're searching for "Redis vs Valkey" as a single query. That returns marketing pages and shallow comparisons. Decompose into "Valkey Lua scripting compatibility," "Redis to Valkey migration production experience," "Valkey performance benchmarks 50GB dataset."

**The signal:** Each sub-question has a clear "what would answer this?" before you start searching. If you can't articulate what evidence would satisfy a sub-question, the question isn't specific enough.

### 2. Fermi Decomposition -- Estimate Before You Search

Tetlock's superforecasters decompose complex questions into knowable and unknowable components, estimate each independently, then combine. "How long will the migration take?" becomes: how many Lua scripts (knowable), what percentage use Redis-specific commands (searchable), how long to port each (estimable).

**The judgment:** Generate your own estimate BEFORE looking up answers. This prevents anchoring on the first number you find. Tversky and Kahneman showed that a random number on a spinning wheel shifted expert estimates by 20 percentage points. Your first search result is that wheel.

**The smell:** You read "migration takes 2 weeks" in a blog post and accept it without checking your own decomposition. That blogger had 3 Lua scripts. You have 200.

**The signal:** Your independent estimate and the evidence roughly agree, or you can explain exactly why they diverge.

### 3. Pre-Registration -- Decide What You're Looking For Before You Look

The replication crisis taught science a painful lesson: analytical flexibility (choosing what to measure after seeing data) inflates false-positive rates from 5% to 60%+ (Simmons, Nelson, & Simonsohn 2011). The same applies to research: if you decide what counts as evidence after you've found it, you'll confirm whatever you already believe.

**Pre-registration for research:** Before searching, write down: (1) what question you're answering, (2) what evidence would change your mind, (3) what output format you'll produce. This is your protocol. Changes to the protocol are fine -- but document them explicitly.

**The smell:** Your research conclusion perfectly matches your initial intuition, and every source you found supports it. You didn't pre-register, so you can't tell whether you found the truth or cherry-picked your way to a comfortable answer.

**The signal:** Your protocol changed during research because you learned something unexpected. That's not a failure -- it's the system working. Document what changed and why.

### 4. The Research Question Hierarchy -- Not All Questions Are Equal

Some questions are clock-like (deterministic, answerable): "What's the syntax for X?" Others are cloud-like (probabilistic, uncertain): "Will this architecture scale?" Tetlock's triage: focus effort on questions in the Goldilocks zone -- not trivially answerable, not fundamentally unknowable.

**Clock-like questions** need lookup, not research. A single authoritative source suffices. Don't dispatch five agents for "what port does PostgreSQL use."

**Cloud-like questions** need triangulation, competing hypotheses, and confidence levels. "Should we migrate to microservices?" has no single right answer -- it depends on context, constraints, and values.

**The smell:** You're spending 30 minutes researching a clock-like question. Or you're presenting a cloud-like answer with false certainty.

---

## Hypothesis-Driven Research

### 5. Analysis of Competing Hypotheses -- The ACH Method

Richards Heuer (CIA, 1999) developed ACH to counter confirmation bias. The method: enumerate ALL plausible hypotheses before searching. Build a matrix: rows = hypotheses, columns = evidence. For each piece of evidence, score it against ALL hypotheses simultaneously. Focus on evidence that DISCRIMINATES -- evidence consistent with all hypotheses has zero diagnostic value.

**The critical move:** Work ACROSS the matrix (one piece of evidence against all hypotheses) not DOWN it (all evidence for one hypothesis). Working down is how confirmation bias operates. Working across forces comparison.

**Reject by inconsistency, not by lack of support.** The hypothesis with the least inconsistent evidence wins -- not the one with the most supporting evidence. This is disconfirmation-based reasoning.

**When to use ACH:** Any question with 3+ plausible answers where evidence is ambiguous. Tech decisions, architecture choices, debugging (what's causing the bug?), vendor selection.

**When it's overkill:** Binary factual questions. Questions with clear consensus. Very early exploration where you don't have enough evidence for a matrix.

**The smell:** You have a favorite hypothesis and you're building a case for it. Every search query includes terms that assume it's correct.

**The signal:** You found evidence that discriminates -- it's consistent with only one hypothesis and inconsistent with the rest. That evidence drives the conclusion more than any amount of confirming data.

### 6. The Key Assumptions Check

The CIA Tradecraft Primer identifies this as the most underused analytical technique. Before starting research, list ALL premises -- stated AND unstated. For each: Why must this be true? Could it have been true historically but not now? What information would undermine it?

**Unstated assumptions are the most dangerous.** The DC Sniper case: the unchallenged assumption that the sniper was a white male driving a white van delayed identification. Pearl Harbor: State Department gave 5-to-1 odds Japan would NOT attack, one week before.

**For technical research:** "We assume the library is still maintained." "We assume our workload is typical." "We assume the benchmarks reflect production." Each assumption is a potential point of failure. Make them explicit, then test them.

**The smell:** You're 80% through research and discover a foundational assumption was wrong. You should have checked it first.

### 7. Devil's Advocacy -- Argue Against Your Own Conclusion

After reaching a preliminary conclusion, systematically argue against it. Not as a formality -- as a genuine attempt to find the strongest countercase. The CIA uses Team A/Team B: separate teams build the best case for competing hypotheses, present with rebuttals before a jury.

**For an AI research agent:** After synthesis, generate the strongest counterargument. Present it alongside the recommendation. If you cannot articulate a credible counterargument, your research is incomplete -- you haven't looked hard enough at the other side.

**The smell:** Your "counterarguments" section lists weak objections you can easily dismiss. Real devil's advocacy finds arguments that genuinely threaten your conclusion.

---

## Confidence & Calibration

### 8. The GRADE System -- Rating Evidence Quality

The GRADE framework rates evidence across four levels: HIGH (very unlikely to change), MODERATE (likely to change), LOW (very likely to change), VERY LOW (extremely uncertain). Evidence starts at a baseline and is downgraded or upgraded based on specific criteria.

**Five downgrade domains:** Risk of bias (who funded it, conflicts of interest), Inconsistency (do sources agree?), Indirectness (does the evidence match your specific question?), Imprecision (how specific is the evidence?), Publication bias (are you only finding one side?).

**Three upgrade domains:** Large effect (multiple independent sources strongly agree), Dose-response gradient (more X consistently produces more Y), Plausible confounding would reduce effect (bias should work against the finding, but the finding persists).

**The judgment:** Having many sources does NOT mean high confidence if they all share the same flaw. Ten blog posts citing the same benchmark with the same methodology is one source, not ten.

**The smell:** You rate confidence as "high" because you found five sources. But all five cite the same original paper, which was funded by the vendor being evaluated.

**The signal:** Your confidence rating explicitly names what could change it. "HIGH -- unless the benchmark methodology is flawed, which I cannot verify without access to the test harness."

### 9. Precise Probabilities Beat Verbal Hedges

Tetlock's superforecasters distinguish 60% from 55% from 65%. "Likely" means different things to different people -- NATO found that "probable" was interpreted anywhere from 25% to 90%. Precise numbers create accountability and enable calibration tracking.

**For research conclusions:** "We are 75% confident this migration will succeed without breaking Lua scripts, based on compatibility reports from 4 production users. The remaining 25% uncertainty comes from our use of deprecated Redis-specific commands that no migration report addressed."

**The smell:** "This approach will probably work." Probably = 51%? 70%? 95%? Nobody knows, including you.

### 10. Base Rates First -- The Outside View

Before evaluating any specific claim, ask: "How often are claims like this true in general?" This is Kahneman's outside view. Most published research findings are false (Ioannidis 2005). Most migration estimates are optimistic. Most benchmarks are gamed.

**The procedure:** Start with the base rate. Then adjust for case-specific evidence. A blog post claiming "10x performance improvement" from a library migration starts at the base rate for such claims (usually exaggerated by 2-5x), then adjusts based on the quality of the specific evidence.

**The smell:** You accept a dramatic claim because the source seems credible, without checking how often similar claims turn out to be true.

**The signal:** Your analysis explicitly states: "The base rate for successful zero-downtime migrations at this scale is approximately 60% based on three production case studies. Our specific situation has [factors] that adjust this to approximately 70%."

---

## Saturation & Stopping

### 11. Four Types of Saturation -- Knowing When You've Found Enough

Saunders et al. (2018) identified four distinct saturation models:

| Type | What saturates | Signal | Best for |
|---|---|---|---|
| Theoretical | Category properties | No new insights from data | Grounded exploration |
| Inductive thematic | Emerging codes/themes | Codebook stabilizes | Open-ended research |
| A priori thematic | Pre-defined categories | All categories filled | Targeted investigation |
| Data saturation | Surface information | "Same comments again" | Quick surveys |

**The critical distinction:** Code saturation (finding all themes) happens BEFORE meaning saturation (understanding all themes). Guest et al. (2006) found code saturation at ~12 interviews, but meaning saturation required 16-24. An agent that stops at code saturation has the map but not the terrain.

**The smell:** You declare "enough" because the last 3 sources said the same thing. But you haven't checked whether you understand the nuances, edge cases, and interactions between what you found.

**The signal:** You can explain not just WHAT you found, but WHY different sources disagree, what the edge cases are, and what would change the picture.

### 12. A Priori Thematic Saturation -- The Best Default for AI Research

Define your categories before searching: pros, cons, implementation details, alternatives, failure modes, production experience. Search until each category has evidence from 2+ independent sources. This is more tractable than open-ended saturation because you know what "done" looks like.

**When to switch to inductive:** When your pre-defined categories keep missing important findings. If sources consistently discuss a theme you didn't anticipate, add a category and search for it explicitly.

**The smell:** Your pre-defined categories perfectly match your findings. Either you got lucky, or you're forcing evidence into boxes.

### 13. The Diminishing Returns Curve

Track information gain per source. The first few sources teach a lot. By source 10-12, you're mostly finding repetition. The curve flattens -- but it never reaches zero. The question is whether the marginal information gain justifies the cost.

**Practical stopping rules:**
- 3 consecutive sources adding zero new themes -> code saturation reached
- All pre-defined categories have 2+ independent sources -> a priori saturation
- New sources only add nuance to existing themes, not new themes -> approaching meaning saturation
- The same names, papers, and projects keep appearing across searches -> the citation network is saturated

**The smell:** You're on source 25 and still searching "just in case." The last 10 sources added one minor detail total.

**The signal:** You can articulate exactly what remains unknown and make a conscious decision about whether that gap matters for the question at hand.

### 14. Time-Boxing -- When "Good Enough" Is Better Than Complete

The UK Rapid Evidence Assessment methodology explicitly trades comprehensiveness for speed. A REA is "more rigorous than ad hoc searching but less exhaustive than a systematic review." The key: acknowledge and document the trade-off rather than pretending to be comprehensive.

**For AI research:** Not every question deserves 4 parallel agents and 50 sources. Simple questions get single-pass search with 3-5 sources. Complex questions get multi-pass with saturation tracking. The coordinator should allocate resources proportional to question complexity and stakes.

**The smell:** Every research task gets the same heavyweight treatment regardless of complexity. Or every task gets the same lightweight treatment regardless of stakes.

---

## Iterative Refinement

### 15. Concurrent Analysis -- Process Each Source Before Deciding What to Search Next

Grounded theory's core principle: analyze during collection, not after. Each source should update your understanding before you decide what to search for next. This is how good research adapts to what it finds.

**The anti-pattern:** Batch-collect 20 sources, then read them all, then synthesize. By the time you read source 15, you realize sources 1-14 were answering the wrong question -- but you've already spent the budget.

**The procedure:** Read source -> update working synthesis -> identify gaps -> formulate next search -> repeat. The research plan is a living document that evolves with each source.

**The smell:** Your search queries at the end of research are identical to your queries at the beginning. You didn't learn anything that changed what you're looking for.

### 16. The Focus Formulation Pivot -- The Most Important Moment in Research

Kuhlthau's Information Search Process identifies Stage 4 (Focus Formulation) as the turning point. Before this, you're exploring broadly. After this, you're collecting with purpose. The pivot happens when you form a personal perspective within the topic -- not just "what exists" but "what matters for my question."

**The feeling before the pivot:** Confusion, too many sources, contradictory findings, uncertainty about direction. This is NORMAL. Kuhlthau calls it "the dip." Many research efforts are abandoned here because the confusion feels like failure.

**The feeling after the pivot:** Clarity about what matters, ability to filter sources quickly, confidence in what to search for next.

**The smell:** You're deep into research and feel overwhelmed by contradictory sources. You want to either give up or just pick one side. Both are wrong -- you're in the dip, and the pivot is coming.

**The signal:** You can suddenly articulate "the real question is..." and it's different from what you started with. That reframing IS the pivot.

### 17. What-If Analysis -- Assume the Unexpected Happened

The CIA Tradecraft Primer's What-If technique: assume a surprising outcome HAS occurred, then reason backwards about what must have been true. "What if the migration fails catastrophically?" -> What would cause that? -> Are any of those causes present now?

**For technical research:** "What if this library is abandoned in 6 months?" forces you to check maintenance signals (commit frequency, issue response time, bus factor). "What if performance is 10x worse than benchmarks?" forces you to check benchmark validity.

**The smell:** Your research only considers the happy path. No failure mode analysis, no contingency planning, no "what would make this recommendation wrong?"

### 18. Sensemaking -- Plausibility Before Accuracy

Weick's sensemaking theory: people construct meaning retrospectively from ambiguous information. A plausible story that enables the next action is more valuable than a perfect understanding that paralyzes.

**For research:** Produce working hypotheses early. Don't wait until all evidence is in to form a view. But label it as provisional: "Based on 6 sources, our working hypothesis is X. This could change if we find Y." The hypothesis directs subsequent search -- which is the point.

**When accuracy matters more than plausibility:** Regulatory filings. Security assessments. Anything where acting on a plausible-but-wrong story has irreversible consequences. In those cases, accept the cost of slower convergence.

**The smell:** You refuse to commit to any position until you've read everything. Research without working hypotheses is aimless browsing.

---

## Multi-Agent Coordination

### 19. Effort Scaling -- Match Resources to Question Complexity

Anthropic's multi-agent research system embeds effort-scaling rules directly in prompts: simple queries get 1 agent with 3-10 tool calls; complex queries get 10+ subagents. The failure mode of fixed-effort research is either wasting resources on simple questions or under-investigating complex ones.

**The judgment:** A factual lookup ("what version of Python supports match statements?") should take 30 seconds and one search. A tech decision ("should we rewrite our data pipeline in Rust?") should take 20 minutes and 30+ searches across multiple agents. The coordinator must distinguish these before dispatching.

**The smell:** Every question gets the same 5-agent treatment. Simple questions are over-investigated; complex questions are under-investigated.

### 20. Context Isolation -- Each Agent Gets a Clean Window

The most important architectural insight from production multi-agent systems: each sub-agent should work in an isolated context window. They receive only their specific task, produce a condensed summary, and never see each other's intermediate reasoning.

**Why isolation matters:** It prevents anchoring. If Agent B sees Agent A's findings before searching, Agent B will unconsciously seek confirming evidence. Isolated agents with different search strategies produce genuinely diverse findings. Exa's research system demonstrated that agents seeing each other's outputs produced less diverse, lower-quality results.

**The smell:** All agents share a context and build on each other's findings. They converge on the same sources and the same conclusions -- you got one opinion five times.

### 21. The Coordinator's Job -- Judge, Don't Aggregate

After agents return findings, the coordinator must JUDGE them, not concatenate them. This is the critical-merge principle: reject outlier findings that don't survive scrutiny, resolve contradictions rather than presenting both sides, downgrade dramatic claims that lack evidence, and cross-validate across agents.

**The Anthropic lesson:** Multi-agent orchestration with specialized sub-agents outperformed single-agent research by 90.2%. But the value wasn't in parallelism -- it was in the synthesis step where findings were cross-referenced and judged.

**The smell:** The final report is a collage of agent outputs with headers. No contradictions resolved, no findings rejected, no confidence levels assigned. That's aggregation, not synthesis.

### 22. The Second Pass -- Filling Gaps, Not Repeating Search

After the first round of agents returns, the coordinator should evaluate coverage: which sub-questions remain unanswered? Which findings lack corroboration? Which contradictions are unresolved? A second pass dispatches targeted agents for specific gaps.

**The key principle:** The second pass must articulate WHAT is missing before dispatching. "Search more" is not a valid second-pass instruction. "Find production experience reports for Valkey migration from Redis with Lua scripting -- the first pass found only blog posts, no first-hand accounts" is valid.

**The stopping rule:** Two passes maximum. If two rounds don't resolve a gap, report it honestly as an open question rather than searching indefinitely.

**The smell:** Second-pass agents return the same sources the first pass found. The gap wasn't specific enough.

---

## Research Anti-Patterns

### 23. Confirmation Bias -- The Seven Mechanisms

Nickerson (1998) identified seven distinct mechanisms of confirmation bias, each requiring a different countermeasure:

1. **Selective search** -- searching only for confirming evidence. Counter: for every confirming search, run an explicit disconfirming search ("problems with X," "X failed").
2. **Biased interpretation** -- same data reads differently depending on prior beliefs. Counter: state the evidence first, then the interpretation. Ask: "How would someone who disagrees interpret this?"
3. **Preferential weighting** -- confirming evidence gets more weight. Counter: apply identical scrutiny to confirming and disconfirming evidence (the Millikan rule).
4. **Belief perseverance** -- initial beliefs resist change despite evidence. Counter: if the first 3 sources agree, the 4th that disagrees should get MORE attention.
5. **Biased assimilation** -- rating the same evidence as more convincing when it confirms. Counter: blind evaluation (read the evidence before knowing if it confirms or denies).
6. **Positive test strategy** -- testing hypotheses by seeking confirming cases. Counter: explicitly search for disconfirming cases first.
7. **Illusory correlation** -- perceiving relationships that don't exist. Counter: demand quantitative evidence, not anecdotes.

**The smell:** All your sources agree. This almost never happens in genuinely contested questions -- it usually means your search was biased.

### 24. First-Result Bias -- The Anchoring Trap

The first search result anchors all subsequent reasoning. Tversky and Kahneman's wheel-of-fortune experiment: a random number shifted expert estimates by 20 points. Your first Google result is that random number.

**Counter:** Run 3-5 diverse search queries before reading any result deeply. Scan the landscape before anchoring on a single source. Start with the diversity of perspectives, not the depth of one.

**The smell:** Your conclusion is based primarily on the first source you found. Everything else "confirms" it.

### 25. Research Theater -- Impressive Output That Doesn't Answer the Question

Feynman's "Cargo Cult Science": following the form of research (many sources, structured output, confidence levels) without the substance (genuine attempt to find the truth, including uncomfortable truths).

**The FINDER benchmark quantified this:** Strategic Content Fabrication accounts for 18.95% of deep research agent failures -- agents generate "plausible but unsupported content" and "mimic factual grounding for checklist compliance rather than verifying actual evidence."

**The smell:** The research report is comprehensive, well-structured, and cites 20 sources. But none of the cited sources actually contain the specific claims attributed to them. Or the claims are real but don't actually answer the original question.

**The signal:** Every claim in the report can be traced to a specific passage in a specific source. Claims without traceable sources are marked as inference or opinion.

### 26. Citation Laundering -- When the Evidence Chain Has No Foundation

Source A cites Source B which cites Source C which is a Stack Overflow answer with no evidence. The claim gains authority through citation despite having no empirical foundation. This is now compounded by AI-generated citations: 19.9% of AI-generated references are completely fabricated (Camp et al. 2025), and hallucinated citations are entering peer-reviewed literature.

**Counter:** Follow citations to their origin. If you can't find the original source, the claim is unverified. If the original source is a single person's unsupported opinion, the claim is anecdotal regardless of how many times it's been cited.

**The smell:** A claim appears in 10 sources -- but all 10 trace back to the same blog post from 2019.

### 27. The Novelty Trap -- Surprising Claims Spread Because They're Surprising

Vosoughi, Roy, and Aral (2018) analyzed 126,000 news cascades on Twitter: falsehood spreads 6x faster than truth. The mechanism is novelty -- surprising claims get shared because they're attention-grabbing, not because they're true. False news triggers surprise and disgust; true news triggers sadness and anticipation.

**For technical research:** The "10x performance improvement" blog post gets shared widely BECAUSE it's dramatic. The "2% improvement with significant caveats" paper doesn't go viral. Popularity and truth are inversely correlated for dramatic claims.

**The smell:** The most-shared, most-cited claim on a topic is the one you trust most. Check whether its virality is because it's true or because it's dramatic.

### 28. Survivorship Bias -- You Only Hear From the Winners

Production experience reports are biased toward success. Companies that migrated successfully write blog posts. Companies that failed silently revert and don't tell anyone. Technology adoption stories are curated: you hear about Google's use of Go, not about the companies that tried Go and switched back.

**Counter:** Explicitly search for failure stories. "X migration failed," "problems with X in production," "why we stopped using X." If you can't find any failures, that's suspicious -- either the technology is genuinely perfect (unlikely) or failures aren't being reported (likely).

**The smell:** Every case study you found is positive. The technology has no reported failures. Nobody has anything bad to say.

---

## The Argumentative Theory Insight

### 29. Solitary Reasoning Is Structurally Broken

Mercier and Sperber (2011) argued that human reasoning evolved for argumentation, not truth-seeking. Confirmation bias is a FEATURE of argument production -- when your job is to persuade, searching for supporting arguments is adaptive. The catch: humans are biased PRODUCERS of arguments but relatively competent EVALUATORS of others' arguments.

**The implication for AI research:** A single agent producing a research report is the worst possible architecture. It produces biased arguments with no adversarial evaluation. The fix is structural: one agent researches, a different agent critiques. The critique agent has no investment in the findings and can evaluate them without confirmation bias.

**The smell:** A single-pass research report with no adversarial review. The agent agreed with itself from start to finish.

**The signal:** The research includes genuine tensions: "Agent A found X, but Agent B found evidence against X. Here's how we resolved the contradiction."

### 30. Laziness, Not Bias -- The Primary Failure Mode

Pennycook and Rand (2019) found that people fall for misinformation primarily because they fail to THINK, not because they reason themselves into believing what they want. Analytical thinking improves discernment regardless of political alignment. The cure is more thinking, not less bias.

**For AI research consumption:** The danger isn't that you'll be biased by the research -- it's that you'll accept it without thinking. Build friction into the process: don't accept findings at face value. For every conclusion, ask: "Does this ACTUALLY follow, or does it just FEEL right?"

**The smell:** You read the research report and thought "sounds about right" without checking any sources or questioning any claims. That's System 1 acceptance.
