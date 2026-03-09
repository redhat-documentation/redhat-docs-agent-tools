---
name: dita-assembly-contents
description: Fix text content in assemblies that appears after include directives. Use this skill when asked to fix assembly content issues or prepare assemblies for DITA conversion.
allowed-tools: Read, Edit, Glob
---

# Assembly contents fix skill

Move or reorganize text content in assemblies that appears between or after module includes.

## Overview

In DITA conversion, text content in an assembly is only supported at the start (introductory text) and in "Additional resources" sections. Text that appears between or after `include::` directives cannot be reliably processed.

## AI Action Plan

**When to use this skill**: When Vale reports `AssemblyContents` issues or when asked to fix assembly content or prepare assemblies for DITA conversion.

**Steps to follow**:

1. **Explain to the user** that no text content is allowed in an assembly file after any include directive

2. **Analyze the text content** that appears after includes:
   - Is it introductory text for a subsection?
   - Is it a "Next steps" section?
   - Is it transitional text between modules?
   - Is it "Additional resources"?

3. **Suggest moving the text**:
   - **For introductory text before a group of includes**: Move into the first included module or create a new concept module
   - **For "Next steps" sections**: Create a new module if content is self-sufficient
   - **For "Additional resources"**: Move to the start of the assembly (before any includes)
   - **For transitional text**: Consider if it belongs in the previous or next module

4. **IMPORTANT**: The user must make the final decision on where text should be moved, as this depends on the contents of the included modules before and after the text

5. **Provide PRELIMINARY suggestions only** - do not make changes without user confirmation

## What it detects

The Vale rule `AssemblyContents.yml` detects text content (headings, paragraphs, lists) that appears after any `include::` directive in an assembly file.

## Scenario 1: "Next steps" section

**Failure (text after includes)**:
```asciidoc
include::modules/example-procedure.adoc[leveloffset=+1]

== Next steps

* Optionally, configure the system further.

== Additional resources
* xref:further-configuration.adoc#further_configuration[Further configuration]
```

**Suggestion**: Create a new module for "Next steps". The user can choose to move the "Additional resources" section to this new module or keep it in the assembly.

**Alternative suggestion**: Move "Next steps" content into the `example-procedure.adoc` module.

## Scenario 2: Introductory text with subsection includes

**Failure (text between includes)**:
```asciidoc
include::modules/example-procedure.adoc[leveloffset=+1]

== Configuration reference

Refer to the following configuration details:

include::modules/example-reference1.adoc[leveloffset=+2]
include::modules/example-reference2.adoc[leveloffset=+2]
```

**Suggestion**: Move the "Configuration reference" heading and introductory text into a new concept module, or into the first reference module (`example-reference1.adoc`).

## Scenario 3: Transitional text

**Failure (text after include)**:
```asciidoc
include::modules/example-procedure.adoc[leveloffset=+1]

== Next steps

* Optionally, configure the system further.

include::modules/further-configuration-procedure.adoc[leveloffset=+1]
```

**Suggestion**: Move the "Next steps" section into the `example-procedure.adoc` module as it provides context for the next module.

## Important notes

- **Do not add `include` statements or references** (`xref:`, `link:`, `<<...>>`) to modules when suggesting changes
- **Provide assembly snippet** showing the module includes with correct `leveloffset` settings when suggesting splits
- **User must verify** the suggestion based on the actual content of the modules involved

## Usage

When the user asks to fix assembly contents:

1. Read the affected assembly file
2. Locate text content that appears after `include::` directives
3. Analyze the context and purpose of the text
4. Suggest where the text could be moved (with rationale)
5. Ask user to confirm the approach before making changes
6. If user confirms, use Edit tool to make changes
7. Report the changes made

## Example invocations

- "Fix assembly contents in assemblies/getting-started.adoc"
- "Review text after includes in assembly files"
- "Fix AssemblyContents Vale errors"

## Output format

When analyzing files, report:

```
assemblies/getting-started.adoc: Text found after includes

Line 45-52: "Next steps" section with 2 list items

Suggested approach:
1. Create a new concept module for "Next steps", OR
2. Move this content into modules/example-procedure.adoc

Please confirm which approach you prefer before I make changes.
```

## Related Vale rule

This skill addresses the error from: `.vale/styles/AsciiDocDITA/AssemblyContents.yml`
