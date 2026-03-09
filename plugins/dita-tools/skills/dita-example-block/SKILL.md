---
name: dita-example-block
description: Convert example blocks to normal text or code blocks for DITA compatibility. Handles both ExampleBlock and TaskExample Vale issues. Use this skill when asked to fix example blocks or prepare files for DITA conversion.
allowed-tools: Read, Edit, Glob
---

# Example block conversion skill

Convert example blocks (`====` delimiters) to normal text, code blocks, or properly formatted examples for DITA compatibility.

## Overview

Example blocks in the main body of modules can usually be converted to normal text or, when they represent code or commands, to code blocks. In procedures (tasks), only one example block is allowed and it must not be part of a step.

## AI Action Plan

**When to use this skill**: When Vale reports `ExampleBlock` or `TaskExample` issues or when asked to fix example blocks or prepare files for DITA conversion.

**Steps to follow for general modules (ExampleBlock)**:

1. **Analyze the example block** and determine its purpose:
   - Is it showing example code/commands? → Convert to code block (`----`)
   - Is it showing example text/output? → Convert to normal paragraphs
   - Does it contain multiple examples? → Keep as example block if it's the only one

2. **Check if preceding text mentions an example**:
   - If not, modify the preceding text to make it clear, e.g., "as in the following example:"
   - Maintain proper text flow

3. **Handle the block title** (if present):
   - If title is redundant (e.g., "Example of" restating previous paragraph), remove it
   - If title contains additional information, work it into the preceding text

**Steps to follow for procedures (TaskExample)**:

1. **Understand the constraint**: Only ONE example block is allowed in a procedure, and it must NOT be part of a step

2. **Analyze extra example blocks**:
   - Are they inside procedure steps? → Must be converted
   - Do they use `====` delimiters but should be code blocks? → Change to `----`
   - Are they actually examples or just misformatted code?

3. **For example blocks within steps**:
   - If it's code/commands, change `====` to `----` (code block delimiters) at both start and end
   - If it's part of a step, ensure it's joined using `+` on its own line
   - Convert content to normal text or code blocks as appropriate

4. **Update preceding text** if needed to introduce the example

5. **Handle block titles**: Remove or incorporate into preceding text

## What it detects

**ExampleBlock.yml**: Detects example blocks in non-procedure modules that should be converted to other formats.

**TaskExample.yml**: Detects multiple example blocks or example blocks within steps in procedure modules.

## General module example conversion

**Failure (example block with code)**:
```asciidoc
.Example configuration

====
[source,yaml]
----
apiVersion: v1
kind: Pod
----
====
```

**Correct (code block)**:
```asciidoc
The following example shows a configuration:

[source,yaml]
----
apiVersion: v1
kind: Pod
----
```

## Procedure example conversion

**Failure (example block in step using `====`)**:
```asciidoc
.Procedure

. Run the following command:
+
====
[source,bash]
----
oc get pods
----
====
```

**Correct (code block in step using `----`)**:
```asciidoc
.Procedure

. Run the following command:
+
[source,bash]
----
oc get pods
----
```

**Failure (multiple examples in procedure)**:
```asciidoc
.Procedure

. Configure the first setting:
+
.Example configuration 1
====
Set value to 10
====

. Configure the second setting:
+
.Example configuration 2
====
Set value to 20
====
```

**Correct (converted to normal text)**:
```asciidoc
.Procedure

. Configure the first setting to 10.

. Configure the second setting to 20.
```

## Wrong delimiter detection

Sometimes `====` is used when `----` is intended:

**Failure**:
```asciidoc
. Review the output:
+
====
$ oc get pods
NAME    READY   STATUS
pod-1   1/1     Running
====
```

**Correct**:
```asciidoc
. Review the output:
+
----
$ oc get pods
NAME    READY   STATUS
pod-1   1/1     Running
----
```

## Usage

When the user asks to fix example blocks:

1. Read the affected file(s)
2. Determine if it's a procedure or general module
3. Locate example blocks (lines with `====`)
4. Analyze each example block's purpose
5. For procedures: Check if example is in a step or if there are multiple examples
6. Convert to appropriate format (code block, normal text, or single example block)
7. Use Edit tool to make changes
8. Report the changes made

## Example invocations

- "Fix example blocks in modules/configuration.adoc"
- "Convert example blocks to code blocks in procedure files"
- "Fix ExampleBlock and TaskExample Vale errors"

## Output format

When fixing files, report:

```
modules/configuration.adoc: Converted 2 example block(s)
  Line 45: Changed example block to code block (used wrong delimiters)
  Line 102: Converted example block to normal paragraphs

modules/installing-software.adoc: Fixed example blocks in procedure
  Line 67: Changed `====` to `----` delimiters for code block in step
  Line 89: Converted example block to normal text in step
```

## Related Vale rules

This skill addresses errors from:
- `.vale/styles/AsciiDocDITA/ExampleBlock.yml`
- `.vale/styles/AsciiDocDITA/TaskExample.yml`
