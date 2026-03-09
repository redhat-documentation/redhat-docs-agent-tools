---
name: jtbd-job-map
description: Map AsciiDoc assembly modules to the 8 Universal Job Map steps (Define, Locate, Prepare, Confirm, Execute, Monitor, Modify, Conclude). Identifies documentation gaps where job steps lack coverage. Use this skill when asked to map documentation to job steps, analyze documentation coverage, or identify missing user journey stages.
model: claude-opus-4-5@20251101
allowed-tools: Bash, Glob, Read, Edit, Write
---

# JTBD Universal Job Map Skill

Map assembly modules to the 8 Universal Job Map steps and identify documentation gaps.

## Overview

The Universal Job Map describes the 8 steps every user goes through when getting a job done:

1. **Define** - Determine goals and plan the approach
2. **Locate** - Gather items and information needed
3. **Prepare** - Set up the environment and components
4. **Confirm** - Verify readiness before proceeding
5. **Execute** - Perform the core task
6. **Monitor** - Track progress and status
7. **Modify** - Make adjustments as needed
8. **Conclude** - Finish, clean up, and verify success

This skill maps each module in an assembly to these steps and identifies gaps where steps have no documentation coverage.

## AI Action Plan

**When to use this skill**: When asked to map documentation structure to user journey steps, analyze documentation coverage, or find gaps in the user experience.

**Steps to follow**:

1. **Run the extraction script** to get assembly structure and module metadata:

```bash
ruby ${CLAUDE_PLUGIN_ROOT}/skills/jtbd-job-map/scripts/jtbd_job_map.rb "<assembly.adoc>" --json
```

2. **Read key modules** to understand their content beyond titles and abstracts.

3. **Map each module to a Job Map step**:
   - A module can map to multiple steps
   - A step can have multiple modules
   - Use the module's content type, title, and abstract to determine mapping

4. **Apply mapping heuristics**:

| Job Map Step | Content Type Hints | Title/Content Hints |
|-------------|-------------------|-------------------|
| Define | CONCEPT | "Understanding", "About", "Overview", "Architecture" |
| Locate | REFERENCE | "Requirements", "Supported", "Compatibility" |
| Prepare | PROCEDURE | "Installing", "Setting up", "Prerequisites" |
| Confirm | PROCEDURE | "Verifying", "Checking", "Validating" |
| Execute | PROCEDURE | "Configuring", "Creating", "Deploying" |
| Monitor | PROCEDURE, REFERENCE | "Monitoring", "Viewing", "Checking status" |
| Modify | PROCEDURE | "Updating", "Modifying", "Scaling", "Tuning" |
| Conclude | PROCEDURE, CONCEPT | "Removing", "Cleaning up", "Migrating", "Troubleshooting" |

5. **Identify gaps** - steps with no corresponding documentation:
   - Missing "Define" → Users do not know what they are doing or why
   - Missing "Locate" → Users cannot find required prerequisites
   - Missing "Prepare" → Users cannot set up their environment
   - Missing "Confirm" → Users proceed without verifying readiness
   - Missing "Execute" → Core task not documented
   - Missing "Monitor" → Users cannot track progress
   - Missing "Modify" → Users cannot adjust after initial setup
   - Missing "Conclude" → Users do not know when they are done or how to clean up

6. **Output a mapping table and gap analysis**

## Output Format

### Job Map Table

```markdown
| Job Map Step | Module | Content Type | Coverage |
|-------------|--------|-------------|----------|
| Define | about-networking.adoc | CONCEPT | Full |
| Locate | (none) | - | GAP |
| Prepare | installing-operator.adoc | PROCEDURE | Full |
| Confirm | (none) | - | GAP |
| Execute | configuring-egress-ips.adoc | PROCEDURE | Full |
| Monitor | (none) | - | GAP |
| Modify | updating-egress-config.adoc | PROCEDURE | Partial |
| Conclude | (none) | - | GAP |
```

### Gap Summary

For each gap, explain:
- What the user needs at that stage
- What type of module would fill the gap (CONCEPT, PROCEDURE, or REFERENCE)
- A suggested title for the missing module

## Usage

```bash
# Map an assembly to the Universal Job Map
/jtbd-tools:jtbd-job-map guides/networking/master.adoc

# Map a top-level assembly
/jtbd-tools:jtbd-job-map master.adoc
```
