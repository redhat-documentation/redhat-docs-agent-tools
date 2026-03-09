---
name: docs-review-rhoai
description: Review AsciiDoc files for Red Hat OpenShift AI documentation conventions and repository-specific patterns. Use this skill for peer reviews of the openshift-ai-documentation repository.
model: claude-opus-4-5@20251101
---

# Red Hat OpenShift AI documentation review skill

Review documentation for RHOAI-specific conventions, docs team standards, and repository patterns that go beyond standard style guides.

**Target repositories** (this skill is automatically applied when reviewing these repos):

| Repository | Platform | Type |
|------------|----------|------|
| `documentation-red-hat-openshift-data-science-documentation/openshift-ai-documentation` | GitLab CEE | Downstream |
| `documentation-red-hat-openshift-data-science-documentation/vllm-documentation` | GitLab CEE | Downstream |
| `documentation-red-hat-openshift-data-science-documentation/rhel-ai` | GitLab CEE | Downstream |
| `opendatahub-io/opendatahub-documentation` | GitHub | Upstream |

---

## Module structure requirements

### Module heading levels

**Critical**: Module titles must use single `=`, not `==`.

**Wrong**:
```asciidoc
== Configuring the feature
```

**Correct**:
```asciidoc
= Configuring the feature
```

Using `==` causes the module to render one level too deep when included in an assembly.

### Abstract requirements

1. **Nothing between title and abstract** - All introductory text must be inside `[role="_abstract"]`
2. **Abstracts must be plain prose** - Not list blocks or bullet points
3. **Add 1-2 sentences** explaining what the module does and when to use it

**Wrong**:
```asciidoc
= Configuring the feature

Some introductory text here.

[role="_abstract"]
* First point
* Second point
```

**Correct**:
```asciidoc
= Configuring the feature

[role="_abstract"]
Configure the Ray compute engine in Feature Store by defining Ray-specific settings in the `feature_store.yaml` file. This enables distributed execution of feature pipelines for materialization and historical feature retrieval.
```

### Context cleanup in assemblies

When setting `:parent-context:`, always restore it at the end:

```asciidoc
ifdef::context[:parent-context: {context}]
:context: featurestore

// ... assembly content ...

ifdef::parent-context[:context: {parent-context}]
ifndef::parent-context[:!context:]
```

Missing context cleanup causes context bleed into subsequent assemblies.

---

## Product naming and attributes

### Required attributes

Use AsciiDoc attributes for product names - never hardcode product names.

| Attribute | Purpose | Example output |
|-----------|---------|----------------|
| `{productname-long}` | Full product name | Red Hat OpenShift AI |
| `{productname-short}` | Short product name | OpenShift AI |
| `{org-name}` | Organization name | Red Hat |

**Wrong**:
```asciidoc
OpenShift AI provides machine learning capabilities.
RHOAI supports distributed workloads.
```

**Correct**:
```asciidoc
{productname-short} provides machine learning capabilities.
{productname-long} supports distributed workloads.
```

### Product name checklist

- [ ] `{productname-short}` used instead of "OpenShift AI" or "RHOAI"
- [ ] `{productname-long}` used for first mention or formal contexts
- [ ] `{org-name}` used instead of "Red Hat"
- [ ] "Operator" is capitalized (per Red Hat Supplementary Style Guide)
- [ ] "Llama Stack" is two words, not "LlamaStack"

---

## Terminology conventions

### Acronym expansion

**Always expand acronyms on first mention**:

| Correct | Incorrect |
|---------|-----------|
| Model Context Protocol (MCP) | MCP (first mention without expansion) |
| time to live (TTL) | time to leave (TTL) - **common error** |
| Directed Acyclic Graph (DAG) | Directed Acyclic Graphs (DAG) - use singular |

### gen AI terminology

Follow IBM Style Guide for generative AI terminology:

| Correct | Incorrect |
|---------|-----------|
| gen AI | GenAI, GENAI, genai, genAI |
| generative AI (gen AI) | First occurrence should spell out |
| Gen AI | Only at start of sentence |

### Allowed AI/ML terminology

The following terms are allowed jargon in Red Hat AI documentation:

| Term | Usage |
|------|-------|
| inferencing | The process of running inference workloads on deployed models |
| inference serving | Serving models for inference requests |

These terms are standard in the AI/ML industry and do not need to be replaced with alternative phrasing.

### Kubernetes terminology

Use proper capitalization for Kubernetes objects:

| Correct | Incorrect |
|---------|-----------|
| ConfigMap | config map, configmap |
| Deployment | deployment (when referring to the resource type) |
| InferenceService | Inference Service, inference service |

### Acronyms to avoid

| Avoid | Use instead |
|-------|-------------|
| OCP | OpenShift, OpenShift Container Platform |
| RHOAI | `{productname-short}` |

### Technical terms requiring backticks

Use backticks for:
- API versions: `v1alpha1`, `v1beta1`
- Kubernetes objects: `ClusterRole`, `ClusterQueue`, `LocalQueue`, `InferenceService`
- Configuration fields: `rawDeploymentServiceConfig`, `managementState`
- Error messages: `CrashLoopBackOff`, `VolumeModificationRateExceeded`
- Commands and CLI output
- File paths: `/opt/app-root/template/`

### Non-standard characters

Avoid non-standard characters that may not render correctly:

| Avoid | Use instead |
|-------|-------------|
| • (Unicode bullet) | `*` for AsciiDoc lists |
| → (arrow) | `->` or write out |
| ← | `<-` or write out |
| Smart quotes | Standard quotes |

---

## Procedure formatting

### Numbered vs bulleted steps

**Procedure steps must be numbered (`.`), not bulleted (`*`)**:

**Wrong**:
```asciidoc
.Procedure
* Configure the setting in your file.
* Save the file.
```

**Correct**:
```asciidoc
.Procedure
. Configure the setting in your file.
. Save the file.
```

### Step formatting with code blocks

Use `+` for list continuation after numbered steps:

**Wrong**:
```asciidoc
. Apply the template.
Run the following command:
----
feast init -t ray my_project
----
```

**Correct**:
```asciidoc
. Apply the template.
+
Run the following command:
+
[source,terminal]
----
feast init -t ray my_project
----
```

### Code block source annotations

Use proper source annotations for code blocks:

| Content type | Annotation |
|--------------|------------|
| Terminal/shell commands | `[source,terminal]` |
| Bash scripts | `[source,bash]` |
| Python code | `[source,python]` |
| YAML configuration | `[source,yaml]` |
| JSON | `[source,json]` |

---

## Link formatting

### Downstream links

Use attributes for downstream documentation links:

```asciidoc
link:{rhoaidocshome}{default-format-url}/guide_name/section#anchor_context[Link text]
```

### Upstream links

Upstream links use **hyphens** in path segments:

```asciidoc
link:{odhdocshome}/deploying-models/#section-name_odh-user[Link text]
```

**Note**: Downstream uses underscores (`deploying_models`), upstream uses hyphens (`deploying-models`).

### Cross-references

Use `xref:` for internal cross-references:

**Wrong**:
```asciidoc
NOTE: For more information, see Ray compute engine usage examples.
```

**Correct**:
```asciidoc
NOTE: For more information, see xref:reference-ray-usage-examples-feature-store_{context}[Ray compute engine usage examples].
```

### Link checklist

- [ ] Downstream links use `{rhoaidocshome}{default-format-url}` attributes
- [ ] Upstream links use `{odhdocshome}` with hyphens in paths
- [ ] Link text is descriptive (not "click here")
- [ ] External links use `^` suffix for new tab
- [ ] Links tested in preview build
- [ ] Cross-references use `xref:` syntax

---

## AsciiDoc formatting

### Code blocks for terminal output

Wrap error messages and terminal output in code blocks:

```asciidoc
When resizing a PVC backed by AWS EBS, you might see the following error message:

[source,terminal]
----
VolumeModificationRateExceeded: You've reached the maximum modification rate per volume limit.
----
```

### Tables and lists

**Bulleted lists don't render correctly inside table cells unless you set an `a` cell operator**.
Incorporate list items into a flowing sentence, or apply `a` cell operator:

**Wrong**:
```asciidoc
|Description
|The following apply:
* Item one
* Item two
```

**Correct**:
```asciidoc
|Description
|You must verify that you have the correct access, that your token is valid, and that you have permission to view the resource.
```

**Correct**:
```asciidoc
|Description
a|The following apply:

* Item one
* Item two
``` 

### Admonition indentation

Ensure notes inside procedures are properly indented:

```asciidoc
. Complete the first step.
+
[NOTE]
====
This note is part of step 1.
====

. Complete the second step.
```

### Ventilated prose

Use one sentence per line for easier diff reviews:

**Wrong**:
```asciidoc
This is a paragraph with multiple sentences. It continues on the same line. This makes diffs harder to read.
```

**Correct**:
```asciidoc
This is a paragraph with multiple sentences.
It continues on a new line.
This makes diffs easier to read.
```

### Bullet punctuation

Red Hat style allows no trailing punctuation for list fragments. Be consistent throughout a document.

---

## Style conventions

### Avoid subjective language

| Avoid | Use instead |
|-------|-------------|
| "easily" | Remove or be specific |
| "simply" | Remove or be specific |
| "just" | Remove or be specific |

**Wrong**:
```asciidoc
You can easily configure the setting.
```

**Correct**:
```asciidoc
You can configure the setting.
```

### Avoid self-referential text

| Avoid | Use instead |
|-------|-------------|
| "This document describes..." | Direct statement of content |
| "This module explains..." | Rewrite as abstract |

**Wrong**:
```asciidoc
This document describes how to configure Feature Store.
```

**Correct**:
```asciidoc
Understand how the system mounts configuration files so that you can create and use features in your code.
```

### Avoid repetitive phrasing

| Avoid | Use instead |
|-------|-------------|
| "This enables..." (repeated) | Direct description |
| "This allows..." (repeated) | Direct description |

**Wrong**:
```asciidoc
|`max_workers`
|This enables the maximum number of Ray workers to use.
```

**Correct**:
```asciidoc
|`max_workers`
|Maximum number of Ray workers to use. If not set, all available cores are used.
```

### IBM Style Guide patterns

| Avoid | Use instead | Reason |
|-------|-------------|--------|
| "lets you" | "you can" | Avoid inanimate objects granting abilities |
| "allows you to" | "you can" | Same as above |
| "in order to" | "to" | Conciseness |

### Sentence case for headings

Use sentence case, not title case:

| Wrong | Correct |
|-------|---------|
| `= Configuring The Database Connection` | `= Configuring the database connection` |
| `= Installing The Operator` | `= Installing the Operator` |

### Article usage with proper nouns

Use "the" before product/feature names when grammatically appropriate:

**Wrong**:
```asciidoc
Configure MCP servers to test models.
```

**Correct**:
```asciidoc
Configure the Model Context Protocol (MCP) servers to test models.
```

---

## Known issues and release notes

### JIRA reference format

Known issues should include JIRA links:

```asciidoc
*https://issues.redhat.com/browse/RHOAIENG-XXXXX[RHOAIENG-XXXXX^] - Brief issue description*

Detailed description of the known issue. When you attempt to perform action X, the operation fails with error Y.

*Workaround*: Description of the workaround steps.
```

### Issue description patterns

- Start with "When you attempt to..." or "After upgrading to..."
- Include the error message in backticks or code block
- End with "This issue is now resolved." for resolved issues

### Deprecation and removal notices

Standard format for deprecation notices:

```asciidoc
Starting with {productname-short} 2.24, the *Feature Name* is deprecated and will be removed in a future release of {productname-short}.
```

---

## Common review patterns

Based on docs team peer review conventions, watch for:

### High-frequency issues

1. **Wrong heading level** - Modules use `=`, not `==`
2. **Missing or malformed abstract** - Must be prose, not lists
3. **Hardcoded product names** - Use attributes instead
4. **Missing list continuation** - Add `+` between step and code block
5. **Wrong heading case** - Use sentence case
6. **Missing `{context}` in anchor IDs** - All modules need `_{context}`
7. **TTL expansion error** - "Time to live", not "Time to leave"
8. **Bulleted procedure steps** - Use numbered steps (`.`)
9. **Unicode bullets** - Use `*` for AsciiDoc lists
10. **Missing acronym expansion** - Expand on first mention

### File-specific patterns

| File type | Common issues |
|-----------|---------------|
| `known-issues.adoc` | Missing JIRA ID, wrong error format |
| `requirements-*.adoc` | Broken downstream links |
| `technology-preview-*.adoc` | Missing version information |
| `modules/*.adoc` | Wrong heading level, missing abstract |
| `assemblies/*.adoc` | Missing context cleanup |

---

## How to use

1. Check module heading level (`=` not `==`)
2. Verify abstract format (prose, not lists)
3. Check product naming uses attributes
4. Verify link formatting with correct path conventions
5. Review procedure step formatting (numbered, not bulleted)
6. Check code block source annotations
7. Verify acronym expansion on first mention
8. Mark issues as **required** or **[SUGGESTION]**

## Example invocations

- "Review this file for RHOAI documentation conventions"
- "Check if this MR follows RHOAI docs team conventions"
- "Do an RHOAI review on the known-issues.adoc file"
- "Verify downstream links in the requirements module"

## Integrates with

- **Vale skill**: Run `vale <file>` for automated style linting
- **docs-review-style**: General style review
- **docs-review-modular-docs**: Module structure review

## References

- Red Hat OpenShift AI documentation repository
- Open Data Hub documentation repository
- IBM Style Guide (word usage, gen AI terminology)
- Red Hat Supplementary Style Guide: https://redhat-documentation.github.io/supplementary-style-guide
- Red Hat Modular Documentation Guide: https://redhat-documentation.github.io/modular-docs/
