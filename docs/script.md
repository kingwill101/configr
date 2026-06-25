# Script Block

Copies a local script to the target system, makes it executable, and runs it.

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `script` | `string` | `""` | Path to the local script file to transfer and execute |
| `args` | `string` | `""` | Command-line arguments to pass to the script |
| `chdir` | `string` | `""` | Working directory to run the script in |
| `creates` | `string` | `""` | Skip execution if this path already exists |
| `removes` | `string` | `""` | Skip execution if this path does not exist |

The script is copied to a temporary location, made executable with `chmod +x`, executed, and then cleaned up.

## Examples

### Run a Setup Script

```
script {
  script = "./scripts/setup.sh"
}
```

### Run with Arguments

```
script {
  script = "./deploy.sh"
  args = "--env production --tag v1.2.3"
}
```

### Run Only If Target Does Not Exist

```
script {
  script = "./init-db.sh"
  creates = "/var/lib/db/initialized"
}
```

### Run Only If Source Exists

```
script {
  script = "./migrate.sh"
  removes = "/tmp/migration-lock"
}
```

## Platform Support

| Platform | Implementation |
|----------|---------------|
| Linux    | Full — copies and executes |
| macOS    | Full — copies and executes |
| FreeBSD  | Full — copies and executes |

## Rollback

No rollback is performed. The temporary script file is deleted after execution regardless of success.
