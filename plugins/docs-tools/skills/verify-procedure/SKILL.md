---
name: verify-procedure
description: Execute and test AsciiDoc procedures on a live system. Runs every command and validates every YAML block against a real cluster, VM, or host. Requires an active connection to the target system. For static review without a live system, use the technical-reviewer agent instead.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Glob
---

# Procedure Verification Skill

This skill executes documented procedures against a live system to prove they work end-to-end. It is the "guided exercise tester" — it runs every command, applies every YAML block, and reports what passes and what breaks.

**This is not a review tool.** For reviewing documentation quality, prerequisites, and structure without a live system, use the `technical-reviewer` agent.

## Prerequisites

You must be connected to the target system before invoking this skill:

- **OpenShift/Kubernetes**: `oc login` or valid `~/.kube/config`
- **RHEL/Linux**: Local access or SSH session to the target host
- **Ansible**: `ansible --version` succeeds and inventory is accessible

At invocation, the skill runs a connectivity check (e.g., `oc whoami`). If the check fails, the skill exits and directs the user to log in first or use `technical-reviewer` for offline review.

## How it works

1. **Parse**: Read the `.adoc` file and extract all `[source,terminal]`, `[source,bash]`, and `[source,yaml]` blocks, associating each with its numbered step.
2. **Execute**: Run the `verify_proc.rb` script against the file:
   ```bash
   ruby <skill_dir>/scripts/verify_proc.rb <file.adoc>
   ```
3. **Report**: Present the script output and flag any additional observations.

## What the Ruby script does

The `scripts/verify_proc.rb` script is a procedure runner that processes an AsciiDoc file sequentially:

### Step extraction
- Parses AsciiDoc numbered steps (`. Step text`) and their associated source blocks
- Associates each `[source,yaml]`, `[source,terminal]`, or `[source,bash]` block with the step that contains it

### Smart skipping
- **Example output blocks**: Detects blocks preceded by "Example output" or "output is shown" and skips them (they are expected output, not commands to run)
- **Placeholder blocks**: Detects `<placeholder>` patterns, `${VAR}` syntax, `CHANGEME`, or `REPLACE` markers and skips those steps, since they require user-specific values

### YAML validation
- Parses every `[source,yaml]` block with Ruby's YAML parser for syntax errors
- If the YAML contains `apiVersion:` (Kubernetes resource), runs `oc apply --dry-run=client` or `kubectl apply --dry-run=client` (auto-detects which CLI is available)
- Reports `[VALID]` or `[FAILURE]` with the specific error

### Bash execution
- Strips leading `$ ` prompts from command lines
- Joins backslash-continued lines
- Executes each command via `Open3.capture3` and captures stdout, stderr, and exit code
- For verification steps (containing words like "verify", "check", "confirm"), displays the command output
- On failure, logs the error but continues to the next step

### Best practices check
- Scans the full file for login/setup patterns (`oc login`, `ssh`, `sudo`, `subscription-manager`, `dnf install`, `ansible-playbook`, etc.)
- Warns if no setup pattern is found in a procedure over 500 characters, suggesting potential "magic steps"

### Summary
- Reports total executable steps, pass count, and fail count
- Lists each failed step with its error message
- Flags if no verification step exists in the procedure

## Output format

The script produces structured terminal output:

```
--- Starting Procedure Validation: <file.adoc> ---

[Step 1] Create a namespace for the PTP Operator
[VALID] YAML syntax for Step 1 is correct.
[VALID] Resource logic (dry-run via oc) passed for Step 1.

[Step 2] Create the Namespace CR
Executing: oc create -f ptp-namespace.yaml
[SUCCESS] Step 2 executed.

[Step 3] ...
[SKIP] Example output - not executed

============================================================
FINAL SUMMARY
============================================================
Total executable steps: 7
Passed: 6
Failed: 1

Failed steps:
  - Step 5: error: the server doesn't have a resource type "PtpConfig"
============================================================
✗ Some steps FAILED
============================================================
```

After the script output, add observations about any patterns noticed during execution (timing issues, missing waits, ordering problems).
