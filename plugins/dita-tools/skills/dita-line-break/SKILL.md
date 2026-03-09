---
name: dita-line-break
description: Remove hard line breaks from AsciiDoc files for DITA compatibility. Use this skill when asked to fix line breaks, remove forced breaks, or prepare files for DITA conversion.
model: claude-haiku-4-5@20251001
allowed-tools: Bash, Glob, Read, Edit, Write
---

# Line break removal skill

Remove hard line breaks from AsciiDoc files for DITA compatibility.

## Overview

This skill uses the `line_break.rb` Ruby script to find and remove hard line breaks that are not supported in DITA. Hard line breaks in AsciiDoc can be created using:

1. A space followed by `+` at the end of a line (` +`)
2. The `:hardbreaks-option:` document attribute
3. The `%hardbreaks` option on blocks
4. The `options=hardbreaks` attribute

## What it removes

### Line continuation markers

**Before:**
```asciidoc
This is the first line +
and this continues on a new line.
```

**After:**
```asciidoc
This is the first line and this continues on a new line.
```

### Document-level hardbreaks attribute

**Before:**
```asciidoc
:hardbreaks-option:

This text has
forced line breaks
everywhere.
```

**After:**
```asciidoc
This text has forced line breaks everywhere.
```

### Block-level hardbreaks option

**Before:**
```asciidoc
[%hardbreaks]
First line
Second line
Third line
```

**After:**
```asciidoc
First line
Second line
Third line
```

## AI Action Plan

**When to use this skill**: When Vale reports `LineBreak` issues or when asked to fix line breaks, remove forced breaks, or prepare files for DITA conversion.

**Steps to follow**:

1. **Locate the affected `+` character** and analyze the context. Pay attention to whether the `+` character is within an AsciiDoc structure, such as a list or table.

2. **If the `+` character is within a table**:
   - Remove the `+` character
   - Replace it with a blank line
   - Add an `a` prefix operator to the cell (e.g., `| content` becomes `a| content`)

3. **If the `+` is at the end of a line within a list** and the following text is a distinct block (code block, table, admonition):
   - Move the `+` to its own line to attach the block to the list item
   - This is the correct usage and should be preserved

4. **If the `+` is at the end of a line NOT within a list** and the following text is a distinct block:
   - Remove the `+`
   - Replace it with a single blank line to create a paragraph break

5. **If the `+` is at the end of a line and is followed by text (not a block)**:
   - Determine if the following text can be logically and grammatically joined to the preceding sentence
   - If it can be joined (e.g., short clarifying phrase), remove the `+` and join into a single paragraph
   - If it cannot be joined, remove the `+` and replace with a blank line to create two separate paragraphs

6. **If the `+` is on its own line but has incorrect spacing** (extra blank lines or comments around it):
   - Fix the spacing by removing the extra lines/comments
   - Ensure `+` is on a line by itself with no blank lines before or after

7. **If complicated formatting is involved** and uncertainty remains, consider using an AsciiDoc open block (bounded by `--` lines at start and end).

## Why this matters

Hard line breaks cannot be mapped to DITA output. The AsciiDocDITA Vale rule `LineBreak.yml` warns:

> Hard line breaks are not supported in DITA.

## Usage

When the user asks to fix line breaks:

1. Identify the target folder or file containing AsciiDoc content
2. Find all `.adoc` files in the target location
3. Run the Ruby script against each file:
   ```bash
   ruby skills/dita-line-break/scripts/line_break.rb <file>
   ```
4. Report the number of line breaks removed

### Dry run mode

To preview changes without modifying files:

```bash
ruby skills/dita-line-break/scripts/line_break.rb <file> --dry-run
```

### Output to different file

```bash
ruby skills/dita-line-break/scripts/line_break.rb <file> -o <output.adoc>
```

### Process all files in a directory

```bash
find <folder> -name "*.adoc" -exec ruby skills/dita-line-break/scripts/line_break.rb {} \;
```

## Example invocations

- "Fix line breaks in modules/"
- "Remove hard line breaks from the getting_started folder"
- "Remove all ` +` line continuations"
- "Preview line break changes in modules/ --dry-run"

## Behavior notes

- **Joins lines**: When removing ` +` at end of line, the following line is joined with a space
- **Removes attribute**: The `:hardbreaks-option:` attribute line is removed entirely
- **Removes block option**: The `%hardbreaks` option is removed from block attribute lists
- **Skips code blocks**: Line breaks inside code blocks (---- or ....) are not modified
- **Skips comments**: Line breaks inside comment blocks (////) are not modified

## Output format

```
<file>: Removed N hard line break(s)
```

Or:

```
<file>: No hard line breaks found
```

## Extension location

The Ruby script is located at: `skills/dita-line-break/scripts/line_break.rb`

## Related Vale rule

This skill addresses the warning from: `.vale/styles/AsciiDocDITA/LineBreak.yml`
