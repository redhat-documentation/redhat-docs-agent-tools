---
name: dita-task-step
description: Fix list continuations in procedure steps for DITA compatibility. Use this skill when asked to fix task steps, add list continuations, or prepare procedure files for DITA conversion.
model: claude-haiku-4-5@20251001
allowed-tools: Bash, Glob, Read, Edit, Write
---

# Task step (list continuation) skill

Fix list continuations in procedure steps for DITA compatibility.

## Overview

This skill uses the `task_step.rb` Ruby script to find procedure steps that contain multi-block content without proper list continuation markers (`+`) and adds them.

## AI Action Plan

**When to use this skill**: When Vale reports `TaskStep` issues or when asked to fix task steps, add list continuations, or prepare procedure files for DITA conversion.

**Steps to follow**:

1. **Analyze the ENTIRE content** from the error line to the next block title (e.g., `.Results`) or to the end of the file if there is no following block title. Understand if it's still part of the procedure and how to join it into the list of steps.

2. **Check for false positives**: If the error line number is inside a table definition and is an empty line between table rows, this is a false positive. Remove the empty line and any other empty lines before the table rows. Do not change the table structure or remove the block title.

3. **If content continues the list but has line breaks causing the issue**:
   - Fix the AsciiDoc list by using the `+` line break symbol on its own line
   - Detect any valid breaks in the AsciiDoc list and fix them

4. **If content has conceptual subtitles** (e.g., bold text like `*Subtitle*`) and lists actions under them:
   - Convert these subtitles into an unordered list of substeps
   - Or use an ordered list if they have numbers
   - Ensure substeps are properly joined to the main step using `+`

5. **If content continues the procedure conceptually but isn't formatted as steps/substeps**:
   - Attempt to reformat it into steps and substeps as necessary
   - Ensure they are joined to the existing ordered or unordered AsciiDoc list of steps
   - Use the `+` line break symbol on its own line
   - Use AsciiDoc open block (bounded by `--` lines) if needed for complex formatting

6. **CRITICAL**: After joining content into a single list of steps, check if the resulting list has only one top-level step. If it does, you MUST make that list unordered (using `*`) to comply with the procedure template.

7. **If content does not continue the procedure conceptually**:
   - Use one of the supported block titles from the procedure template (`.Result`, `.Verification`, `.Next steps`, etc.)
   - **IMPORTANT**: If the new section starts with an admonition (NOTE, WARNING, etc.), add a short phrase describing the result before the admonition

## What it detects

The Vale rule `TaskStep.yml` detects content in procedure modules that appears after steps but is not properly attached to a step using the list continuation marker (`+`).

## List continuations explained

In AsciiDoc, a list continuation marker (`+` on its own line) attaches a block to the preceding list item. Without it, the block is not part of the list item.

See: https://docs.asciidoctor.org/asciidoc/latest/lists/continuation/

## What it fixes

### Missing continuation before code blocks

**Before:**
```asciidoc
.Procedure

. Run the following command:

[source,bash]
----
oc get pods
----

. Check the output.
```

**After:**
```asciidoc
.Procedure

. Run the following command:
+
[source,bash]
----
oc get pods
----

. Check the output.
```

### Missing continuation before paragraphs

**Before:**
```asciidoc
.Procedure

. Configure the settings.

The configuration file is located at `/etc/myapp/config.yaml`.

. Restart the service.
```

**After:**
```asciidoc
.Procedure

. Configure the settings.
+
The configuration file is located at `/etc/myapp/config.yaml`.

. Restart the service.
```

### Missing continuation before admonitions

**Before:**
```asciidoc
.Procedure

. Run the installer.

[NOTE]
====
The installation may take several minutes.
====

. Verify the installation.
```

**After:**
```asciidoc
.Procedure

. Run the installer.
+
[NOTE]
====
The installation may take several minutes.
====

. Verify the installation.
```

## Usage

When the user asks to fix list continuations:

1. Identify the target folder or file containing AsciiDoc content
2. Find procedure modules (files with `:_mod-docs-content-type: PROCEDURE`)
3. Run the Ruby script against each file:
   ```bash
   ruby skills/dita-task-step/scripts/task_step.rb <file>
   ```
4. Report the changes made

### Dry run mode

To preview changes without modifying files:

```bash
ruby skills/dita-task-step/scripts/task_step.rb <file> --dry-run
```

### Output to different file

```bash
ruby skills/dita-task-step/scripts/task_step.rb <file> -o <output.adoc>
```

### Process all files in a directory

```bash
find <folder> -name "*.adoc" -exec ruby skills/dita-task-step/scripts/task_step.rb {} \;
```

## Example invocations

- "Fix list continuations in modules/"
- "Add missing + markers to procedure steps"
- "Fix task steps in the getting_started folder"
- "Preview list continuation changes in modules/ --dry-run"

## Behavior notes

- **Only processes procedures**: Files without `:_mod-docs-content-type: PROCEDURE` are skipped
- **Only in Procedure section**: Only content within the `.Procedure` section is processed
- **Detects orphan content**: Paragraphs, code blocks, admonitions, and other blocks after steps are detected
- **Adds + markers**: The list continuation marker is inserted on a line by itself
- **Preserves existing continuations**: Existing `+` markers are not duplicated
- **Handles nested lists**: Nested list items are properly handled

## Output format

```
<file>: Added N list continuation(s)
```

Or:

```
<file>: No missing list continuations found
```

Or:

```
<file>: Not a procedure module (skipped)
```

## Extension location

The Ruby script is located at: `skills/dita-task-step/scripts/task_step.rb`

## Related Vale rule

This skill addresses the warning from: `.vale/styles/AsciiDocDITA/TaskStep.yml`
