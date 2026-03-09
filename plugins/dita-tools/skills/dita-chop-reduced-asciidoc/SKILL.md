---
name: dita-chop-reduced-asciidoc
description: Chop reduced AsciiDoc files into separate module files based on section headings (h1-h3). Use this skill when asked to chop, split, or modularize a reduced/flattened AsciiDoc document.
model: claude-haiku-4-5@20251001
allowed-tools: Bash, Glob, Read, Edit, Write
---

# Chop Reduced AsciiDoc Skill

Chop a reduced/flattened AsciiDoc file into separate module files based on section headings.

## Overview

This skill takes the output from asciidoctor-reducer (a flattened AsciiDoc file with all includes expanded) and splits it into individual module files based on h1-h3 section headings. It generates a new assembly file with include directives pointing to the chopped modules.

## What it does

### Input: Reduced/flattened AsciiDoc file

```asciidoc
= Master Guide

Introduction paragraph.

== Getting Started

This section explains how to get started.

=== Installation

Install the software using...

== Configuration

Configure the system by...
```

### Output: Chopped modules and assembly

```
tmp/
├── master-guide.adoc           # New assembly with includes
└── includes/
    ├── getting-started.adoc    # == Getting Started section
    ├── installation.adoc       # === Installation section
    └── configuration.adoc      # == Configuration section
```

## Key features

- **Simple section chopping**: Cuts on h1-h3 headings, no content analysis
- **Preserves section IDs**: Uses existing `[id="..."]` attributes or generates from titles
- **Strips `_{context}` for filenames**: Removes `_{context}` suffix from IDs when generating filenames and include paths (the IDs in the module files retain the `_{context}` suffix as required for modules)
- **Assembly IDs without `_{context}`**: The generated assembly file does not include `_{context}` in its ID (assemblies never use this suffix)
- **Tracks module metadata**: Correctly associates `:_module-type:`, `:_mod-docs-content-type:`, and `:parent-context:` attributes with the section that follows
- **Tracks leveloffset**: Parses `:leveloffset:` directives to calculate effective heading levels
- **Normalizes headings**: All module headings are normalized to `= Title` (h1), with leveloffset in includes
- **Preserves all content**: Moves everything in a section to the new module file
- **Generates assembly**: Creates a new assembly with proper leveloffset includes
- **Handles discrete headings**: Discrete headings stay within their parent section

## Usage

```bash
ruby skills/dita-chop-reduced-asciidoc/scripts/chop_reduced_asciidoc.rb <file.adoc> [options]
```

### Options

| Option | Description |
|--------|-------------|
| `-o, --output DIR` | Output directory (default: `tmp/`) |
| `-n, --dry-run` | Show what would be done without writing files |
| `-h, --help` | Show help message |

### Examples

```bash
# Chop a reduced file (output to tmp/)
ruby skills/dita-chop-reduced-asciidoc/scripts/chop_reduced_asciidoc.rb master-reduced.adoc

# Chop with custom output directory
ruby skills/dita-chop-reduced-asciidoc/scripts/chop_reduced_asciidoc.rb master-reduced.adoc -o output/

# Preview without writing files
ruby skills/dita-chop-reduced-asciidoc/scripts/chop_reduced_asciidoc.rb master-reduced.adoc --dry-run
```

## Workflow

Typical workflow with reduce-asciidoc:

```bash
# Step 1: Reduce the assembly (flatten includes)
ruby skills/dita-reduce-asciidoc/scripts/reduce_asciidoc.rb master.adoc -o master-reduced.adoc

# Step 2: Chop into modules
ruby skills/dita-chop-reduced-asciidoc/scripts/chop_reduced_asciidoc.rb master-reduced.adoc -o tmp/
```

## Leveloffset calculation

The script tracks `:leveloffset:` directives from the source file to calculate the **effective level** of each section. Each chopped module is normalized to use `= Title` (h1), and the include directive's leveloffset is set to `effective_level - 1` to reproduce the correct TOC hierarchy.

For example, if the source has:
- `:leveloffset: +1` followed by `= Section Title` → effective level 2 → `leveloffset=+1`
- `:leveloffset: +2` followed by `= Section Title` → effective level 3 → `leveloffset=+2`
- `== Section Title` (no offset) → effective level 2 → `leveloffset=+1`

## Example invocations

- "Chop the reduced assembly into modules"
- "Split master-reduced.adoc into separate files"
- "Modularize the flattened documentation"
- "Create modules from the reduced file"

## Script location

```
skills/dita-chop-reduced-asciidoc/scripts/
└── chop_reduced_asciidoc.rb    # Main chopping script
```
