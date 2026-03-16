#!/usr/bin/env python3
"""tech_references.py — Extract, search, triage, scan, and review technical references.

Consolidates extract_tech_references.rb and search_tech_references.rb into a single
Python script with two new deterministic phases (triage, scan) and a chained review mode.

Subcommands:
    extract   Extract tech references from AsciiDoc/Markdown files
    search    Search code repositories for evidence matching extracted references
    triage    Deterministic triage of search results (scope, validation, evidence)
    scan      Anti-pattern and blast-radius scan across a doc tree
    review    Chain all four phases in a single invocation

Uses only Python 3 standard library (no pip dependencies).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Any


# =============================================================================
# Constants
# =============================================================================

SKIP_FUNCTIONS = {
    # Control flow / keywords
    "if", "for", "while", "else", "case", "break", "next", "return",
    "do", "end", "nil", "true", "false", "var", "let", "const", "def",
    # Python builtins
    "print", "len", "map", "set", "get", "new", "int", "str", "list",
    "dict", "type", "test", "eval", "puts", "echo",
    "range", "open", "sorted", "format", "input", "super", "isinstance",
    "enumerate", "zip", "any", "all", "min", "max", "sum", "abs", "round",
    "hasattr", "getattr", "setattr", "delattr", "repr", "hash", "iter",
    "next", "reversed", "filter", "bool", "bytes", "float", "complex",
    "tuple", "frozenset", "object", "property", "staticmethod",
    "classmethod", "callable", "vars", "dir", "help", "id", "hex", "oct",
    "bin", "ord", "chr", "ascii", "exec", "compile", "globals", "locals",
    "breakpoint", "memoryview", "bytearray", "slice", "issubclass",
    # Python common stdlib
    "join", "split", "strip", "replace", "append", "extend", "insert",
    "remove", "pop", "keys", "values", "items", "update", "copy",
    "startswith", "endswith", "find", "index", "count", "lower", "upper",
    "encode", "decode", "read", "write", "close", "seek", "tell",
    "flush", "readline", "readlines", "writelines",
    # JavaScript / TypeScript builtins
    "require", "module", "exports", "console", "log", "warn", "error",
    "setTimeout", "setInterval", "clearTimeout", "clearInterval",
    "parseInt", "parseFloat", "isNaN", "isFinite", "encodeURI",
    "decodeURI", "JSON", "Array", "Object", "String", "Number",
    "Boolean", "Date", "RegExp", "Error", "Map", "Set", "Promise",
    "Symbol", "Math", "undefined", "null", "NaN", "Infinity",
    "push", "forEach", "filter", "reduce", "concat", "slice", "splice",
    "indexOf", "includes", "toString", "valueOf", "then", "catch",
    "resolve", "reject", "async", "await",
    # Go builtins
    "make", "cap", "copy", "delete", "panic", "recover",
    "close", "func", "defer", "select", "chan", "goroutine",
    "Println", "Printf", "Sprintf", "Fprintf", "Errorf",
    # Rust builtins
    "println", "eprintln", "format", "vec", "Some", "None", "Ok", "Err",
    "unwrap", "expect", "clone", "into", "from", "impl", "self", "Self",
    "Box", "Rc", "Arc", "Vec", "HashMap", "HashSet", "Option", "Result",
    # C / system
    "malloc", "calloc", "realloc", "free", "sizeof", "printf", "fprintf",
    "sprintf", "scanf", "strlen", "strcmp", "strcpy", "strcat", "memcpy",
    "memset", "assert", "exit", "abort",
    # Generic / cross-language
    "main", "init", "run", "start", "stop", "handle", "process",
    "create", "destroy", "begin", "commit", "rollback",
    "not", "and", "or", "xor", "mod", "div", "shl", "shr",
}

EXTERNAL_COMMANDS = {
    "sudo", "su", "dnf", "yum", "rpm", "apt", "dpkg", "pip", "pip3",
    "npm", "yarn", "gem", "bundle", "cargo",
    "systemctl", "journalctl", "firewall-cmd", "nmcli", "ip", "ss",
    "curl", "wget", "scp", "ssh", "rsync",
    "cat", "head", "tail", "grep", "sed", "awk", "find", "xargs",
    "sort", "uniq", "wc", "tee", "tr", "cut",
    "cp", "mv", "rm", "mkdir", "chmod", "chown", "ln",
    "tar", "gzip", "gunzip", "zip", "unzip",
    "git", "svn", "docker", "podman", "buildah", "skopeo",
    "oc", "kubectl", "helm", "kustomize",
    "ansible", "ansible-playbook", "ansible-galaxy",
    "make", "cmake", "gcc", "g++", "javac", "python", "python3",
    "ruby", "node", "go", "rustc",
    "cd", "ls", "echo", "printf", "export", "source", "test", "set",
    "unset", "read",
    "openssl", "keytool", "certbot",
    "mount", "umount", "fdisk", "parted", "lsblk", "blkid",
    "useradd", "usermod", "groupadd", "passwd", "chpasswd",
    "crontab", "at",
    "vi", "vim", "nano", "emacs",
    "man", "info", "help",
    "less", "more", "pg",
    "ps", "kill", "top", "htop",
    "nc", "nmap", "tcpdump",
    "date", "cal", "uptime", "hostname", "uname", "whoami", "id",
    "env", "printenv",
    "true", "false", "exit",
    "subscription-manager", "yum-config-manager", "dnf5",
    "virsh", "virt-install", "qemu-img", "qemu-system-x86_64",
    "ssh-keygen", "ssh-copy-id", "ssh-add",
    "jq", "yq", "xmllint",
    "base64", "sha256sum", "md5sum",
    "diff", "patch",
    "systemd-analyze", "loginctl", "timedatectl", "localectl",
    "hostnamectl",
}

DEFINITION_PATTERNS: dict[str, list[str]] = {
    "function": [
        r"\bdef\s+{name}\b",
        r"\bfunc\s+{name}\b",
        r"\bfunction\s+{name}\b",
        r"\b{name}\s*=\s*(?:function|=>|\()",
        r"\b(?:async\s+)?(?:def|fn)\s+{name}\b",
    ],
    "class": [
        r"\bclass\s+{name}\b",
        r"\binterface\s+{name}\b",
        r"\bstruct\s+{name}\b",
        r"\btype\s+{name}\b",
        r"\benum\s+{name}\b",
    ],
}

# Languages where function/class extraction is meaningful.
# For terminal/text/console blocks, we only extract commands, not identifiers.
CODE_LANGUAGES = {
    "python", "py", "ruby", "rb", "go", "golang", "rust", "rs",
    "java", "kotlin", "scala", "groovy",
    "javascript", "js", "typescript", "ts", "jsx", "tsx",
    "c", "cpp", "c++", "csharp", "cs",
    "swift", "objc", "objective-c",
    "php", "perl", "lua", "elixir", "erlang", "haskell",
    "r", "julia", "dart", "zig",
}

# Uppercase words that are NOT environment variables — avoids false positives
# from headings, acronyms, AsciiDoc keywords, etc.
NOT_ENV_VARS = {
    # Common English / doc words
    "NOTE", "TIP", "WARNING", "IMPORTANT", "CAUTION",
    "TODO", "FIXME", "HACK", "XXX", "BUG",
    "TRUE", "FALSE", "NULL", "NONE", "YES", "NO", "ON", "OFF",
    "GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS",
    "HTTP", "HTTPS", "TCP", "UDP", "DNS", "SSH", "SSL", "TLS", "API",
    "URL", "URI", "HTML", "XML", "JSON", "YAML", "TOML", "CSV",
    "CPU", "GPU", "RAM", "ROM", "SSD", "HDD", "NFS", "NIC",
    "RHEL", "OCP", "ROSA", "ARO", "EKS", "GKE", "AKS",
    "IBM", "AWS", "GCP", "CLI", "GUI", "IDE", "SDK",
    "RPM", "DEB", "OCI", "CNI", "CSI", "CRI",
    "PVC", "PV", "LVM", "RAID", "VLAN", "CIDR", "NAT",
    "CRD", "CR", "RBAC", "LDAP", "SSO", "SAML", "OIDC",
    "EOF", "HEREDOC",
    "PROCEDURE", "CONCEPT", "REFERENCE", "ASSEMBLY", "SNIPPET",
    "HIGH", "MEDIUM", "LOW",
    "RED", "HAT",
    "THE", "AND", "FOR", "NOT", "WITH", "THIS", "THAT",
    "ALL", "ANY", "USE", "SET", "RUN", "ADD",
}

CONFIG_EXTENSIONS = [".yaml", ".yml", ".json", ".toml", ".conf", ".cfg", ".ini", ".properties"]

SKIP_DIRS = [".git", "node_modules", "vendor", "__pycache__", ".tox", ".eggs", "dist", "build"]

# Compiled regex patterns for the extractor
PATTERNS = {
    "source_block": re.compile(r"^\[source(?:,\s*([a-z0-9+\-_]+))?(?:,\s*(.+))?\]\s*$", re.IGNORECASE),
    "code_fence_lang": re.compile(r"^```\s*([a-z0-9+\-_]+)?\s*$", re.IGNORECASE),
    "code_delim": re.compile(r"^-{4,}\s*$"),
    "literal_delim": re.compile(r"^\.{4,}\s*$"),
    "listing_block": re.compile(r"^\[listing\]\s*$", re.IGNORECASE),
    "heading": re.compile(r"^(=+)\s+(.+)$"),
    "md_heading": re.compile(r"^(#{1,6})\s+(.+)$"),
    "block_title": re.compile(r"^\.([A-Za-z][^\n]*?)\s*$"),
    "procedure_step": re.compile(r"^\.\s+(.+)$"),
    "command_line": re.compile(r"^\$\s+(.+)$"),
    "command_line_code": re.compile(r"^[\$#]\s+(.+)$"),
    # File paths: require a / or a known file extension (not just any dot)
    "inline_code_path": re.compile(
        r"`("
        # Path with at least one slash: path/to/file.ext
        r"[a-zA-Z0-9_\-.]+/[a-zA-Z0-9_\-./]+"
        r"|"
        # Or filename with known doc/config/code extension (no slash required)
        r"[a-zA-Z0-9_\-]+\.(?:adoc|md|yaml|yml|json|toml|xml|conf|cfg|ini|properties"
        r"|py|rb|go|rs|java|js|ts|jsx|tsx|c|cpp|h|hpp|sh|bash|zsh|service|socket|timer"
        r"|repo|spec|rules|pem|crt|key|cert|csr|jks|p12)"
        r")`"
    ),
    "function_call": re.compile(r"\b([a-zA-Z_][a-zA-Z0-9_]*)\s*\("),
    "class_def": re.compile(r"\b(?:class|interface|struct)\s+([A-Z][a-zA-Z0-9_]*)"),
    # API endpoints: require HTTP method prefix
    "api_endpoint": re.compile(r"(?:GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)\s+(/[a-z0-9/_\-{}.:]+)"),
    # Environment variables: $VAR or ${VAR} patterns
    "env_var_dollar": re.compile(r"\$\{?([A-Z][A-Z0-9_]{2,})\}?"),
    # Bare env var in prose: "Set the KUBECONFIG variable" — only in specific contexts
    "env_var_bare": re.compile(r"\b([A-Z][A-Z0-9_]{2,})\b"),
    "empty_line": re.compile(r"^\s*$"),
    "comment_line": re.compile(r"^//($|[^/].*)$"),
    "comment_block": re.compile(r"^/{4,}\s*$"),
}


# =============================================================================
# TechReferenceExtractor  (ports extract_tech_references.rb)
# =============================================================================

class TechReferenceExtractor:
    """Extracts technical references from AsciiDoc/Markdown files."""

    def __init__(self, *, verbose: bool = False) -> None:
        self.verbose = verbose
        self.references: dict[str, list[dict[str, Any]]] = {
            "commands": [],
            "code_blocks": [],
            "apis": [],
            "configs": [],
            "file_paths": [],
            "env_vars": [],
        }

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def extract_from_file(self, file_path: str) -> dict[str, list]:
        path = Path(file_path)
        if not path.exists():
            print(f"ERROR: File not found: {file_path}", file=sys.stderr)
            return self.references

        content = path.read_text(encoding="utf-8", errors="replace")
        lines = [l.rstrip("\n\r") for l in content.splitlines()]
        self._extract_references(file_path, lines)
        return self.references

    def extract_from_files(self, file_paths: list[str]) -> dict[str, list]:
        for fpath in file_paths:
            p = Path(fpath)
            if p.is_dir():
                for child in sorted(p.rglob("*")):
                    if child.suffix in (".adoc", ".md") and child.is_file():
                        self.extract_from_file(str(child))
            else:
                self.extract_from_file(fpath)
        return self.references

    def build_output(self) -> dict:
        refs = self.references
        return {
            "summary": {
                "commands": len(refs["commands"]),
                "code_blocks": len(refs["code_blocks"]),
                "apis": len(refs["apis"]),
                "configs": len(refs["configs"]),
                "file_paths": len(refs["file_paths"]),
                "env_vars": len(refs["env_vars"]),
            },
            "references": refs,
        }

    # ------------------------------------------------------------------
    # Internal
    # ------------------------------------------------------------------

    def _extract_references(self, file_path: str, lines: list[str]) -> None:
        in_code_block = False
        code_delimiter: str | None = None
        current_block: dict | None = None
        current_heading: str | None = None
        block_title: str | None = None
        in_comment_block = False
        comment_delimiter: str | None = None
        code_language: str | None = None
        current_step_context: str | None = None
        skip_next_line = False

        for index, line in enumerate(lines):
            line_num = index + 1

            if skip_next_line:
                skip_next_line = False
                continue

            # Track comment blocks
            if PATTERNS["comment_block"].match(line):
                if in_comment_block and line == comment_delimiter:
                    in_comment_block = False
                    comment_delimiter = None
                else:
                    in_comment_block = True
                    comment_delimiter = line
                continue

            if in_comment_block:
                continue
            if PATTERNS["comment_line"].match(line):
                continue

            # Track headings (outside code blocks only)
            if not in_code_block:
                heading_match = PATTERNS["heading"].match(line) or PATTERNS["md_heading"].match(line)
                if heading_match:
                    current_heading = heading_match.group(2).strip()
                    self._debug(f"Found heading: {current_heading}")
                    continue

            # Track block titles
            if PATTERNS["block_title"].match(line) and not in_code_block:
                block_title = line[1:].strip()
                self._debug(f"Found block title: {block_title}")
                continue

            # ----- Detect code block start -----
            if not in_code_block:
                language = None
                delimiter = None

                # [source,language]
                source_match = PATTERNS["source_block"].match(line)
                if source_match:
                    language = source_match.group(1) or "text"
                    next_idx = index + 1
                    if next_idx < len(lines):
                        next_line = lines[next_idx]
                        if PATTERNS["code_delim"].match(next_line) or PATTERNS["literal_delim"].match(next_line):
                            delimiter = next_line
                            skip_next_line = True

                    in_code_block = True
                    code_delimiter = delimiter
                    code_language = language
                    current_block = {
                        "file": file_path,
                        "line": line_num,
                        "language": language,
                        "content": [],
                        "context": block_title or current_heading,
                    }
                    self._debug(f"Started source block: language={language}")
                    continue

                # [listing]
                if PATTERNS["listing_block"].match(line):
                    language = "text"
                    next_idx = index + 1
                    if next_idx < len(lines):
                        next_line = lines[next_idx]
                        if PATTERNS["code_delim"].match(next_line) or PATTERNS["literal_delim"].match(next_line):
                            delimiter = next_line
                            skip_next_line = True

                    in_code_block = True
                    code_delimiter = delimiter
                    code_language = language
                    current_block = {
                        "file": file_path,
                        "line": line_num,
                        "language": language,
                        "content": [],
                        "context": block_title or current_heading,
                    }
                    self._debug("Started listing block")
                    continue

                # ```language
                fence_match = PATTERNS["code_fence_lang"].match(line)
                if fence_match:
                    language = fence_match.group(1) or "text"
                    in_code_block = True
                    code_delimiter = "```"
                    code_language = language
                    current_block = {
                        "file": file_path,
                        "line": line_num,
                        "language": language,
                        "content": [],
                        "context": block_title or current_heading,
                    }
                    self._debug(f"Started code fence: language={language}")
                    continue

                # ---- delimiter (standalone)
                if PATTERNS["code_delim"].match(line):
                    language = "text"
                    in_code_block = True
                    code_delimiter = line
                    code_language = language
                    current_block = {
                        "file": file_path,
                        "line": line_num,
                        "language": language,
                        "content": [],
                        "context": block_title or current_heading,
                    }
                    self._debug("Started delimited code block")
                    continue
            else:
                # ----- Inside code block -----
                is_end = False

                if code_delimiter == "```" and line == "```":
                    is_end = True
                elif code_delimiter is not None and line == code_delimiter:
                    is_end = True
                elif code_delimiter is None:
                    if (PATTERNS["empty_line"].match(line)
                            or PATTERNS["source_block"].match(line)
                            or PATTERNS["listing_block"].match(line)
                            or PATTERNS["heading"].match(line)):
                        is_end = True

                if is_end:
                    # Process completed code block
                    assert current_block is not None
                    content_str = "\n".join(current_block["content"])
                    current_block["content"] = content_str

                    self.references["code_blocks"].append(current_block)
                    self._extract_from_code_block(current_block, file_path, current_block["line"])

                    self._debug(f"Completed code block at line {line_num}")

                    in_code_block = False
                    code_delimiter = None
                    current_block = None
                    code_language = None
                    block_title = None
                else:
                    assert current_block is not None
                    current_block["content"].append(line)

                continue

            # ----- Not in code block: extract inline references -----

            # Procedure steps
            step_match = PATTERNS["procedure_step"].match(line)
            if step_match:
                current_step_context = step_match.group(1)
                self._debug(f"Found procedure step: {current_step_context}")

            # Commands ($ command)
            cmd_match = PATTERNS["command_line"].match(line)
            if cmd_match:
                command = cmd_match.group(1).strip()
                self.references["commands"].append({
                    "file": file_path,
                    "line": line_num,
                    "command": command,
                    "context": current_step_context or block_title or current_heading,
                })
                self._debug(f"Found command: {command}")

            # Inline code paths
            for path_match in PATTERNS["inline_code_path"].finditer(line):
                found_path = path_match.group(1)
                self.references["file_paths"].append({
                    "file": file_path,
                    "line": line_num,
                    "path": found_path,
                    "context": current_heading,
                })
                self._debug(f"Found file path: {found_path}")

            # API endpoints in regular text (require HTTP method prefix)
            api_match = PATTERNS["api_endpoint"].search(line)
            if api_match:
                endpoint = api_match.group(1)
                self.references["apis"].append({
                    "file": file_path,
                    "line": line_num,
                    "type": "endpoint",
                    "name": endpoint,
                    "context": current_heading,
                })
                self._debug(f"Found API endpoint: {endpoint}")

            # Environment variables ($VAR, ${VAR})
            for ev_match in PATTERNS["env_var_dollar"].finditer(line):
                var_name = ev_match.group(1)
                if var_name not in NOT_ENV_VARS and len(var_name) >= 3:
                    self._add_env_var(file_path, line_num, var_name, current_heading)

        # Handle unclosed block
        if in_code_block and current_block is not None:
            content_str = "\n".join(current_block["content"])
            current_block["content"] = content_str
            self.references["code_blocks"].append(current_block)
            self._extract_from_code_block(current_block, file_path, current_block["line"])
            print(
                f"WARNING: Unclosed code block in {file_path} starting at line {current_block['line']}",
                file=sys.stderr,
            )

    def _extract_from_code_block(
        self, block: dict, file_path: str, line_num: int
    ) -> None:
        content = block["content"]
        language = block.get("language", "text")
        context = block.get("context")
        lang_lower = language.lower()

        # Extract commands from code block lines ($ and # prompts)
        for cline in content.splitlines():
            cmd_match = PATTERNS["command_line_code"].match(cline.strip())
            if cmd_match:
                command = cmd_match.group(1).strip()
                prompt_char = cline.lstrip()[0] if cline.lstrip() else "$"
                prompt_type = "root" if prompt_char == "#" else "user"
                self.references["commands"].append({
                    "file": file_path,
                    "line": line_num,
                    "command": command,
                    "prompt_type": prompt_type,
                    "context": context,
                })
                self._debug(f"Found command in code block: {command} ({prompt_type})")

        # Extract function calls and class definitions ONLY from
        # programming language blocks — not from terminal/text/console/output
        if lang_lower in CODE_LANGUAGES:
            for func_match in PATTERNS["function_call"].finditer(content):
                function_name = func_match.group(1)
                if len(function_name) < 3:
                    continue
                if function_name.lower() in SKIP_FUNCTIONS:
                    continue
                self.references["apis"].append({
                    "file": file_path,
                    "line": line_num,
                    "type": "function",
                    "name": function_name,
                    "language": language,
                    "context": context,
                })
                self._debug(f"Found function: {function_name}")

            for class_match in PATTERNS["class_def"].finditer(content):
                class_name = class_match.group(1)
                self.references["apis"].append({
                    "file": file_path,
                    "line": line_num,
                    "type": "class",
                    "name": class_name,
                    "language": language,
                    "context": context,
                })
                self._debug(f"Found class: {class_name}")

        # Extract environment variables from code blocks
        for ev_match in PATTERNS["env_var_dollar"].finditer(content):
            var_name = ev_match.group(1)
            if var_name not in NOT_ENV_VARS and len(var_name) >= 3:
                self._add_env_var(file_path, line_num, var_name, context)

        # Extract config keys from YAML/JSON/TOML
        if lang_lower in ("yaml", "yml", "json", "toml"):
            self._extract_config_keys(content, file_path, line_num, language, context)

    def _extract_config_keys(
        self,
        content: str,
        file_path: str,
        line_num: int,
        fmt: str,
        context: str | None,
    ) -> None:
        keys: list[str] = []
        fmt_lower = fmt.lower()

        if fmt_lower in ("yaml", "yml"):
            for m in re.finditer(r"^(\s*)([a-zA-Z_][a-zA-Z0-9_-]*):", content, re.MULTILINE):
                keys.append(m.group(2))
        elif fmt_lower == "json":
            for m in re.finditer(r'"([a-zA-Z_][a-zA-Z0-9_-]*)"\s*:', content):
                keys.append(m.group(1))
        elif fmt_lower == "toml":
            for m in re.finditer(r"^([a-zA-Z_][a-zA-Z0-9_-]*)\s*=", content, re.MULTILINE):
                keys.append(m.group(1))

        # Deduplicate while preserving order
        seen: set[str] = set()
        unique_keys: list[str] = []
        for k in keys:
            if k not in seen:
                seen.add(k)
                unique_keys.append(k)

        if unique_keys:
            self.references["configs"].append({
                "file": file_path,
                "line": line_num,
                "format": fmt,
                "keys": unique_keys,
                "context": context,
            })
            self._debug(f"Found config keys: {', '.join(unique_keys)}")

    def _add_env_var(
        self, file_path: str, line_num: int, var_name: str, context: str | None
    ) -> None:
        """Add an environment variable reference, deduplicating by name+file."""
        # Deduplicate: don't record the same var from the same file multiple times
        for existing in self.references["env_vars"]:
            if existing["name"] == var_name and existing["file"] == file_path:
                return
        self.references["env_vars"].append({
            "file": file_path,
            "line": line_num,
            "name": var_name,
            "context": context,
        })
        self._debug(f"Found env var: {var_name}")

    def _debug(self, message: str) -> None:
        if self.verbose:
            print(f"[DEBUG] {message}", file=sys.stdout)


# =============================================================================
# TechReferenceSearcher  (ports search_tech_references.rb)
# =============================================================================

class TechReferenceSearcher:
    """Searches code repositories for evidence matching extracted references."""

    def __init__(self, *, verbose: bool = False) -> None:
        self.verbose = verbose
        self.results: list[dict] = []
        self.counters = {"total": 0, "found": 0, "not_found": 0}
        self.schemas: dict[str, dict] = {}
        self.cli_definitions: dict[str, dict] = {}
        self._binary_name_cache: dict[str, str | None] = {}

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def search(self, refs_data: dict, repo_paths: list[str]) -> dict:
        references = refs_data.get("references", {})

        # Pre-discovery
        self.schemas = self._discover_schemas(repo_paths)
        self.cli_definitions = self._discover_cli_definitions(repo_paths)

        self._debug(f"Discovered {len(self.schemas)} schema files")
        self._debug(f"Discovered {len(self.cli_definitions)} CLI entry points")

        self._search_commands(references.get("commands", []), repo_paths)
        self._search_code_blocks(references.get("code_blocks", []), repo_paths)
        self._search_apis(references.get("apis", []), repo_paths)
        self._search_configs(references.get("configs", []), repo_paths)
        self._search_file_paths(references.get("file_paths", []), repo_paths)
        self._search_env_vars(references.get("env_vars", []), repo_paths)

        return {
            "search_results": self.results,
            "summary": self.counters,
            "discovered_schemas": list(self.schemas.keys()),
            "discovered_cli_definitions": [
                {
                    "binary": k,
                    "file": v.get("file", ""),
                    "subcommands": list(v.get("subcommands", {}).keys()),
                }
                for k, v in self.cli_definitions.items()
            ],
        }

    # ------------------------------------------------------------------
    # Commands
    # ------------------------------------------------------------------

    def _search_commands(self, commands: list[dict], repo_paths: list[str]) -> None:
        for idx, cmd in enumerate(commands):
            self.counters["total"] += 1
            ref_id = f"cmd-{idx + 1}"
            raw_command = cmd.get("command", "")
            self._debug(f"Searching for command: {raw_command}")

            parts = _shell_split(raw_command)
            if parts and parts[0] == "sudo":
                parts = parts[1:]
            binary = parts[0] if parts else ""
            flags = [p for p in parts if p.startswith("-")]

            scope = self._classify_command_scope(binary, repo_paths)
            self._debug(f"  Scope: {scope}")

            matches: list[dict] = []
            git_evidence: list[dict] = []
            flags_checked: dict[str, bool] = {}
            cli_validation = None

            if scope != "external":
                escaped_binary = re.escape(binary)

                for repo in repo_paths:
                    if not os.path.isdir(repo):
                        continue

                    # Find binary by name
                    binary_matches = self._find_files_by_name(repo, binary)
                    for path in binary_matches:
                        matches.append({
                            "repo": repo, "path": path,
                            "type": "binary", "context": f"Binary found: {path}",
                        })

                    # Grep for command name
                    grep_hits = self._grep_repo(repo, rf"\b{escaped_binary}\b", max_results=10)
                    for hit in grep_hits:
                        matches.append({
                            "repo": repo, "path": hit["path"],
                            "type": "grep", "context": hit["context"],
                        })

                    # Git log evidence
                    log_entries = self._git_log_search(repo, binary, max_results=5)
                    for entry in log_entries:
                        git_evidence.append({"repo": repo, "type": "log", "context": entry})

                    # Check each flag
                    for flag in flags:
                        if len(flag) < 2:
                            continue
                        flag_hits = self._grep_repo(repo, re.escape(flag), max_results=3)
                        flags_checked[flag] = len(flag_hits) > 0
                        self._debug(f"  Flag {flag}: {'found' if flags_checked[flag] else 'not found'}")

                # Validate against CLI definitions
                if binary in self.cli_definitions:
                    cli_validation = self._validate_command_against_cli(
                        binary, parts[1:] if len(parts) > 1 else [], self.cli_definitions[binary]
                    )
                    self._debug(f"  CLI validation: {'valid' if cli_validation['valid'] else 'issues found'}")

            found = len(matches) > 0
            self.counters["found" if found else "not_found"] += 1

            self.results.append({
                "ref_id": ref_id,
                "category": "command",
                "scope": scope,
                "reference": cmd,
                "results": {
                    "found": found,
                    "matches": matches,
                    "git_evidence": git_evidence,
                    "flags_checked": flags_checked,
                    "cli_validation": cli_validation,
                },
            })

    # ------------------------------------------------------------------
    # Code blocks
    # ------------------------------------------------------------------

    def _search_code_blocks(self, blocks: list[dict], repo_paths: list[str]) -> None:
        for idx, block in enumerate(blocks):
            self.counters["total"] += 1
            ref_id = f"code-{idx + 1}"
            content = block.get("content", "")
            language = block.get("language", "text")
            self._debug(f"Searching for code block ({language}): {content[:60]}...")

            matches: list[dict] = []
            block_lines = [l for l in content.splitlines() if l.strip()]
            if not block_lines:
                continue

            first_line = block_lines[0].strip()
            identifiers = self._extract_identifiers(content)

            for repo in repo_paths:
                if not os.path.isdir(repo):
                    continue

                # Grep for exact first-line match
                if first_line:
                    first_line_hits = self._grep_repo(repo, re.escape(first_line), max_results=5)
                    for hit in first_line_hits:
                        matches.append({
                            "repo": repo, "path": hit["path"],
                            "type": "first_line", "context": hit["context"],
                        })

                # Identifier match ratio
                if identifiers:
                    found_ids: list[str] = []
                    missing_ids: list[str] = []
                    for ident in identifiers:
                        hits = self._grep_repo(repo, rf"\b{re.escape(ident)}\b", max_results=1)
                        if hits:
                            found_ids.append(ident)
                        else:
                            missing_ids.append(ident)

                    total_ids = len(identifiers)
                    found_count = len(found_ids)
                    ratio = round(found_count / total_ids, 2) if total_ids > 0 else 0.0

                    matches.append({
                        "repo": repo,
                        "path": None,
                        "type": "identifier_ratio",
                        "context": f"{found_count}/{total_ids} identifiers found ({ratio})",
                        "found_identifiers": found_ids,
                        "missing_identifiers": missing_ids,
                    })

            found = any(m["type"] != "identifier_ratio" or "/" in str(m.get("context", "")) for m in matches)
            self.counters["found" if found else "not_found"] += 1

            self.results.append({
                "ref_id": ref_id,
                "category": "code_block",
                "reference": block,
                "results": {
                    "found": found,
                    "matches": matches,
                    "git_evidence": [],
                },
            })

    # ------------------------------------------------------------------
    # APIs (functions, classes, endpoints)
    # ------------------------------------------------------------------

    def _search_apis(self, apis: list[dict], repo_paths: list[str]) -> None:
        for idx, api in enumerate(apis):
            self.counters["total"] += 1
            ref_id = f"api-{idx + 1}"
            api_type = api.get("type", "function")
            name = api.get("name", "")
            self._debug(f"Searching for {api_type}: {name}")

            matches: list[dict] = []
            git_evidence: list[dict] = []

            if not name or len(name) < 2:
                continue

            for repo in repo_paths:
                if not os.path.isdir(repo):
                    continue

                if api_type == "function":
                    for pattern_template in DEFINITION_PATTERNS["function"]:
                        pattern = pattern_template.format(name=re.escape(name))
                        hits = self._grep_repo(repo, pattern, max_results=5)
                        for hit in hits:
                            matches.append({
                                "repo": repo, "path": hit["path"],
                                "type": "definition", "context": hit["context"],
                            })

                    # General usage
                    usage_hits = self._grep_repo(repo, rf"\b{re.escape(name)}\b", max_results=5)
                    for hit in usage_hits:
                        matches.append({
                            "repo": repo, "path": hit["path"],
                            "type": "usage", "context": hit["context"],
                        })

                elif api_type == "class":
                    for pattern_template in DEFINITION_PATTERNS["class"]:
                        pattern = pattern_template.format(name=re.escape(name))
                        hits = self._grep_repo(repo, pattern, max_results=5)
                        for hit in hits:
                            matches.append({
                                "repo": repo, "path": hit["path"],
                                "type": "definition", "context": hit["context"],
                            })

                elif api_type == "endpoint":
                    endpoint_hits = self._grep_repo(repo, re.escape(name), max_results=10)
                    for hit in endpoint_hits:
                        matches.append({
                            "repo": repo, "path": hit["path"],
                            "type": "endpoint", "context": hit["context"],
                        })

                # Git log evidence
                log_entries = self._git_log_search(repo, name, max_results=3)
                for entry in log_entries:
                    git_evidence.append({"repo": repo, "type": "log", "context": entry})

            found = any(m["type"] in ("definition", "endpoint") for m in matches)
            if not found:
                found = len(matches) > 0
            self.counters["found" if found else "not_found"] += 1

            self.results.append({
                "ref_id": ref_id,
                "category": "api",
                "reference": api,
                "results": {
                    "found": found,
                    "matches": matches,
                    "git_evidence": git_evidence,
                },
            })

    # ------------------------------------------------------------------
    # Configs
    # ------------------------------------------------------------------

    def _search_configs(self, configs: list[dict], repo_paths: list[str]) -> None:
        for idx, config in enumerate(configs):
            self.counters["total"] += 1
            ref_id = f"cfg-{idx + 1}"
            keys = config.get("keys", [])
            format_type = config.get("format", "yaml")
            self._debug(f"Searching for config keys ({format_type}): {', '.join(keys)}")

            matches: list[dict] = []
            git_evidence: list[dict] = []
            keys_found: dict[str, bool] = {}

            for repo in repo_paths:
                if not os.path.isdir(repo):
                    continue

                extensions = self._config_extensions_for(format_type)
                config_files: list[str] = []
                for ext in extensions:
                    config_files.extend(self._find_files_by_extension(repo, ext))

                self._debug(f"  Found {len(config_files)} config files in {repo}")

                for key in keys:
                    key_found = False
                    for cf in config_files:
                        hits = self._grep_file(cf, key)
                        if not hits:
                            continue
                        key_found = True
                        for hit in hits:
                            matches.append({
                                "repo": repo, "path": cf,
                                "type": "config_key", "key": key,
                                "context": hit,
                            })
                    keys_found[key] = key_found

                    if not key_found:
                        broad_hits = self._grep_repo(repo, rf"\b{re.escape(key)}\b", max_results=3)
                        for hit in broad_hits:
                            matches.append({
                                "repo": repo, "path": hit["path"],
                                "type": "config_key_broad", "key": key,
                                "context": hit["context"],
                            })
                            keys_found[key] = True

                # Git log for missing keys
                for key in keys:
                    if keys_found.get(key):
                        continue
                    log_entries = self._git_log_search(repo, key, max_results=3)
                    for entry in log_entries:
                        git_evidence.append({"repo": repo, "key": key, "type": "log", "context": entry})

            # Validate against schemas
            schema_validation = None
            if self.schemas:
                schema_validation = self._validate_config_against_schemas(keys, self.schemas)
                self._debug(f"  Schema validation: {len(schema_validation['matched_schemas'])} schemas checked")

            found = any(keys_found.values())
            self.counters["found" if found else "not_found"] += 1

            self.results.append({
                "ref_id": ref_id,
                "category": "config",
                "reference": config,
                "results": {
                    "found": found,
                    "matches": matches,
                    "git_evidence": git_evidence,
                    "keys_checked": keys_found,
                    "schema_validation": schema_validation,
                },
            })

    # ------------------------------------------------------------------
    # File paths
    # ------------------------------------------------------------------

    def _search_file_paths(self, paths: list[dict], repo_paths: list[str]) -> None:
        for idx, fp in enumerate(paths):
            self.counters["total"] += 1
            ref_id = f"path-{idx + 1}"
            fpath = fp.get("path", "")
            self._debug(f"Searching for file path: {fpath}")

            matches: list[dict] = []

            if not fpath:
                continue

            for repo in repo_paths:
                if not os.path.isdir(repo):
                    continue

                exact = os.path.join(repo, fpath)
                if os.path.exists(exact):
                    matches.append({
                        "repo": repo, "path": fpath,
                        "type": "exact",
                        "context": f"Exact path exists: {fpath}",
                    })
                    self._debug(f"  Exact match found: {exact}")
                    continue

                basename = os.path.basename(fpath)
                basename_matches = self._find_files_by_name(repo, basename)
                for found_path in basename_matches:
                    matches.append({
                        "repo": repo, "path": found_path,
                        "type": "basename",
                        "context": f"Found by basename at: {found_path}",
                    })

            found = len(matches) > 0
            self.counters["found" if found else "not_found"] += 1

            self.results.append({
                "ref_id": ref_id,
                "category": "file_path",
                "reference": fp,
                "results": {
                    "found": found,
                    "matches": matches,
                    "git_evidence": [],
                },
            })

    # ------------------------------------------------------------------
    # Environment variables
    # ------------------------------------------------------------------

    def _search_env_vars(self, env_vars: list[dict], repo_paths: list[str]) -> None:
        for idx, ev in enumerate(env_vars):
            self.counters["total"] += 1
            ref_id = f"env-{idx + 1}"
            var_name = ev.get("name", "")
            self._debug(f"Searching for env var: {var_name}")

            matches: list[dict] = []
            git_evidence: list[dict] = []

            if not var_name:
                continue

            for repo in repo_paths:
                if not os.path.isdir(repo):
                    continue

                # Grep for the variable name (as env var usage or definition)
                grep_hits = self._grep_repo(
                    repo, rf"\b{re.escape(var_name)}\b", max_results=10
                )
                for hit in grep_hits:
                    matches.append({
                        "repo": repo, "path": hit["path"],
                        "type": "usage", "context": hit["context"],
                    })

                # Git log for rename/deprecation evidence
                log_entries = self._git_log_search(repo, var_name, max_results=3)
                for entry in log_entries:
                    git_evidence.append({
                        "repo": repo, "type": "log", "context": entry,
                    })

            found = len(matches) > 0
            self.counters["found" if found else "not_found"] += 1

            self.results.append({
                "ref_id": ref_id,
                "category": "env_var",
                "reference": ev,
                "results": {
                    "found": found,
                    "matches": matches,
                    "git_evidence": git_evidence,
                },
            })

    # ------------------------------------------------------------------
    # Scope classification
    # ------------------------------------------------------------------

    def _classify_command_scope(self, binary: str, repo_paths: list[str]) -> str:
        if not binary:
            return "external"
        if binary in EXTERNAL_COMMANDS:
            return "external"

        for repo in repo_paths:
            if not os.path.isdir(repo):
                continue
            for ep_file in ("pyproject.toml", "setup.cfg", "setup.py", "Cargo.toml", "package.json"):
                ep_path = os.path.join(repo, ep_file)
                if not os.path.exists(ep_path):
                    continue
                hits = self._grep_file(ep_path, binary)
                if hits:
                    return "in-scope"

        return "unknown"

    # ------------------------------------------------------------------
    # Schema discovery and validation
    # ------------------------------------------------------------------

    def _discover_schemas(self, repo_paths: list[str]) -> dict[str, dict]:
        schemas: dict[str, dict] = {}

        for repo in repo_paths:
            if not os.path.isdir(repo):
                continue

            schema_patterns = [
                "*schema*.yaml", "*schema*.yml", "*schema*.json",
                "*_schema.*", "*.schema.*", "*-schema.*",
            ]

            schema_files: list[str] = []
            for pattern in schema_patterns:
                cmd = (
                    f"find {shlex.quote(repo)} -iname {shlex.quote(pattern)} "
                    f"-not -path '*/.git/*' -not -path '*/node_modules/*' "
                    f"-not -path '*/vendor/*' -not -path '*/__pycache__/*' 2>/dev/null"
                )
                output = self._run_command(cmd, timeout=10)
                if output:
                    schema_files.extend(l for l in output.splitlines() if l.strip())

            for sf in sorted(set(schema_files)):
                try:
                    content = Path(sf).read_text(encoding="utf-8", errors="replace")
                    keys = self._extract_all_keys_from_content(content, sf)
                    rel_path = sf.replace(f"{repo}/", "", 1)
                    schemas[rel_path] = {"repo": repo, "full_path": sf, "keys": keys}
                    self._debug(f"  Found schema: {rel_path} ({len(keys)} keys)")
                except Exception as exc:
                    self._debug(f"  Error reading schema {sf}: {exc}")

        return schemas

    def _extract_all_keys_from_content(self, content: str, file_path: str) -> list[str]:
        keys: list[str] = []
        ext = Path(file_path).suffix.lower()

        if ext in (".yaml", ".yml"):
            for m in re.finditer(r"^\s*([a-zA-Z_][a-zA-Z0-9_-]*)\s*:", content, re.MULTILINE):
                keys.append(m.group(1))
        elif ext == ".json":
            for m in re.finditer(r'"([a-zA-Z_][a-zA-Z0-9_-]*)"\s*:', content):
                keys.append(m.group(1))

        return list(dict.fromkeys(keys))  # deduplicate preserving order

    def _validate_config_against_schemas(
        self, doc_keys: list[str], schemas: dict[str, dict]
    ) -> dict:
        matched_schemas: list[dict] = []

        for schema_path, schema_info in schemas.items():
            schema_keys = schema_info.get("keys", [])
            if not schema_keys:
                continue

            doc_set = set(doc_keys)
            schema_set = set(schema_keys)
            common = sorted(doc_set & schema_set)
            doc_only = sorted(doc_set - schema_set)
            schema_only = sorted(schema_set - doc_set)
            overlap_ratio = round(len(common) / len(doc_keys), 2) if doc_keys else 0.0

            if overlap_ratio < 0.3:
                continue

            matched_schemas.append({
                "schema_file": schema_path,
                "overlap_ratio": overlap_ratio,
                "keys_in_both": common,
                "keys_only_in_doc": doc_only,
                "keys_only_in_schema": schema_only,
            })

        matched_schemas.sort(key=lambda s: -s["overlap_ratio"])
        return {"matched_schemas": matched_schemas}

    # ------------------------------------------------------------------
    # CLI definition discovery
    # ------------------------------------------------------------------

    def _discover_cli_definitions(self, repo_paths: list[str]) -> dict[str, dict]:
        cli_defs: dict[str, dict] = {}

        for repo in repo_paths:
            if not os.path.isdir(repo):
                continue

            binary_name = self._determine_binary_name_cached(repo)
            if binary_name is None:
                continue

            # Python argparse/click
            argparse_hits = self._grep_repo(
                repo,
                r"argparse|add_argument|click\.command|click\.option|click\.argument",
                max_results=30,
            )
            seen_files: set[str] = set()
            for h in argparse_hits:
                rel_path = h["path"]
                if rel_path in seen_files:
                    continue
                seen_files.add(rel_path)
                file_path = os.path.join(repo, rel_path)
                if not os.path.isfile(file_path):
                    continue
                try:
                    content = Path(file_path).read_text(encoding="utf-8", errors="replace")
                    defs = self._extract_cli_from_python(content, rel_path)
                    if defs is None:
                        continue
                    if binary_name in cli_defs:
                        cli_defs[binary_name]["subcommands"].update(defs["subcommands"])
                        existing_flags = set(cli_defs[binary_name]["flags"])
                        for f in defs["flags"]:
                            if f not in existing_flags:
                                cli_defs[binary_name]["flags"].append(f)
                                existing_flags.add(f)
                    else:
                        cli_defs[binary_name] = {**defs, "file": rel_path}
                    self._debug(
                        f"  Found CLI defs for '{binary_name}' in {rel_path}: "
                        f"{len(defs['flags'])} flags, {len(defs['subcommands'])} subcommands"
                    )
                except Exception as exc:
                    self._debug(f"  Error parsing CLI defs from {rel_path}: {exc}")

            # Go cobra
            cobra_hits = self._grep_repo(
                repo,
                r"cobra\.Command|pflag|flag\.String|flag\.Bool",
                max_results=20,
            )
            seen_files_go: set[str] = set()
            for h in cobra_hits:
                rel_path = h["path"]
                if rel_path in seen_files_go:
                    continue
                seen_files_go.add(rel_path)
                file_path = os.path.join(repo, rel_path)
                if not os.path.isfile(file_path):
                    continue
                try:
                    content = Path(file_path).read_text(encoding="utf-8", errors="replace")
                    defs = self._extract_cli_from_go_cobra(content, rel_path)
                    if defs is None:
                        continue
                    if binary_name in cli_defs:
                        cli_defs[binary_name]["subcommands"].update(defs["subcommands"])
                        existing_flags = set(cli_defs[binary_name]["flags"])
                        for f in defs["flags"]:
                            if f not in existing_flags:
                                cli_defs[binary_name]["flags"].append(f)
                                existing_flags.add(f)
                    else:
                        cli_defs[binary_name] = {**defs, "file": rel_path}
                except Exception as exc:
                    self._debug(f"  Error parsing Cobra defs from {rel_path}: {exc}")

        return cli_defs

    def _extract_cli_from_python(self, content: str, file_path: str) -> dict | None:
        flags: list[str] = []
        subcommands: dict[str, dict] = {}

        # argparse: parser.add_argument('--flag', '-f', ...)
        for m in re.finditer(r"add_argument\(\s*['\"](-{1,2}[a-zA-Z0-9_-]+)['\"]", content):
            flags.append(m.group(1))
        # Short+long combo
        for m in re.finditer(
            r"add_argument\(\s*['\"](-[a-zA-Z])['\"],\s*['\"](-{2}[a-zA-Z0-9_-]+)['\"]", content
        ):
            if m.group(1) not in flags:
                flags.append(m.group(1))
            if m.group(2) not in flags:
                flags.append(m.group(2))

        # argparse subparsers
        for m in re.finditer(r"add_parser\(\s*['\"]([a-zA-Z0-9_-]+)['\"]", content):
            subcommands[m.group(1)] = {"source": file_path}

        # click options
        for m in re.finditer(r"@click\.option\(\s*['\"](-{1,2}[a-zA-Z0-9_-]+)['\"]", content):
            flags.append(m.group(1))

        # click arguments
        for m in re.finditer(r"@click\.argument\(\s*['\"]([a-zA-Z0-9_-]+)['\"]", content):
            subcommands[m.group(1)] = {"source": file_path, "type": "argument"}

        # click command/group
        for m in re.finditer(
            r"@(?:click\.command|click\.group)\(\s*(?:name\s*=\s*)?['\"]([a-zA-Z0-9_-]+)['\"]",
            content,
        ):
            subcommands[m.group(1)] = {"source": file_path}

        if not flags and not subcommands:
            return None

        # Deduplicate flags preserving order
        seen: set[str] = set()
        unique_flags: list[str] = []
        for f in flags:
            if f not in seen:
                seen.add(f)
                unique_flags.append(f)

        return {"flags": unique_flags, "subcommands": subcommands}

    def _extract_cli_from_go_cobra(self, content: str, file_path: str) -> dict | None:
        flags: list[str] = []
        subcommands: dict[str, dict] = {}

        # cobra flags
        for m in re.finditer(
            r"\.(?:Flags|PersistentFlags)\(\)\."
            r"(?:String|Bool|Int|Float|Duration|StringSlice)(?:Var|VarP|P)?\(\s*"
            r"(?:&\w+,\s*)?[\"']([a-zA-Z0-9_-]+)[\"']",
            content,
        ):
            flags.append(f"--{m.group(1)}")

        # cobra Use
        for m in re.finditer(r"Use:\s*[\"']([a-zA-Z0-9_-]+)", content):
            subcommands[m.group(1)] = {"source": file_path}

        if not flags and not subcommands:
            return None

        seen: set[str] = set()
        unique_flags = [f for f in flags if f not in seen and not seen.add(f)]  # type: ignore[func-returns-value]

        return {"flags": unique_flags, "subcommands": subcommands}

    def _determine_binary_name_cached(self, repo: str) -> str | None:
        if repo in self._binary_name_cache:
            return self._binary_name_cache[repo]
        name = self._determine_binary_name(repo)
        self._binary_name_cache[repo] = name
        return name

    def _determine_binary_name(self, repo: str) -> str | None:
        # pyproject.toml
        pyproject = os.path.join(repo, "pyproject.toml")
        if os.path.isfile(pyproject):
            try:
                content = Path(pyproject).read_text(encoding="utf-8", errors="replace")
                in_scripts = False
                for raw_line in content.splitlines():
                    stripped = raw_line.strip()
                    if re.match(r"^\[(?:project\.scripts|tool\.poetry\.scripts)\]", stripped):
                        in_scripts = True
                        continue
                    if stripped.startswith("[") and in_scripts:
                        in_scripts = False
                        continue
                    if in_scripts:
                        m = re.match(r'^["\']?([a-zA-Z0-9_-]+)["\']?\s*=\s*["\']', stripped)
                        if m:
                            return m.group(1)
            except Exception:
                pass

        # setup.cfg
        setup_cfg = os.path.join(repo, "setup.cfg")
        if os.path.isfile(setup_cfg):
            try:
                content = Path(setup_cfg).read_text(encoding="utf-8", errors="replace")
                in_entry_points = False
                in_console_scripts = False
                for raw_line in content.splitlines():
                    stripped = raw_line.strip()
                    if stripped == "[options.entry_points]":
                        in_entry_points = True
                        continue
                    if stripped.startswith("[") and in_entry_points:
                        in_entry_points = False
                        in_console_scripts = False
                        continue
                    if in_entry_points and stripped == "console_scripts =":
                        in_console_scripts = True
                        continue
                    if in_console_scripts:
                        m = re.match(r"^([a-zA-Z0-9_-]+)\s*=", stripped)
                        if m:
                            return m.group(1)
            except Exception:
                pass

        # setup.py
        setup_py = os.path.join(repo, "setup.py")
        if os.path.isfile(setup_py):
            try:
                content = Path(setup_py).read_text(encoding="utf-8", errors="replace")
                for block_match in re.finditer(r"console_scripts.*?\[(.*?)\]", content, re.DOTALL):
                    for m in re.finditer(r"['\"]([a-zA-Z0-9_-]+)\s*=", block_match.group(1)):
                        return m.group(1)
            except Exception:
                pass

        # Go cmd/ directory
        cmd_dir = os.path.join(repo, "cmd")
        if os.path.isdir(cmd_dir):
            for child in sorted(Path(cmd_dir).iterdir()):
                if child.is_dir() and (child / "main.go").is_file():
                    return child.name

        # Fallback: repo directory name
        return os.path.basename(repo)

    def _validate_command_against_cli(
        self, binary: str, args: list[str], cli_def: dict
    ) -> dict:
        known_flags = cli_def.get("flags", [])
        known_subcommands = cli_def.get("subcommands", {})

        doc_flags = [a for a in args if a.startswith("-")]
        doc_positionals = [a for a in args if not a.startswith("-")]

        valid_flags: list[str] = []
        unknown_flags: list[str] = []
        for flag in doc_flags:
            normalized = flag.split("=")[0]
            if normalized in known_flags:
                valid_flags.append(normalized)
            else:
                unknown_flags.append(normalized)

        subcommand_check = None
        first_positional = doc_positionals[0] if doc_positionals else None
        if (first_positional
                and "/" not in first_positional
                and "." not in first_positional
                and "<" not in first_positional
                and not re.match(r"^[\$\{]", first_positional)
                and known_subcommands):
            if first_positional in known_subcommands:
                subcommand_check = {"name": first_positional, "valid": True}
            else:
                subcommand_check = {
                    "name": first_positional,
                    "valid": False,
                    "known_subcommands": list(known_subcommands.keys()),
                }

        return {
            "valid": len(unknown_flags) == 0,
            "known_flags": known_flags,
            "valid_flags": valid_flags,
            "unknown_flags": unknown_flags,
            "subcommand_check": subcommand_check,
            "cli_source": cli_def.get("file", ""),
        }

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    def _grep_repo(self, repo: str, pattern: str, *, max_results: int = 10) -> list[dict]:
        exclude_args = " ".join(f"--exclude-dir={d}" for d in SKIP_DIRS)
        cmd = (
            f"grep -rn {exclude_args} --include='*' -E "
            f"{shlex.quote(pattern)} {shlex.quote(repo)} 2>/dev/null"
        )
        output = self._run_command(cmd, timeout=15)
        if not output:
            return []

        results: list[dict] = []
        for line in output.splitlines():
            if not line:
                continue
            m = re.match(r"^(.+?):(\d+):(.*)$", line)
            if m:
                rel_path = m.group(1).replace(f"{repo}/", "", 1)
                results.append({
                    "path": rel_path,
                    "line": int(m.group(2)),
                    "context": m.group(3).strip(),
                })
            if len(results) >= max_results:
                break

        return results

    def _grep_file(self, file_path: str, pattern: str) -> list[str]:
        if not os.path.isfile(file_path):
            return []
        cmd = f"grep -n {shlex.quote(pattern)} {shlex.quote(file_path)} 2>/dev/null"
        output = self._run_command(cmd, timeout=5)
        if not output:
            return []
        return [l for l in output.splitlines() if l.strip()][:5]

    def _git_log_search(self, repo: str, term: str, *, max_results: int = 5) -> list[str]:
        git_dir = os.path.join(repo, ".git")
        if not os.path.isdir(git_dir):
            return []
        cmd = (
            f"git -C {shlex.quote(repo)} log --oneline --all -n {max_results} "
            f"--grep={shlex.quote(term)} 2>/dev/null"
        )
        output = self._run_command(cmd, timeout=10)
        if not output:
            return []
        return [l for l in output.splitlines() if l.strip()][:max_results]

    def _find_files_by_name(self, repo: str, name: str) -> list[str]:
        if not name:
            return []
        cmd = (
            f"find {shlex.quote(repo)} -name {shlex.quote(name)} "
            f"-not -path '*/.git/*' -not -path '*/node_modules/*' "
            f"-not -path '*/vendor/*' 2>/dev/null"
        )
        output = self._run_command(cmd, timeout=10)
        if not output:
            return []
        return [l.replace(f"{repo}/", "", 1) for l in output.splitlines() if l.strip()][:10]

    def _find_files_by_extension(self, repo: str, ext: str) -> list[str]:
        cmd = (
            f"find {shlex.quote(repo)} -name {shlex.quote('*' + ext)} "
            f"-not -path '*/.git/*' -not -path '*/node_modules/*' "
            f"-not -path '*/vendor/*' 2>/dev/null"
        )
        output = self._run_command(cmd, timeout=10)
        if not output:
            return []
        return [l for l in output.splitlines() if l.strip()][:50]

    def _extract_identifiers(self, content: str) -> list[str]:
        identifiers: list[str] = []

        for m in re.finditer(r"\b([a-zA-Z_][a-zA-Z0-9_]{2,})\s*\(", content):
            identifiers.append(m.group(1))
        for m in re.finditer(r"\b(?:class|struct|interface|type)\s+([A-Z][a-zA-Z0-9_]+)", content):
            identifiers.append(m.group(1))
        for m in re.finditer(r"(?:import|from|require|use)\s+['\"]?([a-zA-Z0-9_.\/\-]+)", content):
            identifiers.append(m.group(1))

        return list(dict.fromkeys(identifiers))[:20]

    @staticmethod
    def _config_extensions_for(format_type: str) -> list[str]:
        fmt = format_type.lower()
        if fmt in ("yaml", "yml"):
            return [".yaml", ".yml"]
        elif fmt == "json":
            return [".json"]
        elif fmt == "toml":
            return [".toml"]
        else:
            return list(CONFIG_EXTENSIONS)

    @staticmethod
    def _run_command(cmd: str, *, timeout: int = 15) -> str | None:
        try:
            result = subprocess.run(
                cmd, shell=True, capture_output=True, text=True, timeout=timeout
            )
            # grep returns 1 for no match — that's fine
            if result.returncode not in (0, 1):
                return None
            return result.stdout
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return None

    def _debug(self, message: str) -> None:
        if self.verbose:
            print(f"[DEBUG] {message}", file=sys.stderr)


# =============================================================================
# TechReferenceTriage  (NEW — deterministic triage of search results)
# =============================================================================

class TechReferenceTriage:
    """Processes search results through deterministic triage passes.

    Pass 1 — Scope filtering (commands only):
        external → out-of-scope
    Pass 2 — Deterministic validation:
        CLI unknown flags, schema mismatches, file path mismatches
    Pass 3 — Evidence-based analysis:
        git evidence, partial matches, no matches
    """

    def __init__(self, *, verbose: bool = False) -> None:
        self.verbose = verbose

    def triage(self, search_data: dict) -> dict:
        search_results = search_data.get("search_results", [])
        triaged: list[dict] = []

        for item in search_results:
            triaged_item = self._triage_item(item)
            triaged.append(triaged_item)

        summary = self._build_summary(triaged)
        return {
            "triaged_results": triaged,
            "summary": summary,
            "discovered_schemas": search_data.get("discovered_schemas", []),
            "discovered_cli_definitions": search_data.get("discovered_cli_definitions", []),
        }

    def _triage_item(self, item: dict) -> dict:
        category = item.get("category", "")
        results = item.get("results", {})
        scope = item.get("scope", "")

        triaged = {**item}

        # Pass 1 — Scope filtering (commands only)
        if category == "command" and scope == "external":
            triaged["triage_pass"] = 1
            triaged["triage_status"] = "out-of-scope"
            triaged["confidence"] = 0
            triaged["severity"] = None
            triaged["suggested_fix"] = None
            return triaged

        # Pass 2 — Deterministic validation
        pass2 = self._pass2_deterministic(item, category, results)
        if pass2 is not None:
            triaged.update(pass2)
            return triaged

        # Pass 3 — Evidence-based analysis
        pass3 = self._pass3_evidence(item, category, results)
        triaged.update(pass3)
        return triaged

    # ------------------------------------------------------------------
    # Pass 2 — Deterministic validation
    # ------------------------------------------------------------------

    def _pass2_deterministic(
        self, item: dict, category: str, results: dict
    ) -> dict | None:
        # Commands: unknown flags from CLI validation
        if category == "command":
            cli_val = results.get("cli_validation")
            if cli_val and cli_val.get("unknown_flags"):
                unknown = cli_val["unknown_flags"]
                confidence = min(80 + len(unknown) * 5, 95)
                return {
                    "triage_pass": 2,
                    "triage_status": "issue",
                    "confidence": confidence,
                    "severity": "high",
                    "suggested_fix": f"Unknown flags: {', '.join(unknown)}. "
                                     f"Check valid flags: {', '.join(cli_val.get('known_flags', [])[:10])}",
                }

            # Subcommand check failed
            if cli_val and cli_val.get("subcommand_check"):
                sc = cli_val["subcommand_check"]
                if not sc.get("valid", True):
                    return {
                        "triage_pass": 2,
                        "triage_status": "issue",
                        "confidence": 85,
                        "severity": "high",
                        "suggested_fix": f"Unknown subcommand '{sc['name']}'. "
                                         f"Known subcommands: {', '.join(sc.get('known_subcommands', [])[:10])}",
                    }

        # Configs: schema validation mismatches
        if category == "config":
            schema_val = results.get("schema_validation")
            if schema_val and schema_val.get("matched_schemas"):
                for schema_match in schema_val["matched_schemas"]:
                    doc_only = schema_match.get("keys_only_in_doc", [])
                    if doc_only:
                        overlap = schema_match.get("overlap_ratio", 0)
                        # Higher overlap = more confidence in the mismatch being real
                        confidence = int(70 + overlap * 15)
                        confidence = min(confidence, 85)
                        return {
                            "triage_pass": 2,
                            "triage_status": "issue",
                            "confidence": confidence,
                            "severity": "medium",
                            "suggested_fix": f"Keys not found in schema '{schema_match['schema_file']}': "
                                             f"{', '.join(doc_only[:10])}. "
                                             f"Overlap ratio: {overlap}",
                        }

        # File paths: not found + basename matches
        if category == "file_path":
            found = results.get("found", False)
            matches = results.get("matches", [])
            if not found:
                return {
                    "triage_pass": 2,
                    "triage_status": "issue",
                    "confidence": 45,
                    "severity": "medium",
                    "suggested_fix": "File path not found in any repository.",
                }
            # Has basename-only matches (no exact)
            has_exact = any(m.get("type") == "exact" for m in matches)
            has_basename = any(m.get("type") == "basename" for m in matches)
            if not has_exact and has_basename:
                basename_paths = [m.get("path", "") for m in matches if m.get("type") == "basename"]
                confidence = 75
                return {
                    "triage_pass": 2,
                    "triage_status": "issue",
                    "confidence": confidence,
                    "severity": "medium",
                    "suggested_fix": f"Exact path not found. File exists at: {', '.join(basename_paths[:5])}",
                }

        return None

    # ------------------------------------------------------------------
    # Pass 3 — Evidence-based analysis
    # ------------------------------------------------------------------

    def _pass3_evidence(self, item: dict, category: str, results: dict) -> dict:
        found = results.get("found", False)
        git_evidence = results.get("git_evidence", [])
        matches = results.get("matches", [])

        # Git evidence of renames/deprecation
        if git_evidence:
            evidence_text = "; ".join(e.get("context", "")[:80] for e in git_evidence[:3])
            # More evidence = higher confidence in there being a change
            confidence = min(70 + len(git_evidence) * 5, 90)
            severity = "medium"

            # If not found + git evidence => likely renamed/removed
            if not found:
                severity = "high"
                confidence = min(confidence + 5, 90)

            return {
                "triage_pass": 3,
                "triage_status": "needs-confirmation",
                "confidence": confidence,
                "severity": severity,
                "suggested_fix": f"Git evidence found: {evidence_text}",
            }

        # Partial matches
        if found and matches:
            # Check for identifier_ratio type matches with low ratios
            ratio_matches = [m for m in matches if m.get("type") == "identifier_ratio"]
            if ratio_matches:
                # Parse ratio from context string
                for rm in ratio_matches:
                    ctx = rm.get("context", "")
                    ratio_m = re.search(r"\(([0-9.]+)\)", ctx)
                    if ratio_m:
                        ratio = float(ratio_m.group(1))
                        if ratio < 0.5:
                            return {
                                "triage_pass": 3,
                                "triage_status": "needs-confirmation",
                                "confidence": int(50 + ratio * 28),
                                "severity": "medium",
                                "suggested_fix": f"Only partial match: {ctx}",
                            }

            # Found with good matches
            return {
                "triage_pass": 3,
                "triage_status": "verified",
                "confidence": 90,
                "severity": None,
                "suggested_fix": None,
            }

        # Not found, no evidence
        if not found:
            return {
                "triage_pass": 3,
                "triage_status": "needs-confirmation",
                "confidence": 40,
                "severity": "low",
                "suggested_fix": "No matches or evidence found in any repository.",
            }

        # Default: verified
        return {
            "triage_pass": 3,
            "triage_status": "verified",
            "confidence": 85,
            "severity": None,
            "suggested_fix": None,
        }

    # ------------------------------------------------------------------
    # Summary
    # ------------------------------------------------------------------

    @staticmethod
    def _build_summary(triaged: list[dict]) -> dict:
        total = len(triaged)
        issues = sum(1 for t in triaged if t.get("triage_status") == "issue")
        out_of_scope = sum(1 for t in triaged if t.get("triage_status") == "out-of-scope")
        verified = sum(1 for t in triaged if t.get("triage_status") == "verified")
        needs_confirmation = sum(1 for t in triaged if t.get("triage_status") == "needs-confirmation")

        high = sum(1 for t in triaged if t.get("severity") == "high")
        medium = sum(1 for t in triaged if t.get("severity") == "medium")
        low = sum(1 for t in triaged if t.get("severity") == "low")

        return {
            "total": total,
            "issues": issues,
            "out_of_scope": out_of_scope,
            "verified": verified,
            "needs_confirmation": needs_confirmation,
            "severity_high": high,
            "severity_medium": medium,
            "severity_low": low,
        }


# =============================================================================
# TechReferenceScanner  (NEW — anti-pattern + blast-radius scan)
# =============================================================================

class TechReferenceScanner:
    """Scans a documentation tree for anti-patterns and blast radius of triaged issues."""

    def __init__(self, *, verbose: bool = False) -> None:
        self.verbose = verbose

    def scan(self, triaged_data: dict, docs_dir: str) -> dict:
        triaged_results = triaged_data.get("triaged_results", [])
        scanned: list[dict] = []

        for item in triaged_results:
            scanned_item = self._scan_item(item, docs_dir)
            scanned.append(scanned_item)

        summary = self._build_summary(scanned)
        return {
            "scanned_results": scanned,
            "summary": summary,
            "discovered_schemas": triaged_data.get("discovered_schemas", []),
            "discovered_cli_definitions": triaged_data.get("discovered_cli_definitions", []),
        }

    def _scan_item(self, item: dict, docs_dir: str) -> dict:
        scanned = {**item}
        blast_radius: list[dict] = []

        status = item.get("triage_status", "")
        if status not in ("issue", "needs-confirmation"):
            scanned["blast_radius"] = []
            return scanned

        category = item.get("category", "")
        results = item.get("results", {})

        # Anti-pattern scan: look for specific problematic patterns in the doc tree
        anti_patterns = self._extract_anti_patterns(item, category, results)

        for pattern in anti_patterns:
            hits = self._grep_docs(docs_dir, pattern)
            for hit in hits:
                blast_radius.append({
                    "file": hit["file"],
                    "line": hit["line"],
                    "match": hit["match"],
                    "pattern": pattern,
                })

        # Blast radius scan: grep for the main reference pattern
        main_pattern = self._extract_main_pattern(item, category)
        if main_pattern:
            hits = self._grep_docs(docs_dir, main_pattern)
            for hit in hits:
                # Avoid duplicates
                key = (hit["file"], hit["line"])
                if not any((br["file"], br["line"]) == key for br in blast_radius):
                    blast_radius.append({
                        "file": hit["file"],
                        "line": hit["line"],
                        "match": hit["match"],
                        "pattern": main_pattern,
                    })

        scanned["blast_radius"] = blast_radius
        return scanned

    def _extract_anti_patterns(
        self, item: dict, category: str, results: dict
    ) -> list[str]:
        """Extract specific anti-pattern strings to search for in the doc tree."""
        patterns: list[str] = []

        if category == "command":
            cli_val = results.get("cli_validation")
            if cli_val:
                for flag in cli_val.get("unknown_flags", []):
                    patterns.append(re.escape(flag))
                sc = cli_val.get("subcommand_check")
                if sc and not sc.get("valid", True):
                    patterns.append(re.escape(sc["name"]))

        elif category == "config":
            schema_val = results.get("schema_validation")
            if schema_val:
                for sm in schema_val.get("matched_schemas", []):
                    for key in sm.get("keys_only_in_doc", []):
                        patterns.append(rf"\b{re.escape(key)}\b")

        return patterns

    def _extract_main_pattern(self, item: dict, category: str) -> str | None:
        """Extract the main search pattern for blast-radius scanning."""
        ref = item.get("reference", {})

        if category == "command":
            command = ref.get("command", "")
            if command:
                parts = _shell_split(command)
                if parts and parts[0] == "sudo":
                    parts = parts[1:]
                if parts:
                    return re.escape(parts[0])
        elif category == "api":
            name = ref.get("name", "")
            if name:
                return rf"\b{re.escape(name)}\b"
        elif category == "config":
            keys = ref.get("keys", [])
            if keys:
                # Search for the first key as representative
                return rf"\b{re.escape(keys[0])}\b"
        elif category == "file_path":
            path = ref.get("path", "")
            if path:
                return re.escape(path)
        elif category == "env_var":
            name = ref.get("name", "")
            if name:
                return rf"\b{re.escape(name)}\b"

        return None

    def _grep_docs(self, docs_dir: str, pattern: str) -> list[dict]:
        """Grep the docs directory for a pattern, returning file/line/match."""
        if not os.path.isdir(docs_dir):
            return []

        cmd = (
            f"grep -rn --include='*.adoc' --include='*.md' "
            f"-E {shlex.quote(pattern)} {shlex.quote(docs_dir)} 2>/dev/null"
        )
        try:
            result = subprocess.run(
                cmd, shell=True, capture_output=True, text=True, timeout=30
            )
            if not result.stdout:
                return []
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return []

        hits: list[dict] = []
        for line in result.stdout.splitlines():
            if not line:
                continue
            m = re.match(r"^(.+?):(\d+):(.*)$", line)
            if m:
                hits.append({
                    "file": m.group(1),
                    "line": int(m.group(2)),
                    "match": m.group(3).strip(),
                })
            if len(hits) >= 50:  # cap blast radius results
                break

        return hits

    @staticmethod
    def _build_summary(scanned: list[dict]) -> dict:
        total_issues = sum(
            1 for s in scanned
            if s.get("triage_status") in ("issue", "needs-confirmation")
        )
        total_blast_radius = sum(len(s.get("blast_radius", [])) for s in scanned)
        files_affected: set[str] = set()
        for s in scanned:
            for br in s.get("blast_radius", []):
                files_affected.add(br["file"])

        return {
            "total_issues_scanned": total_issues,
            "total_blast_radius_hits": total_blast_radius,
            "files_affected": len(files_affected),
        }


# =============================================================================
# Utility functions
# =============================================================================

def _shell_split(cmd: str) -> list[str]:
    """Split a command string into parts, handling quotes.

    Uses shlex.split with fallback to simple splitting on failure.
    """
    try:
        return shlex.split(cmd)
    except ValueError:
        # Fallback for unbalanced quotes etc.
        return cmd.split()


def _load_json_file(path: str) -> dict:
    """Load and parse a JSON file."""
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def _write_json(data: dict, output_path: str | None) -> None:
    """Write JSON to a file or stdout."""
    json_str = json.dumps(data, indent=2, ensure_ascii=False)
    if output_path:
        Path(output_path).parent.mkdir(parents=True, exist_ok=True)
        Path(output_path).write_text(json_str + "\n", encoding="utf-8")
    else:
        print(json_str)


# =============================================================================
# CLI subcommand handlers
# =============================================================================

def cmd_extract(args: argparse.Namespace) -> None:
    """Handle the 'extract' subcommand."""
    if not args.files:
        print("ERROR: No input files specified", file=sys.stderr)
        sys.exit(1)

    extractor = TechReferenceExtractor(verbose=args.verbose)
    extractor.extract_from_files(args.files)
    output = extractor.build_output()

    if args.output:
        _write_json(output, args.output)
        refs = output["references"]
        print(f"Extracted technical references to {args.output}")
        print(f"  Commands: {len(refs['commands'])}")
        print(f"  Code blocks: {len(refs['code_blocks'])}")
        print(f"  APIs: {len(refs['apis'])}")
        print(f"  Configs: {len(refs['configs'])}")
        print(f"  File paths: {len(refs['file_paths'])}")
    else:
        _write_json(output, None)


def cmd_search(args: argparse.Namespace) -> None:
    """Handle the 'search' subcommand."""
    empty_output = {"search_results": [], "summary": {"total": 0, "found": 0, "not_found": 0}}

    if not os.path.isfile(args.refs_json):
        print(f"ERROR: References file not found: {args.refs_json}", file=sys.stderr)
        sys.exit(1)

    try:
        refs_data = _load_json_file(args.refs_json)
    except (json.JSONDecodeError, UnicodeDecodeError) as exc:
        print(f"ERROR: Invalid JSON in {args.refs_json}: {exc}", file=sys.stderr)
        sys.exit(1)

    if not args.repo_paths:
        print("ERROR: No repository paths specified", file=sys.stderr)
        sys.exit(1)

    for rp in args.repo_paths:
        if not os.path.isdir(rp):
            print(f"WARNING: Repository path not found: {rp}", file=sys.stderr)

    valid_repos = [rp for rp in args.repo_paths if os.path.isdir(rp)]
    if not valid_repos:
        print("ERROR: No valid repository paths found", file=sys.stderr)
        sys.exit(1)

    searcher = TechReferenceSearcher(verbose=args.verbose)
    output = searcher.search(refs_data, valid_repos)

    if args.output:
        _write_json(output, args.output)
        s = output["summary"]
        print(f"Search completed: {args.output}")
        print(f"  Total references: {s['total']}")
        print(f"  Found: {s['found']}")
        print(f"  Not found: {s['not_found']}")
    else:
        _write_json(output, None)


def cmd_triage(args: argparse.Namespace) -> None:
    """Handle the 'triage' subcommand."""
    if not os.path.isfile(args.search_results_json):
        print(f"ERROR: Search results file not found: {args.search_results_json}", file=sys.stderr)
        sys.exit(1)

    try:
        search_data = _load_json_file(args.search_results_json)
    except (json.JSONDecodeError, UnicodeDecodeError) as exc:
        print(f"ERROR: Invalid JSON in {args.search_results_json}: {exc}", file=sys.stderr)
        sys.exit(1)

    triager = TechReferenceTriage(verbose=args.verbose)
    output = triager.triage(search_data)

    if args.output:
        _write_json(output, args.output)
        s = output["summary"]
        print(f"Triage completed: {args.output}")
        print(f"  Total: {s['total']}")
        print(f"  Issues: {s['issues']}")
        print(f"  Out-of-scope: {s['out_of_scope']}")
        print(f"  Verified: {s['verified']}")
        print(f"  Needs confirmation: {s['needs_confirmation']}")
    else:
        _write_json(output, None)


def cmd_scan(args: argparse.Namespace) -> None:
    """Handle the 'scan' subcommand."""
    if not os.path.isfile(args.triaged_json):
        print(f"ERROR: Triaged results file not found: {args.triaged_json}", file=sys.stderr)
        sys.exit(1)

    if not os.path.isdir(args.docs_dir):
        print(f"ERROR: Docs directory not found: {args.docs_dir}", file=sys.stderr)
        sys.exit(1)

    try:
        triaged_data = _load_json_file(args.triaged_json)
    except (json.JSONDecodeError, UnicodeDecodeError) as exc:
        print(f"ERROR: Invalid JSON in {args.triaged_json}: {exc}", file=sys.stderr)
        sys.exit(1)

    scanner = TechReferenceScanner(verbose=args.verbose)
    output = scanner.scan(triaged_data, args.docs_dir)

    if args.output:
        _write_json(output, args.output)
        s = output["summary"]
        print(f"Scan completed: {args.output}")
        print(f"  Issues scanned: {s['total_issues_scanned']}")
        print(f"  Blast radius hits: {s['total_blast_radius_hits']}")
        print(f"  Files affected: {s['files_affected']}")
    else:
        _write_json(output, None)


def cmd_review(args: argparse.Namespace) -> None:
    """Handle the 'review' subcommand — chains extract, search, triage, scan."""
    if not args.files:
        print("ERROR: No input files specified", file=sys.stderr)
        sys.exit(1)

    if not args.repos:
        print("ERROR: No repository paths specified (use --repos)", file=sys.stderr)
        sys.exit(1)

    valid_repos = [rp for rp in args.repos if os.path.isdir(rp)]
    if not valid_repos:
        print("ERROR: No valid repository paths found", file=sys.stderr)
        sys.exit(1)

    verbose = args.verbose

    # Phase 1: Extract
    if verbose:
        print("[REVIEW] Phase 1: Extracting technical references...", file=sys.stderr)
    extractor = TechReferenceExtractor(verbose=verbose)
    extractor.extract_from_files(args.files)
    extract_output = extractor.build_output()

    refs = extract_output["references"]
    if verbose:
        print(
            f"[REVIEW]   Commands: {len(refs['commands'])}, "
            f"Code blocks: {len(refs['code_blocks'])}, "
            f"APIs: {len(refs['apis'])}, "
            f"Configs: {len(refs['configs'])}, "
            f"File paths: {len(refs['file_paths'])}, "
            f"Env vars: {len(refs.get('env_vars', []))}",
            file=sys.stderr,
        )

    # Phase 2: Search
    if verbose:
        print("[REVIEW] Phase 2: Searching repositories...", file=sys.stderr)
    searcher = TechReferenceSearcher(verbose=verbose)
    search_output = searcher.search(extract_output, valid_repos)

    s = search_output["summary"]
    if verbose:
        print(
            f"[REVIEW]   Total: {s['total']}, Found: {s['found']}, Not found: {s['not_found']}",
            file=sys.stderr,
        )

    # Phase 3: Triage
    if verbose:
        print("[REVIEW] Phase 3: Triaging results...", file=sys.stderr)
    triager = TechReferenceTriage(verbose=verbose)
    triage_output = triager.triage(search_output)

    ts = triage_output["summary"]
    if verbose:
        print(
            f"[REVIEW]   Issues: {ts['issues']}, Verified: {ts['verified']}, "
            f"Needs confirmation: {ts['needs_confirmation']}",
            file=sys.stderr,
        )

    # Phase 4: Scan (only if docs_dir is provided)
    if args.docs_dir and os.path.isdir(args.docs_dir):
        if verbose:
            print("[REVIEW] Phase 4: Scanning doc tree for blast radius...", file=sys.stderr)
        scanner = TechReferenceScanner(verbose=verbose)
        scan_output = scanner.scan(triage_output, args.docs_dir)

        ss = scan_output["summary"]
        if verbose:
            print(
                f"[REVIEW]   Blast radius hits: {ss['total_blast_radius_hits']}, "
                f"Files affected: {ss['files_affected']}",
                file=sys.stderr,
            )

        final_output = scan_output
    else:
        if verbose:
            print("[REVIEW] Phase 4: Skipped (no --docs-dir provided)", file=sys.stderr)
        final_output = triage_output

    # Add extraction summary to final output
    final_output["extraction_summary"] = extract_output["summary"]
    final_output["search_summary"] = search_output["summary"]

    if args.output:
        _write_json(final_output, args.output)
        print(f"Review completed: {args.output}")
    else:
        _write_json(final_output, None)


# =============================================================================
# CLI entry point
# =============================================================================

def main() -> None:
    parser = argparse.ArgumentParser(
        prog="tech_references",
        description="Extract, search, triage, scan, and review technical references in documentation.",
    )
    parser.add_argument("-v", "--verbose", action="store_true", help="Enable debug output")
    subparsers = parser.add_subparsers(dest="command", help="Subcommand to run")

    # --- extract ---
    p_extract = subparsers.add_parser(
        "extract",
        help="Extract technical references from AsciiDoc/Markdown files",
    )
    p_extract.add_argument("files", nargs="*", help="Files or directories to extract from")
    p_extract.add_argument("-o", "--output", help="Write JSON to file instead of stdout")
    p_extract.set_defaults(func=cmd_extract)

    # --- search ---
    p_search = subparsers.add_parser(
        "search",
        help="Search code repositories for evidence matching extracted references",
    )
    p_search.add_argument("refs_json", help="Path to extracted references JSON")
    p_search.add_argument("repo_paths", nargs="*", help="Paths to code repositories")
    p_search.add_argument("-o", "--output", help="Write JSON to file instead of stdout")
    p_search.set_defaults(func=cmd_search)

    # --- triage ---
    p_triage = subparsers.add_parser(
        "triage",
        help="Deterministic triage of search results",
    )
    p_triage.add_argument("search_results_json", help="Path to search results JSON")
    p_triage.add_argument("-o", "--output", help="Write JSON to file instead of stdout")
    p_triage.set_defaults(func=cmd_triage)

    # --- scan ---
    p_scan = subparsers.add_parser(
        "scan",
        help="Anti-pattern and blast-radius scan across a doc tree",
    )
    p_scan.add_argument("triaged_json", help="Path to triaged results JSON")
    p_scan.add_argument("--docs-dir", required=True, help="Path to documentation directory")
    p_scan.add_argument("-o", "--output", help="Write JSON to file instead of stdout")
    p_scan.set_defaults(func=cmd_scan)

    # --- review ---
    p_review = subparsers.add_parser(
        "review",
        help="Chain all phases: extract -> search -> triage -> scan",
    )
    p_review.add_argument("files", nargs="*", help="Files or directories to review")
    p_review.add_argument("--repos", nargs="+", required=True, help="Paths to code repositories")
    p_review.add_argument("--docs-dir", help="Path to documentation directory (enables scan phase)")
    p_review.add_argument("-o", "--output", help="Write JSON to file instead of stdout")
    p_review.set_defaults(func=cmd_review)

    args = parser.parse_args()

    if args.command is None:
        parser.print_help()
        sys.exit(1)

    args.func(args)


if __name__ == "__main__":
    main()
