# Privilege Lock

## Overview

The PrivilegeLock is a timeout-based session tracker that caches sudo
authentication across multiple operations, reducing password prompts.

## Implementation

v2 uses an instance-based lock with configurable timeout. The lock tracks whether sudo authentication is active and when it was last used, releasing automatically after the configured timeout period.

## How It Works

1. **Acquire**: On first successful sudo, the lock is acquired and a timer starts for the configured timeout.
2. **Reuse**: Subsequent privileged operations check the lock first. If active, non-interactive sudo is attempted.
3. **Timeout**: After the configured timeout, the lock auto-releases.
4. **Refresh**: Each successful privileged operation resets the timer.

## Configuration

The privilege lock supports a configurable timeout and optional persistence across runs. It is initialized when building your Configr configuration.

## Benefits

- Fewer password prompts during batch operations
- Configurable timeout per session
- No persistent shell process (uses system sudo cache)
- Instance-based design — testable, no global state

## CLI Usage

The privilege lock is used automatically by the v2 pipeline when a block requires privilege escalation.
