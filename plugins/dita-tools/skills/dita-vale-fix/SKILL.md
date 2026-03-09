---
name: dita-vale-fix
description: Run Vale on AsciiDoc files and systematically fix all reported issues using the appropriate dita-* skills. Use this skill when asked to prepare files for DITA conversion, fix Vale issues, or validate AsciiDoc for DITA compatibility.
allowed-tools: Bash, Read, Glob, Skill, TodoWrite
---

# Vale issue resolution workflow skill

Run Vale on AsciiDoc files and systematically resolve all reported issues using the appropriate dita-* skills.

## Overview

This is an orchestration skill that provides end-to-end Vale validation and issue resolution. It runs Vale, analyzes the report, groups issues by type, and invokes the corresponding dita-* skills to fix each issue category.

## AI Action Plan

**When to use this skill**: When asked to prepare files for DITA conversion, fix Vale issues, validate AsciiDoc for DITA compatibility, or run comprehensive DITA preparation.

**Workflow steps**:

1. **Identify target files/directories**
   - If user specifies files/folders, use those
   - Otherwise, ask user which files to validate

2. **Run Vale on the target**
   ```bash
   vale path/to/files --output=JSON
   ```
   - Use JSON output for easier parsing
   - Capture all Vale issues

3. **Analyze the Vale report**
   - Parse JSON output
   - Group issues by rule name (EntityReference, ShortDescription, TaskStep, etc.)
   - Count issues per type
   - Identify files affected

4. **Create a todo list** with all issue types to fix

5. **Process issues in recommended order** (from simple to complex):
   - **Phase 1 - Informational** (report only, no fixes):
     - CrossReference → `/dita-cross-reference`
     - AttributeReference → `/dita-attribute-reference`
     - LinkAttribute → `/dita-link-attribute`

   - **Phase 2 - Simple structural fixes**:
     - AuthorLine → `/dita-author-line`
     - DocumentId → `/dita-document-id`
     - DocumentTitle → `/dita-document-title`
     - ContentType → `/dita-content-type`

   - **Phase 3 - Content formatting**:
     - EntityReference → `/dita-entity-reference`
     - LineBreak → `/dita-line-break`
     - ShortDescription → `/dita-short-description`
     - RelatedLinks → `/dita-related-links`

   - **Phase 4 - Block-level fixes**:
     - AdmonitionTitle → `/dita-admonition-title`
     - ExampleBlock → `/dita-example-block`
     - CalloutList → `/dita-callout-list`

   - **Phase 5 - Procedure-specific fixes**:
     - TaskContents → `/dita-task-contents`
     - TaskDuplicate → `/dita-task-duplicate`
     - TaskStep → `/dita-task-step`

   - **Phase 6 - Complex structural changes**:
     - BlockTitle → `/dita-block-title`
     - NestedSection → `/dita-nested-section`
     - AssemblyContents → `/dita-assembly-contents`

6. **For each issue type**:
   - Invoke the corresponding skill using the Skill tool
   - Update todo list to mark as completed
   - Report progress to user

7. **Re-run Vale** to verify fixes

8. **Report summary**:
   - Issues found vs. issues fixed
   - Remaining issues (if any)
   - Files modified
   - Recommendations for manual review

## Issue Type to Skill Mapping

| Vale Rule | Skill Name | Phase | Type |
|-----------|-----------|-------|------|
| CrossReference | dita-cross-reference | 1 | Informational |
| AttributeReference | dita-attribute-reference | 1 | Informational |
| LinkAttribute | dita-link-attribute | 1 | Informational |
| AuthorLine | dita-author-line | 2 | Simple fix |
| DocumentId | dita-document-id | 2 | Simple fix |
| DocumentTitle | dita-document-title | 2 | Simple fix |
| ContentType | dita-content-type | 2 | Simple fix |
| EntityReference | dita-entity-reference | 3 | Content fix |
| LineBreak | dita-line-break | 3 | Content fix |
| ShortDescription | dita-short-description | 3 | Content fix |
| RelatedLinks | dita-related-links | 3 | Content fix |
| AdmonitionTitle | dita-admonition-title | 4 | Block fix |
| ExampleBlock | dita-example-block | 4 | Block fix |
| TaskExample | dita-example-block | 4 | Block fix |
| CalloutList | dita-callout-list | 4 | Block fix |
| TaskContents | dita-task-contents | 5 | Procedure fix |
| TaskDuplicate | dita-task-duplicate | 5 | Procedure fix |
| TaskStep | dita-task-step | 5 | Procedure fix |
| BlockTitle | dita-block-title | 6 | Complex fix |
| NestedSection | dita-nested-section | 6 | Complex fix |
| TaskSection | dita-nested-section | 6 | Complex fix |
| AssemblyContents | dita-assembly-contents | 6 | Complex fix |

## Phased approach rationale

The workflow processes issues in phases to minimize conflicts:

1. **Informational first** - Identify issues that can be ignored or need manual review
2. **Simple structural fixes** - Add missing IDs, titles, content types
3. **Content formatting** - Fix entities, line breaks, abstracts, links
4. **Block-level fixes** - Handle admonitions, examples, callouts
5. **Procedure-specific** - Fix procedure structure and steps
6. **Complex structural** - Handle block titles, nested sections, assembly content

This order ensures that:
- Simple fixes don't get overwritten by complex ones
- Content type is set before procedure-specific fixes
- Document structure is correct before handling nested sections

## Running Vale

The skill uses Vale with JSON output for easier parsing:

```bash
# Single file
vale --output=JSON modules/my-file.adoc

# Directory
vale --output=JSON modules/

# Specific files
vale --output=JSON modules/file1.adoc modules/file2.adoc assemblies/assembly1.adoc
```

## Example JSON output structure

```json
{
  "modules/example.adoc": [
    {
      "Action": {"Name": "error"},
      "Check": "AsciiDocDITA.ShortDescription",
      "Description": "Assign [role=\"_abstract\"] to a paragraph...",
      "Line": 5,
      "Link": "",
      "Message": "...",
      "Severity": "error",
      "Span": [1, 10]
    }
  ]
}
```

## Usage

When the user asks to fix Vale issues:

1. **Determine scope**:
   - Single file: `vale modules/example.adoc`
   - Directory: `vale modules/`
   - Multiple targets: `vale modules/ assemblies/`

2. **Run Vale with JSON output**

3. **Parse and group issues**

4. **Create todo list** for all phases

5. **Invoke skills** in phase order

6. **Report progress** after each phase

7. **Re-run Vale** to verify

8. **Summarize results**

## Example invocations

- "Fix all Vale issues in modules/"
- "Run Vale on my-file.adoc and fix all issues"
- "Prepare modules/ for DITA conversion"
- "Validate and fix assemblies/getting-started.adoc"
- "Run comprehensive Vale fixes on the documentation"

## Output format

### Initial report:
```
Running Vale on modules/ ...

Vale Report Summary:
- 45 issues found across 8 files
- 12 error(s), 28 warning(s), 5 info message(s)

Issues by type:
- ShortDescription: 8 files
- TaskStep: 5 files
- EntityReference: 3 files
- BlockTitle: 6 files
- DocumentId: 2 files
- CrossReference: 12 occurrences (informational)

Creating fix plan with 6 phases...
```

### Progress updates:
```
Phase 1: Informational issues
✓ CrossReference: Reported 12 occurrences (no fixes needed)

Phase 2: Simple structural fixes
✓ DocumentId: Added IDs to 2 files
✓ ContentType: Added content types to 3 files

Phase 3: Content formatting
⚙ ShortDescription: Fixing 8 files...
✓ ShortDescription: Fixed 8 files, drafted 5 new descriptions
...
```

### Final summary:
```
Vale Fix Summary:
==================

Initial issues: 45
Issues fixed: 38
Remaining issues: 7 (6 informational, 1 requires manual review)

Files modified: 8
- modules/example1.adoc: 6 fixes applied
- modules/example2.adoc: 4 fixes applied
...

Remaining issues:
- CrossReference: 12 occurrences (informational, can be ignored)
- BlockTitle: 1 occurrence in modules/complex.adoc (requires manual review - complex nesting)

Re-running Vale to verify...
✓ Verification complete: 38 issues resolved, 7 informational remaining

Recommendation: Review the 1 manual issue in modules/complex.adoc
```

## Error handling

If a skill fails or cannot fix an issue:
- Mark it in todo list as requiring manual review
- Continue with other issues
- Report in final summary

## Batch vs. Interactive mode

The skill can operate in two modes:

1. **Batch mode** (default): Fix all issues automatically where possible
2. **Interactive mode**: Ask user for confirmation before complex fixes
   - Invoked with: "Interactively fix Vale issues in modules/"
   - Prompts user before BlockTitle, NestedSection, AssemblyContents changes

## Re-validation

After fixes are applied, the skill automatically re-runs Vale to:
- Verify issues are resolved
- Catch any new issues introduced by fixes
- Provide confidence that files are DITA-ready

## Integration with other workflows

This skill can be combined with:
- **dita-reduce-asciidoc** - Flatten assemblies before Vale validation
- **dita-convert** - Convert to DITA after Vale validation passes
- **vale** skill - For standalone Vale execution with custom options

## Related skills

- Individual dita-* skills for targeted fixes
- vale skill for Vale execution only
- dita-convert for AsciiDoc to DITA conversion
- dita-cleanup for post-conversion DITA cleanup
