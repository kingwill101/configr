# Terminal UI

Configr uses the **Artisanal** framework for styled console output,
progress indicators, and interactive prompts.

## Output Style

All output uses Artisanal's `io` API:

| Method | Purpose | Example |
|--------|---------|---------|
| `io.title()` | Section headers | `Apply Configuration (v2)` |
| `io.section()` | Sub-sections | `Configuration parsed successfully` |
| `io.success()` | Success messages | `✔ download_0: Download completed` |
| `io.error()` | Error messages | `✘ copy_1: Copy failed` |
| `io.warn()` | Warnings | `⚠ Config unchanged since last apply` |
| `io.info()` | Info messages | `ℹ copy_1: Copying file…` |
| `io.line()` | Regular output | `▶ download_0: Starting download` |

## Block-level Progress

During apply/rollback, events from the pipeline are displayed:

```
▶ download_0: Starting download from https://get.docker.com/
✔ download_0: Download completed in 562ms
▶ copy_1: Starting copy of docker.sh to docker.copied.sh
✔ copy_1: Copy completed — 1 copied, 0 skipped, 0 overwritten
```

## Interactive Mode

With `--no-interaction` (or `-n`), all prompts are skipped. Without it,
interactive prompts are shown for:
- Rollback confirmation
- Overwrite confirmation in `init`
- Error recovery prompts

## Verbosity

- Default: Shows block-level progress
- `-v`: Shows parsed statement count
- `-vv`: Shows more details
- `-d` / `-vvv`: Shows raw config content
