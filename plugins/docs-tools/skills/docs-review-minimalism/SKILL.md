---
name: docs-review-minimalism
description: Review AsciiDoc files for minimalism issues including conciseness, scannability, and customer focus. Use this skill for minimalism-focused peer reviews.
model: claude-opus-4-5@20251101
---

# Minimalism review skill

Review documentation for minimalism: conciseness, scannability, customer focus, and removing unnecessary content.

## Checklist

### Customer focus and action orientation

- [ ] Content focuses on actions and customer tasks
- [ ] Features are explained in terms of what users can do with them
- [ ] Content answers "how do I...?" not "what is...?"

### Scannability and findability

- [ ] Content is easy to scan
- [ ] Information is easy to find
- [ ] Bulleted lists break up dense paragraphs
- [ ] Tables present comparative or reference information
- [ ] Headings describe the content that follows

### Sentences

- [ ] Sentences are not unnecessarily long (aim for <25 words)
- [ ] Sentences use only required words
- [ ] Long sentences are split into shorter ones
- [ ] Sentences are concise and informative
- [ ] Each sentence adds value

### Conciseness (no fluff)

- [ ] Text does not include unnecessary information
- [ ] Obvious statements are removed ("As you know...", "It is important to note that...")
- [ ] Self-referential text is removed ("This section describes...", "This topic explains...", "This guide shows...")
- [ ] Redundant phrases are eliminated:
  - "in order to" → "to"
  - "at this point in time" → "now"
  - "due to the fact that" → "because"
- [ ] Admonitions are used only when necessary
- [ ] Screenshots are used only when text cannot suffice
- [ ] Diagrams add value that text alone cannot provide
- [ ] Content is clear, precise, and unambiguous

## Key principles

**Minimalism means:**
- Writing only what users need to know
- Focusing on tasks, not features
- Removing redundant or obvious information
- Using simple, direct language
- Getting users to their goal quickly

**Ask yourself:**
- Does this sentence help the user complete their task?
- Can this be said in fewer words?
- Would removing this change the user's understanding?

## How to use

1. Review only changed content and necessary context
2. Look for content that can be shortened or removed
3. Check that each paragraph serves a clear purpose
4. Mark issues as **required** (unclear content) or **[SUGGESTION]** (could be shorter)

## Example invocations

- "Review this file for minimalism"
- "Check if the getting-started guide can be more concise"
- "Do a minimalism review on the concept modules"
- "Look for fluff and unnecessary content in this procedure"

## References

For detailed guidance, consult:
- Red Hat Minimalism Guidelines
- IBM Style Guide
