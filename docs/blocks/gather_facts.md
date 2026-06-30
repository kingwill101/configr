# Gather Facts Block

Collects system facts and sets them as context variables for use in subsequent actions.

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `gather_subset` | `string` | `"all"` | Fact subset to collect. Supported: `all`, `min`, `network`, `hardware`, `virtual` |

## Facts Collected

The following context variables are populated:

| Variable | Source |
|----------|--------|
| `os_family` | `OsFacts.detect()` — e.g. `Debian`, `RedHat`, `Darwin` |
| `distribution` | `OsFacts.detect()` — e.g. `Ubuntu`, `macOS` |
| `distribution_version` | `OsFacts.detect()` — e.g. `22.04` |
| `architecture` | `OsFacts.detect()` — e.g. `x86_64`, `arm64` |
| `system` | `OsFacts.detect()` — e.g. `Linux`, `Darwin`, `FreeBSD` |
| `hostname` | `Platform.localHostname` |
| `kernel` | `uname -a` full output |
| `kernel_version` | `uname -r` |
| `processor_count` | `nproc` |
| `memtotal_mb` | Total memory in MB (OS-specific: `free -b` on Linux, `sysctl hw.memsize` on macOS, `sysctl hw.physmem` on FreeBSD) |
| `mounts` | `df -B1 /` output |
| `interfaces` | `ip -o addr show` on Linux, `ifconfig` on macOS/FreeBSD |

## Examples

### Gather All Facts

```
gather_facts {
  gather_subset = "all"
}
```

### Gather Only Network Facts

```
gather_facts {
  gather_subset = "network"
}
```

### Gather Minimal Facts

```
gather_facts {
  gather_subset = "min"
}
```

## Platform Support

| Platform | Implementation |
|----------|---------------|
| Linux    | Full — uses `free`, `ip`, `nproc`, `uname` |
| macOS    | Full — uses `sysctl`, `ifconfig`, `nproc`, `uname` |
| FreeBSD  | Full — uses `sysctl`, `ifconfig`, `nproc`, `uname` |
| Other    | Partial — OS facts, hostname, kernel only |

## Rollback

No rollback is performed. Fact gathering is a read-only operation that does not modify system state.
