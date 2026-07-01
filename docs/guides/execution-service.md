# Execution Service

The Execution Service is the internal layer responsible for running commands on local and remote targets. It abstracts platform differences, enforces audit logging, and provides a consistent interface for all command execution in Configr.

## What It Is

The Execution Service sits between Configr blocks (like `execute`, `raw`, and `script`) and the operating system. Every command that Configr runs—whether on the local machine or over SSH—passes through this service.

It ensures that:
- Commands run on the correct platform with the correct shell
- PowerShell on Windows uses encoded commands to avoid quoting issues
- Output is captured and logged for audit trails
- Sensitive environment variables are redacted from logs
- File transfers between controller and target are handled consistently

## Service Implementations

### Local Execution Service

Used when Configr applies changes to the machine it is running on.

- Directly invokes system processes
- Detects the local platform automatically
- Supports streaming output for long-running commands
- No network layer involved

### SSH Execution Service

Used when Configr connects to a remote target over SSH.

- Establishes an SSH session using the configured credentials
- Executes commands remotely through the SSH channel
- Transfers files to and from the remote target
- Closes the session cleanly when the run completes or fails

### Audited Execution Service

Wraps either of the implementations above to add structured audit logging.

- Writes JSONL audit records for every command
- Records: command, arguments, working directory, start time, duration, exit code, stdout, and stderr
- Decodes PowerShell `-EncodedCommand` arguments for readable logs
- Redacts environment variables whose names contain secrets, keys, tokens, or passwords
- Provides an audit log directory and session ID for traceability

## How Commands Are Executed

### Shell Selection

Configr selects the shell based on the target platform and block configuration.

- **Linux, macOS, FreeBSD**: Uses `sh` by default. Some environments support `bash`.
- **Windows**: Uses PowerShell by default. PowerShell commands are sent as encoded commands to avoid shell quoting problems.
- **Override**: Some blocks allow the shell to be overridden explicitly in the configuration.

### PowerShell Encoding

On Windows, when PowerShell is used, Configr encodes the command before sending it. This prevents quoting and escaping issues that commonly occur with complex PowerShell commands.

### Output Handling

- Stdout and stderr are captured separately
- Output can be streamed line-by-line for real-time feedback
- All captured output is available in the block result

## Logging and Auditing

### Audit Logs

When audit logging is enabled, every shell interaction is written to a JSONL file. Each entry represents one event:

- `shell_call`: A command is about to run
- `shell_response`: The command finished, with exit code and output
- `shell_error`: The command failed before producing a result

### Redaction

The audit logger automatically redacts environment variables whose names suggest they contain sensitive data. This includes names containing:
- password
- secret
- token
- key
- private

Redacted values appear as `<redacted>` in logs.

## File Transfers

The Execution Service also handles file operations needed by blocks:

- **putFile**: Copies a file from the controller to the target
- **fetchFile**: Retrieves a file from the target to the controller

On local targets, these are normal file copies. On remote SSH targets, they use the SSH channel.

## Integration With Strategies

The Execution Service works alongside execution strategies that choose platform-specific behavior:

- **ScriptStrategy**: Determines how inline scripts are formatted for Unix vs Windows
- **HookStrategy**: Determines how pre-apply and post-apply scripts are executed
- **NetworkStrategy**: Determines how network operations like waiting for a port are executed

These strategies produce platform-correct commands, and the Execution Service runs them.

## Common Scenarios

### Local Command

Configr runs a command on the local machine using the local shell and native process execution.

### Remote Command

Configr connects to a remote host using SSH, runs the command remotely, and returns the result.

### Audit-Tracked Command

Every command is logged as it runs, producing an auditable record of what was executed, where, and with what result.

### Windows PowerShell Command

A command is encoded for PowerShell and executed with output captured and decoded for readable logs.

## Key Points

- The Execution Service is not configured directly by users
- It is selected automatically based on whether the target is local or remote
- Audit logging is enabled when an audit directory is configured
- All command output, exit codes, and execution metadata are available to blocks
- Sensitive data is automatically redacted from audit logs
