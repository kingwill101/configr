# Terminal UI

Configr uses **Artisanal** for styled console output, task widgets with
spinner animations, progress bars, and interactive prompts.

## Output Style

All output uses Artisanal's `Console` API:

| Method | Purpose |
|--------|---------|
| `title()` | Section headers |
| `section()` | Sub-section headers |
| `task()` | Block operations with spinner → DONE/FAIL |
| `success()` | Success messages |
| `error()` | Error messages |
| `warn()` | Warnings |
| `info()` | Info and status messages |

## UI Handlers

Configr has two UI handlers that share the same visual widgets. The only
difference is how they handle user prompts:

### InteractiveHandler (default)

- Uses `Console(interactive: true)` — prompts the user for input
- Renders block operations as `task()` widgets (spinner → DONE/FAIL)
- Shows status updates, progress, and resource events as styled text
- Dispatches `UserInputRequiredEvent` for interactive prompts

### CLIHandler (`--no-interaction` / `-n`)

- Uses `Console(interactive: false)` — auto-answers prompts with defaults
- Same visual widgets as interactive mode (task spinners, styled text)
- Never blocks on user input

## Block Operations

During `apply` / `rollback`, each block operation is displayed with a
spinner that animates while the block executes, then resolves to a
status label:

```
  Downloading from https://get.docker.com/ ....................... DONE
  Copying docker.sh → docker.copied.sh .......................... DONE
  Deleting docker.sh ............................................ DONE
```

## Event Bus

The UI handlers subscribe to a shared `EventBus` that carries structured
events from block execution:

| Event | Purpose |
|-------|---------|
| `StartedEvent` | Triggers a new task widget with spinner |
| `CompletedEvent` | Completes the task widget as DONE |
| `FailedEvent` | Completes the task widget as FAIL |
| `StatusUpdateEvent` | Info/warning/error status messages |
| `ProgressEvent` | Progress bar updates (suppressed when task widget active) |
| `DownloadProgressEvent` | Download progress bar (suppressed when task widget active) |
| `ResourceStartedEvent` | Resource-level operation started |
| `ResourceCompletedEvent` | Resource-level operation completed |
| `UserInputRequiredEvent` | Prompt user for input |
| `WaitForUserEvent` | Pause and wait for user |
| `RetryEvent` | Retry attempt in progress |
| `PerformanceEvent` | Performance metrics (debug) |
| `SecurityEvent` | Security-related notifications |

Both handlers process the same events with the same visual output —
prompt events are the only divergence.

## Verbosity

| Level | Shows |
|-------|-------|
| Default | Block-level task widgets, status updates, errors |
| `-v` / `--verbose` | Progress bars, retry attempts, plugin actions |
| `-d` / `--debug` | Performance metrics, debug messages |
| `-q` / `--quiet` | No output (suppressed) |
