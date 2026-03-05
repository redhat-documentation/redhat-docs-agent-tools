# Contributing

## Creating a new plugin

1. Create a directory under `plugins/` with your plugin name (use kebab-case):

    ```
    plugins/my-plugin/
    ├── .claude-plugin/
    │   └── plugin.json
    ├── commands/
    │   └── my-command.md
    └── README.md
    ```

2. Define `plugin.json` with metadata:

    ```json
    {
      "name": "my-plugin",
      "version": "1.0.0",
      "description": "What this plugin does",
      "author": "github.com/your-username"
    }
    ```

3. Add commands as Markdown files in `commands/` with frontmatter:

    ```markdown
    ---
    description: "What this command does"
    argument-hint: "[optional-args]"
    ---

    # Name
    ...
    ```

4. Use the `hello-world` plugin as a reference implementation.

## Versioning

Plugins use [semantic versioning](https://semver.org/). Bump the version in `plugin.json` when making changes:

- **Patch** (1.0.x): Bug fixes, documentation updates
- **Minor** (1.x.0): New commands, non-breaking changes
- **Major** (x.0.0): Breaking changes to existing commands

## Auto-generated docs

The following files are auto-generated and should not be edited manually:

- `PLUGINS.md`
- `docs/plugins.md`
- `docs/installation.md`

These are regenerated on every merge to main via CI.

## Code review

All changes require a pull request with at least one approval.
