---
description: Summarize Claude-assisted documentation work from git history and conversation logs
argument-hint: [--since <YYYY-MM-DD>] [--days <N>]
allowed-tools: Read, Write, Glob, Grep, Edit, Bash
---

# Summarize Claude Work

Generate a comprehensive summary of Claude-assisted documentation work by the current user in the current repository for a given time period.

Combines git commit history (filtered to the current user) with Claude Code conversation session data to produce a categorized summary of work performed.

## Arguments

- **--since**: $1 (optional) - Start date in YYYY-MM-DD format. Defaults to 30 days ago.
- **--days**: $2 (optional) - Number of days to look back. Ignored if --since is provided. Defaults to 30.

## Step-by-Step Instructions

### Step 1: Determine Date Range

Calculate the date range for the summary. If no arguments are provided, default to the last 30 days.

```bash
# Parse arguments
SINCE_DATE=""
DAYS=30

while [[ $# -gt 0 ]]; do
    case "$1" in
        --since) SINCE_DATE="$2"; shift 2 ;;
        --days) DAYS="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# Calculate dates
if [ -z "$SINCE_DATE" ]; then
    SINCE_DATE=$(date -d "-${DAYS} days" +%Y-%m-%d 2>/dev/null || date -v-${DAYS}d +%Y-%m-%d)
fi
END_DATE=$(date +%Y-%m-%d)
REPO_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
GIT_USER=$(git config user.name)
GIT_EMAIL=$(git config user.email)

echo "Repository: ${REPO_NAME}"
echo "User: ${GIT_USER} <${GIT_EMAIL}>"
echo "Date range: ${SINCE_DATE} to ${END_DATE}"
```

### Step 2: Gather Git History

Get all non-merge commits by the current user in the date range with file change statistics.

```bash
git log --since="${SINCE_DATE}" --author="${GIT_USER}" --all --no-merges --stat --format="=== %h %ad %s ===" --date=short > /tmp/claude-work-git-log.txt 2>/dev/null || true
echo "Git log saved to /tmp/claude-work-git-log.txt (filtered to author: ${GIT_USER})"
```

Read the git log output with the Read tool to understand the commit history.

### Step 3: Scan Conversation Sessions

Run the conversation summarizer script to extract session data from Claude Code JSONL files.

The script is located in the plugin's scripts directory:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
python3 "${CLAUDE_PLUGIN_ROOT}/commands/scripts/summarize_conversations.py" \
    --repo-path "${REPO_ROOT}" \
    --since "${SINCE_DATE}" \
    --output /tmp/claude-work-conversations.txt
```

Read the conversation summary output with the Read tool.

### Step 4: Synthesize Summary

Using both the git history from Step 2 and the conversation session data from Step 3, synthesize a comprehensive summary organized by category.

Create the final summary file using the Write tool at `/tmp/claude-work-summary-${SINCE_DATE}-to-${END_DATE}.md` with the following structure:

```markdown
# Claude Work Summary: {REPO_NAME}

**Period**: {SINCE_DATE} to {END_DATE}
**Author**: {GIT_USER} <{GIT_EMAIL}>
**Repository**: {REPO_NAME}
**Generated**: {END_DATE}

## Summary

Brief overview paragraph describing the scope of work performed.

## New Documentation Authored

- List new documentation files created
- Include file paths, line counts, and topic descriptions

## Batch Workflow Runs

- JIRA tickets processed with ticket numbers
- Workflow stages completed

## Structural and Standards Improvements

- Changes to documentation structure
- Template or convention updates
- AsciiDoc formatting improvements

## Documentation Review Activities

- Files reviewed and review types performed
- Issues identified and fixed

## Project Governance Updates

- CLAUDE.md changes
- Configuration or settings changes
- Style guide updates

## Tooling and Workflow Improvements

- Script updates or new scripts
- Build pipeline changes
- Automation improvements

## Operational Support

- Ad-hoc tasks and requests
- Troubleshooting activities
- Repository maintenance

## Statistics

| Metric | Value |
|--------|-------|
| Total commits | N |
| Total sessions | N |
| Files modified | N |
| Date range | SINCE to END |

## Daily Activity Timeline

Compact timeline showing daily session counts and key activities.
```

Omit any category section that has no items. Include file names, line counts, and JIRA ticket numbers where relevant.

### Step 5: Report Results

After saving the summary file, display the file path and a brief overview to the user.

```
Summary saved to: /tmp/claude-work-summary-{SINCE_DATE}-to-{END_DATE}.md
```

## Output

The workflow produces:

1. **Git log**: `/tmp/claude-work-git-log.txt` - raw git commit history
2. **Conversation summary**: `/tmp/claude-work-conversations.txt` - extracted session data
3. **Final summary**: `/tmp/claude-work-summary-{SINCE_DATE}-to-{END_DATE}.md` - categorized work summary

## Notes

- The conversation JSONL files are stored at `~/.claude/projects/-<path-with-dashes>/` where the path matches the repo's absolute path with `/` replaced by `-`
- Each JSONL file is one Claude Code session containing JSON objects with role, message, and tool call metadata
- This command works for any repository with Claude Code history
- The summary script automatically detects the Claude projects directory based on the repo path
- Adjust `--since` or `--days` to cover the desired period

## Usage Examples

Summarize the last 30 days (default):
```bash
/docs-tools:docs-summarize-claude-work
```

Summarize since a specific date:
```bash
/docs-tools:docs-summarize-claude-work --since 2026-01-01
```

Summarize the last 7 days:
```bash
/docs-tools:docs-summarize-claude-work --days 7
```
