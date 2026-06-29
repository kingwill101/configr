# Privilege Lock

Some blocks need elevated permissions, such as writing to `/etc`, managing
services, changing users or groups, or installing packages. The privilege lock
keeps that elevated session available for the duration of an apply so Configr
does not repeatedly prompt for the same permission.

## When It Applies

Privilege escalation may be needed for blocks such as:

- `package`, `apt`, `dnf`, `yum`, `pacman`, `brew`
- `service` and `systemd`
- `user` and `group`
- `hostname`, `timezone`, `sysctl`, `mount`
- file operations that write protected paths

## Usage

Preview first:

```bash
configr apply --dry-run
```

Apply normally:

```bash
configr apply
```

If a block requires elevated access, Configr requests it through the configured
privilege flow and keeps it available until the run finishes or times out.

## Safety Notes

- Use `--dry-run` before touching protected paths.
- Keep privileged blocks narrow and explicit.
- Prefer remote SSH users with the minimum permission needed.
- Rollback may also require elevated permissions if the original change did.
