---
name: dita-reduce-asciidoc
description: Reduce AsciiDoc files by expanding all include directives into a single flattened document using asciidoctor-reducer. Use this skill when asked to reduce, flatten, resolve, or normalize AsciiDoc assemblies.
model: claude-haiku-4-5@20251001
allowed-tools: Bash, Glob, Read, Edit, Write
---

# Reduce AsciiDoc Skill

Reduce AsciiDoc files by expanding all include directives into a single flattened document using the asciidoctor-reducer gem.

## Overview

This skill wraps the official asciidoctor-reducer tool to flatten AsciiDoc documents that contain include directives. It recursively resolves all includes and produces a single self-contained document.

## Prerequisites

Install the asciidoctor-reducer gem:

```bash
gem install asciidoctor-reducer
```

## What it does

### Input: Document with includes

```asciidoc
= Master Guide

include::_attributes/common.adoc[]

include::modules/con-intro.adoc[leveloffset=+1]

include::assemblies/getting-started.adoc[leveloffset=+1]
```

### Output: Flattened document

All include directives are expanded inline, producing a single document with no external dependencies.

## Key features

- **Uses asciidoctor-reducer**: Leverages the official Asciidoctor tool for reliable include resolution
- **Recursive expansion**: All includes are resolved to any depth
- **Preprocessor conditionals**: Evaluates ifdef/ifndef/endif by default (can be preserved)
- **Safe mode**: Runs in unsafe mode to allow includes from any directory

## Usage

```bash
ruby skills/dita-reduce-asciidoc/scripts/reduce_asciidoc.rb <file.adoc> [options]
```

### Options

| Option | Description |
|--------|-------------|
| `-o, --output FILE` | Write output to FILE (default: `<input>-reduced.adoc`) |
| `-n, --dry-run` | Show what would be done without writing files |
| `-p, --preserve-conditionals` | Keep ifdef/ifndef/endif directives unchanged |
| `-h, --help` | Show help message |

### Examples

```bash
# Reduce an assembly (output to master-reduced.adoc)
ruby skills/dita-reduce-asciidoc/scripts/reduce_asciidoc.rb master.adoc

# Reduce with custom output path
ruby skills/dita-reduce-asciidoc/scripts/reduce_asciidoc.rb master.adoc -o flat-master.adoc

# Preview without writing
ruby skills/dita-reduce-asciidoc/scripts/reduce_asciidoc.rb master.adoc --dry-run

# Keep preprocessor conditionals
ruby skills/dita-reduce-asciidoc/scripts/reduce_asciidoc.rb master.adoc --preserve-conditionals
```

## Alternative: Direct CLI usage

You can also use asciidoctor-reducer directly:

```bash
# Basic usage
asciidoctor-reducer input.adoc -o output.adoc

# Preserve conditionals
asciidoctor-reducer --preserve-conditionals input.adoc -o output.adoc
```

## Example invocations

- "Reduce the assembly in docs/master.adoc"
- "Flatten all includes into a single file"
- "Normalize the nested assemblies"
- "Expand includes in the documentation"

## Script location

```
skills/dita-reduce-asciidoc/scripts/
└── reduce_asciidoc.rb      # Wrapper script for asciidoctor-reducer
```
