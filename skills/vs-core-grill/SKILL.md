---
name: vs-core-grill
description: Socratic interview to reach shared understanding before starting work. Use this skill when the user wants to discuss a plan, design, or approach before implementing. Also use when the user says "grill me", "interview me", "let's think through this", "what should we consider", or when starting a complex task where requirements are unclear.
allowed-tools: Read Glob Grep Bash AskUserQuestion
---

## Artifact Profile

Read `../vs-core-_shared/prompts/artifact-persistence.md` for the full protocol.

- **stage_name**: grill
- **artifact_filename**: grill.md
- **write_cardinality**: single
- **upstream_reads**: none
- **body_format**:
  ```
  ## Shared Understanding
  ### Decisions Made
  - [Decision 1]
  ...
  ### Open Questions (if any)
  ### Recommended Next Step
  ```

# Socratic Interview

Interview the user relentlessly about every aspect of this plan until you reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one.

## Artifact Flow

1. **Before the interview begins**: Run ARTIFACT_DISCOVERY (see artifact-persistence.md). Establish the feature slug silently if unambiguous.
2. **After producing the Shared Understanding summary**: Run WRITE_ARTIFACT -- write `grill.md` to `.spec/{slug}/` with the frontmatter schema and the Shared Understanding block as the body.

## Rules

- Ask questions **one at a time**
- For each question, **provide your recommended answer as a single declarative sentence the user can accept with "yes" or reject with "no"**. If you need a table, multiple paragraphs, or a "here are your options" list to explain the recommendation, the question is either premature (explore the codebase first) or actually several questions in disguise (split it). A recommendation the user has to interpret is a blank canvas with extra steps.
- If a question can be answered by **exploring the codebase**, explore the codebase instead of asking the user
- Resolve dependencies in order: don't ask about implementation details before agreeing on the approach
- Challenge assumptions: if the user's answer seems to conflict with what you know about the codebase or domain, push back respectfully
- Keep going until every branch of the design tree has been resolved to a concrete decision
- Summarize the shared understanding at the end as a bullet list of decisions made

## Output Contract

When the interview is complete, produce a structured summary:

```
## Shared Understanding

### Decisions Made
- [Decision 1]
- [Decision 2]
...

### Open Questions (if any)
- [Question that needs more investigation]

### Recommended Next Step
[What should happen next -- /vs-core-implement, /vs-core-rfc, /vs-core-arch, or something else]
```

This output format allows composite skills (like `/vs-core-rfc`) to consume the grill results programmatically.
