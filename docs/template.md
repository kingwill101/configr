# Template Module

The template module provides advanced file generation from templates using the Liquid templating engine. It supports variable substitution, conditional logic, loop constructs, and comprehensive validation.

## Features

- **Variable Substitution**: Replace template variables with provided values
- **Conditional Logic**: Include or exclude template blocks based on conditions
- **Loop Constructs**: Repeat template blocks for collections
- **Template Validation**: Validate templates before processing
- **Backup Support**: Create backups of original files before overwriting
- **Progress Tracking**: Track processing progress for batch operations
- **Rollback Support**: Restore original files if needed

## Configuration

### Basic Template Processing

**Inside a resource (v1 style):**

```
resource {
  id "config-template"
  source "config.template"
  destination "/etc/myapp/config.conf"
  
  actions {
    template {
      template_vars {
        app_name "MyApp"
        port 8080
        debug true
      }
    }
  }
}
```

### Standalone Template Block (v2 flat syntax)

```
template {
  source = "my_file.template"
  destination = "/etc/myapp/config.conf"
  vars {
    app_name "MyApp"
    port 8080
    debug true
  }
}
```

### In-Memory Templating (v2 resource-scoped)

When `template { }` is placed directly inside a `resource { }` (not under `actions { }`), it renders in-memory without writing to disk. Child actions (like `copy { }`) inherit the rendered content:

```
resource {
  source = "my_file.template"
  destination = "output.txt"
  template {
    vars {
      name "susan"
    }
  }
  actions {
    copy {
      destination = "output.txt"
    }
  }
}
```

This avoids writing the rendered template to disk and then re-reading it — the rendered string is passed directly through the context.

### Advanced Template Processing

```
resource {
  id "advanced-template"
  source "advanced.template"
  destination "/var/www/config.php"
  
  actions {
    template {
      template_vars {
        database {
          host "localhost"
          port 5432
          name "myapp"
        }
        users {
          admin {
            name "admin"
            role "administrator"
          }
          user {
            name "user"
            role "user"
          }
        }
      }
      validate_template true
      backup_original true
      backup_suffix ".bak"
      show_progress true
    }
  }
}
```

## Template Syntax

The template module uses the Liquid templating engine, which provides a powerful and flexible syntax:

### Variables

```liquid
Hello {{ name }}, welcome to {{ app }}!
```

### Conditional Logic

```liquid
{% if user.isAdmin %}
Welcome, Administrator {{ user.name }}!
{% else %}
Welcome, {{ user.name }}!
{% endif %}
```

### Loops

```liquid
{% for item in items %}
- {{ item.name }}: {{ item.value }}
{% endfor %}
```

### Filters

```liquid
{{ name | upcase }}
{{ date | date: "%Y-%m-%d" }}
{{ text | truncate: 50 }}
```

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `template_vars` | Map | `{}` | Variables to substitute in the template |
| `validate_template` | Boolean | `true` | Whether to validate the template before processing |
| `show_progress` | Boolean | `true` | Whether to show progress during processing |
| `backup_original` | Boolean | `false` | Whether to backup the original file before overwriting |
| `backup_suffix` | String | `.backup` | Suffix for backup files |
| `template_engine` | String | `liquid` | Template engine to use (currently only 'liquid' supported) |

## Examples

### Simple Configuration File

**Template file (`config.template`):**
```ini
[app]
name={{ app_name }}
version={{ version }}
debug={{ debug }}

[server]
host={{ host }}
port={{ port }}
```

**Configuration:**
```
resource {
  id "app-config"
  source "config.template"
  destination "/etc/myapp/config.ini"
  
  actions {
    template {
      template_vars {
        app_name "MyApplication"
        version "1.0.0"
        debug false
        host "0.0.0.0"
        port 8080
      }
    }
  }
}
```

**Generated output:**
```ini
[app]
name=MyApplication
version=1.0.0
debug=false

[server]
host=0.0.0.0
port=8080
```

### Dynamic User Configuration

**Template file (`users.template`):**
```json
{
  "users": [
    {% for user in users %}
    {
      "id": {{ user.id }},
      "name": "{{ user.name }}",
      "email": "{{ user.email }}",
      "role": "{{ user.role }}"
    }{% unless forloop.last %},{% endunless %}
    {% endfor %}
  ]
}
```

**Configuration:**
```
resource {
  id "users-config"
  source "users.template"
  destination "/etc/myapp/users.json"
  
  actions {
    template {
      template_vars {
        users {
          user1 {
            id 1
            name "John Doe"
            email "john@example.com"
            role "admin"
          }
          user2 {
            id 2
            name "Jane Smith"
            email "jane@example.com"
            role "user"
          }
        }
      }
    }
  }
}
```

**Generated output:**
```json
{
  "users": [
    {
      "id": 1,
      "name": "John Doe",
      "email": "john@example.com",
      "role": "admin"
    },
    {
      "id": 2,
      "name": "Jane Smith",
      "email": "jane@example.com",
      "role": "user"
    }
  ]
}
```

### Conditional Configuration

**Template file (`nginx.template`):**
```nginx
server {
    listen {{ port }};
    server_name {{ domain }};
    
    {% if ssl_enabled %}
    ssl_certificate {{ ssl_cert }};
    ssl_certificate_key {{ ssl_key }};
    {% endif %}
    
    location / {
        proxy_pass http://{{ backend_host }}:{{ backend_port }};
    }
    
    {% if enable_logging %}
    access_log /var/log/nginx/{{ domain }}.access.log;
    error_log /var/log/nginx/{{ domain }}.error.log;
    {% endif %}
}
```

**Configuration:**
```
resource {
  id "nginx-config"
  source "nginx.template"
  destination "/etc/nginx/sites-available/myapp"
  
  actions {
    template {
      template_vars {
        port 443
        domain "myapp.example.com"
        ssl_enabled true
        ssl_cert "/etc/ssl/certs/myapp.crt"
        ssl_key "/etc/ssl/private/myapp.key"
        backend_host "127.0.0.1"
        backend_port 8080
        enable_logging true
      }
    }
  }
}
```

## Error Handling

The template module provides comprehensive error handling:

- **Template Validation**: Templates are validated before processing to catch syntax errors early
- **Variable Validation**: Missing required variables are detected and reported
- **File System Errors**: Proper handling of file system operations with detailed error messages
- **Rollback Support**: Automatic rollback on failure to restore original state

## Best Practices

1. **Template Validation**: Always enable template validation in production environments
2. **Backup Original Files**: Use backup functionality when overwriting important configuration files
3. **Variable Naming**: Use descriptive variable names to make templates self-documenting
4. **Error Handling**: Test templates with various input scenarios to ensure robustness
5. **Documentation**: Document template variables and their expected values

## Troubleshooting

### Common Issues

**Template validation fails:**
- Check for syntax errors in the template
- Ensure all braces and tags are properly closed
- Verify that the template engine supports the syntax used

**Variable substitution not working:**
- Verify that variable names match exactly (case-sensitive)
- Check that variables are provided in the `template_vars` property
- Ensure variable values are of the expected type

**File permission errors:**
- Check that the destination directory exists and is writable
- Verify that the user has sufficient permissions to create/modify files
- Consider using privilege escalation if needed

### Debug Mode

Enable debug mode to get detailed information about template processing:

```
resource {
  id "debug-template"
  source "template.txt"
  destination "output.txt"
  
  actions {
    template {
      template_vars {
        debug true
        verbose true
      }
    }
  }
}
```

This will provide detailed logging of the template processing steps, variable substitution, and any errors encountered.
