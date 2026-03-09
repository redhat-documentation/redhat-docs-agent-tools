# Test Fixtures

This directory contains test AsciiDoc files for verifying the functionality of the Ruby scripts.

## Directory Structure

- `dita-callouts/` - Test files for `callouts.rb`
- `dita-chop-reduced-asciidoc/` - Test files for `chop_reduced_asciidoc.rb`
- `dita-convert/` - Test files for `dita_convert.rb`
- `dita-document-id/` - Test files for `document_id.rb`
- `dita-entity-reference/` - Test files for `entity_reference.rb`
- `dita-line-break/` - Test files for `line_break.rb`
- `dita-reduce-asciidoc/` - Test files for `reduce_asciidoc.rb`
- `dita-related-links/` - Test files for `related_links.rb`
- `dita-short-description/` - Test files for `short_description.rb`
- `dita-task-contents/` - Test files for `task_contents.rb`
- `dita-task-step/` - Test files for `task_step.rb`
- `dita-task-title/` - Test files for `task_title.rb`

## Usage

Run a script against test fixtures with `--dry-run` to verify behavior:

```bash
# AsciiDoc reducer (requires: gem install asciidoctor-reducer)
ruby dita-tools/skills/dita-reduce-asciidoc/scripts/reduce_asciidoc.rb test-fixtures/dita-reduce-asciidoc/master.adoc --dry-run

# Chop reduced assemblies
ruby dita-tools/skills/dita-chop-reduced-asciidoc/scripts/chop_reduced_asciidoc.rb test-fixtures/dita-chop-reduced-asciidoc/master-reduced.adoc --dry-run

# DITA converter
ruby dita-tools/skills/dita-convert/scripts/dita_convert.rb test-fixtures/dita-convert/concept-module.adoc --dry-run

# Document ID generator
ruby dita-tools/skills/dita-document-id/scripts/document_id.rb test-fixtures/dita-document-id/missing-id-concept.adoc --dry-run

# Entity reference replacer
ruby dita-tools/skills/dita-entity-reference/scripts/entity_reference.rb test-fixtures/dita-entity-reference/common-entities.adoc --dry-run

# Short description adder
ruby dita-tools/skills/dita-short-description/scripts/short_description.rb test-fixtures/dita-short-description/missing-abstract-concept.adoc --dry-run

# Line break remover
ruby dita-tools/skills/dita-line-break/scripts/line_break.rb test-fixtures/dita-line-break/simple-line-continuation.adoc --dry-run

# Related links cleaner
ruby dita-tools/skills/dita-related-links/scripts/related_links.rb test-fixtures/dita-related-links/mixed-content.adoc --dry-run

# Task contents fixer (add .Procedure title)
ruby dita-tools/skills/dita-task-contents/scripts/task_contents.rb test-fixtures/dita-task-contents/missing-procedure-title.adoc --dry-run

# Task step fixer (list continuations)
ruby dita-tools/skills/dita-task-step/scripts/task_step.rb test-fixtures/dita-task-step/missing-continuations.adoc --dry-run

# Task title remover
ruby dita-tools/skills/dita-task-title/scripts/task_title.rb test-fixtures/dita-task-title/unsupported-titles.adoc --dry-run
```

## Workflow Example

A typical workflow to reduce and chop an assembly:

```bash
# Step 1: Reduce the assembly (flatten includes)
ruby dita-tools/skills/dita-reduce-asciidoc/scripts/reduce_asciidoc.rb test-fixtures/dita-reduce-asciidoc/master.adoc -o /tmp/master-reduced.adoc

# Step 2: Chop into modules
ruby dita-tools/skills/dita-chop-reduced-asciidoc/scripts/chop_reduced_asciidoc.rb /tmp/master-reduced.adoc -o /tmp/output/
```
