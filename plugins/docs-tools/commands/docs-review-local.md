---
description: Review documentation changes in the current branch against main
allowed-tools: Read, Write, Glob, Grep, Edit, Bash, Skill, Agent
---

# Self Documentation Review Workflow

Review documentation changes in the current branch compared to the base branch (main/master), suggesting improvements using documentation review skills.

## Workflow Overview

This command:

1. **Detect branches**: Find current branch and base branch (main/master)
2. **Find modified files**: Get list of changed .adoc and .md files
3. **Run reviews**: Apply documentation review skills to each file
4. **Suggest changes**: Provide actionable suggestions for improvements
5. **Generate report**: Create a consolidated review report

## Step-by-Step Instructions

### Step 1: Detect Current Branch and Base Branch

```bash
# Get current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"

# Detect base branch (prefer main, fall back to master)
if git show-ref --verify --quiet refs/heads/main; then
    BASE_BRANCH="main"
elif git show-ref --verify --quiet refs/heads/master; then
    BASE_BRANCH="master"
else
    echo "ERROR: No main or master branch found"
    exit 1
fi
echo "Base branch: $BASE_BRANCH"

# Check if we're on the base branch
if [ "$CURRENT_BRANCH" = "$BASE_BRANCH" ]; then
    echo "ERROR: Currently on $BASE_BRANCH branch. Switch to a feature branch first."
    exit 1
fi
```

### Step 2: Find Modified Documentation Files

Get all modified, added, or renamed files compared to the base branch:

```bash
# Get modified files (staged and unstaged) compared to base branch
git diff --name-only "$BASE_BRANCH"...HEAD > /tmp/docs-review-local-all-files.txt

# Also include uncommitted changes
git diff --name-only HEAD >> /tmp/docs-review-local-all-files.txt
git diff --name-only --cached >> /tmp/docs-review-local-all-files.txt

# Remove duplicates and filter for documentation files
sort -u /tmp/docs-review-local-all-files.txt | grep -E '\.(adoc|md)$' > /tmp/docs-review-local-doc-files.txt || true

# Count files
TOTAL_FILES=$(sort -u /tmp/docs-review-local-all-files.txt | wc -l)
DOC_FILES=$(wc -l < /tmp/docs-review-local-doc-files.txt)

echo "Total changed files: $TOTAL_FILES"
echo "Documentation files (.adoc, .md): $DOC_FILES"
```

If no documentation files are found, report that and exit:

```bash
if [ "$DOC_FILES" -eq 0 ]; then
    echo ""
    echo "No documentation files (.adoc or .md) modified in this branch."
    echo "Review complete - no documentation changes to review."
    exit 0
fi
```

### Step 3: Review Each File

For each file in `/tmp/docs-review-local-doc-files.txt`:

1. **Read the file content** using the Read tool
2. **Determine file type** from the path and content:
   - Check for `:_mod-docs-content-type:` attribute
   - Infer from filename prefix or content structure

#### Detect RHOAI repository

Check if the current repository is a Red Hat AI documentation repository. If so, include the `docs-review-rhoai` skill in the review.

```bash
# RHOAI repository patterns
RHOAI_REPOS=(
    "documentation-red-hat-openshift-data-science-documentation/openshift-ai-documentation"
    "documentation-red-hat-openshift-data-science-documentation/vllm-documentation"
    "documentation-red-hat-openshift-data-science-documentation/rhel-ai"
    "opendatahub-io/opendatahub-documentation"
)

# Get the current repository remote URL
REPO_REMOTE=$(git remote get-url origin 2>/dev/null || echo "")

# Check if repository matches any RHOAI repository
USE_RHOAI_REVIEW=false
for repo in "${RHOAI_REPOS[@]}"; do
    if echo "${REPO_REMOTE}" | grep -q "${repo}"; then
        USE_RHOAI_REVIEW=true
        echo "RHOAI repository detected: ${repo}"
        echo "Including docs-review-rhoai skill in review"
        break
    fi
done
```

#### Step A: Run Vale first (sequential prerequisite)

```bash
vale "${FILE_PATH}" 2>&1 || true
```

Save the Vale output — it will be shared with all review subagents.

#### Step B: Run review skills in parallel using subagents

Spawn all independent review skills as parallel subagents in a single message. Each subagent reads the file, applies its checklist, and returns findings.

**For `.adoc` files**, spawn 6 subagents in parallel (7 if RHOAI):

```
Agent(subagent_type="general-purpose", model="haiku", description="review language",
  prompt="Read <file_path>. Apply docs-review-language checklist: American English spelling, acronyms expanded on first use, consistent terminology. Vale output: <vale_output>. Return findings with location, severity, fix.")

Agent(subagent_type="general-purpose", model="haiku", description="review style",
  prompt="Read <file_path>. Apply docs-review-style checklist: active voice, present tense, sentence case headings, no future tense. Vale output: <vale_output>. Return findings.")

Agent(subagent_type="general-purpose", model="haiku", description="review minimalism",
  prompt="Read <file_path>. Apply docs-review-minimalism checklist: user task focus, no unnecessary content, scannable structure. Return findings.")

Agent(subagent_type="general-purpose", model="haiku", description="review structure",
  prompt="Read <file_path>. Apply docs-review-structure checklist: logical flow, user story alignment. Return findings.")

Agent(subagent_type="general-purpose", model="haiku", description="review usability",
  prompt="Read <file_path>. Apply docs-review-usability checklist: descriptive links, alt text, complete code blocks. Return findings.")

Agent(subagent_type="general-purpose", model="haiku", description="review modular-docs",
  prompt="Read <file_path>. Apply docs-review-modular-docs checklist: module type declared, anchor ID format, title conventions, prerequisites before procedures, single heading per module. Return findings.")

# If USE_RHOAI_REVIEW=true:
Agent(subagent_type="general-purpose", model="haiku", description="review rhoai",
  prompt="Read <file_path>. Apply docs-review-rhoai checklist: product naming uses attributes, allowed AI/ML terminology, module structure requirements. Return findings.")
```

**For `.md` files**, spawn 5 subagents (6 if RHOAI) — skip modular-docs.

#### Step C: Merge subagent results

After all subagents return:
1. Collect findings from all subagents
2. Deduplicate issues flagged by both Vale and a review skill
3. Group by severity (errors first, then warnings, then suggestions)
4. Format using `docs-review-feedback` guidelines

### Step 4: Document Findings

For each issue found, record:

- **File path**: Full path to the file
- **Line number**: Specific line where the issue occurs
- **Severity**: `error` (must fix), `warning` (should fix), or `suggestion` (optional)
- **Category**: Which review skill identified it
- **Issue**: Description of the problem
- **Suggestion**: Recommended fix

### Step 5: Generate Review Report

**IMPORTANT**: Use Bash with heredoc to write /tmp files:

```bash
cat > /tmp/docs-review-local-report.md << 'EOF'
# Self Documentation Review Report

**Branch**: ${CURRENT_BRANCH}
**Base**: ${BASE_BRANCH}
**Date**: $(date +%Y-%m-%d)

## Summary

| Metric | Value |
|--------|-------|
| Total files changed | X |
| Documentation files reviewed | Y |
| Required changes | Z |
| Suggestions | N |

## Files Reviewed

### 1. path/to/file.adoc

**Type**: CONCEPT | PROCEDURE | REFERENCE | ASSEMBLY

#### Vale Linting

| Line | Severity | Rule | Message |
|------|----------|------|---------|
| 15 | error | RedHat.TermsErrors | Use 'data center' rather than 'datacenter' |

#### Modular Docs Compliance

- [x] Module type declared
- [ ] **REQUIRED**: Title should use gerund form for procedure

#### Language

- [x] American English spelling
- [ ] **SUGGESTION**: Expand acronym "API" on first use

#### Style

- [x] Active voice used
- [ ] **REQUIRED**: Line 42: Change "will be created" to "is created"

...

---

## Summary of Required Changes

1. **file.adoc:42**: Use active voice instead of passive
2. **file.adoc:15**: Correct terminology

## Summary of Suggestions

1. **file.adoc:28**: Consider condensing explanation

---

*Generated with [Claude Code](https://claude.com/claude-code)*
EOF
```

### Step 6: Present Results and Offer to Apply Changes

After generating the report:

1. Display a summary to the user
2. For each **required change** (errors), offer to apply the fix using the Edit tool
3. For each **suggestion**, describe the improvement but let the user decide

```
Documentation review complete.

Summary:
  - Files reviewed: X
  - Required changes: Y
  - Suggestions: Z

Full report saved to: /tmp/docs-review-local-report.md

Would you like me to apply the suggested fixes?
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

## Usage Examples

Review modified files in current branch:
```bash
/docs-tools:docs-review-local
```

## Output

The workflow produces:

1. **Console summary**: Quick overview of review results with suggested changes
2. **Review report**: `/tmp/docs-review-local-report.md` - detailed findings for each file
3. **Vale output**: Inline Vale linting results (if available)

## Notes

- This workflow reviews LOCAL files in the current working directory
- Changes are compared against the base branch (main/master)
- Both committed and uncommitted changes are included
- The workflow can suggest and apply fixes using the Edit tool
- For .adoc files, modular docs compliance is checked
- Vale linting requires Vale to be installed and configured
- Unlike `docs-review-pr`, this command works on local files, not PR/MR content
