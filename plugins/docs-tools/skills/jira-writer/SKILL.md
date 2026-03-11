---
name: jira-writer
description: Update and modify JIRA issues on Red Hat Issue Tracker. Use this skill to push release notes to JIRA issues, update custom fields (release note content, status), and modify issue properties. This skill performs write operations and will prompt for user approval before making changes. Requires jira and ratelimit Python packages. Only use when explicitly asked to update or modify JIRA issues.
author: Gabriel McGoldrick (gmcgoldr@redhat.com)
---

# JIRA Writer Skill

This skill provides write access to JIRA issues on Red Hat Issue Tracker (https://issues.redhat.com).

**WARNING: This skill modifies JIRA issues. Always verify the changes before confirming.**

## Capabilities

- **Push Release Notes**: Update the release note custom field with generated content
- **Update Status**: Set release note status to 'Proposed' or other values
- **Update Custom Fields**: Modify any custom field on a JIRA issue
- **Batch Updates**: Update multiple issues with the same content

## Usage

The skill uses a Python script that connects to JIRA using an authentication token.

### Environment Variables Required

Set in `~/.env` (see docs-tools README for setup):

```bash
JIRA_AUTH_TOKEN=your-jira-token
JIRA_URL=https://issues.redhat.com  # optional, defaults to issues.redhat.com
```

### Examples

**Push a release note:**
```bash
python3 scripts/jira_writer.py --issue COO-1145 --release-note "Fixed issue with Korrel8r..."
```

**Update release note status:**
```bash
python3 scripts/jira_writer.py --issue COO-1145 --status Proposed
```

**Update custom field:**
```bash
python3 scripts/jira_writer.py --issue COO-1145 --custom-field customfield_12317313 --value "Release note content"
```

**Batch update multiple issues:**
```bash
python3 scripts/jira_writer.py --issue COO-1145 --issue COO-1271 --status Approved
```

**Read release note from file:**
```bash
python3 scripts/jira_writer.py --issue COO-1145 --release-note-file /path/to/note.txt
```

## Output Format

The script outputs JSON with the following structure:

```json
{
  "success": true,
  "issue_key": "COO-1145",
  "updated_fields": {
    "customfield_12317313": "Release note content",
    "customfield_12310213": "Proposed"
  },
  "url": "https://issues.redhat.com/browse/COO-1145"
}
```

## Custom Fields

Common custom fields used:
- `customfield_12317313`: Release Note Content
- `customfield_12310213`: Release Note Status (values: Proposed, Approved, Rejected)

## Rate Limiting

The skill respects JIRA API rate limits (2 calls per 5 seconds) to avoid overwhelming the server.

## Security

- Requires user approval before making changes (no allowed-tools restriction)
- Token stored in environment variable (not in code)
- All changes are logged with details

## Common Use Cases

1. **Publish release notes**: Push generated release note content to JIRA
2. **Update status**: Mark release notes as Proposed/Approved after review
3. **Batch updates**: Apply same status to multiple issues
4. **Field updates**: Modify any custom field on JIRA issues

## Best Practices

- Always review the content before pushing to JIRA
- Test with non-production issues first
- Verify the issue key is correct
- Back up existing content if overwriting
- Use descriptive commit messages when used with git workflows
