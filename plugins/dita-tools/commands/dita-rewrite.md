---
description: Run the DITA rewrite workflow to fix issues through intelligent LLM-guided content rewriting
argument-hint: <file.adoc> [--no-commit] [--dry-run] [--branch <name>]
allowed-tools: Read, Write, Glob, Grep, Edit, Bash, Skill, TodoWrite, Agent
---

# DITA Rewrite Workflow

Run Vale to identify AsciiDocDITA issues and use LLM-guided refactoring to fix them through intelligent content rewriting. This workflow creates commits and PR/MR for version control.

## Required Argument

- **file**: (required) Path to an AsciiDoc module, assembly, or folder (e.g., `modules/con-overview.adoc` or `assemblies/installing.adoc`)

**IMPORTANT**: This command requires a file path. If no argument is provided, stop and ask the user to provide one.

## Options

| Option | Description |
|--------|-------------|
| `--no-commit` | Skip commit creation |
| `--dry-run` | Show what would be done without making changes |
| `--branch <name>` | Use custom branch name (default: auto-generated) |
| `--from-commit <sha>` | Get file list from a commit instead of from includes/folder. Only files that exist on the current branch are processed. Use for backporting fixes across enterprise branches. |

## Workflow Overview

1. **Setup**: Validate input, create working branch
2. **Discover**: If assembly, find all included files using `dita-includes`
3. **Baseline**: Run Vale to establish issue count
4. **Rewrite**: Use LLM-guided refactoring to fix issues — **parallel subagents for multiple files**, sequential for single files
5. **Validate**: Run Vale to confirm issues are resolved
6. **Commit**: Create per-file commits with issue summary (sequential after parallel rewrites)
7. **Push**: Push the branch to origin
8. **Summary**: Write a summary file for use in PR/MR description

---

## Phase 1: Setup and Analysis

### Step 1: Validate Input

```bash
# Check for required argument (file path OR --from-commit)
if [ -z "${1}" ] && [ -z "${FROM_COMMIT}" ]; then
    echo "ERROR: No file path or --from-commit provided"
    echo "Usage: /dita-tools:dita-rewrite <file.adoc> [options]"
    echo "       /dita-tools:dita-rewrite --from-commit <sha> [options]"
    exit 1
fi

# If a file/folder argument is provided, verify it exists
if [ -n "${1}" ]; then
    test -f "${1}" -o -d "${1}" && echo "Input exists: ${1}" || { echo "ERROR: Not found: ${1}"; exit 1; }
fi

# If --from-commit is provided, verify the commit exists
if [ -n "${FROM_COMMIT}" ]; then
    git cat-file -e "${FROM_COMMIT}" 2>/dev/null && echo "Commit exists: ${FROM_COMMIT}" || { echo "ERROR: Commit not found: ${FROM_COMMIT}"; exit 1; }
fi
```

If the file does not exist, STOP and inform the user.

### Step 2: Parse Options

Check for options in the arguments:

- `--no-commit`: Set `NO_COMMIT=true`
- `--dry-run`: Set `DRY_RUN=true`
- `--branch <name>`: Set `BRANCH_NAME=<name>`
- `--from-commit <sha>`: Set `FROM_COMMIT=<sha>` (get file list from commit, filter to files that exist on current branch)

### Step 3: Create Working Branch

Unless `--no-commit` or `--dry-run` is set:

```bash
# Generate branch name from input path
INPUT_NAME=$(basename "${1}" .adoc)
BRANCH_NAME="${BRANCH_NAME:-dita-rewrite-${INPUT_NAME}-$(date +%Y%m%d-%H%M%S)}"

# Create and switch to branch
git checkout -b "$BRANCH_NAME"
echo "Created branch: $BRANCH_NAME"
```

### Step 4: Build File List

Determine input type and build list of files to process:

```bash
# Get absolute path
INPUT_ABS=$(realpath "${1}")

if [ -n "${FROM_COMMIT}" ]; then
    # --from-commit mode: get file list from a specific commit
    echo "Getting file list from commit ${FROM_COMMIT}"
    git diff-tree --no-commit-id --name-only -r "${FROM_COMMIT}" | grep '\.adoc$' > /tmp/dita-rewrite-files-candidate.txt
elif [ -d "${1}" ]; then
    # Folder: find all .adoc files
    echo "Folder detected - finding all AsciiDoc files"
    find "${INPUT_ABS}" -name "*.adoc" -type f > /tmp/dita-rewrite-files-candidate.txt
elif grep -q "^include::" "${1}"; then
    # Assembly: use dita-includes skill
    echo "Assembly detected - discovering includes"
    bash ${CLAUDE_PLUGIN_ROOT}/skills/dita-includes/scripts/find_includes.sh "${INPUT_ABS}" --existing | grep '\.adoc$' > /tmp/dita-rewrite-files-candidate.txt
else
    # Single module
    echo "Module detected"
    echo "${INPUT_ABS}" > /tmp/dita-rewrite-files-candidate.txt
fi
```

#### Step 4a: Verify files exist on the current branch

After building the candidate file list, verify each file actually exists on the current branch. This is critical for **backport workflows** where a source commit may reference files that were introduced in a later version and do not exist on the target enterprise branch.

```bash
# Verify each candidate file exists on the current branch
> /tmp/dita-rewrite-files.txt
> /tmp/dita-rewrite-files-excluded.txt

while read -r filepath; do
    if [ -f "$filepath" ]; then
        echo "$filepath" >> /tmp/dita-rewrite-files.txt
    else
        echo "$filepath" >> /tmp/dita-rewrite-files-excluded.txt
    fi
done < /tmp/dita-rewrite-files-candidate.txt

FILE_COUNT=$(wc -l < /tmp/dita-rewrite-files.txt)
EXCLUDED_COUNT=$(wc -l < /tmp/dita-rewrite-files-excluded.txt)

echo "Files to process: ${FILE_COUNT}"
cat /tmp/dita-rewrite-files.txt

if [ "${EXCLUDED_COUNT}" -gt 0 ]; then
    echo ""
    echo "WARNING: ${EXCLUDED_COUNT} file(s) excluded (not present on current branch):"
    cat /tmp/dita-rewrite-files-excluded.txt
fi
```

**How it works**: `git cat-file -e HEAD:<path>` checks git's object store for a file on the current branch without touching the working directory. For the simpler working-directory case, `[ -f "$filepath" ]` achieves the same result. This prevents the workflow from failing on files that don't exist on the target branch (e.g., modules introduced in 4.20 that don't exist on enterprise-4.16).

### Step 5: Run Vale BEFORE (Baseline)

Use the `dita-validate-asciidoc` skill to run Vale with AsciiDocDITA rules:

```bash
# Create output directory
mkdir -p .claude_docs/vale-reports

# Run dita-validate-asciidoc to get all AsciiDocDITA issues
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
bash ${CLAUDE_PLUGIN_ROOT}/skills/dita-validate-asciidoc/scripts/validate_asciidoc.sh "${1}" --existing > /tmp/dita-rewrite-vale-baseline.txt

# Separate actionable from informational issues
grep -v -E "AsciiDocDITA\.(ConditionalCode|AttributeReference|IncludeDirective|TagDirective|CrossReference)" /tmp/dita-rewrite-vale-baseline.txt > /tmp/dita-rewrite-vale-actionable.txt || true

# Count baseline issues
BASELINE_COUNT=$(wc -l < /tmp/dita-rewrite-vale-actionable.txt)
echo ""
echo "=== Baseline Vale Results ==="
echo "Actionable AsciiDocDITA issues: ${BASELINE_COUNT}"
echo ""
echo "Issues by rule:"
grep -oE "AsciiDocDITA\.[A-Za-z]+" /tmp/dita-rewrite-vale-actionable.txt | sort | uniq -c | sort -rn
```

Save the baseline counts for comparison.

---

## Phase 2: LLM-Guided Refactoring

Apply fixes using the **dita-asciidoc-rewrite skill** instructions. When processing multiple files (assemblies or folders), use **parallel subagents** to rewrite files concurrently.

### Parallel execution (multiple files)

When the file list contains **2 or more files**, spawn parallel subagents to process files concurrently. Each subagent works on a different file, so there are no conflicts.

#### Step 1: Extract per-file Vale issues

Before spawning subagents, split the baseline Vale output into per-file issue lists so each subagent receives only its relevant issues:

```bash
# For each file, extract its Vale issues
while read -r filepath; do
    BASENAME=$(basename "$filepath" .adoc)
    grep "$filepath" /tmp/dita-rewrite-vale-actionable.txt > "/tmp/dita-rewrite-vale-${BASENAME}.txt" 2>/dev/null || true
done < /tmp/dita-rewrite-files.txt
```

#### Step 2: Spawn parallel subagents

Spawn one `Agent` call per file **in a single message** so they execute concurrently:

```
Agent(subagent_type="general-purpose", description="rewrite file1.adoc",
  prompt="You are a DITA rewrite specialist. Read the dita-asciidoc-rewrite skill at
  <plugin_root>/skills/dita-asciidoc-rewrite/SKILL.md for fixing instructions.

  File to rewrite: <file1_path>
  Vale issues for this file:
  <paste contents of /tmp/dita-rewrite-vale-file1.txt>

  Instructions:
  1. Read the file
  2. Read the dita-asciidoc-rewrite SKILL.md for the AI Action plans
  3. For each Vale issue, apply the appropriate fix following the skill instructions
  4. Edit the file in place using the Edit tool
  5. Validate changes maintain document integrity and flow
  6. Return a summary of fixes applied in this format:
     FILE: <filepath>
     FIXED:
     - <issue-type-1>: <description>
     - <issue-type-2>: <description>
     SKIPPED:
     - <issue-type>: <reason>
  ")

Agent(subagent_type="general-purpose", description="rewrite file2.adoc", prompt="...")
Agent(subagent_type="general-purpose", description="rewrite file3.adoc", prompt="...")
# ... one per file
```

**Important subagent guidelines:**
- Each subagent **must read** the `dita-asciidoc-rewrite/SKILL.md` file to get the full fixing instructions
- Each subagent edits only its assigned file — no cross-file edits
- Use `subagent_type="general-purpose"` (not haiku — these rewrites need the full model for quality)
- Maximum ~8 parallel subagents at a time; if more files, batch into groups

#### Step 3: Collect results and commit sequentially

After all subagents return, commit each modified file sequentially:

```bash
# For each file that was modified by a subagent
git add "<file>"
git commit -m "$(cat <<'EOF'
fix(<module-name>): DITA compatibility fixes

- Fixed <issue-type-1>
- Fixed <issue-type-2>
...

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

Track which issues were fixed for each file from the subagent summaries.

### Sequential execution (single file)

When processing a **single file**, run the rewrite directly without subagents:

1. **Read the file** to understand current content and structure
2. **Review Vale issues** for this specific file from the baseline
3. **Apply fixes** following the AI Action plans in the dita-asciidoc-rewrite skill for each issue type:
   - EntityReference, AttributeReference, AuthorLine
   - DocumentId, DocumentTitle, ShortDescription
   - ExampleBlock, TaskExample, NestedSection
   - TaskSection, TaskContents, TaskDuplicate
   - AdmonitionTitle, BlockTitle, ContentType
   - LineBreak, LinkAttribute, TaskStep
   - AssemblyContents, CalloutList, RelatedLinks
4. **Validate** that changes maintain document integrity and flow
5. **Commit** (unless `--no-commit` or `--dry-run`):

```bash
git add "<file>"
git commit -m "$(cat <<'EOF'
fix(<module-name>): DITA compatibility fixes

- Fixed <issue-type-1>
- Fixed <issue-type-2>
...

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

Track which issues were fixed for each file.

---

## Phase 3: Validation and Reporting

### Step 1: Run Vale AFTER

Use the `dita-validate-asciidoc` skill to run Vale again and compare with baseline:

```bash
# Run dita-validate-asciidoc to get final AsciiDocDITA issues
bash ${CLAUDE_PLUGIN_ROOT}/skills/dita-validate-asciidoc/scripts/validate_asciidoc.sh "${1}" --existing > /tmp/dita-rewrite-vale-final.txt

# Separate actionable issues
grep -v -E "AsciiDocDITA\.(ConditionalCode|AttributeReference|IncludeDirective|TagDirective|CrossReference)" /tmp/dita-rewrite-vale-final.txt > /tmp/dita-rewrite-vale-final-actionable.txt || true

FINAL_COUNT=$(wc -l < /tmp/dita-rewrite-vale-final-actionable.txt)
TOTAL_FIXED=$((BASELINE_COUNT - FINAL_COUNT))

echo ""
echo "=== Final Results ==="
echo "Baseline issues: ${BASELINE_COUNT}"
echo "Final issues: ${FINAL_COUNT}"
echo "Total fixed: ${TOTAL_FIXED}"
if [ ${BASELINE_COUNT} -gt 0 ]; then
    echo "Improvement: $(( (TOTAL_FIXED * 100) / BASELINE_COUNT ))%"
fi
```

### Step 2: Write Workflow Summary to File

After completing all steps, write a markdown-formatted summary to a file so the user can copy it for the PR/MR description.

**IMPORTANT**: Use the Write tool to create or overwrite the file `/tmp/dita-rewrite-pr-summary.md` with the raw markdown content. Do NOT output the summary directly to the CLI as it will be rendered instead of shown as copyable text.

#### Generating the Issue Details table

Before writing the summary, parse the remaining Vale issues to populate the Issue Details table:

1. Read `/tmp/dita-rewrite-vale-final-actionable.txt` which contains lines in Vale output format:
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

Write the following template to `/tmp/dita-rewrite-pr-summary.md`, replacing placeholders with actual values:

```
## Summary

Refactored AsciiDoc files in `<input_path>` for DITA conversion compatibility using LLM-guided rewriting.

## Changes Applied

The following DITA issues were fixed through LLM-guided refactoring:

- **EntityReference**: Replaced HTML entities with Unicode equivalents
- **DocumentId**: Added missing document IDs
- **ShortDescription**: Added or improved [role="_abstract"] paragraphs
- **TaskStep**: Fixed list continuations in procedure steps
- **BlockTitle**: Converted or removed unsupported block titles
- **RelatedLinks**: Cleaned up Additional resources sections
- (list all issue types that were actually fixed)

## Files Processed

<file_count> files were processed.

| File | Issues Before | Issues After | Fixed |
|------|---------------|--------------|-------|
| <file1.adoc> | <before> | <after> | <fixed> |
| <file2.adoc> | <before> | <after> | <fixed> |

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

<!-- Generate one row per issue from /tmp/dita-rewrite-vale-final-actionable.txt -->
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
| AsciiDocDITA.CrossReference | <count> |

**Note:** Informational issues represent conditional content, attribute references, cross-references, and include directives that may need manual review for DITA conversion but are not errors.

## Test Plan

- [ ] Verify the AsciiDoc renders correctly
- [ ] Run DITA conversion on the modified files
- [ ] Content meaning preserved
- [ ] Links and cross-references work

---
Generated with [Claude Code](https://claude.com/claude-code)
```

After writing the file, inform the user:

```
Branch pushed: ${BRANCH_NAME}

Summary written to /tmp/dita-rewrite-pr-summary.md

Copy the summary to clipboard:
  cat /tmp/dita-rewrite-pr-summary.md | xclip -selection clipboard

Suggested MR/PR title:
  Claude Code DITA rewrite run for <input_path>

Create the MR/PR and paste the rewrite summary into the description field.
```

Replace `<input_path>` with the original input path argument.

---

## Phase 4: Push Branch

Unless `--no-commit` or `--dry-run` is set:

```bash
git push -u origin "$BRANCH_NAME"
```

Inform the user that the branch has been pushed and they can create a PR/MR when ready.

---

## Usage Examples

```bash
# Single module
/dita-tools:dita-rewrite modules/installing/proc_installing-component.adoc

# Assembly with all includes
/dita-tools:dita-rewrite assemblies/installing.adoc

# Folder of modules
/dita-tools:dita-rewrite modules/configuring/

# Dry run (preview only)
/dita-tools:dita-rewrite modules/installing/ --dry-run

# Custom branch name
/dita-tools:dita-rewrite assemblies/admin.adoc --branch dita-admin-fixes

# Backport from a commit - only process files that exist on the current branch
# (e.g., backporting DITA fixes from main to enterprise-4.16)
git checkout -b TICKET-416-CP upstream/enterprise-4.16
/dita-tools:dita-rewrite --from-commit b80294f08a --no-commit
```

---

## Notes

- This workflow uses **only** LLM-guided refactoring (no automated Ruby scripts)
- The **dita-asciidoc-rewrite skill** provides detailed fixing instructions for 22+ issue types - invoke it with `/dita-tools:dita-asciidoc-rewrite` for the fixing guidelines
- **Multiple files are processed in parallel** using subagents for significantly faster execution
- Single files are processed sequentially (no subagent overhead)
- Each subagent reads the full `dita-asciidoc-rewrite/SKILL.md` for fixing instructions
- Vale is used before and after to measure progress
- Commits are created per-file sequentially after parallel rewrites complete
- Informational issues (AttributeReference, CrossReference, etc.) are reported but not fixed
