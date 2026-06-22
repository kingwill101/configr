# i3config v2 Parser: Array/List Syntax Not Supported

## Issue
The i3config v2 parser rejects `[...]` array/list syntax in command arguments and assignment values inside block bodies.

## Expected Behavior
Arrays should be parseable as values, e.g. `packages ["a", "b", "c"]` or `items = ["x", "y"]`.

## Actual Behavior
`ParseError: end of input expected` at the `[` character.

## Minimal Reproducers
### Array syntax in block body
```i3
foo {
  packages ["a", "b", "c"]
}
```

### Array as command argument
```i3
bar {
  items ["x", "y"]
}
```

### Empty array
```i3
baz {
  tags []
}
```

### Single-element array
```i3
qux {
  item ["single"]
}
```

### Assignment with array value
```i3
myconfig {
  packages = ["a", "b"]
}
```

## Additional Context
- The `[...]` syntax is common in tools built on i3config (like Configr) where arrays are used for package lists, environment variables, include/exclude patterns, etc.
- Workaround: comma-separated strings (`packages "a, b, c"`) work fine.
- Version: i3config 2.1.1

## Additional Feature Request: Support `resource` as a Top-Level Block
The parser currently accepts `resources { resource { ... } }` but `resource { ... }` at the top level (without the `resources` wrapper) could also be supported for simpler config layouts. This would be consistent with how `echo { }`, `copy { }`, etc. work directly at the top level in Configr.
