---
description: Run the multi-stage documentation workflow
argument-hint: [action] <ticket> [--pr <url>] [--create-jira <PROJECT>]
allowed-tools: Read, Write, Glob, Grep, Edit, Bash, Skill, Task, WebSearch, WebFetch, Agent
---

# Documentation Workflow

Run the multi-stage documentation workflow for a JIRA ticket. This command orchestrates four specialized agents sequentially — requirements analysis, planning, writing, and review — to produce complete AsciiDoc documentation.

## Agents

| Stage | Agent | Subagent Type | Description |
|-------|-------|---------------|-------------|
| 1. Requirements | requirements-analyst | `docs-tools:requirements-analyst` | Parses JIRA issues, PRs, and specs to extract documentation requirements |
| 2. Planning | docs-planner | `docs-tools:docs-planner` | Creates documentation plans with JTBD framework and gap analysis |
| 3. Writing | docs-writer | `docs-tools:docs-writer` | Writes complete AsciiDoc modules following Red Hat modular docs standards |
| 4. Review | docs-reviewer | `docs-tools:docs-reviewer` | Reviews with Vale linting and style guide checks, edits files in place |
| 5. Create JIRA | *(direct bash/curl)* | — | Optional: creates a docs JIRA ticket linked to the parent ticket |

## Output Structure

```
.claude_docs/
├── workflow/           # Workflow state files (JSON)
├── requirements/       # Stage 1 outputs
├── plans/              # Stage 2 outputs
└── drafts/             # Stage 3 + 4 outputs (per-ticket folders)
    └── <ticket>/
        ├── _index.md
        ├── _review_report.md   # Stage 4 review report
        ├── assembly_*.adoc
        └── modules/
            ├── <concept>.adoc
            ├── <procedure>.adoc
            └── <reference>.adoc
```

## Arguments

- **action**: $1 (default: `start`) — Action to perform: `start`, `resume`, or `status`
- **ticket**: $2 (required) — JIRA ticket identifier (e.g., `RHAISTRAT-123`)

**IMPORTANT**: This command requires a ticket identifier. If no ticket is provided, stop and ask the user to provide one.

## Options

- **--pr \<url\>**: GitHub PR or GitLab MR URL to include in requirements analysis. Can be specified multiple times across start/resume invocations.
- **--create-jira \<PROJECT\>**: Create a documentation JIRA ticket in the specified project (e.g., `INFERENG`) after the review stage completes. The project key is mandatory — there is no default. The created ticket is linked to the parent ticket with a "Documents" relationship. Can be passed on `start` or `resume`.

## Step-by-Step Instructions

### Step 1: Parse Arguments

Parse the action, ticket, and options from the command arguments.

```bash
ACTION="${1:-start}"
TICKET="${2:-}"

# Parse --pr and --create-jira flags from remaining arguments
PR_URLS=()
CREATE_JIRA_PROJECT=""
shift 2 2>/dev/null
while [[ $# -gt 0 ]]; do
    case "$1" in
        --pr) PR_URLS+=("$2"); shift 2 ;;
        --create-jira) CREATE_JIRA_PROJECT="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# Validate ticket is provided
if [[ -z "$TICKET" ]]; then
    echo "ERROR: Ticket identifier is required."
    echo "Usage: /docs-tools:docs-workflow [start|resume|status] <TICKET> [--pr <url>] [--create-jira <PROJECT>]"
    exit 1
fi

echo "Action: ${ACTION}"
echo "Ticket: ${TICKET}"
if [[ ${#PR_URLS[@]} -gt 0 ]]; then
    echo "PR URLs: ${PR_URLS[*]}"
fi
if [[ -n "$CREATE_JIRA_PROJECT" ]]; then
    echo "Create JIRA in project: ${CREATE_JIRA_PROJECT}"
fi
```

If no ticket is provided, STOP and ask the user to provide one.

### Step 2: Pre-flight Validation

Validate that required access tokens are available before proceeding.

```bash
echo ""
echo "Validating access tokens..."

HAS_ERRORS=false

# JIRA token is REQUIRED
if [[ -z "${JIRA_AUTH_TOKEN:-}" ]]; then
    echo "ERROR: JIRA_AUTH_TOKEN is not set."
    echo "  The workflow requires JIRA access to fetch ticket details."
    echo "  Add JIRA_AUTH_TOKEN to ~/.env and source it."
    HAS_ERRORS=true
else
    echo "  JIRA_AUTH_TOKEN: configured"
fi

# GitHub token — warning only
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    echo "  GITHUB_TOKEN: configured"
else
    echo "  GITHUB_TOKEN: not set (required if using GitHub PRs)"
fi

# GitLab token — warning only
if [[ -n "${GITLAB_TOKEN:-}" ]]; then
    echo "  GITLAB_TOKEN: configured"
else
    echo "  GITLAB_TOKEN: not set (required if using GitLab MRs)"
fi

if [[ "$HAS_ERRORS" == "true" ]]; then
    echo ""
    echo "CRITICAL: Required access tokens are missing."
    echo "The workflow WILL NOT proceed without JIRA_AUTH_TOKEN."
    echo ""
    echo "Available env files:"
    ls -la ~/.env* 2>/dev/null || echo "  No ~/.env* files found"
    echo ""
    echo "To fix: add JIRA_AUTH_TOKEN to ~/.env and run: source ~/.env"
    exit 1
fi

echo ""
```

**If JIRA_AUTH_TOKEN is missing, STOP IMMEDIATELY.** Do not proceed without it. Display the error and available env files.

#### JIRA Environment File Fallback

If JIRA access fails later during requirements analysis, try alternate env files:

1. Search for `~/.env*` files containing "jira"
2. Source each alternate file and retry
3. If all fail, reset to `~/.env` and retry
4. If still failing, STOP and report the error

```bash
# List alternate JIRA env files
ls -la ~/.env*jira* ~/.env*.jira* 2>/dev/null

# Source an alternate env file
set -a && source ~/.env.jira_internal && set +a
```

### Step 3: Initialize or Load State

Create the workflow state file or load existing state.

```bash
CLAUDE_DOCS_DIR="${PWD}/.claude_docs"
SAFE_TICKET=$(echo "$TICKET" | tr '[:upper:]' '[:lower:]' | tr '-' '_')
STATE_FILE="${CLAUDE_DOCS_DIR}/workflow/workflow_${SAFE_TICKET}.json"

# Ensure directories exist
mkdir -p "${CLAUDE_DOCS_DIR}/workflow" "${CLAUDE_DOCS_DIR}/requirements" "${CLAUDE_DOCS_DIR}/plans" "${CLAUDE_DOCS_DIR}/drafts"
```

#### For `start` action

If a state file already exists, treat it as a resume. Otherwise, create a new state file:

```bash
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Build PR URLs JSON array
PR_URLS_JSON="[]"
if [[ ${#PR_URLS[@]} -gt 0 ]]; then
    PR_URLS_JSON=$(printf '%s\n' "${PR_URLS[@]}" | jq -R . | jq -s .)
fi

cat > "$STATE_FILE" << EOF
{
  "ticket": "${TICKET}",
  "created_at": "${NOW}",
  "updated_at": "${NOW}",
  "current_stage": "requirements",
  "status": "pending",
  "options": {
    "pr_urls": ${PR_URLS_JSON},
    "create_jira_project": ${CREATE_JIRA_PROJECT:+\"$CREATE_JIRA_PROJECT\"}${CREATE_JIRA_PROJECT:-null}
  },
  "data": {
    "jira_summary": null,
    "related_prs": []
  },
  "stages": {
    "requirements": {"status": "pending", "output_file": null, "started_at": null, "completed_at": null},
    "planning": {"status": "pending", "output_file": null, "started_at": null, "completed_at": null},
    "writing": {"status": "pending", "output_file": null, "started_at": null, "completed_at": null},
    "review": {"status": "pending", "output_file": null, "started_at": null, "completed_at": null},
    "create_jira": {"status": "pending", "output_file": null, "started_at": null, "completed_at": null}
  }
}
EOF

echo "Initialized workflow for ${TICKET}"
```

#### For `resume` action

Load the existing state file and add any new `--pr` URLs:

```bash
test -f "$STATE_FILE" || {
    echo "No workflow found for ${TICKET}."
    echo "Use: /docs-tools:docs-workflow start ${TICKET}"
    exit 1
}

# Add new PR URLs if provided
for url in "${PR_URLS[@]}"; do
    TMP=$(mktemp)
    jq --arg url "$url" '.options.pr_urls += [$url] | .options.pr_urls |= unique' "$STATE_FILE" > "$TMP"
    mv "$TMP" "$STATE_FILE"
    echo "Added PR/MR URL: ${url}"
done

# Set create_jira_project if provided on resume
if [[ -n "$CREATE_JIRA_PROJECT" ]]; then
    TMP=$(mktemp)
    jq --arg proj "$CREATE_JIRA_PROJECT" '.options.create_jira_project = $proj' "$STATE_FILE" > "$TMP"
    mv "$TMP" "$STATE_FILE"
    echo "Set create-jira project: ${CREATE_JIRA_PROJECT}"
fi
```

#### For `status` action

Display the current workflow state and exit:

```bash
test -f "$STATE_FILE" || {
    echo "No workflow found for ${TICKET}."
    exit 1
}

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Documentation Workflow Status: ${TICKET}"
echo "════════════════════════════════════════════════════════════"
echo ""

STATUS=$(jq -r '.status' "$STATE_FILE")
CURRENT=$(jq -r '.current_stage' "$STATE_FILE")
PR_LIST=$(jq -r '.options.pr_urls // [] | join(", ")' "$STATE_FILE")

echo "Overall Status: ${STATUS}"
echo "Current Stage:  ${CURRENT}"
if [[ -n "$PR_LIST" ]]; then
    echo "PR/MR URLs:     ${PR_LIST}"
fi
echo ""
echo "Stages:"

CREATE_JIRA_PROJ=$(jq -r '.options.create_jira_project // ""' "$STATE_FILE")
STAGES="requirements planning writing review"
case "$CREATE_JIRA_PROJ" in
    ""|"null") ;;
    *) STAGES="$STAGES create_jira" ;;
esac

for STAGE in $STAGES; do
    STAGE_STATUS=$(jq -r ".stages.${STAGE}.status" "$STATE_FILE")
    OUTPUT=$(jq -r ".stages.${STAGE}.output_file // \"\"" "$STATE_FILE")
    case "$STAGE_STATUS" in
        "completed") ICON="[x]" ;;
        "in_progress") ICON="[>]" ;;
        "failed") ICON="[!]" ;;
        *) ICON="[ ]" ;;
    esac
    DISPLAY_NAME="${STAGE}"
    if [[ "$STAGE" == "create_jira" ]]; then
        DISPLAY_NAME="create_jira (${CREATE_JIRA_PROJ})"
    fi
    case "$OUTPUT" in
        ""|"null") echo "  ${ICON} ${DISPLAY_NAME}" ;;
        *) echo "  ${ICON} ${DISPLAY_NAME} -> ${OUTPUT}" ;;
    esac
done

echo ""
```

**If the action is `status`, display the state and STOP. Do not run any stages.**

### Step 4: Determine Next Stage

Find the first stage that is not completed. If all stages are completed, report that the workflow is done.

```bash
CREATE_JIRA_PROJ=$(jq -r '.options.create_jira_project // ""' "$STATE_FILE")
STAGES="requirements planning writing review"
case "$CREATE_JIRA_PROJ" in
    ""|"null") ;;
    *) STAGES="$STAGES create_jira" ;;
esac

NEXT_STAGE=""
for STAGE in $STAGES; do
    STAGE_STATUS=$(jq -r ".stages.${STAGE}.status" "$STATE_FILE")
    case "$STAGE_STATUS" in
        "completed") ;;
        *) NEXT_STAGE="$STAGE"; break ;;
    esac
done

if [[ -z "$NEXT_STAGE" ]]; then
    echo "Workflow for ${TICKET} is already complete."
    # Show status and stop
fi
```

If all stages are completed, show the status summary and STOP.

### Step 5: Run Stages Sequentially

Run each remaining stage in order: `requirements` → `planning` → `writing` → `review` → `create_jira` (if `--create-jira` was specified).

For each stage:

1. Update the state to `in_progress`
2. Invoke the Task tool with the appropriate agent
3. After the agent completes, verify the output file exists
4. Update the state to `completed` with the output file path
5. Proceed to the next stage

**IMPORTANT**: Run stages sequentially, not in parallel. Each stage depends on the previous stage's output.

#### State update commands

Use these bash/jq commands to update the state file before and after each stage:

**Mark stage as in_progress:**

```bash
TMP=$(mktemp)
jq --arg stage "<STAGE>" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '.stages[$stage].status = "in_progress" | .stages[$stage].started_at = $now | .updated_at = $now | .status = "in_progress" | .current_stage = $stage' \
   "$STATE_FILE" > "$TMP"
mv "$TMP" "$STATE_FILE"
```

**Mark stage as completed:**

```bash
TMP=$(mktemp)
jq --arg stage "<STAGE>" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg output "<OUTPUT_FILE>" \
   '.stages[$stage].status = "completed" | .stages[$stage].completed_at = $now | .stages[$stage].output_file = $output | .updated_at = $now' \
   "$STATE_FILE" > "$TMP"
mv "$TMP" "$STATE_FILE"
```

**Mark stage as failed:**

```bash
TMP=$(mktemp)
jq --arg stage "<STAGE>" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '.stages[$stage].status = "failed" | .updated_at = $now | .status = "failed"' \
   "$STATE_FILE" > "$TMP"
mv "$TMP" "$STATE_FILE"
```

Replace `<STAGE>` and `<OUTPUT_FILE>` with actual values for each invocation.

## Stage Prompts

The following sections define the exact prompt to pass to the Task tool for each stage. Use the Task tool with the specified `subagent_type` and include the full prompt text below.

### Stage 1: Requirements (requirements-analyst)

**Task tool parameters:**
- `subagent_type`: `docs-tools:requirements-analyst`
- `description`: `Analyze requirements for <TICKET>`

**Output file path:**

```bash
NOW=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="${CLAUDE_DOCS_DIR}/requirements/requirements_${SAFE_TICKET}_${NOW}.md"
```

**Prompt:**

> Analyze documentation requirements for JIRA ticket `<TICKET>`.
>
> **Step 1: Fetch JIRA ticket details**
>
> Use the jira-reader skill to fetch the ticket:
> - Invoke the Skill tool with `skill="jira-reader"` and `args="<TICKET>"`
>
> **Step 2: Fetch PR/MR code changes** (if PR URLs are provided)
>
> The following PR/MR URLs are associated with this ticket:
> - `<PR_URL_1>`
> - `<PR_URL_2>`
>
> For each PR/MR URL, use the git_review_api.py script:
> ```
> python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py info <url> --json
> python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py files <url> --json
> python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py diff <url>
> ```
>
> **Step 3: Expand research**
>
> Use WebSearch to find upstream documentation, release notes, and best practices related to the ticket topic.
>
> **Step 4: Write analysis**
>
> Save your complete analysis to: `<OUTPUT_FILE>`
>
> The output MUST include:
> 1. JIRA ticket summary (title, type, priority, status)
> 2. Related PRs/MRs analyzed (if any)
> 3. Code changes summary (files modified, features added/changed)
> 4. Documentation requirements identified
> 5. Recommended module types (CONCEPT, PROCEDURE, REFERENCE)
> 6. Existing release notes content from JIRA (if present)
>
> Format the output as structured markdown for the next stage.

**Note:** Only include the PR/MR URL section if PR URLs exist in the state file. Read them with:

```bash
jq -r '.options.pr_urls // [] | .[]' "$STATE_FILE"
```

After the agent completes, verify the output file exists. If not, search for the most recent file in the requirements directory:

```bash
ls -t "${CLAUDE_DOCS_DIR}/requirements/"*.md 2>/dev/null | head -1
```

### Stage 2: Planning (docs-planner)

**Task tool parameters:**
- `subagent_type`: `docs-tools:docs-planner`
- `description`: `Create documentation plan for <TICKET>`

**Output file path:**

```bash
NOW=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="${CLAUDE_DOCS_DIR}/plans/plan_${SAFE_TICKET}_${NOW}.md"
```

**Previous output:** Read from the requirements stage output file in the state:

```bash
PREV_OUTPUT=$(jq -r '.stages.requirements.output_file // ""' "$STATE_FILE")
```

**Prompt:**

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

After the agent completes, verify the output file exists.

### Stage 3: Writing (docs-writer)

**Task tool parameters:**
- `subagent_type`: `docs-tools:docs-writer`
- `description`: `Write documentation for <TICKET>`

**Output paths:**

```bash
TICKET_LOWERCASE=$(echo "$TICKET" | tr '[:upper:]' '[:lower:]')
DRAFTS_DIR="${CLAUDE_DOCS_DIR}/drafts/${TICKET_LOWERCASE}"
MODULES_DIR="${DRAFTS_DIR}/modules"
mkdir -p "${MODULES_DIR}"
OUTPUT_FILE="${DRAFTS_DIR}/_index.md"
```

**Previous output:** Read from the planning stage output file in the state:

```bash
PREV_OUTPUT=$(jq -r '.stages.planning.output_file // ""' "$STATE_FILE")
```

**Prompt:**

> Write complete AsciiDoc documentation based on the documentation plan for ticket `<TICKET>`.
>
> Read the plan from: `<PREV_OUTPUT>`
>
> **IMPORTANT**: Write COMPLETE .adoc files, not summaries or outlines.
>
> Output folder structure:
> ```
> <DRAFTS_DIR>/
> ├── _index.md                     # Index of all modules
> ├── assembly_<name>.adoc          # Assembly files at root
> └── modules/                      # All module files
>     ├── <concept-name>.adoc
>     ├── <procedure-name>.adoc
>     └── <reference-name>.adoc
> ```
>
> Save modules to: `<MODULES_DIR>/`
> Save assemblies to: `<DRAFTS_DIR>/`
> Create index at: `<DRAFTS_DIR>/_index.md`
>
> **Parallel module writing**: When the plan specifies **2 or more modules**, write them in parallel using subagents. Each subagent writes one module independently:
>
> 1. Read the documentation plan to identify all modules to write
> 2. Spawn one subagent per module in a single message:
>    ```
>    Agent(subagent_type="general-purpose", description="write <module-name>",
>      prompt="Write a complete AsciiDoc <MODULE_TYPE> module for ticket <TICKET>.
>      Module specification from plan: <module spec from plan>
>      Save to: <MODULES_DIR>/<module-name>.adoc
>      Follow Red Hat modular documentation standards.")
>    ```
> 3. After all module subagents return, write the assembly file(s) that reference them (sequential — assemblies depend on modules existing)
> 4. Create the `_index.md` listing all written files

After the agent completes, verify the index file exists at `<DRAFTS_DIR>/_index.md`.

### Stage 4: Review (docs-reviewer)

**Task tool parameters:**
- `subagent_type`: `docs-tools:docs-reviewer`
- `description`: `Review documentation for <TICKET>`

**Output path:**

```bash
TICKET_LOWERCASE=$(echo "$TICKET" | tr '[:upper:]' '[:lower:]')
DRAFTS_DIR="${CLAUDE_DOCS_DIR}/drafts/${TICKET_LOWERCASE}"
OUTPUT_FILE="${DRAFTS_DIR}/_review_report.md"
```

**Prompt:**

> Review the AsciiDoc documentation drafts for ticket `<TICKET>`.
>
> Source drafts location: `<DRAFTS_DIR>/`
> - Modules in: `<DRAFTS_DIR>/modules/`
> - Assemblies in: `<DRAFTS_DIR>/`
>
> **Edit files in place** in the drafts folder. Do NOT create copies in a separate folder.
>
> For each .adoc file:
> 1. Run Vale linting once (use the `vale` skill)
> 2. Fix obvious errors where the fix is clear and unambiguous
> 3. Run documentation review skills: modular-docs, style, language, minimalism, structure, usability
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

After the agent completes, verify the review report exists.

### Stage 5: Create JIRA (optional — direct bash/curl)

This stage only runs when `--create-jira <PROJECT>` was provided. It does NOT use a Task agent — it uses direct Bash commands with the JIRA REST API.

**Check if stage should run:**

```bash
CREATE_JIRA_PROJ=$(jq -r '.options.create_jira_project // ""' "$STATE_FILE")
if [[ -z "$CREATE_JIRA_PROJ" || "$CREATE_JIRA_PROJ" == "null" ]]; then
    echo "Skipping create_jira stage (--create-jira not specified)"
    # Skip this stage entirely — do NOT mark it in state
fi
```

If `create_jira_project` is not set in the state, skip this stage entirely and proceed to workflow completion.

**Step 5a: Check for existing "is documented by" link on parent ticket**

Before creating a new ticket, check if another ticket already "documents" this parent. If it does, skip ticket creation.

```bash
JIRA_URL="https://issues.redhat.com"

# Fetch parent ticket's issue links
LINKS_JSON=$(curl -s \
  -H "Authorization: Bearer ${JIRA_AUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  "${JIRA_URL}/rest/api/2/issue/${TICKET}?fields=issuelinks")

# Check for existing "Is documented by" link.
# In Step 5d we create the link with:
#   outwardIssue = TICKET          (the parent — source, shows "Is documented by")
#   inwardIssue  = NEW_ISSUE_KEY   (the docs ticket — destination)
# When querying TICKET's links, the docs ticket appears as inwardIssue.
HAS_DOC_LINK=$(echo "$LINKS_JSON" | jq -r '
  .fields.issuelinks[]? |
  select(
    .type.name == "Documents" and
    .inwardIssue != null
  ) | .type.name' | head -1)

if [[ -n "$HAS_DOC_LINK" ]]; then
    LINKED_KEY=$(echo "$LINKS_JSON" | jq -r '
      .fields.issuelinks[] |
      select(.type.name == "Documents" and .inwardIssue != null) |
      .inwardIssue.key' | head -1)
    echo "Parent ticket ${TICKET} already documents ${LINKED_KEY}."
    echo "Skipping JIRA creation."
fi
```

If a "Documents" link already exists, mark the stage as completed with a note and STOP. Do not create a duplicate.

**Step 5b: Extract description content from requirements output**

Read the requirements analysis output file and extract the "Executive Summary" and "User Jobs Identified" sections. These are markdown sections written by the requirements-analyst agent in Stage 1.

```bash
REQUIREMENTS_FILE=$(jq -r '.stages.requirements.output_file // ""' "$STATE_FILE")
```

Use the Read tool to read `<REQUIREMENTS_FILE>`. Then extract:

1. The content under the `## Executive Summary` heading (everything between that heading and the next `##` heading). Do NOT include the heading itself — only the content.
2. The content under the `## User Jobs Identified` heading (everything between that heading and the next `##` heading). Do NOT include the heading itself — only the content.

Combine them into a single description string. Append the following line at the end:

```
----
(i) Doc requirements generated by Claude <YYYY-MM-DD>.
See the attached markdown file for the complete generated doc plans.
*Review and validate AI generated doc plans for accuracy with an SME before implementation.*
```

Where `<YYYY-MM-DD>` is today's date from `date +%Y-%m-%d`.

**Step 5c: Create the JIRA ticket**

Use the JIRA REST API to create a new ticket. The `JIRA_AUTH_TOKEN` environment variable is used for authentication (from `~/.env`, already validated in pre-flight).

```bash
JIRA_URL="https://issues.redhat.com"
TODAY=$(date +%Y-%m-%d)

# DESCRIPTION is the extracted Executive Summary + User Jobs Identified + footer
# Escape the description for JSON
ESCAPED_DESCRIPTION=$(echo "$DESCRIPTION" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')

# Build the summary from the parent ticket's summary
PARENT_SUMMARY=$(curl -s \
  -H "Authorization: Bearer ${JIRA_AUTH_TOKEN}" \
  "${JIRA_URL}/rest/api/2/issue/${TICKET}?fields=summary" | jq -r '.fields.summary')

RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer ${JIRA_AUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  --data "{
    \"fields\": {
      \"project\": { \"key\": \"${CREATE_JIRA_PROJ}\" },
      \"summary\": \"[ccs] Docs - ${PARENT_SUMMARY}\",
      \"description\": ${ESCAPED_DESCRIPTION},
      \"issuetype\": { \"name\": \"Story\" },
      \"components\": [{ \"name\": \"Documentation\" }]
    }
  }" \
  "${JIRA_URL}/rest/api/2/issue")

NEW_ISSUE_KEY=$(echo "$RESPONSE" | jq -r '.key')

if [[ -z "$NEW_ISSUE_KEY" || "$NEW_ISSUE_KEY" == "null" ]]; then
    echo "ERROR: Failed to create JIRA ticket."
    echo "Response: $RESPONSE"
    # Mark stage as failed
    exit 1
fi

echo "Created JIRA ticket: ${NEW_ISSUE_KEY}"
echo "URL: ${JIRA_URL}/browse/${NEW_ISSUE_KEY}"
```

**Step 5d: Link the new ticket to the parent ticket**

Create a "Documents" link so that the parent ticket "documents" the new docs ticket.

```bash
# outwardIssue = TICKET (the parent — source, shows "documents")
# inwardIssue  = NEW_ISSUE_KEY (the docs ticket — destination, shows "is documented by")
curl -s -X POST \
  -H "Authorization: Bearer ${JIRA_AUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  --data "{
    \"type\": { \"name\": \"Documents\" },
    \"outwardIssue\": { \"key\": \"${TICKET}\" },
    \"inwardIssue\": { \"key\": \"${NEW_ISSUE_KEY}\" }
  }" \
  "${JIRA_URL}/rest/api/2/issueLink"

echo "Linked ${TICKET} documents ${NEW_ISSUE_KEY}"
```

If the "Documents" link type name does not match, query available link types to find the correct one:

```bash
curl -s -H "Authorization: Bearer ${JIRA_AUTH_TOKEN}" \
  "${JIRA_URL}/rest/api/2/issueLinkType" | jq '.issueLinkTypes[] | {name, inward, outward}'
```

**Step 5e: Attach the docs plan**

Attach the full documentation plan file (Stage 2 output) to the new JIRA ticket.

```bash
PLAN_FILE=$(jq -r '.stages.planning.output_file // ""' "$STATE_FILE")

if [[ -n "$PLAN_FILE" && -f "$PLAN_FILE" ]]; then
    curl -s -X POST \
      -H "Authorization: Bearer ${JIRA_AUTH_TOKEN}" \
      -H "X-Atlassian-Token: no-check" \
      -F "file=@${PLAN_FILE}" \
      "${JIRA_URL}/rest/api/2/issue/${NEW_ISSUE_KEY}/attachments"
    echo "Attached docs plan: ${PLAN_FILE}"
fi
```

**Step 5f: Update state**

After the ticket is created and linked, mark the stage as completed with the new ticket URL as the output file.

```bash
TMP=$(mktemp)
jq --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg output "${JIRA_URL}/browse/${NEW_ISSUE_KEY}" \
   '.stages.create_jira.status = "completed" | .stages.create_jira.completed_at = $now | .stages.create_jira.output_file = $output | .updated_at = $now' \
   "$STATE_FILE" > "$TMP"
mv "$TMP" "$STATE_FILE"
```

## Workflow Completion

After all stages complete successfully (four core stages, plus the optional create_jira stage if `--create-jira` was specified), update the overall workflow status:

```bash
TMP=$(mktemp)
jq --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '.status = "completed" | .updated_at = $now' \
   "$STATE_FILE" > "$TMP"
mv "$TMP" "$STATE_FILE"
```

Then display the final status summary showing all stages as completed, and inform the user where the output files are located.

If the `create_jira` stage completed, display the created JIRA ticket URL as a clickable link:

```bash
CREATED_JIRA_URL=$(jq -r '.stages.create_jira.output_file // ""' "$STATE_FILE")
case "$CREATED_JIRA_URL" in
    ""|"null") ;;
    *) echo ""; echo "Created JIRA ticket: ${CREATED_JIRA_URL}" ;;
esac
```

**IMPORTANT**: Always display the JIRA URL at the end of the workflow output so the user can click directly to the created ticket.

## Access Failure Handling

If any stage fails due to access issues (JIRA, GitHub, GitLab):

1. **STOP IMMEDIATELY** — Do not proceed to the next stage
2. **Report the exact error** — Display the full error message
3. **List available env files** — Run `ls -la ~/.env* 2>/dev/null`
4. **Mark the stage as failed** in the state file
5. **Await user action** — User must fix credentials and resume with:
   ```
   /docs-tools:docs-workflow resume <TICKET>
   ```
6. **NEVER guess or infer** — No assumptions about ticket or PR content

### Why this matters

If JIRA access fails and the workflow proceeded anyway, it would make assumptions about what a ticket is about based on the ticket ID, generate documentation for the wrong topic entirely, and waste effort that must be completely redone.

## Usage Examples

Start a new workflow:
```bash
/docs-tools:docs-workflow start RHAISTRAT-123
```

Start with a related PR/MR:
```bash
/docs-tools:docs-workflow start RHAISTRAT-123 --pr https://github.com/org/repo/pull/456
```

Start with a GitLab MR:
```bash
/docs-tools:docs-workflow start RHAISTRAT-123 --pr https://gitlab.com/org/repo/-/merge_requests/789
```

Check workflow status:
```bash
/docs-tools:docs-workflow status RHAISTRAT-123
```

Resume and add a PR URL:
```bash
/docs-tools:docs-workflow resume RHAISTRAT-123 --pr https://github.com/org/repo/pull/456
```

Start with JIRA creation in INFERENG project:
```bash
/docs-tools:docs-workflow start RHAISTRAT-123 --create-jira INFERENG
```

Add JIRA creation on resume (after review completes):
```bash
/docs-tools:docs-workflow resume RHAISTRAT-123 --create-jira INFERENG
```

## Prerequisites

- `jq` — JSON processor (install with: `sudo dnf install jq`)
- `python3` — Python 3 for git_review_api.py
- `jira-reader` skill installed (from pr-plugins marketplace)
- `JIRA_AUTH_TOKEN` in `~/.env` (required)
- `GITHUB_TOKEN` and/or `GITLAB_TOKEN` in `~/.env` (for PR/MR access)

## Notes

- If no action is specified, the command defaults to `start`
- The ticket parameter is required for all actions
- Workflow state is maintained between runs for resume functionality
- All outputs are organized by ticket ID for easy tracking
- Multiple --pr URLs can be added across start/resume commands
- **Access failures stop the workflow** — the workflow never guesses or infers content
- **Stage 3 (writing) uses parallel subagents** to write multiple modules concurrently; assemblies are written sequentially after modules complete
- **Stage 4 (review) uses parallel subagents** to run review skills concurrently per file (see `docs-reviewer` parallel execution mode)
- The review stage edits files in place in the drafts folder rather than creating copies
- The `--create-jira` stage is optional — it only runs when the flag is provided with a project key
- The `--create-jira` stage checks for existing "Is documented by" links on the parent ticket before creating a duplicate ticket. If the "Is documented by" link exists, a new ticket is not created.
- The created JIRA description contains the Executive Summary and User Jobs Identified from the requirements analysis (not the section title for Executive Summary, just its content), with the full docs plan attached
