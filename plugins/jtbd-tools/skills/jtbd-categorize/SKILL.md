---
name: jtbd-categorize
description: Categorize AsciiDoc assembly modules into Red Hat JTBD categories (Discover, Get Started, Plan, Install, Configure, Observe, Troubleshoot). Produces a categorization report for TOC reorganization. Use this skill when asked to categorize documentation, organize a TOC by user journey, or align documentation structure with JTBD categories.
model: claude-opus-4-5@20251101
allowed-tools: Bash, Glob, Read, Edit, Write
---

# JTBD TOC Categorization Skill

Categorize assembly modules into Red Hat JTBD categories for TOC organization.

## Overview

Red Hat documentation uses 7 JTBD categories to organize content by user journey stage:

1. **Discover** - Learn what the product does and whether it fits your needs
2. **Get Started** - Quick start guides and first-time setup
3. **Plan** - Architecture decisions, sizing, and deployment planning
4. **Install** - Installation and initial deployment
5. **Configure** - Post-install configuration and customization
6. **Observe** - Monitoring, logging, and status checking
7. **Troubleshoot** - Problem resolution and debugging

This skill classifies each module in an assembly into these categories and produces a recommendation report.

## AI Action Plan

**When to use this skill**: When asked to categorize documentation, organize a TOC by user journey, or align documentation structure with JTBD categories.

**Steps to follow**:

1. **Run the extraction script** to get the assembly TOC structure:

```bash
ruby ${CLAUDE_PLUGIN_ROOT}/skills/jtbd-categorize/scripts/jtbd_categorize.rb "<assembly.adoc>" --json
```

2. **Read key modules** if titles and abstracts are insufficient for categorization.

3. **Classify each module** into a JTBD category using these heuristics:

| Category | Content Type Hints | Title/Content Patterns |
|----------|-------------------|----------------------|
| Discover | CONCEPT | "About", "Overview", "Understanding", "Architecture", "How X works" |
| Get Started | ASSEMBLY, PROCEDURE | "Getting started", "Quick start", "Tutorial", "First steps" |
| Plan | CONCEPT, REFERENCE | "Planning", "Requirements", "Sizing", "Supported configurations" |
| Install | PROCEDURE | "Installing", "Deploying", "Setting up", "Upgrading" |
| Configure | PROCEDURE, REFERENCE | "Configuring", "Customizing", "Setting", "Enabling", "Options" |
| Observe | PROCEDURE, REFERENCE | "Monitoring", "Logging", "Viewing", "Checking", "Metrics", "Alerts" |
| Troubleshoot | PROCEDURE, REFERENCE | "Troubleshooting", "Debugging", "Known issues", "Error messages" |

4. **Handle ambiguous cases**:
   - If a module could fit multiple categories, choose the primary one and note the secondary
   - Procedures that include both install and configure steps → categorize by the primary intent
   - Reference tables → categorize by what the user is looking up

5. **Produce the categorization report** (recommendation only, no automatic reordering):

## Output Format

### Categorization Report

```markdown
## JTBD Categorization Report

### Assembly: <assembly title>

| # | Module | Current Position | JTBD Category | Confidence | Notes |
|---|--------|-----------------|---------------|------------|-------|
| 1 | about-networking.adoc | 1 | Discover | High | Overview content |
| 2 | requirements.adoc | 2 | Plan | High | Prerequisites and requirements |
| 3 | installing-operator.adoc | 3 | Install | High | Installation procedure |
| 4 | configuring-egress.adoc | 4 | Configure | High | Configuration procedure |
| 5 | viewing-status.adoc | 5 | Observe | Medium | Could also be Configure |

### Category Distribution

| Category | Count | Modules |
|----------|-------|---------|
| Discover | 1 | about-networking.adoc |
| Get Started | 0 | (none) |
| Plan | 1 | requirements.adoc |
| Install | 1 | installing-operator.adoc |
| Configure | 1 | configuring-egress.adoc |
| Observe | 1 | viewing-status.adoc |
| Troubleshoot | 0 | (none) |

### Gaps

- **Get Started**: No quick-start or tutorial content. Consider adding a "Getting started with networking" assembly.
- **Troubleshoot**: No troubleshooting content. Consider adding common error scenarios and resolutions.

### Suggested TOC Order (by JTBD journey)

1. [Discover] about-networking.adoc
2. [Plan] requirements.adoc
3. [Install] installing-operator.adoc
4. [Configure] configuring-egress.adoc
5. [Observe] viewing-status.adoc
```

## Important Notes

- This skill produces a **recommendation report only** — it does NOT automatically reorder the assembly
- The user should review the categorization and decide whether to reorganize
- Some assemblies are intentionally organized differently (by feature, by role, etc.)
- The JTBD categories are a guide, not a strict requirement

## Usage

```bash
# Categorize an assembly's modules
/jtbd-tools:jtbd-categorize guides/networking/master.adoc

# Categorize a top-level assembly
/jtbd-tools:jtbd-categorize master.adoc
```
