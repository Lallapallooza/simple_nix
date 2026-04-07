---
name: vs-core-tropes
description: Review text for AI writing tropes. Use this skill when the user wants to check prose for AI-sounding patterns, or says "tropes", "check for AI slop", "does this sound AI", "deslop", or wants to make text sound more human.
allowed-tools: Read Glob Grep Bash
---

# AI Tropes Review

Review the target text against the catalog below. Report patterns that appear repeatedly or cluster together. A single instance is not a finding -- repeated patterns or clusters of 3+ different tropes are.

## Process

1. Read the target text (file, diff, or pasted prose)
2. **Mandatory**: Run `check-unicode.sh` on the target path(s) before the manual review. If it finds issues, run `fix-unicode.sh` to auto-fix them. These scripts live in the skill directory alongside this file.
   ```bash
   bash <skill-dir>/check-unicode.sh <target-path>
   # If issues found:
   bash <skill-dir>/fix-unicode.sh <target-path>
   ```
3. Scan for patterns from every category below
4. Report findings with: location (line or paragraph), the trope, a concrete rewrite
5. One-offs get a note. Repeated patterns or clusters get flagged.

## Output

```
## Tropes Review

**Overall**: [Clean | Minor tells | Needs rewrite]

### Findings
- **Line/paragraph**: [where]
- **Trope**: [name from catalog]
- **Text**: [the offending passage]
- **Rewrite**: [concrete alternative]

### Patterns
[Which tropes appear more than once -- the systemic issues, not the one-offs]
```

---

## Tropes Catalog

Source: [tropes.fyi](https://tropes.fyi) by ossama.is

### Word Choice

**Magic adverbs.** "Quietly", "deeply", "fundamentally", "remarkably", "arguably" -- adverbs that inflate mundane descriptions into false significance.

- "quietly orchestrating workflows, decisions, and interactions"
- "the one that quietly suffocates everything else"
- "a quiet intelligence behind it"

**"Delve" and friends.** Part of a family of overused AI vocabulary: "certainly", "utilize", "leverage" (as verb), "robust", "streamline", "harness".

- "Let's delve into the details..."
- "Delving deeper into this topic..."
- "We certainly need to leverage these robust frameworks..."

**"Tapestry" and "landscape".** Ornate nouns where simple words work. Also: "paradigm", "synergy", "ecosystem", "framework" used decoratively.

- "The rich tapestry of human experience..."
- "Navigating the complex landscape of modern AI..."
- "The ever-evolving landscape of technology..."

**"Serves as" dodge.** Replacing "is" with pompous alternatives. AI avoids basic copulas because repetition penalty pushes toward fancier constructions.

- "The building serves as a reminder of the city's heritage."
- "The station marks a pivotal moment in the evolution of regional transit."

### Sentence Structure

**Negative parallelism.** "It's not X -- it's Y." The single most identified AI writing tell. One per piece can work. Ten is an insult. Variants: "not because X, but because Y", the cross-sentence "The question isn't X. The question is Y."

- "It's not bold. It's backwards."
- "Feeding isn't nutrition. It's dialysis."
- "Half the bugs you chase aren't in your code. They're in your head."

**Dramatic countdown.** "Not X. Not Y. Just Z." Builds false tension by negating things before the reveal.

- "Not a bug. Not a feature. A fundamental design flaw."
- "Not ten. Not fifty. Five hundred and twenty-three lint violations across 67 files."
- "not recklessly, not completely, but enough"

**Self-posed rhetorical questions.** Asks a question nobody was asking, answers it for drama.

- "The result? Devastating."
- "The worst part? Nobody saw it coming."
- "The scary part? This attack vector is perfect for developers."

**Anaphora abuse.** Repeating the same sentence opening 3+ times in quick succession.

- "They assume that users will pay... They assume that developers will build... They assume that ecosystems will emerge..."
- "They could expose... They could offer... They could provide... They could create... They could let... They could unlock..."

**Tricolon abuse.** Overuse of rule-of-three, often extended to four or five. One tricolon is elegant. Three back-to-back is pattern failure.

- "Products impress people; platforms empower them. Products solve problems; platforms create worlds. Products scale linearly; platforms scale exponentially."
- "workflows, decisions, and interactions"

**"It's worth noting."** Filler transitions that signal nothing and connect nothing. Also: "It bears mentioning", "Importantly", "Interestingly", "Notably".

- "It's worth noting that this approach has limitations."
- "Importantly, we must consider the broader implications."
- "Interestingly, this pattern repeats across industries."

**Superficial analyses.** Tacking "-ing" phrases onto sentences for shallow depth.

- "contributing to the region's rich cultural heritage"
- "highlighting the enduring legacy of the community's resistance and the transformative power of unity in shaping its identity"
- "underscoring its role as a dynamic hub of activity and culture"

**False ranges.** "From X to Y" where X and Y aren't on any real scale. "From innovation to cultural transformation" -- what's in between? Nothing.

- "From innovation to implementation to cultural transformation."
- "From the singularity of the Big Bang to the grand cosmic web."
- "From problem-solving and tool-making to scientific discovery, artistic expression, and technological innovation."

### Paragraph Structure

**Short punchy fragments.** Excessive one-sentence paragraphs for manufactured emphasis. No human writes first drafts this way.

- "He published this. Openly. In a book. As a priest."
- "These weren't just products. And the software side matched. Then it professionalised. But I adapted."
- "Platforms do."

**Listicle in a trench coat.** Numbered points disguised as prose. You told it to stop making lists and it did this instead.

- "The first wall is the absence of a free, scoped API... The second wall is the lack of delegated access... The third wall is the absence of scoped permissions..."
- "The second takeaway is that... The third takeaway is that... The fourth takeaway is that..."

### Tone

**"Here's the kicker."** False suspense before an unremarkable observation. Also: "Here's the thing", "Here's where it gets interesting", "Here's what most people miss", "Here's the deal".

**"Think of it as..."** Patronizing analogy. Defaults to teacher mode. Often the analogy is less clear than the original concept.

- "Think of it like a highway system for data."
- "Think of it as a Swiss Army knife for your workflow."
- "It's like asking someone to buy a car they're only allowed to sit in while it's parked."

**"Imagine a world where..."** The futurism invitation. Sells the argument with a utopian fantasy list.

- "Imagine a world where every tool you use -- your calendar, your inbox, your documents, your CRM, your code editor -- has a quiet intelligence behind it..."
- "In that world, workflows stop being collections of manual steps and start becoming orchestrations."

**False vulnerability.** Performative self-awareness. Real vulnerability is specific and uncomfortable. AI vulnerability is polished and risk-free.

- "And yes, I'm openly in love with the platform model"
- "And yes, since we're being honest: I'm looking at you, OpenAI, Google, Anthropic, Meta"
- "This is not a rant; it's a diagnosis"

**"The truth is simple."** Asserting clarity instead of demonstrating it. If you have to tell the reader it's clear, it isn't. Also: "The real story is..." waving away everything prior.

- "The reality is simpler and less flattering"
- "History is unambiguous on this point"
- "History is clear, the metrics are clear, the examples are clear"

**Grandiose stakes inflation.** Everything is world-historical. A blog post about API pricing becomes a meditation on civilization's fate.

- "This will fundamentally reshape how we think about everything."
- "will define the next era of computing"
- "something entirely new"

**"Let's break this down."** Pedagogical hand-holding. Also: "Let's unpack this", "Let's explore", "Let's dive in."

- "Let's break this down step by step."
- "Let's unpack what this really means."
- "Let's explore this idea further."

**Vague attributions.** Unnamed authorities. If you can't name the expert, you don't have a source.

- "Experts argue that this approach has significant drawbacks."
- "Industry reports suggest that adoption is accelerating."
- "Observers have cited the initiative as a turning point."

**Invented concept labels.** Compound labels that sound analytical but aren't established terms. Names a thing, skips the argument. Multiple in one piece is a strong AI signal.

- "the supervision paradox"
- "the acceleration trap"
- "workload creep"

### Formatting

**Em-dash addiction.** 2-3 per piece is natural. 20+ is AI.

- "The problem -- and this is the part nobody talks about -- is systemic."
- "The tinkerer spirit didn't die of natural causes -- it was bought out."
- "Not recklessly, not completely -- but enough -- enough to matter."

**Bold-first bullets.** Every bullet starts with a bolded phrase. Almost nobody formats lists this way by hand. Telltale in docs, READMEs, blog posts.

- "**Security**: Environment-based configuration with..."
- "**Performance**: Lazy loading of expensive resources..."

**Unicode decoration.** Arrows, smart quotes, box-drawing characters, special characters you can't type on a regular keyboard. Only printable ASCII is natural. Real writers produce straight quotes, `->`, and `---` section dividers -- not `-`, `->`, or `"` `"`.

- "Input -> Processing -> Output"
- "# -- Section ------------------"
- Smart quotes: "like this" instead of "like this"

### Composition

**Fractal summaries.** "What I'll tell you; what I'm telling you; what I just told you" at every level.

- "In this section, we'll explore... [3000 words later] ...as we've seen in this section."
- "A conclusion that restates every point already made in the previous 3000 words"
- "And so we return to where we began."

**Dead metaphor.** One metaphor beaten across the entire piece. Humans introduce a metaphor, use it, move on. AI repeats it 10 times.

- "The ecosystem needs ecosystems to build ecosystem value."
- "Walls and doors used 30+ times in the same article"
- "Every paragraph finds a way to say 'primitives' again"

**Historical analogy stacking.** Rapid-fire company/revolution name-drops for false authority.

- "Apple didn't build Uber. Facebook didn't build Spotify. Stripe didn't build Shopify. AWS didn't build Airbnb."
- "Every major technological shift -- the web, mobile, social, cloud -- followed the same pattern."
- "Take Spotify... Or consider Uber... Airbnb followed a similar path... Shopify is another example... Even Discord..."

**One-point dilution.** Single argument restated 10 ways across thousands of words. 800-word thesis padded to 4000 with different metaphors for the same idea.

**Content duplication.** Same section or paragraph appearing verbatim or near-verbatim in different parts of the piece. Happens when the model loses track of what it already wrote, especially in longer output.

**Signposted conclusion.** "In conclusion", "To sum up", "In summary." Competent writing doesn't announce it's concluding.

- "In conclusion, the future of AI depends on..."
- "To sum up, we've explored three key themes..."
- "In summary, the evidence suggests..."

**"Despite its challenges..."** The rigid formula: acknowledge problems, immediately dismiss them, end optimistic.

- "Despite these challenges, the initiative continues to thrive."
- "Despite its industrial and residential prosperity, Korattur faces challenges typical of urban areas."
- "Despite their promising applications, pyroelectric materials face several challenges that must be addressed for broader adoption."

---

Any of these patterns used once might be fine. The problem is when multiple tropes cluster or a single trope repeats. Flag the patterns, not the one-offs.
