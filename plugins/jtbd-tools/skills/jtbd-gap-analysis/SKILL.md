---
name: jtbd-gap-analysis
description: Analyze AsciiDoc procedures for 6 types of JTBD documentation gaps (prerequisite verification, monitoring, outcome verification, error recovery, decision, rollback). Produces a severity-rated gap report. Use this skill when asked to find documentation gaps, check procedure completeness, or identify missing user guidance.
model: claude-opus-4-5@20251101
allowed-tools: Bash, Glob, Read, Edit, Write
---

# JTBD Gap Analysis Skill

Identify documentation gaps that prevent users from successfully completing their jobs.

## Overview

Even well-written documentation can have gaps that leave users stuck. This skill checks for 6 types of gaps that map to JTBD failure points:

1. **Prerequisite verification gap** - Users cannot confirm they are ready to start
2. **Monitoring gap** - Users cannot track progress during multi-step procedures
3. **Outcome verification gap** - Users cannot confirm they succeeded
4. **Error recovery gap** - Users have no guidance when steps fail
5. **Decision gap** - Users must choose without trade-off information
6. **Rollback gap** - Users perform destructive operations without undo guidance

## AI Action Plan

**When to use this skill**: When asked to find documentation gaps, check procedure completeness, analyze user experience quality, or identify missing guidance.

**Steps to follow**:

1. **Run the gap analysis script** to detect gaps automatically:

```bash
ruby ${CLAUDE_PLUGIN_ROOT}/skills/jtbd-gap-analysis/scripts/jtbd_gap_analysis.rb "<file.adoc>" --json
```

2. **Read the file** to validate and refine the script findings.

3. **Review each detected gap** and assess whether it is a true gap or a false positive:
   - Some "error recovery gaps" may not apply to simple, low-risk commands
   - Some "decision gaps" may have trade-off guidance elsewhere in the assembly
   - Some procedures are intentionally minimal and do not need monitoring steps

4. **Look for gaps the script may have missed**:
   - **Implicit prerequisites** that are not listed (e.g., needing network access, specific permissions)
   - **Long wait times** that are not mentioned (e.g., "wait for the operator to install" without specifying how long)
   - **Environment-specific variations** not covered (e.g., cloud vs. bare metal differences)
   - **Security implications** of configuration choices

5. **Rate each gap by severity**:
   - **High**: User will likely get stuck or cause damage without this information
   - **Medium**: User may be confused or make suboptimal choices
   - **Low**: Nice to have but not blocking

6. **Write the gap analysis report** to `/tmp/jtbd-gap-analysis-report.md`

## Gap Type Details

### 1. Prerequisite Verification Gap

**What it means**: Prerequisites are listed but users cannot verify they meet them.

**Example gap**:
```
.Prerequisites
* You have cluster-admin privileges.
```

**Fix**: Add verification command:
```
.Prerequisites
* You have cluster-admin privileges. Verify by running `oc auth can-i create clusterroles`.
```

### 2. Monitoring Gap

**What it means**: A multi-step procedure with no progress-checking guidance.

**Example gap**: A 10-step installation procedure with no "check status" steps between commands.

**Fix**: Add monitoring steps:
```
. Run the installation command.
. Verify the pods are starting:
+
[source,terminal]
----
$ oc get pods -n <namespace> -w
----
```

### 3. Outcome Verification Gap

**What it means**: No `.Verification` section, or the section is vague.

**Vague example**:
```
.Verification
* Verify the installation was successful.
```

**Concrete example**:
```
.Verification
* Run the following command and verify the output shows `Ready`:
+
[source,terminal]
----
$ oc get deployment -n my-namespace
----
```

### 4. Error Recovery Gap

**What it means**: Steps that can fail have no troubleshooting guidance.

**Example gap**: `oc apply -f config.yaml` without mentioning what to do if it fails.

**Fix**: Add error guidance:
```
. Apply the configuration:
+
[source,terminal]
----
$ oc apply -f config.yaml
----
+
If this command fails with a validation error, check the YAML syntax.
```

### 5. Decision Gap

**What it means**: Users must choose between options without trade-off information.

**Example gap**: "Choose either option A or option B" without explaining the implications.

**Fix**: Add trade-off guidance:
```
Choose one of the following deployment strategies:

* **Rolling update**: Gradual replacement with zero downtime. Use when availability is critical.
* **Recreate**: All pods replaced at once. Use when you need a clean cutover and can tolerate brief downtime.
```

### 6. Rollback Gap

**What it means**: Destructive operations (delete, remove, drop) without backup or undo guidance.

**Example gap**: `oc delete project my-project` without mentioning backups.

**Fix**: Add rollback guidance:
```
WARNING: This action is irreversible. Before proceeding, back up any important data:

[source,terminal]
----
$ oc get project my-project -o yaml > project-backup.yaml
----
```

## Output Format

Write the report to `/tmp/jtbd-gap-analysis-report.md`:

```markdown
# JTBD Gap Analysis Report

## File: <filename>
## Title: <document title>
## Content Type: <type>

## Summary

| Severity | Count |
|----------|-------|
| High | 2 |
| Medium | 3 |
| Low | 1 |
| **Total** | **6** |

## Gap Details

### HIGH Severity

1. **Outcome verification gap** (no .Verification section)
   - Impact: Users cannot confirm the procedure succeeded
   - Recommendation: Add .Verification section with `oc get` command and expected output

2. **Rollback gap** (line 45: `oc delete project`)
   - Impact: Destructive operation with no undo guidance
   - Recommendation: Add backup command before the delete step

### MEDIUM Severity

...

### LOW Severity

...
```

## Usage

```bash
# Analyze a single procedure
/jtbd-tools:jtbd-gap-analysis modules/proc-installing-operator.adoc

# Analyze all procedures in a directory
# (Run the script manually on each file)
for f in modules/proc-*.adoc; do
  ruby jtbd-tools/skills/jtbd-gap-analysis/scripts/jtbd_gap_analysis.rb "$f"
done
```
