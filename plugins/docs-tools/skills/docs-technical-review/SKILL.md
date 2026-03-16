---
name: docs-technical-review
description: Validate documentation technical accuracy against source code repositories. Runs a deterministic pipeline (extract, search, triage, scan) to detect stale commands, flags, APIs, config keys, code examples, and file paths.
allowed-tools: Read, Bash, Glob, Grep
---

# Technical Review Skill

Validate documentation against source code repositories using a deterministic Python pipeline.

## Prerequisites

- `python3` (standard library only, no pip dependencies)
- Code repositories already cloned to local paths

## Invocation

Run the `tech_references.py` script in `review` mode to chain all four deterministic phases (extract, search, triage, scan):

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/commands/scripts/tech_references.py" review \
  <doc_files...> \
  --repos <repo_paths...> \
  --docs-dir <scan_dir> \
  --output /tmp/tech-review-results.json
```

- `<doc_files...>`: One or more `.adoc` or `.md` file paths or directories
- `<repo_paths...>`: One or more local paths to cloned code repositories
- `<scan_dir>`: Directory of docs to scan for blast radius (typically the parent directory of the doc files)
- `--output`: Path for the JSON results file

Read the JSON output file after the script completes.

## Output Schema

Top-level keys:

| Key | Description |
|-----|-------------|
| `issues` | Array of triaged items with `triage_status: issue` or `needs-confirmation` |
| `out_of_scope` | Array of items tagged `out-of-scope` (external commands, skipped) |
| `verified` | Array of items that passed all checks |
| `discovered_schemas` | Schema files found in code repos |
| `discovered_cli_definitions` | CLI entry points found (argparse, click, cobra) |

Per-issue fields:

| Field | Description |
|-------|-------------|
| `category` | `command`, `code_block`, `api`, `config`, `file_path`, or `env_var` |
| `reference` | The original extracted reference (file, line, content) |
| `confidence` | 0-100 integer, how certain the issue is real |
| `severity` | `high`, `medium`, or `low` |
| `triage_pass` | Which pass flagged this (1, 2, or 3) |
| `triage_status` | `issue`, `out-of-scope`, `verified`, or `needs-confirmation` |
| `evidence` | Search matches, git log entries, CLI/schema validation data |
| `suggested_fix` | Deterministic fix suggestion (when available) |
| `blast_radius` | Array of `{file, line, match}` — other docs with the same pattern |

## Pass 4: Source Verification (your job)

The Python pipeline handles passes 1-3 deterministically. Pass 4 requires reading source code, which is your responsibility.

For each issue with `triage_status: needs-confirmation` and `confidence >= 50`:

1. Read the source file cited in the `evidence` field
2. Confirm or refute the issue based on what the source code actually says
3. Upgrade confidence if source confirms the issue
4. Downgrade confidence (or drop the issue) if source contradicts it

Do not report issues you cannot confirm against source code.

## Interpreting Results for Review Dimensions

Map pipeline output to the technical-reviewer's review dimensions:

| Pipeline output | Review dimension |
|----------------|-----------------|
| `cli_validation` issues (unknown flags, invalid subcommands) | 3. Command and API accuracy |
| `schema_validation` issues (keys only in doc, missing from schema) | 3. Command and API accuracy |
| Code block `found: false` | 1. Code example integrity |
| File path issues | 2. Prerequisite completeness or 6. Cross-references |
| `env_var` issues (not found in code) | 3. Command and API accuracy |
| `blast_radius` data | Note additional affected files in your findings |
| `out_of_scope` items | Skip, do not report |
| Items with confidence < 50 and no source confirmation | Recommend SME verification |
