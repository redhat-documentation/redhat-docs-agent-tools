---
name: jtbd-identify
description: Identify the core Job-to-be-Done from AsciiDoc documentation. Extracts metadata and uses LLM analysis to define the job executor, situation, motivation, and expected outcome. Produces a JTBD statement in standard format. Use this skill when asked to identify jobs, define JTBD statements, or analyze documentation from a user outcome perspective.
model: claude-opus-4-5@20251101
allowed-tools: Bash, Glob, Read, Edit, Write
---

# JTBD Job Identification Skill

Identify the core Job-to-be-Done (JTBD) from an AsciiDoc module or assembly and produce a structured job statement.

## Overview

Every piece of documentation exists to help a user accomplish a job. This skill identifies that job by analyzing the document's title, content type, abstract, and executor hints, then produces a JTBD statement in the standard format:

> "When [situation], I want to [motivation], so I can [expected outcome]."

## AI Action Plan

**When to use this skill**: When asked to identify jobs, define JTBD statements, or analyze documentation from a user outcome perspective.

**Steps to follow**:

1. **Run the extraction script** to get structured metadata:

```bash
ruby ${CLAUDE_PLUGIN_ROOT}/skills/jtbd-identify/scripts/jtbd_identify.rb "<file.adoc>" --json
```

2. **Read the file** to understand the full context beyond what the script extracts.

3. **Identify the Core Job Executor**:
   - Who is the person performing this job?
   - Use executor hints from the script output
   - Common executors: cluster administrator, developer, platform engineer, application owner, SRE
   - If no executor hints, infer from content type and topic

4. **Define the Job Statement** using this format:
   - **Situation**: The circumstance or trigger that creates the need
   - **Motivation**: The action the user wants to take (verb-based)
   - **Expected Outcome**: The end result or benefit the user achieves

5. **Apply JTBD constraints**:
   - Do NOT include product names in the statement (no "OpenShift", "Kubernetes", etc.)
   - Focus on functional goals, not emotional goals
   - The job should be stable over time (technology-agnostic where possible)
   - The job should be solution-agnostic (describe the need, not the tool)

6. **Output a YAML block** with the structured result:

```yaml
executor: "cluster administrator"
job: "control application traffic routing during node failures"
situation: "When nodes in my cluster become unavailable"
motivation: "I want to configure automatic traffic failover"
outcome: "so I can maintain application availability without manual intervention"
statement: "When nodes in my cluster become unavailable, I want to configure automatic traffic failover, so I can maintain application availability without manual intervention."
confidence: high  # high, medium, or low
notes: "Optional notes about assumptions or ambiguities"
```

## Job Statement Guidelines

### Good job statements

- Focus on the user's goal, not the product feature
- Use plain language (no jargon)
- Are testable (you can verify if the job was done)
- Are stable over time

### Examples

**Feature-centric (bad)**: "Configure EgressIP failover"
**Job statement (good)**: "When my application needs a stable external IP address, I want to configure outbound traffic routing, so I can maintain consistent network identity for external services."

**Feature-centric (bad)**: "Install the Operator"
**Job statement (good)**: "When I need to add a new capability to my cluster, I want to install and configure the required components, so I can enable the functionality my applications depend on."

## Content Type Considerations

| Content Type | Typical Job Pattern |
|-------------|-------------------|
| CONCEPT | Understanding/learning job ("When I need to understand X...") |
| PROCEDURE | Doing/accomplishing job ("When I need to accomplish X...") |
| REFERENCE | Looking up/deciding job ("When I need to find the right setting for X...") |
| ASSEMBLY | Multi-step journey ("When I need to set up X end-to-end...") |

## Output Format

Present the JTBD analysis as:

1. **Script output summary** - Key metadata extracted
2. **YAML block** - Structured job statement
3. **Rationale** - Brief explanation of why this job was identified
4. **Suggestions** - If the document title or abstract could be improved to better reflect the job

## Usage

```bash
# Identify the job for a single module
/jtbd-tools:jtbd-identify modules/configuring-egress-ips.adoc

# Identify the job for an assembly
/jtbd-tools:jtbd-identify guides/networking/master.adoc
```
