# Git Operations Example

This example demonstrates the git module functionality using well-known public repositories.

## What This Example Does

This configuration demonstrates several git operations:

1. **Clone Operation**: Clones the popular Oh My Zsh repository
2. **Pull Operation**: Pulls latest changes from the cloned repository
3. **Commit Operation**: Shows how to commit changes to a repository
4. **Network Check**: Verifies network connectivity to GitHub

## Repositories Used

- **Oh My Zsh**: https://github.com/robbyrussell/oh-my-zsh.git
  - A popular Zsh configuration framework
  - Large, well-maintained repository with many contributors
  - Good for testing clone and pull operations

- **Hello World**: https://github.com/octocat/Hello-World.git
  - GitHub's official "Hello World" repository
  - Small, simple repository perfect for testing
  - Good for demonstrating commit operations

## How to Run

1. **Apply the configuration**:
   ```bash
   cd examples/git
   dart run ../../bin/main.dart apply
   ```

2. **Rollback changes**:
   ```bash
   # Rollback all operations
   dart run ../../bin/main.dart rollback
   
   # Rollback individual operations
   dart run ../../bin/main.dart rollback -n 1
   ```

3. **Check the status**:
   ```bash
   dart run ../../bin/main.dart status
   ```

## Expected Results

After running this example, you should see:

- `examples/git/oh-my-zsh/` - A cloned copy of the Oh My Zsh repository
- `examples/git/test-repo/` - A cloned copy of the Hello World repository with additional files:
  - `configr-demo.txt` - Demo file created by the File Module
  - `.gitignore` - Git ignore file created by the File Module
  - `README.md` - Documentation file created by the File Module
- Network connectivity test results

## File Module Integration

This example demonstrates the integration between the Git Module and File Module:

- **File Creation**: Uses the File Module to create files in git repositories
- **Git Operations**: Commits the created files to version control
- **Rollback Support**: Both file operations and git operations can be rolled back
- **State Tracking**: All operations are tracked in the lockfile for rollback

## Git Operations Demonstrated

### Clone Operation
```
git {
  operation "clone"
  repository_url "https://github.com/robbyrussell/oh-my-zsh.git"
  local_path "examples/git/oh-my-zsh"
  branch "master"
  stream_output "true"
  show_progress "true"
}
```

### Pull Operation
```
git {
  operation "pull"
  local_path "examples/git/oh-my-zsh"
  branch "master"
  stream_output "true"
}
```

### Commit Operation
```
git {
  operation "commit"
  local_path "examples/git/test-repo"
  commit_message "Add example file for Configr git demo"
  stream_output "true"
}
```

## Streaming Features

The git module supports real-time output streaming:

- **`stream_output`**: When set to "true", git command output is streamed directly to the console
- **`show_progress`**: When set to "true" (default), shows progress information for long operations
- **Real-time Feedback**: See git operations happening in real-time instead of waiting for completion
- **Progress Indicators**: Clone operations show download progress with the `--progress` flag

### Streaming Benefits
- **Better UX**: Users can see what's happening during long operations
- **Debugging**: Easier to diagnose issues with real-time output
- **Progress Tracking**: Know how long operations will take
- **Interactive**: Some git operations may prompt for input

## Validation Features

The git module includes comprehensive validation:

- **Directory Existence**: Ensures local directories exist before operations
- **Git Repository Check**: Validates that directories are valid git repositories
- **Operation Success**: Confirms operations actually completed successfully
- **Change Detection**: Detects if pull/commit operations actually made changes
- **Error Handling**: Provides clear error messages for failed operations

## Troubleshooting

If you encounter issues:

1. **Network Connectivity**: Ensure you have internet access
2. **Git Installation**: Make sure git is installed and available in PATH
3. **Permissions**: Ensure you have write permissions to the examples/git directory
4. **Repository Access**: Verify the repositories are accessible (they should be public)

## Cleanup

To clean up the example files:

```bash
rm -rf examples/git/oh-my-zsh
rm -rf examples/git/test-repo
```

## Real-World Usage

This example demonstrates patterns you can use for:

- **Dotfile Management**: Clone and maintain your dotfile repositories
- **Configuration Backup**: Backup configuration files to git repositories
- **Automated Updates**: Pull latest changes from remote repositories
- **Change Tracking**: Commit and track changes to your configurations
