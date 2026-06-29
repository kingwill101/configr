# Mount Block

Manages mount points and filesystem table (`/etc/fstab`) entries, with support for mounting and unmounting filesystems.

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `path` | `string` | `""` | Mount point path (e.g. `/mnt/data`) |
| `src` | `string` | `""` | Device or remote filesystem source (e.g. `/dev/sda1`, `192.168.1.1:/export`) |
| `fstype` | `string` | `""` | Filesystem type (e.g. `ext4`, `nfs`, `auto`) |
| `opts` | `string` | `"defaults"` | Mount options (e.g. `noexec,nosuid`) |
| `dump` | `int` | `0` | Dump frequency for fstab |
| `passno` | `int` | `0` | Filesystem check order for fstab |
| `state` | `string` | `"present"` | Desired state: `present`, `absent`, `mounted`, `unmounted`, `remounted` |

States:
- **present** — Ensure the entry exists in fstab (do not mount)
- **absent** — Remove the fstab entry and unmount if mounted
- **mounted** — Ensure the filesystem is mounted and the fstab entry exists
- **unmounted** — Unmount the filesystem (keep fstab entry)
- **remounted** — Unmount then mount (apply new options)

## Examples

### Mount a Disk

```
mount {
  path = "/mnt/data"
  src = "/dev/sdb1"
  fstype = "ext4"
  opts = "defaults,noatime"
  state = "mounted"
}
```

### Ensure fstab Entry Only

```
mount {
  path = "/mnt/backup"
  src = "/dev/sdc1"
  fstype = "ext4"
  state = "present"
}
```

### Unmount and Remove from fstab

```
mount {
  path = "/mnt/old"
  state = "absent"
}
```

## Platform Support

| Platform | Implementation | Details |
|----------|---------------|---------|
| Linux    | Full | Uses `mount`, `umount`, `/etc/fstab` |
| macOS    | Full | Uses `mount`, `umount`, `/etc/fstab` |
| FreeBSD  | Full | Uses `mount`, `umount`, `/etc/fstab` |
| Other    | Unsupported | Throws `UnsupportedError` |

## Rollback

No automatic rollback is performed. Fstab modifications and mount operations are not undone.
