# UFW Block

Manages UFW (Uncomplicated Firewall) rules and state.

## Usage

### Allow a Port
```
ufw {
  rule = "allow"
  port = "8080"
  proto = "tcp"
}
```

### Deny Inbound from an IP
```
ufw {
  rule = "deny"
  direction = "in"
  from = "10.0.0.1"
}
```

### Enable UFW with Limit Rule
```
ufw {
  state = "enabled"
  rule = "limit"
  port = "22"
  proto = "tcp"
  direction = "in"
}
```

### Reset UFW
```
ufw {
  state = "reset"
}
```

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `rule` | `string` | `""` | Rule type: `allow`, `deny`, `reject`, `limit` |
| `port` | `string` | `""` | Port number or service name |
| `proto` | `string` | `""` | Protocol: `tcp`, `udp` |
| `direction` | `string` | `""` | Traffic direction: `in`, `out` |
| `from` | `string` | `""` | Source IP or CIDR (with `to` for full syntax) |
| `to` | `string` | `""` | Destination IP or CIDR |
| `state` | `string` | `""` | Firewall state: `enabled`, `disabled`, `reloaded`, `reset` |
| `interface` | `string` | `""` | Network interface (e.g., `eth0`) |
| `log` | `string` | `""` | Log level for the rule |

## Platform Support

| Platform | Implementation | Commands Used |
|----------|---------------|---------------|
| Linux | Full | `ufw` (with `--force` for enable/reset) |
| macOS | Not supported | — |
| FreeBSD | Not supported | — |

Linux only. Requires `ufw` to be installed on the target system.

## Rollback

The block tracks state changes and applied rules. On rollback:
- If the firewall was **enabled**, it is **disabled**.
- If the firewall was **disabled**, it is **enabled**.
- If the firewall was **reset**, the reset cannot be undone (best effort).
- Applied rules are **deleted** via `ufw delete <rule>`.
