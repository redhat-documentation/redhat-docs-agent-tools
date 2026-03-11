---
name: jira-reader
description: Read and analyze JIRA issues from Red Hat Issue Tracker. Use this skill to fetch issue details, search issues, extract comments and discussions, categorize issues (bugs, CVEs, features, stories), analyze custom fields (release notes, fix versions), retrieve Git links, and generate summaries. This skill is read-only and cannot modify JIRA issues. Requires jira and ratelimit Python packages.
author: Gabriel McGoldrick (gmcgoldr@redhat.com)
allowed-tools: Read, Bash, Grep, Glob
---

# JIRA Reader Skill

This skill provides read-only access to JIRA issues on Red Hat Issue Tracker (https://issues.redhat.com).

## Capabilities

- **Fetch Issue Details**: Get full issue information including description, status, priority, assignee, components
- **Process Comments**: Extract and analyze comment threads with anonymized participants
- **Extract Custom Fields**: Access release note types, fix versions, and other custom fields
- **Find Git Links**: Retrieve related GitHub/GitLab pull requests and commits
- **Categorize Issues**: Classify issues as bugs, CVEs, features, stories, epics, tasks
- **Generate Summaries**: Create categorized reports and analysis of multiple issues

## Usage

The skill uses a Python script that connects to JIRA using an authentication token.

### Environment Variables Required

Set in `~/.env` (see docs-tools README for setup):

```bash
JIRA_AUTH_TOKEN=your-jira-token
JIRA_URL=https://issues.redhat.com  # optional, defaults to issues.redhat.com
```

### Examples

**Fetch a single issue:**
```bash
python3 scripts/jira_reader.py --issue COO-1145
```

**Fetch issue with comments:**
```bash
python3 scripts/jira_reader.py --issue COO-1145 --include-comments
```

**Fetch multiple issues:**
```bash
python3 scripts/jira_reader.py --issue COO-1145 --issue COO-1271 --issue COO-1130
```

**Search issues by JQL (FAST - returns summaries):**
```bash
python3 scripts/jira_reader.py --jql "project=COO AND fixVersion='1.3.0 RC'"
```

**Search with full details (SLOW - fetches all fields):**
```bash
python3 scripts/jira_reader.py --jql "project=COO AND fixVersion='1.3.0 RC'" --fetch-details
```

## Performance Modes

### Default: Fast Summary Mode
JQL searches return summaries by default (1 API call, ~3 seconds for any number of results):
- issue_key, issue_type, issue_category, priority, status
- assignee, summary, fix_versions, url

Use for: Quick analysis, categorization, release planning, CVE reports

### Opt-in: Detailed Mode (`--fetch-details`)
Fetches full details for each issue (N+1 API calls, ~2.5 seconds per issue):
- Everything in summary mode PLUS
- Full description, comments, git_links, created/updated dates, all custom fields

Use for: Deep analysis, comment threads, Git link extraction

## Output Formats

**Summary output (default for JQL):**
```json
{
  "issue_key": "COO-1145",
  "issue_type": "Bug",
  "issue_category": "Bug",
  "priority": "Blocker",
  "status": "Verified",
  "assignee": "Alan Conway",
  "summary": "Issue summary text",
  "fix_versions": ["1.3.0 RC"],
  "url": "https://issues.redhat.com/browse/COO-1145"
}
```

**Detailed output (with --fetch-details or --issue):**
```json
{
  "issue_key": "COO-1145",
  "issue_type": "Bug",
  "issue_category": "Bug",
  "priority": "Blocker",
  "status": "Verified",
  "assignee": "Alan Conway",
  "summary": "Issue summary text",
  "description": "Full issue description...",
  "created": "2025-07-30T14:10:21.952+0000",
  "updated": "2025-08-13T14:57:39.990+0000",
  "comments": [
    {
      "participant": "Participant A",
      "timestamp": "2025-07-30 15:10",
      "body": "Comment text..."
    }
  ],
  "custom_fields": {
    "release_note_type": "Bug Fix",
    "fix_versions": ["1.3.0 RC"]
  },
  "git_links": [
    "https://github.com/org/repo/pull/123"
  ],
  "url": "https://issues.redhat.com/browse/COO-1145"
}
```

## Rate Limiting

The skill respects JIRA API rate limits (2 calls per 5 seconds) to avoid overwhelming the server. Summary mode requires only 1 call regardless of result count, making it ~80x faster for bulk operations.

## Security

- Read-only operations only (enforced by allowed-tools)
- Token stored in environment variable (not in code)
- Comment anonymization to protect user identities in analysis

## Common Use Cases

1. **Analyze release issues**: Fetch all issues for a fix version and categorize them
2. **CVE reporting**: Extract security vulnerabilities and their status
3. **Bug triage**: Get issue details with comments for understanding context
4. **Release notes**: Extract information needed for documentation
5. **Link analysis**: Find related Git changes for code review
