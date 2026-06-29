# Secrets Block

The `secrets` block resolves secret URIs and exposes the resolved values as
configuration variables. Resolved sensitive values are registered with the
redaction middleware so they are hidden from logs and event output.

```i3
secrets {
  provider prod_db = env://DATABASE_URL
  database_url = "prod_db"
  deploy_token = "file:///run/secrets/deploy-token"
}

template {
  source = "./app.env.liquid"
  destination = "/etc/app.env"
  variables = {
    DATABASE_URL = "$database_url"
    DEPLOY_TOKEN = "$deploy_token"
  }
}
```

## Providers

Built-in providers include:

| Provider | URI form |
|----------|----------|
| `env` | `env://NAME` |
| `file` | `file:///path/to/secret` |
| `dotenv` | `dotenv://path?key=NAME` |
| `cmd` | `cmd://command` |
| `onepassword` | provider-specific 1Password URI |
| `keyring` | provider-specific keyring URI |
| `bitwarden` | provider-specific Bitwarden URI |
| `aws` | AWS Secrets Manager URI |
| `gcp` | GCP Secret Manager URI |
| `doppler` | Doppler URI |

## Aliases

Use `provider <alias> = <uri>` to define aliases, then assign variables to the
alias name:

```i3
secrets {
  provider api_key = env://CONFIGR_API_KEY
  token = "api_key"
}
```

See the [secrets guide](../guides/secrets.md) for provider-specific examples
and redaction behavior.

