# NotebookLM Integration for Procedure Validation

Quick guide to integrate your existing NotebookLM MCP server with procedure validation.

## Your Existing Setup ✓

- **NotebookLM MCP**: `~/notebooklm-mcp/`
- **Authentication**: `cookies.txt` already configured
- **MCP Tools**: Available in Claude Code

## Quick Start

### 1. Create OpenShift Documentation Notebook

Run this in Claude Code to create a notebook with OpenShift docs:

```
Create a new NotebookLM notebook called "OpenShift CNF Documentation" and add these sources:
- https://docs.redhat.com/en/documentation/openshift_container_platform/4.17/html/scalability_and_performance/low-latency-tuning
- https://docs.redhat.com/en/documentation/openshift_container_platform/4.17/html/nodes/
- https://redhat-documentation.github.io/supplementary-style-guide/
- https://redhat-documentation.github.io/modular-docs/

Then give me the notebook ID.
```

### 2. Save the Notebook ID

```bash
echo 'export OPENSHIFT_DOCS_NOTEBOOK_ID="<your-notebook-id>"' >> ~/.bashrc
source ~/.bashrc
```

### 3. Test Query

Query the notebook to validate it works:

```
Query notebook ${OPENSHIFT_DOCS_NOTEBOOK_ID} with:
"What fields are required in a PerformanceProfile spec?"
```

## Integration with verify-procedure

### Option A: Two-Step Workflow (Simple)

Run both tools manually:

```bash
# Step 1: Functional validation on live cluster
ruby docs-tools/skills/verify-procedure/scripts/verify_proc.rb procedure.adoc

# Step 2: Ask Claude to validate against NotebookLM
# "Please validate this procedure against the OpenShift docs notebook"
```

### Option B: Combined Wrapper Script

Create `validate-procedure-complete.sh`:

```bash
#!/bin/bash
# Complete procedure validation: Live cluster + Documentation

PROCEDURE=$1
NOTEBOOK_ID=${OPENSHIFT_DOCS_NOTEBOOK_ID}

if [ -z "$PROCEDURE" ]; then
    echo "Usage: $0 <procedure.adoc>"
    exit 1
fi

if [ -z "$NOTEBOOK_ID" ]; then
    echo "Error: OPENSHIFT_DOCS_NOTEBOOK_ID not set"
    exit 1
fi

echo "============================================"
echo "PROCEDURE VALIDATION REPORT"
echo "File: $PROCEDURE"
echo "============================================"
echo ""

echo "=== Phase 1: Functional Validation ==="
echo "Testing commands on live cluster..."
echo ""

ruby docs-tools/skills/verify-procedure/scripts/verify_proc.rb "$PROCEDURE"
FUNCTIONAL_EXIT=$?

echo ""
echo "=== Phase 2: Documentation Validation ==="
echo "Querying NotebookLM for technical accuracy..."
echo ""

# Extract procedure content for validation
PROC_CONTENT=$(cat "$PROCEDURE")

# Create a prompt for Claude Code
cat > /tmp/validate-prompt.txt <<EOF
Please validate this OpenShift procedure against the documentation in notebook ${NOTEBOOK_ID}:

Procedure file: $PROCEDURE

Check:
1. Command syntax (oc commands, flags, arguments)
2. API resource fields (YAML correctness)
3. Prerequisites completeness
4. Verification steps present
5. Red Hat documentation standards

Provide a structured validation report.
EOF

echo "Run this in Claude Code:"
echo ""
cat /tmp/validate-prompt.txt

echo ""
echo "============================================"
echo "VALIDATION SUMMARY"
echo "============================================"
if [ $FUNCTIONAL_EXIT -eq 0 ]; then
    echo "✓ Functional validation: PASSED"
else
    echo "✗ Functional validation: FAILED"
fi
echo "  Documentation validation: See Claude Code output"
echo "============================================"
```

Make it executable:
```bash
chmod +x validate-procedure-complete.sh
```

## Usage Examples

### Validate New Procedure

```bash
# Run functional + doc validation
./validate-procedure-complete.sh modules/my-new-procedure.adoc
```

### Query Documentation During Writing

While writing a procedure, ask NotebookLM:

```
Query the OpenShift docs notebook:
"What is the correct syntax for oc exec with namespace flag?"
```

```
Query the OpenShift docs notebook:
"What cgroup path should I use for cpuset.cpus in OpenShift 4.x?"
```

### Validate Specific Command

```
Check if this command is correct according to OpenShift documentation:
oc get performanceprofile performance -o=jsonpath='{.status.runtimeClass}'
```

## Common Validation Queries

Save these for quick reference:

```bash
# Command validation
"Is this oc command syntax correct for OpenShift 4.17: <command>"

# API validation
"Does this PerformanceProfile YAML match the official API schema: <yaml>"

# Prerequisite check
"What prerequisites are needed for per-pod power management in OpenShift?"

# cgroup path
"What is the correct cgroup path for cpuset.cpus in OpenShift 4.x?"

# Best practices
"What are the best practices for writing verification steps in OpenShift procedures?"
```

## Notebook Maintenance

### Add Validated Procedures as References

After validating a procedure successfully:

```
Add this validated procedure as a text source to notebook ${OPENSHIFT_DOCS_NOTEBOOK_ID}:

<paste procedure content>

Title: "Validated: CPU Isolation for Executed Processes"
```

### Update Documentation Sources

When OpenShift docs update:

```
Add this updated URL to notebook ${OPENSHIFT_DOCS_NOTEBOOK_ID}:
https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/...
```

## Benefits

1. **Catch errors early**: Validate before testing on cluster
2. **Learn from docs**: NotebookLM explains why something is correct/incorrect
3. **Consistency**: Ensures procedures match official documentation
4. **Time savings**: Fewer test/fix cycles

## Example Workflow

```
1. Write procedure draft
2. Ask NotebookLM: "Review this procedure for technical accuracy"
3. Fix issues based on NotebookLM feedback
4. Run verify-procedure on live cluster
5. Fix any functional issues
6. Final NotebookLM check
7. Commit to git
```

## Troubleshooting

### "Cookies have expired"
```bash
# Re-authenticate (see ~/notebooklm-mcp/CLAUDE.md)
# Extract fresh cookies from Chrome DevTools
```

### Notebook ID not working
```bash
# List notebooks to find correct ID
echo "List all my NotebookLM notebooks"
```

### Poor quality responses
```
The notebook might need more/better sources. Add more official OpenShift documentation URLs.
```

## Next Steps

1. Create your OpenShift docs notebook (see Quick Start step 1)
2. Save the notebook ID in your bashrc
3. Test a validation query
4. Try validating the CPU isolation procedure you just fixed
5. Add the validated procedure to the notebook as a reference example
