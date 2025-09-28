# Template Module Example

This example demonstrates the new template module with various features including variable substitution, conditional logic, loops, and backup functionality.

## Files

- `config` - Main configuration file with multiple template resources
- `app_config.template` - Basic template with variables and conditionals
- `nginx_config.template` - Complex template with conditional SSL configuration
- `users_config.template` - Template with loop constructs for user data
- `service_config.template` - Systemd service template with backup functionality

## Features Demonstrated

### 1. Basic Variable Substitution
The `app_config.template` shows:
- Simple variable replacement: `{{ app_name }}`
- Conditional blocks: `{% if debug %}...{% endif %}`
- Filters: `{{ app_name | downcase }}`

### 2. Complex Conditional Logic
The `nginx_config.template` demonstrates:
- Multi-level conditionals for SSL configuration
- Complex template structure with nested blocks
- Security headers and logging configuration

### 3. Loop Constructs
The `users_config.template` shows:
- Iterating over collections: `{% for user in users %}`
- Loop variables: `{% unless forloop.last %}`
- Collection filters: `{{ users | where: "role", "administrator" | size }}`

### 4. Advanced Features
The `service_config.template` demonstrates:
- Backup functionality with `backup_original true`
- Template validation with `validate_template true`
- Complex variable usage in paths and commands

## Running the Example

1. Navigate to this directory:
   ```bash
   cd examples/template-module
   ```

2. Run configr to process the templates:
   ```bash
   configr apply config
   ```

3. Check the generated files in the `generated/` directory:
   - `app_config.conf` - Application configuration
   - `nginx.conf` - Nginx server configuration
   - `users.json` - User data in JSON format
   - `service.conf` - Systemd service file

## Expected Output

### app_config.conf
```ini
# Application Configuration
# Generated from template on 2024-01-15 10:30:45

[application]
name = MyApplication
version = 1.0.0
debug = false

[server]
host = localhost
port = 8080

[logging]
level = info
file = /var/log/myapplication.log

# Environment-specific settings
[production]
performance_mode = true
```

### nginx.conf
```nginx
# Nginx Configuration for myapp.example.com
# Generated from template

server {
    listen 80;
    server_name myapp.example.com;
    
    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name myapp.example.com;
    
    # SSL Configuration
    ssl_certificate /etc/ssl/certs/myapp.crt;
    ssl_certificate_key /etc/ssl/private/myapp.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    # Proxy to backend
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Logging
    access_log /var/log/nginx/myapp.example.com.access.log;
    error_log /var/log/nginx/myapp.example.com.error.log;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
}
```

### users.json
```json
{
  "users": [
    {
      "id": 1,
      "name": "John Doe",
      "email": "john@example.com",
      "role": "administrator",
      "active": true,
      "created_at": "2024-01-15T10:30:45Z"
    },
    {
      "id": 2,
      "name": "Jane Smith",
      "email": "jane@example.com",
      "role": "user",
      "active": true,
      "created_at": "2024-01-15T10:30:45Z"
    },
    {
      "id": 3,
      "name": "Bob Wilson",
      "email": "bob@example.com",
      "role": "user",
      "active": true,
      "created_at": "2024-01-15T10:30:45Z"
    }
  ],
  "metadata": {
    "total_users": 3,
    "admin_count": 1,
    "user_count": 2,
    "generated_at": "2024-01-15 10:30:45"
  }
}
```

## Template Engine Features

This example showcases the Liquid templating engine features:

- **Variables**: `{{ variable_name }}`
- **Conditionals**: `{% if condition %}...{% endif %}`
- **Loops**: `{% for item in collection %}...{% endfor %}`
- **Filters**: `{{ text | upcase }}`, `{{ date | date: "%Y-%m-%d" }}`
- **Loop variables**: `forloop.first`, `forloop.last`, `forloop.index`
- **Collection filters**: `where`, `size`, `first`, `last`

## Rollback

To rollback the template processing:

```bash
configr rollback config
```

This will restore any original files that were backed up and remove generated files that didn't exist originally.
