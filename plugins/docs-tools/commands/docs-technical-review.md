---
description: Validate documentation technical accuracy against code repositories — detects stale commands, flags, APIs, config keys, code examples, and file paths. Use when asked to check if docs match the code, verify examples, find outdated references, or run a technical review.
argument-hint: --docs <source> [--docs <source>...] [--code URL] [--jira TICKET] [--pr URL] [--gdoc URL] [--fix]
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task, WebFetch, AskUserQuestion
---

## Name

docs-tools:docs-technical-review

## Synopsis

`/docs-tools:docs-technical-review --docs <source> [--docs <source>...] [--code URL] [--jira TICKET] [--pr URL] [--gdoc URL] [--fix]`

## Description

Validate documentation for technical accuracy by comparing against source code repositories.

**Two modes**:

1. **Report only** (default) — validate and produce a human-readable report. No files are modified.
2. **Fix mode** (`--fix`) — validate, auto-fix high-confidence issues (>=65%), then interactively walk through remaining issues one by one.

## Implementation

### Arguments

### Required

- `--docs <source>` — Documentation to validate (repeatable). Can be a file path, directory, glob pattern, PR/MR URL, Google Doc URL, or remote repo URL.

If no `--docs` is provided, stop and ask the user.

### Repository Discovery (at least one required)

| Argument | Description |
|----------|-------------|
| `--code <URL>` | Explicit code repository URL (repeatable) |
| `--ref <branch>` | Git ref for previous `--code` (default: main) |
| `--jira <TICKET-123>` | Auto-discover repos from JIRA ticket |
| `--pr <URL>` | Auto-discover from PR/MR URL (repeatable) |
| `--gdoc <URL>` | Auto-discover from Google Doc |

**Discovery priority**: `--code` > `--pr` > `--jira` > `--gdoc` > AsciiDoc `:code-repo-url:` attributes

### Actions

| Flag | Description |
|------|-------------|
| *(none)* | Validate only, write report. No files modified. |
| `--fix` | Validate, auto-fix high-confidence issues (>=65%), then interactively step through remaining issues. |

## Usage Examples

```bash
# Report only — validate docs against a code repo
/docs-tools:docs-technical-review --docs modules/ \
  --code https://github.com/org/repo

# Fix mode — auto-fix + interactive walkthrough
/docs-tools:docs-technical-review --docs modules/ \
  --code https://github.com/org/repo --fix

# Multiple doc sources and repos via JIRA + PR
/docs-tools:docs-technical-review --docs modules/ --docs guides/admin/ \
  --jira PROJ-123 --pr https://github.com/org/repo/pull/456 --fix
```

## Implementation Workflow

### Step 1: Parse Arguments

Extract arguments from the user's command. If `--docs` is empty, stop and ask the user.

### Step 2: Resolve Docs Sources

Each `--docs` source is auto-detected and resolved:

| Source Type | Detection | Resolution |
|-------------|-----------|------------|
| Local file | Path exists as file | Use directly |
| Local directory | Path exists as directory | Glob for `*.adoc` and `*.md` files |
| Glob pattern | Contains `*` or `?` | Expand pattern to matching files |
| PR/MR URL | Matches GitHub/GitLab PR URL pattern | Fetch changed doc files via `./scripts/git_review_api.py` |
| Google Doc URL | Matches `docs.google.com` | Read via `docs-tools:docs-convert-gdoc-md` skill, save to temp file |
| Remote repo URL | Matches `https://github.com` or `https://gitlab.com` (non-PR) | Clone and glob for doc files |

### Step 3: Discover Code Repositories

Use discovery methods in priority order. If `--jira` is provided, fetch the JIRA ticket using the `docs-tools:jira-reader` skill, extract linked PR/MR URLs, and parse for repo references. If no repos are found by any method, search for `:code-repo-url:` attributes in AsciiDoc files as a fallback.

Verify at least one repo was found. If not, stop with an error listing the available discovery options.

### Step 4: Clone Code Repositories

Clone each repo to `/tmp/tech-review/<repo-name>/` using `git clone`. Do NOT use `--depth 1` — the search script uses `git log` to find rename and deprecation evidence, which requires full history. Try the specified `--ref` first, fall back to default branch. Skip repos already cloned. Warn and continue if a clone fails.

### Parallelization

When multiple code repositories are involved, parallelize the review pipeline across repos using subagents. Each repo's pipeline is independent and can run concurrently. Merge JSON results before proceeding to Step 6.

For single-repo reviews, run sequentially.

### Step 5: Run Deterministic Review Pipeline

Run the `tech_references.py` script in `review` mode. This chains four deterministic phases (extract → search → triage → scan) in a single invocation:

```bash
python3 "./scripts/tech_references.py" review \
  "${DOCS_FILES[@]}" \
  --repos "${REPO_PATHS[@]}" \
  --docs-dir "${DOCS_SCAN_DIR}" \
  --output /tmp/tech-review-results.json
```

Where:
- `${DOCS_FILES[@]}` — resolved doc file paths from Step 2
- `${REPO_PATHS[@]}` — cloned repo paths from Step 4 (e.g. `/tmp/tech-review/repo1`)
- `${DOCS_SCAN_DIR}` — parent directory of `--docs` sources, used for blast-radius scanning

The script produces a JSON file with:
- `issues` — items flagged with confidence, severity, triage_pass, triage_status, evidence, suggested_fix, and blast_radius
- `out_of_scope` — external commands skipped
- `verified` — items that passed all checks
- `discovered_schemas` — schema files found in code repos
- `discovered_cli_definitions` — CLI entry points found (argparse, click, cobra)

### Step 6: Source Verification (Pass 4)

The Python script handles passes 1-3 deterministically. Pass 4 requires reading source code.

For each issue with `triage_status: needs-confirmation` and `confidence >= 50`:

1. Read the source file cited in the `evidence` field
2. Confirm or refute the issue based on what the source code actually says
3. Upgrade confidence if source confirms the issue
4. Downgrade confidence (or drop the issue) if source contradicts it

Do not report issues you cannot confirm against source code.

**Severity levels**: `High` = users will hit errors (broken commands, missing APIs). `Medium` = misleading but not blocking (wrong names, stale options). `Low` = cosmetic or informational.

**Threshold**: >=65% = auto-fixable, <65% = needs interactive review.

### Step 7: Report or Fix

#### Path 1: Report only (no `--fix`)

Write `.claude/docs/technical-review-report.md` with these sections:

1. **Header** — docs sources, timestamp, repo count
2. **Discovery Summary** — discovered schemas, CLI definitions, and scope classification stats (how many commands were external/in-scope/unknown)
3. **Triage Summary** — counts by pass (scope-filtered, deterministic, evidence-based, source-verified)
4. **Summary table** — per-category counts (validated, issues found, by severity)
5. **Code Repositories** — URL, ref, source, clone path
6. **Issues Found** — each with ID, location, severity, confidence, issue description, evidence, suggested fix, reasoning, validation source (cli_validation/schema_validation/git_evidence/manual_analysis)
7. **Whole-Repo Scan Results** — grouped by issue type, listing all files/lines affected
8. **Out-of-Scope References** — summary count of external commands skipped, grouped by tool name (collapsed, not individual items)

Display the summary to the user and the path to the report file.

#### Path 2: Fix mode (`--fix`)

**Phase A — Auto-fix high-confidence issues**:

For each issue with confidence >=65%, apply the fix using the Edit tool. Track each fix applied.

**Phase B — Interactive walkthrough of remaining issues**:

For each issue with confidence <65%, present it to the user and ask how to proceed. If there are no remaining issues, skip to the report.

**For each item**:

1. **Read current file** to verify the issue text exists
2. **Present** the item:

```
Issue 1 of 5: Command flag renamed | Confidence: 60% | Severity: High
File: modules/proc-install.adoc

Current:   $ my-tool --enable-feature
Suggested: $ my-tool --feature-enable

Evidence: Flag renamed in commit abc123, git log confirms deprecation
Reasoning: Exact command exists, only the flag changed — likely a rename
```

3. **Ask user** via `AskUserQuestion` with four options:
   - **Apply suggested fix** — use as-is
   - **Modify fix** — ask what they want changed, apply modified version
   - **Skip** — leave for manual editing later
   - **Delete section** — remove entirely from documentation

4. **Apply fix** using content-based matching: `Edit(file_path=FILE, old_string=old_text, new_string=new_text)`

**After all items**: Write `.claude/docs/technical-review-report.md` with the same sections as Path 1, plus:

- **Issues Auto-Fixed** — each with ID (`AF-N`), location, issue, evidence, before/after diff
- **Issues Interactively Resolved** — each with ID, action taken (applied/modified/deleted)
- **Issues Skipped** — each with ID, location, issue (for future reference)

Display counts of auto-fixed, interactively applied, modified, skipped, and deleted items.

## Error Handling

- **No `--docs` provided**: Stop and ask the user
- **No repos discovered**: Exit with error, show discovery options
- **Clone failures**: Warn and skip repo, continue with others
- **No references found**: Exit gracefully with summary
- **Issue text not found in file**: Warn user, show current file content, ask how to proceed
- **Edit operation fails**: Report error, ask to retry or skip

## Prerequisites

- `python3` — for the review pipeline, JIRA, and Git review API scripts
- `git` — for cloning repositories
- For JIRA discovery: `JIRA_AUTH_TOKEN` in `~/.env`
- For PR discovery: `GITHUB_TOKEN` or `GITLAB_TOKEN` in `~/.env`
