---
name: docs-review-style
description: Review AsciiDoc files for style issues including voice, tense, titles, and formatting. Use this skill for style-focused peer reviews.
model: claude-opus-4-5@20251101
---

# Style review skill

Review documentation for style issues: passive voice, tense, titles, formatting, and AsciiDoc markup.

## Checklist

### Voice

- [ ] Unnecessary passive voice is avoided
- [ ] Active voice is used when the actor is known
- [ ] Passive voice is acceptable when the actor is unknown or unimportant

### Tense

- [ ] Present tense is used for current facts and states
- [ ] Future tense is used only when necessary (describing what will happen)

### Titles and headings

- [ ] Titles use sentence case (not Title Case)
- [ ] Titles and headings have consistent styling
- [ ] Titles are effective and descriptive
- [ ] Titles focus on customer tasks, not the product
- [ ] Titles are 3-11 words long (50-80 characters)
- [ ] Procedure module titles begin with a gerund:
  - "Configuring the database connection"
  - "Installing the operator"
  - "Using the CLI to manage resources"

### Number conventions

- [ ] Spell out one through nine in body text
- [ ] Use numerals for 10 and above
- [ ] Use numerals in tables and lists
- [ ] Use numerals with units (5 GB, 3 seconds)

### Formatting

- [ ] User-replaceable values use correct format: `_<placeholder>_`
- [ ] Code blocks use correct syntax highlighting
- [ ] Lists have parallel structure
- [ ] Tables have header rows

### AsciiDoc markup

- [ ] Correct AsciiDoc markup is used throughout
- [ ] Admonitions use correct syntax (NOTE, IMPORTANT, WARNING, TIP, CAUTION)
- [ ] Cross-references use xref macro correctly

## How to use

1. Review only changed content and necessary context
2. Run Vale for automated style checking: `vale <file.adoc>`
3. For manual issues, cite the relevant style guide
4. Mark issues as **required** (style violations) or **[SUGGESTION]** (preferences)

## Example invocations

- "Review this file for style issues"
- "Check voice and tense in the procedure modules"
- "Do a style review on assemblies/installing.adoc"
- "Run vale and review style in modules/"

## Integrates with

- **Vale skill**: Run `vale <file>` for automated style linting

## References

For detailed guidance, consult:
- IBM Style Guide
- Red Hat Supplementary Style Guide: https://redhat-documentation.github.io/supplementary-style-guide
