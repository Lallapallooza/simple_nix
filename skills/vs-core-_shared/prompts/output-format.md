# Structured Finding Format

Report each finding using this structure. No prose paragraphs -- structured data only.

## Finding Template

```
### [SEVERITY] Category: Brief title

**Location**: `file:line` or `module::function`
**Severity**: Critical | High | Medium | Low
**Category**: Correctness | Security | Architecture | Performance | Style | Testing
**Issue**: One-sentence description of what's wrong
**Evidence**: The specific code, logic trace, or reasoning that proves this is a real issue
**Impact**: What bad thing happens if this is not fixed -- the failure scenario
**Suggestion**: Concrete fix (what to change, not just "consider improving")
```

## The "So What?" Test

Every finding must pass this test: if this finding is real, what bad thing happens? If you can't articulate the consequence, the finding is noise. "This function is long" fails -- so what? "This function is long and the error handling on line 147 is unreachable because of the early return on line 89" passes.

## Evidence Standards

Every finding must meet a minimum evidence bar:

- **Specific lines** referenced -- not just "in this function" but `file.py:47-53`
- **Specific concern** identified -- not just "error handling" but "ValueError from parse() is caught but the retry counter isn't decremented"
- **Specific pattern** or trace -- how you found this, what execution path triggers it

Findings without line references are noise. Speculation without traced evidence is noise. "This looks wrong" without explaining WHY is noise.

## Severity Definitions

- **Critical**: Will cause data loss, security breach, crash, or undefined behavior in production
- **High**: Incorrect behavior under non-exotic conditions, or a vulnerability with a plausible attack vector
- **Medium**: Edge case bug, performance issue under load, maintainability problem that will cause future bugs. **"Probably fine" = Medium** -- flag it, let the human decide
- **Low**: Style, naming, minor inefficiency, or improvement opportunity

## Rules

- One issue per finding -- don't combine unrelated problems
- Concrete suggestions -- "refactor this" is useless; show what the refactored code looks like or describe the specific change
- Deduplicate -- if the same pattern appears in 5 places, report it once and list all locations
- **Zero findings is valid.** If rigorous examination found nothing, say what you examined and why it's correct. Don't fabricate findings to fill a template.
