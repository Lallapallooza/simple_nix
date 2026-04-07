# Source Evaluation & Evidence Judgment

A decision framework for evaluating sources and evidence, not a checklist. Each topic is how a senior researcher thinks about whether to trust what they've found, written for someone who can find sources but hasn't yet internalized when a source is lying, when it's honestly wrong, and when it's right for the wrong reasons.

---

## The Default Stance

### 1. Assume Wrong Until Proven Otherwise

Ioannidis (2005) demonstrated mathematically that most published research findings are false. The Open Science Collaboration (2015) confirmed it empirically: only 36% of psychology studies replicated, with effect sizes halving. The replication crisis isn't limited to psychology -- it's a property of any field with publication bias, small samples, and analytical flexibility.

**The implication:** Your default assumption about any single source should be skepticism, not trust. A claim starts at low confidence and evidence raises it -- not the other way around. This isn't cynicism; it's calibration.

**Six conditions that make findings more likely false (Ioannidis corollaries):**
1. Small studies (low statistical power)
2. Small effect sizes (relative risks near 1.0)
3. Large number of tested relationships (fishing expeditions)
4. Greater analytical flexibility (many researcher degrees of freedom)
5. Greater financial or ideological interests
6. "Hot" fields with many competing teams racing to publish

**The smell:** You trust a finding because it appeared in a prestigious venue. But venue prestige doesn't fix small samples, p-hacking, or conflicts of interest. Check the study itself, not the journal.

**The signal:** You can articulate exactly why you trust this particular finding: independent replication, large sample, pre-registered analysis, no obvious conflicts.

### 2. The Millikan Rule -- Equal Scrutiny in Both Directions

Feynman described how after Millikan's slightly-too-low measurement of electron charge, subsequent researchers unconsciously filtered results. Values too far from Millikan's were scrutinized for errors; values near it were accepted without equivalent scrutiny. The measurements drifted upward over decades as researchers unconsciously corrected their bias.

**The rule:** Apply identical scrutiny to confirming and disconfirming evidence. If you would question a source that contradicts your finding, apply the same level of questioning to a source that confirms it.

**The smell:** You found a source contradicting your conclusion and spent 10 minutes evaluating its methodology. You found a confirming source and accepted it in 30 seconds. That's the Millikan effect.

**The signal:** Your evaluation process is symmetric. You can honestly say: "I would have accepted/rejected this source regardless of whether it confirmed my hypothesis."

---

## Source Authority

### 3. Lateral Reading -- The Expert Move

Wineburg and McGrew (2019) compared how PhD historians, Stanford undergrads, and professional fact-checkers evaluated websites. The fact-checkers dramatically outperformed both -- in less time. The difference: lateral vs. vertical reading.

**Vertical reading** (what historians and students did): Stay on the website. Read content top-to-bottom. Evaluate based on internal features: domain name, visual design, About page claims. Were fooled by .org domains, professional logos, and official-looking layouts.

**Lateral reading** (what fact-checkers did): Left the site almost immediately. Opened new tabs to check what OTHERS say about this source. Used Wikipedia for quick background checks. Asked three questions: Who is behind this? What is their evidence? What do other sources say?

**The judgment:** Never evaluate a source by reading it deeply first. Before extracting claims from any unfamiliar source, run a parallel check: search for the source's reputation, funding, and known biases. Sixty seconds of lateral reading catches what hours of vertical reading misses.

**The smell:** You're evaluating a source by how professional it looks, how many citations it has, or whether it has a .org domain. These are cheap to fake.

**The signal:** You know who funds the source, what their track record is, and whether other credible sources corroborate or contradict them -- all before you extract a single claim.

### 4. Authority Is Constructed and Contextual -- The ACRL Insight

The ACRL Framework for Information Literacy identifies a threshold concept: authority depends on context. A database vendor's benchmark is authoritative for what their product can do in ideal conditions -- but not for how it performs in your specific workload. A blog post by someone who migrated in production is authoritative for what actually happened -- even if the author has no credentials.

**The authority hierarchy for technical research:**
1. **Primary evidence you can verify** -- source code, benchmark you can reproduce, test you can run
2. **First-hand production experience** -- someone who did the thing, reporting what happened
3. **Peer-reviewed research** -- with caveats about replication and context
4. **Official documentation** -- authoritative for intended behavior, not for actual behavior
5. **Expert opinion** -- credentialed people stating beliefs without specific evidence
6. **Tutorial / blog post** -- secondary reporting, often simplified, sometimes wrong
7. **AI-generated content** -- plausible, fluent, potentially fabricated

**The nuance:** This hierarchy isn't strict. A detailed production experience report from a blog (level 6 format) can be more valuable than a peer-reviewed paper (level 3 format) if the blog describes your exact use case and the paper studies a different workload.

**The smell:** You're dismissing a source because it's "just a blog post" or trusting a source because it's "peer-reviewed." The format is a weak signal; the content is what matters.

### 5. When Official Docs Are Wrong

Documentation describes intended behavior. Code implements actual behavior. When they diverge, the code is the truth. This happens more often than most developers realize: features that were documented but never implemented, behavior that changed without docs being updated, edge cases that docs describe incorrectly.

**The hierarchy of truth:** Code > tests > runtime behavior > documentation > comments > commit messages > design docs. Each step further from execution is a step further from reality.

**The smell:** The docs say the API returns 404 for missing resources, but the actual code returns 200 with an empty body. You trust the docs because they're "official."

**The signal:** When docs and behavior diverge, you investigate which is correct for your use case. Sometimes the docs describe the desired behavior and the code has a bug. Sometimes the code is right and the docs are stale.

### 6. The Two-Source Rule -- Triangulation Minimum

From journalism and intelligence: no claim is considered verified until confirmed by two independent sources. "Independent" means they can't be citing each other or sharing a common source. If Source A cites Source B, that's one source, not two.

**Denzin's four types of triangulation:** Data (multiple sources across time/space), Investigator (multiple researchers with different backgrounds), Theory (testing rival hypotheses), Methodological (combining qualitative and quantitative). Each type has different blind spots -- combining them compensates.

**For technical research:** The strongest evidence is convergent: a benchmark result (quantitative) that matches a practitioner's experience report (qualitative) that matches the official documentation (authoritative). When three independent evidence types agree, confidence is high.

**The smell:** Your key conclusion rests on a single source. No matter how credible that source is, it could be wrong, outdated, or describing a different context than yours.

---

## Detecting Unreliable Sources

### 7. AI Content Pollution -- The Invisible Threat

Yu et al. (2026) demonstrated "Retrieval Collapse": at 67% pool contamination with AI content, over 80% of top-10 search results become AI-generated. Answer accuracy appears stable even as source diversity collapses -- the AI content is fluent and plausible. The system looks "deceptively healthy" while becoming structurally brittle.

**The compounding problem:** AI-generated content enters training data for future models. Shumailov et al. (2024) showed this causes "model collapse" -- progressive loss of diversity and accuracy. Each generation of AI training on AI output loses tail information: minority viewpoints, edge cases, and nuanced distinctions disappear.

**How to detect AI-generated content:**
- Multiple search results with suspiciously similar phrasing and structure
- No identifiable human author or institutional affiliation
- Fluent and comprehensive but lacking specific dates, citations, or verifiable details
- Reads like a "helpful summary" without original reporting or analysis
- Perfect agreement across multiple sources (source diversity collapse)

**Counter:** Prefer primary sources. Government databases, peer-reviewed journals, official project documentation, and first-party technical docs are less susceptible to AI pollution. Content from before ~2022 is less likely AI-generated. Named authors with verifiable track records are more trustworthy.

**The smell:** You searched for a technical topic and every result is a well-written, comprehensive blog post that says roughly the same thing in slightly different words. You may be reading the same AI output five times.

### 8. Citation Laundering -- Following the Evidence Chain

Source A cites B, B cites C, C is a Stack Overflow answer with no evidence. Each citation adds apparent authority while the original claim has no empirical foundation.

**Now compounded by AI:** Camp et al. (2025) found 19.9% of AI-generated references were completely fabricated and 45.4% contained serious bibliographic errors. GPTZero found 100+ hallucinated citations across 51 accepted NeurIPS 2025 papers. The citations LOOK real -- plausible author names, real journal titles, proper formatting -- but the papers don't exist.

**The TRACE move (from SIFT):** When a source cites a study or quote, follow the citation to the original. Extract from the original, not the secondary report. If the original can't be found, the claim is unverified.

**Verification method:** For any critical citation: check DOI resolution, search Google Scholar for the exact title, check the publisher's website. If a reference can't be found on any of these, it may not exist.

**The smell:** A source makes a strong claim and cites a paper you've never heard of. You include the claim with the citation without checking whether the cited paper exists or says what's claimed.

### 9. SEO Spam and Content Farms

Search engine optimization has created a parallel information ecosystem where ranking is determined by keyword density, backlink count, and engagement metrics -- not by accuracy or expertise. Content farms produce articles optimized for search ranking, not for truth.

**The mechanism:** Epstein and Robertson (2015) demonstrated the Search Engine Manipulation Effect: biased search rankings shift undecided opinions by 20%+ without awareness. The first page of results shapes beliefs regardless of result quality.

**Signals of content farm output:**
- Keyword-stuffed titles and headers
- Listicle format with thin content under each heading
- "Updated for [current year]" with no substantive changes
- Affiliate links or product recommendations embedded in "neutral" analysis
- Multiple nearly-identical articles across different domains
- No author bio or generic "staff writer" attribution

**Counter:** Skip the first page of results for controversial or commercial topics. Use site-specific searches (site:arxiv.org, site:github.com, site:*.edu). Prefer sources that rank well for reasons OTHER than SEO (academic databases, documentation sites, established engineering blogs).

### 10. Goodhart's Law -- When Metrics Are Gamed

"When a measure becomes a target, it ceases to be a good measure." Any benchmark, ranking, or metric used to evaluate sources will eventually be gamed. LLM benchmarks have a 6-12 month shelf life before contamination renders them useless.

**Concrete examples:** Meta tested 27 private model variants before releasing LMArena scores. Selective submissions inflated scores by up to 112%. SWE-bench agents learned to copy patches from git history instead of solving problems. LiveCodeBench showed models dropping 20-30% on post-training-cutoff problems.

**For source evaluation:** Citation count is gamed (citation rings, self-citation). Star count on GitHub is gamed (bot stars, campaigns). Download numbers are gamed (bots, CI/CD). Even peer review is gamed (suggested reviewers who are friends, citation requirements that benefit the editor).

**The smell:** You're evaluating a source or tool primarily by a single metric (stars, citations, downloads, benchmark score). That metric is almost certainly gamed.

**The signal:** You evaluate on multiple independent signals: stars AND contributor count AND issue response time AND production usage reports AND actual code quality.

---

## Evaluating Specific Evidence Types

### 11. Benchmarks vs. Production -- The Eternal Gap

Benchmarks measure performance under controlled conditions. Production measures performance under your conditions. These are different things. Goodhart's Law applies: once a benchmark becomes important, it gets optimized for at the expense of real-world performance.

**Production experience reports are gold** because they describe what actually happened with real workloads, real data, and real operational constraints. They're also rare, because companies that had bad experiences often don't write about them (survivorship bias).

**The smell:** Your tech decision is based primarily on benchmark numbers. Nobody who actually runs this in production has weighed in.

**The signal:** You found 2-3 production experience reports from teams with workloads similar to yours. Their experience carries more weight than any benchmark.

### 12. Contradictory Sources -- When Source A Says X and Source B Says Y

Contradictions aren't noise -- they're signal. They reveal either version-specific truth (X was true in v2.3 but not v3.0), context-specific truth (X is true for small datasets, Y for large), methodological differences (different benchmarks measure different things), or one source is wrong.

**Resolution procedure:**
1. Check version/date -- is this a temporal contradiction?
2. Check context -- are they describing different situations?
3. Check methodology -- are they measuring different things?
4. Check source quality -- is one source more reliable than the other?
5. If unresolvable -- report both positions with your assessment of which is more likely correct and why.

**The smell:** You present contradictory findings side-by-side without resolving them. "Source A says X. Source B says Y." That's reporting, not research.

**The signal:** "Source A says X (based on benchmarks from 2023 with synthetic data). Source B says Y (based on production data from 2025 with real workloads). We weight Source B more heavily because production data is more relevant and more recent."

### 13. Version-Specific Truth -- The Temporal Trap

Technical information decays fast. An answer that was correct for Python 3.8 may be wrong for 3.12. A Kubernetes configuration that worked in 1.24 may be deprecated in 1.29. The web is full of technically correct but temporally wrong information.

**Check dates on everything.** A source from 2020 about a rapidly evolving technology is suspect. The more actively developed the technology, the shorter the information shelf life.

**The smell:** You found a Stack Overflow answer with 500 upvotes. It's from 2018. The technology has had three major versions since then. The answer is probably wrong for the current version.

**The signal:** Your sources are from the last 12 months for actively evolving technologies, and you verified that the specific version you're using matches the source's context.

### 14. "No Evidence Found" vs. "Evidence of Absence"

Failing to find evidence that X is true is NOT evidence that X is false. It might mean: the evidence exists but your search didn't find it, the question hasn't been studied, or the evidence is behind paywalls or in unpublished work.

**True evidence of absence** requires: a thorough search that SHOULD have found evidence if it existed, combined with a reasonable expectation that evidence would exist if the claim were true. "I searched five databases and found no production reports of this failure mode" is evidence of absence only if the failure mode would be noticeable and worth reporting.

**The smell:** "I didn't find any reports of problems, so it must work well." Maybe nobody has tried it yet. Maybe people who had problems didn't write about them.

---

## Cognitive Bias Countermeasures

### 15. The Availability Trap -- Easy to Find != Important

Tversky and Kahneman (1973): people estimate frequency by how easily examples come to mind. In research, the most-indexed, most-SEO-optimized, most-viral content is the most "available." It's not necessarily the most accurate or relevant.

**The counter:** After completing initial search, deliberately ask: "What is NOT showing up in these results that should be?" Search for the absence. If you're researching database options and one major player isn't appearing in results, search for it specifically -- its absence from organic results doesn't mean it's irrelevant.

**The smell:** Your analysis covers only the options that appeared in the first page of search results. You didn't check whether there are important alternatives that don't SEO well.

### 16. The Anchoring Trap -- First Number Wins

The first quantitative claim you encounter anchors all subsequent evaluation. "Redis handles 100K ops/sec" becomes the baseline against which all other numbers are judged, even if that number was from a specific benchmark with specific conditions that don't match yours.

**Counter:** Before looking up numbers, generate your own estimate using Fermi decomposition. Compare your estimate to the found number. If they diverge significantly, investigate why -- don't just accept the published number.

**The smell:** You're evaluating a claim that a technology "only handles 10K requests per second" as slow -- because the first result you found claimed 100K. But 10K might be the realistic production number while 100K was a best-case synthetic benchmark.

### 17. Authority Bias -- Trusting Names Over Evidence

A claim from Google carries more weight than the same claim from an unknown startup. But Google engineers can be wrong, especially when talking about domains outside their expertise, or when describing internal-only practices that don't apply to your scale.

**The counter:** Evaluate the evidence, not the speaker. A detailed, reproducible benchmark from an unknown developer is more valuable than a handwave from a Google SRE. "We use X at Google" tells you nothing about whether X is right for your 10-person team.

**The smell:** Your key recommendation is based on "Google uses this" or "Amazon recommends this." Google and Amazon operate at scales, with teams, and under constraints that probably don't match yours.

### 18. The Replication Mindset -- Could Someone Else Reach the Same Conclusion?

Bellingcat's transparency principle: "Include each step of the process so that anyone reading the work should be able to follow those steps and arrive at the same conclusions without making any leaps of logic."

**For research:** Every conclusion should be traceable to evidence. Every evidence evaluation should be reproducible. If someone followed your exact search queries, read your exact sources, and applied your exact evaluation criteria, they should reach the same conclusion. If they wouldn't, you've made a leap somewhere.

**The smell:** Your conclusion "follows" from the evidence, but you can't articulate the exact chain of reasoning. There's a gap where your intuition filled in.

---

## Practical Evaluation Protocols

### 19. The SIFT Method -- Four Moves for Quick Evaluation

Caulfield's SIFT (2019), based on how professional fact-checkers actually work:

1. **Stop** -- Before engaging with content, pause. Do you know this source? What is your purpose? This prevents rabbit holes.
2. **Investigate the source** -- Spend 60 seconds identifying who is behind the information. Check credentials, track record, potential biases. Do this BEFORE reading deeply.
3. **Find better coverage** -- Don't evaluate the one article in front of you. Search for the CLAIM itself across multiple trusted sources. What does the best available evidence say?
4. **Trace claims to original context** -- Follow quotes to original sources. Find complete documents, not excerpts. Check what was included vs. omitted.

**The unifying concept: recontextualization.** The internet strips context from everything. All four moves restore context.

**When to skip SIFT:** Known authoritative sources (official docs, well-known peer-reviewed journals). Primary source documents. Simple factual lookups.

### 20. The Three-Pass Method for Papers and Technical Sources

Keshav (2007), developed from 15 years of reading practice:

**Pass 1 (5-10 minutes):** Read title, abstract, introduction, section headings, conclusions. Answer the Five C's: Category (what type?), Context (what's it related to?), Correctness (are claims plausible?), Contributions (what's new?), Clarity (is it well-written?). Decision: worth reading further?

**Pass 2 (up to 1 hour):** Read with care but skip proofs and detailed math. Note key figures and diagrams. Mark unread references. After this pass, you should be able to summarize the paper's argument with evidence.

**Pass 3 (1-5 hours):** Virtually re-implement the paper. Make the same assumptions and recreate the work. This reveals hidden assumptions, missing steps, and potential errors.

**The judgment:** Most sources only deserve Pass 1. Reserve Pass 2 for sources that will influence decisions. Pass 3 is only for sources that are foundational to your recommendation.

### 21. The Quality-Relevance Matrix

The UK Rapid Evidence Assessment uses a dual-axis evaluation:

| | Low Quality | High Quality |
|---|---|---|
| **High Relevance** | Use cautiously, note limitations | Primary evidence |
| **Low Relevance** | Discard | Background only |

**The key insight:** A highly relevant low-quality source (a blog post describing exactly your use case) may be more useful than a high-quality irrelevant source (a rigorous paper studying a different workload). Relevance and quality are independent dimensions -- evaluate both.

**The smell:** You include a source because it's high quality (peer-reviewed, rigorous) even though it doesn't match your specific context. Quality without relevance is noise.

### 22. The Evidence Provenance Chain

For every claim in your final output, maintain a provenance chain:
- **Claim** -> **Source** -> **Source type** -> **How you found it** -> **How you verified it**

If any link in the chain is broken (you can't remember where you found it, you didn't verify the source exists, you didn't check if the source actually says what you think it says), the claim is unverified and should be labeled as such.

**The smell:** Your report cites 15 sources but you only actually read 6 of them. The other 9 were cited by the 6 you read, and you assumed they support what was claimed.

---

## The AI-Specific Evaluation Challenge

### 23. AI-Generated Research About AI -- The Recursion Problem

When using AI to research AI technologies, you face a recursion: the research tool has opinions about the research topic. An LLM researching "best LLM for code generation" has inherent conflicts and training biases. It may systematically favor its own vendor, overweight training data patterns, or reproduce benchmark hype from its training set.

**Counter:** For AI-about-AI research, weight external validation (independent benchmarks, third-party evaluations, production experience) more heavily than any single source. Be especially suspicious of claims that align with the research tool's likely training biases.

### 24. The "Almost Right" Problem

Stack Overflow's 2025 developer survey: 66% of developers cite "AI solutions that are almost right, but not quite" as their top frustration. The danger isn't wrong answers -- those are caught. The danger is plausible answers with subtle errors that pass shallow review.

**For source evaluation:** AI-generated content can be factually correct in its broad strokes while wrong in specific details. A summary of a paper might correctly describe the paper's topic and general findings while misattributing specific numbers, getting the methodology wrong, or missing critical caveats.

**Counter:** For any critical claim derived from an AI-generated source, verify the specific details against the primary source. Don't trust the summary; trust the original.

### 25. Model Collapse and Information Monoculture

Shumailov et al. (2024): when AI models train on AI-generated data recursively, they progressively lose diversity. Minority viewpoints, edge cases, and nuanced distinctions disappear first while overall quality appears maintained. This means AI-generated research summaries systematically lose exactly the information that's most valuable -- the exceptions, the caveats, the minority opinions.

**Counter:** Always maintain chains back to original human-generated sources. When AI summarizes 10 sources into one paragraph, the paragraph loses tails. Go back to the originals for anything that matters.

**The smell:** Multiple AI-generated summaries of a topic agree perfectly. They may all be drawing from the same training data and reproducing the same simplified consensus, missing the dissenting views that exist in the original literature.
