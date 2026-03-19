# Design Spec: Hook-Based Docs Orchestrator

**Date**: 2026-03-19
**Status**: Draft
**Scope**: `plugins/docs-tools/`
**Related**: `specs/2026-03-18-docs-workflow-decomposition-design.md` (step skill decomposition)

## Problem

The `docs-workflow` command (`commands/docs-workflow.md`) is a ~1300-line monolithic orchestrator that inlines all stage prompts, state management, JIRA API logic, and control flow into a single markdown file. This causes:

- **Every team gets the same pipeline** — no way to add, remove, or reorder stages without forking the orchestrator
- **New workflows require new orchestrator skills** — a review-only workflow or a simplified onboarding workflow each need their own hardcoded orchestrator
- **No reusability** — individual stages cannot be invoked independently
- **Maintenance burden** — changes to one stage risk breaking others

## Solution

Decompose the monolith into **step skills** orchestrated by Claude's intelligence, with **hooks** as guardrails. Three components:

1. **A workflow skill** (~100 lines) that teaches Claude the standard pipeline and conventions
2. **A Stop hook** that validates workflow completion by checking progress state and file contents
3. **Step skills** that each own one stage of the pipeline

Claude Code already has the primitives to orchestrate workflows without a custom engine:

- **Skills** define what each step does
- **Stop hooks** prevent Claude from finishing until work is complete
- **Agent-based hooks** verify conditions by inspecting files and running commands
- **Compaction hooks** re-inject workflow state after context compaction

No YAML parsing, no template resolution engine, no state management script. Claude reads the skill, understands the pipeline, and executes it. The hook catches incomplete workflows.

## Architecture

```
User: "Write docs for PROJ-123 --pr https://..."
     |
     v
docs-orchestrator skill                 ← Teaches Claude the pipeline
     |
     +-- Claude decides what's needed   ← Intelligence, not a dispatch engine
     |
     +-- Skill: step-1-skill            ← Step skills (existing, independent)
     +-- Skill: step-2-skill
     +-- ...
     |
     v
Stop hook                              ← Validates: is the workflow complete?
     |
     +-- Checks progress.json          ← Status, output paths, content verification
     +-- {ok: true}  → Claude stops
     +-- {ok: false, reason: "..."}  → Claude continues
```

The orchestrator is Claude itself. The skill is a checklist. The hook is a safety net.

## Component Inventory

### New files

```
plugins/docs-tools/skills/
  docs-orchestrator/
    docs-orchestrator.md                      # Workflow skill (~100 lines)
    hooks/
      workflow-completion-check.sh            # Stop hook script (~80 lines)
    scripts/
      setup-hooks.sh                          # Hook installation helper
```

### Step skills

```
plugins/docs-tools/skills/
  docs-workflow-requirements/
    docs-workflow-requirements.md
  docs-workflow-planning/
    docs-workflow-planning.md
  docs-workflow-writing/
    docs-workflow-writing.md
  docs-workflow-tech-review/
    docs-workflow-tech-review.md
  docs-workflow-style-review/
    docs-workflow-style-review.md
  docs-workflow-integrate/
    docs-workflow-integrate.md
  docs-workflow-create-jira/
    docs-workflow-create-jira.md
```

Each step skill follows the step skill contract: parse args, do work, write output. Step skills do **not** manage workflow state — the orchestrator (Claude + progress file) handles all state transitions. The agent definitions in `agents/*.md` remain unchanged.

For full step skill details (agent dispatch, prompts, output paths, iteration logic), see the step skills section below.

### Hook configuration (user setup)

```
.claude/settings.json                         # Stop hook + compaction hook
```

### Existing files (unchanged)

- `commands/docs-workflow.md` — continues to work as-is
- `agents/*.md` — all 6 agent definitions unchanged

## Workflow Skill: `docs-orchestrator.md`

**Location**: `plugins/docs-tools/skills/docs-orchestrator/docs-orchestrator.md`

```markdown
---
name: docs-orchestrator
description: >
  Documentation workflow orchestrator. Runs the full docs pipeline for a
  JIRA ticket: requirements analysis, planning, writing, technical review,
  style review, and optionally integration and JIRA creation.
argument-hint: <ticket> [--pr <url>] [--mkdocs] [--integrate] [--create-jira <PROJECT>]
allowed-tools: Read, Write, Glob, Grep, Edit, Bash, Skill, AskUserQuestion, WebSearch, WebFetch
---

## Pre-flight

Before starting, verify required environment:

1. Source `~/.env` if `JIRA_AUTH_TOKEN` is not set
2. If `JIRA_AUTH_TOKEN` is still unset → STOP and ask the user
3. Warn (don't stop) if `GITHUB_TOKEN` or `GITLAB_TOKEN` are unset

## Parse arguments

- `$1` — JIRA ticket ID (required)
- `--pr <url>` — PR/MR URLs (repeatable, accumulated into a list)
- `--mkdocs` — use Material for MkDocs format instead of AsciiDoc
- `--integrate` — integrate drafts into the repo build framework after review
- `--create-jira <PROJECT>` — create a linked JIRA ticket in the specified project

## Output conventions

All outputs go under `.claude/docs/`:

```
.claude/docs/
  requirements/requirements_<ticket>_<timestamp>.md
  plans/plan_<ticket>_<timestamp>.md
  drafts/<ticket>/
    _index.md
    [modules and assemblies]
    _technical_review.md
    _review_report.md
    _integration_plan.md      (if --integrate)
    _integration_report.md    (if --integrate)
  workflow/
    docs-workflow_<ticket>.json    (progress state)
```

Convert the ticket ID to lowercase for directory names (e.g., `PROJ-123` → `proj-123`).
Use lowercase with underscores for filenames (e.g., `PROJ-123` → `proj_123`).

## Check for existing work

Before starting, check for a progress file at
`.claude/docs/workflow/docs-workflow_<ticket>.json`.

If the progress file exists:
  - Read it and identify which steps have status "completed"
  - Skip completed steps and resume from the first step with status "pending" or "failed"
  - Tell the user: "Found existing work for <ticket>. Resuming from <step>."

If no progress file exists, start from step 1 and create a new progress file.

## Progress file

The progress file tracks workflow state as JSON. Create it at workflow start.
Update it after each step completes.

**Location**: `.claude/docs/workflow/<workflow-type>_<ticket>.json`

The filename includes the workflow type (`docs-workflow`, `review-only`, etc.) to
support multiple workflow types against the same ticket without conflict.

```json
{
  "workflow_type": "docs-workflow",
  "ticket": "PROJ-123",
  "status": "in_progress",
  "created_at": "2026-03-19T10:00:00Z",
  "updated_at": "2026-03-19T12:34:56Z",
  "options": {
    "format": "adoc",
    "integrate": false,
    "create_jira_project": null,
    "pr_urls": []
  },
  "steps": {
    "requirements": {
      "status": "completed",
      "output": ".claude/docs/requirements/requirements_proj_123_20260319_100100.md"
    },
    "planning": {
      "status": "completed",
      "output": ".claude/docs/plans/plan_proj_123_20260319_100500.md"
    },
    "writing": {
      "status": "in_progress",
      "output": null
    },
    "technical-review": {
      "status": "pending",
      "output": null,
      "iterations": 0,
      "confidence": null
    },
    "style-review": {
      "status": "pending",
      "output": null
    },
    "integration": {
      "status": "skipped",
      "output": null
    },
    "create-jira": {
      "status": "skipped",
      "output": null
    }
  }
}
```

### Status values

| Value | Meaning |
|---|---|
| `pending` | Not yet started |
| `in_progress` | Currently running |
| `completed` | Finished successfully |
| `failed` | Failed — needs retry |
| `skipped` | Not applicable (conditional step not requested) |

### Step-specific fields

The `technical-review` step includes extra fields:

- `iterations` — number of review cycles completed (0-3)
- `confidence` — last observed confidence level (`HIGH`, `MEDIUM`, `LOW`, or `null`)

These fields allow the Stop hook to verify that the tech review either reached
acceptable confidence or exhausted its iteration budget.

### Writing the progress file

Claude writes the progress file directly using the Write tool. No Python script
is needed — Claude reads and writes JSON natively.

- Create the progress file after parsing arguments (before step 1)
- Update `steps.<name>.status` to `"in_progress"` before starting each step
- Update `steps.<name>.status` to `"completed"` and set `output` after each step
- Update `steps.<name>.status` to `"skipped"` for conditional steps not requested
- Set `status` to `"completed"` when all applicable steps are done
- Set `updated_at` on every write

## Workflow steps

Run these steps in order. After each step, verify the output file exists before
proceeding. Update the progress file after each step completes.

### Step 1: Requirements analysis

```
Skill: docs-tools:docs-workflow-requirements, args: "<ticket> [--pr <urls>] --output <output_path>"
```

Verify: requirements file exists. Update progress: requirements → completed.

### Step 2: Documentation planning

```
Skill: docs-tools:docs-workflow-planning, args: "<ticket> --input <requirements_output> --output <output_path>"
```

Verify: plan file exists. Update progress: planning → completed.

### Step 3: Writing

```
Skill: docs-tools:docs-workflow-writing, args: "<ticket> --input <plan_output> --output <output_path> --format <adoc|mkdocs>"
```

Verify: `_index.md` exists in the drafts directory. Update progress: writing → completed.

### Step 4: Technical review (with iteration)

```
Skill: docs-tools:docs-workflow-tech-review, args: "<ticket> --drafts-dir <drafts_dir> --output <output_path>"
```

After the review completes, read the output and check for `Overall technical confidence`.

- If HIGH → update progress: technical-review → completed, confidence → HIGH
- If MEDIUM or LOW and iterations < 3 → invoke the fix skill, then re-run the review:

```
Skill: docs-tools:docs-workflow-writing, args: "<ticket> --fix-from <review_output> --drafts-dir <drafts_dir>"
```

Update progress: increment iterations, set confidence to the observed level.

If confidence is not HIGH after 3 iterations, proceed with a warning that manual
review is recommended. Update progress: technical-review → completed, note that
confidence is MEDIUM (acceptable after max iterations).

### Step 5: Style review

```
Skill: docs-tools:docs-workflow-style-review, args: "<ticket> --drafts-dir <drafts_dir> --output <output_path> --format <adoc|mkdocs>"
```

Verify: review report exists. Update progress: style-review → completed.

### Step 6: Integration (only if --integrate)

Skip this step if `--integrate` was not specified. Mark as skipped in progress.

**6a: Plan**

```
Skill: docs-tools:docs-workflow-integrate, args: "<ticket> --phase plan --drafts-dir <drafts_dir> --output <plan_output>"
```

**6b: Confirm**

Read the integration plan and present a summary to the user.
Ask: "The integration plan proposes the changes listed above. Shall I proceed?"

- If yes → continue to 6c
- If no → save the plan for manual reference, mark integration → completed

**6c: Execute**

```
Skill: docs-tools:docs-workflow-integrate, args: "<ticket> --phase execute --drafts-dir <drafts_dir> --plan <plan_output> --output <report_output>"
```

Update progress: integration → completed.

### Step 7: JIRA creation (only if --create-jira)

Skip this step if `--create-jira` was not specified. Mark as skipped in progress.

```
Skill: docs-tools:docs-workflow-create-jira, args: "<ticket> --project <PROJECT> --plan <plan_output>"
```

Update progress: create-jira → completed.

## Completion

Update progress file: status → completed.

Display a summary:

- List all output files with paths
- Note any warnings (tech review didn't reach HIGH, etc.)
- Show JIRA URL if created
```

## Step Skills

Each step skill follows the step skill contract: parse args, do work, write output. Step skills do **not** manage workflow state. The agent definitions in `agents/*.md` remain unchanged.

### `docs-workflow-requirements`

**Agent**: `docs-tools:requirements-analyst`

**Output**: `requirements/requirements_{ticket}_{timestamp}.md`

**Prompt**:

> Analyze documentation requirements for JIRA ticket `<TICKET>`.
>
> Manually-provided PR/MR URLs to include in analysis (merge with any auto-discovered URLs, dedup):
> - `<PR_URL_1>`
> - `<PR_URL_2>`
>
> Save your complete analysis to: `<OUTPUT_FILE>`
>
> Follow your standard analysis methodology (JIRA fetch, ticket graph traversal, PR/MR analysis, web search expansion). Format the output as structured markdown for the next stage.

The PR URL bullet list is conditional — included only if PR URLs are provided.

**Output verification fallback**: Search `.claude/docs/requirements/*<ticket>*.md` for most recent match.

### `docs-workflow-planning`

**Agent**: `docs-tools:docs-planner`

**Output**: `plans/plan_{ticket}_{timestamp}.md`

**Inputs**: Previous step output (requirements file path)

**Prompt**:

> Create a comprehensive documentation plan based on the requirements analysis.
>
> Read the requirements from: `<PREV_OUTPUT>`
>
> The plan must include:
> 1. Gap analysis (existing vs needed documentation)
> 2. Module specifications (type, title, audience, content points, prerequisites, dependencies)
> 3. Implementation order based on dependencies
> 4. Assembly structure (how modules group together)
> 5. Content sources from JIRA and PR/MR analysis
>
> Save the complete plan to: `<OUTPUT_FILE>`
>
> Use structured markdown with clear sections for each module.

### `docs-workflow-writing`

**Agent**: `docs-tools:docs-writer`

**Output**: `drafts/{ticket}/_index.md`

**Inputs**: Previous step output (plan file path), format option

**Output directory structure (AsciiDoc, default)**:

```
.claude/docs/drafts/<ticket>/
  _index.md
  assembly_<name>.adoc
  modules/
    <concept>.adoc
    <procedure>.adoc
    <reference>.adoc
```

**Output directory structure (MkDocs, `format == mkdocs`)**:

```
.claude/docs/drafts/<ticket>/
  _index.md
  mkdocs-nav.yml
  docs/
    <concept>.md
    <procedure>.md
    <reference>.md
```

**Prompt (AsciiDoc)**:

> Write complete AsciiDoc documentation based on the documentation plan for ticket `<TICKET>`.
>
> Read the plan from: `<PREV_OUTPUT>`
>
> **IMPORTANT**: Write COMPLETE .adoc files, not summaries or outlines.
>
> Output folder structure:
> ```
> <DRAFTS_DIR>/
> +-- _index.md
> +-- assembly_<name>.adoc
> +-- modules/
>     +-- <concept-name>.adoc
>     +-- <procedure-name>.adoc
>     +-- <reference-name>.adoc
> ```
>
> Save modules to: `<MODULES_DIR>/`
> Save assemblies to: `<DRAFTS_DIR>/`
> Create index at: `<DRAFTS_DIR>/_index.md`

**Prompt (MkDocs)**:

> Write complete Material for MkDocs Markdown documentation based on the documentation plan for ticket `<TICKET>`.
>
> Read the plan from: `<PREV_OUTPUT>`
>
> **IMPORTANT**: Write COMPLETE .md files with YAML frontmatter (title, description), not summaries or outlines. Use Material for MkDocs conventions: admonitions, content tabs, code blocks with titles, and proper heading hierarchy starting at `# h1`.
>
> Output folder structure:
> ```
> <DRAFTS_DIR>/
> +-- _index.md
> +-- mkdocs-nav.yml
> +-- docs/
>     +-- <concept-name>.md
>     +-- <procedure-name>.md
>     +-- <reference-name>.md
> ```
>
> Save pages to: `<DOCS_DIR>/`
> Create nav fragment at: `<DRAFTS_DIR>/mkdocs-nav.yml`
> Create index at: `<DRAFTS_DIR>/_index.md`

**Output verification**: Check that `_index.md` exists at the output path. The `_index.md` serves as the manifest for the entire drafts directory.

### `docs-workflow-tech-review`

**Agent (reviewer)**: `docs-tools:technical-reviewer`
**Agent (fix)**: `docs-tools:docs-writer`

**Output**: `drafts/{ticket}/_technical_review.md`

This is the most complex step skill because the orchestrator drives its review-fix iteration loop.

**Reviewer prompt**:

> Perform a technical review of the documentation drafts for ticket `<TICKET>`.
> Source drafts location: `<DRAFTS_DIR>/`
> Review all .adoc and .md files. Follow your standard review methodology.
> Save your review report to: `<TECH_REVIEW_FILE>`

**Fix prompt** (dispatched by the orchestrator between iterations):

> The technical reviewer found issues in the documentation for ticket `<TICKET>`.
> Read the technical review report at: `<TECH_REVIEW_FILE>`
> Address all Critical issues and Significant issues.
> Edit draft files in place at `<DRAFTS_DIR>/`.
> Do NOT address minor issues or style concerns.

**Iteration**: The orchestrator reads the review output and checks for `Overall technical confidence: (HIGH|MEDIUM|LOW)`. Iteration stops on `HIGH`, or on `MEDIUM` or above after 3 attempts.

**Note on `subagent_type`**: Throughout this spec, agent references (e.g., `docs-tools:technical-reviewer`) refer to agent definitions in `agents/*.md`, not skills. This matches the Claude Code Agent tool convention where `subagent_type` loads agent markdown files as the subagent's system instructions.

### `docs-workflow-style-review`

**Agent**: `docs-tools:docs-reviewer`

**Output**: `drafts/{ticket}/_review_report.md`

**Inputs**: Format option determines which review skills to include

**AsciiDoc review skills**:

- Vale linting: `vale-tools:lint-with-vale`
- Red Hat docs: `docs-tools:docs-review-modular-docs`, `docs-tools:docs-review-content-quality`
- IBM Style Guide: `docs-tools:ibm-sg-audience-and-medium`, `docs-tools:ibm-sg-language-and-grammar`, `docs-tools:ibm-sg-punctuation`, `docs-tools:ibm-sg-numbers-and-measurement`, `docs-tools:ibm-sg-structure-and-format`, `docs-tools:ibm-sg-references`, `docs-tools:ibm-sg-technical-elements`, `docs-tools:ibm-sg-legal-information`
- Red Hat SSG: `docs-tools:rh-ssg-grammar-and-language`, `docs-tools:rh-ssg-formatting`, `docs-tools:rh-ssg-structure`, `docs-tools:rh-ssg-technical-examples`, `docs-tools:rh-ssg-gui-and-links`, `docs-tools:rh-ssg-legal-and-support`, `docs-tools:rh-ssg-accessibility`, `docs-tools:rh-ssg-release-notes` (if applicable)

**MkDocs review skills**: Same as AsciiDoc but omits `docs-tools:docs-review-modular-docs` (AsciiDoc-specific) and `docs-tools:rh-ssg-release-notes`.

**Prompt**:

> Review the [AsciiDoc|MkDocs Markdown] documentation drafts for ticket `<TICKET>`.
>
> Source drafts location: `<DRAFTS_DIR>/`
>
> **Edit files in place** in the drafts folder. Do NOT create copies.
>
> For each file:
> 1. Run Vale linting once
> 2. Fix obvious errors where the fix is clear and unambiguous
> 3. Run documentation review skills: [skill list based on format]
> 4. Skip ambiguous issues that require broader context
>
> Save the review report to: `<DRAFTS_DIR>/_review_report.md`
>
> The report must include:
> - Summary of files reviewed
> - Vale linting results (errors, warnings, suggestions)
> - Issues found by each review skill (with file:line references)
> - Fixes applied
> - Remaining issues requiring manual review

### `docs-workflow-integrate`

**Agent**: `docs-tools:docs-integrator`

**Output (plan)**: `drafts/{ticket}/_integration_plan.md`
**Output (execute)**: `drafts/{ticket}/_integration_report.md`

Integration is expressed as a **plan + confirm + execute** sequence in the orchestrator skill. The integrate step skill handles a single phase per invocation:

**Plan prompt**:

> Phase: PLAN
> Plan the integration of documentation drafts for ticket `<TICKET>`.
> Drafts location: `<DRAFTS_DIR>/`
> Save the integration plan to: `<INTEGRATION_PLAN_FILE>`

**Execute prompt**:

> Phase: EXECUTE
> Execute the integration plan for ticket `<TICKET>`.
> Drafts location: `<DRAFTS_DIR>/`
> Integration plan: `<INTEGRATION_PLAN_FILE>`
> Save the integration report to: `<INTEGRATION_REPORT_FILE>`

The orchestrator skill handles the confirmation gate between plan and execute using `AskUserQuestion`. If the user declines, the step is marked completed with the plan saved for manual reference.

### `docs-workflow-create-jira`

**No agent dispatch** — uses direct Bash/curl/Python for JIRA REST API calls.

**Output**: `null` (produces a JIRA URL, not a file)

**Inputs**: `create_jira_project` option (target JIRA project key), planning step output (documentation plan to extract description)

**Step-by-step logic**:

1. **Check for existing link** — Fetch parent ticket's issuelinks via JIRA REST API. If a "Document" link with inwardIssue already exists, return immediately (no duplicate).
2. **Check project visibility** — Unauthenticated curl to `/rest/api/2/project/<PROJECT>`. HTTP 200 = public (do NOT attach detailed plan). Other = private (attach plan).
3. **Extract description** — Read the planning step output and extract 3 sections: main JTBD, JTBD relation, and information sources. Append footer with date and AI attribution.
4. **Convert to JIRA wiki markup** — Python inline script handles headings, bold, code, links, tables, numbered lists, horizontal rules.
5. **Create JIRA ticket** — POST to `/rest/api/2/issue`. Summary: `[ccs] Docs - <parent_summary>`. Issue type: Story. Component: Documentation.
6. **Link to parent ticket** — POST to `/rest/api/2/issueLink`. Type: "Document" (singular). outwardIssue: parent (shows "documents"), inwardIssue: new ticket (shows "is documented by").
7. **Attach docs plan** — Private projects only. POST to `/rest/api/2/issue/<NEW_KEY>/attachments` with plan file.
8. **Return** — The orchestrator records completion. The JIRA URL is reported to the user but not written to a file.

## Stop Hook: Workflow Completion Check

### Purpose

The Stop hook fires every time Claude finishes responding. When a documentation workflow is in progress, the hook verifies all expected steps are complete — checking both the progress file status and file contents where relevant. If steps are missing or incomplete, it returns a reason that Claude uses as its next instruction.

### Hook script: `workflow-completion-check.sh`

**Location**: `plugins/docs-tools/skills/docs-orchestrator/hooks/workflow-completion-check.sh`

```bash
#!/bin/bash
# workflow-completion-check.sh
#
# Stop hook: verify documentation workflow is complete before letting Claude stop.
# Only activates when a progress JSON file exists in .claude/docs/workflow/.
#
# Checks:
# 1. Progress file status (are all steps completed/skipped?)
# 2. Output file existence (do declared outputs actually exist?)
# 3. Content verification (did tech review reach acceptable confidence?)
#
# Input (stdin): JSON with session context including stop_hook_active flag
# Output (stdout): JSON {ok: true/false, reason: "..."}

INPUT=$(cat)

# Prevent infinite loops — if this hook already triggered a continuation, allow stop
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  echo '{"ok": true}'
  exit 0
fi

# Find progress files
PROGRESS_FILES=$(ls .claude/docs/workflow/*.json 2>/dev/null)
if [ -z "$PROGRESS_FILES" ]; then
  # No workflow in progress — allow stop
  echo '{"ok": true}'
  exit 0
fi

# Check each progress file for incomplete workflows
for pfile in $PROGRESS_FILES; do
  WORKFLOW_STATUS=$(jq -r '.status' "$pfile" 2>/dev/null)

  if [ "$WORKFLOW_STATUS" != "in_progress" ]; then
    continue
  fi

  TICKET=$(jq -r '.ticket' "$pfile")

  # Find first non-completed, non-skipped step
  NEXT_STEP=$(jq -r '
    .steps | to_entries[]
    | select(.value.status != "completed" and .value.status != "skipped")
    | .key' "$pfile" | head -1)

  if [ -z "$NEXT_STEP" ]; then
    # All steps done but status not updated — allow stop, Claude will update it
    continue
  fi

  # Content verification: check tech review confidence
  if [ "$NEXT_STEP" = "style-review" ] || [ "$NEXT_STEP" = "integration" ] || [ "$NEXT_STEP" = "create-jira" ]; then
    # Tech review should be done by now — verify confidence
    TECH_STATUS=$(jq -r '.steps["technical-review"].status' "$pfile")
    if [ "$TECH_STATUS" = "completed" ]; then
      CONFIDENCE=$(jq -r '.steps["technical-review"].confidence // "null"' "$pfile")
      ITERATIONS=$(jq -r '.steps["technical-review"].iterations // 0' "$pfile")

      if [ "$CONFIDENCE" != "HIGH" ] && [ "$CONFIDENCE" != "MEDIUM" ] && [ "$ITERATIONS" -lt 3 ]; then
        echo "{\"ok\": false, \"reason\": \"Documentation workflow for $TICKET: technical review completed with confidence '$CONFIDENCE' after $ITERATIONS iterations. Run additional review iterations (max 3) to reach MEDIUM or higher confidence.\"}"
        exit 0
      fi
    fi
  fi

  # Check if declared output files actually exist
  STEP_OUTPUT=$(jq -r ".steps[\"$NEXT_STEP\"].output // \"null\"" "$pfile")
  STEP_STATUS=$(jq -r ".steps[\"$NEXT_STEP\"].status" "$pfile")

  if [ "$STEP_STATUS" = "completed" ] && [ "$STEP_OUTPUT" != "null" ] && [ ! -f "$STEP_OUTPUT" ]; then
    echo "{\"ok\": false, \"reason\": \"Documentation workflow for $TICKET: step '$NEXT_STEP' is marked completed but output file $STEP_OUTPUT does not exist. Re-run the step.\"}"
    exit 0
  fi

  echo "{\"ok\": false, \"reason\": \"Documentation workflow for $TICKET is not complete. Next step: $NEXT_STEP. Continue the workflow.\"}"
  exit 0
done

# All workflows complete or no incomplete steps found
echo '{"ok": true}'
exit 0
```

### Hook registration

The hook is registered in `.claude/settings.json`. The `setup-hooks.sh` script (see Hook Installation below) handles this automatically.

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PROJECT_DIR}/.claude/hooks/workflow-completion-check.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

### Stop hook behavior

| Scenario | Hook response | Effect |
|---|---|---|
| No progress file exists | `{ok: true}` | Claude stops normally |
| Progress file status: completed | `{ok: true}` | Claude stops normally |
| Progress file status: in_progress, steps remain | `{ok: false, reason: "Next step: ..."}` | Claude continues with the reason as instruction |
| Tech review completed with LOW confidence, < 3 iterations | `{ok: false, reason: "Run additional iterations..."}` | Claude runs more tech review cycles |
| Step marked completed but output file missing | `{ok: false, reason: "Re-run the step"}` | Claude re-runs the step |
| `stop_hook_active` is true | `{ok: true}` | Prevents infinite loop — Claude stops |

### Content verification

The Stop hook verifies file contents, not just file existence:

1. **Tech review confidence** — After the tech review step, the hook checks the `confidence` and `iterations` fields in the progress file. If confidence is below MEDIUM and iterations are under 3, the hook tells Claude to run more iterations. MEDIUM is acceptable after 3 iterations (exhausted budget). HIGH is always acceptable.

2. **Output file existence** — If a step is marked "completed" in the progress file but the declared output file doesn't exist on disk, the hook tells Claude to re-run the step. This catches cases where a file was written but later deleted, or where the skill reported success but didn't actually write the file.

### Infinite loop prevention

The `stop_hook_active` field is critical. When a Stop hook returns `{ok: false}`, Claude continues working. When Claude finishes that continuation and tries to stop again, the next Stop event includes `stop_hook_active: true`. The hook MUST check this field and return `{ok: true}` to allow Claude to stop.

This means the hook gets **one chance** per stop attempt to redirect Claude. If Claude stops again after the redirect, the hook allows it. This prevents infinite loops where the hook keeps saying "not done" forever.

In practice, Claude typically completes all remaining steps in a single continuation because the skill instructions tell it to run all steps sequentially. The Stop hook is a safety net for edge cases where Claude finishes mid-workflow (e.g., after a compaction event, or when it misinterprets a step result as the final output).

## Hook Installation

### Setup script: `setup-hooks.sh`

**Location**: `plugins/docs-tools/skills/docs-orchestrator/scripts/setup-hooks.sh`

The plugin provides a setup script that installs the Stop hook and compaction hook into the project's `.claude/settings.json`. Users run this once per project.

```bash
#!/bin/bash
# setup-hooks.sh
#
# Install docs-orchestrator hooks into .claude/settings.json.
# Safe to run multiple times — checks for existing hooks before adding.

set -e

SETTINGS_FILE=".claude/settings.json"
HOOK_SCRIPT_SRC="${CLAUDE_PLUGIN_ROOT}/skills/docs-orchestrator/hooks/workflow-completion-check.sh"
HOOK_SCRIPT_DST=".claude/hooks/workflow-completion-check.sh"

# Create directories
mkdir -p .claude/hooks

# Copy hook script to project
cp "$HOOK_SCRIPT_SRC" "$HOOK_SCRIPT_DST"
chmod +x "$HOOK_SCRIPT_DST"

# Create or update settings.json
if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{}' > "$SETTINGS_FILE"
fi

# Check if Stop hook already exists
EXISTING=$(jq '.hooks.Stop // []' "$SETTINGS_FILE" 2>/dev/null)
HAS_WORKFLOW_HOOK=$(echo "$EXISTING" | jq '[.[].hooks[]? | select(.command | contains("workflow-completion-check"))] | length')

if [ "$HAS_WORKFLOW_HOOK" -gt 0 ]; then
  echo "Workflow completion hook already installed."
else
  # Add Stop hook
  jq '.hooks.Stop = (.hooks.Stop // []) + [{
    "hooks": [{
      "type": "command",
      "command": "bash ${CLAUDE_PROJECT_DIR}/.claude/hooks/workflow-completion-check.sh",
      "timeout": 10
    }]
  }]' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
  echo "Installed workflow completion Stop hook."
fi

# Check if compaction hook already exists
EXISTING_COMPACT=$(jq '.hooks.SessionStart // []' "$SETTINGS_FILE" 2>/dev/null)
HAS_COMPACT_HOOK=$(echo "$EXISTING_COMPACT" | jq '[.[].hooks[]? | select(.command | contains("workflow"))] | length')

if [ "$HAS_COMPACT_HOOK" -gt 0 ]; then
  echo "Compaction re-injection hook already installed."
else
  # Add SessionStart hook for compaction
  jq '.hooks.SessionStart = (.hooks.SessionStart // []) + [{
    "matcher": "compact",
    "hooks": [{
      "type": "command",
      "command": "for f in .claude/docs/workflow/*.json; do [ -f \"$f\" ] && STATUS=$(jq -r .status \"$f\") && [ \"$STATUS\" = \"in_progress\" ] && echo \"Active workflow:\" && cat \"$f\"; done"
    }]
  }]' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
  echo "Installed compaction re-injection hook."
fi

echo ""
echo "Setup complete. Hooks installed in $SETTINGS_FILE"
echo "Run /hooks in Claude Code to verify."
```

### Usage

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/docs-orchestrator/scripts/setup-hooks.sh
```

Or ask Claude: *"Set up the docs-orchestrator hooks"* — Claude will run the setup script.

### What gets installed

| Hook | Event | Purpose |
|---|---|---|
| `workflow-completion-check.sh` | `Stop` | Validates workflow completion before allowing Claude to stop |
| Inline command | `SessionStart` (matcher: `compact`) | Re-injects active progress files after context compaction |

### README documentation

The plugin README documents hook setup as a one-time step:

> **Setup (one time per project):**
>
> ```
> bash ${CLAUDE_PLUGIN_ROOT}/skills/docs-orchestrator/scripts/setup-hooks.sh
> ```
>
> This installs two hooks into `.claude/settings.json`:
> 1. A Stop hook that ensures documentation workflows run to completion
> 2. A compaction hook that re-injects workflow state after context compaction
>
> Run `/hooks` in Claude Code to verify the hooks are active.

## Context Re-injection After Compaction

Long workflows may trigger context compaction, which summarizes the conversation to free space. This can lose track of workflow progress. A `SessionStart` hook with a `compact` matcher re-injects the active progress file:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "compact",
        "hooks": [
          {
            "type": "command",
            "command": "for f in .claude/docs/workflow/*.json; do [ -f \"$f\" ] && STATUS=$(jq -r .status \"$f\") && [ \"$STATUS\" = \"in_progress\" ] && echo \"Active workflow:\" && cat \"$f\"; done"
          }
        ]
      }
    ]
  }
}
```

This prints any active progress files (status: in_progress) to stdout, which gets added to Claude's context after compaction. Claude then knows which workflow is active, what steps are done, and where to resume.

## How Resume Works

### Same session

Claude reads the progress file and skips completed steps. The Stop hook ensures Claude doesn't stop prematurely if it loses track after a compaction.

### New session

User says: *"Resume docs workflow for PROJ-123"*

1. Claude invokes `docs-tools:docs-orchestrator` with the ticket
2. The skill instructs: "Check for existing work before starting"
3. Claude finds `docs-workflow_proj_123.json` → reads it
4. Claude sees requirements and planning are completed → skips to writing
5. Claude continues from the first pending/failed step

### After failure

Same as new session. The progress file shows which steps completed and which failed. Claude re-attempts the failed step. The user can also re-specify flags on resume (e.g., add `--integrate` that wasn't in the original run) — Claude updates the progress file options and adjusts which steps to run.

### Cross-session param persistence

The progress file stores `options` (format, integrate, pr_urls, etc.), so Claude can read them on resume without the user re-specifying flags. If the user provides new flags on resume, they override the stored options.

## Workflow Type Namespacing

Progress files are namespaced by workflow type in the filename:

```
.claude/docs/workflow/<workflow-type>_<ticket>.json
```

Examples:
- `.claude/docs/workflow/docs-workflow_proj_123.json` — full docs pipeline
- `.claude/docs/workflow/review-only_proj_123.json` — review-only workflow

This prevents conflicts when different workflow types run against the same ticket. A user can run a full docs workflow and a separate review-only pass without the progress files overwriting each other.

The `workflow_type` field inside the JSON matches the filename prefix, making it easy for the Stop hook to identify which workflow is which.

### Defining new workflow types

Teams create new workflow types by writing new skills. For example, a `review-only` workflow:

```markdown
---
name: docs-review-workflow
description: Run technical and style review on existing documentation drafts.
argument-hint: <drafts-dir> [--mkdocs]
allowed-tools: Read, Write, Glob, Grep, Edit, Bash, Skill, AskUserQuestion
---

## Progress file

Create at `.claude/docs/workflow/review-only_<dir-name>.json` with steps:
technical-review, style-review.

## Steps

### Step 1: Technical review
...

### Step 2: Style review
...
```

No YAML file needed. The skill IS the workflow definition. The Stop hook works automatically — it reads whatever progress files exist and validates completion regardless of workflow type.

## Example Workflows

### Full documentation workflow

```
User: Write docs for PROJ-123 --pr https://github.com/org/repo/pull/456 --integrate

Claude: [reads docs-orchestrator skill]
        [checks .claude/docs/workflow/ — no existing progress file]
        [creates docs-workflow_proj_123.json]
        [runs requirements analysis → updates progress]
        [runs planning → updates progress]
        [runs writing → updates progress]
        [runs tech review → confidence MEDIUM → runs fix → re-reviews → HIGH]
        [updates progress: technical-review completed, confidence HIGH, iterations 2]
        [runs style review → updates progress]
        [runs integration plan → asks user to confirm → runs execute]
        [updates progress: status completed]
        [displays summary]

Stop hook: [reads docs-workflow_proj_123.json — status: completed] → {ok: true}
```

### Review-only (direct skill invocation)

```
User: Run a technical and style review on the docs in ./modules/

Claude: [recognizes this as a review task — no full orchestrator needed]
        [invokes docs-workflow-tech-review directly]
        [invokes docs-workflow-style-review directly]
        [displays results]
```

For simple tasks, Claude doesn't need the orchestrator skill at all. It can invoke step skills directly.

### Resume after interruption

```
User: Resume docs for PROJ-123

Claude: [reads docs-orchestrator skill]
        [finds docs-workflow_proj_123.json]
        [reads progress: requirements and planning completed, writing pending]
        "Found existing work for PROJ-123. Resuming from writing."
        [runs writing]
        [continues through remaining steps]

Stop hook: [validates each step on progress] → {ok: false} until all done
```

### Stop hook catches incomplete workflow

```
User: Write docs for PROJ-123
Claude: [runs requirements, planning, writing]
        [tries to stop — perhaps misinterprets writing output as final]

Stop hook: [reads progress — technical-review still pending]
           → {ok: false, reason: "Workflow for PROJ-123 not complete. Next step: technical-review"}

Claude: [continues with tech review, style review]
        [updates progress: status completed]

Stop hook: [reads progress — status: completed] → {ok: true}
```

## Step Skill Contract

Step skills invoked by the orchestrator follow a lightweight contract.

### What step skills receive

A single `args` string containing everything the skill needs — ticket ID, input file paths, output file path, format options, etc.

### What step skills must do

1. Parse their args (the skill defines its own arg format)
2. Do their work (dispatch agents, run scripts, call APIs)
3. Write their output to the path specified in args (if applicable)
4. Return — the orchestrator handles state updates

### What step skills must NOT do

- Manage workflow state (no writing to the progress file)
- Know about other steps (no reading from progress file)
- Handle iteration (the orchestrator loops, not the skill)
- Handle confirmation gates (the orchestrator asks, not the skill)

### Standalone invocation

Step skills can be invoked directly, outside the orchestrator:

```
Skill: docs-tools:docs-workflow-requirements, args: "PROJ-123 --output /tmp/reqs.md --pr https://..."
```

The skill doesn't know or care whether it's being called by the orchestrator or directly. It just receives args and does its work.

## Design Note: Skill Composition is the Intended Pattern

The orchestrator invokes step skills via the `Skill` tool, and step skills dispatch agents via the `Agent` tool. This is not "3 levels of nesting" — it is standard skill composition:

1. Claude loads orchestrator instructions (context load, not a subprocess)
2. Claude invokes `Skill` tool → step skill markdown loads into context (context load)
3. Claude invokes `Agent` tool → subagent runs (actual subprocess)

Only the `Agent` dispatch creates a real subprocess. The skill-to-skill invocation is just Claude reading sequential instructions in the same context. This is the same pattern used by `docs-reviewer`, which loads 18 review skills through its agent definition.

## Migration Path

### From docs-workflow command

Teams can adopt the hook-based orchestrator incrementally:

1. Run `setup-hooks.sh` to install the Stop and compaction hooks
2. Create step skills that follow the step skill contract (can reuse agent definitions from `docs-workflow`)
3. Invoke `docs-tools:docs-orchestrator` instead of the `docs-workflow` command
4. Update `marketplace.json` to register `docs-orchestrator`

### Implementation steps

1. Create `docs-orchestrator.md` skill
2. Create `workflow-completion-check.sh` Stop hook script
3. Create `setup-hooks.sh` installation helper
4. Create step skills (can reuse agent definitions from `docs-workflow`)
5. Update plugin README with setup instructions
6. Update `marketplace.json` to register `docs-orchestrator`

## Testing

### Workflow skill

- Full pipeline executes all steps in order
- Conditional steps (integrate, create-jira) are skipped when flags are absent
- Conditional steps execute when flags are present
- Tech review iteration stops at HIGH confidence
- Tech review iteration continues through MEDIUM/LOW up to 3 attempts
- After 3 iterations, MEDIUM confidence is accepted with warning
- Resume detects existing progress file and skips completed steps
- Progress file is updated after each step with correct status and output path

### Stop hook

- Returns `{ok: true}` when no progress file exists
- Returns `{ok: true}` when progress file shows status: completed
- Returns `{ok: false}` with correct next step when workflow is in progress
- Returns `{ok: true}` when `stop_hook_active` is true (loop prevention)
- Correctly skips steps with status "skipped" in the progress file
- Detects tech review with LOW confidence and < 3 iterations → requests more iterations
- Accepts tech review with MEDIUM confidence after 3 iterations
- Detects completed steps with missing output files → requests re-run
- Handles multiple concurrent progress files (different tickets or workflow types)

### Hook installation

- `setup-hooks.sh` creates `.claude/hooks/` directory
- `setup-hooks.sh` copies hook script and sets executable permission
- `setup-hooks.sh` adds Stop hook to settings.json without duplicating
- `setup-hooks.sh` adds compaction hook to settings.json without duplicating
- `setup-hooks.sh` is idempotent — safe to run multiple times
- `/hooks` menu shows both hooks after installation

### Integration

- End-to-end workflow with Stop hook produces all expected artifacts
- Resume after session break picks up at correct step
- Compaction hook re-injects progress file content
- Step skills work identically whether invoked by orchestrator or directly
- Multiple workflow types against same ticket don't conflict

## Error Handling

### Step failure

When a step skill fails (returns an error, or output verification fails):

1. Claude updates the progress file: step status → `failed`
2. Claude displays the error and tells the user what failed
3. Claude suggests: "Fix the issue and resume with: `docs-tools:docs-orchestrator PROJ-123`"

### Preflight failure

If `JIRA_AUTH_TOKEN` is not set and cannot be sourced:

1. Claude displays the specific check that failed
2. Claude does NOT create a progress file or run any steps
3. Claude suggests sourcing `~/.env` or setting the variable

### Access failures

If any step fails due to access issues (JIRA auth, GitHub token, GitLab token):

1. Claude stops immediately — does not proceed to the next step
2. Claude reports the exact error
3. Claude updates progress: step status → `failed`
4. User must fix credentials and resume

### Stop hook catches abandoned workflows

If Claude stops mid-workflow without updating the progress file (e.g., crash, timeout):

1. The Stop hook detects the in_progress workflow on the next Claude invocation
2. The hook returns `{ok: false}` with the next step
3. Claude resumes the workflow

This is a safety net — normally Claude updates the progress file before stopping.
