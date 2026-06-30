## next

### v2 ActionBlock Pipeline

- **TemplateBlock**: Standalone flat `template { }` block support and in-memory template rendering inside `resource { }`. When nested under a resource, templates render in-memory and store the result in the context — child actions (e.g. `copy { }`) inherit the rendered content instead of reading from disk.
- **Package blocks**: All 11 package manager blocks (`apt`, `brew`, `dnf`, `docker`, `flatpak`, `npm`, `pacman`, `pamac`, `pip`, `snap`, `yum`) registered as ActionBlocks under `actions { }`. Package operations supported: `install`, `uninstall`, `upgrade`, `reinstall` with `skip_if_installed` and `update_cache`.
- **Package CLI**: `configr package list/update/upgrade/lock` subcommands discover blocks via the snapshot pipeline (`parseAndCollect`) instead of manual AST parsing — eliminating the hardcoded `_knownPackageBlockTypes` list.
- **Bug fix**: `packageManager` field in `BasePackageBlock` now defaults to `blockType` instead of hardcoded `'apt'`.
- **UI**: `CopyBlock._writeRenderedContent()` emits a `StartedEvent` so the UI handler displays a proper formatted status line with timing.
- **Template vars**: `TemplateVarsBlockHandler` uses `context.options['templateVars']` (consistent with how block handlers store data), not `context.getVariable('template_vars')`.

## 1.0.0

- Initial version.
