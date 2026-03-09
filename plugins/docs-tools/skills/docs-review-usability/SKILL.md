---
name: docs-review-usability
description: Review AsciiDoc files for usability issues including accessibility, links, and visual rendering. Use this skill for usability-focused peer reviews.
model: claude-opus-4-5@20251101
---

# Usability review skill

Review documentation for usability: accessibility, links, visual continuity, and audience appropriateness.

## Checklist

### Audience

- [ ] Content is appropriate for the intended audience
- [ ] Technical level matches expected reader knowledge
- [ ] Jargon is explained or avoided for general audiences

### Accessibility

- [ ] Images have alternative (alt) text that describes the content
- [ ] Tables have descriptive captions
- [ ] Diagrams are explained in surrounding text
- [ ] Color is not the only way to convey information
- [ ] Links have descriptive text (not "click here")

### Links and cross-references

- [ ] Inline links are minimized (prefer Additional resources section)
- [ ] All links are functional
- [ ] All links point to current, valid content
- [ ] External links include context about the destination
- [ ] Cross-references use meaningful anchor text

### Visual continuity

- [ ] Content renders correctly in preview
- [ ] Spacing is correct and consistent
- [ ] Bulleted lists format correctly
- [ ] Numbered lists have correct numbering
- [ ] Code blocks render with proper formatting
- [ ] Tables display as intended

### Accuracy

- [ ] Product versions are accurate
- [ ] Release dates are correct
- [ ] Command examples are current
- [ ] UI element names match the product

### Context and transitions

- [ ] Readers understand where they are in the workflow
- [ ] Transitions between sections are smooth
- [ ] Readers know what to do next after completing a procedure

## Key principles

**Usability means:**
- Content works for all users, including those with disabilities
- Links are functional and up-to-date
- Visual presentation matches intent
- Information is accurate and current

## How to use

1. Review only changed content and necessary context
2. Check that content renders correctly (use preview)
3. Verify links are functional
4. Mark issues as **required** (broken links, accessibility) or **[SUGGESTION]** (improvements)

## Example invocations

- "Review this file for usability issues"
- "Check accessibility in the getting-started guide"
- "Verify all links work in this assembly"
- "Do a usability review on the changed modules"

## References

For detailed guidance, consult:
- CCS Accessibility Checklist
- IBM Style Guide
- WCAG 2.1 Guidelines
