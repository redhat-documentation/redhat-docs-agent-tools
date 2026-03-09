---
name: dita-short-description
description: Add missing [role="_abstract"] attribute to AsciiDoc files for DITA short description support. Use this skill when asked to add abstracts, fix short descriptions, rewrite short descriptions, or prepare files for DITA conversion.
model: claude-haiku-4-5-20251001
allowed-tools: Bash, Glob, Read, Edit, Write
---

# Short description (abstract) skill

Add missing `[role="_abstract"]` attributes to AsciiDoc files and help write effective short descriptions for DITA compatibility.

## Overview

This skill uses the `short_description.rb` Ruby script to find AsciiDoc files missing the `[role="_abstract"]` attribute and automatically adds it before the first paragraph after the document title. When requested, it can also help rewrite or create more effective short descriptions.

**The short description is the first paragraph and cannot be more than a single paragraph.**

## What it does

For a file like this:

```asciidoc
:_mod-docs-content-type: CONCEPT
[id="about-optimization_{context}"]
= About optimization

As AI applications mature and new compression algorithms are published...

More content here...
```

The script adds the missing abstract role:

```asciidoc
:_mod-docs-content-type: CONCEPT
[id="about-optimization_{context}"]
= About optimization

[role="_abstract"]
As AI applications mature and new compression algorithms are published...

More content here...
```

## AI Action Plan

**When to use this skill**: When Vale reports `ShortDescription` issues or when asked to add abstracts, fix short descriptions, or prepare files for DITA conversion.

**Steps to follow**:

1. **Scan**: Run the script to add `[role="_abstract"]` and identify quality issues.
2. **Tag**: The script adds `[role="_abstract"]` before the first paragraph after the title.
3. **Analyze & Rewrite**: If the script reports `NEEDS REWRITE`:
   - Read the file content and check the `:_mod-docs-content-type:`
   - Rewrite the paragraph using the "Rewrite for Impact" guidelines below
   - Ensure the `[role="_abstract"]` attribute remains above the new paragraph
4. **If no suitable paragraph exists**, draft a new summarizing paragraph based on the module content:
   - For CONCEPT topics: Start with a brief definition if the term is unfamiliar, then explain value and purpose
   - For PROCEDURE topics: Explain what the task does, its benefits/purpose, and when or why to perform it
   - For REFERENCE topics: Describe what the items are, what they do, and what they're used for
   - Keep it standalone, concise (1-2 sentences, under 50 words), and complete
   - Don't repeat the title, state the obvious, or use "this topic..." phrasing
5. **Review the drafted short description** to ensure it's clear, useful, and follows Red Hat style guidelines.

## Rewrite for Impact

The script flags paragraphs that need rewriting. When `NEEDS REWRITE` appears in the output, fix these issues:

1. **No Lead-ins**: Remove "This topic covers", "In this section", "This procedure describes", etc.
2. **Concise**: Maximum 50 words.
3. **Standalone**: Must be meaningful in search results and hover text.
4. **Information Type Logic**:
   - **CONCEPT**: Answer "What is this?" and "Why do I care?" Start with a definition.
   - **PROCEDURE/TASK**: Answer "What is the benefit?" and "Why is this necessary?" Focus on the goal.
   - **REFERENCE**: Identify the items and their primary usage.

### Example rewrite

- **Initial**: "This procedure describes how to install the secondary scheduler."
- **Improved**: "Installing the secondary scheduler enables NUMA-aware pod placement, optimizing performance for high-throughput workloads by reducing memory latency."

## Why this matters

The `[role="_abstract"]` attribute marks a paragraph as the short description (`<shortdesc>`) element in DITA output. This is required by the AsciiDocDITA Vale rule `ShortDescription.yml` which warns:

> Assign [role="_abstract"] to a paragraph to use it as `<shortdesc>` in DITA.

## Writing effective short descriptions

Short descriptions give a concise summary of a topic's purpose or main point. They are used as the first paragraph in outputs, as link preview text, and as subordinate topic previews. A well-written short description helps readers decide whether to open a topic and improves usability and search.

### General rules

- **Keep it standalone, concise, and complete.** Don't rely on the surrounding topic for meaning.
- **One or two sentences, under 50 words.**
- **Use complete sentences.** Avoid fragments except for very short API references.
- **Don't repeat the title**, state the obvious, start with "this topic…," or treat it as a lead-in sentence.

### Writing tips

- Focus on clarity and utility.
- If you can't fit a clear summary within ~50 words, the topic may be too complex and could need splitting.
- Including a short description encourages topic clarity and improves navigation and search results.

### CONCEPT topic examples

Concept topics answer "what is this?" and "why should I care?" Start with a brief definition if the term is unfamiliar. Make the main point clear.

**Poor (repeats title, lead-in style):**
```asciidoc
= About model optimization

[role="_abstract"]
This topic explains about model optimization.
```

**Good (standalone, explains value):**
```asciidoc
= About model optimization

[role="_abstract"]
Model optimization reduces neural network size and inference time through techniques like quantization and pruning, enabling AI applications to run efficiently on resource-constrained devices without significant accuracy loss.
```

### PROCEDURE topic examples

Procedure topics explain what the task does, its benefits or purpose, and when or why the user should perform it. Include who performs the task if relevant.

**Poor (states the obvious):**
```asciidoc
= Configuring authentication

[role="_abstract"]
Follow these steps to configure authentication.
```

**Good (explains purpose and benefit):**
```asciidoc
= Configuring authentication

[role="_abstract"]
Configure LDAP authentication to enable single sign-on for your organization, allowing users to access the application with their existing corporate credentials.
```

**Good (includes who and when):**
```asciidoc
= Rotating encryption keys

[role="_abstract"]
Cluster administrators should rotate encryption keys annually or immediately after a security incident to maintain compliance and protect sensitive data at rest.
```

### REFERENCE topic examples

Reference topics describe what the items are, what they do, and what they're used for. Use consistent phrasing across topics.

**Poor (vague, no context):**
```asciidoc
= Configuration parameters

[role="_abstract"]
The following table lists configuration parameters.
```

**Good (describes purpose and usage):**
```asciidoc
= Configuration parameters

[role="_abstract"]
The following configuration parameters control memory allocation, connection pooling, and timeout behavior for the database driver. Set these values in the `application.properties` file before starting the server.
```

**Good (consistent reference style):**
```asciidoc
= Environment variables for the CLI

[role="_abstract"]
Use the following environment variables to configure authentication, output format, and logging behavior when running commands non-interactively or in CI/CD pipelines.
```

## Usage

When the user asks to add abstract role or short descriptions:

1. Identify the target folder or file containing AsciiDoc content
2. Find all `.adoc` files in the target location
3. Run the Ruby script against each file:
   ```bash
   ruby skills/dita-short-description/scripts/short_description.rb <file>
   ```
4. Report which files were updated

### Process all files in a directory

```bash
find <folder> -name "*.adoc" -exec ruby skills/dita-short-description/scripts/short_description.rb {} \;
```

## Example invocations

- "Add abstract role to files in modules/ and update poorly written short descriptions"
- "Fix missing short descriptions in the getting_started folder"
- "Add [role="_abstract"] to all AsciiDoc files"
- "Preview abstract changes in modules/ --dry-run"

## Behavior notes

- **Skips assembly files**: Files with `:_mod-docs-content-type: ASSEMBLY` are skipped (assemblies use a different structure)
- **Skips snippet files**: Files with `:_mod-docs-content-type: SNIPPET` are skipped
- **Skips files with existing abstracts**: If `[role="_abstract"]` already exists, no changes are made
- **Finds first paragraph**: The script locates the first regular paragraph after the title, skipping:
  - Empty lines
  - Attribute definitions
  - Attribute lists
  - Conditionals (ifdef/ifndef/endif)
  - Section headings
  - List items
  - Include directives
  - Admonition blocks

## Output format

When an abstract is added successfully:
```
<file>: Added [role="_abstract"] before line N
```

When an abstract is added but needs rewriting:
```
<file>: Added [role="_abstract"] before line N - NEEDS REWRITE: Starts with prohibited lead-in
<file>: Added [role="_abstract"] before line N - NEEDS REWRITE: Too long (65 words)
<file>: Added [role="_abstract"] before line N - NEEDS REWRITE: Starts with prohibited lead-in, Too long (65 words)
```

When using `--dry-run`:
```
<file>: Would add [role="_abstract"] before line N
<file>: Would add [role="_abstract"] before line N - NEEDS REWRITE: Too long (55 words)
```

When no changes needed:
```
<file>: Abstract already exists
```

```
<file>: Assembly or snippet file (skipped)
```

```
<file>: No document title found
```

```
<file>: No paragraph found after title
```

## Extension location

The Ruby script is located at: `skills/dita-short-description/scripts/short_description.rb`

## Related Vale rule

This skill addresses the warning from: `.vale/styles/AsciiDocDITA/ShortDescription.yml`
