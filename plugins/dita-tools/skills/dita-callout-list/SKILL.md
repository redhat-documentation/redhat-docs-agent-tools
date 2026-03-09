---
name: dita-callout-list
description: Replace callout lists with description lists or bullet lists for DITA compatibility. Use this skill when asked to fix callouts or prepare files for DITA conversion.
allowed-tools: Read, Edit, Glob
---

# Callout list replacement skill

Replace callout lists with DITA-compatible description lists or bullet lists.

## Overview

Callout lists (numbered annotations in code blocks with explanatory lists below) are not supported in DITA conversion. They must be replaced with user-replaceable placeholders and description lists, or with bullet lists for code structure explanations.

## AI Action Plan

**When to use this skill**: When Vale reports `CalloutList` issues or when asked to fix callouts or prepare files for DITA conversion.

**Steps to follow**:

1. **Analyze the callouts** to determine their purpose:
   - Do they denote **values** that users should replace? (Most common)
   - Do they denote **blocks or structures** in the code?

2. **For value callouts** (most typical case):
   - Replace callouts like `value <1>` in the code block with user-replaceable placeholders in angled brackets: `<value>`
   - Convert the callout list to a description list using the format:
     ```asciidoc
     `<placeholder>`:: Explains what this value is
     ```
   - Use "where:" or similar introductory text before the description list

3. **For code structure callouts**:
   - Remove the callouts from the code
   - List the structures in a bulleted list under the code block
   - Use notation like `spec.workspaces` to reference the code structure

4. **Ensure placeholders are descriptive**:
   - Use snake_case for multi-word placeholders: `<my_product_database_certificates_secrets>`
   - Make them clearly user-replaceable
   - Match the semantic meaning of the original callout

## What it detects

The Vale rule `CalloutList.yml` detects code blocks with callout markers `<1>`, `<2>`, etc. and corresponding callout lists below them.

## Callouts for values (convert to description list)

**Failure (callout list)**:
```asciidoc
[source,yaml]
----
apiVersion: v1
kind: Secret
metadata:
 name: my_product_database_certificates_secrets <1>
type: Opaque
stringData:
 postgres-ca.pem: |-
  -----BEGIN CERTIFICATE-----
  ==AABB.... <2>
 postgres-key.key: |-
  -----BEGIN CERTIFICATE-----
  ==BBAA... <3>
----
<1> The name of the certificate secret.
<2> The CA certificate key.
<3> The TLS Private key.
```

**Correct (description list with placeholders)**:
```asciidoc
[source,yaml,subs="+attributes,+quotes"]
----
apiVersion: v1
kind: Secret
metadata:
 name: <my_product_database_certificates_secrets>
type: Opaque
stringData:
 postgres-ca.pem: |-
  -----BEGIN CERTIFICATE-----
  <ca_certificate_key>
 postgres-key.key: |-
  -----BEGIN CERTIFICATE-----
  <tls_private_key>
----

where:

`<my_product_database_certificates_secrets>`:: Specifies the name of the certificate secret.
`<ca_certificate_key>`:: Specifies the CA certificate key.
`<tls_private_key>`:: Specifies the TLS private key.
```

**Important notes**:
- Add `subs="+attributes,+quotes"` to the source block to render the angle brackets
- Use "where:" or "where the following variables are used:" to introduce the description list
- Start each description with a verb like "Specifies", "Defines", "Indicates"

## Callouts for code structure (convert to bullet list)

**Failure (callout list for structures)**:
```asciidoc
[source,yaml]
----
apiVersion: tekton.dev/v1
kind: Pipeline
spec:
  workspaces: <1>
  - name: shared-workspace
  tasks: <2>
  - name: build-image
    workspaces: <3>
    - name: source
      workspace: shared-workspace
----
<1> The list of pipeline workspaces shared between tasks.
<2> The tasks used in the pipeline.
<3> The list of task workspaces used in the tasks.
```

**Correct (bullet list)**:
```asciidoc
[source,yaml]
----
apiVersion: tekton.dev/v1
kind: Pipeline
spec:
  workspaces:
  - name: shared-workspace
  tasks:
  - name: build-image
    workspaces:
    - name: source
      workspace: shared-workspace
----

* `spec.workspaces` defines the list of pipeline workspaces shared between tasks.
* `spec.tasks` defines the tasks used in the pipeline.
* `spec.tasks.workspaces` defines the list of task workspaces used in the tasks.
```

## Usage

When the user asks to fix callout lists:

1. Read the affected file(s)
2. Locate code blocks with callout markers (`<1>`, `<2>`, etc.)
3. Identify the callout list below the code block
4. Determine if callouts represent values or code structures
5. For values: Replace with placeholders and create description list
6. For structures: Remove callouts and create bullet list
7. Use Edit tool to make changes
8. Report the changes made

## Example invocations

- "Fix callout lists in modules/configuration.adoc"
- "Replace callouts with description lists"
- "Fix CalloutList Vale errors in all modules"

## Output format

When fixing files, report:

```
modules/configuration.adoc: Replaced callout list with description list
  Converted 4 callouts to user-replaceable placeholders
  Created description list with 4 entries
```

Or:

```
modules/api-reference.adoc: Replaced callout list with bullet list
  Removed 3 structure callouts
  Created bullet list explaining code structures
```

## Related Vale rule

This skill addresses the error from: `.vale/styles/AsciiDocDITA/CalloutList.yml`
