# Locale Gen Module

Generates system locales — Ansible-style `locale_gen` module.

## Overview

The Locale Gen Module manages system locale generation. It uncomments or adds locales in `/etc/locale.gen` and runs `locale-gen` to generate them. Supports multiple locale names and Arch Linux.

## Features

- **Single or multiple locales**: Accept a single `name` string or a `locales` list
- **Automatic uncommenting**: Uncomments commented locales in `/etc/locale.gen`
- **Append mode**: Appends locales not already present in the file
- **Locale validation**: Checks against `/usr/share/i18n/SUPPORTED` on Debian
- **Debian/Ubuntu support**: Full `locale-gen` integration
- **Arch Linux support**: Same `/etc/locale.gen` + `locale-gen` workflow

## Properties

### Standard Properties
- `name`: Single locale name (e.g., `en_US.UTF-8`)
- `locales`: List of locale names (alternative to `name`)

### Notes
- Either `name` or `locales` can be used, but `locales` takes priority if both are specified
- If neither is specified, the block does nothing

## Examples

### Generate a Single Locale

```configr
resource {
  type "locale_gen"
  name "en_US.UTF-8"
  state "present"

  actions {
    locale_gen {}
  }
}
```

### Generate Multiple Locales

```configr
resource {
  type "locale_gen"
  state "present"

  actions {
    locale_gen {
      locales ["en_US.UTF-8", "de_DE.UTF-8", "ja_JP.UTF-8"]
    }
  }
}
```

### Remove a Locale

```configr
resource {
  type "locale_gen"
  name "ja_JP.UTF-8"
  state "absent"

  actions {
    locale_gen {}
  }
}
```

## Platform Support

| Platform | Implementation | Commands Used |
|----------|---------------|---------------|
| Debian/Ubuntu | Full | `locale-gen`, `locale -a`, `/usr/share/i18n/SUPPORTED` validation |
| Arch Linux | Full | `locale-gen`, `/etc/locale.gen` management |

## Rollback

The previous state of `/etc/locale.gen` is tracked in the lockfile and restored on rollback. Note that removing generated locale data from the system is not supported.
