# Artifact Persistence Protocol

All pipeline skills write structured artifacts to `.spec/`. This file defines the complete protocol. Read it fully before executing any skill logic.

## Frontmatter Schema

Every artifact file begins with exactly these 5 fields:

```yaml
---
feature: string          # the feature slug (matches the .spec/{slug}/ directory name)
stage: string            # must match this skill's stage_name exactly
created: ISO-8601        # set once on first write, never updated
updated: ISO-8601        # updated on every write
upstream: list<string>   # stages actually consumed (not merely declared -- only what was read)
---
```

No additional fields. No omissions. All 5 fields must be present on every write.

## Pipeline Summary

| Skill | stage_name | upstream_reads | multi-artifact |
|---|---|---|---|
| vs-core-grill | grill | none | false |
| vs-core-research | research | grill | false |
| vs-core-arch | arch | grill, research | false |
| vs-core-rfc | rfc | grill, research | false |
| vs-core-implement | implement | rfc | false |
| vs-core-audit | audit | grill, research, arch, rfc, implement | true |
| vs-core-debug | debug | implement | true |

**Multi-artifact** means the skill can produce multiple artifacts per feature (one per session). See WRITE_ARTIFACT for naming.

## ARTIFACT_DISCOVERY

Run this before any skill logic begins.

1. Scan `.spec/` for subdirectories. Exclude `_standalone/`.
2. **count == 0**: Auto-generate a slug from the user's description (see SLUG_GENERATION). Create `.spec/{slug}/`. No confirmation required. If no description is available, ask: "What is this work about?"
3. **count == 1**: Use that slug silently. No confirmation required.
4. **count > 1**: List the feature directories, ask the user to select one.

The selected slug is used for all subsequent reads and writes in this session.

## UPSTREAM_CONSUMPTION

For each stage listed in this skill's `upstream_reads` (from the Pipeline Summary):

1. Check if `.spec/{slug}/{stage}.md` exists.
2. **Exists**: Read it. Include its content in your working context.
3. **Missing**: Warn the user: "Expected upstream artifact `{stage}.md` not found. Proceed without it?" Wait for their answer before continuing.

The `upstream` frontmatter field on the artifact you write records only the stages you actually read -- not the full declared list. If you skipped a stage because the file was missing and the user confirmed proceeding, do not include that stage in `upstream`.

## WRITE_ARTIFACT

### Single-artifact skills (grill, research, arch, rfc, implement)

File path: `.spec/{slug}/{stage_name}.md`

- **mode="create"**: File does not exist. Write full file: frontmatter + body. Set `created=now`, `updated=now`.
- **mode="overwrite"**: File exists. Preserve `created` from existing frontmatter. Set `updated=now`. Replace body entirely. If file does not exist, treat as create.

### Multi-artifact skills (audit, debug)

File path: `.spec/{slug}/{stage_name}-{session-slug}.md`

Where `session-slug` is a 2-4 word lowercase hyphenated identifier derived from the current session's topic (e.g., `audit-auth-refactor`, `debug-login-crash`).

**Slug collision**: If the file already exists, append `-2`, `-3`, etc. until the path is unique.

### Both modes

Always ensure all 5 frontmatter fields are present. Never write a partial frontmatter block.

## STANDALONE_FALLBACK

Use this when the user indicates no feature context, or when you determine this is isolated work not belonging to an ongoing feature.

- Path: `.spec/_standalone/{skill_name}-{slug}.md`
- Create `.spec/_standalone/` if it does not exist.
- `_standalone/` is excluded from ARTIFACT_DISCOVERY scans -- it will never be returned as a feature candidate.
- Write using the standard frontmatter schema. Set `feature` to the slug, `upstream` to `[]`.

## SLUG_GENERATION

- Input: a description string (from user's message or feature context)
- Output: lowercase letters and hyphens only, 2-4 words, recognizable abbreviation of the topic
- Examples: "user authentication refactor" -> `auth-refactor`, "fix login crash on mobile" -> `login-crash-mobile`
- No confirmation required -- generate and proceed.

## Nested Invocation Rule

When a skill is invoked by another skill as a sub-routine (via the Skill tool), the sub-skill does NOT execute this artifact persistence protocol.

- Only top-level user-invoked skills write artifacts.
- The sub-skill runs its logic normally. Its output feeds the parent skill, not the filesystem.
- The parent skill is solely responsible for its own artifact write.

## Design Constraints

- **Single writer per artifact**: each stage_name is written by exactly one skill. No exceptions.
- **No `downstream` field**: artifacts do not track who reads them.
- **Evolution Log lives in `implement.md`**: no other skill writes to it. No cross-write exception.
- **No gitignore**: `.spec/` is not gitignored by default. Lifecycle is the user's responsibility.
