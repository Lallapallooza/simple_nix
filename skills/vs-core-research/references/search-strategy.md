# Search Strategy & Query Craft

A decision framework for finding information efficiently, not a tutorial on web search. Each topic is how a senior researcher thinks about where to look, how to formulate queries, and when to stop -- written for someone who can use search tools but hasn't yet internalized the strategy layer above them.

---

## Query Formulation

### 1. Short Queries Beat Long Queries

Anthropic's multi-agent research system found that overly verbose queries were an early failure mode. Short, focused queries return better results than long, detailed ones because search engines match on keywords, not on intent. "Valkey Lua scripting compatibility" outperforms "Is it possible to migrate Redis Lua scripts to Valkey and will they be compatible?"

**The exception:** When searching for a specific error message or code pattern, use the exact string. "RuntimeError: dictionary changed size during iteration" finds the exact problem. Paraphrasing it loses precision.

**The smell:** Your search query is a complete sentence. Strip it to 3-5 keywords.

### 2. Multiple Query Formulations -- Cast a Wide Net

A single query samples one slice of the information landscape. Different formulations reach different source types. For any non-trivial question, use 3-5 different query formulations:

- **Exact terminology:** "Valkey Lua scripting compatibility"
- **Problem framing:** "Redis Lua scripts broken after Valkey migration"
- **Experience framing:** "Valkey migration production experience"
- **Failure framing:** "Valkey migration problems" / "Valkey Lua bugs"
- **Comparison framing:** "Redis vs Valkey Lua support differences"

Each formulation surfaces different sources. The exact terminology finds documentation. The problem framing finds Stack Overflow and issue trackers. The experience framing finds blog posts. The failure framing finds what nobody else is looking for.

**The smell:** All your queries are variations of the same phrasing. You're sampling the same slice five times.

**The signal:** Your queries reach different source types: docs, forums, blog posts, academic papers, issue trackers.

### 3. Domain-Specific Search -- Go Where the Experts Are

Generic web search returns generic results. Domain-specific searches find expert content:

- **Academic papers:** Use Google Scholar, arXiv, Semantic Scholar. Search for survey papers first -- they cite the foundational work.
- **Code:** Search GitHub (code search), grep.app, sourcegraph.
- **Official docs:** Use site:docs.rs, site:docs.python.org, site:wiki.hypr.land.
- **Production experience:** Search for "in production" + technology, "migration experience," "post-mortem."
- **Issue trackers:** Search GitHub Issues, JIRA, Linear for actual bug reports and feature discussions.
- **Conference talks:** Search YouTube, Vimeo for conference names + topic. Talks often contain insights that never make it into papers.

**The smell:** All your sources come from generic web search. No academic sources, no source code, no issue tracker data.

### 4. Negative Queries -- Search for What's Wrong

For every positive search ("X benefits," "X features"), run a negative search ("X problems," "X limitations," "X failed," "why I stopped using X"). This counters confirmation bias at the search level.

**The mechanism:** Positive content is overproduced. Companies write about their products' strengths. Happy users write blog posts. Unhappy users quietly switch and say nothing. Negative search deliberately seeks the underrepresented perspective.

**The smell:** Every source you found is positive about the technology. You didn't search for failures.

**The signal:** You found both advocates and critics, and you can articulate the strongest case each side makes.

### 5. Query Iteration -- Let Results Inform Next Queries

The first search teaches you the vocabulary of the domain. Use terminology from results to refine subsequent searches. If you search for "database performance" and results mention "TPC-H benchmark," your next search should include "TPC-H" -- you've learned the domain's language.

**Concurrent analysis:** Process each batch of results before formulating the next query. What did you learn? What vocabulary did you discover? What gaps did the results reveal? Let understanding shape search, not a pre-determined query list.

**The smell:** Your queries at the end of research use the same terms as your queries at the beginning. You didn't learn the domain's vocabulary.

---

## Progressive Search Strategy

### 6. Broad-Then-Narrow -- The Funnel Pattern

Start with broad queries to map the landscape, then narrow based on what you find. This matches how every effective research system works:

- **Round 1 (broad):** 3-5 general queries to identify the major themes, key players, and dominant opinions. Don't read deeply -- scan for structure.
- **Round 2 (targeted):** Based on what Round 1 revealed, search for specific sub-questions, named technologies, specific authors, particular benchmarks.
- **Round 3 (deep):** For the most critical sub-questions, search for primary sources, production reports, and counterarguments.

**The anti-pattern:** Starting narrow. If you search for "Valkey cluster mode performance on ARM with TLS" before understanding the broader Valkey landscape, you miss context that would change how you interpret the results.

**The smell:** Your first search is hyper-specific. You're optimizing before you understand the landscape.

### 7. Citation Chaining -- Following the Knowledge Graph

Wohlin (2014) showed that citation chaining (snowballing) can replace or complement database searches. It works because the citation network follows intellectual connections, not keyword matches.

**Backward chaining:** A good source cites its sources. Follow those references to find the foundational work that the good source builds on. This finds older, deeper sources that keyword searches miss.

**Forward chaining:** Search for papers that cite a good source (Google Scholar's "Cited by" feature). This finds newer work that builds on the foundation. Forward chaining is how you find the state of the art.

**Start set diversity:** Begin with sources from different authors, venues, and time periods. If your start set is all from the same research group, your citation chain will stay in their citation bubble.

**Stopping criterion:** When a chaining iteration yields no new relevant sources meeting your inclusion criteria, stop.

**The smell:** You found one great paper and stopped. You didn't check what it cites or who cites it.

### 8. The Snippet-First Strategy -- Evaluate Before Committing

Exa's research system demonstrated that evaluating search result snippets before fetching full pages provides massive token savings with minimal quality loss. Most results can be evaluated from snippets alone -- only fetch the full content of sources that pass snippet-level screening.

**The procedure:** Run search. Read titles and snippets. Discard obviously irrelevant results. Prioritize remaining results by likely relevance. Fetch and deep-read only the top 3-5.

**The smell:** You fetch and read every search result in full. Most of the time is spent reading irrelevant content.

**The signal:** You process 20 search results but deeply read only 5 -- and those 5 contain 90% of the useful information.

### 9. Scent-Following -- Information Foraging Theory

Pirolli and Card's Information Foraging Theory (1999) models information seeking as predator-prey behavior. "Scent" is the perceived relevance of a path based on surface cues (titles, snippets, file names, function names). High-scent paths should be followed first.

**Key principles:**
- **Between-patch navigation:** Deciding which source to read next based on surface signals (titles, domains, dates, authors).
- **Within-patch extraction:** Once reading a source, knowing when to stop extracting because returns are diminishing.
- **Leave when the marginal rate of gain in the current source drops below the average rate across all sources.** Don't read a 2000-word article to the end if the first 500 words answered your question.

**For code investigation:** File names and function names are scent. `auth_middleware.py` has high scent for an authentication question. Follow the highest-scent results first, then trace dependencies from there.

**The smell:** You're reading every file/source to completion. Some sources lose scent quickly -- learn to abandon early.

---

## Multi-Source Strategies

### 10. The Source Type Portfolio

Different source types have different strengths and biases. A complete research effort draws from multiple types:

| Source Type | Strength | Weakness |
|---|---|---|
| Academic papers | Rigor, methodology transparency | Lag time, may not match your context |
| Official documentation | Authoritative for intended behavior | May be outdated, describes ideal not real |
| Production experience reports | Real-world evidence | Survivorship bias, specific to one context |
| Issue trackers / bug reports | Reveals actual problems | Noisy, may be fixed in newer versions |
| Source code | Ground truth for behavior | Requires expertise to interpret |
| Conference talks / podcasts | Expert insight, nuance | Not citable, may be opinion |
| Benchmarks | Quantitative evidence | Gamed, may not match your workload |
| Community forums / Q&A | Diverse perspectives, practical | Variable quality, often outdated |

**The judgment:** No single source type is sufficient. Official docs tell you what should work. Issue trackers tell you what doesn't. Production reports tell you what happens in reality. Source code tells you the truth.

**The smell:** All your sources are the same type (all blog posts, all docs, all papers).

### 11. Parallel Diverse Search -- Different Strategies, Not Different Queries

When dispatching multiple search agents, each should use a genuinely DIFFERENT search strategy -- not just different queries on the same approach. The judgment file research showed this: agents with different mandates (web researcher, architecture researcher, gap finder) produced better results than agents all doing the same type of web search.

**Strategy diversity examples:**
- Agent A: Web search for recent sources (last 12 months), focusing on production experience
- Agent B: Academic search for foundational papers, then forward-chain to current state of the art
- Agent C: Codebase exploration -- what does the actual code show?
- Agent D: Contrarian search -- find criticisms, failures, alternatives

**The smell:** All agents are doing web searches with slightly different keywords. They return overlapping results.

**The signal:** Each agent returns a meaningfully different set of sources. Overlap exists (convergent evidence is good) but isn't dominant.

### 12. The Gap Analysis Pass

After initial search, explicitly enumerate what's missing:
- Which sub-questions remain unanswered?
- Which claims lack corroboration (only one source)?
- Which contradictions are unresolved?
- What source types are missing (no production reports? no academic sources?)?
- What perspectives are absent (no critics? no users at different scale?)?

This gap analysis informs the second search pass. Together AI's research system confirmed: explicit knowledge gap analysis after each round is "the difference between premature stopping and comprehensive research."

**The smell:** Your second search pass repeats the first with different keywords. It finds the same sources.

**The signal:** Your second pass specifically targets identified gaps: "Find production experience from teams with >100GB datasets -- first pass only found examples under 10GB."

---

## Codebase-Specific Search

### 13. Entry Point Identification -- Where to Start Reading

When investigating unfamiliar code, the first question is: where does execution begin? Different project types have different entry point patterns:

- **Web servers:** Look for route definitions, HTTP handlers, middleware registration
- **CLI tools:** Look for main functions, argument parsers, command registration
- **Libraries:** Look for public API surface -- exported functions, public modules
- **Build outputs:** Read `package.json` scripts, `Makefile` targets, CI configuration

Glob for entry point patterns: `main.{rs,go,py,ts}`, `index.{ts,js}`, `app.{py,rb}`, `*handler*`, `*route*`, `*controller*`.

**The smell:** You start reading code from the first file alphabetically, or from whatever file is open.

### 14. The 44 Questions as Search Targets

Sillito, Murphy, and De Volder (2006) catalogued 44 questions programmers ask during code changes. These form a progression from narrow to broad:

**Finding focus (where to start):**
- Where is the text in this error message? -> `grep` for the literal string
- Where is code involved in this behavior? -> `grep` for behavior keywords
- Is there an entity named like X? -> `glob` for name patterns

**Expanding (trace outward):**
- Who calls this function? -> `grep` for function name with `(`
- Who implements this interface? -> `grep` for `implements InterfaceName`
- Where are instances created? -> `grep` for `new ClassName`

**Connecting (how things work together):**
- How does control get from here to here? -> trace call chain
- Under what circumstances is this called? -> read callers' conditionals
- What data flows in and out? -> read function signatures and return types

**Impact (what changes affect):**
- What's the direct impact of this change? -> `grep` for all references
- What's the total impact? -> combine reference grep with temporal coupling analysis

**The smell:** You're investigating code without a specific question. "Understand how auth works" is too vague. "Where does the JWT token get validated?" is a searchable question.

### 15. Git History as Research Source

Adam Tornhill's behavioral code analysis: VCS history reveals architecture invisible to static analysis.

**Hotspot analysis:** Files that change frequently AND are complex are where bugs concentrate. `git log --format=format: --name-only | sort | uniq -c | sort -rn | head -20` shows the most-changed files. Cross-reference with file size for hotspots.

**Temporal coupling:** Files that change together in commits have hidden dependencies. If `auth.py` and `billing.py` always change in the same commits, they're coupled regardless of what the import graph says.

**Knowledge mapping:** `git shortlog -sn -- path/to/file` shows who knows this code. Single-author files are knowledge orphans.

**Commit messages as intent:** `git log --oneline --follow path/to/file` reveals WHY the file evolved the way it did. The code shows WHAT; history shows WHY.

**The smell:** You're trying to understand a module purely from current code. You haven't checked its history.

### 16. Tests as Specification

Test files document expected behavior more reliably than comments or documentation, because tests that are wrong cause failures. Well-written tests serve as executable specifications of what the code should do.

**Using tests for investigation:**
- Find test files: `glob` for `*test*`, `*spec*`, `__tests__`
- Read tests to understand expected inputs, outputs, and edge cases
- Missing tests reveal untested behaviors -- potential risk areas
- Test setup code reveals dependencies and required configuration

Feathers' characterization tests: write a test that calls the code, let it fail to discover actual output, update the assertion. Now you have a documented behavior baseline.

**The smell:** You're reading implementation code trying to understand what it should do. The test file next to it already answers that question.

---

## Knowing When to Stop

### 17. The Saturation Check -- Three Signals

Track these three signals during research:

1. **Theme repetition:** New sources repeat themes you've already found. The last 3 sources added zero new themes.
2. **Citation convergence:** The same papers, projects, and people keep appearing across different searches. The citation network has been mapped.
3. **Query exhaustion:** You can't think of a new query formulation that would reach different sources. Every query variation returns sources you've already seen.

When all three signals fire, you've reached saturation. Additional searching has negligible expected value.

### 18. The Coverage Checklist

Before declaring research complete, verify:
- [ ] Every sub-question has at least 2 independent sources
- [ ] At least one source was found through negative/contrarian search
- [ ] Source types include at least 3 different categories (docs, production reports, academic, code, etc.)
- [ ] The strongest counterargument to your conclusion has been identified and addressed
- [ ] Any claim you're uncertain about is marked with a confidence level
- [ ] Sources from the last 12 months are included for rapidly evolving topics

Unchecked items indicate coverage gaps worth one more search pass.

### 19. Honest Gaps -- Reporting What You Didn't Find

The mark of rigorous research is honest reporting of what remains unknown. PRISMA requires documenting exclusion reasons. GRADE requires explicit uncertainty expression. Intelligence analysis standards require distinguishing evidence from inference.

**Template:** "This research did not find: [specific gap]. This means [implication for the conclusion]. To resolve this, you would need to [specific next step]."

**The smell:** Your report reads as comprehensive and confident throughout, with no gaps, no unknowns, and no areas of uncertainty. That's not thorough research -- that's overconfident reporting.

**The signal:** Your report explicitly states what it doesn't know, why that matters, and what would resolve it.

### 20. Budget Awareness -- Don't Spend $10 Answering a $1 Question

OpenAI Deep Research uses hard limits: 30-60 web searches, 120-150 page fetches, 20-30 minutes. These constraints force efficient exploration. Without them, agents tend to search endlessly or over-invest in dead-end paths.

**The judgment:** Before starting research, estimate the question's value. A critical architecture decision that affects 6 months of work deserves 50+ searches and multiple agent passes. A quick factual question deserves 3 searches and a single-pass answer.

**The smell:** Every question gets the same depth of investigation regardless of importance.
