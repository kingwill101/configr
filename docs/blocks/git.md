# Git Block

Performs Git repository operations — clone, pull, push, and commit with full rollback support.

## Usage

### Clone Repository
```
git {
  source = "https://github.com/user/dotfiles.git"
  destination = "~/dotfiles"
  branch = "main"
  operation = "clone"
}
```

### Pull Latest Changes
```
git {
  destination = "~/dotfiles"
  operation = "pull"
  branch = "main"
}
```

### Push Changes
```
git {
  destination = "~/dotfiles"
  operation = "push"
  branch = "main"
}
```

### Commit Changes
```
git {
  destination = "~/dotfiles"
  operation = "commit"
  commit_message = "Update config files"
}
```

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `source` | `string` | - | Repository URL (required for clone) |
| `destination` | `string` (required) | - | Local path for the repository |
| `branch` | `string` | `null` | Branch to work with |
| `operation` | `string` | `"clone"` | Operation type: `clone`, `pull`, `push`, or `commit` |
| `commit_message` | `string` | `null` | Commit message (required for commit) |
| `stream_output` | `boolean` | `true` | Stream Git output to event system |

## Operations

### `clone`
Clones a repository to the destination path. If the destination already exists, the clone is skipped.

### `pull`
Pulls latest changes from the remote repository. Commits before pull are stored for rollback.

### `push`
Pushes local commits to the remote repository. Cannot be rolled back.

### `commit`
Creates a commit with all changes. Message is required via `commit_message`.

## Rollback

- **clone** — Removes the cloned repository directory
- **pull** — Resets to the commit hash before the pull
- **commit** — Resets soft to `HEAD~1`
- **push** — No rollback available (remote changes cannot be undone)