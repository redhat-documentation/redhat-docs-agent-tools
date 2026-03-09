---
name: verify-procedure
description: Execute, test, and verify AsciiDoc procedures on a live cluster. Identifies "magic steps," validates YAML, and ensures the procedure functions as a "guided exercise."
allowed-tools:
  - Bash
  - Read
  - Edit
  - Glob
---

# Procedure Verification Skill

[cite_start]This skill acts as "first-line QE" for technical documentation[cite: 54]. [cite_start]It ensures procedures are sequential, precise, and contain no "magic steps" or assumed knowledge[cite: 6, 12, 14].

## Core Principles

When verifying a procedure, the skill must enforce these standards:
- [cite_start]**No Magic Steps**: Ensure every command and prerequisite is explicitly stated[cite: 6].
- [cite_start]**Sequential Clarity**: Steps must be numbered and follow a logical order to prevent errors[cite: 12, 13].
- [cite_start]**Live Validation**: Commands and YAML must be tested against a live cluster to ensure they work end-to-end[cite: 7, 41].
- [cite_start]**Verification Points**: Procedures must include steps to verify the outcome (e.g., checking status, logs, or config files).

## Usage

1. **Identify**: Find the `.adoc` file to be tested.
2. **Scan**: Identify bash and YAML blocks associated with numbered steps.
3. **Execute**: Use the Ruby script to run the commands on the cluster.
   ```bash
   ruby .claude/skills/verify-procedure/scripts/verify_proc.rb <file.adoc>
