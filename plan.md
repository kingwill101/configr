# Configr v2 Migration Plan

## Why v2?

Configr v1.0.0 has significant architectural debt that limits its utility as both a CLI tool and a library:

- **No public library API**: `lib/configr.dart` returns `42` — other Dart packages cannot consume configr programmatically
- **Singleton abuse**: `ConfigManager`, `EventBus`, `PluginRegistry`, `PluginManager` all use global singletons, making testing brittle and state leaks inevitable
- **Weak typing throughout**: Module state is `Map<String, dynamic>`, action types are raw strings matched in switch cases, resource types are string constants
- **Dead plugin system**: `PluginManager` and `PluginRegistry` have full scaffolding but `load()`/`init()` are TODO stubs
- **Format lock-in**: i3config format is the only supported format despite YAML being declared as a dependency and planned support
- **No barrel exports**: Every file imports by direct path with no clean public API surface

## Goals

- Deliver a proper Dart library (`package:configr`) with a clean public API
- Eliminate global singletons in favor of dependency injection
- Support multiple config formats (i3, YAML, JSON) via a unified reader/writer interface
- Strengthen types for actions, modules, resources, and state
- Make the plugin system actually functional
- Keep the CLI as a thin consumer of the library (not the primary API)

## Key Decisions

- **Console UI**: Replace `interact` with `artisanal` (Lip Gloss styling, Bubble Tea TUI framework, rich Console I/O)
- **CLI framework**: Replace manual `args` CommandRunner with `artisanal`'s built-in `CommandRunner` (package:artisanal/args.dart)
- **Interactive mode**: Rewrite `InteractiveHandler` using `artisanal`'s TUI runtime for real-time progress, spinners, tables, and prompts
- **Format support**: i3 config stays default; YAML and JSON added alongside via `ConfigReader`/`ConfigWriter` abstraction

## Non-Goals

- Rewrite every resource module — keep existing `ResourceModule` implementations working with minimal changes
- Change the config file syntax — i3 format stays; we add support for other formats alongside it
- Remove rollback or lockfile functionality — these are core features, just better typed
- Full OpenSpec spec coverage — we'll add specs incrementally as we touch each capability

## Phases

### Phase A: Library API Foundation

Introduce a proper `package:configr` library surface.

- [ ] A.1 Replace `lib/configr.dart` with a barrel export file exposing all public types
- [ ] A.2 Audit all `lib/src/` files and make `export` selective (hide internals)
- [ ] A.3 Move CLI-only code (`bin/`, CLI handlers, CommandRunner) into a `cli/` subdirectory separate from the library
- [ ] A.4 Fix spelling: rename `privellage_escallation.dart` → `privilege_escalation.dart`, update all references
- [ ] A.5 Update `pubspec.yaml` description from `"A sample command-line application"` to something meaningful
- [ ] A.6 Verify `dart doc` generates clean documentation for the public API

### Phase B: Dependency Injection

Break the singleton pattern so configr can be consumed programmatically with clear ownership.

- [ ] B.1 Define `ConfigrConfig` class (hold options, FS, escalation, UI handler, event bus)
- [ ] B.2 `ConfigManager` accepts `ConfigrConfig` via constructor instead of relying on `_instance`
- [ ] B.3 `EventBus` accepts an optional `StreamController` via constructor (no singleton factory)
- [ ] B.4 `PluginRegistry` / `PluginManager` accept their dependencies (event bus, FS, config)
- [ ] B.5 Remove top-level `eventBus` variable and `emitEvent()` function; route events through `ConfigrConfig`
- [ ] B.6 Update `bin/main.dart` to wire up dependencies and pass `ConfigrConfig` to `ConfigManager`
- [ ] B.7 Update test helper to construct isolated `ConfigrConfig` per test (no shared global state)

### Phase C: Config Format Abstraction

Support multiple config formats through a common interface.

- [ ] C.1 Define `ConfigReader` abstract class (parse → `Config`)
- [ ] C.2 Define `ConfigWriter` abstract class (`Config` → string)
- [ ] C.3 Extract existing i3 parser/serializer into `I3ConfigReader` and `I3ConfigWriter`
- [ ] C.4 Implement `YamlConfigReader` and `YamlConfigWriter` using the `yaml` package (already a dependency)
- [ ] C.5 Implement `JsonConfigReader` and `JsonConfigWriter` (already partially done in `lib/utils/config.dart`)
- [ ] C.6 Create `ConfigFormatRegistry` that detects format by file extension / content heuristic
- [ ] C.7 Update `loadConfig()` / `updateConfig()` / `exportConfiguration()` to use the registry
- [ ] C.8 Keep i3 as the default format for new configs; no breaking change to existing config files

### Phase D: Stronger Types

Replace stringly-typed and `Map<String, dynamic>` patterns with proper types.

- [ ] D.1 Define `ActionType` sealed class/enum replacing raw action-type strings
- [ ] D.2 Define `ResourceType` sealed class replacing `'file'` / `'directory'` string constants
- [ ] D.3 Define `ModuleState` typed class (not `Map<String, dynamic>`) with per-action-type subclasses
- [ ] D.4 Update `ResourceModule.execute()` return type and `saveState()` signature
- [ ] D.5 Replace `getModuleForAction()` switch with a proper registry that maps `ActionType` → `ResourceModule` factory
- [ ] D.6 Add `ModuleState` serialization/deserialization in `LockfileData`
- [ ] D.7 Migrate existing modules one at a time (backup, copy, delete, permissions, symlink, etc.)

### Phase E: Plugin System

Ship a working plugin system alongside the existing built-in modules.

- [ ] E.1 Define `Plugin` abstract class with `init(ConfigrConfig)` and lifecycle methods
- [ ] E.2 Implement `PluginLoader` that discovers and loads plugins from a configurable directory
- [ ] E.3 Implement `PluginIsolate` execution for out-of-process plugins (already scaffolded, needs wiring)
- [ ] E.4 Wire `PluginManager.loadAll()` into the `ConfigManager.init()` flow
- [ ] E.5 Add `--plugin-dir` CLI flag and `ConfigrConfig.pluginDirs` configuration
- [ ] E.6 Write integration test for a minimal plugin that registers a custom `ActionType`

### Phase F: Artisanal Console UI

Replace the `interact`-based CLI with a rich `artisanal`-powered console experience.

- [ ] F.1 Replace `interact` dependency with `artisanal` in `pubspec.yaml`
- [ ] F.2 Rewrite `CliHandler` to use `artisanal` `Console` for styled output (tables, spinners, progress bars, task runners)
- [ ] F.3 Rewrite `InteractiveHandler` using `artisanal`'s Bubble Tea TUI runtime (Model/Msg/Cmd event loop) for real-time interactive workflows
- [ ] F.4 Migrate from `args` CommandRunner to `artisanal`'s `CommandRunner` (`package:artisanal/args.dart`) with styled help output
- [ ] F.5 Add styled status indicators, progress spinners during resource operations, and summary tables on completion
- [ ] F.6 Keep `base_handler.dart` as the abstract interface; `artisanal` implementations live in `bin/ui/`

### Phase G: CLI Library Separation

Refine the CLI to be a thin consumer of `package:configr`.

- [ ] G.1 Split `commands/` into library-level command models and CLI-specific `CommandRunner` bindings
- [ ] G.2 `BaseCommand.execute()` receives a `ConfigrConfig` instance instead of calling `ConfigManager.instance`
- [ ] G.3 Remove CLI-specific imports from `lib/` (ui handlers, command runners stay in `bin/`)
- [ ] G.4 Verify `dart run configr` still works identically to v1
- [ ] G.5 Verify `dart doc` on the library only shows public API (no CLI internals)

### Phase H: Watch & Live Reload

Add file watching for auto-reapply on config changes.

- [ ] H.1 Add `watch` dependency (or use `dart:io` `FileWatcher`)
- [ ] H.2 Implement `ConfigWatcher` that monitors config file for changes
- [ ] H.3 Integrate with `ConfigManager` to auto-reapply on change
- [ ] H.4 Add `configr watch` CLI command
- [ ] H.5 `configr apply` gains `--watch` flag

## Migration Strategy

### Branching
- Work on a `v2` branch (not `main`) until Phase D is complete
- Merge Phases A–D sequentially into `v2`, then merge `v2` → `main` as a single release (v2.0.0)
- Phases E–H can be shipped as v2.1.0, v2.2.0, etc.

### Backward Compatibility
- All v1 config files (i3 format) continue to work unmodified
- `ConfigManager` retains a static backward-compat factory that creates an isolated instance
- v1 imports continue to work via re-exports (deprecate in v3)

### Testing
- Every phase must not regress existing tests
- Write new tests for the abstraction layers (ConfigReader, ConfigWriter, ActionType registry)
- Plugin system tests use in-memory isolates (no real file system)

## Risks

| Risk | Mitigation |
|------|------------|
| Phase B (DI) breaks many call sites | Do in one focused pass with a clear `ConfigrConfig` contract; update all call sites before merging |
| Format abstraction (Phase C) is over-engineered | Keep `ConfigReader`/`ConfigWriter` minimal (just parse + serialize); no AST transformation layer yet |
| Plugin system never becomes useful | Ship with 1-2 built-in examples so the extension point is validated; defer deep security concerns |
| Existing OpenSpec changes conflict | Review `enhance-configr-modules`, `refactor-ui-experience`, `add-privilege-escalation-persistence` and ensure v2 absorbs their intent; retire them as superseded |
