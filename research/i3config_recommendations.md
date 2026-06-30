# i3config Library Recommendations

## 1. Handler Lifecycle: Expose Command Args to Block Handlers

**Problem:** When `host "web-01" { address = "10.0.0.1" }` is parsed, it produces a `Command(head='host', args=[Quoted('web-01')], block=Block(...))`. The handler lifecycle (`handle`, `processChildren`, `afterChildrenProcessed`) receives only the **inner `Block`** — the part inside `{ }`. The identifier (`"web-01"`) lives in `command.args` and is inaccessible to handlers.

The identifier IS computed in `_processCommandWithBlock` (line 226) but stored via `registerBlock` in the `finally` block — **after** `afterChildrenProcessed` returns. Handlers that need the identifier (e.g., to name a host) cannot get it.

**Fix:** Either:
- Pass the identifier to `handle()` as a parameter, or
- Store it in the context (`context.currentBlockIdentifier`) before calling `handle()`, alongside `context.currentBlockType`.

## 2. Clarify `processChildren` Return Semantics

**Problem:** `processChildren` returns `FutureOr<bool>?`. The caller checks `if (customProcessing != null)`. But `BaseBlockHandler` returns `false` (not null), causing `await false` to run and **skip** default child processing. The intent was that `false` means "I didn't handle it, process defaults" — but `false` is not null, so default processing never runs.

```dart
// state.dart line 190-207
final customProcessing = handler.processChildren(block, processor.context);
if (customProcessing != null) {
  await customProcessing;  // false is not null, so this runs
} else {
  // NEVER REACHED for default BaseBlockHandler
  for (final element in block.body) { ... }
}
```

**Fix:** Change to a tri-state return or check `== true` instead of `!= null`:
- `null` → use default processing
- `Future<void>` → custom async processing, skip defaults  
- (remove `bool` return entirely since it's misleading)

## 3. Add Parent Pointers to AST Nodes

**Problem:** No way to navigate from a child AST node to its parent. A handler receiving a `Block` cannot find the wrapping `Command` or its `args`. This makes it impossible to access command-level metadata (like identifiers) from within the handler lifecycle.

**Fix:** Add an optional `parent` field to `ConfigElement`:

```dart
abstract class ConfigElement {
  ConfigElement? parent;
  SourceSpan? span;
  // ...
}
```

Set it during parsing so handlers can walk up the tree when needed.

## 4. Support Inline Blocks with Semicolons in Nested Contexts

**Problem:** The parser rejects inline blocks with semicolons when nested inside another block:

```i3
inventory {
  host "web-01" { address = "10.0.0.1"; roles = ["web"] }  # Parse error
}
```

But multi-line versions work:

```i3
inventory {
  host "web-01" {
    address = "10.0.0.1"
    roles = ["web"]
  }
}
```

This is inconsistent — top-level inline blocks work fine.

**Fix:** Debug the grammar rule for nested blocks to handle semicolons as assignment separators inside inline `{ }`.

## 5. Expose `expandValue` as a Static/Utility Method

**Problem:** `expandValue` is a mixin/instance method on `BaseBlockHandler` and `BaseCommandHandler`. Handlers that don't extend these bases (e.g., custom `BlockHandler` implementations) must duplicate the expansion logic.

**Fix:** Make `expandValue` a top-level function or static method on `Context`:

```dart
// In Context:
static String expandValue(Value value, Context context);
```

## 6. Better Context API for Variable Handling

**Problem:** `Context.getVariable()` returns `dynamic`, exposing raw parsed values. There's no distinction between "variable not set" and "variable set to empty string". Lists come through as `List<dynamic>` requiring manual casting.

**Fix:** Add typed accessors:

```dart
class Context {
  T? get<T>(String name) => variables[name] as T?;
  String getString(String name, [String defaults = '']) => ...;
  List<String> getList(String name) => ...;
  bool getBool(String name) => ...;
}
```

## 7. RegisterBlock Data Flow Could Be More Transparent

**Problem:** `registerBlock` stores context variables in `blockRegistry` keyed by `(blockType, identifier)`, but this happens in `_processCommandWithBlock`'s `finally` block — after `afterChildrenProcessed`. The only way for parent handlers to access child data is through `blockRegistry`, which is both powerful and opaque.

**Fix:** Document that `blockRegistry` is the intended cross-block communication channel, and consider adding a `getBlockVariables(blockType, identifier)` helper:

```dart
Map<String, dynamic>? getChildBlock(String type, String? identifier) {
  return blockRegistry[type]?[identifier];
}
```

Also consider adding a `countBlock(blockType)` and `getAllBlocks(blockType)` for iterating registered children.

## 8. Sensitive Value Handling

**Problem:** The library has no concept of sensitive/secret values. Variables are plain strings that get logged, serialized, and exposed in `toConfigString()`.

**Fix:** Introduce a `SensitiveValue` wrapper:

```dart
class SensitiveValue {
  final String value;
  const SensitiveValue(this.value);

  @override
  String toString() => '***';
  String toConfigString() => '***';
}
```

And allow `Context.getVariable` to optionally mask sensitive values in logs/serialization. A `Set<String>` of sensitive variable names (`_secrets`) on Context would let the engine auto-mask them.

## 9. Error Reporting Could Include Source Location

**Problem:** `Context.reportError(String message, {SourceSpan? span})` has an optional span that's rarely populated. Parse errors show line:column, but runtime handler errors don't.

**Fix:** Require or always populate `SourceSpan` on errors, or at minimum track the current line/column in Context so handlers can report meaningful locations.

## 10. Document the Handler Lifecycle

**Problem:** The three-stage handler lifecycle (handle → processChildren → afterChildrenProcessed) and the `blockRegistry` cross-block communication pattern are undocumented. Developers must read `state.dart` to understand the contract.

**Fix:** Add doc comments to `BlockHandler` explaining:
- When each stage is called (before/after child processing)
- What data is available at each stage (variables not yet set vs. fully populated)
- How `blockRegistry` works for parent-child data exchange
- Return value semantics of `processChildren`
