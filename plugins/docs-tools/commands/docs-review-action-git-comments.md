---
description: Review and action unresolved PR/MR comments from GitHub or GitLab
argument-hint: [<pr-url>]
allowed-tools: Read, Write, Glob, Grep, Edit, Bash, AskUserQuestion
---

# Action Git PR/MR Review Comments

Fetch unresolved review comments from GitHub Pull Requests or GitLab Merge Requests and action them one by one.

## Optional Argument

- **pr-url**: GitHub PR or GitLab MR URL (if omitted, finds PR/MR for current branch)

## Supported URL Formats

- **GitHub**: `https://github.com/owner/repo/pull/123`
- **GitLab**: `https://gitlab.com/group/project/-/merge_requests/123`

## Git Review API

This command uses the `git_review_api.py` Python script for interacting with GitHub PRs and GitLab MRs.

### Script Location

```
${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py
```

### Available Commands

| Command | Description |
|---------|-------------|
| `post <pr-url> <comments.json>` | Post review comments to a PR/MR |
| `post <pr-url> <comments.json> --dry-run` | Preview comments without posting |
| `extract <pr-url> <file-path> <pattern>` | Find line number for a pattern in diff |
| `extract --dump <pr-url> <file-path>` | Dump all added/modified lines with line numbers |
| `extract --validate <pr-url> <comments.json>` | Validate comments against actual diff |

## Authentication

Authentication is handled automatically by `git_review_api.py`. Tokens are **required** (no CLI fallback):

| Platform | Token |
|----------|-------|
| GitHub | `GITHUB_TOKEN` in `~/.env` |
| GitLab | `GITLAB_TOKEN` in `~/.env` |

Required token scopes:
- **GitHub**: `repo` scope for private repos, `public_repo` for public
- **GitLab**: `api` scope for full API access

## Workflow Overview

1. **Validate PR URL**: Confirm the provided URL is valid
2. **Fetch comments**: Retrieve all unresolved review comments
3. **Filter comments**: Bot comments and resolved threads are filtered automatically
4. **Process comments**: Present each comment and apply changes with user approval
5. **Summary**: Report on comments addressed vs skipped

## Step-by-Step Instructions

### Step 1: Validate PR/MR URL

A PR/MR URL must be provided:

```bash
PR_URL="${1}"

if [ -z "$PR_URL" ]; then
    echo "ERROR: PR/MR URL is required"
    echo "Usage: /docs-tools:docs-review-action-git-comments <pr-url>"
    exit 1
fi

echo "PR/MR URL: $PR_URL"
```

### Step 2: Fetch Unresolved Comments

Use the Git Review API Python script (works for both GitHub and GitLab):

```bash
# Get review comments (bot comments and resolved threads are filtered automatically)
python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py comments "${PR_URL}" --json

# Or get human-readable output
python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py comments "${PR_URL}"

# Include resolved comments if needed
python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py comments "${PR_URL}" --include-resolved --json
```

### Step 3: Comment Filtering

The `git_review_api.py comments` command automatically:

1. **Filters bot comments**: Ignores comments from bots (gemini, mergify, github-actions, dependabot)
2. **Filters resolved threads**: Only returns unresolved/open comments (unless `--include-resolved`)
3. **Returns top-level comments only**: Skips replies (in_reply_to_id is null)

Each comment includes:
- `id`: Comment ID
- `path`: File path
- `line`: Line number
- `body`: Comment text
- `author`: Username of commenter
- `resolved`: Boolean (GitLab only)

### Step 4: Process Each Comment

For each unresolved comment, present to the user with the following format:

```markdown
## Comment from @{author} on `{file_path}:{line}`

> {comment_body}

### Current Content

{Show the relevant lines from the file}

### Suggested Change

{Analyze the comment and propose a specific change}
```

Use the AskUserQuestion tool to get user decision with these options:

| Option | Action |
|--------|--------|
| **Apply** | Apply the suggested change using Edit tool |
| **Edit** | Let user modify the suggestion before applying |
| **Skip** | Move to next comment without changes |
| **View context** | Read more of the file before deciding |

### Step 5: Apply Approved Changes

When the user approves a change:

1. Read the target file using the Read tool
2. Apply the edit using the Edit tool
3. Confirm the change was applied
4. Move to the next comment

### Step 6: Validate Line Numbers (Optional)

Before posting response comments, validate line numbers against the actual diff:

```bash
# Validate comments JSON against PR diff
python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py extract --validate \
    "$PR_URL" /tmp/response-comments.json
```

### Step 7: Post Response Comments (Optional)

If needed, post response comments using the Python API:

```bash
# Post response comments
python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py post \
    "$PR_URL" /tmp/response-comments.json

# Or dry-run first
python ${CLAUDE_PLUGIN_ROOT}/commands/scripts/git_review_api.py post \
    "$PR_URL" /tmp/response-comments.json --dry-run
```

### Step 8: Summary

After processing all comments, provide a summary:

```markdown
## Summary

| Metric | Count |
|--------|-------|
| Total comments | X |
| Comments addressed | Y |
| Comments skipped | Z |
| Bot comments filtered | N |

### Changes Made

1. **file.adoc:42**: Applied fix for typo
2. **file.adoc:15**: Updated formatting

### Comments Skipped

1. **file.md:8**: User chose to skip (needs discussion)
```

## Comment Categories

Categorize comments to help prioritize:

| Category | Description | Action |
|----------|-------------|--------|
| **Required** | Style violations, typos, errors | Must fix |
| **Suggestion** | Improvements, rewording | User discretion |
| **Question** | Clarification needed | May need discussion |
| **Outdated** | Already addressed | Skip or confirm |

## Comments JSON Format

When creating response comments:

```json
[
  {"file": "path/to/file.adoc", "line": 42, "severity": "suggestion", "message": "Fixed as requested"},
  {"file": "path/to/file.md", "line": 15, "severity": "suggestion", "message": "Applied the suggested change"}
]
```

## Usage Examples

Action comments on current branch's PR:
```bash
/docs-tools:docs-review-action-git-comments
```

Action comments on a specific GitHub PR:
```bash
/docs-tools:docs-review-action-git-comments https://github.com/owner/repo/pull/123
```

Action comments on a specific GitLab MR:
```bash
/docs-tools:docs-review-action-git-comments https://gitlab.cee.redhat.com/group/project/-/merge_requests/456
```

## Notes

- Always read the file before suggesting changes
- Preserve the author's intent when applying changes
- For ambiguous comments, ask the user for clarification
- Group related comments on the same file together when possible
- The `git_review_api.py` script handles authentication automatically
- Bot comments are filtered out by default
- Only unresolved/open comments are processed
