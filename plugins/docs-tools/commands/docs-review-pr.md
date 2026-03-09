---
description: Review documentation changes in a GitHub PR or GitLab MR
argument-hint: <pr-url> [--post-comments]
allowed-tools: Read, Write, Glob, Grep, Edit, Bash, Skill, WebFetch, Agent
---

# Documentation Review Workflow

Review documentation changes in a GitHub Pull Request or GitLab Merge Request using documentation review skills.

## Required Argument

- **pr-url**: (required) GitHub PR or GitLab MR URL

## Options

- **--post-comments**: Post review findings as inline comments on the PR/MR under your username

**IMPORTANT**: This command requires a PR/MR URL. If no argument is provided, stop and ask the user to provide one.

## Supported URL Formats

- **GitHub**: `https://github.com/owner/repo/pull/123`
- **GitLab**: `https://gitlab.com/group/project/-/merge_requests/123`

## Workflow Overview

This command:

1. **Detect platform**: Determine GitHub or GitLab from URL
2. **Fetch PR/MR info**: Get title, description, and changed files
3. **Filter files**: Only review `.adoc` and `.md` files
4. **Fetch file content**: Get the current content of changed files
5. **Run reviews**: Apply documentation review skills
6. **Generate report**: Create a consolidated review report
7. **Post comments** (optional): Post inline review comments to PR/MR

## Step-by-Step Instructions

### Step 1: Validate Input and Detect Platform

Parse the PR/MR URL to determine the platform:

```bash
PR_URL="${1}"

# Detect platform from URL
if echo "${PR_URL}" | grep -q "github.com"; then
    PLATFORM="github"
    echo "Platform: GitHub"
elif echo "${PR_URL}" | grep -q "gitlab"; then
    PLATFORM="gitlab"
    echo "Platform: GitLab"
else
    echo "ERROR: Unable to determine platform from URL: ${PR_URL}"
    echo "Supported formats:"
    echo "  GitHub: https://github.com/owner/repo/pull/123"
    echo "  GitLab: https://gitlab.com/group/project/-/merge_requests/123"
    exit 1
fi
```

### Step 2: Fetch PR/MR Information

Use the Git Review API Python script (works for both GitHub and GitLab):

```bash
# Get PR/MR info
python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py info "${PR_URL}" --json

# Get list of changed files
python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py files "${PR_URL}" --json
```

### Step 3: Filter for Documentation Files

Filter the file list to only include `.adoc` and `.md` files:

```bash
# Get all changed files and filter for documentation
python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py files "${PR_URL}" --filter "*.adoc" --json > /tmp/docs-review-adoc.json
python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py files "${PR_URL}" --filter "*.md" --json > /tmp/docs-review-md.json

# Or get all files and filter locally
python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py files "${PR_URL}" --json | \
    python3 -c "import json,sys; files=[f['path'] for f in json.load(sys.stdin) if f['path'].endswith(('.adoc','.md'))]; print('\n'.join(files))" > /tmp/docs-review-doc-files.txt

# Count files
DOC_FILES=$(wc -l < /tmp/docs-review-doc-files.txt)

echo "Documentation files (.adoc, .md): ${DOC_FILES}"

# Check if any documentation files exist
if [ "${DOC_FILES}" -eq 0 ]; then
    echo ""
    echo "No documentation files (.adoc or .md) found in this PR/MR."
    echo "Review complete - no documentation changes to review."
    exit 0
fi
```

### Step 4: Fetch Changed File Content

Get the diff to extract file content:

```bash
# Get the full diff
python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py diff "${PR_URL}" > /tmp/pr-diff.txt

# Or dump lines for a specific file
python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py extract --dump "${PR_URL}" "path/to/file.adoc"
```

### Step 5: Run Documentation Reviews

For each documentation file, run the appropriate review skills based on file type.

#### Detect RHOAI repository

Check if the PR/MR URL matches a Red Hat AI documentation repository. If so, include the `docs-review-rhoai` skill in the review.

```bash
# RHOAI repository patterns
RHOAI_REPOS=(
    "documentation-red-hat-openshift-data-science-documentation/openshift-ai-documentation"
    "documentation-red-hat-openshift-data-science-documentation/vllm-documentation"
    "documentation-red-hat-openshift-data-science-documentation/rhel-ai"
    "opendatahub-io/opendatahub-documentation"
)

# Check if PR URL matches any RHOAI repository
USE_RHOAI_REVIEW=false
for repo in "${RHOAI_REPOS[@]}"; do
    if echo "${PR_URL}" | grep -q "${repo}"; then
        USE_RHOAI_REVIEW=true
        echo "RHOAI repository detected: ${repo}"
        echo "Including docs-review-rhoai skill in review"
        break
    fi
done
```

#### Initialize review output

```bash
# Create output directory
mkdir -p /tmp/docs-review-output

# Initialize the review report
cat > /tmp/docs-review-output/review-report.md << 'EOF'
# Documentation Review Report

**PR/MR**: ${PR_URL}
**Date**: $(date +%Y-%m-%d)

## Summary

| Metric | Count |
|--------|-------|
| Total files changed | ${TOTAL_FILES} |
| Documentation files | ${DOC_FILES} |

## Files Reviewed

EOF
```

#### Review each file

For each file in `/tmp/docs-review-doc-files.txt`:

**Step 1: Run Vale first** (sequential prerequisite):
```bash
vale "${FILE_PATH}" > /tmp/docs-review-output/vale-${BASENAME}.txt 2>&1 || true
```

**Step 2: Run review skills in parallel using subagents**

Spawn all independent review skills as parallel subagents in a single message. Each subagent reads the file, applies its checklist, and returns findings.

**For `.adoc` files**, spawn 6 subagents in parallel (7 if RHOAI):

```
Agent(subagent_type="general-purpose", model="haiku", description="review language",
  prompt="Read <file_path>. Apply docs-review-language checklist. Vale output: <vale_output>.
  Return findings as: ## Language Review\n### Findings\n(severity, location, problem, fix)")

Agent(subagent_type="general-purpose", model="haiku", description="review style", prompt="...")
Agent(subagent_type="general-purpose", model="haiku", description="review minimalism", prompt="...")
Agent(subagent_type="general-purpose", model="haiku", description="review structure", prompt="...")
Agent(subagent_type="general-purpose", model="haiku", description="review usability", prompt="...")
Agent(subagent_type="general-purpose", model="haiku", description="review modular-docs", prompt="...")
# If USE_RHOAI_REVIEW=true:
Agent(subagent_type="general-purpose", model="haiku", description="review rhoai", prompt="...")
```

**For `.md` files**, spawn 5 subagents (6 if RHOAI) — skip modular-docs.

Each subagent receives:
- The file path to read
- The Vale output for context
- The specific review skill checklist (from the SKILL.md)
- Instructions to return findings with: issue description, location, severity, fix

**Step 3: Merge subagent results**

After all subagents return:
1. Collect findings from all subagents
2. Deduplicate issues flagged by both Vale and a review skill
3. Group by severity (errors first, then warnings, then suggestions)
4. Format using `docs-review-feedback` guidelines

### Step 6: Generate Consolidated Review Report

**IMPORTANT**: Use Bash with heredoc to write /tmp files (the Write tool requires reading first):

```bash
cat > /tmp/docs-review-report.md << 'EOF'
# Documentation Review Report
...content...
EOF
```

Create a markdown report at `/tmp/docs-review-report.md`:

```markdown
# Documentation Review Report

**PR/MR**: [PR Title](PR_URL)
**Platform**: GitHub | GitLab
**Review Date**: YYYY-MM-DD

## Overview

| Metric | Value |
|--------|-------|
| Total files changed | X |
| Documentation files reviewed | Y |
| Required changes | Z |
| Suggestions | N |

## Files Reviewed

### 1. path/to/file.adoc

**Type**: AsciiDoc (CONCEPT | PROCEDURE | REFERENCE | ASSEMBLY)

#### Vale Linting

| Line | Severity | Rule | Message |
|------|----------|------|---------|
| 15 | error | RedHat.TermsErrors | Use 'data center' rather than 'datacenter' |

#### Modular Docs Compliance

- [x] Module type declared
- [x] Anchor ID includes _{context}
- [ ] **REQUIRED**: Title should use gerund form for procedure

#### Language

- [x] American English spelling
- [ ] **SUGGESTION**: Expand acronym "API" on first use

#### Style

- [x] Active voice used
- [ ] **REQUIRED**: Line 42: Change "will be created" to "is created"

#### Minimalism

- [x] Content focuses on user tasks
- [ ] **SUGGESTION**: Line 28-30 could be more concise

#### Structure

- [x] Information in logical order
- [x] Prerequisites before procedures

#### Usability

- [x] Links have descriptive text
- [ ] **SUGGESTION**: Add alt text to image on line 55

---

### 2. path/to/another-file.md

...

---

## Summary of Required Changes

These issues must be addressed before merging:

1. **file.adoc:42**: Use active voice instead of passive
2. **file.adoc:15**: Correct terminology: 'data center' not 'datacenter'

## Summary of Suggestions

These are optional improvements:

1. **file.adoc:28**: Consider condensing explanation
2. **another-file.md:12**: Expand acronym on first use

---

*Generated with [Claude Code](https://claude.com/claude-code)*
```

### Step 7: Generate Comments JSON (Deterministic Approach)

Create a JSON file with all review findings for posting as inline comments.

**CRITICAL**: Line numbers MUST be extracted from the actual PR diff using the helper script. Do NOT estimate or guess line numbers.

#### Step 7.1: Dump the Diff Line Map

First, extract the line number map for each file you want to comment on:

```bash
# Dump all added/modified lines with their correct file line numbers
python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py extract --dump "${PR_URL}" "path/to/file.adoc" > /tmp/file-lines.txt

# Output format: LINE_NUMBER<tab>CONTENT
# Example:
# 1	// Module comment
# 2
# 3	:_mod-docs-content-type: PROCEDURE
# 4	[id="example_{context}"]
# 5	= Example Title
# ...
# 13	.Prerequisites
```

#### Step 7.2: Identify Issues by Content, Look Up Line Numbers

When you find an issue, identify it by the **content pattern**, then use the script to get the exact line number:

```bash
# You identify: "The .Prerequisites line should use a numbered list"
# Get the exact line number from the script:
LINE=$(python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py extract "${PR_URL}" "path/to/file.adoc" ".Prerequisites")
echo $LINE  # Output: 13

# Or search the already-dumped file:
grep -F ".Prerequisites" /tmp/file-lines.txt | cut -f1
# Output: 13
```

#### Step 7.3: Build the Comments JSON

For each issue, use the script to get the line number, then add to the JSON:

```bash
# Get line numbers for each issue
FILE="path/to/file.adoc"
LINE1=$(python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py extract "${PR_URL}" "$FILE" "deloyed")
LINE2=$(python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py extract "${PR_URL}" "$FILE" ".Prerequisites")

# Build JSON with script-extracted line numbers
cat > /tmp/docs-review-comments.json << EOF
[
  {"file": "$FILE", "line": $LINE1, "severity": "error", "message": "Typo: \"deloyed\" should be \"deployed\""},
  {"file": "$FILE", "line": $LINE2, "severity": "warning", "message": "Prerequisites should use numbered list"}
]
EOF
```

For each finding, add an entry with:
- **file**: The file path relative to repository root
- **line**: The line number from the script (never estimated)
- **severity**: One of `error`, `warning`, or `suggestion`
- **message**: Concise description (do NOT include line numbers in the message)

### Step 7a: How the Git Review API Works

The `git_review_api.py` Python script provides a unified API for extracting line numbers from PR diffs and posting comments. It parses the unified diff format to map content to correct file line numbers.

#### Diff Format Explained

```
diff --git a/modules/example.adoc b/modules/example.adoc     <- header
new file mode 100644                                          <- header
--- /dev/null                                                 <- header
+++ b/modules/example.adoc                                    <- header
@@ -0,0 +1,50 @@                                              <- hunk header (line 1, 50 lines)
+// Module comment                                             <- file line 1
+                                                              <- file line 2
+:_mod-docs-content-type: PROCEDURE                           <- file line 3
+[id="example_{context}"]                                      <- file line 4
+= Example Title                                               <- file line 5
```

Rules applied:
- Lines starting with `+` are added lines (increment file line counter)
- Lines starting with `-` are deleted lines (do NOT increment)
- Lines starting with ` ` (space) are context lines (increment file line counter)
- Hunk header `@@ -old,count +new,count @@` sets the starting line number

#### Available Commands

```bash
# Dump all lines with their file line numbers
python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py extract --dump "${PR_URL}" "path/to/file.adoc"

# Find line number for a specific pattern
python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py extract "${PR_URL}" "path/to/file.adoc" "pattern"

# Validate comments JSON against PR diff
python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py extract --validate "${PR_URL}" /tmp/docs-review-comments.json
```

### Step 8: Post Inline Comments (if --post-comments)

If the `--post-comments` option is provided, post the review findings as inline comments on the PR/MR.

**Comments are posted under YOUR username** using tokens from `~/.env`.

```bash
# Post comments using the Python script
python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py post "${PR_URL}" /tmp/docs-review-comments.json

# Or dry-run first to preview
python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py post "${PR_URL}" /tmp/docs-review-comments.json --dry-run
```

The script:
- Detects the platform (GitHub/GitLab) from the URL
- Uses tokens from `~/.env` (GITLAB_TOKEN, GITHUB_TOKEN) with CLI fallback
- Posts each comment as an inline diff comment at the specified file:line
- Skips comments that already exist (avoids duplicates)

**Example comment format on the PR/MR:**

```
Typo: "deloyed" should be "deployed"

🤖 RHAI docs Claude Code review
```

```
Service selector uses `app: granite-spyre` but Deployment uses `app: granite`

🤖 RHAI docs Claude Code review
```

```
Consider using `$NAMESPACE` variable for consistency

🤖 RHAI docs Claude Code review
```

### Step 9: Present Results

After generating the report:

1. Display a summary to the user
2. Inform them where the full report is saved
3. Report on posted comments (if --post-comments was used)

```bash
echo ""
echo "Documentation review complete."
echo ""
echo "Summary:"
echo "  - Files reviewed: ${DOC_FILES}"
echo "  - Required changes: <count>"
echo "  - Suggestions: <count>"
echo ""
echo "Full report saved to: /tmp/docs-review-report.md"
echo "Comments JSON saved to: /tmp/docs-review-comments.json"
echo ""
echo "To copy report to clipboard:"
echo "  cat /tmp/docs-review-report.md | xclip -selection clipboard"
```

If `--post-comments` was used:
```bash
echo ""
echo "Inline comments posted to PR/MR under your username."
```

## Review Skills Reference

| Skill | Applies To | Focus |
|-------|------------|-------|
| `vale` | .adoc | Style guide linting (RedHat, IBM rules) |
| `docs-review-modular-docs` | .adoc | Module types, anchor IDs, assemblies |
| `docs-review-language` | .adoc, .md | Spelling, grammar, acronyms |
| `docs-review-style` | .adoc, .md | Voice, tense, titles, formatting |
| `docs-review-minimalism` | .adoc, .md | Conciseness, scannability |
| `docs-review-structure` | .adoc, .md | Logical flow, user stories |
| `docs-review-usability` | .adoc, .md | Accessibility, links, rendering |
| `docs-review-rhoai` | .adoc, .md | RHOAI conventions, product naming, terminology (auto-enabled for RHOAI repos) |
| `docs-review-feedback` | N/A | How to format review comments |

## Usage Examples

Review a GitHub PR (report only):
```bash
/docs-tools:docs-review-pr https://github.com/redhat-documentation/openshift-docs/pull/12345
```

Review a GitLab MR (report only):
```bash
/docs-tools:docs-review-pr https://gitlab.cee.redhat.com/documentation/rhel-docs/-/merge_requests/678
```

Review and post inline comments to a GitHub PR:
```bash
/docs-tools:docs-review-pr https://github.com/owner/repo/pull/123 --post-comments
```

Review and post inline comments to a GitLab MR:
```bash
/docs-tools:docs-review-pr https://gitlab.cee.redhat.com/group/project/-/merge_requests/456 --post-comments
```

## Output

The workflow produces:

1. **Console summary**: Quick overview of review results
2. **Review report**: `/tmp/docs-review-report.md` - detailed findings for each file
3. **Comments JSON**: `/tmp/docs-review-comments.json` - structured data for posting comments
4. **Vale output**: `/tmp/docs-review-output/vale-*.txt` - raw Vale linting results (if available)

If `--post-comments` is used:
5. **Inline comments**: Posted directly to the PR/MR under your username

## Git Review API Script

The `git_review_api.py` Python script can be used standalone to post review comments and extract line numbers:

```bash
# Post comments from a JSON file
python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py post <pr-url> <comments.json>

# Dry-run to preview without posting
python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py post <pr-url> <comments.json> --dry-run

# Extract line numbers from diff
python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py extract --dump <pr-url> <file-path>

# Find line number for a pattern
python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py extract <pr-url> <file-path> <pattern>

# Validate comments against PR diff
python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py extract --validate <pr-url> <comments.json>
```

**Comments JSON format:**
```json
[
  {"file": "path/to/file.adoc", "line": 42, "severity": "error", "message": "Typo: \"deloyed\" should be \"deployed\""},
  {"file": "path/to/file.adoc", "line": 15, "severity": "warning", "message": "Service selector mismatch with Deployment labels"},
  {"file": "path/to/file.md", "line": 8, "severity": "suggestion", "message": "Consider expanding acronym on first use"}
]
```

**Message format guidelines:**
- Keep messages concise - do NOT include line numbers (the comment is already positioned)
- Do NOT include "Suggested fix:" in the message body
- The signature "🤖 RHAI docs Claude review" is added automatically

**Severity levels** (used internally for tracking, not shown in comment body):
- `error` / `critical`: Must fix
- `warning`: Should fix
- `suggestion`: Optional improvement

Comments are posted with a minimal format: just the message followed by the signature "🤖 RHAI docs Claude Code review".

## Notes

- This workflow does NOT make changes to files - it only reviews and reports
- For .adoc files, modular docs compliance is checked in addition to other reviews
- Markdown files receive language, style, minimalism, structure, and usability reviews
- Vale linting requires Vale to be installed and configured
- The workflow works on the PR/MR branch content, not the local files
- **Comments are posted under YOUR username** using tokens from `~/.env`
- Duplicate comments are automatically skipped
- Comments are posted as inline diff comments on the specific lines
- Always use Bash with heredoc/cat for writing /tmp files (not the Write tool)
- **CRITICAL: Always use `git_review_api.py extract` for deterministic line numbers** - never estimate or guess line numbers. The script parses the actual PR diff to ensure comments appear on the correct lines.

## Git Review API Commands

| Command | Purpose |
|---------|---------|
| `git_review_api.py extract --dump` | Extract correct line numbers from PR diff |
| `git_review_api.py extract` | Find line number for a pattern |
| `git_review_api.py extract --validate` | Validate comments against PR diff |
| `git_review_api.py post` | Post review comments to PR/MR |

### git_review_api.py Usage

```bash
# Dump all lines with their file line numbers
python git_review_api.py extract --dump <pr-url> <file-path>

# Find line number for a specific pattern
python git_review_api.py extract <pr-url> <file-path> <pattern>

# Validate comments JSON against PR diff
python git_review_api.py extract --validate <pr-url> <comments.json>

# Post comments
python git_review_api.py post <pr-url> <comments.json>
```

## Prerequisites for Posting Comments

To post inline comments, you must have tokens configured in `~/.env`:

```bash
# ~/.env file format
GITLAB_TOKEN=your_gitlab_personal_access_token
GITHUB_TOKEN=your_github_personal_access_token
```

Tokens require the following scopes:
- **GitLab**: `api` scope
- **GitHub**: `repo` scope
