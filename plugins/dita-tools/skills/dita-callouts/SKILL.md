---
name: dita-callouts
description: Transform callouts in AsciiDoc source blocks to prepare for DITA conversion. Use this skill when asked to transform, convert, or fix callouts in AsciiDoc files or folders.
model: claude-haiku-4-5@20251001
allowed-tools: Bash, Glob, Read, Edit, Write
---

# Callout transform skill

Transform callout usage in AsciiDoc source blocks following Red Hat documentation guidelines.

## Overview

This skill transforms AsciiDoc files with callout markers in source blocks to use the three approved Red Hat documentation formats:

1. **Simple sentence** - For single command or line explanations
2. **Definition list** - For multiple parameters, placeholders, or user-replaced values
3. **Bulleted list** - For YAML structure explanations or multiple related lines

**IMPORTANT**: Inline comments within code blocks (especially YAML) are NOT supported and should never be used. Callouts in YAML create invalid syntax because `#` is treated as a comment marker.

## Usage

When the user asks to transform callouts:

1. Identify the target folder or file containing AsciiDoc content
2. Find all `.adoc` files in the target location
3. Run the Ruby script with the appropriate mode:

   **Auto mode (recommended)**: Intelligently chooses the best format
   ```bash
   ruby skills/dita-callouts/scripts/callouts.rb <file> --auto
   ```

   **Simple sentence mode**: For single callout
   ```bash
   ruby skills/dita-callouts/scripts/callouts.rb <file> --simple-sentence
   ```

   **Definition list mode**: For multiple parameters/placeholders
   ```bash
   ruby skills/dita-callouts/scripts/callouts.rb <file> --definition-list
   ```

   **Bulleted list mode**: For YAML structures
   ```bash
   ruby skills/dita-callouts/scripts/callouts.rb <file> --bulleted-list
   ```

4. Review the output and refine explanations as needed
5. Report the updated files and/or any errors found

## Command options

```
ruby callouts.rb <file.adoc> [OPTIONS]

Options:
  --auto                 Automatically choose the best format (default)
  --simple-sentence      Convert to simple sentence explanation
  --definition-list      Convert to definition list with "where:"
  --bulleted-list        Convert to bulleted list for structures
  --dry-run              Show what would be changed without modifying files
  -o <file>              Write output to specified file instead of modifying in place
```

## Transformation modes

### 1. Definition List (--definition-list) — DEFAULT

**When to use**: All callout transformations. This is the default `--auto` mode.

The "where:" + definition list format maintains the connection between code lines and their explanations. It works for single and multiple callouts, YAML and non-YAML, placeholders and literal values.

**Guidelines:**
- Introduce with "where:"
- Use the full code line content as the definition list term (wrapped in backticks)
- Use AsciiDoc `::` definition list syntax
- List explanations in order they appear
- Use the original callout text as the description

**Before (multiple placeholders):**
```asciidoc
[source,yaml]
----
metadata:
  name: <my_product_database> <1>
stringData:
  postgres-ca.pem: |-
    -----BEGIN CERTIFICATE-----
    <ca_certificate_key> <2>
  postgres-key.key: |-
    -----BEGIN CERTIFICATE-----
    <tls_private_key> <3>
----
<1> The database name
<2> The CA certificate key
<3> The TLS private key
```

**After:**
```asciidoc
[source,yaml]
----
metadata:
  name: <my_product_database>
stringData:
  postgres-ca.pem: |-
    -----BEGIN CERTIFICATE-----
    <ca_certificate_key>
  postgres-key.key: |-
    -----BEGIN CERTIFICATE-----
    <tls_private_key>
----

where:

`name: <my_product_database>`:: The database name.

`<ca_certificate_key>`:: The CA certificate key.

`<tls_private_key>`:: The TLS private key.
```

**Before (literal values):**
```asciidoc
[source,terminal]
----
cgu.id 36 <1>
fw.cgu 8032.16973825.6021 <2>
----
<1> CGU hardware revision number
<2> The DPLL firmware version running in the CGU
```

**After:**
```asciidoc
[source,terminal]
----
cgu.id 36
fw.cgu 8032.16973825.6021
----

where:

`cgu.id 36`:: CGU hardware revision number.

`fw.cgu 8032.16973825.6021`:: The DPLL firmware version running in the CGU.
```

**Before (single callout):**
```asciidoc
[source,yaml]
----
ublxCmds:
  - args:
      - "-z"
      - "CFG-TP-ANT_CABLEDELAY,<antenna_delay_offset>" <1>
    reportOutput: false
----
<1> Measured T-GM antenna delay offset in nanoseconds.
```

**After:**
```asciidoc
[source,yaml]
----
ublxCmds:
  - args:
      - "-z"
      - "CFG-TP-ANT_CABLEDELAY,<antenna_delay_offset>"
    reportOutput: false
----

where:

`"CFG-TP-ANT_CABLEDELAY,<antenna_delay_offset>"`:: Measured T-GM antenna delay offset in nanoseconds.
```

### 2. Simple Sentence (--simple-sentence)

**When to use**: Only when explicitly requested. For a single command or line explanation where a definition list is not needed.

**Before:**
```asciidoc
[source,bash]
----
$ hcp create cluster aws --help <1>
----
<1> Displays help for the aws platform
```

**After:**
```asciidoc
[source,bash]
----
$ hcp create cluster aws --help
----

Use the `hcp create cluster` command to create and manage hosted clusters. The supported platforms are `aws`, `agent`, and `kubevirt`.
```

### 3. Bulleted List (--bulleted-list)

**When to use**: Only when explicitly requested. For YAML structure explanations using dot-notation paths.

**Guidelines:**
- Use dot notation for nested structures (e.g., `spec.workspaces`)
- Use parallel sentence structure: all bullets use third-person declarative verbs (e.g., "defines", "specifies", "configures") — imperative forms like "define" are automatically normalized to "defines"

**Before:**
```asciidoc
[source,yaml]
----
spec:
  workspaces: <1>
  - name: shared-workspace
  tasks: <2>
  - name: build-image
    taskRef:
      resolver: cluster <3>
----
<1> Defines pipeline workspaces
<2> Defines the tasks used
<3> References a cluster task
```

**After:**
```asciidoc
[source,yaml]
----
spec:
  workspaces:
  - name: shared-workspace
  tasks:
  - name: build-image
    taskRef:
      resolver: cluster
----

- `spec.workspaces` defines the list of pipeline workspaces shared between tasks. A pipeline can define as many workspaces as required.
- `spec.tasks` defines the tasks used in the pipeline. This example defines two tasks: `build-image` and `apply-manifests`.
- `spec.tasks.taskRef.resolver` references a cluster-scoped task resource.
```

## Auto mode selection logic

The `--auto` mode always selects **definition list** format. This ensures consistent output that maintains the connection between code lines and their explanations.

The `--simple-sentence` and `--bulleted-list` modes are available via explicit flags when a different format is specifically needed.

## Why inline comments are deprecated

**CRITICAL**: The old `--add-inline-comments` mode is NO LONGER SUPPORTED because:

1. **YAML syntax violation**: `#` creates comments, making the code unparseable
2. **Red Hat style guide**: Explicitly prohibits inline comments in code blocks
3. **DITA conversion**: Inline comments cannot be properly converted

## Style guide reference

These transformations follow the Red Hat supplementary style guide:
- https://redhat-documentation.github.io/supplementary-style-guide/#explain-commands-variables-in-code-blocks

## Example invocations

- "Transform callouts in modules/getting_started/ using auto mode"
- "Convert callout usage in the assemblies folder to definition lists"
- "Fix callouts in modules/inference-rhaiis.adoc for DITA conversion"
- "Transform YAML callouts to bulleted list format"

## Output format

Issues are reported in a parseable format:
```
<file>:<line>: <TYPE>: <message>
```

Where TYPE is one of:
- `ERROR`: Critical issue that must be fixed
- `WARNING`: Issue that should be reviewed

## Extension location

The Ruby script is located at: `skills/dita-callouts/scripts/callouts.rb`
