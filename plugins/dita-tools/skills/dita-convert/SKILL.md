---
name: dita-convert
description: Convert AsciiDoc files to DITA 2.0 format (concept, task, reference, ditamap). Use this skill when asked to convert AsciiDoc to DITA, generate DITA topics, or create DITAMAPs from assemblies.
model: claude-haiku-4-5@20251001
allowed-tools: Bash, Glob, Read, Edit, Write
---

# DITA conversion skill

Convert Red Hat AsciiDoc documentation to DITA 2.0 format.

## Overview

This skill uses the `dita_convert.rb` Ruby script to convert AsciiDoc files to DITA 2.0 XML format. It automatically detects the content type (ASSEMBLY, CONCEPT, PROCEDURE, REFERENCE) and generates the appropriate DITA output.

## What it does

### Input: AsciiDoc module

```asciidoc
:_mod-docs-content-type: CONCEPT
[id="vllm-overview_{context}"]
= vLLM overview

[role="_abstract"]
vLLM is a fast and easy-to-use library for LLM inference.

vLLM provides the following key features:

* State-of-the-art serving throughput
* Efficient memory management
```

### Output: DITA concept topic

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE concept PUBLIC "-//OASIS//DTD DITA 2.0 Concept//EN" "concept.dtd">
<concept id="vllm-overview">
  <title>vLLM overview</title>
  <shortdesc>vLLM is a fast and easy-to-use library for LLM inference.</shortdesc>
  <conbody>
    <p>vLLM provides the following key features:</p>
    <ul>
      <li>State-of-the-art serving throughput</li>
      <li>Efficient memory management</li>
    </ul>
  </conbody>
</concept>
```

## Content type mapping

The `:_mod-docs-content-type:` attribute is read from the AST and determines the output type:

| AsciiDoc `:_mod-docs-content-type:` | DITA Output |
|-------------------------------------|-------------|
| `ASSEMBLY` | `.ditamap` (map with topicrefs to `topics/` folder) |
| `CONCEPT` | `<concept>` topic |
| `PROCEDURE` | `<task>` topic |
| `REFERENCE` | `<reference>` topic |
| `SNIPPET` | Included inline where referenced (no standalone output) |

When processing assemblies, each included module is parsed individually and its `:_mod-docs-content-type:` attribute determines the appropriate DITA topic type.

## Element conversion

### Block elements

| AsciiDoc | DITA |
|----------|------|
| `= Title` | `<title>` |
| `[role="_abstract"]` paragraph | `<shortdesc>` |
| Paragraph | `<p>` |
| `* item` (unordered list) | `<ul><li>` |
| `. item` (ordered list) | `<ol><li>` or `<steps><step>` |
| Definition list | `<dl><dlentry>` or `<properties>` |
| `[source,lang]` | `<codeblock outputclass="language-X">` |
| Table | `<table><tgroup>` |
| `== Section` | `<section><title>` |

### Inline elements

| AsciiDoc | DITA |
|----------|------|
| `*bold*` | `<b>` |
| `_italic_` | `<i>` |
| `` `monospace` `` | `<codeph>` |
| `link:https://url[text]` | `<xref href="..." format="html" scope="external">` |
| `\<<anchor>>` / `#anchor` | `<xref href="#anchor">` |

### Procedure-specific mapping

| AsciiDoc | DITA Task |
|----------|-----------|
| `.Prerequisites` section | `<prereq>` |
| `.Procedure` ordered list | `<steps><step><cmd>` |
| `.Verification` section | `<result>` |
| Code blocks in steps | `<stepxmp><codeblock>` |

## Usage

When the user asks to convert AsciiDoc to DITA:

1. Identify the target file or folder containing AsciiDoc content
2. Run the Ruby script against each file:
   ```bash
   ruby skills/dita-convert/scripts/dita_convert.rb <file.adoc>
   ```
3. Report the converted files and any validation errors

All output files are written to `.claude_docs/dita-convert/` by default.

### Basic conversion

```bash
ruby skills/dita-convert/scripts/dita_convert.rb module.adoc
```

Output goes to `.claude_docs/dita-convert/`.

### Specify output directory

```bash
ruby skills/dita-convert/scripts/dita_convert.rb module.adoc -o output/
```

### Dry run (preview without writing)

```bash
ruby skills/dita-convert/scripts/dita_convert.rb module.adoc --dry-run
```

### Show parsed AST

```bash
ruby skills/dita-convert/scripts/dita_convert.rb module.adoc --ast
```

### Convert assembly (generates DITAMAP + all modules)

```bash
ruby skills/dita-convert/scripts/dita_convert.rb assembly.adoc
```

## Example invocations

- "Convert modules/concept-vllm.adoc to DITA"
- "Generate DITA topics from the assemblies folder"
- "Create a DITAMAP from assembly-openshift-ai.adoc"
- "Convert all AsciiDoc files in modules/ to DITA format"
- "Preview DITA conversion for reference-config-options.adoc"

## AST output

The script can output the parsed AsciiDoc as an Abstract Syntax Tree (AST). If the `toon` gem is installed, it outputs in TOON format (Token-Oriented Object Notation) for reduced token usage:

```bash
gem install toon-ruby
ruby skills/dita-convert/scripts/dita_convert.rb module.adoc --ast
```

Example TOON output:
```
type: document
id: vllm-overview
title: vLLM overview
children[2]:
 type: paragraph
 text[1]: vLLM is a fast library.
 type: ulist
 children[2]:
  type: list_item
  text[1]: Feature one
```

## Validation

Output is automatically validated using DITA-OT. Requires the `dita` command on PATH.

Install DITA-OT: https://www.dita-ot.org/download

## Content coverage

After conversion, the script validates that all AST content has been processed. If any content is missing from the output, warnings are displayed:

```
=== Content Coverage Warnings ===
Coverage: 75.0% (15/20 nodes)

WARNING: Unhandled sidebar
         Location: document > section > sidebar
WARNING: Unhandled paragraph
         Location: document > section > sidebar > paragraph
================================
```

This helps identify:
- Unhandled block types (sidebar, example, open blocks)
- Missing content due to parsing issues
- Elements that need converter support added

## Behavior notes

- **Assembly conversion**: Automatically finds and converts all included modules to `topics/` subfolder
- **Output structure**: DITAMAP at root, topics in `topics/` subfolder with proper hrefs
- **ID handling**: Preserves AsciiDoc IDs (with `_{context}` suffix if present)
- **Shortdesc extraction**: Uses `[role="_abstract"]` paragraph as `<shortdesc>`
- **Table conversion**: Supports both simple and complex tables with headers
- **Code blocks**: Preserves language hints as `outputclass` attributes
- **Attribute filtering**: Skips `_attributes/` and `snippets/` includes in assembly processing
- **Automatic validation**: Output is validated using DITA-OT after each file is written
- **AST output**: An AST file is always written alongside each DITA output (`.ast.toon` if toon gem is installed, otherwise `.ast.json`)

## Output structure

All output is written to `.claude_docs/dita-convert/` by default.

### Single module conversion

```
.claude_docs/dita-convert/
├── concept-vllm-overview.ast.toon
└── concept-vllm-overview.dita
```

### Assembly conversion

Assemblies are converted to a DITAMAP at the root with topics in a `topics/` subfolder:

```
.claude_docs/dita-convert/
├── assembly-openshift-ai.ast.toon
├── assembly-openshift-ai.ditamap
└── topics/
    ├── concept-intro.ast.toon
    ├── concept-intro.dita
    ├── procedure-install.ast.toon
    ├── procedure-install.dita
    ├── reference-config.ast.toon
    └── reference-config.dita
```

The DITAMAP references topics with relative paths:

```xml
<map id="openshift-ai">
  <title>OpenShift AI</title>
  <topicref href="topics/concept-intro.dita"/>
  <topicref href="topics/procedure-install.dita"/>
  <topicref href="topics/reference-config.dita"/>
</map>
```

## Output format

Successful conversion:
```
Wrote: output/concept-vllm-overview.dita

Conversion complete:
  Type: concept
  Input: modules/concept-vllm-overview.adoc
  Output: output/concept-vllm-overview.dita
```

Assembly conversion:
```
Wrote: output/assembly-openshift-ai.ditamap
Wrote: output/topics/concept-intro.dita
Wrote: output/topics/procedure-install.dita
Wrote: output/topics/reference-config.dita

Conversion complete:
  Type: assembly
  Input: assembly-openshift-ai.adoc
  Output: output/assembly-openshift-ai.ditamap
  Modules converted: 3
    - concept: output/topics/concept-intro.dita
    - task: output/topics/procedure-install.dita
    - reference: output/topics/reference-config.dita
```

## Script location

```bash
ruby skills/dita-convert/scripts/dita_convert.rb <file.adoc>
```

The script uses supporting libraries in `lib/`:
```
skills/dita-convert/scripts/
├── dita_convert.rb             # Main entry point
└── lib/
    ├── dita_generator.rb       # Core XML utilities module
    ├── ast_converter.rb        # Asciidoctor node to hash converter
    ├── content_tracker.rb      # Content coverage validation
    ├── dita_validator.rb       # DITA-OT validation
    ├── dita_converter.rb       # Main orchestrator class
    └── generators/
        ├── concept_generator.rb    # Concept topic generation
        ├── task_generator.rb       # Task topic generation
        ├── reference_generator.rb  # Reference topic generation
        └── map_generator.rb        # DITAMAP generation
```
