# Red Hat Docs Agent Tools

A collection of Claude Code plugins, skills, and agent tools for Red Hat documentation workflows.

## Repository structure

```
plugins/<name>/
  .claude-plugin/plugin.json   # Plugin metadata (name, version, description)
  commands/<command>.md         # Command definitions with frontmatter
  skills/<skill>.md             # Skill definitions (optional)
  README.md                    # Plugin documentation
```

## Development commands

- `make update` - Regenerate PLUGINS.md and docs pages from plugin metadata
- `make serve` - Start local Zensical dev server
- `make build` - Build the Zensical site

## Contributing rules

- Use kebab-case for plugin and command names
- Each plugin must have a `.claude-plugin/plugin.json` with name, version, description
- Bump version in plugin.json when making changes
- Auto-generated files (PLUGINS.md, docs/plugins.md, docs/plugins/, docs/installation.md) are gitignored and built by CI only. Run `make update` locally to preview them
- Use the hello-world plugin as a reference implementation
- Use `.work/` directory for temporary files (gitignored)
