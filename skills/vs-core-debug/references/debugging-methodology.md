# Debugging Methodology

A decision framework for systematic debugging, grounded in research on how expert debuggers actually work. Each topic is how a senior engineer thinks about the trade-off -- when the textbook advice is right, when it's wrong, and how to tell the difference.

---

## The Mental Model

### 1. The Infection Chain -- Debugging Is Tracing Causation

Zeller's "Why Programs Fail" (2005, 2009) defines the defect-infection-failure chain: a defect in code causes an infection in program state, which propagates through subsequent states until a failure becomes externally observable. Debugging is identifying and severing this chain.

**The practical implication:** Every bug has a traceable path from defect to failure. If you can't trace the path, you haven't found the root cause -- you've found a symptom. The fix must target the defect (where the chain starts), not the failure (where you noticed it) or an intermediate infection point.

**When the chain model breaks:** Emergent failures in concurrent systems, where no single defect exists -- the bug is in the interaction between correct components. Configuration bugs, where the code is correct but the environment is wrong. In these cases, the "defect" is a design assumption that doesn't hold.

**The smell:** Your fix changes where the failure appears but the behavior near the defect is unchanged. You severed the chain at the wrong point -- the infection will find another path to a failure.

### 2. Competing Hypotheses -- Don't Depth-First on One Theory

Chattopadhyay et al. (ICSE 2020) observed 10 professional developers in the field and found fixation bias is the dominant cognitive failure in debugging: 428 of 477 fixation-linked actions were subsequently reversed, consuming 25% of total work time. Developers commit to one theory and seek confirming evidence.

**The countermeasure:** Always maintain at least two competing explanations. For each piece of evidence, ask: which explanations does this support, and which does it contradict? Evidence that distinguishes between hypotheses is more valuable than evidence that confirms one. This is Heuer's Analysis of Competing Hypotheses principle applied to debugging.

**The trap for AI agents:** LLMs generate one explanation and pursue it depth-first, just like humans with fixation bias. The mechanism is different (token-by-token generation vs. cognitive commitment) but the outcome is the same. Force yourself to name a second explanation before investigating the first.

**The smell:** All your hypotheses are in the same module. Step back -- what if the bug isn't in that module at all?

### 3. Strategy Selection Is Dynamic -- Rigid Processes Fail

Alvarez-Picallo et al. (2025, arxiv:2501.11792) studied 35 developers and interviewed 16 experienced engineers. They found six primary debugging strategies used in practice: hypothesis-testing, backward-reasoning, forward-reasoning, simplification, error-message debugging, and binary-search. The critical finding: **experts dynamically switch strategies based on context** -- defect characteristics, codebase familiarity, tool availability. No single strategy dominates.

**What triggers a strategy switch:** Clear error message enables direct approach. Non-reproducible defect pushes toward hypothesis-testing with logging. Unfamiliar codebase forces forward-reasoning from entry points. Production constraints (no debugger access) force indirect methods.

**The anti-pattern:** Following a fixed debugging procedure regardless of what you observe. The strategy table in SKILL.md is a starting point -- adapt as evidence accumulates.

---

## Reproduction and Scoping

### 4. Reproduce First, Isolate Second

Reproduction is the foundation. Without it, you're debugging a description of a bug, not the bug itself. Get the exact error message, the exact stack trace, the exact wrong output. Then isolate: what's the smallest context where this breaks? Does it break with simpler input? In a different environment?

**Why isolation matters:** Zeller's delta debugging (TSE 2002) reduced a Mozilla crash from 95 user actions to 3 relevant ones, and 896 lines of HTML to 1 line. You don't need the algorithm -- you need the principle: every element you remove from the reproduction that doesn't change the failure is one less thing to reason about.

**The boundary between working and broken IS fault localization.** If it works with input A but fails with input B, the bug is in how the code handles the difference. If it works in module X's tests but fails in module Y's integration, the bug is at the boundary. The working/broken boundary is the most informative single piece of evidence.

### 5. The Reproduction Paradox -- When Observation Changes the Bug

Heisenbugs -- bugs that disappear when observed -- are a documented class. Adding a debugger changes thread timing. Print statements change I/O scheduling. Log probes alter cache line behavior. For timing-sensitive race conditions, "reproduce under observation" is structurally impossible.

**When you can't reproduce:** Don't keep trying the same reproduction strategy. Switch to: log analysis of past occurrences, code review of concurrency assumptions, deterministic replay tools (rr records at <=1.2x overhead and replays deterministically -- O'Callahan et al., USENIX ATC 2017), or systematic concurrency testing (CHESS from MSR enumerates thread interleavings).

**The judgment:** Try to reproduce, but recognize when reproduction is impossible for a specific bug class. Spending 80% of debugging time on reproduction of a Heisenbug is the wrong allocation.

---

## Cognitive Traps

### 6. Confirmation Bias in Debugging -- The Evidence

Developers are 4x more likely to write tests that confirm working behavior than tests designed to break code (Springer SQJ 2013). This rate is the same for experienced and novice developers -- expertise does not cure confirmation bias. A 2026 study (arxiv:2601.08045) found that LLM-assisted development is more biased, not less: 56.4% of LLM-triggered actions showed cognitive bias.

**Countermeasures:** For every confirming piece of evidence, seek one disconfirming piece. If your hypothesis is "the bug is in the parser," explicitly check whether the parser's output is actually correct before investigating further. Ask: "what would I expect to see if my hypothesis is WRONG?" -- then look for that.

**The smell:** Every piece of evidence you've gathered supports your hypothesis. Real debugging almost always encounters contradictions early. If everything confirms, you're not looking hard enough.

### 7. Mental Model Development Is the Bottleneck

Bohme et al. (arxiv:2602.11435, 2026) conducted the most methodologically rigorous study of professional debugging: a grounded theory analysis of real debugging sessions. Key finding: mental model development consumes approximately 57% of debugging time -- far more than the fix itself.

**The implication for AI debugging:** The agent's job is not just finding a patch. It's building the model of how the system works, how the failure occurs, and why the fix is correct. A patch without a model is a guess.

**What experts actually do vs. what they say:** Bohme's study found developers report using scientific hypothesis-testing, but observation shows different behavior -- their theories are "too vague to be testable, or too many to each be tested." Experts use recognition-primed decision making: pattern-matching from past bugs, not formal experimentation. An AI agent lacks the experience library for pattern matching, so structured investigation compensates.

### 8. The Root Cause Default and Its Exceptions

Root cause analysis prevents recurrence. A fix that addresses the symptom will break again when a different input triggers the same defect. This is the default because the expected cost of recurrence usually exceeds the cost of investigation.

**Three exceptions where the default is wrong:**
1. **Active incident** -- production is burning. The SRE playbook is correct: mitigate first, investigate after. Patching the symptom to stop user impact is the right call when the alternative is extended outage during investigation.
2. **Code being replaced** -- if the module is scheduled for removal or rewrite within a known timeline, root cause analysis of a bug in dead-walking code is wasted effort.
3. **Investigation cost demonstrably exceeds recurrence cost** -- a cosmetic bug that appears once a year in a low-traffic path. The judgment: estimate recurrence frequency x impact vs. investigation time. If investigation costs more, document the decision and move on.

**In all three cases, document that root cause was deferred and why.** Undocumented symptom patches accumulate into systemic fragility.

---

## Framing and Communication

### 9. When to Shift Strategy -- Abandonment Triggers

Three signals that your current investigation direction is wrong:
1. **Evidence plateau** -- you've gathered 3+ pieces of evidence and none discriminates between hypotheses. You're confirming what you already know rather than narrowing the search.
2. **Expanding scope** -- each step of investigation reveals more code to examine rather than less. You're moving away from the root cause, not toward it.
3. **Repeated contradiction** -- evidence contradicts your hypothesis but you keep adjusting the hypothesis to accommodate it ("maybe it's a race condition... or maybe the cache is stale... or maybe the config is wrong"). If you've revised the hypothesis 3 times without converging, abandon it.

**What to do:** Dispatch the reflector. It reads your investigation cold and identifies what assumption you're making that you haven't tested. The reflector's value is that it has no investment in your theory.

### 10. Causal Explanation Over Ranked Lists

Parnin & Orso (ISSTA 2011, Impact Paper Award 2021) studied whether fault localization tools actually help developers. Key finding: developers do not examine suspicious statements in the order tools provide -- they jump around based on intuition. Changes in ranking had no significant effect on outcomes.

**What developers actually want:** "Values, overviews, and explanations." Ko & Myers' Whyline (ICSE 2008) reframed debugging as answering "why did X happen?" and "why didn't Y happen?" -- developers were 3x more successful and 2x faster with this framing.

**The implication for an AI agent:** Don't present a list of suspicious locations. Explain the infection chain: "This variable is null because function X returned early on line Y, which happened because the config was missing key Z." Trace causation, don't rank suspicion.
