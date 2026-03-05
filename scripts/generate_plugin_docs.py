#!/usr/bin/env python3
"""Generate PLUGINS.md and docs pages from plugin metadata and commands."""

import json
import os
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PLUGINS_DIR = REPO_ROOT / "plugins"
DOCS_DIR = REPO_ROOT / "docs"


def parse_frontmatter(text: str) -> dict:
    """Parse YAML-style frontmatter from a markdown file."""
    meta = {}
    if not text.startswith("---"):
        return meta
    end = text.find("---", 3)
    if end == -1:
        return meta
    for line in text[3:end].strip().splitlines():
        if ":" in line:
            key, val = line.split(":", 1)
            meta[key.strip()] = val.strip().strip('"')
    return meta


def load_plugins() -> list[dict]:
    """Scan plugins/ and return metadata for each plugin."""
    plugins = []
    if not PLUGINS_DIR.is_dir():
        return plugins

    for plugin_dir in sorted(PLUGINS_DIR.iterdir()):
        plugin_json = plugin_dir / ".claude-plugin" / "plugin.json"
        if not plugin_json.is_file():
            continue

        with open(plugin_json) as f:
            meta = json.load(f)

        commands = []
        commands_dir = plugin_dir / "commands"
        if commands_dir.is_dir():
            for cmd_file in sorted(commands_dir.glob("*.md")):
                cmd_text = cmd_file.read_text()
                fm = parse_frontmatter(cmd_text)
                commands.append({
                    "name": cmd_file.stem,
                    "description": fm.get("description", ""),
                    "argument_hint": fm.get("argument-hint", ""),
                })

        skills = []
        skills_dir = plugin_dir / "skills"
        if skills_dir.is_dir():
            for skill_file in sorted(skills_dir.glob("*.md")):
                skill_text = skill_file.read_text()
                fm = parse_frontmatter(skill_text)
                skills.append({
                    "name": skill_file.stem,
                    "description": fm.get("description", ""),
                })

        plugins.append({
            "name": meta.get("name", plugin_dir.name),
            "version": meta.get("version", "0.0.0"),
            "description": meta.get("description", ""),
            "commands": commands,
            "skills": skills,
        })

    return plugins


def generate_plugins_md(plugins: list[dict]) -> str:
    """Generate the PLUGINS.md content."""
    lines = [
        "# Plugins",
        "",
        "> This file is auto-generated. Do not edit manually.",
        "> Run `make update` or merge to main to regenerate.",
        "",
    ]

    for p in plugins:
        lines.append(f"## {p['name']} (v{p['version']})")
        lines.append("")
        lines.append(p["description"])
        lines.append("")

        if p["commands"]:
            lines.append("### Commands")
            lines.append("")
            lines.append("| Command | Description |")
            lines.append("|---------|-------------|")
            for cmd in p["commands"]:
                hint = f" {cmd['argument_hint']}" if cmd["argument_hint"] else ""
                lines.append(
                    f"| `/{p['name']}:{cmd['name']}{hint}` | {cmd['description']} |"
                )
            lines.append("")

        if p["skills"]:
            lines.append("### Skills")
            lines.append("")
            lines.append("| Skill | Description |")
            lines.append("|-------|-------------|")
            for skill in p["skills"]:
                lines.append(f"| `{skill['name']}` | {skill['description']} |")
            lines.append("")

    return "\n".join(lines)


def generate_plugin_detail_page(plugin: dict) -> str:
    """Generate a per-plugin detail page at docs/plugins/<name>.md."""
    p = plugin
    lines = [
        f"# {p['name']}",
        "",
        f"> **Version:** {p['version']}",
        "",
        p["description"],
        "",
        "## Installation",
        "",
        "```",
        f"/plugin install {p['name']}@redhat-docs-agent-tools",
        "```",
        "",
    ]

    if p["commands"]:
        lines.append("## Commands")
        lines.append("")
        for cmd in p["commands"]:
            hint = f" {cmd['argument_hint']}" if cmd["argument_hint"] else ""
            lines.append(f"### `/{p['name']}:{cmd['name']}{hint}`")
            lines.append("")
            lines.append(cmd["description"])
            lines.append("")

    if p["skills"]:
        lines.append("## Skills")
        lines.append("")
        for skill in p["skills"]:
            lines.append(f"### `{skill['name']}`")
            lines.append("")
            lines.append(skill["description"])
            lines.append("")

    lines.extend([
        "## Update",
        "",
        "```",
        "/plugin marketplace update redhat-docs-agent-tools",
        "```",
    ])

    return "\n".join(lines)


def generate_docs_plugins_index(plugins: list[dict]) -> str:
    """Generate the docs/plugins.md card grid index page."""
    lines = [
        "# Plugins",
        "",
        "Browse available plugins. Click a card to view installation and usage details.",
        "",
        "> This page is auto-generated on every merge to main.",
        "",
        '<div class="grid cards" markdown>',
        "",
    ]

    for p in plugins:
        cmd_count = len(p["commands"])
        skill_count = len(p["skills"])
        summary_parts = []
        if cmd_count:
            summary_parts.append(f"{cmd_count} command{'s' if cmd_count != 1 else ''}")
        if skill_count:
            summary_parts.append(f"{skill_count} skill{'s' if skill_count != 1 else ''}")
        summary = " | ".join(summary_parts) if summary_parts else "Plugin"

        lines.append(f"-   :material-puzzle-outline:{{ .lg .middle }} **{p['name']}**")
        lines.append("")
        lines.append("    ---")
        lines.append("")
        lines.append(f"    {p['description']}")
        lines.append("")
        lines.append(f"    **v{p['version']}** | {summary}")
        lines.append("")
        lines.append(f"    [:octicons-arrow-right-24: Details](plugins/{p['name']}.md)")
        lines.append("")

    lines.append("</div>")

    return "\n".join(lines)


def generate_installation_page(plugins: list[dict]) -> str:
    """Generate the docs/installation.md page."""
    lines = [
        "# Installation",
        "",
        "> This page is auto-generated on every merge to main.",
        "",
        "## Prerequisites",
        "",
        "- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI installed",
        "",
        "## Install from marketplace",
        "",
        "Add the plugin marketplace to your Claude Code configuration:",
        "",
        "```",
        "/plugin marketplace add aireilly/redhat-docs-agent-tools",
        "```",
        "",
        "Then install any plugin:",
        "",
        "```",
        "/plugin install <plugin-name>@redhat-docs-agent-tools",
        "```",
        "",
        "## Available plugins",
        "",
        "| Plugin | Version | Description |",
        "|--------|---------|-------------|",
    ]

    for p in plugins:
        lines.append(f"| {p['name']} | {p['version']} | {p['description']} |")

    lines.append("")
    lines.append("## Update plugins")
    lines.append("")
    lines.append("```")
    lines.append("/plugin marketplace update redhat-docs-agent-tools")
    lines.append("```")

    return "\n".join(lines)


def main():
    plugins = load_plugins()

    # Write PLUGINS.md at repo root
    plugins_md = generate_plugins_md(plugins)
    (REPO_ROOT / "PLUGINS.md").write_text(plugins_md)
    print(f"Generated PLUGINS.md ({len(plugins)} plugins)")

    # Write docs pages
    DOCS_DIR.mkdir(exist_ok=True)

    # Card grid index page
    (DOCS_DIR / "plugins.md").write_text(generate_docs_plugins_index(plugins))
    print("Generated docs/plugins.md (card grid)")

    # Per-plugin detail pages
    plugins_pages_dir = DOCS_DIR / "plugins"
    plugins_pages_dir.mkdir(exist_ok=True)
    for p in plugins:
        page_path = plugins_pages_dir / f"{p['name']}.md"
        page_path.write_text(generate_plugin_detail_page(p))
        print(f"Generated docs/plugins/{p['name']}.md")

    (DOCS_DIR / "installation.md").write_text(generate_installation_page(plugins))
    print("Generated docs/installation.md")


if __name__ == "__main__":
    main()
