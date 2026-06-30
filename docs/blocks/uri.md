# URI Block

Makes HTTP/HTTPS requests with configurable method, headers, and body.

## Usage

### Simple GET Request
```
uri {
  url = "https://api.example.com/health"
}
```

### POST with JSON Body
```
uri {
  url = "https://api.example.com/data"
  method = "POST"
  headers = { "Content-Type": "application/json" }
  body = "{\"key\": \"value\"}"
}
```

### Validate Response Status
```
uri {
  url = "https://api.example.com/status"
  method = "GET"
  status_code = 204
  timeout = 10
}
```

### Disable TLS Verification
```
uri {
  url = "https://self-signed.internal/health"
  method = "GET"
  validate_certs = false
}
```

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `url` | `string` | `""` | Target URL for the HTTP request |
| `method` | `string` | `"GET"` | HTTP method: `GET`, `POST`, `PUT`, `DELETE`, `PATCH`, `HEAD` |
| `headers` | `map` | `{}` | HTTP headers to include in the request |
| `body` | `string` | `""` | Request body (ignored for GET and HEAD) |
| `status_code` | `int` | `200` | Expected HTTP response status code |
| `timeout` | `int` | `30` | Connection and response timeout in seconds |
| `validate_certs` | `boolean` | `true` | Whether to validate TLS certificates |

## Context Variables Set

| Variable | Description |
|----------|-------------|
| `uri_status` | HTTP response status code |
| `uri_content` | Response body as a string |
| `uri_method` | HTTP method used |
| `uri_url` | Target URL |

## Platform Support

| Platform | Implementation |
|----------|---------------|
| Linux | Full |
| macOS | Full |
| FreeBSD | Full |

Cross-platform — uses Dart's `dart:io` `HttpClient`.

## Rollback

No rollback necessary. HTTP requests are side-effect operations on remote systems and cannot be automatically undone.
