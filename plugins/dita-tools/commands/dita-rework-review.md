---
description: Review DITA rework changes by comparing current file against upstream/main version
argument-hint: <file.adoc>
allowed-tools: Read, Write, Glob, Grep, Edit, Bash, Skill, TodoWrite
---

# DITA Rework Review Workflow

Review DITA rework and rewrite changes by comparing the current version of a file against the upstream/main version. For assemblies, the workflow reduces both versions to single flattened documents for comprehensive content comparison.

## Prerequisites

**Run this command after completing a DITA rework or rewrite workflow:**

1. Run `/dita-tools:dita-rework <assembly.adoc>` or `/dita-tools:dita-rewrite <file.adoc>`
2. Remain on the feature branch created by the rework/rewrite command
3. Run this review command to validate the changes before creating a PR/MR

This command assumes you are on a branch with DITA rework changes and compares against `upstream/main` or `origin/main`.

## Required Argument

- **file**: (required) Path to an AsciiDoc module or assembly file (e.g., `modules/con-overview.adoc` or `assemblies/master.adoc`)

**IMPORTANT**: This command requires a file path. If no argument is provided, stop and ask the user to provide one.

## Workflow Overview

1. **Build Check**: Run asciidoctor to verify file builds without errors
2. **Setup**: Validate input file exists and has changes vs upstream
3. **Detect Type**: Determine if file is an assembly or module
4. **Prepare Comparison**:
   - For assemblies: Reduce both current and upstream/main versions
   - For modules: Compare files directly
5. **Generate Diff**: Compare the two versions
6. **Analyze Changes**: Identify content modifications, additions, and deletions
7. **Produce Review**: Output structured review with module-level change tracking

---

## Phase 1: Build Check (GATE)

**CRITICAL**: Before any other processing, verify the reworked file builds successfully with asciidoctor. If errors are found, STOP and help fix them.

### Step 1: Run Asciidoctor Check

```bash
FILE_PATH="${1}"

# Run asciidoctor build check
bash ${CLAUDE_PLUGIN_ROOT}/skills/dita-check-asciidoctor/scripts/check_asciidoctor.sh "${FILE_PATH}"
EXIT_CODE=$?

if [ ${EXIT_CODE} -eq 2 ]; then
    echo ""
    echo "ERROR: Asciidoctor build failed with errors."
    echo "The reworked file has syntax errors that must be fixed before review."
    echo ""
    echo "Review the errors above and fix them before proceeding."
    exit 1
fi

if [ ${EXIT_CODE} -eq 1 ]; then
    echo ""
    echo "WARNING: Asciidoctor build completed with warnings."
    echo "Continuing with review, but consider addressing warnings."
    echo ""
fi
```

### Step 2: Handle Build Errors

If the asciidoctor check returns exit code 2 (errors found):

1. **STOP all further processing** - Do not continue to diff generation or review
2. **Read the source file** at the line numbers reported in the errors
3. **Identify the issue** - Look for:
   - Unclosed conditionals (`ifdef::` without `endif::[]`)
   - Unclosed admonition blocks (`====` without closing pair)
   - Unclosed code/listing blocks (`----` without closing pair)
   - Unclosed open blocks (`--` without closing pair)
   - Missing include files
   - Malformed attributes
4. **Suggest specific fixes** - Provide the exact edits needed to fix each error
5. **Offer to apply fixes** - Ask the user if they want you to fix the issues

**Example response when errors are found:**

```
BUILD CHECK FAILED

The file has asciidoctor errors that must be fixed before review can proceed.

Errors found:
1. Line 45: Unclosed conditional block
   - Found `ifdef::openshift[]` without matching `endif::[]`
   - Fix: Add `endif::[]` after the conditional content

2. Line 78: Unclosed code block
   - The `----` delimiter at line 72 is not closed
   - Fix: Add `----` after line 77

Would you like me to apply these fixes?
```

---

## Phase 2: Setup and Validation

### Step 1: Validate Input

```bash
# Check for required argument
if [ -z "${1}" ]; then
    echo "ERROR: No file path provided"
    echo "Usage: /dita-tools:dita-rework-review <file.adoc>"
    exit 1
fi

# Verify the file exists
test -f "${1}" && echo "File exists: ${1}" || { echo "ERROR: Not found: ${1}"; exit 1; }
```

If the file does not exist, STOP and inform the user.

### Step 2: Check Git Status

Verify the file has changes compared to upstream/main:

```bash
# Get the file path
FILE_PATH="${1}"

# Check if the file has changes against upstream/main
git diff upstream/main -- "${FILE_PATH}" > /dev/null 2>&1 || git diff origin/main -- "${FILE_PATH}" > /dev/null 2>&1

# Determine the upstream ref to use
if git rev-parse --verify upstream/main > /dev/null 2>&1; then
    UPSTREAM_REF="upstream/main"
elif git rev-parse --verify origin/main > /dev/null 2>&1; then
    UPSTREAM_REF="origin/main"
else
    echo "ERROR: Neither upstream/main nor origin/main found"
    exit 1
fi

echo "Using upstream reference: ${UPSTREAM_REF}"
```

### Step 3: Detect File Type

Determine if the input is an assembly (contains includes) or a module:

```bash
FILE_PATH="${1}"

# Check if file contains include directives
if grep -q "^include::" "${FILE_PATH}"; then
    echo "File type: ASSEMBLY (contains include directives)"
    FILE_TYPE="assembly"
else
    echo "File type: MODULE (no include directives)"
    FILE_TYPE="module"
fi
```

---

## Phase 3: Prepare Comparison Files

### For Assemblies

When the input is an assembly, use `dita-reduce-asciidoc` to create flattened versions of both current and upstream/main:

#### Step A: Create Reduced Version of Current File

```bash
FILE_PATH="${1}"
FILE_DIR=$(dirname "${FILE_PATH}")
FILE_NAME=$(basename "${FILE_PATH}" .adoc)

# Create temp directory for comparison files
REVIEW_DIR="/tmp/dita-rework-review"
mkdir -p "${REVIEW_DIR}"

# Reduce the current version
ruby ${CLAUDE_PLUGIN_ROOT}/skills/dita-reduce-asciidoc/scripts/reduce_asciidoc.rb "${FILE_PATH}" -o "${REVIEW_DIR}/${FILE_NAME}-current-reduced.adoc"

echo "Created reduced current version: ${REVIEW_DIR}/${FILE_NAME}-current-reduced.adoc"
```

#### Step B: Create Reduced Version of Upstream/Main File

```bash
# Get the upstream/main version of the assembly
git show "${UPSTREAM_REF}:${FILE_PATH}" > "${REVIEW_DIR}/${FILE_NAME}-upstream.adoc"

# For assembly reduction, we need to temporarily create the upstream file structure
# Create a temporary working directory
UPSTREAM_WORK_DIR="${REVIEW_DIR}/upstream-work"
mkdir -p "${UPSTREAM_WORK_DIR}"

# Get the directory structure from the assembly
ASSEMBLY_DIR=$(dirname "${FILE_PATH}")

# Extract all included files from upstream/main
echo "Extracting upstream/main file tree for reduction..."

# Get list of includes from the upstream assembly
bash ${CLAUDE_PLUGIN_ROOT}/skills/dita-includes/scripts/find_includes.sh "${FILE_PATH}" --relative 2>/dev/null | while read -r include_file; do
    if [ -n "${include_file}" ]; then
        # Create parent directory in temp location
        include_dir=$(dirname "${include_file}")
        mkdir -p "${UPSTREAM_WORK_DIR}/${include_dir}"
        # Extract the upstream version
        git show "${UPSTREAM_REF}:${include_file}" > "${UPSTREAM_WORK_DIR}/${include_file}" 2>/dev/null || true
    fi
done

# Also extract the main assembly file
mkdir -p "${UPSTREAM_WORK_DIR}/${ASSEMBLY_DIR}"
git show "${UPSTREAM_REF}:${FILE_PATH}" > "${UPSTREAM_WORK_DIR}/${FILE_PATH}"

# Run asciidoctor-reducer on the upstream assembly
cd "${UPSTREAM_WORK_DIR}"
ruby ${CLAUDE_PLUGIN_ROOT}/skills/dita-reduce-asciidoc/scripts/reduce_asciidoc.rb "${FILE_PATH}" -o "${REVIEW_DIR}/${FILE_NAME}-upstream-reduced.adoc" 2>/dev/null || {
    # Fallback: if reduction fails, use the raw upstream assembly
    cp "${UPSTREAM_WORK_DIR}/${FILE_PATH}" "${REVIEW_DIR}/${FILE_NAME}-upstream-reduced.adoc"
    echo "Warning: Upstream reduction failed, using non-reduced upstream file"
}
cd -

echo "Created reduced upstream version: ${REVIEW_DIR}/${FILE_NAME}-upstream-reduced.adoc"
```

#### Step C: Render to HTML and Extract Text

Render both reduced AsciiDoc files to HTML, then convert to plain text for content-level comparison that ignores markup differences:

```bash
# Render current reduced AsciiDoc to HTML
asciidoctor -o "${REVIEW_DIR}/${FILE_NAME}-current.html" "${REVIEW_DIR}/${FILE_NAME}-current-reduced.adoc"

# Render upstream reduced AsciiDoc to HTML
asciidoctor -o "${REVIEW_DIR}/${FILE_NAME}-upstream.html" "${REVIEW_DIR}/${FILE_NAME}-upstream-reduced.adoc"

# Convert current HTML to plain text
python3 -c "
import html2text
h = html2text.HTML2Text()
h.ignore_links = False
h.ignore_images = True
h.body_width = 0
with open('${REVIEW_DIR}/${FILE_NAME}-current.html', 'r') as f:
    print(h.handle(f.read()))
" > "${REVIEW_DIR}/${FILE_NAME}-current.txt"

# Convert upstream HTML to plain text
python3 -c "
import html2text
h = html2text.HTML2Text()
h.ignore_links = False
h.ignore_images = True
h.body_width = 0
with open('${REVIEW_DIR}/${FILE_NAME}-upstream.html', 'r') as f:
    print(h.handle(f.read()))
" > "${REVIEW_DIR}/${FILE_NAME}-upstream.txt"

echo "Rendered and extracted text for content comparison"
```

#### Step D: Set Comparison File Paths

```bash
CURRENT_FILE="${REVIEW_DIR}/${FILE_NAME}-current.txt"
UPSTREAM_FILE="${REVIEW_DIR}/${FILE_NAME}-upstream.txt"
```

### For Modules

When the input is a module, compare files directly without reduction:

```bash
FILE_PATH="${1}"
FILE_NAME=$(basename "${FILE_PATH}" .adoc)

# Create temp directory
REVIEW_DIR="/tmp/dita-rework-review"
mkdir -p "${REVIEW_DIR}"

# Get upstream version
git show "${UPSTREAM_REF}:${FILE_PATH}" > "${REVIEW_DIR}/${FILE_NAME}-upstream.adoc"

# Render current module to HTML
asciidoctor -o "${REVIEW_DIR}/${FILE_NAME}-current.html" "${FILE_PATH}"

# Render upstream module to HTML
asciidoctor -o "${REVIEW_DIR}/${FILE_NAME}-upstream.html" "${REVIEW_DIR}/${FILE_NAME}-upstream.adoc"

# Convert current HTML to plain text
python3 -c "
import html2text
h = html2text.HTML2Text()
h.ignore_links = False
h.ignore_images = True
h.body_width = 0
with open('${REVIEW_DIR}/${FILE_NAME}-current.html', 'r') as f:
    print(h.handle(f.read()))
" > "${REVIEW_DIR}/${FILE_NAME}-current.txt"

# Convert upstream HTML to plain text
python3 -c "
import html2text
h = html2text.HTML2Text()
h.ignore_links = False
h.ignore_images = True
h.body_width = 0
with open('${REVIEW_DIR}/${FILE_NAME}-upstream.html', 'r') as f:
    print(h.handle(f.read()))
" > "${REVIEW_DIR}/${FILE_NAME}-upstream.txt"

# Set comparison paths to plain text files
CURRENT_FILE="${REVIEW_DIR}/${FILE_NAME}-current.txt"
UPSTREAM_FILE="${REVIEW_DIR}/${FILE_NAME}-upstream.txt"
```

---

## Phase 4: Generate Diff and Analyze

### Step 1: Generate Rendered Content Diff

```bash
# Generate rendered content diff
diff -u "${UPSTREAM_FILE}" "${CURRENT_FILE}" > "${REVIEW_DIR}/changes.diff" || true

# Count additions and deletions
ADDITIONS=$(grep -c "^+" "${REVIEW_DIR}/changes.diff" 2>/dev/null | grep -v "^+++" || echo 0)
DELETIONS=$(grep -c "^-" "${REVIEW_DIR}/changes.diff" 2>/dev/null | grep -v "^---" || echo 0)

echo "Changes detected:"
echo "  Lines added: ${ADDITIONS}"
echo "  Lines removed: ${DELETIONS}"
```

### Step 2: Identify Modified Sections

For assemblies, track which modules have changed by parsing the reduced content:

```bash
# If assembly, identify module boundaries in the diff
if [ "${FILE_TYPE}" = "assembly" ]; then
    echo ""
    echo "Analyzing module-level changes..."

    # Extract section headers from the diff to identify affected modules
    # Sections typically start with = or == markers
    grep -E "^[-+]= " "${REVIEW_DIR}/changes.diff" 2>/dev/null || echo "No section header changes found"
fi
```

### Step 3: Analyze Content Changes

Use the Read tool to examine the diff and identify:

1. **Content additions** - New paragraphs, sections, or elements
2. **Content deletions** - Removed content that may have been important
3. **Content modifications** - Changed wording, rewritten sections
4. **Structural changes** - Reordered content, moved sections
5. **Potential issues** - Malformed markup, broken cross-references

Read both the diff file and the two reduced files to perform a comprehensive analysis.

---

## Phase 5: Track Module-Level Changes

For assemblies, identify which individual modules were modified:

### Step 1: Get List of Changed Files

```bash
FILE_PATH="${1}"

# Get list of included files
bash ${CLAUDE_PLUGIN_ROOT}/skills/dita-includes/scripts/find_includes.sh "${FILE_PATH}" --existing > "${REVIEW_DIR}/current-includes.txt"

# For each include, check if it differs from upstream
echo ""
echo "=== Module-Level Change Analysis ==="
echo ""

while read -r module_path; do
    if [ -n "${module_path}" ]; then
        # Check if module has changes vs upstream
        if git diff --quiet "${UPSTREAM_REF}" -- "${module_path}" 2>/dev/null; then
            : # No changes
        else
            echo "MODIFIED: ${module_path}"
            # Get summary of changes for this module
            git diff --stat "${UPSTREAM_REF}" -- "${module_path}" 2>/dev/null || true
        fi
    fi
done < "${REVIEW_DIR}/current-includes.txt"
```

### Step 2: Categorize Module Changes

For each modified module, categorize the type of changes:

- **Formatting only** - Whitespace, line breaks, attribute formatting
- **Content changes** - Text modifications, rewrites
- **Structural changes** - Section reorganization, list modifications
- **DITA fixes** - Changes made by DITA rework tools

---

## Phase 6: Produce Review Output

Generate a structured review report. Use the Write tool to create the report file:

**IMPORTANT**: Use the Write tool to create `/tmp/dita-rework-review-report.md` with the complete review.

### Review Report Template

Write the following structure to `/tmp/dita-rework-review-report.md`:

```
# DITA Rework Review Report

**File reviewed**: <file_path>
**Upstream reference**: <upstream_ref>
**File type**: <assembly|module>
**Review date**: <timestamp>

---

## Summary

| Metric | Count |
|--------|-------|
| Lines added | <count> |
| Lines removed | <count> |
| Modules modified | <count> |

## Content Analysis

### Added Content

<!-- List any significant content additions -->
- <description of addition>
- <location and impact>

### Removed Content

<!-- List any content that was removed - FLAG if important content appears missing -->
- <description of removal>
- <assessment: intentional removal or potential issue?>

### Modified Content

<!-- List significant content modifications -->
- <description of change>
- <assessment: improvement, neutral, or potential issue?>

### Structural Changes

<!-- List any structural reorganization -->
- <description of structural change>

## Module Change Report

<!-- Only for assemblies - list each modified module -->
| Module | Change Type | Summary |
|--------|-------------|---------|
| <module_path> | <formatting\|content\|structural> | <brief description> |

## Potential Issues

<!-- Flag any concerns for reviewer attention -->

### Missing Content
<!-- Content that appears to have been accidentally removed -->
- [ ] <issue description>

### Malformed Markup
<!-- AsciiDoc syntax that may be broken -->
- [ ] <issue description>

### Broken References
<!-- Cross-references or links that may be broken -->
- [ ] <issue description>

### Style Concerns
<!-- Content that may not follow guidelines -->
- [ ] <issue description>

## Recommendations

<!-- Provide actionable recommendations -->
1. <recommendation>
2. <recommendation>

---

## Rendered Content Diff

<details>
<summary>Click to expand full rendered content diff</summary>

\`\`\`diff
<contents of changes.diff>
\`\`\`

</details>

---
Generated with [Claude Code](https://claude.com/claude-code)
```

### Report Generation Instructions

1. **Read the diff file** at `${REVIEW_DIR}/changes.diff`
2. **Read both rendered text files** to understand the full content:
   - `${CURRENT_FILE}` - Current version (rendered plain text)
   - `${UPSTREAM_FILE}` - Upstream/main version (rendered plain text)
3. **Read the reduced AsciiDoc files** if markup-level context is needed:
   - `${REVIEW_DIR}/${FILE_NAME}-current-reduced.adoc` (assemblies) or the original file (modules)
   - `${REVIEW_DIR}/${FILE_NAME}-upstream-reduced.adoc` or `${REVIEW_DIR}/${FILE_NAME}-upstream.adoc`
4. **Analyze the changes** to populate each section of the report
5. **Flag potential issues** such as:
   - Content that appears accidentally removed
   - Malformed AsciiDoc syntax introduced
   - Broken cross-references or includes
   - Missing abstract paragraphs or IDs
6. **Write the report** using the Write tool to `/tmp/dita-rework-review-report.md`

---

## Phase 7: Display Results

After generating the report:

```bash
echo ""
echo "=== Review Complete ==="
echo ""
echo "Review report written to: /tmp/dita-rework-review-report.md"
echo ""
echo "To view the report:"
echo "  cat /tmp/dita-rework-review-report.md"
echo ""
echo "To copy to clipboard:"
echo "  cat /tmp/dita-rework-review-report.md | xclip -selection clipboard"
```

Display a summary of key findings to the user in the CLI output.

---

## Usage Examples

### Typical workflow

```bash
# Step 1: Run DITA rework on an assembly
/dita-tools:dita-rework guides/admin/master.adoc

# Step 2: Review the changes (still on the rework branch)
/dita-tools:dita-rework-review guides/admin/master.adoc

# Step 3: Address any issues found, then create PR/MR
```

### After dita-rewrite

```bash
# Step 1: Run DITA rewrite on files
/dita-tools:dita-rewrite modules/installing/

# Step 2: Review a specific module
/dita-tools:dita-rework-review modules/installing/proc-install-component.adoc

# Step 3: Review the entire assembly
/dita-tools:dita-rework-review assemblies/installing.adoc
```

### Review an existing rework branch

```bash
# Switch to an existing rework branch
git checkout guides-admin-dita-rework

# Review the assembly
/dita-tools:dita-rework-review guides/admin/master.adoc
```

---

## Notes

- **Post-rework review**: This command is designed to run after `dita-rework` or `dita-rewrite` to validate changes before PR/MR creation
- **Read-only**: This command does not modify files - it only analyzes and reports
- **Assembly reduction**: For assemblies, both versions are reduced to enable content-level comparison across all included modules
- **HTML-rendered comparison**: Both versions are rendered to HTML via asciidoctor and converted to plain text via html2text, so the diff shows only content changes visible to the reader, not markup noise (added attributes, IDs, block titles, etc.)
- **Module tracking**: For assemblies, the report identifies which individual modules were modified
- **Human review**: Potential issues are flagged but require human judgment to assess
- **Rendered content diff included**: The full rendered content diff is included in the report for detailed inspection
