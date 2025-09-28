# Download Module

Enhanced file download with resume capability, authentication, and integrity verification.

## Features

- **Resume Capability**: Resume interrupted downloads from last position
- **Authentication**: Support for Basic, Bearer token, and API key authentication
- **Multiple Checksums**: SHA-256, MD5, and SHA-1 checksum validation
- **Progress Tracking**: Real-time progress monitoring with speed and duration
- **Event System**: Comprehensive event emission for monitoring and logging
- **Rollback Support**: Ability to undo download operations

## Basic Usage

### Simple Download

```
resource {
  source "https://example.com/file.zip"
  destination "/path/to/downloaded/file.zip"
  actions {
    download {}
  }
}
```

### Download with Overwrite

```
resource {
  source "https://example.com/file.zip"
  destination "/path/to/existing/file.zip"
  actions {
    download {
      overwrite true
    }
  }
}
```

## Advanced Features

### Resume Capability

Resume interrupted downloads from where they left off:

```
resource {
  source "https://example.com/large-file.zip"
  destination "/path/to/large-file.zip"
  actions {
    download {
      resume true
    }
  }
}
```

### Authentication

#### Basic Authentication

```
resource {
  source "https://example.com/protected/file.zip"
  destination "/path/to/file.zip"
  actions {
    download {
      auth_type "basic"
      username "user"
      password "pass"
    }
  }
}
```

#### Bearer Token Authentication

```
resource {
  source "https://api.example.com/file.zip"
  destination "/path/to/file.zip"
  actions {
    download {
      auth_type "bearer"
      auth_token "your-bearer-token"
    }
  }
}
```

#### API Key Authentication

```
resource {
  source "https://api.example.com/file.zip"
  destination "/path/to/file.zip"
  actions {
    download {
      auth_type "api_key"
      auth_token "your-api-key"
      api_key_header "X-API-Key"
    }
  }
}
```

### Checksum Validation

#### SHA-256 Checksum (Default)

```
resource {
  source "https://example.com/file.zip"
  destination "/path/to/file.zip"
  actions {
    download {
      checksum "a1b2c3d4e5f6..."
    }
  }
}
```

#### MD5 Checksum

```
resource {
  source "https://example.com/file.zip"
  destination "/path/to/file.zip"
  actions {
    download {
      checksum_algorithm "md5"
      checksum "d41d8cd98f00b204e9800998ecf8427e"
    }
  }
}
```

#### SHA-1 Checksum

```
resource {
  source "https://example.com/file.zip"
  destination "/path/to/file.zip"
  actions {
    download {
      checksum_algorithm "sha1"
      checksum "da39a3ee5e6b4b0d3255bfef95601890afd80709"
    }
  }
}
```

### Complex Configuration

```
resource {
  source "https://api.example.com/large-file.zip"
  destination "/path/to/large-file.zip"
  actions {
    download {
      resume true
      auth_type "bearer"
      auth_token "your-token"
      checksum_algorithm "sha256"
      checksum "expected-checksum"
      overwrite true
    }
  }
}
```

## Configuration Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `overwrite` | boolean | `false` | Overwrite existing files |
| `resume` | boolean | `false` | Enable resume capability |
| `auth_type` | string | `null` | Authentication type (`basic`, `bearer`, `api_key`) |
| `auth_token` | string | `null` | Authentication token or API key |
| `username` | string | `null` | Username for basic authentication |
| `password` | string | `null` | Password for basic authentication |
| `api_key_header` | string | `X-API-Key` | Header name for API key authentication |
| `checksum` | string | `null` | Expected checksum for validation |
| `checksum_algorithm` | string | `sha256` | Checksum algorithm (`sha256`, `md5`, `sha1`) |

## State Tracking

The download module tracks detailed state information:

### State Properties

| Property | Type | Description |
|----------|------|-------------|
| `receivedBytes` | int | Number of bytes downloaded |
| `totalBytes` | int | Total file size in bytes |
| `downloadSpeed` | int | Download speed in bytes per second |
| `downloadDuration` | Duration | Total download time |
| `actualChecksum` | string | Calculated checksum of downloaded file |
| `expectedChecksum` | string | Expected checksum for validation |
| `isResumed` | boolean | Whether download was resumed |
| `resumePosition` | int | Byte position where download resumed |
| `authType` | string | Authentication type used |
| `checksumAlgorithm` | string | Checksum algorithm used |

## Examples

### Download with Progress Tracking

```
resource {
  source "https://example.com/large-file.zip"
  destination "/downloads/large-file.zip"
  actions {
    download {
      resume true
      overwrite true
    }
  }
}
```

### Secure Download with Authentication

```
resource {
  source "https://secure.example.com/backup.tar.gz"
  destination "/backups/backup.tar.gz"
  actions {
    download {
      auth_type "basic"
      username "backup_user"
      password "secure_password"
      checksum_algorithm "sha256"
      checksum "expected-sha256-hash"
    }
  }
}
```

### API Download with Custom Header

```
resource {
  source "https://api.github.com/repos/user/repo/archive/main.zip"
  destination "/downloads/repo.zip"
  actions {
    download {
      auth_type "api_key"
      auth_token "ghp_your_github_token"
      api_key_header "Authorization"
      overwrite true
    }
  }
}
```

### Resume Large Download

```
resource {
  source "https://example.com/very-large-file.iso"
  destination "/downloads/very-large-file.iso"
  actions {
    download {
      resume true
      checksum_algorithm "md5"
      checksum "expected-md5-hash"
    }
  }
}
```