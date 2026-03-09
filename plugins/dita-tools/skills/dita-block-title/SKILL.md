---
name: dita-block-title
description: Fix unsupported block titles for DITA compatibility. DITA only allows titles on examples, figures (images), and tables, plus fixed procedure-specific titles that map to DITA elements. Use this skill when asked to fix block titles, remediate BlockTitle warnings, or prepare files for DITA conversion.
model: claude-haiku-4-5@20251001
allowed-tools: Bash, Glob, Read, Edit, Write
---

# Block title handling skill

Handle unsupported block titles by analyzing context and converting to appropriate DITA-compatible formats.

## Overview

DITA does not support titles on arbitrary blocks. It only allows titles on three elements: `<example>`, `<fig>`, and `<table>`. These AsciiDoc block titles are therefore fully supported:

- `.Figure title` before `image::` — converts to `<fig><title>`
- `.Example title` before `====` — converts to `<example><title>`
- `.Table title` before `|===` — converts to `<table><title>`

In addition, the DITA conversion tooling recognizes fixed block titles in procedures and maps them to specific DITA elements. In **all module types**, `.Additional resources` is supported and converts to `<related-links>`. In **procedures**, the following titles are recognized:

| Block title | DITA element |
|-------------|-------------|
| `.Prerequisites` / `.Prerequisite` | `<prereq>` |
| `.Procedure` | `<steps>` or `<steps-unordered>` |
| `.Verification` / `.Results` / `.Result` | `<result>` |
| `.Troubleshooting` / `.Troubleshooting steps` / `.Troubleshooting step` | `<tasktroubleshooting>` |
| `.Next steps` / `.Next step` | `<postreq>` |

These procedure-specific titles are **skipped by this skill** (they are handled by `dita-task-title` and `dita-task-contents` instead).

All other block titles (on paragraphs, code blocks, admonitions, etc.) are not supported by DITA and must be remediated based on their context and purpose.

## AI Action Plan

**When to use this skill**: When Vale reports `BlockTitle` issues or when asked to fix block titles or prepare files for DITA conversion.

**Decision flow** - work through these in order:

1. **If the specific block title is `.Procedure` and the module's content type is NOT `procedure`**:
   - Analyze the entire module
   - Suggest either converting the module to a procedure OR splitting the procedure part into another module
   - **Do NOT proceed to other rules** - handle this case completely

2. **If the module's content type is NOT `procedure` AND the block title is a supported procedure element** (`.Prerequisites`, `.Verification`, `.Result`, `.Next steps`, etc.):
   - Analyze if the module or a part of it is actually a procedure
   - Suggest converting to procedure or splitting procedure into separate module

3. **If the block title is `.Example output`, `.Example command`, `.Example response`, or `.Example request` AND it is inside a list continuation (`+`) in a procedure**:
   - **Skip** — this is valid and maps correctly in DITA when inside a list continuation
   - These titles are only valid when preceded by `+` (list continuation) within a procedure step
   - If the list continuation is broken (missing `+`), this is an error — flag it

4. **If the block title is `.Example` or `.Examples` and it's the only block of this type**:
   - Convert content under this title into a single `[example]` block
   - Keep the `.Example` block title (it's supported for example blocks)
   - **MUST NOT add more than one example block per file**
   - **Example block MUST NOT be part of a list** (no `+` joiner)
   - If you need multiple examples, use the "proper block heading" option instead

5. **If several block titles in succession represent a list**:
   - Change to unordered list or description list
   - **EXCEPTION**: If `.Procedure` is one of the block titles, do NOT apply this fix to `.Procedure` - use specific rule for it
   - You can still apply the list fix to other block titles in the sequence

6. **If module is NOT procedure AND block title is where a subheading should be**:
   - If it would be a second level heading (`==`), convert block title to subheading
   - If it would be third level (`===`) or deeper, suggest splitting the module

7. **If module IS procedure AND block title is where a subheading should be**:
   - Suggest splitting the module (procedures cannot have subheadings)

8. **If block title is a heading to a block** (typically code block):
   - Reword heading into normal text preceding the block
   - Preserve flow of text and AsciiDoc framing
   - **Follow the "Following rule"**: If text adds a paragraph and block is in list, use `+` to join
   - Do NOT remove example content

## What it detects

The Vale rule `BlockTitle.yml` detects block titles (`.Title`) that are not attached to tables, images, or example blocks.

## Scenario 1: Procedure element in non-procedure module

**Failure (.Procedure in concept)**:
```asciidoc
:_mod-docs-content-type: CONCEPT
[id="about-configuration"]
= About configuration

Configuration allows customization of behavior.

.Procedure

. Open the configuration file.
. Modify the settings.
```

**Suggestion**: Either convert the entire module to PROCEDURE, or split the procedure part into a separate procedure module.

## Scenario 2: Single .Example block

**Failure (multiple content blocks under .Example)**:
```asciidoc
.Examples

The following example shows pipeline A:

[source,yaml]
----
apiVersion: v1
kind: Pipeline
name: pipeline-a
----

The following example shows pipeline B:

[source,yaml]
----
apiVersion: v1
kind: Pipeline
name: pipeline-b
----
```

**Correct (single example block)**:
```asciidoc
.Example
[example]
====
The following example shows pipeline A:

[source,yaml]
----
apiVersion: v1
kind: Pipeline
name: pipeline-a
----

The following example shows pipeline B:

[source,yaml]
----
apiVersion: v1
kind: Pipeline
name: pipeline-b
----
====
```

**Important**: You MUST NOT add more than one example block per file. Example blocks MUST NOT be part of lists (no `+` joiner).

## Scenario 3: Example block title inside list continuation

`.Example output`, `.Example command`, `.Example response`, and `.Example request` are valid when inside a list continuation in a procedure step.

**Valid (inside list continuation)**:
```asciidoc
.Procedure

. List etcd pods by running the following command:
+
[source,terminal]
----
$ oc -n openshift-etcd get pods -l k8s-app=etcd -o wide
----
+
.Example output
[source,terminal]
----
etcd-openshift-control-plane-0   5/5   Running   11   3h56m   192.168.10.9
etcd-openshift-control-plane-1   5/5   Running   0    3h54m   192.168.10.10
----
```

**Error (broken list continuation — missing `+` before `.Example output`)**:
```asciidoc
.Procedure

. List etcd pods by running the following command:
+
[source,terminal]
----
$ oc -n openshift-etcd get pods -l k8s-app=etcd -o wide
----

.Example output
[source,terminal]
----
etcd-openshift-control-plane-0   5/5   Running   11   3h56m   192.168.10.9
----
```

The second example is an error because the empty line after `----` breaks the list continuation. The `.Example output` title is no longer attached to the procedure step, so it cannot be mapped to a DITA task element.

## Scenario 4: Block titles forming a list

**Failure (multiple options as block titles)**:
```asciidoc
To resolve this error, use one of the following workarounds:

.For Platform 2.5:

Specify the optional key/value pair in the model secret.

.For Platform 2.4:

You can disable SSL protection when testing. Add this setting:
----
extra_settings:
  - setting: VERIFY_SSL
    value: false
----
```

**Correct (unordered list)**:
```asciidoc
To resolve this error, use one of the following workarounds:

* For Platform 2.5, specify the optional key/value pair in the model secret.

* For Platform 2.4, you can disable SSL protection when testing. Add this setting:
+
----
extra_settings:
  - setting: VERIFY_SSL
    value: false
----
```

**CAUTION**: Don't blindly convert all block titles to list. If `.Procedure` appears, apply the procedure-specific rule instead.

## Scenario 5: Block title as subheading

Sometimes a block title should be a section heading:

**Failure (should be subheading)**:
```asciidoc
= Configuring authentication

.OAuth configuration

OAuth can be configured...

.SAML configuration

SAML can be configured...
```

**Correct (second level headings)**:
```asciidoc
= Configuring authentication

== OAuth configuration

OAuth can be configured...

== SAML configuration

SAML can be configured...
```

**But if nesting would be too deep** (level 3+), split into modules instead.

## Scenario 6: Proper block heading (heading to a code block)

**Failure**:
```asciidoc
Use the `ls` command to list files.

.Example command
----
$ ls f*
----

.Example output
----
file1  file2
----
```

**Correct (reworded into text)**:
```asciidoc
Use the `ls` command to list files, as in the following example:

----
$ ls f*
----

The output of this command is:

----
file1  file2
----
```

**In a list context**:

**Failure**:
```asciidoc
. Add parameters to the `ls` command:
+
|===
|Parameter |Description
|`-l` |Long listing format
|===
+
.Example `ls` command
----
ls -l *.adoc
----
```

**Correct (paragraph joined to list)**:
```asciidoc
. Add parameters to the `ls` command:
+
|===
|Parameter |Description
|`-l` |Long listing format
|===
+
The following example shows an `ls` command using parameters:
+
----
ls -l *.adoc
----
```

## Module splitting guidance

When suggesting module splits:

1. **Do NOT add `include` statements or references** to modules
2. **Provide assembly snippet** with includes and leveloffset settings:
   ```asciidoc
   include::modules/head_module.adoc[leveloffset=+1]
   include::modules/subsection_module.adoc[leveloffset=+2]
   ```
3. **Ensure each module** has correct content type and complies with template
4. **When identifying content to split** based on procedure element, treat entire logical section as content to move (intro paragraphs, the content, associated admonitions/examples)

## Usage

When the user asks to fix block titles:

1. Read the affected file(s)
2. Locate block titles (lines starting with `.`)
3. Check if block title is attached to table, image, or example block
4. If not supported, work through decision flow
5. Determine appropriate conversion based on context
6. Use Edit tool to make changes
7. Report the changes made

## Example invocations

- "Fix block titles in modules/configuration.adoc"
- "Convert unsupported block titles"
- "Fix BlockTitle Vale errors"

## Output format

When fixing files, report:

```
modules/configuration.adoc: Fixed 3 block title(s)
  Line 45: Converted .Example to proper example block
  Line 102: Converted block titles to unordered list (2 options)
  Line 234: Reworded block title into preceding text
```

## Related Vale rule

This skill addresses the error from: `.vale/styles/AsciiDocDITA/BlockTitle.yml`
