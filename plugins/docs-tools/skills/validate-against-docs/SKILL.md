---
name: validate-against-docs
description: Validate procedure technical accuracy against official documentation using NotebookLM. Queries a shared OpenShift documentation notebook to verify commands, YAML syntax, and technical details.
allowed-tools:
  - Read
  - Bash
  - mcp__notebooklm-mcp__notebook_query
  - mcp__notebooklm-mcp__notebook_get
  - mcp__notebooklm-mcp__notebook_list
---

# Validate Against Documentation Skill

This skill uses NotebookLM to validate procedure accuracy against official OpenShift documentation.

## Prerequisites

1. **NotebookLM Authentication**: Authenticate before using this skill
2. **Shared Documentation Notebook**: Create a notebook with:
   - OpenShift performance documentation
   - CNF/low-latency tuning guides
   - PerformanceProfile API reference
   - Real-time kernel documentation
   - Red Hat modular documentation style guides

## Setup

### 1. Authenticate with NotebookLM

Follow the notebooklm-mcp-server authentication process to get your cookies.

### 2. Create Shared Documentation Notebook

```python
# Create a notebook for OpenShift CNF documentation
notebook = create_notebook("OpenShift CNF Documentation")

# Add key documentation sources
add_url(notebook, "https://docs.redhat.com/en/documentation/openshift_container_platform/4.17/html/scalability_and_performance/")
add_url(notebook, "https://docs.redhat.com/en/documentation/openshift_container_platform/4.17/html/nodes/")
add_url(notebook, "https://docs.redhat.com/en/documentation/openshift_container_platform/4.17/html/networking/")

# Add Red Hat style guides
add_url(notebook, "https://redhat-documentation.github.io/supplementary-style-guide/")
add_url(notebook, "https://redhat-documentation.github.io/modular-docs/")
```

### 3. Set Notebook ID

```bash
# Export for reuse
export OPENSHIFT_DOCS_NOTEBOOK_ID="your-notebook-id"
```

## Usage

The skill reads a procedure file and validates it against the NotebookLM documentation notebook.

### As a Claude Code Skill

```bash
/validate-against-docs /path/to/procedure.adoc
```

### Programmatically

```bash
# With notebook ID from environment
claude code --skill validate-against-docs procedure.adoc

# With explicit notebook ID
claude code --skill validate-against-docs --notebook-id abc123 procedure.adoc
```

## What It Validates

### 1. **Command Syntax**
- Validates `oc` command flags and arguments
- Checks for deprecated commands
- Verifies JSONPath syntax

### 2. **API Resources**
- Validates YAML structure against API schemas
- Checks field names and values
- Verifies apiVersion and kind

### 3. **Prerequisites**
- Ensures all prerequisites are documented
- Checks for "magic steps" (undocumented assumptions)

### 4. **Verification Steps**
- Validates that procedures include verification
- Ensures example outputs match expected results

### 5. **Documentation Standards**
- Red Hat modular documentation compliance
- Style guide adherence
- Proper use of AsciiDoc markup

## Integration with verify-procedure

Use both skills together for comprehensive validation:

```bash
# 1. Test on live cluster (functional validation)
ruby docs-tools/skills/verify-procedure/scripts/verify_proc.rb procedure.adoc

# 2. Validate against documentation (accuracy validation)
/validate-against-docs procedure.adoc

# 3. Review both reports
```

## Output

The skill produces a validation report:

```
=== Documentation Validation Report ===
File: cnf-enabling-cpu-isolation-for-executed-processes.adoc

✓ Command Syntax: 8/8 commands valid
✓ API Resources: 2/2 resources valid
⚠ Prerequisites: 1 missing (must-gather collection)
✓ Verification Steps: Present
✓ Documentation Standards: Compliant

Issues Found:
1. [WARNING] Step 3: Command missing namespace flag
   Documentation: https://docs.redhat.com/...
   Suggested: oc exec -n <namespace> ...

2. [INFO] Missing prerequisite about must-gather
   Documentation: https://docs.redhat.com/...

Overall Score: 90/100
```

## Example Questions Asked to NotebookLM

When validating a procedure, the skill queries NotebookLM with questions like:

- "What is the correct syntax for oc get performanceprofile?"
- "What fields are required in a PerformanceProfile spec?"
- "What prerequisites are needed for per-pod power management?"
- "What is the correct cgroup path for cpuset.cpus in OpenShift 4.x?"
- "How should verification steps be structured in a procedure module?"

## Benefits

1. **Catches documentation drift** - Ensures procedures stay current with latest docs
2. **Validates technical accuracy** - Confirms commands/APIs match official documentation
3. **Improves consistency** - Enforces Red Hat documentation standards
4. **Reduces review cycles** - Catches issues before peer review
5. **Educational** - Teaches writers by showing documentation references

## Architecture

```
┌─────────────────────┐
│  procedure.adoc     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ validate-against-   │
│ docs skill          │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ NotebookLM MCP      │
│ Server              │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ NotebookLM Notebook │
│ (OpenShift CNF Docs)│
└─────────────────────┘
```

## Future Enhancements

- **Automatic doc updates**: Suggest documentation updates based on validated procedures
- **Style checking**: Integrate Vale for comprehensive style validation
- **Link validation**: Verify all documentation links are current
- **Version tracking**: Track which OpenShift version the procedure targets
