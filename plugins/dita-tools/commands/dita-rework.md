---
description: Run the DITA rework workflow to prepare AsciiDoc files for DITA conversion
argument-hint: <assembly.adoc>
allowed-tools: Read, Write, Glob, Grep, Edit, Bash, Skill, TodoWrite
---

# DITA Rework Workflow

Run a suite of DITA cleanup tools against an AsciiDoc assembly and all its included files, preparing them for DITA conversion.

## Required Argument

- **assembly**: (required) Path to an AsciiDoc assembly file (e.g., `working-on-projects/master.adoc`)

**IMPORTANT**: This command requires an assembly file path. If no argument is provided, stop and ask the user to provide one.

## Workflow Overview

This command runs the following steps in sequence:

1. **Setup**: Create a git branch for the rework
2. **Discovery**: Find all included files using `dita-includes`
3. **Baseline**: Run Vale with AsciiDocDITA rules to establish baseline
4. **Remediation**: Run DITA cleanup skills in sequence, committing after each
5. **Validation**: Run Vale again to compare results
6. **Push**: Push the branch to origin
7. **Summary**: Write a summary file for use in PR/MR description

## Step-by-Step Instructions

### Step 1: Validate Input

First, verify the assembly file exists:

```bash
# Check if the file exists
test -f "${1}" && echo "File exists: ${1}" || echo "ERROR: File not found: ${1}"
```

If the file does not exist, STOP and inform the user.

### Step 2: Create Git Branch

Derive the branch name from the assembly path:

1. Take the parent directory of the assembly file
2. Replace `/` with `-`
3. Append `-dita-rework`

Example: `working-on-projects/master.adoc` → `working-on-projects-dita-rework`

```bash
# Get the parent directory path relative to repository root
ASSEMBLY_PATH="${1}"
PARENT_DIR=$(dirname "${ASSEMBLY_PATH}")
BRANCH_NAME="${PARENT_DIR//\//-}-dita-rework"

# Create and checkout the new branch
git checkout -b "${BRANCH_NAME}"
```

### Step 3: Discover Included Files

Use the `dita-includes` skill to build a list of all files referenced by the assembly:

```bash
# Get absolute path of the assembly
ASSEMBLY_ABS=$(realpath "${ASSEMBLY_PATH}")

# Find all includes recursively, filter to .adoc files only
bash ${CLAUDE_PLUGIN_ROOT}/skills/dita-includes/scripts/find_includes.sh "${ASSEMBLY_ABS}" --existing | grep '\.adoc$' > /tmp/dita-rework-files.txt

# Display the file list
cat /tmp/dita-rework-files.txt
```

Store this list for use in subsequent steps.

### Step 4: Run Baseline Vale Check

Use the `dita-validate-asciidoc` skill to run Vale with AsciiDocDITA rules against all files.

**IMPORTANT**: The following rules are informational only and should be excluded from before/after counts (but listed separately):
- `ConditionalCode` - ifdef/ifndef directives
- `AttributeReference` - attribute references
- `IncludeDirective` - include directives
- `TagDirective` - tag directives

```bash
# Run dita-validate-asciidoc to get all AsciiDocDITA issues
bash ${CLAUDE_PLUGIN_ROOT}/skills/dita-validate-asciidoc/scripts/validate_asciidoc.sh "${ASSEMBLY_PATH}" --existing > /tmp/dita-rework-vale-before-all.txt

# Separate actionable issues from informational issues
grep -v -E "AsciiDocDITA\.(ConditionalCode|AttributeReference|IncludeDirective|TagDirective)" /tmp/dita-rework-vale-before-all.txt > /tmp/dita-rework-vale-before.txt || true
grep -E "AsciiDocDITA\.(ConditionalCode|AttributeReference|IncludeDirective|TagDirective)" /tmp/dita-rework-vale-before-all.txt > /tmp/dita-rework-vale-before-info.txt || true

# Count issues
echo "Baseline AsciiDocDITA issues (actionable): $(wc -l < /tmp/dita-rework-vale-before.txt)"
echo "Baseline AsciiDocDITA issues (informational): $(wc -l < /tmp/dita-rework-vale-before-info.txt)"
```

If Vale is not available, skip this step with a warning.

### Step 5: Run DITA Cleanup Skills

Run each skill in sequence against all files. After each skill completes, create a git commit.

**CRITICAL**: Use `--auto` for dita-callouts (defaults to definition list format).

#### 5a. dita-content-type

```bash
# For each file in the list
while read -r file; do
    ruby ${CLAUDE_PLUGIN_ROOT}/skills/dita-content-type/scripts/content_type.rb "$file"
done < /tmp/dita-rework-files.txt

# Commit changes
git add -A && git commit -m "dita-content-type: Add :_mod-docs-content-type: attributes

Applied dita-content-type skill to detect and add content type attributes
(CONCEPT, PROCEDURE, REFERENCE, ASSEMBLY, SNIPPET) for DITA compatibility.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

#### 5b. dita-document-id

```bash
while read -r file; do
    ruby ${CLAUDE_PLUGIN_ROOT}/skills/dita-document-id/scripts/document_id.rb "$file"
done < /tmp/dita-rework-files.txt

git add -A && git commit -m "dita-document-id: Add missing document IDs

Applied dita-document-id skill to generate and insert missing anchor IDs
for document titles. IDs follow AsciiDoc conventions with _{context} suffix
for modules.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

#### 5c. dita-callouts

```bash
# For each file in the list
while read -r file; do
    ruby ${CLAUDE_PLUGIN_ROOT}/skills/dita-callouts/scripts/callouts.rb "$file" --auto
done < /tmp/dita-rework-files.txt

# Commit changes
git add -A && git commit -m "dita-callouts: Transform callouts to definition lists

Applied dita-callouts skill to convert callout markers to definition
lists with where: prefix for DITA compatibility.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

#### 5d. dita-entity-reference

```bash
while read -r file; do
    ruby ${CLAUDE_PLUGIN_ROOT}/skills/dita-entity-reference/scripts/entity_reference.rb "$file"
done < /tmp/dita-rework-files.txt

git add -A && git commit -m "dita-entity-reference: Replace HTML entities with Unicode

Applied dita-entity-reference skill to replace HTML character entity
references with Unicode equivalents for DITA compatibility.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

#### 5e. dita-line-break

```bash
while read -r file; do
    ruby ${CLAUDE_PLUGIN_ROOT}/skills/dita-line-break/scripts/line_break.rb "$file"
done < /tmp/dita-rework-files.txt

git add -A && git commit -m "dita-line-break: Remove hard line breaks

Applied dita-line-break skill to remove hard line breaks and
[%hardbreaks] options for DITA compatibility.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

#### 5f. dita-related-links

```bash
while read -r file; do
    ruby ${CLAUDE_PLUGIN_ROOT}/skills/dita-related-links/scripts/related_links.rb "$file"
done < /tmp/dita-rework-files.txt

git add -A && git commit -m "dita-related-links: Clean up Additional resources sections

Applied dita-related-links skill to fix Additional resources sections
by removing or relocating non-link content for DITA compatibility.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

#### 5g. dita-add-shortdesc-abstract

```bash
while read -r file; do
    ruby ${CLAUDE_PLUGIN_ROOT}/skills/dita-add-shortdesc-abstract/scripts/short_description.rb "$file"
done < /tmp/dita-rework-files.txt

git add -A && git commit -m "dita-add-shortdesc-abstract: Add [role=\"_abstract\"] attributes

Applied dita-add-shortdesc-abstract skill to add missing [role=\"_abstract\"]
attributes for DITA short description support.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

#### 5h. dita-task-contents

```bash
while read -r file; do
    ruby ${CLAUDE_PLUGIN_ROOT}/skills/dita-task-contents/scripts/task_contents.rb "$file"
done < /tmp/dita-rework-files.txt

git add -A && git commit -m "dita-task-contents: Add .Procedure block titles

Applied dita-task-contents skill to add missing .Procedure block titles
to procedure modules for DITA compatibility.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

#### 5i. dita-task-step

```bash
while read -r file; do
    ruby ${CLAUDE_PLUGIN_ROOT}/skills/dita-task-step/scripts/task_step.rb "$file"
done < /tmp/dita-rework-files.txt

git add -A && git commit -m "dita-task-step: Fix list continuations in procedure steps

Applied dita-task-step skill to add list continuation markers (+)
for multi-block step content in procedures.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

#### 5j. dita-task-title

```bash
while read -r file; do
    ruby ${CLAUDE_PLUGIN_ROOT}/skills/dita-task-title/scripts/task_title.rb "$file"
done < /tmp/dita-rework-files.txt

git add -A && git commit -m "dita-task-title: Remove unsupported block titles

Applied dita-task-title skill to remove unsupported block titles from
procedure modules for DITA compatibility.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

#### 5k. dita-block-title

```bash
while read -r file; do
    ruby ${CLAUDE_PLUGIN_ROOT}/skills/dita-block-title/scripts/block_title.rb "$file"
done < /tmp/dita-rework-files.txt

git add -A && git commit -m "dita-block-title: Fix unsupported block titles

Applied dita-block-title skill to convert or remove block titles that
are not valid in DITA (only examples, figures, and tables support titles).

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

### Step 6: Validate Changes and Count Fixed Errors

Run `dita-validate-asciidoc` again and compare with the baseline to validate the remediation work.

**IMPORTANT**: Exclude informational rules (ConditionalCode, AttributeReference, IncludeDirective, TagDirective) from before/after counts. List them separately.

```bash
# Run dita-validate-asciidoc to get all AsciiDocDITA issues
bash ${CLAUDE_PLUGIN_ROOT}/skills/dita-validate-asciidoc/scripts/validate_asciidoc.sh "${ASSEMBLY_PATH}" --existing > /tmp/dita-rework-vale-after-all.txt

# Separate actionable issues from informational issues
grep -v -E "AsciiDocDITA\.(ConditionalCode|AttributeReference|IncludeDirective|TagDirective)" /tmp/dita-rework-vale-after-all.txt > /tmp/dita-rework-vale-after.txt || true
grep -E "AsciiDocDITA\.(ConditionalCode|AttributeReference|IncludeDirective|TagDirective)" /tmp/dita-rework-vale-after-all.txt > /tmp/dita-rework-vale-after-info.txt || true

# Count actionable issues before and after
BEFORE_COUNT=$(wc -l < /tmp/dita-rework-vale-before.txt)
AFTER_COUNT=$(wc -l < /tmp/dita-rework-vale-after.txt)
FIXED_COUNT=$((BEFORE_COUNT - AFTER_COUNT))

# Count informational issues
INFO_COUNT=$(wc -l < /tmp/dita-rework-vale-after-info.txt)
```

#### Analyze remaining actionable issues

If actionable issues remain after remediation, categorize them by rule and capture full details:

```bash
# Group remaining actionable issues by rule
echo "Remaining actionable issues by rule:"
grep -oE "AsciiDocDITA\.[A-Za-z]+" /tmp/dita-rework-vale-after.txt | sort | uniq -c | sort -rn

# Display full issue details (file:line:col: severity: [Rule] Message)
echo ""
echo "Issue details:"
cat /tmp/dita-rework-vale-after.txt
```

The Vale output format is: `file:line:col: severity: [Rule] Message`

Parse this to extract:
- **File**: The file path (before first `:`)
- **Line**: The line number (between first and second `:`)
- **Rule**: The rule name in brackets (e.g., `AsciiDocDITA.ShortDescription`)
- **Message**: The descriptive message after the rule name

#### Why issues remain unprocessed

For each remaining issue, determine why it was not fixed by the automated scripts:

| Rule | Reason Not Auto-Fixed |
|------|----------------------|
| **ShortDescription** | Abstract paragraph needs human judgment to write meaningful content |
| **TaskStep** | Complex nested content requires manual review of list structure |
| **BlockTitle** | Ambiguous whether title should become figure caption, example title, or be removed |
| **CalloutList** | Callouts in non-standard format or complex nesting not handled by script |
| **EntityReference** | Entity in attribute, URL, or other context where replacement might break functionality |
| **DocumentId** | ID generation skipped due to complex title or existing conflicting ID |
| **RelatedLinks** | Mixed content in Additional resources requires human decision on what to keep |

Document specific reasons for each remaining issue in the PR/MR description to guide manual remediation.

#### Analyze informational issues

List the informational issues separately (these don't count toward fixed/remaining):

```bash
# Group informational issues by rule
echo "Informational issues (excluded from counts):"
grep -oE "AsciiDocDITA\.[A-Za-z]+" /tmp/dita-rework-vale-after-info.txt | sort | uniq -c | sort -rn
```

**IMPORTANT**: Review any remaining actionable AsciiDocDITA issues. Some may require manual intervention that the automated scripts cannot handle. Document these in the PR/MR description.

### Step 7: Push Branch

Push the branch to the remote:

```bash
# Push the branch
git push -u origin "${BRANCH_NAME}"
```

Inform the user that the branch has been pushed and they can create a PR/MR when ready.

### Step 8: Write Workflow Summary to File

After completing all steps, write a markdown-formatted summary to a file so the user can copy it for the PR/MR description.

**IMPORTANT**: Use the Write tool to create or overwrite the file `/tmp/dita-rework-pr-summary.md` with the raw markdown content. Do NOT output the summary directly to the CLI as it will be rendered instead of shown as copyable text.

#### Generating the Issue Details table

Before writing the summary, parse the remaining Vale issues to populate the Issue Details table:

1. Read `/tmp/dita-rework-vale-after.txt` which contains lines in Vale output format:
   ```
   file:line:col: severity: [AsciiDocDITA.RuleName] Message text here
   ```

2. For each line, extract:
   - **File:Line**: The file path and line number (before the second `:`)
   - **Rule**: The rule name from brackets (e.g., `ShortDescription` from `[AsciiDocDITA.ShortDescription]`)
   - **Message**: The text after the rule name

3. Look up the "Why Not Auto-Fixed" reason based on the rule name using this mapping:
   - **ShortDescription** → Abstract paragraph needs human judgment to write meaningful content
   - **TaskStep** → Complex nested content requires manual review of list structure
   - **BlockTitle** → Ambiguous whether title should become figure caption, example title, or be removed
   - **CalloutList** → Callouts in non-standard format or complex nesting not handled by script
   - **EntityReference** → Entity in attribute, URL, or other context where replacement might break functionality
   - **DocumentId** → ID generation skipped due to complex title or existing conflicting ID
   - **RelatedLinks** → Mixed content in Additional resources requires human decision on what to keep
   - **Other rules** → Requires manual review

4. Generate a table row for EACH remaining issue (not just one placeholder row)

Write the following template to `/tmp/dita-rework-pr-summary.md`, replacing placeholders with actual values:

```
## Summary

Prepared AsciiDoc files in `<parent_dir>/` for DITA conversion by running the DITA rework workflow.

## Changes Applied

The following DITA cleanup skills were applied in sequence:

1. **dita-content-type**: Added :_mod-docs-content-type: attributes (<count> files)
2. **dita-document-id**: Added missing document IDs (<count> files)
3. **dita-callouts**: Transformed callouts to definition lists (<count> files)
4. **dita-entity-reference**: <status>
5. **dita-line-break**: <status>
6. **dita-related-links**: Cleaned up Additional resources sections (<count> files)
7. **dita-short-description**: Added [role="_abstract"] attributes (<count> files)
8. **dita-task-contents**: <status>
9. **dita-task-step**: Fixed list continuations in procedure steps (<count> files)
10. **dita-task-title**: Removed unsupported block titles (<count> files)
11. **dita-block-title**: Fixed unsupported block titles (<count> files)

## Files Processed

<file_count> files were processed from the assembly and its includes.

## Vale Validation Results (Actionable Issues Only)

| Metric | Count |
|--------|-------|
| Issues before | <before_count> |
| Issues after | <after_count> |
| **Fixed** | **<fixed_count>** |
| Improvement | <percent>% |

### Remaining Actionable Issues

| Rule | Count |
|------|-------|
| <rule_name> | <count> |

#### Issue Details

<!-- Generate one row per issue from /tmp/dita-rework-vale-after.txt -->
<!-- IMPORTANT: Use the FULL relative file path exactly as it appears in Vale output. Do NOT abbreviate or truncate paths with "..." -->
| File:Line | Rule | Message | Why Not Auto-Fixed |
|-----------|------|---------|--------------------|
| upstream/modules/common/backing-up-your-cluster.adoc:42 | ShortDescription | Missing abstract paragraph | Abstract paragraph needs human judgment to write meaningful content |
| upstream/modules/common/configuring-oidc-auth-gateway-api.adoc:15 | BlockTitle | Block title not supported | Ambiguous whether title should become figure caption, example title, or be removed |
<!-- ... one row for each remaining issue, using FULL relative file paths from Vale output ... -->

**Common reasons issues are not auto-fixed:**
- **ShortDescription**: Abstract paragraph needs human judgment to write meaningful content
- **TaskStep**: Complex nested content requires manual review of list structure
- **BlockTitle**: Ambiguous whether title should become figure caption, example title, or be removed
- **CalloutList**: Callouts in non-standard format or complex nesting not handled by script
- **EntityReference**: Entity in attribute, URL, or other context where replacement might break functionality
- **DocumentId**: ID generation skipped due to complex title or existing conflicting ID
- **RelatedLinks**: Mixed content in Additional resources requires human decision on what to keep

### Informational Issues (Excluded from Counts)

The following issues are informational only and excluded from the before/after counts:

| Rule | Count |
|------|-------|
| AsciiDocDITA.ConditionalCode | <count> |
| AsciiDocDITA.AttributeReference | <count> |
| AsciiDocDITA.IncludeDirective | <count> |
| AsciiDocDITA.TagDirective | <count> |

**Note:** Informational issues represent conditional content, attribute references, and include directives that may need manual review for DITA conversion but are not errors.

## Test Plan

- [ ] Verify the AsciiDoc renders correctly
- [ ] Run DITA conversion on the modified files
- [ ] Review definition lists created from callouts
- [ ] Review block title conversions

---
Generated with [Claude Code](https://claude.com/claude-code)
```

After writing the file, inform the user:

```
Branch pushed: ${BRANCH_NAME}

Summary written to /tmp/dita-rework-pr-summary.md

Copy the summary to clipboard:
  cat /tmp/dita-rework-pr-summary.md | xclip -selection clipboard

Suggested MR/PR title:
  Claude Code DITA rework run for <relative_assembly_path>

Create the MR/PR and paste the rework summary into the description field.
```

Replace `<relative_assembly_path>` with the original assembly path argument (e.g., `self-managed-managing-rhoai/master.adoc`).

## Usage Examples

```bash
# Run DITA rework on an assembly
/dita-tools:dita-rework working-on-projects/master.adoc

# Run on a nested assembly
/dita-tools:dita-rework guides/administration/master.adoc
```

## Notes

- Each skill is run in sequence to avoid conflicts
- A commit is created after each skill for easy rollback
- The workflow requires ruby for running the DITA scripts
- Vale is optional but recommended for tracking improvements
- If any skill fails, the workflow continues with remaining skills
- Empty commits (no changes) are skipped automatically
