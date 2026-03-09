---
name: jtbd-rewrite
description: Rewrite AsciiDoc documentation from feature-centric to outcome-oriented style. Transforms titles, parameter tables, prerequisites, and verification sections to focus on user outcomes and trade-offs. Use this skill when asked to make documentation more user-focused, outcome-oriented, or to improve titles and tables for JTBD alignment.
model: claude-opus-4-5@20251101
allowed-tools: Bash, Glob, Read, Edit, Write
---

# JTBD Outcome-Oriented Rewriting Skill

Rewrite AsciiDoc content to be outcome-oriented rather than feature-centric.

## Overview

Feature-centric documentation describes what a product does. Outcome-oriented documentation describes what the user can achieve. This skill transforms existing documentation to focus on user outcomes while preserving all technical accuracy.

## AI Action Plan

**When to use this skill**: When asked to make documentation more user-focused, rewrite titles for outcomes, add trade-off guidance to tables, or improve verification sections.

**Steps to follow**:

1. **Run the extraction script** to analyze the file:

```bash
ruby ${CLAUDE_PLUGIN_ROOT}/skills/jtbd-rewrite/scripts/jtbd_rewrite.rb "<file.adoc>" --json
```

2. **Read the full file** to understand context.

3. **Rewrite titles** (if title issues were found):
   - Convert noun-based titles to verb-based outcome titles
   - Use gerund form for procedures ("Configuring X" not "X configuration")
   - Use "Understanding" or similar for concepts
   - Remove product names where they are not essential for clarity

   **Examples**:
   | Before | After |
   |--------|-------|
   | EgressIP configuration | Controlling outbound traffic identity with EgressIPs |
   | NetworkPolicy settings | Restricting pod-to-pod communication with network policies |
   | Pod security | Enforcing security standards for workloads |
   | OAuth server | Configuring authentication for cluster access |

4. **Transform parameter tables** (if parameter tables with missing trade-off columns were found):
   - Add "What it controls" column explaining the user impact
   - Add "Trade-off" column explaining consequences of different values
   - Keep the "Default" column if present

   **Before**:
   ```
   | Parameter | Description | Default |
   |-----------|-------------|---------|
   | maxSurge | Max extra pods during update | 25% |
   | maxUnavailable | Max unavailable pods | 25% |
   ```

   **After**:
   ```
   | Parameter | What it controls | Trade-off | Default |
   |-----------|-----------------|-----------|---------|
   | maxSurge | How many extra pods are created during a rolling update | Higher = faster updates but more resource usage | 25% |
   | maxUnavailable | How many pods can be down during a rolling update | Higher = faster updates but reduced capacity | 25% |
   ```

5. **Improve prerequisites** (if prerequisites lack verification commands):
   - Add state-verification commands so users can confirm readiness
   - Each prerequisite should be verifiable

   **Before**:
   ```
   .Prerequisites
   * You have cluster-admin privileges.
   * The Operator is installed.
   ```

   **After**:
   ```
   .Prerequisites
   * You have cluster-admin privileges. Verify by running `oc auth can-i create clusterroles`.
   * The Operator is installed. Verify by running `oc get csv -n openshift-operators | grep <operator-name>`.
   ```

6. **Improve verification sections** (if verification is vague):
   - Add concrete success criteria
   - Include example command output where possible
   - Specify what the user should see

   **Before**:
   ```
   .Verification
   * Verify the resource was created.
   ```

   **After**:
   ```
   .Verification
   * Run the following command to verify the resource was created:
   +
   [source,terminal]
   ----
   $ oc get <resource> -n <namespace>
   ----
   +
   Expected output:
   +
   [source,terminal]
   ----
   NAME       READY   STATUS
   example    True    Active
   ----
   ```

7. **Do NOT change**:
   - Command syntax or code blocks (preserve exact technical content)
   - Technical parameter names or values
   - API endpoints or configuration keys
   - File paths or directory structures

## Rewrite Guidelines

### Title rewriting rules

- PROCEDURES: Use gerund form describing the outcome ("Configuring X to achieve Y")
- CONCEPTS: Use "Understanding" or outcome-focused phrasing ("How X enables Y")
- REFERENCES: Use descriptive phrasing ("X options and their trade-offs")
- Keep titles under 80 characters
- Do not remove context needed for disambiguation

### Table transformation rules

- Only transform tables that list parameters, options, or settings
- Do not transform tables that already have outcome/trade-off columns
- Do not transform tables that list examples, versions, or compatibility info
- "What it controls" should be in plain language (no jargon)
- "Trade-off" should explain both sides (e.g., "Higher = X but Y")

### Prerequisite rules

- Only add verification commands for prerequisites that can be verified via CLI
- Do not add verification for subjective prerequisites ("You understand networking concepts")
- Use the appropriate CLI tool (oc, kubectl, curl, etc.)

### Verification rules

- Include the actual command to run
- Include expected output or what to look for
- Specify what "success" looks like concretely

## Output Format

Report changes as:

```
## Rewrite Summary for <filename>

### Title
- Before: "EgressIP configuration"
- After: "Controlling outbound traffic identity with EgressIPs"
- Rationale: Changed from noun-based to outcome-oriented

### Tables
- Table at lines 25-40: Added "What it controls" and "Trade-off" columns

### Prerequisites
- Added verification command for 2 of 3 prerequisites

### Verification
- Rewrote vague verification to include concrete success criteria
```

## Usage

```bash
# Rewrite a single module
/jtbd-tools:jtbd-rewrite modules/configuring-egress-ips.adoc

# Rewrite with analysis only (no edits)
# Run the script directly to see what would change
ruby jtbd-tools/skills/jtbd-rewrite/scripts/jtbd_rewrite.rb modules/configuring-egress-ips.adoc
```
