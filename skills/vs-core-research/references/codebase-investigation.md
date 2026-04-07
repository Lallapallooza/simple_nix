# Codebase Investigation & Program Understanding

A decision framework for systematically understanding unfamiliar code, not a tutorial. Each topic is how a senior engineer thinks about navigating and comprehending code -- written for someone who knows the tools but hasn't yet internalized when to read, when to search, and when to stop.

Codebase investigation IS research -- the sources are code, tests, history, and configuration instead of web pages and papers.

---

## Comprehension Strategy

### 1. The Integrated Model -- Three Modes, Constant Switching

Von Mayrhauser and Vans (1995) unified 30 years of comprehension research into one model. Developers use three concurrent sub-models:

- **Program model (bottom-up):** Read code statement by statement, identify control flow, recognize syntactic chunks. Triggered when code is completely unfamiliar.
- **Situation model (data flow):** Understand what data transforms occur, what functional role code plays. Triggered when you've read enough to see patterns emerging.
- **Top-down model (domain):** Start with expectations from domain knowledge, decompose into sub-goals, search for confirmation. Triggered when the language or domain is familiar.

**The critical insight:** Experts don't pick one mode -- they switch constantly. They start top-down (hypothesize from file names), drop to bottom-up when the hypothesis fails (actually read the code), build a situation model (summarize what this code does), then use that model to go top-down on the next component.

**Switching triggers:**
- Bottom-up -> top-down: You recognize a beacon (a swap inside a loop -> "this is sorting")
- Top-down -> bottom-up: Your hypothesis fails (the file doesn't do what the name suggests)
- Any mode -> situation model: You've read enough to summarize "this code takes X and produces Y"

**The smell:** You're reading every file top-to-bottom (pure bottom-up). Or you're only looking at file names and assuming you know what's inside (pure top-down). Both are slower than switching.

### 2. Hypothesize Before You Read -- The Letovsky Principle

Letovsky (1987) found that programmers don't read code -- they form and test hypotheses about it. Most comprehension time is spent on conjecture generation and validation, not sequential reading.

**Three question types drive investigation:**
- **Why** questions: What is the purpose of this code?
- **How** questions: What mechanism accomplishes this goal?
- **What** questions: What category does this belong to?

**The procedure:** Before reading any file deeply, form a hypothesis from available cues (file name, function signature, directory location, imports). Then read to confirm or refute. A confirmed hypothesis lets you skip detailed reading. A refuted hypothesis is even more valuable -- it tells you something specific about the code that the surface cues didn't reveal.

**The smell:** You're reading code without a question in mind. "I'll read this file and see what's in it" is browsing, not investigating.

**The signal:** You open a file with a specific hypothesis ("I think this handles JWT validation") and within 30 seconds you know whether you're right or wrong.

### 3. Beacons -- Recognizable Patterns That Accelerate Understanding

Soloway and Ehrlich's "beacons" are stereotypical code patterns that signal known algorithms or design patterns. When you recognize a beacon during bottom-up reading, you can skip to top-down understanding without reading every line.

**Common beacons to search for:**
- Factory: `create`, `build`, `make` + returns new object
- Observer: `subscribe`, `addEventListener`, `on(`, `emit(`
- Middleware: `use(`, chained `next()` calls
- Repository: `findBy`, `getAll`, `save`, `delete`
- State machine: `state`, `transition`, `switch(state)`
- Iterator: `next()`, `hasNext()`, `__iter__`
- Builder: method chaining returning `self`
- Decorator: wrapper function returning inner function

**The smell:** You're reading a 200-line function line by line when the first 10 lines contain a beacon (a retry loop with exponential backoff) that tells you what the whole function does.

### 4. Partial Comprehension -- Seven Questions Are Enough

Erdos and Sneed (1998) proved you don't need to understand an entire program to maintain it. Seven questions suffice for the sector you're modifying:

1. Where is this subroutine invoked?
2. What are the arguments and results?
3. How does control flow reach this location?
4. Where is this variable set, used, or queried?
5. Where is this variable declared?
6. Where is this data object accessed?
7. What are the inputs and outputs of this module?

**The judgment:** Global comprehension is neither necessary nor achievable for most tasks. Spinellis: "You can modify a million-line system by selectively understanding and changing one or two files." Direct your investigation to answer these seven questions for the specific code you need to change. Then stop.

**The smell:** You're trying to understand the entire codebase before making a single change. That's not thoroughness -- it's procrastination.

**The signal:** You can answer all seven questions for the code you're changing, and you haven't read a single file outside that scope.

---

## Starting Points

### 5. Read All the Code in One Hour -- The OORP Scan

Demeyer, Ducasse, and Nierstrasz's "First Contact" pattern: allocate exactly one hour to scan the entire codebase. Don't try to understand everything. Use your brain as a filter for what seems important.

**Targets for the one-hour scan:**
- Test files (reveal expected behavior)
- Abstract base classes and interfaces (reveal the design vocabulary)
- Class hierarchy roots (reveal the domain model)
- The largest files (likely god classes -- where complexity concentrates)
- Build configuration (reveals module boundaries and dependencies)
- README and documentation entry points (reveals intended architecture)

**For an AI agent, the equivalent:**
1. `ls` to get directory structure -- form initial hypotheses about module boundaries
2. `glob` for all source files, sort by size -- the largest files are where to start
3. Read build files (`package.json`, `Cargo.toml`, `Makefile`) -- reveals dependency graph
4. Read README and any architecture docs -- reveals intended design
5. `glob` for test files -- reveals what behavior the developers considered important

**The smell:** You start investigating by reading the first source file you find. Without scanning the landscape first, you can't tell whether this file is central or peripheral.

### 6. Entry Points -- Where Execution Begins

Every investigation needs a starting location. Different project types have different entry points:

| Project Type | Entry Point Pattern | Search Strategy |
|---|---|---|
| Web server | Route definitions, HTTP handlers | `grep` for `app.get`, `router.`, `@app.route` |
| CLI tool | Main function, argument parser | `grep` for `fn main`, `if __name__`, `argparse` |
| Library | Public API surface, exports | Read `lib.rs`, `index.ts`, `__init__.py` |
| Worker/daemon | Event loop, message handler | `grep` for `while`, `consume`, `on_message` |
| Test suite | Test files themselves | `glob` for `*test*`, `*spec*` |

**The smell:** You can't find the entry point. This often means the codebase uses a framework that hides it (Spring Boot, Rails, Django). Search for the framework's configuration file -- it points to the entry point.

### 7. Data Model First -- The Most Stable Starting Point

Jeremy Ong (game engine developer): "Understand the data model before the algorithms." Data structures change less frequently than logic and constrain what the logic can do. Once you know the data model, the code that operates on it becomes more predictable.

**Where to find the data model:**
- Database migrations: `glob` for `*migration*`, `*schema*`
- Type definitions: `glob` for `*model*`, `*entity*`, `*types*`
- API schemas: `glob` for `*.proto`, `*schema*`, `*openapi*`
- Configuration: `glob` for `*.toml`, `*.yaml`, `*.json` in config directories

**The smell:** You're trying to understand complex logic without first understanding what data it operates on. The algorithm is a function of the data model -- know the inputs before tracing the process.

---

## Navigation Techniques

### 8. Seek-Relate-Collect -- The Ko Model

Ko, Myers, Coblenz, and Aung (2006) observed that developers navigate code through three interleaved activities:

**Seek:** Search for relevant code using keyword search or structural navigation.
- Start with `grep` for the user's keywords, error messages, or UI text
- If that fails, use `glob` to find files by name patterns
- If that fails, use `git log --all -S "search term"` to find where a string was introduced

**Relate:** Once relevant code is found, follow dependencies in both directions.
- Incoming: `grep` for function/class name to find all callers
- Outgoing: Read the function to see what it calls/imports
- The "hub and spoke" pattern: return to a central entity and explore different dependencies from it

**Collect:** Gather information for later use.
- Maintain a running list of key files and their roles
- Record each file's purpose in one sentence
- Track which questions remain unanswered

**Key finding:** 35% of developer time was spent on navigation mechanics, not understanding. Pre-computing the dependency neighborhood before deep-reading any file eliminates most of this overhead.

**The smell:** You're reading files sequentially without tracking connections between them. You re-discover the same dependency three times because you didn't record it.

### 9. Scent-Following -- Navigate by Lexical Relevance

Lawrance and Burnett (2013) applied information foraging theory to code navigation. "Scent" is the lexical similarity between your goal (the question you're investigating) and the surface cues of code (function names, variable names, comments).

**The procedure:** Extract keywords from your investigation question. Grep for those keywords across the codebase. Files and functions with the most keyword matches have the highest scent -- investigate those first. From each high-scent location, follow dependencies to the next highest-scent neighbor.

**Scent propagation:** If method A calls method B, and B has high scent for your question, then A's call to B inherits elevated scent. This means callers of relevant functions are also worth investigating.

**False scent:** A misleading name is WORSE than a meaningless name. A function called `validateToken` that actually handles logging is a false scent trap. When a high-scent location turns out to be irrelevant, backtrack to the last branch point.

**The finding:** PFIS (Programmer Flow by Information Scent) predicted programmer navigation more accurately than another programmer's predictions. Scent-following is that systematic.

**The smell:** You keep returning to the same irrelevant file because its name sounds relevant. Recognize the false scent and blacklist it.

### 10. Dependency Tracing -- Follow Imports and Calls

The most reliable navigation method when scent is unclear:

**Forward tracing (what does this code depend on):**
- Read import/require statements at the top of the file
- For each imported module, check what from it is used
- Follow the most-used import first

**Backward tracing (what depends on this code):**
- `grep` for the module/function/class name across the codebase
- Filter to actual usage (not just imports that don't use it)
- Callers reveal how the code is expected to behave

**Data flow tracing (where does this value come from):**
- Find where a variable is assigned
- Find where each component of that assignment comes from
- Recursively trace back -- this is manual program slicing (Weiser 1984)
- The average slice is ~30% of the program, so slicing eliminates ~70% of irrelevant code

**The smell:** You're trying to understand a function by reading it in isolation. Without knowing who calls it and what it calls, you're missing context that defines its purpose.

---

## Specialized Investigation Techniques

### 11. Hotspot Analysis -- Where Bugs Concentrate

Tornhill's behavioral code analysis: files that change frequently AND are complex are hotspots -- they account for 4-6% of the codebase but concentrate most defects.

**Quick hotspot identification:**
```bash
# Most-changed files in the last 6 months
git log --since='6 months ago' --format=format: --name-only | sort | uniq -c | sort -rn | head -20
```

Cross-reference with file size (`wc -l`) for a simple hotspot metric. Large files that change often are the highest-risk areas.

**Temporal coupling detection:** Files that change together in commits have hidden dependencies:
```bash
# For each commit, which files changed together
git log --pretty=format:'%h' --since='6 months ago' | while read commit; do git diff-tree --no-commit-id --name-only -r $commit; echo "---"; done
```

Files with >30% co-change rate are temporally coupled regardless of what the import graph says.

**The smell:** You're investigating a bug by reading the most obviously related file. But the bug might be in a hotspot -- a frequently-changing file that's accumulated complexity and technical debt.

### 12. Architecture Recovery -- Reconstructing Design from Code

SEI's Architecture Reconstruction process (CMU/SEI-2002-TR-034): architecture is never directly visible in code -- there's no programming language construct for "layer" or "connector." Architecture must be inferred from patterns of relationships.

**The four-phase process:**
1. **Extract:** Find entities (files, classes, modules) and relationships (imports, calls, inherits). Use `grep` for import statements and `glob` for file enumeration.
2. **Normalize:** Group files into modules (usually by directory). Name modules by their apparent purpose.
3. **Fuse views:** Layer the modules. If A imports B but B never imports A, then A depends on B. Check if dependencies only flow in one direction (layered) or form cycles (coupled).
4. **Test hypotheses:** "Is this MVC?" -> Check for clear model, view, controller groups with expected dependency patterns. "Is this layered?" -> Check for unidirectional dependencies.

**The key insight:** "As-built" architecture often differs from "as-designed." Finding where they diverge reveals architectural decay -- and where future problems will come from.

**The smell:** You assume the architecture matches the README's description. The code may tell a different story.

### 13. Scratch Refactoring -- Understand by Restructuring

Feathers (Working Effectively with Legacy Code): freely restructure code to understand it, then REVERT everything. Extract methods, rename variables to what you think they mean, simplify logic, move code around. The goal is comprehension, not production code.

**Why it works:** Renaming `x` to `retry_count` forces you to verify that `x` IS a retry count. Extracting a method forces you to identify the boundaries of a logical unit. Simplifying a conditional forces you to understand all the branches.

**The rule:** Always work on a branch you'll discard. Scratch refactoring is a reading technique, not a writing technique.

**The smell:** You're staring at a complex function trying to understand it mentally. Physical restructuring (even reverted) is faster than mental modeling.

### 14. Characterization Tests -- Capture Actual Behavior

Feathers' technique: write a test that calls the code, let it fail to discover actual output, update the assertion to match. Now you have documented actual behavior as a regression safety net.

**Why this matters for investigation:** You think you understand what the code does. The characterization test verifies it. If the test output surprises you, your mental model is wrong -- and you've caught it before making a change based on that wrong model.

**The smell:** You've read the code and you're confident about what it does, but you haven't verified. Characterization tests are the verification.

### 15. Configuration as Hidden Architecture

Chen et al. (2020) found that 86% of configuration dependencies in cloud systems were undocumented. Configuration parameters interact in ways that no documentation mentions.

**Five dependency types to look for:**
1. **Control dependency:** Parameter A determines whether parameter B is used at all
2. **Value relationship:** Parameter A constrains valid values of parameter B
3. **Overwrite dependency:** Parameter A's value replaces parameter B
4. **Default value dependency:** Parameter A is fallback when parameter B is unset
5. **Behavioral dependency:** Parameters A and B jointly determine a behavior (host + port)

**Investigation method:** When investigating a config parameter, grep for where it's read in code. Trace the value through conditionals and assignments. If it appears in an `if` that gates another config read, that's a control dependency.

**The smell:** You changed a configuration value and something unrelated broke. You hit an undocumented configuration dependency.

---

## History-Based Investigation

### 16. Commit Messages as Intent -- The WHY Behind the WHAT

Code shows WHAT exists. Git history shows WHY it exists. For investigation, the WHY is often more valuable.

- `git log --oneline -20` -- recent history, high-level timeline
- `git log --oneline --follow path/to/file` -- specific file evolution
- `git log -p --follow path/to/file` -- patches showing what changed and when
- `git blame path/to/file` -- who wrote each line and when
- `git log --all -S "search_term"` -- when a string was introduced or removed (pickaxe search)

**The smell:** You're confused about why the code is structured this way. The answer is often in the commit message from when it was last significantly changed.

### 17. Knowledge Mapping -- Who Knows What

`git shortlog -sn -- path/to/module` reveals who has contributed most to a module. This matters for investigation because:
- The top contributor likely understands the design intent
- Modules with a single contributor are knowledge orphans -- if that person left, nobody understands the code
- Modules with many contributors change frequently -- they're collaboration hotspots

**The smell:** You're struggling with a module and don't know who to ask. Git shortlog tells you.

### 18. Temporal Coupling -- Hidden Dependencies

Files that change together in commits are coupled, regardless of what the import graph says. Copy-paste duplication, implicit protocols, shared conventions -- all create temporal coupling invisible to static analysis.

**Detection:** For each commit, record which files changed together. Files with >30% co-change rate across commits are temporally coupled. When investigating one, you should investigate the other.

**The smell:** You changed one file and something in a completely unrelated file broke. There's temporal coupling you didn't know about.

---

## Strategy Management

### 19. Drop Failing Strategies Fast

Spinellis: "If a strategy does not quickly produce the results you want, drop it and try something different." This is the single most important practical rule for efficient investigation.

**Strategy rotation:** If grep for a function name returns nothing, try:
1. Search for the error message it might produce
2. Search for the test that exercises it
3. Search for the config that enables it
4. Search for the import that references it
5. Search git history for when it was introduced

Spend no more than 2-3 minutes on a failing strategy before switching.

**The smell:** You've been grepping variations of the same term for 10 minutes with no results. Try a completely different approach.

### 20. Time-Box and Iterate -- Prevent Rabbit Holes

OORP's one-hour scan, Feathers' scratch refactoring (revert when done), SEI's iterative phases -- all prevent rabbit holes. Set explicit depth limits and return to broaden before going deeper.

**The procedure:**
1. Scan broadly (10 minutes): directory structure, file sizes, build config
2. Investigate target area (20 minutes): entry point, immediate dependencies, relevant tests
3. Check understanding (5 minutes): can you explain what you found? what remains unclear?
4. Go deeper only on specific gaps (remaining time): targeted investigation of what you don't yet understand

**The smell:** You've been reading code for an hour and can't summarize what you've learned. You went too deep too early without building a framework.

### 21. The Investigation Report -- What to Record

After investigation, record:
- **Module map:** Key files and their roles (1 sentence each)
- **Data model:** Key types, their relationships, where they're defined
- **Entry points:** Where execution begins for the relevant use cases
- **Hotspots:** Files that change frequently, files that are most complex
- **Open questions:** What remains unclear and where to look next
- **Surprises:** Anything unexpected -- these are often the most valuable findings

This report is a starting point for future investigation of the same codebase. It's the agent's equivalent of the expert's internalized knowledge.

**The smell:** You investigated thoroughly but recorded nothing. The next investigator (or the next conversation) starts from zero.
