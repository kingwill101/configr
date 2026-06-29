# Validate Module

Enhanced file validation with support for multiple formats, schema validation, and custom rules.

## Features

- **Multiple Format Support**: JSON and YAML formats
- **Schema Validation**: Validate files against schema definitions
- **Custom Rules**: Define custom validation rules with flexible syntax
- **Checksum Verification**: SHA-256 checksum validation for file integrity
- **Strict Mode**: Enhanced validation with stricter rules
- **Comprehensive Error Reporting**: Detailed error messages with context

## Basic Usage

### Simple Format Validation

```
resource {
  source "config.json"
  destination "/etc/app/config.json"

  actions {
    validate {
      format "json"
    }
    copy {}
  }
}
```

### Checksum Validation

```
resource {
  source "binary.exe"
  destination "/usr/local/bin/app"

  actions {
    validate {
      checksum "64e604787cbf194841e7b68d7cd28786f6c9a0a3ab9f8b0a0e87cb8387ab0002"
    }
    copy {}
    permissions {
      mode "755"
    }
  }
}
```

## Advanced Features

### Multiple Format Support

The validate module supports various file formats:

#### JSON Format
```
resource {
  source "config.json"
  actions {
    validate {
      format "json"
    }
  }
}
```

#### YAML Format
```
resource {
  source "config.yaml"
  actions {
    validate {
      format "yaml"
      strictMode true  # Enable strict YAML validation
    }
  }
}
```

The YAML validation uses the official `yaml` package for proper parsing and validation.


### Schema Validation

Validate files against schema definitions:

#### JSON Schema Validation
```
resource {
  source "data.json"
  actions {
    validate {
      format "json"
      schema "schema.json"
      strictMode true  # Reject unknown keys
    }
  }
}
```

Schema file format:
```json
{
  "name": {"required": true},
  "value": {"required": true},
  "optional": {"required": false}
}
```

#### YAML Schema Validation
```
resource {
  source "data.yaml"
  actions {
    validate {
      format "yaml"
      schema "schema.yaml"
    }
  }
}
```

Schema file format:
```yaml
name:
value:
optional:
```

### Custom Rules Validation

Define custom validation rules with flexible syntax:

#### Content Validation
```
resource {
  source "config.txt"
  actions {
    validate {
      customRules [
        "contains:must:required_text",
        "contains:mustnot:forbidden_text"
      ]
    }
  }
}
```

#### Regex Validation
```
resource {
  source "emails.txt"
  actions {
    validate {
      customRules [
        "regex:must:.*@.*\\.com",
        "regex:mustnot:.*@spam\\..*"
      ]
    }
  }
}
```

#### Length Validation
```
resource {
  source "document.txt"
  actions {
    validate {
      customRules [
        "length:min:100",
        "length:max:1000"
      ]
    }
  }
}
```

#### Line Count Validation
```
resource {
  source "data.csv"
  actions {
    validate {
      customRules [
        "lines:min:10",
        "lines:max:1000"
      ]
    }
  }
}
```

### Combined Validation

Use multiple validation types together:

```
resource {
  source "config.json"
  actions {
    validate {
      format "json"
      schema "schema.json"
      checksum "abc123..."
      customRules [
        "contains:must:version",
        "length:min:50"
      ]
      strictMode true
    }
  }
}
```

## Configuration Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `format` | string | `null` | File format to validate (`json`, `yaml`) |
| `checksum` | string | `null` | Expected SHA-256 checksum for file integrity |
| `schema` | string | `null` | Path to schema file for validation |
| `customRules` | array | `[]` | List of custom validation rules |
| `strictMode` | boolean | `false` | Enable strict validation mode |

## Custom Rules Syntax

Custom rules use the format: `type:condition:value`

### Rule Types

- **`contains`**: Check if content contains or doesn't contain text
- **`regex`**: Validate using regular expressions
- **`length`**: Validate content length
- **`lines`**: Validate line count

### Conditions

- **`must`**: Content must match the condition
- **`mustnot`**: Content must not match the condition
- **`min`**: Value must be at least the specified amount
- **`max`**: Value must be at most the specified amount
- **`exact`**: Value must be exactly the specified amount

### Examples

```
# Content must contain "version"
"contains:must:version"

# Content must not contain "debug"
"contains:mustnot:debug"

# Must match email pattern
"regex:must:.*@.*\\.com"

# Length must be at least 100 characters
"length:min:100"

# Must have exactly 5 lines
"lines:exact:5"
```

## State Tracking

The validate module tracks detailed validation results:

### State Properties

| Property | Type | Description |
|----------|------|-------------|
| `validationCompleted` | boolean | Whether validation completed successfully |
| `validationResults` | object | Results of each validation type |
| `formatValidated` | boolean | Whether format validation passed |
| `schemaValidated` | boolean | Whether schema validation passed |
| `customRulesValidated` | boolean | Whether custom rules validation passed |
| `actualChecksum` | string | Computed checksum of the file |
| `sourceExists` | boolean | Whether the source file exists |

## Error Handling

The validate module provides comprehensive error reporting:

- **Format Validation Errors**: Detailed syntax error messages with line numbers
- **Schema Validation Errors**: Missing required fields and type mismatches
- **Custom Rule Errors**: Specific rule violations with context
- **Checksum Errors**: Expected vs actual checksum comparison

## Examples

### Complete Configuration Example

```
resource {
  source "/home/user/app-config.json"
  destination "/etc/app/config.json"

  actions {
    validate {
      format "json"
      schema "/home/user/schema.json"
      checksum "d8c04bddc717c157fb37ea4db608dd094546ac89461ce1dabbe6a2d899e20e1b"
      customRules [
        "contains:must:version",
        "regex:must:.*@.*\\.com",
        "length:min:100"
      ]
      strictMode true
    }
    copy {}
    permissions {
      mode "644"
    }
  }
}
```

### Multi-Format Validation

```
resource {
  source "/configs/*"
  destination "/etc/app/configs/"

  actions {
    validate {
      format "yaml"
      customRules [
        "contains:must:environment",
        "lines:min:5"
      ]
    }
    copy {
      recursive true
    }
  }
}
```
