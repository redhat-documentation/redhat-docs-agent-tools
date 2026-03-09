---
name: dita-author-line
description: Add a blank line after document title to prevent author line interpretation. Use this skill when asked to fix author line issues or prepare files for DITA conversion.
allowed-tools: Read, Edit, Glob
---

# Author line fix skill

Add a blank line after the document title to prevent AsciiDoc from interpreting the following line as an author line.

## Overview

In AsciiDoc, a non-blank line immediately following a document title (level 0 heading) is interpreted as the author line. The DITA conversion process does not support author lines, and in modular documentation, real author lines are never used.

## AI Action Plan

**When to use this skill**: When Vale reports `AuthorLine` issues or when asked to fix author line problems or prepare files for DITA conversion.

**Steps to follow**:

1. **Locate the document title** (level 0 heading starting with `=`)

2. **Check if there's a blank line** after the document title
   - If there is already a blank line, the file is correct (this shouldn't trigger the Vale rule)
   - If there is NO blank line, continue to step 3

3. **Add a blank line** immediately after the document title

4. **Verify the fix** by checking that the structure now looks like:
   ```asciidoc
   [id="module-id"]
   = Document title

   [role="_abstract"]
   First paragraph or content...
   ```

## What it detects

The Vale rule `AuthorLine.yml` detects when there is no blank line between a document title and the text that follows it.

**Failure (no blank line after title)**:
```asciidoc
:_mod-docs-content-type: CONCEPT
[id="about-optimization_{context}"]
= About optimization
As AI applications mature...
```

**Correct (blank line after title)**:
```asciidoc
:_mod-docs-content-type: CONCEPT
[id="about-optimization_{context}"]
= About optimization

As AI applications mature...
```

## Why this matters

AsciiDoc interprets a non-blank line immediately following a document title as the author line. Since the DITA conversion process does not support author lines and modular documentation never uses them, this indicates that the writer simply forgot to add a blank line after the title.

## Usage

When the user asks to fix author line issues:

1. Read the affected file(s)
2. Locate the document title (first level heading: `= Title`)
3. Check if a blank line exists after the title
4. If not, use the Edit tool to add a blank line
5. Report the changes made

## Example invocations

- "Fix author line issue in modules/about-optimization.adoc"
- "Add blank line after title in all modules/"
- "Fix AuthorLine Vale errors"

## Output format

When fixing files, report:

```
modules/about-optimization.adoc: Added blank line after document title
  Title: "About optimization"
```

Or:

```
modules/about-optimization.adoc: Blank line already exists after title
```

## Related Vale rule

This skill addresses the error from: `.vale/styles/AsciiDocDITA/AuthorLine.yml`
