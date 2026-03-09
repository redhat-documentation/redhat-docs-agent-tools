---
name: dita-task-duplicate
description: Merge duplicate procedure block titles (e.g., both .Verification and .Result). Use this skill when asked to fix duplicate block titles in procedures or prepare procedure files for DITA conversion.
allowed-tools: Read, Edit, Glob
---

# Task duplicate block title fix skill

Merge duplicate procedure block titles to comply with DITA procedure template.

## Overview

The procedure template allows only one block title from each group. If more than one title from the same group is present, the `TaskDuplicate` Vale issue is raised.

## AI Action Plan

**When to use this skill**: When Vale reports `TaskDuplicate` issues or when asked to fix duplicate block titles in procedures or prepare procedure files for DITA conversion.

**Steps to follow**:

1. **Determine which block titles are duplicates** by checking these groups:
   - **Prerequisites group**: `.Prerequisite`, `.Prerequisites`
   - **Procedure group**: `.Procedure` (only one allowed)
   - **Verification/Result group**: `.Verification`, `.Result`, `.Results`
   - **Troubleshooting group**: `.Troubleshooting`, `.Troubleshooting step`, `.Troubleshooting steps`
   - **Next steps group**: `.Next step`, `.Next steps`

2. **Most commonly**, the issue is `.Verification` and `.Result` (or `.Results`) both being present in the same procedure

3. **Merge the content** under the duplicate block titles:
   - Keep the content from both sections
   - Use only one of the block titles from the group
   - Preserve the logical flow of information
   - Maintain any list formatting or code blocks

4. **Choose which title to keep**:
   - For Prerequisites: Use `.Prerequisites` (plural is more common)
   - For Verification/Result: Use `.Verification` if content describes how to verify, use `.Result` if content describes expected outcomes
   - For Troubleshooting: Use `.Troubleshooting` (simplest form)
   - For Next steps: Use `.Next steps` (plural is more common)

## Supported block title groups

From the procedure template, these groups of block titles map to the same DITA element:

| Group | Allowed titles | DITA element |
|-------|----------------|--------------|
| Prerequisites | `.Prerequisite`, `.Prerequisites` | `<prereq>` |
| Procedure | `.Procedure` | `<steps>` |
| Verification/Result | `.Verification`, `.Result`, `.Results` | `<result>` |
| Troubleshooting | `.Troubleshooting`, `.Troubleshooting step`, `.Troubleshooting steps` | `<troubleshooting>` |
| Next steps | `.Next step`, `.Next steps` | `<postreq>` |

Only ONE title from each group is allowed per procedure module.

## What it detects

The Vale rule `TaskDuplicate.yml` detects when more than one block title from the same group appears in a procedure module.

**Failure (both .Verification and .Result)**:
```asciidoc
.Procedure

. Run the installer.
. Configure the settings.

.Verification

Check that the service is running:
[source,bash]
----
systemctl status myapp
----

.Result

The service should show as "active (running)".
```

**Correct (merged into .Verification)**:
```asciidoc
.Procedure

. Run the installer.
. Configure the settings.

.Verification

Check that the service is running:
[source,bash]
----
systemctl status myapp
----

The service should show as "active (running)".
```

## Why this matters

Each procedure element in DITA has a specific semantic meaning and can only appear once. Having duplicate elements would cause conversion errors or loss of content.

## Usage

When the user asks to fix duplicate block titles:

1. Read the affected procedure file(s)
2. Identify which block titles are duplicates (from the same group)
3. Determine the best single title to use
4. Merge the content under both titles
5. Use Edit tool to remove the duplicate title and merge content
6. Report the changes made

## Example invocations

- "Fix duplicate block titles in modules/installing-software.adoc"
- "Merge .Verification and .Result in procedure modules"
- "Fix TaskDuplicate Vale errors"

## Output format

When fixing files, report:

```
modules/installing-software.adoc: Merged duplicate block titles
  Removed: .Result
  Kept: .Verification
  Merged 2 paragraphs of content
```

## Related Vale rule

This skill addresses the error from: `.vale/styles/AsciiDocDITA/TaskDuplicate.yml`
