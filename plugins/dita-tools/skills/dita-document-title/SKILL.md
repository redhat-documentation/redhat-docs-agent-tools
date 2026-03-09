---
name: dita-document-title
description: Add missing document title (first-level section heading) to modules and assemblies. Use this skill when asked to fix missing titles or prepare files for DITA conversion.
allowed-tools: Read, Edit, Glob
---

# Document title addition skill

Add a missing document title (first-level section heading) to module or assembly files.

## Overview

Every module or assembly file in AsciiDoc modular documentation must have a document title, which is a first-level section heading (starting with `=`) at the very start of the file, immediately after the `id` attribute is set.

## AI Action Plan

**When to use this skill**: When Vale reports `DocumentTitle` issues or when asked to fix missing titles or prepare files for DITA conversion.

**Steps to follow**:

1. **Check if the file is a snippet**
   - Look for `:_mod-docs-content-type: SNIPPET` definition
   - If it's a snippet, titles are not required
   - Inform user that the file is marked as a snippet and ask if this is intentional
   - If intentional, suggest adding the SNIPPET content type if not present
   - If not intentional, continue to add a title

2. **Add a document title** (first-level section heading, starting with `=`) immediately after the `id` attribute setting

3. **Draft an appropriate title** based on the file content
   - For CONCEPT: Describe what the topic is about (e.g., "About X", "Understanding Y", "X overview")
   - For PROCEDURE: Use gerund form (e.g., "Installing X", "Configuring Y", "Creating Z")
   - For REFERENCE: Describe the reference content (e.g., "X configuration options", "Y API reference", "Z command reference")
   - For ASSEMBLY: Describe the collection of topics (e.g., "Getting started with X", "Managing Y")
   - Use sentence case (not title case)
   - Keep it concise (under 10 words)

4. **Ask user to verify the title** is appropriate for the content

5. **Ensure proper structure**:
   ```asciidoc
   [id="module-id"]
   = Document title

   [role="_abstract"]
   Content...
   ```

## What it detects

The Vale rule `DocumentTitle.yml` detects module or assembly files that are missing a first-level section heading at the start of the file.

**Failure (no document title)**:
```asciidoc
:_mod-docs-content-type: PROCEDURE
[id="installing-software_{context}"]

[role="_abstract"]
Install the software using the package manager.

.Procedure
...
```

**Correct (has document title)**:
```asciidoc
:_mod-docs-content-type: PROCEDURE
[id="installing-software_{context}"]
= Installing the software

[role="_abstract"]
Install the software using the package manager.

.Procedure
...
```

## Snippet files

If the file is actually a snippet (content intended for inclusion inside modules), a title is not required. In this case, the user must add a `:_mod-docs-content-type: SNIPPET` definition at the start of the file:

```asciidoc
:_mod-docs-content-type: SNIPPET

This content will be included in other modules...
```

## Why this matters

Document titles are required for:
- Proper DITA conversion (maps to `<title>` element)
- Navigation and table of contents generation
- Search engine optimization
- User orientation when reading the topic

## Usage

When the user asks to add document titles:

1. Read the affected file(s)
2. Check if `:_mod-docs-content-type: SNIPPET` is present
3. If not a snippet, check for document title (first `=` heading)
4. If missing, draft an appropriate title based on content type and file content
5. Use Edit tool to add the title after the `id` attribute
6. Ask user to verify the title is appropriate

## Example invocations

- "Add document title to modules/installing-software.adoc"
- "Fix missing title in assemblies/getting-started.adoc"
- "Add titles to all modules missing them"

## Output format

When adding titles, report:

```
modules/installing-software.adoc: Added document title
  Suggested title: "Installing the software"
  Please verify this title is appropriate for the content.
```

Or:

```
snippets/prereq-admin-access.adoc: File is marked as SNIPPET - title not required
```

## Related Vale rule

This skill addresses the error from: `.vale/styles/AsciiDocDITA/DocumentTitle.yml`
