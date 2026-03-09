---
name: dita-cross-reference
description: Informational skill for CrossReference Vale warnings. Cross-references that reference only an ID (not files) require manual review. Use this skill when asked about cross-reference issues or preparing files for DITA conversion.
allowed-tools: Read, Glob
---

# Cross-reference informational skill

Provide information about cross-reference warnings from Vale.

## Overview

This is an informational-only skill. The Vale rule `CrossReference.yml` warns about cross-references that reference only an ID rather than an AsciiDoc file. These cross-references require more work to convert to DITA, but there is a standard approach to such conversion.

## AI Action Plan

**When to use this skill**: When Vale reports `CrossReference` warnings.

**Group handling**: YES - List all CrossReference warnings together under a single heading.

**Steps to follow**:

1. **List all instances** of the CrossReference warning in the file together under a single heading

2. **Display this explanation** to the user:

   > Cross-references that reference AsciiDoc files (e.g., `xref:some-file.adoc[Link text]`) convert cleanly to DITA.
   >
   > Cross-references that reference only an ID (e.g., `xref:some-id[Link text]` or `<<some-id>>`) take more work to convert and therefore cause this warning.
   >
   > However, there is a standard approach to such conversion at this time. You can safely ignore `CrossReference` issues.

3. **Do not suggest fixes** - users can safely ignore these warnings

## What it detects

The Vale rule detects cross-references in these formats:
- `xref:id-only[Link text]`
- `<<id-only>>`
- `<<id-only,Link text>>`

These differ from file-based cross-references:
- `xref:modules/some-file.adoc[Link text]` (converts cleanly)
- `xref:assemblies/some-assembly.adoc#some-id[Link text]` (converts cleanly)

## Why this is informational only

DITA conversion tools have a standard way of handling ID-only cross-references. The warning exists to inform users that additional processing may occur during conversion, but no action is required from the writer.

## Example output

When handling CrossReference warnings, output should look like:

```
## Cross-reference warnings (informational)

The following cross-references use ID-only format:
- Line 45: xref:configuring-auth[Configuring authentication]
- Line 102: <<prerequisites>>
- Line 234: <<next-steps,Next steps>>

These warnings are informational only. Cross-references that reference only an ID (rather than a file path) take more work to convert, but there is a standard approach to such conversion. You can safely ignore these warnings.
```

## Related Vale rule

This skill addresses the warning from: `.vale/styles/AsciiDocDITA/CrossReference.yml`
