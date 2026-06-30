# Privilege Lock

## Overview

The PrivilegeLock is a timeout-based session tracker that caches sudo
authentication across multiple operations, reducing password prompts.

## Implementation

Unlike the old singleton `PrivilegeLock.instance`, v2 uses an
**instance-based** lock with configurable timeout:

```dart
class PrivilegeLock {
  final Duration timeout;     // Default: 15 minutes
  bool _isActive = false;    // Tracks authentication state
  DateTime? _lastUsed;       // For timeout calculation
  Timer? _timeoutTimer;      // Auto-release timer
}
```

## How It Works

1. **Acquire**: On first successful `sudo`, the lock is acquired and a
   timer starts for the configured timeout.
2. **Reuse**: Subsequent privileged operations check the lock first. If
   active, `sudo -n` is attempted (relies on system sudo session).
3. **Timeout**: After the configured timeout, the lock auto-releases.
4. **Refresh**: Each successful privileged operation resets the timer.

## Configuration

```dart
// In ConfigrConfig:
ConfigrConfig(
  privilegeLock: PrivilegeLock(timeout: Duration(minutes: 30)),
  keepPrivilegeLock: true,
)
```

## Benefits

- Fewer password prompts during batch operations
- Configurable timeout per session
- No persistent shell process (uses system sudo cache)
- Instance-based — testable, no global state

## CLI Usage

The privilege lock is used automatically by the v2 pipeline when
`ActionBlock.requirePrivilegeEscalation` is `true`.
