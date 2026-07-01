/// Capability strings for target runtime feature detection.
///
/// Blocks can check whether the target supports a capability (e.g. a
/// particular shell) before deciding how to execute. Capabilities are
/// probed by [TargetSystemProbe] and stored in [TargetSystemFacts].
///
/// Naming convention: `{domain}.{feature}` — the same pattern used in
/// the portability matrix and capability-fact tables.
library;

// ── Execution capabilities ──────────────────────────────────────────

/// Target can run POSIX `sh` commands.
const String execSh = 'exec.sh';

/// Target has Bash available.
const String execBash = 'exec.bash';

/// Target has PowerShell (or pwsh) available.
const String execPowerShell = 'exec.powershell';

/// Target provides a process execution backend (always true for local/SSH).
const String execProcess = 'exec.process';
