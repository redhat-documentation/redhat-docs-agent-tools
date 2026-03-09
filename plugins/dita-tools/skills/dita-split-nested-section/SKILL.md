---
name: dita-split-nested-section
description: Split nested sections in AsciiDoc module files into separate modules for DITA compatibility. Use this skill when a module contains subsection headings (== or deeper) that should be extracted into their own module files, or when Vale reports NestedSection issues.
model: claude-haiku-4-5-20251001
allowed-tools: Bash, Glob, Read, Edit, Write
---

# Split nested sections

Split nested sections (== or deeper) in AsciiDoc module files into separate module files for DITA compatibility and Red Hat modular documentation compliance.

## Overview

Red Hat modular documentation standards require that each module has a single heading level. Nested sections (`==`, `===`, etc.) inside a module should be extracted into separate module files. This skill detects nested sections and splits them into new modules, updating the parent assembly to include them.

## What it detects

For a module file like this:

```asciidoc
:_mod-docs-content-type: CONCEPT
[id="ptp-elements_{context}"]
= Elements of a PTP domain

[role="_abstract"]
PTP is used to synchronize multiple nodes...

Grandmaster clock:: The grandmaster clock provides...

[id="ptp-advantages-over-ntp_{context}"]
== Advantages of PTP over NTP

One of the main advantages that PTP has over NTP...
```

The script detects:
- Line 12: `== Advantages of PTP over NTP` (nested section inside a module)

## AI Action Plan

**When to use this skill**: When Vale reports `NestedSection` issues, when a module contains `==` or deeper headings, or when asked to split a module into smaller modules.

**Steps to follow**:

1. **Analyze**: Run the script to detect nested sections:

```bash
ruby ${CLAUDE_PLUGIN_ROOT}/skills/dita-split-nested-section/scripts/split_nested_section.rb "<file.adoc>" --json
```

2. **Review**: Check the analysis output for:
   - Number of nested sections found
   - Suggested filenames for new modules
   - Suggested content types (CONCEPT, PROCEDURE, REFERENCE)

3. **Identify the parent assembly**: Find which assembly includes this module:

```bash
grep -rl "<module-filename>" --include="*.adoc" <docs-root>/
```

4. **Split the module** using one of these approaches:

   **Option A - Automated split** (for straightforward cases):
   ```bash
   ruby ${CLAUDE_PLUGIN_ROOT}/skills/dita-split-nested-section/scripts/split_nested_section.rb "<file.adoc>" --split --assembly "<assembly.adoc>" --dry-run
   ```
   Review the dry-run output, then run without `--dry-run` to apply.

   **Option B - Manual split** (for cases needing judgment):
   - Read the module file
   - For each nested section:
     1. Create a new module file in the same directory
     2. Add `:_mod-docs-content-type:` based on content (CONCEPT, PROCEDURE, REFERENCE)
     3. Add `[id="<section-id>_{context}"]` (preserve existing ID or generate one)
     4. Change `==` heading to `=` (top-level heading for the new module)
     5. Add `[role="_abstract"]` before the first paragraph
     6. Move all content belonging to that section into the new file
   - Remove the nested section from the original module
   - Update the parent assembly to include the new module

5. **Update the assembly**: Add include directives for the new modules after the original module's include:

```asciidoc
include::modules/original-module.adoc[leveloffset=+1]

include::modules/new-split-module.adoc[leveloffset=+2]
```

The `leveloffset` for the new module should reflect its original nesting depth:
- `==` in original -> `leveloffset=+2` in assembly
- `===` in original -> `leveloffset=+3` in assembly

6. **Verify**: Run Vale to confirm the NestedSection violation is resolved:

```bash
vale --config=.vale.ini <original-file.adoc> <new-file.adoc>
```

## Content type determination

When creating new modules from split sections, determine the content type:

| Content pattern | Content type |
|----------------|--------------|
| Explains what something is, background, overview | CONCEPT |
| Step-by-step instructions, procedures, "how to" | PROCEDURE |
| Tables of parameters, options, API fields, specifications | REFERENCE |

## Example transformation

### Before (single module with nested section)

**modules/nw-ptp-introduction.adoc:**
```asciidoc
:_mod-docs-content-type: CONCEPT
[id="ptp-elements_{context}"]
= Elements of a PTP domain

[role="_abstract"]
PTP is used to synchronize multiple nodes connected in a network.

Grandmaster clock:: The grandmaster clock provides standard time information.

Boundary clock:: The boundary clock has ports in two or more communication paths.

Ordinary clock:: The ordinary clock has a single port connection.

[id="ptp-advantages-over-ntp_{context}"]
== Advantages of PTP over NTP

One of the main advantages that PTP has over NTP is the hardware support.
```

**Assembly (about-ptp.adoc):**
```asciidoc
include::modules/nw-ptp-introduction.adoc[leveloffset=+1]
```

### After (two separate modules)

**modules/nw-ptp-introduction.adoc:**
```asciidoc
:_mod-docs-content-type: CONCEPT
[id="ptp-elements_{context}"]
= Elements of a PTP domain

[role="_abstract"]
PTP is used to synchronize multiple nodes connected in a network.

Grandmaster clock:: The grandmaster clock provides standard time information.

Boundary clock:: The boundary clock has ports in two or more communication paths.

Ordinary clock:: The ordinary clock has a single port connection.
```

**modules/ptp-advantages-over-ntp.adoc:**
```asciidoc
:_mod-docs-content-type: CONCEPT
[id="ptp-advantages-over-ntp_{context}"]
= Advantages of PTP over NTP

[role="_abstract"]
One of the main advantages that PTP has over NTP is the hardware support.
```

**Assembly (about-ptp.adoc):**
```asciidoc
include::modules/nw-ptp-introduction.adoc[leveloffset=+1]

include::modules/ptp-advantages-over-ntp.adoc[leveloffset=+2]
```

## Usage

```bash
# Analyze a module for nested sections
ruby dita-tools/skills/dita-split-nested-section/scripts/split_nested_section.rb <file.adoc>

# Analyze with JSON output
ruby dita-tools/skills/dita-split-nested-section/scripts/split_nested_section.rb <file.adoc> --json

# Split nested sections (dry run)
ruby dita-tools/skills/dita-split-nested-section/scripts/split_nested_section.rb <file.adoc> --split --dry-run

# Split and update assembly
ruby dita-tools/skills/dita-split-nested-section/scripts/split_nested_section.rb <file.adoc> --split --assembly <assembly.adoc>
```

## Behavior notes

- **Skips assemblies**: Files with `:_mod-docs-content-type: ASSEMBLY` or `include::` directives are skipped
- **Preserves IDs**: Existing `[id="..."]` attributes are preserved; new IDs are generated from titles if missing
- **Detects discrete headings**: `[discrete]` headings are not treated as nested sections (they are presentational only)
- **Content type inference**: Suggests CONCEPT, PROCEDURE, or REFERENCE based on heading keywords

## Related Vale rule

This skill addresses: `.vale/styles/AsciiDocDITA/NestedSection.yml`
