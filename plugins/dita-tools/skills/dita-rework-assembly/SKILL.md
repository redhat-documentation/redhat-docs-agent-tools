---
name: dita-rework-assembly
description: Extract inline content from AsciiDoc assembly files into separate modules. Use when refactoring assemblies to follow Red Hat modular documentation standards — moving introductory preambles, inline procedures, inline concepts, admonitions, or any other content into reusable modules.
allowed-tools: Read, Edit, Write, Glob, Grep, Bash, Task
---

# Extract content from assemblies into modules

This skill extracts inline content from AsciiDoc assembly files and moves it into separate modules following Red Hat modular documentation standards. It handles introductory preambles, inline procedures, inline concepts, admonitions, additional resources sections, and any other content that should live in a module rather than directly in an assembly.

## When to use

Use this skill when:

- Refactoring assemblies to follow modular documentation best practices
- Moving inline introductory paragraphs from assemblies into reusable concept modules
- Extracting inline procedures or concepts that were written directly in an assembly
- Creating `about-*` concept modules from assembly preambles
- Moving admonition blocks or additional resources sections into their own modules
- The user asks to "extract content", "move preamble to modules", or "refactor assembly"

## Process overview

1. Find all target assembly files (typically `master.adoc` or files with `:_mod-docs-content-type: ASSEMBLY`)
2. For each assembly, identify content that should be extracted into modules
3. Create new modules containing the extracted content
4. Update the assembly to include the new modules
5. Adjust xref paths for the new module's directory depth
6. Preserve any admonitions, additional resources, and formatting

## Step-by-step instructions

### Step 1: Find assembly files

Search for assembly files in the repository:

```
Glob pattern: **/master.adoc
```

Or search for files with the assembly content type:

```
Grep pattern: :_mod-docs-content-type: ASSEMBLY
```

### Step 2: Analyze each assembly

For each assembly file, identify content that should be extracted. This includes:

**Introductory content** (between the header and the first `include::` directive):

1. **Header section**: Lines containing `:_mod-docs-content-type:`, `include::_attributes/`, title (`=`), and document attributes (`:doctype:`, `:toc:`, `:context:`)
2. **Preamble content**: All content between the header section and the first `include::modules/` directive

**Inline content** (between `include::` directives):

1. **Inline procedures**: Step-by-step instructions written directly in the assembly
2. **Inline concepts**: Explanatory paragraphs or sections between includes
3. **Inline references**: Tables, lists, or reference material between includes

Content that may be extracted includes:

- `[role="_abstract"]` blocks
- Paragraphs describing the assembly topic
- `[NOTE]`, `[IMPORTANT]`, `[WARNING]`, or `[TIP]` admonition blocks
- `[role="_additional-resources"]` sections with links
- Numbered or bulleted procedure steps
- Tables or reference content
- Subsections with their own headings

### Step 3: Determine module type and name

Choose the module type based on the content being extracted:

| Content type | Module type | Naming convention |
|---|---|---|
| Introductory/explanatory | CONCEPT | `about-<topic>.adoc` |
| Step-by-step instructions | PROCEDURE | `<action>-<topic>.adoc` |
| Tables, lists, specs | REFERENCE | `ref-<topic>.adoc` |

Where `<topic>` is derived from the assembly's parent directory or the content's subject (e.g., `server_arguments` becomes `server-arguments`).

Place new modules in the `modules/` directory relative to the repository root.

### Step 4: Create the new module

Use the appropriate template based on the module type:

**Concept module:**

```asciidoc
:_mod-docs-content-type: CONCEPT
[id="about-<topic>_{context}"]
= About <topic title>

[role="_abstract"]
<Extracted content>
```

**Procedure module:**

```asciidoc
:_mod-docs-content-type: PROCEDURE
[id="<action>-<topic>_{context}"]
= <Action> <topic title>

[role="_abstract"]
<Brief description of what the procedure accomplishes>

.Prerequisites

* <Any prerequisites from the assembly context>

.Procedure

. <Extracted steps>

.Verification

* <Any verification steps>
```

**Reference module:**

```asciidoc
:_mod-docs-content-type: REFERENCE
[id="ref-<topic>_{context}"]
= <Topic title>

[role="_abstract"]
<Brief description>

<Extracted tables, lists, or reference content>
```

### Step 5: Enhance the extracted content

When creating the module, improve the content where appropriate:

- Write descriptive prose rather than bullet lists of topics
- Avoid phrases like "This assembly covers..." or "In this section, you will learn..."
- Expand on the original content to provide context about the feature or topic
- Mention key capabilities or use cases
- Use product attribute references (e.g., `{product-title}`, `{prodname-short}`)

### Step 6: Update the assembly

Replace the extracted inline content in the assembly with an `include::` statement:

```asciidoc
include::modules/<new-module>.adoc[leveloffset=+1]
```

For introductory content, place the include as the first module after the header attributes.

Remove:

- The extracted content (paragraphs, admonitions, procedures, etc.)
- Any `[role="_abstract"]` tags that were moved
- Additional resources sections that were moved

Keep:

- The assembly header (`:_mod-docs-content-type: ASSEMBLY`, attributes include, title, document attributes)
- All other `include::` statements
- Any trailing additional resources sections that apply to the whole assembly

## Adjusting xref paths

When content containing `xref:` cross-references is moved from an assembly to a new module, you **must** recalculate the relative `../` climbing paths. The assembly and the new module are typically at different directory depths.

For example, if the assembly is at `installing/installing_sno/master.adoc` (depth 2) and the new module is at `modules/about-installing-sno.adoc` (depth 1):

- **Wrong** (copied verbatim): `xref:../../storage/persistent_storage/...`
- **Correct** (adjusted): `xref:../storage/persistent_storage/...`

**Formula:** count the directory depth of both files from the repo root, then adjust the `../` count by `(source depth − destination depth)`.

```
new_climb_count = original_climb_count - (source_depth - destination_depth)
```

Use the bundled helper script to calculate and verify adjustments:

```bash
scripts/xref-path-calculator.sh <source-file> <destination-file>
```

## Example transformation

### Before (master.adoc)

```asciidoc
:_mod-docs-content-type: ASSEMBLY
include::_attributes/attributes.adoc[]
= Getting started
:doctype: book
:toc: left
:context: getting-started

{product-title} is a container image that optimizes serving and inferencing with LLMs.
Using {prodname-short}, you can serve and inference models in a way that boosts their performance.

include::modules/overview.adoc[leveloffset=+1]

To configure the server, complete the following steps:

. Download the configuration file.
. Edit the `server.conf` file.
. Restart the service.

include::modules/installation.adoc[leveloffset=+1]
```

### After (master.adoc)

```asciidoc
:_mod-docs-content-type: ASSEMBLY
include::_attributes/attributes.adoc[]
= Getting started
:doctype: book
:toc: left
:context: getting-started

include::modules/about-getting-started.adoc[leveloffset=+1]

include::modules/overview.adoc[leveloffset=+1]

include::modules/configuring-the-server.adoc[leveloffset=+1]

include::modules/installation.adoc[leveloffset=+1]
```

### New concept module (modules/about-getting-started.adoc)

```asciidoc
:_mod-docs-content-type: CONCEPT
[id="about-getting-started_{context}"]
= About {product-title}

[role="_abstract"]
{product-title} is a container image that optimizes serving and inferencing with LLMs.
Using {prodname-short}, you can serve and inference models in a way that boosts their performance.

{product-title} supports multiple hardware platforms including NVIDIA CUDA accelerators,
AMD ROCm accelerators, and other supported AI accelerators. You can run {prodname-short}
with Podman on supported hosts, enabling flexible deployment options for development,
testing, and production workloads.
```

### New procedure module (modules/configuring-the-server.adoc)

```asciidoc
:_mod-docs-content-type: PROCEDURE
[id="configuring-the-server_{context}"]
= Configuring the server

[role="_abstract"]
Configure the {product-title} server to customize its behavior for your environment.

.Procedure

. Download the configuration file.
. Edit the `server.conf` file.
. Restart the service.
```

## Style guidelines

Follow these guidelines when creating new modules:

- Use sentence case for headings
- Include `[role="_abstract"]` immediately after the title
- Use product attributes from `_attributes/attributes.adoc` for product names
- Do not use file prefixes like `con-`, `proc-`, `ref-`
- Preserve any `[NOTE]` or `[IMPORTANT]` admonitions from the original content
- Preserve `[role="_additional-resources"]` sections with their links
- Write descriptive prose rather than bullet lists of topics
- Avoid phrases like "This assembly covers..." or "In this section, you will learn..."

## Verification

After completing the extraction:

1. Verify the new module files exist in the `modules/` directory
2. Verify the assembly includes the new modules in the correct order
3. Verify no duplicate content exists between the modules and assembly
4. Check that all product attributes resolve correctly
5. Verify that any `xref:` paths in the new modules have been adjusted for the module's directory depth
6. Verify that no content is missing between the modules and assembly
