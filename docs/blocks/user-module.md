# User Module

Manages system user accounts.

## Overview

The User Module creates, modifies, and removes system user accounts with full rollback support. It automatically detects the operating system and uses the appropriate platform-specific commands (`useradd`/`usermod`/`userdel` on Linux, `dscl` on macOS, `pw` on FreeBSD).

## Features

- **User Creation**: Create system or regular users with home directories
- **User Modification**: Change UID, groups, shell, home directory, comment
- **User Removal**: Remove users with or without their home directory
- **Group Membership**: Append or replace supplementary groups
- **Password Support**: Set user passwords via `chpasswd`
- **Rollback**: Full undo support for all operations

## Properties

### Standard Properties
- `name` (required): Username to manage
- `state` (required): `present` to create/modify, `absent` to remove

### User Properties
- `uid`: User ID (numeric)
- `group`: Primary group name or GID
- `groups`: Supplementary groups (comma-separated)
- `comment`: GECOS comment (full name, etc.)
- `home`: Home directory path
- `shell`: Login shell path
- `password`: Encrypted password string

### Boolean Properties
- `system`: Whether to create a system account
- `create_home`: Create home directory (default: `true`)
- `move_home`: Move home directory when changing UID
- `remove`: Remove home directory and mail spool on absent
- `force`: Force removal even if user is logged in
- `append`: Append groups instead of replacing (default: `false`)

## Examples

### Create a Regular User

```configr
resource {
  type "user"
  name "johndoe"
  state "present"

  actions {
    user {
      comment "John Doe"
      shell "/bin/bash"
      groups "wheel,docker"
      create_home "true"
    }
  }
}
```

### Create a System User

```configr
resource {
  type "user"
  name "nginx"
  state "present"

  actions {
    user {
      system "true"
      shell "/sbin/nologin"
      create_home "false"
    }
  }
}
```

### Remove a User

```configr
resource {
  type "user"
  name "olduser"
  state "absent"

  actions {
    user {
      remove "true"
      force "true"
    }
  }
}
```

## Platform Support

| Platform | Implementation | Commands Used |
|----------|---------------|---------------|
| Linux    | Full          | `useradd`, `usermod`, `userdel`, `chpasswd`, `id`, `getent` |
| macOS    | Stub          | Not yet implemented (will use `dscl`) |
| FreeBSD  | Stub          | Not yet implemented (will use `pw`) |

## Rollback

The User Module tracks created/modified users in the lockfile. Rollback will remove created users or restore modified properties. Home directories created during setup are removed on rollback.
