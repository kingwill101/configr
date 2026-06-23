import 'dart:async';

import 'package:i3config/i3config_v2.dart' as i3;

/// Block handler for `dynamic { ... }` — repeats its child blocks once per
/// item in a list, similar to HCL's `dynamic` blocks.
///
/// ```i3
/// dynamic {
///   for_each = ["firefox", "vim", "git"]
///   package {
///     name = "$item"
///     manager = "apt"
///   }
/// }
/// ```
///
/// Properties:
/// - `for_each` — a list of strings or a comma-separated string
/// - `iterator` — optional variable name (default `"item"`) set per iteration
class DynamicBlockHandler extends i3.BaseBlockHandler {
  @override
  String get blockType => 'dynamic';

  @override
  FutureOr<void> handle(i3.Block block, i3.Context context) {
    // No setup needed
  }

  @override
  Future<void> processChildren(i3.Block block, i3.Context context) async {
    final processor =
        context.globalContext.options['_processor'] as i3.ConfigProcessor;

    // First pass: process all assignment children so for_each and iterator
    // are set as context variables before we read them.
    for (final element in block.body) {
      if (element is i3.Assignment) {
        processor.pushState(i3.InitialState());
        try {
          await processor.currentState.process(element, processor);
        } finally {
          processor.popState();
        }
      }
    }

    // Read for_each — supports list or comma-separated string
    final raw = context.getVariable('for_each');
    final items = <String>[];
    if (raw is List) {
      for (final v in raw) {
        final s = v.toString();
        if (s.isNotEmpty) items.add(s);
      }
    } else if (raw is String && raw.isNotEmpty) {
      items.addAll(
        raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty),
      );
    }
    if (items.isEmpty) return;

    final iterator = (context.getVariable('iterator') as String?) ?? 'item';

    // Collect child command-blocks (the things to repeat)
    final children = block.body
        .whereType<i3.Command>()
        .where((c) => c.block != null)
        .toList();
    if (children.isEmpty) return;

    // For each item, process all children through the state machine
    for (final item in items) {
      processor.pushContext();
      try {
        processor.context.setVariable(iterator, item);
        for (final child in children) {
          processor.pushState(i3.InitialState());
          try {
            await processor.currentState.process(child, processor);
          } finally {
            processor.popState();
          }
        }
      } finally {
        processor.popContext();
      }
    }
  }
}
