#!/usr/bin/env python3
"""Check for hardcoded product names in AsciiDoc documentation.

Searches active content for hardcoded product names that should use
AsciiDoc attributes instead. Handles known exceptions (UI labels,
plugin names, link text, code blocks, attribute definitions).

CQA parameters: P18, O1, O3
Skill: cqa-legal-branding

Usage:
    python3 check-product-names.py <DOCS_DIR>

Exit codes:
    0 - No violations found
    1 - Violations found
    2 - Invalid arguments (e.g., docs_dir is not a directory)
"""

import argparse
import os
import re
import sys

# Product names to search for, ordered longest-first to avoid double-counting.
# Each tuple: (hardcoded_string, recommended_attribute)
PRODUCT_NAMES = [
    ("Red Hat OpenShift Dev Spaces", "{prod}"),
    ("OpenShift Container Platform", "{ocp}"),
    ("OpenShift Dev Spaces", "{prod-short}"),
    ("Dev Spaces", "{prod-short} or {prod2}"),
]

# Separate capitalization check
CASE_TYPO = ("Openshift", "OpenShift")

# Known legitimate hardcoded uses — exact substrings that are exceptions.
# UI button labels, plugin names, extension names.
KNOWN_EXCEPTIONS = [
    "Connect to Dev Spaces",
    "Gateway provider for OpenShift Dev Spaces",
    "OpenShift Dev Spaces plugin",
    "OpenShift Dev Spaces extension",
]

# Directories to scan (relative to DOCS_DIR)
SCAN_DIRS = ["assemblies", "topics", "snippets"]

# Directories to skip entirely
SKIP_DIRS = {"legacy-content-do-not-use"}

# Files to skip (basename)
SKIP_FILES = {"attributes.adoc"}


def collect_adoc_files(docs_dir):
    """Collect all .adoc files from scan directories, skipping exclusions."""
    files = []
    for scan_dir in SCAN_DIRS:
        full_dir = os.path.join(docs_dir, scan_dir)
        if not os.path.isdir(full_dir):
            continue
        for root, dirs, filenames in os.walk(full_dir):
            # Skip excluded directories
            dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
            for fname in filenames:
                if fname.endswith(".adoc") and fname not in SKIP_FILES:
                    filepath = os.path.join(root, fname)
                    rel_path = os.path.relpath(filepath, docs_dir)
                    files.append((filepath, rel_path))
    return sorted(files, key=lambda x: x[1])


def parse_code_block_lines(lines):
    """Return a set of line indices inside code, literal, passthrough, or comment blocks.

    Tracks a single block state so that delimiters nested inside another
    block type are treated as content rather than toggling a second block.
    Handles: ---- (source), .... (literal), ++++ (passthrough), //// (comment).
    """
    code_lines = set()
    current_block = None  # None, "-", ".", "+", "/"

    for i, line in enumerate(lines):
        stripped = line.strip()
        # Detect block delimiters: ---- .... ++++ ////
        matched_char = None
        for delim_char in ("-", ".", "+", "/"):
            prefix = delim_char * 4
            if (stripped.startswith(prefix) and len(stripped) >= 4
                    and all(c == delim_char for c in stripped)):
                matched_char = delim_char
                break

        if matched_char is not None and current_block in (None, matched_char):
            code_lines.add(i)
            current_block = None if current_block == matched_char else matched_char
            continue

        if current_block is not None:
            code_lines.add(i)
    return code_lines


def find_product_names(line):
    """Find all hardcoded product names in a line, avoiding double-counting.

    Returns list of (position, matched_text, replacement) tuples.
    Processes patterns longest-first so shorter patterns don't match
    substrings already claimed by longer patterns.
    """
    matches = []
    consumed = set()

    for name, replacement in PRODUCT_NAMES:
        start = 0
        while True:
            idx = line.find(name, start)
            if idx == -1:
                break
            match_range = set(range(idx, idx + len(name)))
            if not match_range.intersection(consumed):
                matches.append((idx, name, replacement))
                consumed.update(match_range)
            start = idx + 1

    # Separate check for "Openshift" (lowercase S) typo
    start = 0
    while True:
        idx = line.find(CASE_TYPO[0], start)
        if idx == -1:
            break
        match_range = set(range(idx, idx + len(CASE_TYPO[0])))
        if not match_range.intersection(consumed):
            matches.append((idx, CASE_TYPO[0], CASE_TYPO[1]))
            consumed.update(match_range)
        start = idx + 1

    return sorted(matches, key=lambda x: x[0])


def is_inside_pattern(line, match_start, match_end, regex):
    """Check if position range falls inside a regex capture group."""
    for m in re.finditer(regex, line):
        bracket_start = m.start(1)
        bracket_end = m.end(1)
        if match_start >= bracket_start and match_end <= bracket_end:
            return True
    return False


def classify_match(line, match_start, matched_text):
    """Classify a match as a violation or an exception.

    Returns one of:
        COMMENT        - inside an AsciiDoc comment
        ATTRIBUTE_DEF  - attribute definition line
        KNOWN_EXCEPTION - matches a known UI label/plugin name
        UI_LABEL       - inside backtick delimiters
        LINK_TEXT      - inside link:...[text] brackets
        XREF_TEXT      - inside xref:...[text] brackets
        IMAGE_ALT      - inside image::[alt] brackets (should use attributes)
        PROSE          - body text (violation)
    """
    stripped = line.strip()
    match_end = match_start + len(matched_text)

    # Comment line
    if stripped.startswith("//"):
        return "COMMENT"

    # Attribute definition (e.g., :prod-short: OpenShift Dev Spaces)
    if re.match(r"^:\w[\w-]*:", stripped):
        return "ATTRIBUTE_DEF"

    # Known exception (UI label, plugin name)
    for exc in KNOWN_EXCEPTIONS:
        # Check if the matched text is part of a known exception on this line
        exc_idx = line.find(exc)
        if exc_idx != -1:
            exc_range = range(exc_idx, exc_idx + len(exc))
            if match_start >= exc_idx and match_end <= exc_idx + len(exc):
                return "KNOWN_EXCEPTION"

    # Inside backticks (UI label or command)
    # Find all backtick-delimited regions
    in_backtick = False
    backtick_start = -1
    for i, ch in enumerate(line):
        if ch == "`":
            if in_backtick:
                # Closing backtick — check if match falls within
                if match_start > backtick_start and match_end <= i:
                    return "UI_LABEL"
                in_backtick = False
            else:
                in_backtick = True
                backtick_start = i

    # Inside link text: link:URL[text]
    if is_inside_pattern(line, match_start, match_end, r"link:[^\[]*\[([^\]]*)\]"):
        return "LINK_TEXT"

    # Inside xref text: xref:id[text]
    if is_inside_pattern(line, match_start, match_end, r"xref:[^\[]*\[([^\]]*)\]"):
        return "XREF_TEXT"

    # Inside image alt text: image::path[alt text]
    if is_inside_pattern(line, match_start, match_end, r"image::[^\[]*\[([^\]]*)\]"):
        return "IMAGE_ALT"

    # Everything else is prose
    return "PROSE"


def check_file(filepath, rel_path):
    """Check a single file for hardcoded product names.

    Returns a list of finding dicts.
    """
    findings = []
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()
    except (UnicodeDecodeError, IOError):
        return findings

    lines = content.splitlines()
    code_lines = parse_code_block_lines(lines)

    for line_idx, line in enumerate(lines):
        if line_idx in code_lines:
            continue

        matches = find_product_names(line)
        for pos, matched_text, replacement in matches:
            classification = classify_match(line, pos, matched_text)
            findings.append({
                "file": rel_path,
                "line_num": line_idx + 1,
                "line": line.rstrip(),
                "match": matched_text,
                "replacement": replacement,
                "classification": classification,
            })

    return findings


def main():
    parser = argparse.ArgumentParser(
        description="Check for hardcoded product names in AsciiDoc docs."
    )
    parser.add_argument(
        "docs_dir",
        help="Path to the documentation repository root",
    )
    args = parser.parse_args()

    docs_dir = os.path.abspath(args.docs_dir)
    if not os.path.isdir(docs_dir):
        print(f"Error: {docs_dir} is not a directory", file=sys.stderr)
        sys.exit(2)

    print("Product Name Check")
    print("=" * 60)
    print(f"Scanning: {docs_dir}")
    print(f"Directories: {', '.join(SCAN_DIRS)}")
    print(f"Excluding: {', '.join(SKIP_DIRS)}, {', '.join(SKIP_FILES)}")
    print()

    files = collect_adoc_files(docs_dir)
    all_findings = []
    for filepath, rel_path in files:
        all_findings.extend(check_file(filepath, rel_path))

    # Group by classification
    violations = [f for f in all_findings if f["classification"] == "PROSE"]
    image_alt = [f for f in all_findings if f["classification"] == "IMAGE_ALT"]
    exceptions = [f for f in all_findings if f["classification"] in (
        "KNOWN_EXCEPTION", "UI_LABEL", "LINK_TEXT", "XREF_TEXT"
    )]
    skipped = [f for f in all_findings if f["classification"] in (
        "COMMENT", "ATTRIBUTE_DEF"
    )]

    # Report violations
    print("VIOLATIONS (hardcoded product names in prose):")
    if violations:
        for f in violations:
            print(f"  {f['file']}:{f['line_num']}")
            print(f"    Found: \"{f['match']}\" -> use {f['replacement']}")
            print(f"    Line:  {f['line']}")
            print()
    else:
        print("  (none)")
    print()

    # Report image alt text issues
    print("IMAGE ALT TEXT (should use attributes):")
    if image_alt:
        for f in image_alt:
            print(f"  {f['file']}:{f['line_num']}")
            print(f"    Found: \"{f['match']}\" -> use {f['replacement']}")
            print(f"    Line:  {f['line']}")
            print()
    else:
        print("  (none)")
    print()

    # Report exceptions (informational)
    print("EXCEPTIONS (automatically excluded — no action needed):")
    if exceptions:
        for f in exceptions:
            print(f"  {f['file']}:{f['line_num']}  [{f['classification']}]")
            print(f"    \"{f['match']}\" in: {f['line'].strip()}")
        print()
    else:
        print("  (none)")
        print()

    # Summary
    total_issues = len(violations) + len(image_alt)
    print("-" * 60)
    print(f"Summary: {len(violations)} violations, "
          f"{len(image_alt)} image alt text issues, "
          f"{len(exceptions)} exceptions, "
          f"{len(skipped)} skipped (comments/attributes)")
    print(f"Files scanned: {len(files)}")

    if total_issues > 0:
        print(f"\nResult: FAIL ({total_issues} issues found)")
        sys.exit(1)
    else:
        print("\nResult: PASS")
        sys.exit(0)


if __name__ == "__main__":
    main()
