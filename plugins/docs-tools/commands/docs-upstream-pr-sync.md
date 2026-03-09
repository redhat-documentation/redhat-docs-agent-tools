---
description: Review upstream PRs with documentation labels and synthesize JIRA ticket descriptions for downstream doc updates
argument-hint: <repo> <version> [--label <label>] [--state <state>]
allowed-tools: Read, Write, Glob, Grep, Edit, Bash, WebFetch, WebSearch
---

# Upstream Documentation PR Sync

Analyze upstream source code repository PRs labeled with documentation labels, synthesize the changes, review the current downstream docs repo, and generate JIRA ticket descriptions that suggest documentation updates.

## Required Arguments

- **repo**: $1 (required) - Upstream GitHub repository in `owner/repo` format (e.g., `vllm-project/vllm`, `vllm-project/llm-compressor`)
- **version**: $2 (required) - Target version tag or milestone to filter PRs (e.g., `v0.11.2`, `0.8.1`)

**IMPORTANT**: This command requires both a repo and version. If either argument is missing, stop and ask the user to provide them.

## Options

- **--label**: Custom label to filter PRs (default: `documentation`). Accepts comma-separated labels for OR matching (e.g., `documentation,docs,doc`).
- **--state**: PR state filter: `merged`, `closed`, `open`, or `all` (default: `merged`)

## Supported Repositories

This command is designed for upstream repos that feed into RHAIIS documentation:

| Upstream Repo | Downstream Product | Docs Version Attribute |
|---------------|-------------------|----------------------|
| `vllm-project/vllm` | Red Hat AI Inference Server | `{vllm-version}` |
| `vllm-project/llm-compressor` | Red Hat AI Model Optimization Toolkit | `{llmcompressor-version}` |

Other GitHub repositories are also supported.

## Workflow Overview

This command:

1. **Validate inputs**: Confirm repo exists and version is valid
2. **Search PRs**: Find merged PRs with documentation labels for the target version
3. **Analyze each PR**: Fetch title, description, changed files, and diff content
4. **Review current docs**: Scan the downstream documentation repo for related content
5. **Synthesize updates**: Generate JIRA-ready descriptions mapping upstream changes to downstream doc updates
6. **Write output files**: Save analysis as markdown files in `./.claude_docs/upstream_docs/`

## Step-by-Step Instructions

### Step 1: Validate Inputs and Configure

Parse the arguments and validate the repository exists.

```bash
REPO="${1}"
VERSION="${2}"
LABEL="documentation"
STATE="merged"

# Parse optional arguments
shift 2 2>/dev/null
while [[ $# -gt 0 ]]; do
    case "$1" in
        --label) LABEL="$2"; shift 2 ;;
        --state) STATE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

echo "Repository: ${REPO}"
echo "Version: ${VERSION}"
echo "Label filter: ${LABEL}"
echo "State filter: ${STATE}"

# Validate repository exists
gh repo view "${REPO}" --json name,description > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: Repository '${REPO}' not found or not accessible."
    echo "Ensure GITHUB_TOKEN is set and the repository exists."
    exit 1
fi
```

### Step 2: Search for Documentation-Labeled PRs

Use the GitHub CLI to find PRs matching the version and documentation label.

**Strategy**: Search for PRs associated with the version using multiple approaches:

1. PRs with the documentation label that mention the version in title or body
2. PRs with the documentation label merged between the version tag and the previous tag
3. PRs with the documentation label in the milestone matching the version

```bash
# Create output directory
mkdir -p ./.claude_docs/upstream_docs

# Search for PRs with documentation label
# Try milestone-based search first
gh pr list --repo "${REPO}" \
    --label "${LABEL}" \
    --state "${STATE}" \
    --limit 100 \
    --json number,title,body,url,mergedAt,labels,milestone,files,author \
    > /tmp/upstream-doc-prs.json 2>/dev/null

# Count results
PR_COUNT=$(python3 -c "import json; data=json.load(open('/tmp/upstream-doc-prs.json')); print(len(data))")
echo "Found ${PR_COUNT} PRs with label '${LABEL}'"
```

If the label search returns no results, try alternative label names:

```bash
# Try alternative documentation labels
for alt_label in "documentation" "docs" "doc" "type:documentation" "area/docs" "kind/documentation"; do
    if [ "${PR_COUNT}" = "0" ]; then
        echo "Trying label: ${alt_label}"
        gh pr list --repo "${REPO}" \
            --label "${alt_label}" \
            --state "${STATE}" \
            --limit 100 \
            --json number,title,body,url,mergedAt,labels,milestone,files,author \
            > /tmp/upstream-doc-prs.json 2>/dev/null
        PR_COUNT=$(python3 -c "import json; data=json.load(open('/tmp/upstream-doc-prs.json')); print(len(data))")
        if [ "${PR_COUNT}" != "0" ]; then
            LABEL="${alt_label}"
            echo "Found ${PR_COUNT} PRs with label '${alt_label}'"
            break
        fi
    fi
done
```

If still no results, report available labels to the user:

```bash
if [ "${PR_COUNT}" = "0" ]; then
    echo ""
    echo "No PRs found with documentation labels."
    echo ""
    echo "Available labels in ${REPO}:"
    gh label list --repo "${REPO}" --limit 50 --json name --jq '.[].name' | sort
    echo ""
    echo "Try running again with --label <label-name>"
    exit 1
fi
```

### Step 3: Filter PRs by Version

Filter the PR list to only include PRs relevant to the target version. Use multiple heuristics:

1. **Milestone match**: PR milestone matches the version string
2. **Merge date range**: PR merged between the version tag date and the previous tag
3. **Title/body mention**: PR title or body mentions the version

```bash
# Get the tag date for the version
VERSION_DATE=$(gh api "repos/${REPO}/git/refs/tags/${VERSION}" --jq '.object.sha' 2>/dev/null | \
    xargs -I{} gh api "repos/${REPO}/git/commits/{}" --jq '.committer.date' 2>/dev/null)

if [ -n "${VERSION_DATE}" ]; then
    echo "Version ${VERSION} tag date: ${VERSION_DATE}"
fi

# Get previous version tag for date range filtering
PREV_TAG=$(gh api "repos/${REPO}/tags?per_page=20" --jq '.[].name' 2>/dev/null | \
    grep -A1 "^${VERSION}$" | tail -1)

if [ -n "${PREV_TAG}" ]; then
    echo "Previous tag: ${PREV_TAG}"
fi
```

Use Python to filter the PRs by version relevance:

```python
import json
import sys
from datetime import datetime

prs = json.load(open('/tmp/upstream-doc-prs.json'))
version = sys.argv[1] if len(sys.argv) > 1 else ""

filtered = []
for pr in prs:
    # Check milestone
    if pr.get('milestone') and version in str(pr['milestone'].get('title', '')):
        pr['_match_reason'] = 'milestone'
        filtered.append(pr)
        continue

    # Check title/body mention
    title = pr.get('title', '')
    body = pr.get('body', '') or ''
    if version in title or version in body:
        pr['_match_reason'] = 'version_mentioned'
        filtered.append(pr)
        continue

# If no version-specific matches, include all (user can manually filter)
if not filtered:
    for pr in prs:
        pr['_match_reason'] = 'label_match_only'
    filtered = prs

json.dump(filtered, open('/tmp/upstream-doc-prs-filtered.json', 'w'), indent=2)
print(f"Filtered to {len(filtered)} version-relevant PRs")
```

### Step 4: Analyze Each PR

For each filtered PR, fetch the full details including the diff and changed files.

For each PR in the filtered list:

1. **Fetch PR details**: Get the full PR description, comments, and review comments
2. **Fetch changed files**: Get the list of files changed and their diffs
3. **Categorize changes**: Identify what type of documentation change this represents

```bash
# For each PR, get the full diff
PR_NUMBER=<number>
gh pr view "${PR_NUMBER}" --repo "${REPO}" --json title,body,files,comments,reviews,url,mergedAt,author
gh pr diff "${PR_NUMBER}" --repo "${REPO}" > "/tmp/upstream-pr-${PR_NUMBER}.diff"
```

Categorize each PR into one or more of these documentation change types:

| Category | Description | Downstream Action |
|----------|-------------|-------------------|
| **New feature docs** | Documents a new feature or capability | Create new modules or update existing ones |
| **API changes** | Updates to API parameters, endpoints, or behavior | Update server arguments or API reference |
| **Configuration changes** | New or modified configuration options | Update configuration guides |
| **Bug fix docs** | Documents a bug fix or workaround | Update troubleshooting or release notes |
| **Deprecation notice** | Marks features as deprecated | Add deprecation notices, update migration guides |
| **Example updates** | New or updated code examples | Update code examples in relevant modules |
| **Architecture docs** | Changes to system architecture or design | Update concept modules |

### Step 5: Review Current Documentation Repository

Scan the current downstream documentation repository to identify where upstream changes should be reflected.

Search the docs repo for:

1. **Related content**: Files that discuss the same features or components
2. **Existing coverage**: Whether the upstream change is already documented downstream
3. **Gap analysis**: What is documented upstream but missing downstream

```bash
# Search for related content in the docs repo
# Use the PR title keywords to find relevant files
grep -rl "keyword_from_pr" modules/ snippets/ --include="*.adoc" 2>/dev/null
```

For each PR, use the Read and Grep tools to search the documentation repository:

1. Search `modules/` for files mentioning the feature or component
2. Search `snippets/` for reusable content related to the change
3. Search assembly `master.adoc` files for relevant assembly structures
4. Check `_attributes/attributes.adoc` for version-specific attributes

### Step 6: Synthesize JIRA Ticket Descriptions

For each upstream PR, generate a JIRA ticket description that maps the upstream change to a downstream documentation update.

The JIRA ticket description should include:

1. **Summary**: One-line description of the documentation update needed
2. **Upstream reference**: Link to the upstream PR with its title
3. **Change analysis**: What changed in the upstream PR and why it matters for downstream docs
4. **Affected downstream files**: List of downstream doc files that need updating
5. **Suggested updates**: Specific changes recommended for each affected file
6. **Acceptance criteria**: What "done" looks like for this documentation update

### Step 7: Write Output Files

Create markdown files in `./.claude_docs/upstream_docs/` for each analyzed PR.

```bash
mkdir -p ./.claude_docs/upstream_docs
```

#### File naming convention

Files are named using the pattern: `pr-<number>-<short-slug>.md`

Where:
- `<number>` is the upstream PR number
- `<short-slug>` is a kebab-case slug derived from the PR title (max 50 chars)

Example: `pr-12345-add-speculative-decoding-docs.md`

#### Output file format

Each file should follow this structure:

```markdown
# Upstream PR #<number>: <PR Title>

**Repository**: <owner/repo>
**PR URL**: <url>
**Version**: <version>
**Merged**: <date>
**Author**: <author>
**Labels**: <labels>

## Upstream Change Summary

<2-3 paragraph summary of what the upstream PR changed and why>

## Files Changed in Upstream PR

| File | Change Type | Description |
|------|-------------|-------------|
| path/to/file1 | Added | New documentation for feature X |
| path/to/file2 | Modified | Updated API parameter descriptions |

## Downstream Documentation Impact

### Affected Downstream Files

| Downstream File | Impact | Update Needed |
|-----------------|--------|---------------|
| modules/feature-x.adoc | Direct | Update feature description with new parameters |
| snippets/api-params.adoc | Indirect | Add new parameter to shared snippet |

### Gap Analysis

- **Covered**: <aspects already documented downstream>
- **Missing**: <aspects not yet documented downstream>
- **Outdated**: <aspects documented but now incorrect>

## Suggested JIRA Ticket

### Summary

<One-line JIRA summary, max 120 chars>

### Description

{noformat}
*Upstream PR*: [PR #<number>: <title>|<url>]
*Upstream Repo*: <owner/repo>
*Version*: <version>

h3. Background

<Why this documentation update is needed, referencing the upstream change>

h3. Scope of Changes

<Bulleted list of specific documentation updates needed>

* Update `modules/<file>.adoc` to include <specific change>
* Add new section for <new feature> in `<assembly>/master.adoc`
* Update code examples to reflect <API change>

h3. Acceptance Criteria

* [ ] <Specific, testable criterion>
* [ ] <Another criterion>
* [ ] Documentation builds without errors
* [ ] Vale linting passes
{noformat}

### Labels

`documentation`, `upstream-sync`, `<version>`

### Priority

<Suggested priority: Critical/Major/Minor/Trivial based on impact>

---

*Generated by docs-upstream-pr-sync on <date>*
*Source: [<repo> PR #<number>](<url>)*
```

#### Summary index file

After processing all PRs, generate a summary index file at `./.claude_docs/upstream_docs/_index.md`:

```markdown
# Upstream Documentation PR Sync

**Repository**: <owner/repo>
**Version**: <version>
**Label**: <label>
**Generated**: <date>
**Total PRs analyzed**: <count>

## PRs Analyzed

| PR # | Title | Category | Priority | Downstream Impact |
|------|-------|----------|----------|-------------------|
| #123 | Add speculative decoding docs | New feature | Major | 3 files affected |
| #456 | Update API params for v2 | API changes | Critical | 5 files affected |

## Summary Statistics

- **New feature docs**: X PRs
- **API changes**: Y PRs
- **Configuration changes**: Z PRs
- **Total downstream files affected**: N

## Output Files

- [pr-123-add-speculative-decoding-docs.md](pr-123-add-speculative-decoding-docs.md)
- [pr-456-update-api-params-v2.md](pr-456-update-api-params-v2.md)

---

*Generated by docs-upstream-pr-sync on <date>*
```

### Step 8: Present Results

After generating all output files, present a summary to the user.

```bash
echo ""
echo "Upstream Documentation PR Sync complete."
echo ""
echo "Repository: ${REPO}"
echo "Version: ${VERSION}"
echo "PRs analyzed: ${PR_COUNT}"
echo ""
echo "Output files saved to: ./.claude_docs/upstream_docs/"
echo ""
echo "Files generated:"
ls -1 ./.claude_docs/upstream_docs/
echo ""
echo "To review the summary: cat ./.claude_docs/upstream_docs/_index.md"
```

## Output Structure

Output is created in the current working directory:

```
./.claude_docs/
└── upstream_docs/
    ├── _index.md                              # Summary of all analyzed PRs
    ├── pr-123-add-speculative-decoding.md     # Individual PR analysis
    ├── pr-456-update-api-params.md            # Individual PR analysis
    └── pr-789-deprecate-old-endpoint.md       # Individual PR analysis
```

## Usage Examples

Sync vLLM documentation PRs for a specific version:
```bash
/docs-tools:docs-upstream-pr-sync vllm-project/vllm v0.11.2
```

Sync LLM Compressor documentation PRs:
```bash
/docs-tools:docs-upstream-pr-sync vllm-project/llm-compressor 0.8.1
```

Use a custom label:
```bash
/docs-tools:docs-upstream-pr-sync vllm-project/vllm v0.11.2 --label "area/docs"
```

Include open PRs as well as merged:
```bash
/docs-tools:docs-upstream-pr-sync vllm-project/vllm v0.11.2 --state all
```

Search with multiple labels:
```bash
/docs-tools:docs-upstream-pr-sync vllm-project/vllm v0.11.2 --label "documentation,docs"
```

## Prerequisites

- `gh` - GitHub CLI (install with: `sudo dnf install gh`)
- `python3` - Python 3 for JSON processing
- `GITHUB_TOKEN` - Set in environment or via `gh auth login`

## CRITICAL: Access Configuration

**This command requires GitHub API access.** The `gh` CLI must be authenticated.

### Authentication

Verify GitHub CLI is authenticated:

```bash
gh auth status
```

If not authenticated:

```bash
gh auth login
```

Or set the `GITHUB_TOKEN` environment variable:

```bash
export GITHUB_TOKEN=your_github_personal_access_token
```

Required token scopes:
- `public_repo` for public repositories
- `repo` for private repositories

### Access Failure Behavior

If the GitHub API is not accessible:

1. **STOP IMMEDIATELY** - No further processing occurs
2. **Report the exact error** - Display the authentication error
3. **Await user action** - User must authenticate and retry

## Notes

- This command is read-only and does not modify the upstream repository or create JIRA tickets
- The JIRA ticket descriptions use Atlassian wiki markup format (`{noformat}`, `h3.`, etc.) for direct pasting
- PRs are filtered by version using milestone, title/body mentions, and merge date range heuristics
- If no version-specific PRs are found, all documentation-labeled PRs are included with a warning
- The command searches for alternative documentation labels automatically if the default label yields no results
- Output files are idempotent; re-running overwrites previous output for the same repo/version
- Large PRs with many changed files may take longer to analyze due to API rate limits
- The `_index.md` file provides a quick overview suitable for team status updates
