---
name: docs-review-feedback
description: Guide for providing effective peer review feedback including scope, tone, and distinguishing required vs optional changes. Use this skill when giving or formatting review comments.
model: claude-opus-4-5@20251101
---

# Peer review feedback skill

Guidelines for providing effective, respectful, and actionable peer review feedback.

## Core principles

Peer reviews must be **kind**, **helpful**, and **consistent**.

## Scope rules

### In scope (review this)

- Content changed in the PR/MR
- Preexisting sections that provide context for new content
- Issues that make content unclear

### Out of scope (do NOT review)

- Content not changed in the PR/MR
- Enhancement requests (unless content is unclear without it)
- Requesting additional details like default values or units
- Technical accuracy (that's for SMEs and QE)

**For out-of-scope issues, use friendly wording:**
- "I know this was existing content, but would you mind fixing this typo while you're in there?"
- "This is out of scope for this PR, but consider looking into this in a future update."

## Required vs optional changes

### Required (blocks merging)

Mark with **Required:** or no prefix. Must be supported by style guides.

- Typographical errors, grammatical issues
- Modular docs template violations
- IBM Style Guide / Red Hat SSG violations
- Product-specific guideline violations

### Optional (does not block)

Mark with **[SUGGESTION]** or use softer language.

- Wording improvements
- Content reorganization
- Stylistic preferences

**Example phrasing:**
- "[SUGGESTION] Consider moving this to prerequisites"
- "Here, it might be clearer to say..."

## Feedback tone

### Do

- Support comments with style guide references
- Explain the impact on the audience
- Pose comments as questions when unsure
- Use softening language: "consider", "suggest", "might"
- Provide positive feedback for well-done content
- Be concise

### Don't

- Leave unsupported comments ("I don't like this")
- Use harsh language
- Rewrite entire paragraphs
- Tag SMEs or QEs directly
- Overwhelm the writer with too many comments at once

## Constructive suggestions

**Bad:** "This doesn't make sense."

**Good:** "I don't understand this description. Did you mean...?"

**For recurring issues, use global comments:**
- "[GLOBAL] This typo occurs in other locations. I won't comment on other examples, but please address all instances."

## Writer autonomy

- Writers **must** implement required feedback (style violations, typos)
- Writers **may** decline optional suggestions
- If you strongly disagree, speak privately and cite sources

## When to pause

Stop the review and contact the writer if:
- Build is broken
- Content is not rendering properly
- Content is not modularized correctly
- Review requires extensive rework

**Action:** Contact writer privately, express concerns, decide if you can help or need to refer elsewhere.

## Review comment format

When writing review comments, use this structure:

```
**[REQUIRED/SUGGESTION]** Brief description

Explanation of why, with style guide reference if applicable.

Suggested fix (optional):
> Alternative wording here
```

## Example invocations

- "Help me write feedback for this review"
- "Format my review comments properly"
- "Check if my feedback follows peer review guidelines"
- "How should I phrase this required change?"

## References

- IBM Style Guide and Red Hat SSG for supporting citations
