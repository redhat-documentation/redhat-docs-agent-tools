---
name: docs-review-language
description: Review AsciiDoc files for language issues including spelling, grammar, word usage, and acronyms. Use this skill for language-focused peer reviews.
model: claude-opus-4-5@20251101
---

# Language review skill

Review documentation for language issues: spelling, grammar, word usage, acronyms, and terminology.

## Checklist

### Spelling and typos

- [ ] American English spelling is used consistently
- [ ] Correct punctuation is used throughout

### Grammar

- [ ] American English grammar is used consistently
- [ ] Slang or non-English words are not used

### Word usage and entity naming

- [ ] Precise wording is used
- [ ] Words are used according to their dictionary definitions
- [ ] Context of words is considered (meaning, tone, implications)
- [ ] Named entities are classified on first use
- [ ] Contractions are avoided (unless intentionally used for conversational style)
- [ ] Proper nouns are capitalized
- [ ] Conscious language guidelines are followed:
  - Avoid "blacklist", "whitelist", "master", "slave" unless absolutely necessary
  - Use "allowlist", "denylist", "primary", "replica" instead

### Acronyms and abbreviations

- [ ] Acronyms are expanded on first use
- [ ] Abbreviations are used and applied correctly

### Terms and constructions

- [ ] Phrasal verbs are avoided (use "delete" not "get rid of")
- [ ] Problematic terms avoided:
  - Use "might" instead of "may" (permission vs possibility)
  - Use "must" instead of "should" for requirements
- [ ] Anthropomorphism is avoided (systems don't "want" or "think")

## How to use

1. Review only changed content and necessary context
2. For each issue found, cite the relevant style guide
3. Mark issues as **required** (typos, style violations) or **[SUGGESTION]** (wording improvements)

## Example invocations

- "Review this file for language issues"
- "Check spelling and grammar in modules/getting-started.adoc"
- "Do a language review on the changed files in this PR"

## References

For detailed guidance, consult:
- IBM Style Guide
- Red Hat Supplementary Style Guide: https://redhat-documentation.github.io/supplementary-style-guide
- Merriam-Webster Dictionary for spelling
