# i3config v2: Array/List Syntax Support

## Status: ✅ Resolved in i3config 2.3.0

The `[...]` array/list syntax that was rejected in i3config 2.1.1 is now
fully supported in version 2.3.0. All test cases pass.

The array value is represented as `ArrayValue` in the AST, with `items`
containing the list of `Value` elements.

### Usage
```i3
my_block {
  packages ["a", "b", "c"]
  items = ["x", "y"]
  tags []
  single ["one"]
}
```

## Feature Request: Support `resource` as a Top-Level Block

The parser currently accepts `resources { resource { ... } }` but
`resource { ... }` at the top level (without the `resources` wrapper)
is not yet supported. This would be useful for simpler config layouts
where a single resource block is needed without the wrapper.

### Current behavior
```i3
# Works:
resources {
  resource {
    copy { source = "/tmp/a" destination = "/tmp/b" }
  }
}

# Does not work:
resource {
  copy { source = "/tmp/a" destination = "/tmp/b" }
}
```
