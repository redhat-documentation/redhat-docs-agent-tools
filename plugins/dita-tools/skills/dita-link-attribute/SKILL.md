---
name: dita-link-attribute
description: Informational skill for LinkAttribute Vale warnings. Links with attributes in their targets are not supported in DITA. Use this skill when asked about link attribute issues or preparing files for DITA conversion.
allowed-tools: Read, Glob
---

# Link attribute informational skill

Provide information about link attribute warnings from Vale.

## Overview

This is an informational-only skill. The Vale rule `LinkAttribute.yml` warns about links that include attributes as part of the link target. DITA does not support using attributes as part of a link target.

## AI Action Plan

**When to use this skill**: When Vale reports `LinkAttribute` warnings.

**Group handling**: YES - List all LinkAttribute warnings together under a single heading.

**Steps to follow**:

1. **List all instances** of link attribute warnings in the file together

2. **For each link**, display the attribute name(s) used in the link target

3. **Display this explanation** to the user:

   > DITA does not support using attributes as part of a link target. A link target must either:
   > - Not include any attributes (e.g., `link:https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8[RHEL 8 documentation]`)
   > - Be entirely defined as an attribute (e.g., `:rhel_8_docs: link:https://docs.redhat.com/...[]` used as `{rhel_8_docs}`)
   >
   > Links like `link:{red_hat_docs}/red_hat_enterprise_linux/8[RHEL 8 documentation]` (where `{red_hat_docs}` is part of the URL) are not supported.
   >
   > To resolve this issue, you must either:
   > 1. Replace the link target with the full URL (resolve the attribute manually)
   > 2. Provide the attribute names and values to the conversion team to handle during conversion

4. **Do not suggest specific fixes** - AI cannot resolve this without knowing attribute values

5. **Include attribute names in the explanation** so users know which attributes need attention

## What it detects

The Vale rule detects links with attributes embedded in the target URL:

**Failures (not supported)**:
- `link:{red_hat_docs}/red_hat_enterprise_linux/8[RHEL 8 docs]`
- `link:https://{domain}/path[Link text]`
- `link:{base_url}/api/v1/endpoint[API docs]`

**Correct formats**:
- `link:https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8[RHEL 8 docs]` (full URL)
- `:rhel_8_docs: link:https://docs.redhat.com/...[]` then use `{rhel_8_docs}` (entire link as attribute)

## Why this cannot be auto-fixed

An AI cannot resolve this issue because:
- Attribute values are defined elsewhere in the documentation (header, separate config files)
- The AI does not have access to the attribute definitions in the current context
- The user must decide whether to inline the URL or coordinate with the conversion team

## Example output

When handling LinkAttribute warnings, output should look like:

```
## Link attribute warnings

The following links use attributes in their targets and are not supported for DITA conversion:

- Line 45: `link:{red_hat_docs}/red_hat_enterprise_linux/8[RHEL 8 documentation]`
  - Uses attribute: `{red_hat_docs}`

- Line 102: `link:https://{domain}/api/v1/users[User API]`
  - Uses attribute: `{domain}`

- Line 234: `link:{base_url}/getting-started[Getting started guide]`
  - Uses attribute: `{base_url}`

DITA does not support using attributes as part of a link target. To resolve these issues:

1. Replace the link targets with full URLs (resolving the attributes manually), OR
2. Provide the attribute names and values to the conversion team:
   - `{red_hat_docs}` = ?
   - `{domain}` = ?
   - `{base_url}` = ?
```

## Related Vale rule

This skill addresses the warning from: `.vale/styles/AsciiDocDITA/LinkAttribute.yml`
