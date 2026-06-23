# Network Block

Performs network connectivity checks — HTTP, TCP, DNS, ping, and general connectivity.

## Usage

### HTTP Check
```
network {
  source = "https://api.example.com/health"
  operation = "http"
  expected_status = 200
  expected_text = "OK"
  timeout = 30
}
```

### HTTP with Authentication
```
network {
  source = "https://api.example.com/status"
  operation = "http"
  username = "admin"
  password = "secret"
  expected_status = 200
}
```

### TCP Port Check
```
network {
  source = "localhost"
  operation = "tcp"
  port = 8080
  timeout = 10
}
```

### DNS Resolution Check
```
network {
  source = "github.com"
  operation = "dns"
  timeout = 5
}
```

### Ping Check
```
network {
  source = "8.8.8.8"
  operation = "ping"
  timeout = 10
}
```

### General Connectivity
```
network {
  source = "https://example.com"
  operation = "connectivity"
  timeout = 30
}
```

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `source` | `string` (required) | - | URL or hostname to check |
| `destination` | `string` | - | Alias for source |
| `operation` | `string` | `"connectivity"` | Check type: `connectivity`, `http`, `tcp`, `dns`, or `ping` |
| `port` | `integer` | `80` | Port number for TCP/HTTP |
| `timeout` | `integer` | `30` | Timeout in seconds |
| `expected_status` | `integer` | `null` | Expected HTTP status code |
| `expected_text` | `string` | `null` | Text to expect in HTTP response |
| `expected_content_type` | `string` | `null` | Expected HTTP content-type header |
| `method` | `string` | `"GET"` | HTTP method |
| `request_body` | `string` | `null` | Body for POST/PUT requests |
| `content_type` | `string` | `null` | Content-Type header for request |
| `username` | `string` | `null` | HTTP Basic auth username |
| `password` | `string` | `null` | HTTP Basic auth password |
| `follow_redirects` | `boolean` | `true` | Follow HTTP redirects |
| `validate_certificate` | `boolean` | `true` | Validate SSL certificates |

## Operations

### `connectivity`
Tests general network connectivity by performing a DNS lookup on the source URL.

### `http`
Performs an HTTP/HTTPS request and validates response. Supports status code, body text, and content-type checks.

### `tcp`
Attempts to open a TCP connection to the specified host and port.

### `dns`
Resolves a hostname to its IP address.

### `ping`
Sends a single ICMP ping packet to the target host.

## Notes

- All operations are read-only and cannot be rolled back
- SSL certificate validation can be disabled for self-signed certificates
- Authentication uses HTTP Basic auth