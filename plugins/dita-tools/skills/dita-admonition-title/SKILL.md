---
name: dita-admonition-title
description: Remove or rework admonition titles for DITA compatibility. Use this skill when asked to fix admonition titles or prepare files for DITA conversion.
allowed-tools: Read, Edit, Glob
---

# Admonition title removal skill

Remove or rework admonition titles to comply with DITA requirements.

## Overview

Admonition titles (block titles on NOTE, IMPORTANT, WARNING, CAUTION, TIP admonitions) are not supported in DITA conversion. The title information must be incorporated into the admonition text itself.

## AI Action Plan

**When to use this skill**: When Vale reports `AdmonitionTitle` issues or when asked to fix admonition titles or prepare files for DITA conversion.

**Steps to follow**:

1. **Determine if the admonition title can be removed** without affecting the information in the document
   - If the title is redundant with the admonition type (e.g., `.Important information` on an `[IMPORTANT]` block), remove it
   - If the title doesn't add meaningful information, remove it

2. **If the title contains important information**:
   - Work the content of the title into the admonition text
   - Ensure the information flows naturally
   - Maintain the clarity of the admonition

3. **Remove the title line** (the line starting with `.Title`)

4. **Verify the admonition** still conveys the same information and intent

## What it detects

The Vale rule `AdmonitionTitle.yml` detects admonitions that have titles (block titles starting with `.`).

**Failure (title can be removed)**:
```asciidoc
[NOTE]
.Consideration for system updates
====
A system update sometimes requires a reboot. Make sure all important tasks can shut down gracefully.
====
```

**Correct (title removed)**:
```asciidoc
[NOTE]
====
A system update sometimes requires a reboot. Make sure all important tasks can shut down gracefully.
====
```

**Failure (title contains information)**:
```asciidoc
[IMPORTANT]
.Caring for floppy disks
====
* Put 5 inch floppies in sleeves at all times when they are not in use
* Never expose floppies to direct sunlight
* Keep all floppies far away from magnets
====
```

**Correct (information worked into text)**:
```asciidoc
[IMPORTANT]
====
Take the following steps to care for floppy disks:

* Put 5 inch floppies in sleeves at all times when they are not in use
* Never expose floppies to direct sunlight
* Keep all floppies far away from magnets
====
```

## Common scenarios

### Redundant titles

Often, admonition titles simply restate the admonition type:

- `.Note` on `[NOTE]`
- `.Important` on `[IMPORTANT]`
- `.Warning` on `[WARNING]`

These can be removed without any other changes.

### Descriptive titles

Titles that describe the context or subject:

- `.Considerations for X`
- `.About Y`
- `.Requirements for Z`

Work these into the opening sentence of the admonition.

### Instructional titles

Titles that introduce a list or steps:

- `.To avoid errors:`
- `.Follow these guidelines:`
- `.Required steps:`

Convert these into introductory sentences within the admonition.

## Usage

When the user asks to fix admonition titles:

1. Read the affected file(s)
2. Locate admonitions with titles (look for `[NOTE]`, `[IMPORTANT]`, etc. followed by a `.Title` line)
3. Determine if title can be removed or needs to be incorporated
4. Use Edit tool to remove title and/or rework admonition text
5. Report the changes made

## Example invocations

- "Fix admonition titles in modules/configuration.adoc"
- "Remove admonition titles from all modules"
- "Fix AdmonitionTitle Vale errors"

## Output format

When fixing files, report:

```
modules/configuration.adoc: Fixed 2 admonition title(s)
  Line 45: Removed redundant title "Note"
  Line 102: Incorporated title "Caring for floppy disks" into admonition text
```

## Related Vale rule

This skill addresses the error from: `.vale/styles/AsciiDocDITA/AdmonitionTitle.yml`
