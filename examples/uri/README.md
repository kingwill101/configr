# URI Action Block

The `uri` action block makes HTTP requests to remote endpoints.

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `url` | string | — | The URL to request |
| `method` | string | `"GET"` | HTTP method (`GET`, `POST`, `PUT`, `DELETE`, etc.) |
| `status_code` | int | — | Expected HTTP status code for validation |

## How It Works

Configr sends an HTTP request to the specified URL using the given method. If `status_code` is set, Configr validates the response matches the expected code and fails if it doesn't.

## Usage

```bash
configr apply config
```

This will perform a `GET` request to `https://api.example.com/health` and verify the response status is `200`.
