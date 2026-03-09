---
name: dita-content-type
description: Add or update :_mod-docs-content-type: attribute in AsciiDoc files. Detects content type (CONCEPT, PROCEDURE, ASSEMBLY, SNIPPET) from file structure and adds the attribute if missing. Use this skill when asked to add content types, fix module types, or prepare files for DITA conversion.
model: claude-haiku-4-5@20251001
allowed-tools: Bash, Glob, Read, Edit, Write
---

# Content type detection and addition skill

Detect and add the missing `:_mod-docs-content-type:` attribute to AsciiDoc modules and assemblies.

## Overview

Every AsciiDoc assembly or module must have a content type defined as the `:_mod-docs-content-type:` attribute close to the start of the file, ideally on the first line.

## AI Action Plan

**When to use this skill**: When Vale reports `ContentType` issues or when asked to add content types or prepare files for DITA conversion.

**Steps to follow**:

1. **In all cases**, display an explanation that includes a link to the AsciiDoc DITA Toolkit for bulk content type addition: https://github.com/rheslop/asciidoc-dita-toolkit/tree/main

2. **Attempt to determine the content type** based on file analysis:
   - Look at the title and content
   - Check for procedure steps → PROCEDURE
   - Check for explanatory/conceptual content → CONCEPT
   - Check for tables/lists of options/commands → REFERENCE
   - Check for multiple `include::` directives → ASSEMBLY
   - Check if file is just reusable snippets → SNIPPET

3. **If you can determine the content type**, add the content type definition at the start of the file (first line)

4. **If the content type is PROCEDURE**, you MUST immediately perform a full structural validation:
   - **Proactively check** for potential TaskStep or TaskSection violations
   - **Verify** the procedure has `.Procedure` block title
   - **Verify** the procedure has a short description `[role="_abstract"]`
   - **Check** for nested sections (not allowed in procedures)
   - **Suggest all necessary fixes** in a single response
   - If introduction is missing, draft one (explain what user will accomplish, no "This procedure describes..." phrasing)

5. **If uncertain about content type**, suggest the most likely type and ask user to confirm

## Supported content types

Use UPPERCASE for the content type value:

- `CONCEPT` - Explains what something is, why it matters, background information
- `PROCEDURE` - Step-by-step instructions for completing a task
- `REFERENCE` - Lookup information (tables, options, commands, API details)
- `ASSEMBLY` - Combines modules into a complete topic
- `SNIPPET` - Reusable content fragments (not standalone topics)

## Alternative attribute names

Some files may use older attributes with the same meaning:
- `:_content_type:` (older)
- `:_module_type:` (older)

Never recommend these for new additions, but if they already exist, you don't need to replace them.

## Content type determination guidelines

### CONCEPT indicators:
- Explains "what is X" or "why use Y"
- Contains background, theory, or explanatory information
- Title patterns: "About X", "Understanding Y", "X overview"
- No step-by-step instructions

### PROCEDURE indicators:
- Contains numbered or bulleted steps
- Tells user to do something
- Title patterns: "Installing X", "Configuring Y", "Creating Z" (gerund form)
- Has `.Procedure` block title or should have one

### REFERENCE indicators:
- Contains tables of options, parameters, commands
- Lists API endpoints, configuration files, environment variables
- Title patterns: "X command reference", "Y configuration options", "Z API"
- Primarily lookup/reference information

### ASSEMBLY indicators:
- Multiple `include::` directives (3 or more typically)
- Organizes other modules into a topic
- Filename often contains "assembly"
- Title patterns: "Getting started with X", "Managing Y"

### SNIPPET indicators:
- Content is incomplete or fragment-like
- Meant to be included in other modules
- No proper document structure (may lack title)
- Filename often contains "snippet" or is in snippets/ directory

## What it detects

The Vale rule `ContentType.yml` detects files missing the `:_mod-docs-content-type:` attribute.

**Failure (no content type)**:
```asciidoc
[id="installing-software_{context}"]
= Installing the software

[role="_abstract"]
Install the software using the package manager.

.Procedure

. Download the package.
. Run the installer.
```

**Correct (has content type)**:
```asciidoc
:_mod-docs-content-type: PROCEDURE

[id="installing-software_{context}"]
= Installing the software

[role="_abstract"]
Install the software using the package manager.

.Procedure

. Download the package.
. Run the installer.
```

## CRITICAL: Procedure validation requirement

When the content type is PROCEDURE, you MUST also perform complete structural validation:

1. **Check for `.Procedure` block title** - if missing, add it
2. **Check for short description** - if missing, draft one
3. **Check for nested sections** - procedures cannot have subheadings
4. **Check procedure steps** - ensure they form a single list
5. **Provide all fixes together** in one response

**Example of complete procedure fix**:

Before:
```asciidoc
[id="installing-software_{context}"]
= Installing the software

. Download the package.
. Run the installer.
```

After (all fixes applied):
```asciidoc
:_mod-docs-content-type: PROCEDURE

[id="installing-software_{context}"]
= Installing the software

[role="_abstract"]
Install the software to enable application deployment.

.Procedure

. Download the package.
. Run the installer.
```

## Usage

When the user asks to add content types:

1. Read the affected file(s)
2. Analyze file content to determine appropriate content type
3. Check for existing content type attributes (including older variants)
4. If no content type exists, add `:_mod-docs-content-type: <TYPE>` at the first line
5. **If type is PROCEDURE**: Immediately validate and fix structure
6. Use Edit tool to add the attribute and any necessary structural fixes
7. Report the changes made and ask user to verify

## Example invocations

- "Add content type to modules/installing-software.adoc"
- "Detect and add content types to all modules/"
- "Fix ContentType Vale errors"

## Output format

When adding content types, report:

```
modules/installing-software.adoc: Added content type
  Type: PROCEDURE
  Also fixed:
  - Added [role="_abstract"] short description
  - Added .Procedure block title
  - Drafted introduction: "Install the software to enable application deployment."

  Please verify the introduction is appropriate for this procedure.
```

Or for bulk toolkit recommendation:

```
Found 25 files missing content types.

For working out content types for many files at once, consider using the AsciiDoc DITA Toolkit:
https://github.com/rheslop/asciidoc-dita-toolkit/tree/main

Would you like me to analyze individual files and suggest content types?
```

## Related Vale rule

This skill addresses the error from: `.vale/styles/AsciiDocDITA/ContentType.yml`
