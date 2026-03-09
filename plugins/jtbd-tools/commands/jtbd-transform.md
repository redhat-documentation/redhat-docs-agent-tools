---
description: Run the JTBD transformation workflow to analyze and rewrite AsciiDoc documentation from feature-centric to outcome-oriented
argument-hint: <assembly-or-module.adoc>
allowed-tools: Read, Write, Glob, Grep, Edit, Bash, Skill, TodoWrite, Agent
---

# JTBD Transform Workflow

Run all 5 JTBD skills against an AsciiDoc assembly or module to analyze and transform documentation from feature-centric to outcome-oriented.

## Required Argument

- **file**: (required) Path to an AsciiDoc assembly or module file (e.g., `guides/networking/master.adoc`)

**IMPORTANT**: This command requires a file path. If no argument is provided, stop and ask the user to provide one.

## Workflow Overview

This command runs the following steps, using **parallel subagents** for per-file operations when processing multiple files:

1. **Validate input** - check file exists, determine if assembly or module
2. **Create git branch** - `<parent-dir>-jtbd-transform`
3. **Discover files** - find all included files (if assembly)
4. **jtbd-identify** - identify jobs for each file (**parallel** across files)
5. **jtbd-job-map** - map modules to Universal Job Map steps (assembly only, sequential)
6. **jtbd-rewrite** - rewrite each file (**parallel** across files, commits sequential after)
7. **jtbd-categorize** - categorize modules into JTBD categories (assembly only, sequential)
8. **jtbd-gap-analysis** - analyze procedures for gaps (**parallel** across files)
9. **Push branch** - push to origin
10. **Write summary** - consolidated report

## Step-by-Step Instructions

### Step 1: Validate Input

```bash
# Check if the file exists
test -f "${1}" && echo "File exists: ${1}" || echo "ERROR: File not found: ${1}"
```

If the file does not exist, STOP and inform the user.

Determine whether the file is an assembly or a single module:
- Assembly: contains 2+ `include::` directives
- Module: everything else

```bash
# Count includes
INCLUDE_COUNT=$(grep -c '^include::' "${1}" 2>/dev/null || echo 0)
if [ "$INCLUDE_COUNT" -ge 2 ]; then
    echo "Detected: Assembly ($INCLUDE_COUNT includes)"
    IS_ASSEMBLY=true
else
    echo "Detected: Module"
    IS_ASSEMBLY=false
fi
```

### Step 2: Create Git Branch

Derive the branch name from the file path:

```bash
FILE_PATH="${1}"
PARENT_DIR=$(dirname "${FILE_PATH}")
BRANCH_NAME="${PARENT_DIR//\//-}-jtbd-transform"

# Create and checkout the new branch
git checkout -b "${BRANCH_NAME}"
```

### Step 3: Discover Files

For assemblies, find all included files. Try `dita-includes` first (if available), fall back to grep-based discovery.

```bash
# Try dita-includes if available
DITA_INCLUDES_SCRIPT="${CLAUDE_PLUGIN_ROOT}/../dita-tools/skills/dita-includes/scripts/find_includes.sh"
if [ -f "$DITA_INCLUDES_SCRIPT" ]; then
    ASSEMBLY_ABS=$(realpath "${FILE_PATH}")
    bash "$DITA_INCLUDES_SCRIPT" "${ASSEMBLY_ABS}" --existing > /tmp/jtbd-transform-files.txt
else
    # Fallback: grep-based discovery
    realpath "${FILE_PATH}" > /tmp/jtbd-transform-files.txt
    BASE_DIR=$(dirname "$(realpath "${FILE_PATH}")")
    grep -oP '(?<=include::)[^\[]+' "${FILE_PATH}" | while read -r inc; do
        RESOLVED="$BASE_DIR/$inc"
        if [ -f "$RESOLVED" ]; then
            realpath "$RESOLVED" >> /tmp/jtbd-transform-files.txt
        fi
    done
fi

# Display the file list
echo "Files to process:"
cat /tmp/jtbd-transform-files.txt
FILE_COUNT=$(wc -l < /tmp/jtbd-transform-files.txt)
echo "Total: $FILE_COUNT files"
```

For single modules, just use the input file:

```bash
realpath "${FILE_PATH}" > /tmp/jtbd-transform-files.txt
```

### Step 4: JTBD Identify (parallel across files)

Run the identification script on each file and collect job statements. When processing **2 or more files**, spawn parallel subagents.

#### Parallel execution (multiple files)

Spawn one subagent per file **in a single message**:

```
Agent(subagent_type="general-purpose", model="haiku", description="jtbd-identify file1",
  prompt="Run the jtbd-identify script and analyze the result:
  1. Run: ruby <plugin_root>/skills/jtbd-identify/scripts/jtbd_identify.rb <file1_path> --json
  2. Read the file to understand its content
  3. Produce a job statement in this format:
     FILE: <filepath>
     EXECUTOR: <role>
     JOB: <job description>
     STATEMENT: When [situation], I want to [motivation], so I can [expected outcome].
  Return only the job statement block.")

Agent(subagent_type="general-purpose", model="haiku", description="jtbd-identify file2", prompt="...")
# ... one per file
```

After all subagents return, merge their job statements into `/tmp/jtbd-transform-jobs.md`.

#### Sequential execution (single file)

```bash
ruby ${CLAUDE_PLUGIN_ROOT}/skills/jtbd-identify/scripts/jtbd_identify.rb "$file" --json
```

Analyze the file's metadata and produce a job statement. Write to `/tmp/jtbd-transform-jobs.md`.

#### Output format

For each file, produce a YAML block:

```yaml
# <filename>
executor: "<role>"
job: "<job description>"
statement: "When [situation], I want to [motivation], so I can [expected outcome]."
```

### Step 5: JTBD Job Map (Assembly Only)

If the input is an assembly, map modules to the Universal Job Map.

```bash
ruby ${CLAUDE_PLUGIN_ROOT}/skills/jtbd-job-map/scripts/jtbd_job_map.rb "${FILE_PATH}" --json
```

Use the LLM to map each module to the 8 Universal Job Map steps. Write the mapping to `/tmp/jtbd-transform-job-map.md`.

This step is analysis only — no file modifications.

### Step 6: JTBD Rewrite (parallel across files)

Run the rewrite analysis on each file, then apply edits. When processing **2 or more files**, spawn parallel subagents for the rewrites. Each subagent edits only its assigned file.

#### Parallel execution (multiple files)

Spawn one subagent per file **in a single message**:

```
Agent(subagent_type="general-purpose", description="jtbd-rewrite file1",
  prompt="You are a JTBD rewrite specialist. Rewrite this file from feature-centric to outcome-oriented.

  1. Run: ruby <plugin_root>/skills/jtbd-rewrite/scripts/jtbd_rewrite.rb <file1_path> --json
  2. Read the file to understand its content
  3. Apply outcome-oriented rewrites using the Edit tool:
     - Rewrite titles from noun-based to verb-based outcome titles
     - Transform parameter tables to include trade-off columns
     - Add verification commands to prerequisites
     - Improve vague verification sections with concrete criteria
  4. CRITICAL: Do NOT change command syntax, code blocks, technical parameter names,
     API endpoints, or file paths. Only change titles, table structure, prerequisite text,
     and verification text.
  5. Return a summary:
     FILE: <filepath>
     CHANGES:
     - <change description>
     - <change description>
  ")

Agent(subagent_type="general-purpose", description="jtbd-rewrite file2", prompt="...")
# ... one per file
```

**Note**: Use `subagent_type="general-purpose"` without specifying `model: "haiku"` — rewrites need the full model for quality.

After all subagents return, commit each modified file sequentially:

```bash
git add "$file" && git commit -m "jtbd-rewrite: Outcome-oriented rewrite of $(basename "$file")

Applied JTBD rewrite skill to transform content from feature-centric to
outcome-oriented style.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

#### Sequential execution (single file)

```bash
ruby ${CLAUDE_PLUGIN_ROOT}/skills/jtbd-rewrite/scripts/jtbd_rewrite.rb "$file" --json
```

1. Run the script to identify rewrite opportunities
2. Use the LLM to apply outcome-oriented rewrites
3. Use the Edit tool to apply changes
4. Commit the file

**CRITICAL**: Do NOT change command syntax, code blocks, technical parameter names, API endpoints, or file paths. Only change titles, table structure, prerequisite text, and verification text.

### Step 7: JTBD Categorize (Assembly Only)

If the input is an assembly, categorize modules into JTBD categories.

```bash
ruby ${CLAUDE_PLUGIN_ROOT}/skills/jtbd-categorize/scripts/jtbd_categorize.rb "${FILE_PATH}" --json
```

Use the LLM to classify each module into the 7 JTBD categories. Write the categorization report to `/tmp/jtbd-transform-categorization.md`.

This step is analysis only — no file modifications or TOC reordering.

### Step 8: JTBD Gap Analysis (parallel across procedure files)

Run gap analysis on procedure files. When there are **2 or more procedure files**, spawn parallel subagents.

#### Identify procedure files

```bash
# Filter for procedure files only
while read -r file; do
    if grep -q ':_mod-docs-content-type: PROCEDURE' "$file" 2>/dev/null; then
        echo "$file"
    fi
done < /tmp/jtbd-transform-files.txt > /tmp/jtbd-transform-procedures.txt

PROC_COUNT=$(wc -l < /tmp/jtbd-transform-procedures.txt)
echo "Procedure files for gap analysis: $PROC_COUNT"
```

#### Parallel execution (multiple procedure files)

Spawn one subagent per procedure file **in a single message**:

```
Agent(subagent_type="general-purpose", model="haiku", description="gap-analysis file1",
  prompt="Run gap analysis on this procedure file:
  1. Run: ruby <plugin_root>/skills/jtbd-gap-analysis/scripts/jtbd_gap_analysis.rb <file1_path> --json
  2. Read the file and review the script output
  3. Analyze for 6 gap types: missing prerequisites, unclear steps, missing verification,
     missing error handling, missing rollback, missing context
  4. Return findings as:
     FILE: <filepath>
     GAPS:
     - SEVERITY: high/medium/low
       TYPE: <gap type>
       DESCRIPTION: <description>
       RECOMMENDATION: <recommendation>
  ")

Agent(subagent_type="general-purpose", model="haiku", description="gap-analysis file2", prompt="...")
```

#### Sequential execution (single procedure file)

```bash
ruby ${CLAUDE_PLUGIN_ROOT}/skills/jtbd-gap-analysis/scripts/jtbd_gap_analysis.rb "$file" --json
```

After all results are collected, merge into the consolidated gap report at `/tmp/jtbd-transform-gaps.md`.

This step is analysis only — no file modifications.

### Step 9: Push Branch

```bash
git push -u origin "${BRANCH_NAME}"
```

### Step 10: Write Summary

Write a consolidated summary to `/tmp/jtbd-transform-summary.md` using the Write tool.

```markdown
# JTBD Transform Summary

## Input
- File: <file_path>
- Type: Assembly / Module
- Files processed: <count>
- Branch: <branch_name>

## Job Statements

<Include job statements from Step 4>

## Job Map Coverage (Assembly Only)

| Job Map Step | Coverage | Modules |
|-------------|----------|---------|
| Define | Full/Partial/GAP | <modules> |
| Locate | ... | ... |
| ... | ... | ... |

## Rewrites Applied

| File | Changes |
|------|---------|
| <file> | Title rewritten, trade-off table added |
| ... | ... |

## JTBD Categorization (Assembly Only)

| Category | Count | Modules |
|----------|-------|---------|
| Discover | ... | ... |
| ... | ... | ... |

## Gap Analysis

| Severity | Count |
|----------|-------|
| High | <n> |
| Medium | <n> |
| Low | <n> |

### Top Gaps

<List the high-severity gaps with recommendations>

## Generated Reports

- Job statements: `/tmp/jtbd-transform-jobs.md`
- Job map: `/tmp/jtbd-transform-job-map.md`
- Categorization: `/tmp/jtbd-transform-categorization.md`
- Gap analysis: `/tmp/jtbd-transform-gaps.md`

---
Generated with [Claude Code](https://claude.com/claude-code)
```

After writing, inform the user:

```
Branch pushed: ${BRANCH_NAME}

Summary written to /tmp/jtbd-transform-summary.md

Reports:
  /tmp/jtbd-transform-jobs.md          - Job statements
  /tmp/jtbd-transform-job-map.md       - Universal Job Map
  /tmp/jtbd-transform-categorization.md - JTBD categories
  /tmp/jtbd-transform-gaps.md          - Gap analysis

Copy the summary to clipboard:
  cat /tmp/jtbd-transform-summary.md | xclip -selection clipboard
```

## Usage Examples

```bash
# Transform an assembly
/jtbd-tools:jtbd-transform guides/networking/master.adoc

# Transform a single module
/jtbd-tools:jtbd-transform modules/configuring-egress-ips.adoc
```

## Notes

- **Per-file operations run in parallel** using subagents when processing multiple files (Steps 4, 6, 8)
- Assembly-level operations (Steps 5, 7) run sequentially as they analyze the whole assembly
- The rewrite step (Step 6) is the only step that modifies files
- Commits are created sequentially after parallel rewrites complete
- Steps 4, 5, 7, and 8 produce analysis reports only
- Each rewrite is committed individually for easy rollback
- The workflow preserves all technical content (commands, code, parameters)
- If any skill fails, the workflow continues with remaining skills
