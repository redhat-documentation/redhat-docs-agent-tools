---
name: dita-nested-section
description: Handle nested sections (level 3+ headings) by flattening structure or splitting modules. Handles both NestedSection and TaskSection Vale issues. Use this skill when asked to fix nested sections or prepare files for DITA conversion.
allowed-tools: Read, Edit, Glob
---

# Nested section handling skill

Fix nested sections (headings of level 3 or deeper) by flattening the structure or splitting into separate modules.

## Overview

DITA limits nesting depth for modules. Modules can have at most level 2 headings (`==`). Procedures cannot have any subheadings at all. Deeper nesting requires splitting the content into separate modules.

## AI Action Plan

**When to use this skill**: When Vale reports `NestedSection` or `TaskSection` issues or when asked to fix nested sections or prepare files for DITA conversion.

**Steps for general modules (NestedSection)**:

1. **Determine if the file is an assembly**:
   - Check for `:_mod-docs-content-type: ASSEMBLY` definition
   - Or check if filename contains "assembly"
   - Or check if file has several `include::` directives with `[leveloffset=...]`

2. **If the file IS an assembly**:
   - Check if `:_mod-docs-content-type: ASSEMBLY` definition is present
   - If not, recommend adding it
   - If there are subsections marked with `===` or deeper in assembly text (not in included modules), recommend either:
     a. Flattening the structure (removing the third-level headings), OR
     b. Splitting the assembly
   - **Do not suggest specific candidate text for splitting** - assemblies require manual review for reorganization

3. **If the file IS NOT an assembly** (it's a module):
   - Break the file into several modules
   - Typically move sections (level 2 headings `==`) into their own modules
   - **Do not add `include` statements** to modules
   - Instead, provide an assembly snippet showing the include directives with correct `leveloffset` settings

4. **When breaking modules**:
   - Ensure every module has the correct content type
   - Ensure every module complies with its template
   - Use `leveloffset` settings to preserve hierarchy:
     ```asciidoc
     include::modules/head_module.adoc[leveloffset=+1]
     include::modules/subsection_module.adoc[leveloffset=+2]
     ```

**Steps for procedures (TaskSection)**:

1. **No subsections or subheadings are allowed in procedures**

2. **Check if subheading is actually a block title**:
   - Look for supported block titles: `.Procedure`, `.Prerequisites`, `.Verification`, `.Result`, etc.
   - Check for typos: `== Proedure` should be `.Procedure`
   - If it's a supported block title, suggest changing to block title format

3. **If it's a real subheading** (not a block title):
   - The subsections must be split into separate modules
   - **Do not add `include` statements** to modules
   - Provide assembly snippet with includes and `leveloffset` settings
   - Subsections of procedures are often (but not always) procedures themselves

## What it detects

**NestedSection.yml**: Detects level 3+ headings (`===` or deeper) in modules or assemblies.

**TaskSection.yml**: Detects ANY subheadings (`==` or deeper) in procedure modules.

## Nested section examples

**Failure (level 3 heading in module)**:
```asciidoc
:_mod-docs-content-type: CONCEPT
[id="about-authentication"]
= About authentication

== Authentication methods

=== OAuth 2.0

OAuth 2.0 is a protocol...

=== SAML

SAML is a standard...
```

**Correct (split into modules)**:

`modules/about-authentication.adoc`:
```asciidoc
:_mod-docs-content-type: CONCEPT
[id="about-authentication_{context}"]
= About authentication

Multiple authentication methods are supported.
```

`modules/oauth-authentication.adoc`:
```asciidoc
:_mod-docs-content-type: CONCEPT
[id="oauth-authentication_{context}"]
= OAuth 2.0 authentication

OAuth 2.0 is a protocol...
```

`modules/saml-authentication.adoc`:
```asciidoc
:_mod-docs-content-type: CONCEPT
[id="saml-authentication_{context}"]
= SAML authentication

SAML is a standard...
```

Assembly snippet:
```asciidoc
include::modules/about-authentication.adoc[leveloffset=+1]
include::modules/oauth-authentication.adoc[leveloffset=+2]
include::modules/saml-authentication.adoc[leveloffset=+2]
```

## Procedure section example

**Failure (subheading in procedure)**:
```asciidoc
:_mod-docs-content-type: PROCEDURE
[id="configuring-auth"]
= Configuring authentication

.Procedure

. Configure the authentication provider.

== Verification

To verify the configuration works:

. Test the login.
. Check the logs.
```

**Correct (change to block title)**:
```asciidoc
:_mod-docs-content-type: PROCEDURE
[id="configuring-auth"]
= Configuring authentication

.Procedure

. Configure the authentication provider.

.Verification

. Test the login.
. Check the logs.
```

**Failure (real subsection in procedure)**:
```asciidoc
:_mod-docs-content-type: PROCEDURE
[id="managing-users"]
= Managing users

.Procedure

. Access the user management interface.

== Adding a user

. Click *Add user*.
. Enter user details.

== Removing a user

. Select the user.
. Click *Remove*.
```

**Correct (split into modules)**:

Split into two separate procedure modules, one for adding users and one for removing users, then include them in an assembly.

## Usage

When the user asks to fix nested sections:

1. Read the affected file(s)
2. Determine if file is assembly, procedure, or general module
3. Locate nested headings (level 3+ for modules, any level for procedures)
4. For procedures: Check if headings should be block titles
5. For modules/assemblies: Recommend splitting or flattening
6. If splitting: Draft the separate modules and assembly snippet
7. Ask user to confirm approach before making changes
8. Use Edit/Write tools to make changes
9. Report the changes made

## Example invocations

- "Fix nested sections in modules/authentication.adoc"
- "Split procedure with subsections into separate modules"
- "Fix NestedSection and TaskSection Vale errors"

## Output format

When analyzing files, report:

```
modules/authentication.adoc: Found level 3 headings

Line 15: === OAuth 2.0
Line 23: === SAML

Recommendation: Split into separate concept modules
- modules/about-authentication.adoc (intro)
- modules/oauth-authentication.adoc
- modules/saml-authentication.adoc

I can draft these modules for you. Should I proceed?
```

## Related Vale rules

This skill addresses errors from:
- `.vale/styles/AsciiDocDITA/NestedSection.yml`
- `.vale/styles/AsciiDocDITA/TaskSection.yml`
