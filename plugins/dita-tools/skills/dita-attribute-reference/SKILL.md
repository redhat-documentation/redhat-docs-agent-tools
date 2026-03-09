---
name: dita-attribute-reference
description: Informational skill for AttributeReference Vale messages. Informs users about attribute references in their content that need discussion with conversion team. Use this skill when asked about attribute reference issues.
allowed-tools: Read, Glob
---

# Attribute reference informational skill

Provide information about attribute reference messages from Vale.

## Overview

This is an informational-only skill. The Vale rule `AttributeReference.yml` reports an informational message (not an error or warning) when it detects attribute references like `{attribute}` in the text.

## AI Action Plan

**When to use this skill**: When Vale reports `AttributeReference` messages.

**Group handling**: YES - List all AttributeReference messages together under a single heading.

**Steps to follow**:

1. **List all instances** of attribute references in the file together under a single heading

2. **Display this explanation** to the user:

   > The file contains attribute references (e.g., `{product-name}`, `{version}`, `{platform}`).
   >
   > This is an informational message, not requiring immediate fixes. However, you must discuss with the conversion team which attributes should be:
   > - **Resolved** (changed to normal text) during conversion
   > - **Kept as DITA shared content** (converted to DITA `conref` or `keyref` mechanisms)
   >
   > The conversion team will need to know the attribute names and their values to handle this correctly at conversion time.

3. **Do not suggest fixes** - this requires coordination with the conversion team

## What it detects

The Vale rule detects attribute references in this format:
- `{product-name}`
- `{version}`
- `{platform}`
- `{any-attribute}`

## Why this is informational only

Attribute references are valid AsciiDoc and can be converted to DITA. However, the conversion approach depends on whether the attribute should be resolved to static text or mapped to DITA's conref/keyref system for content reuse.

This decision requires coordination with the conversion team and depends on the broader documentation architecture and reuse strategy.

## Example output

When handling AttributeReference messages, output should look like:

```
## Attribute references (informational)

The following attribute references were found:
- Line 12: {product-name}
- Line 45: {version}
- Line 78: {platform}
- Line 123: {default-namespace}

This is informational only. You should discuss with the conversion team which attributes need to be resolved (changed to normal text) during conversion and which should refer to DITA shared content.

The conversion team will need the names and values of these attributes:
- `{product-name}`
- `{version}`
- `{platform}`
- `{default-namespace}`
```

## Related Vale rule

This skill addresses the informational message from: `.vale/styles/AsciiDocDITA/AttributeReference.yml`
