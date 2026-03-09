---
name: dita-entity-reference
description: Replace HTML character entity references with Unicode equivalents for DITA compatibility. Use this skill when asked to fix entity references, replace HTML entities, or prepare files for DITA conversion.
model: claude-haiku-4-5@20251001
allowed-tools: Bash, Glob, Read, Edit, Write
---

# Entity reference transform skill

Replace unsupported HTML character entity references with their Unicode equivalents for DITA compatibility.

## Overview

This skill uses the `entity_reference.rb` Ruby script to find and replace HTML character entity references (like `&nbsp;`, `&mdash;`, `&copy;`) with their Unicode character equivalents. DITA only supports five XML entities: `&amp;`, `&lt;`, `&gt;`, `&apos;`, and `&quot;`.

## AI Action Plan

**When to use this skill**: When Vale reports `EntityReference` issues or when asked to fix entity references, replace HTML entities, or prepare files for DITA conversion.

**Group handling**: YES - List all EntityReference issues together under a single heading.

**Steps to follow**:

1. **If there are few (5 or less) unsupported entity references**:
   - Replace them with AsciiDoc attributes to the best of your knowledge
   - Use built-in AsciiDoc attributes when available: https://docs.asciidoctor.org/asciidoc/latest/attributes/character-replacement-ref/
   - Or use normal characters (such as `&` or `<`) when appropriate

2. **In all cases**, display an explanation to the user, importantly including:
   - Link to built-in AsciiDoc attributes: https://docs.asciidoctor.org/asciidoc/latest/attributes/character-replacement-ref/
   - Link to AsciiDoc DITA Toolkit for bulk replacement: https://github.com/rheslop/asciidoc-dita-toolkit/tree/main
   - Reminder that the five standard XML entity references (`&amp;`, `&lt;`, `&gt;`, `&apos;`, `&quot;`) are supported and should not be replaced

## What it transforms

### Common replacements

| Entity | Unicode | Description |
|--------|---------|-------------|
| `&nbsp;` | ` ` | Non-breaking space |
| `&ndash;` | `–` | En dash |
| `&mdash;` | `—` | Em dash |
| `&hellip;` | `…` | Horizontal ellipsis |
| `&copy;` | `©` | Copyright |
| `&reg;` | `®` | Registered trademark |
| `&trade;` | `™` | Trademark |
| `&rarr;` | `→` | Right arrow |
| `&larr;` | `←` | Left arrow |

### Supported entity categories

- Spaces and breaks
- Dashes and hyphens
- Quotation marks
- Punctuation
- Currency symbols
- Math and symbols
- Arrows
- Greek letters
- Accented characters

## Usage

When the user asks to fix entity references:

1. Identify the target folder or file containing AsciiDoc content
2. Find all `.adoc` files in the target location
3. Run the Ruby script against each file:
   ```bash
   ruby skills/dita-entity-reference/scripts/entity_reference.rb <file>
   ```
4. Report the number of replacements made and any unknown entities found

### Dry run mode

To preview changes without modifying files:

```bash
ruby skills/dita-entity-reference/scripts/entity_reference.rb <file> --dry-run
```

### Output to different file

```bash
ruby skills/dita-entity-reference/scripts/entity_reference.rb <file> -o <output.adoc>
```

## Example invocations

- "Fix entity references in modules/getting_started/"
- "Replace HTML entities in the assemblies folder"
- "Run entity reference transformation on all AsciiDoc files"
- "Fix the entities in modules/inference-rhaiis-with-podman.adoc"
- "Preview entity changes in modules/ --dry-run"

## Behavior notes

- **Preserves supported entities**: `&amp;`, `&lt;`, `&gt;`, `&apos;`, and `&quot;` are left unchanged
- **Skips code blocks**: Entities inside code blocks (---- or ....) are not replaced unless the block has `subs="replacements"` or `subs="normal"`
- **Skips comments**: Entities inside comment blocks (////) and single-line comments (//) are not replaced
- **Reports unknowns**: Unknown entities are reported but not modified

## Output format

```
<file>: Replaced N entity reference(s)
  Unknown entities (not replaced):
    Line X: &unknown;
```

## Extension location

The Ruby script is located at: `skills/dita-entity-reference/scripts/entity_reference.rb`
