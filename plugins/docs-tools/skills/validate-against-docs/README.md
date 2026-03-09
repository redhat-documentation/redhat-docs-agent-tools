# Validate Against Docs Skill

Validate OpenShift procedures against official documentation using NotebookLM.

## Overview

This skill integrates with your existing `notebooklm-mcp` server to provide AI-powered documentation validation for OpenShift procedures.

## Files

- **SKILL.md** - Claude Code skill definition and full documentation
- **INTEGRATION.md** - Quick integration guide for your existing NotebookLM setup
- **README.md** - This file

## Quick Start

### Step 1: Find or Create Documentation Notebook

**Option A: Use Existing Notebook (Recommended)**

First, list your existing notebooks to see if you already have OpenShift documentation:

```
List my NotebookLM notebooks
```

Look for notebooks like:
- "Red Hat OpenShift Container Platform Documentation 4.20"
- "Red Hat OpenShift Container Platform Documentation 4.19"
- "OpenShift Docs manual"

**Option B: Create New Notebook**

If you don't have one, ask Claude Code:
```
Create a new NotebookLM notebook called "OpenShift CNF Documentation" and add:
- https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/scalability_and_performance/
- https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/nodes/
- https://redhat-documentation.github.io/supplementary-style-guide/
```

### Step 2: Set Up Notebook ID

**Copy the notebook ID** from the list (e.g., `d14fb168-b0d0-453f-8000-a24dcee1218b`)

Add to your `~/.bashrc` for permanent access:
```bash
echo 'export OPENSHIFT_DOCS_NOTEBOOK_ID="d14fb168-b0d0-453f-8000-a24dcee1218b"' >> ~/.bashrc
source ~/.bashrc
```

**Why set this in .bashrc?**
- Makes the notebook ID available in all terminal sessions
- Can reference as `${OPENSHIFT_DOCS_NOTEBOOK_ID}` in shell scripts
- Simplifies validation commands

### Step 3: Test the Connection

Verify it works:
```
Query notebook ${OPENSHIFT_DOCS_NOTEBOOK_ID}:
"What fields are required in a PerformanceProfile spec?"
```

### Step 4: Validate Procedures

Ask Claude Code to validate your procedure:
```
Validate this procedure against the OpenShift docs in notebook ${OPENSHIFT_DOCS_NOTEBOOK_ID}:

<paste procedure content or file path>

Check:
1. Command syntax (oc commands, flags, arguments)
2. API resource field accuracy
3. Prerequisites completeness
4. Red Hat documentation standards
```

## Integration with verify-procedure

Use both skills together:

1. **verify-procedure** - Tests procedure on live cluster (functional validation)
2. **validate-against-docs** - Checks procedure against official docs (accuracy validation)

Together they ensure procedures are both **functional** and **accurate**.

## See Also

- [INTEGRATION.md](./INTEGRATION.md) - Detailed integration guide
- [SKILL.md](./SKILL.md) - Full skill documentation
- [~/notebooklm-mcp/CLAUDE.md](~/notebooklm-mcp/CLAUDE.md) - NotebookLM MCP server docs
