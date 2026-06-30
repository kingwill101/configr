# Firewalld Block

Manages firewalld services, ports, sources, and rich rules on Linux systems. Uses `firewall-cmd` to apply changes to both the running configuration and permanent firewall rules.

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `service` | `string` | `""` | Firewalld service name (e.g. `http`, `ssh`) |
| `port` | `string` | `""` | Port specification (e.g. `"8080/tcp"`, `"53/udp"`) |
| `zone` | `string` | `"public"` | Firewalld zone to apply the rule to |
| `source` | `string` | `""` | Source address/subnet (e.g. `"192.168.1.0/24"`) |
| `rich_rule` | `string` | `""` | Rich rule specification |
| `state` | `string` | `""` | `enabled` to add, `disabled` to remove |
| `permanent` | `boolean` | `true` | Apply change to permanent configuration |
| `immediate` | `boolean` | `false` | Immediately apply change to runtime configuration |

## Examples

### Allow a Service

```
firewalld {
  service = "http"
  zone = "public"
  state = "enabled"
}
```

### Open a Port

```
firewalld {
  port = "8080/tcp"
  zone = "internal"
  state = "enabled"
  permanent = "true"
  immediate = "true"
}
```

### Remove a Rich Rule

```
firewalld {
  rich_rule = "rule family=ipv4 source address=10.0.0.0/8 reject"
  zone = "public"
  state = "disabled"
}
```

## Platform Support

| Platform | Implementation |
|----------|---------------|
| Linux | Full (requires firewalld) |
| macOS | Not supported |
| FreeBSD | Not supported |

## Rollback

Rollback **is supported**. When rolled back, firewalld automatically reverses the operation — rules that were added are removed, and rules that were removed are re-added.
