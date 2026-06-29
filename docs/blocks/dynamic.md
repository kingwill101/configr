# Dynamic Block

The `dynamic` block repeats its child blocks once per item in a list. During
each iteration Configr sets an iterator variable in the child context.

```i3
dynamic {
  for_each = ["git", "curl", "vim"]

  package {
    name = "$item"
    state = "present"
  }
}
```

## Properties

| Property | Default | Description |
|----------|---------|-------------|
| `for_each` | required | List of values, or a comma-separated string |
| `iterator` | `item` | Variable name set for each iteration |

## Custom Iterator

```i3
dynamic {
  for_each = "nginx,postgresql,redis"
  iterator = "service_name"

  service {
    name = "$service_name"
    state = "started"
  }
}
```

Only child blocks are repeated. Assignments such as `for_each` and `iterator`
are consumed before expansion and are not emitted as actions.

