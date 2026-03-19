---
name: cqa-assess
description: Use when starting or continuing a full CQA 2.1 content quality assessment. Guides through all three tabs (Pre-migration, Quality, Onboarding) parameter by parameter.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# CQA 2.1 Content Quality Assessment

## Overview

Run a complete CQA 2.1 assessment against a Red Hat modular documentation repository. The assessment covers three tabs with 54 total parameters across Pre-migration, Quality, and Onboarding.

See [scoring-guide.md](../../reference/scoring-guide.md) for score definitions and [checklist.md](../../reference/checklist.md) for the full parameter list.

## Workflow

### Step 0: Ask the user for scope and mode

Before starting any checks, ask the user two questions:

**Scope** — what to assess:
- **Entire repo** — all files in the repository
- **One assembly** — a specific assembly file and all topics it includes (resolve `include::` directives to find the topic files)
- **One topic** — a single topic file
- **One parameter group** — a specific skill (e.g., editorial only) across the chosen file scope

**Mode** — what to do with issues:
- **Assess only** — report issues and score, but do not modify any files
- **Assess and fix** — report issues, fix them, re-verify, then score

### Steps 1-8: For each parameter

1. **Pick a parameter** from the checklist (or let the user specify one)
2. **Invoke the matching skill** for that parameter group
3. **Run the check** — automated where possible, manual review where needed. Apply to the files within the user's chosen scope only.
4. **If assess-and-fix mode**: fix issues found during the check, then re-run the check to confirm 0 issues
5. **Score the parameter** with evidence
6. **Report results** to the user: score, evidence, files changed (if any)
7. **Mark parameter complete** on the checklist
8. **Repeat** for the next parameter

## Skill Map

| Skill | Parameters Covered |
|-------|-------------------|
| `cqa-vale-check` | P1 |
| `cqa-modularization` | P2, P3, P4, P5, P6, P7 |
| `cqa-titles-descriptions` | P8, P9, P10, P11, Q11 |
| `cqa-procedures` | P12, Q12, Q13, Q14, Q15, Q16 |
| `cqa-editorial` | P13, P14, Q1, Q2, Q3, Q4, Q5, Q18, Q20 |
| `cqa-links` | P15, P16, P17, Q24, Q25 |
| `cqa-legal-branding` | P18, P19, Q17, Q23, O1, O2, O3, O4, O5 |
| `cqa-user-focus` | Q6, Q7, Q8, Q9, Q10 |
| `cqa-tables-images` | Q19, Q21, Q22 |
| `cqa-onboarding` | O6, O7, O8, O9, O10 |
| `cqa-report` | Final report generation |

## Assessment Order

Recommended order (dependencies flow downward):

1. `cqa-vale-check` — foundational; fixes here affect other checks
2. `cqa-modularization` — structural compliance
3. `cqa-titles-descriptions` — metadata quality
4. `cqa-procedures` — procedure structure
5. `cqa-editorial` — writing quality
6. `cqa-links` — cross-references and URLs
7. `cqa-legal-branding` — compliance
8. `cqa-user-focus` — content quality
9. `cqa-tables-images` — visual elements
10. `cqa-onboarding` — publishing readiness
11. `cqa-report` — final summary

## Automation Scripts

Reusable scripts in `skills/cqa-assess/scripts/` automate repetitive checks. Each script accepts a docs repo path and exits 0 (pass) or 1 (issues found). Python 3.9+ stdlib only.

| Script | Skill | Parameters |
|--------|-------|-----------|
| `check-product-names.py` | `cqa-legal-branding` | P18, O1, O3 |
| `check-conscious-language.py` | `cqa-legal-branding` | Q23, O4 |
| `check-content-types.py` | `cqa-modularization` | P3, P4, P5 |
| `check-tp-disclaimers.py` | `cqa-legal-branding` | P19, O5 |
| `check-external-links.py` | `cqa-legal-branding` | Q17 |
| `check-legal-notices.py` | `cqa-legal-branding` | O2 |
| `check-scannability.py` | `cqa-editorial` | Q1 |
| `check-simple-words.py` | `cqa-editorial` | Q3 |
| `check-readability.py` | `cqa-editorial` | Q4 |
| `check-fluff.py` | `cqa-editorial` | Q5 |

Run all at once:

```bash
for script in ${CLAUDE_PLUGIN_ROOT}/skills/cqa-assess/scripts/check-*.py; do
  python3 "$script" "$DOCS_REPO"
  echo "---"
done
```

## Important Rules

- **Respect the user's chosen mode.** In assess-only mode, never modify files. In assess-and-fix mode, fix everything before scoring.
- **Respect the user's chosen scope.** Only assess files within the scope (repo, assembly + its topics, or single topic). Do not scan files outside the scope.
- **0 errors, 0 warnings for automated checks.** Never suppress or ignore.
- **Evidence before claims.** Run the verification command, read the output, then state the score.
- **Update project rules** with any new rules discovered during the assessment.
