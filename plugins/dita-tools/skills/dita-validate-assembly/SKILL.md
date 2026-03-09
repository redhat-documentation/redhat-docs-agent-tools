---
name: dita-validate-assembly
description: Run Vale validation on an assembly and all modules it includes. Extracts include directives, resolves paths, and validates the complete documentation set. Use this skill when asked to validate an assembly, check assembly documentation, or prepare an assembly for DITA conversion.
allowed-tools: Bash, Read, Glob, Grep, Skill, TodoWrite
---

# Assembly validation skill

Run comprehensive Vale validation on an assembly file and all modules it includes.

## Overview

This skill provides end-to-end validation for complete documentation assemblies. It reads the assembly file, extracts all `include::` directives, resolves the file paths, and runs Vale validation on the entire documentation set (assembly + all included modules).

**Implementation**: This skill has a Ruby script (`scripts/validate_assembly.rb`) that automatically:
1. Extracts all `include::` directives from the assembly
2. Resolves relative paths correctly
3. Runs Vale on the complete file set (assembly + modules)
4. Reports results grouped by file with structured output

This ensures consistent validation that matches CI behavior.

## Using the script directly

The skill can be invoked using the Ruby script:

```bash
# Basic usage - validate assembly and all directly included modules
ruby scripts/validate_assembly.rb /path/to/assembly.adoc

# Recursive mode - include nested includes (snippets in modules)
ruby scripts/validate_assembly.rb /path/to/assembly.adoc --recursive

# Report only - don't invoke fix skills
ruby scripts/validate_assembly.rb /path/to/assembly.adoc --report-only

# JSON output for programmatic parsing
ruby scripts/validate_assembly.rb /path/to/assembly.adoc --output-format=json

# Summary output - just counts and stats
ruby scripts/validate_assembly.rb /path/to/assembly.adoc --output-format=summary

# Custom Vale config
ruby scripts/validate_assembly.rb /path/to/assembly.adoc --vale-config=.vale.ini
```

**Script output includes**:
- Assembly structure visualization
- Content type detection for each file
- Vale issues grouped by file
- Summary statistics (total files, files with issues, issue counts by type)

## AI Action Plan

**When to use this skill**: When asked to validate an assembly, check assembly documentation, fix all issues in an assembly, or prepare an assembly for DITA conversion.

**Workflow steps**:

1. **Run the validate_assembly.rb script** on the assembly file using Bash tool
   ```bash
   ruby scripts/validate_assembly.rb <assembly-file> [options]
   ```

2. **Parse the script output** to identify:
   - All included files (assembly + modules)
   - Files with Vale issues
   - Issue types and counts
   - Missing files (if any)

3. **Create a todo list** with all issue types to fix

4. **For each issue type**, invoke the corresponding dita-* skill:
   - ContentType → `/dita-content-type`
   - DocumentId → `/dita-document-id`
   - ShortDescription → `/dita-short-description`
   - etc. (see issue mapping table below)

5. **Report summary** to user:
   - Files validated
   - Issues found and fixed
   - Remaining issues (if any)

## Include directive patterns

The skill recognizes various include formats:

```asciidoc
# Standard module include
include::modules/installing.adoc[leveloffset=+1]

# Relative path (parent directory)
include::../shared/common-prereq.adoc[]

# Relative path (current directory)
include::./modules/configuring.adoc[leveloffset=+1]

# Snippet include (within modules)
include::snippets/note-admin-access.adoc[]

# Conditional include
ifdef::environment[]
include::modules/advanced-config.adoc[leveloffset=+1]
endif::[]
```

## Path resolution

Paths are resolved relative to the assembly file location:

```
# Assembly at: assemblies/getting-started.adoc
# Include: include::modules/installing.adoc[]
# Resolved: assemblies/modules/installing.adoc

# Assembly at: assemblies/user-guide/getting-started.adoc
# Include: include::../modules/installing.adoc[]
# Resolved: assemblies/modules/installing.adoc

# Assembly at: assemblies/getting-started.adoc
# Include: include::./modules/installing.adoc[]
# Resolved: assemblies/modules/installing.adoc
```

## Usage modes

### Mode 1: Validate and fix (default)

Runs `/dita-vale-fix` on the complete documentation set:

```bash
/dita-validate-assembly assemblies/getting-started.adoc
```

### Mode 2: Report only

Just reports issues without fixing:

```bash
/dita-validate-assembly assemblies/getting-started.adoc --report-only
```

### Mode 3: Recursive validation

Validates assembly + modules + snippets included by modules:

```bash
/dita-validate-assembly assemblies/getting-started.adoc --recursive
```

### Mode 4: Interactive fixing

Asks for confirmation before complex fixes:

```bash
/dita-validate-assembly assemblies/getting-started.adoc --interactive
```

## Example assembly structure

```asciidoc
# assemblies/getting-started.adoc
:_mod-docs-content-type: ASSEMBLY
[id="getting-started"]
= Getting started with MyProduct

This assembly describes how to install and configure MyProduct.

include::modules/about-myproduct.adoc[leveloffset=+1]

include::modules/installing-myproduct.adoc[leveloffset=+1]

include::modules/configuring-myproduct.adoc[leveloffset=+1]

include::modules/verifying-installation.adoc[leveloffset=+1]

== Additional resources

* link:https://example.com[Product documentation]
```

## What the skill does

For the above assembly, the skill:

1. **Extracts includes**:
   - `modules/about-myproduct.adoc`
   - `modules/installing-myproduct.adoc`
   - `modules/configuring-myproduct.adoc`
   - `modules/verifying-installation.adoc`

2. **Resolves paths** (assuming assembly is at `assemblies/getting-started.adoc`):
   - `assemblies/modules/about-myproduct.adoc`
   - `assemblies/modules/installing-myproduct.adoc`
   - `assemblies/modules/configuring-myproduct.adoc`
   - `assemblies/modules/verifying-installation.adoc`

3. **Builds file list**:
   - `assemblies/getting-started.adoc`
   - `assemblies/modules/about-myproduct.adoc`
   - `assemblies/modules/installing-myproduct.adoc`
   - `assemblies/modules/configuring-myproduct.adoc`
   - `assemblies/modules/verifying-installation.adoc`

4. **Runs `/dita-vale-fix`** on all 5 files

## Example invocations

- "Validate assemblies/getting-started.adoc and all its modules"
- "Fix all Vale issues in assemblies/user-guide.adoc and its includes"
- "Check assemblies/admin-guide.adoc for DITA compatibility"
- "Prepare assemblies/installation.adoc for conversion"
- "Run Vale on assemblies/troubleshooting.adoc and everything it includes"

## Output format

### Initial analysis:
```
Analyzing assembly: assemblies/getting-started.adoc

Assembly structure:
├── assemblies/getting-started.adoc (ASSEMBLY)
├── modules/about-myproduct.adoc (CONCEPT)
├── modules/installing-myproduct.adoc (PROCEDURE)
├── modules/configuring-myproduct.adoc (PROCEDURE)
└── modules/verifying-installation.adoc (PROCEDURE)

Files to validate: 5
- 1 assembly
- 4 modules (1 concept, 3 procedures)

Running Vale validation...
```

### Validation results:
```
Vale Report by File:
====================

assemblies/getting-started.adoc:
✓ No issues found

modules/about-myproduct.adoc:
⚠ ShortDescription: Missing [role="_abstract"]
⚠ DocumentId: Missing ID attribute

modules/installing-myproduct.adoc:
✓ No issues found

modules/configuring-myproduct.adoc:
⚠ TaskStep: List continuation missing at line 45
⚠ ShortDescription: Missing [role="_abstract"]

modules/verifying-installation.adoc:
⚠ TaskContents: Missing .Procedure block title
⚠ EntityReference: Unsupported entity &nbsp; at line 23

Summary:
- Total issues: 6
- Files with issues: 3 of 5
- Ready to fix

Proceeding with fixes using /dita-vale-fix...
```

### Fix progress:
```
Phase 1: Simple structural fixes...
✓ DocumentId: Added ID to modules/about-myproduct.adoc

Phase 2: Content formatting...
✓ ShortDescription: Fixed 2 files
✓ EntityReference: Fixed 1 file

Phase 3: Procedure fixes...
✓ TaskContents: Added .Procedure to modules/verifying-installation.adoc
✓ TaskStep: Fixed list continuation in modules/configuring-myproduct.adoc

All issues resolved!
```

### Final summary:
```
Assembly Validation Complete
============================

Assembly: assemblies/getting-started.adoc

Results:
✓ All 5 files validated
✓ 6 issues found and fixed
✓ 0 issues remaining

Modified files:
- modules/about-myproduct.adoc (2 fixes)
- modules/configuring-myproduct.adoc (2 fixes)
- modules/verifying-installation.adoc (2 fixes)

Status: ✓ Assembly is ready for DITA conversion

Next steps:
- Run /dita-reduce-asciidoc assemblies/getting-started.adoc (optional)
- Run /dita-convert assemblies/getting-started.adoc
```

## Handling missing files

If an included file doesn't exist:

```
⚠ Warning: Include not found
  Assembly: assemblies/getting-started.adoc
  Include: modules/missing-file.adoc
  Referenced at: line 15

Skipping missing file. The assembly references a file that doesn't exist.
Please verify the include path or create the missing module.

Continuing with remaining files...
```

## Handling nested includes

With `--recursive` flag:

```
Analyzing assembly: assemblies/getting-started.adoc (recursive mode)

Assembly structure:
├── assemblies/getting-started.adoc (ASSEMBLY)
├── modules/installing-myproduct.adoc (PROCEDURE)
│   ├── snippets/prereq-admin-access.adoc (SNIPPET)
│   └── snippets/note-sudo-required.adoc (SNIPPET)
├── modules/configuring-myproduct.adoc (PROCEDURE)
│   └── snippets/warning-backup-first.adoc (SNIPPET)
└── modules/verifying-installation.adoc (PROCEDURE)

Files to validate: 7
- 1 assembly
- 3 modules (procedures)
- 3 snippets

Running Vale validation...
```

## Integration with other skills

This skill works well with:

- **dita-vale-fix** (called automatically) - Fix all issues
- **dita-reduce-asciidoc** - Flatten assembly before conversion
- **dita-convert** - Convert to DITA after validation passes

## Workflow example

Complete assembly preparation workflow:

```bash
# Step 1: Validate and fix assembly + modules
/dita-validate-assembly assemblies/getting-started.adoc

# Step 2: Reduce (flatten) assembly for conversion
/dita-reduce-asciidoc assemblies/getting-started.adoc

# Step 3: Convert to DITA
/dita-convert assemblies/getting-started-reduced.adoc
```

## Error handling

The skill handles:
- Assembly file not found
- Invalid assembly (no includes)
- Missing included files (warns, continues with others)
- Circular includes (detects and prevents infinite loops)
- Permission errors (reports, skips)

## Report-only mode benefits

Use `--report-only` when you want to:
- Assess the scope of issues before fixing
- Generate a report for team review
- Identify which modules need the most work
- Export Vale results for tracking

## Related skills

- **dita-vale-fix** - Fix Vale issues in files
- **dita-reduce-asciidoc** - Flatten assemblies
- **dita-convert** - Convert to DITA
- **vale** - Run Vale with custom options
