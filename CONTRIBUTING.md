# Contributing to Red Hat Docs Agent Tools

## Getting started

1. Fork and clone the repository
2. Create a new branch for your changes
3. Follow the plugin structure in `plugins/hello-world/` as a reference

## Plugin structure

Each plugin lives under `plugins/<plugin-name>/` and must contain:

- `.claude-plugin/plugin.json` - Plugin metadata
- `commands/` - Command definitions as Markdown files
- `README.md` - Plugin documentation

## Versioning

Plugins follow [semver](https://semver.org/). Bump the version in `plugin.json` with every change:

- **Patch**: Bug fixes, docs updates
- **Minor**: New commands, non-breaking changes
- **Major**: Breaking changes

## Auto-generated files

These files are built by CI on every merge to main and are gitignored (not tracked in source):

- `PLUGINS.md`
- `docs/plugins.md`
- `docs/plugins/*.md`
- `docs/installation.md`

Run `make update` locally to generate and preview them.

## Local development

```bash
# Regenerate docs
make update

# Start local site
make serve

# Build site
make build
```

## Pull requests

All changes require a pull request with review before merging.
