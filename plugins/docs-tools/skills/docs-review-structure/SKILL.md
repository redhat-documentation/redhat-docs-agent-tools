---
name: docs-review-structure
description: Review AsciiDoc files for structure issues including modular docs compliance, logical flow, and user stories. Use this skill for structure-focused peer reviews.
model: claude-opus-4-5@20251101
---

# Structure review skill

Review documentation for structure: modular docs compliance, logical flow, user stories, and content organization.

## Checklist

### Modular docs compliance

- [ ] Module types are not mixed:
  - Concept modules explain "what is..."
  - Procedure modules explain "how to..."
  - Reference modules provide lookup tables/lists
- [ ] Module types are used correctly for the content
- [ ] Modules are self-contained for reuse
- [ ] Each module has a single, clear purpose
- [ ] Assemblies combine modules logically

### Module structure

- [ ] Concept modules:
  - Start with a definition or explanation
  - Have `[role="_abstract"]` for short description
  - Do not include procedures
- [ ] Procedure modules:
  - Have `.Prerequisites` section if needed
  - Have `.Procedure` section with numbered steps
  - Have `.Verification` section if applicable
  - Title starts with gerund (Configuring, Installing)
- [ ] Reference modules:
  - Contain tables, lists, or specifications
  - Provide lookup information

### Logical flow of information

- [ ] Information is provided at the right pace
- [ ] Information is presented in logical order
- [ ] Prerequisites come before procedures
- [ ] Context is provided before details
- [ ] Cross-references are used appropriately

### User stories

- [ ] The user goal is clear
- [ ] Tasks reflect the intended goal of the user
- [ ] Troubleshooting steps are included where appropriate
- [ ] Error recognition and recovery is addressed

### Content organization

- [ ] Related information is grouped together
- [ ] Assembly structure reflects user workflow
- [ ] Table of contents makes sense for the user journey

## Key principles

**Good structure means:**
- Separating concepts from procedures
- Organizing information in a task-oriented way
- Making modules reusable across assemblies
- Providing information when users need it

## How to use

1. Review only changed content and necessary context
2. Check module type matches content type
3. Verify required sections are present
4. Mark issues as **required** (modular violations) or **[SUGGESTION]** (reorganization)

## Example invocations

- "Review this file for structure issues"
- "Check if this procedure follows modular docs guidelines"
- "Do a structure review on the assembly"
- "Verify the module types are correct in modules/"

## References

For detailed guidance, consult:
- Red Hat Modular Documentation Guide: https://redhat-documentation.github.io/modular-docs/
- IBM Style Guide
