import 'dart:io';
import 'package:i3config/i3config_v2.dart' as i3;

/// Generates minimal failing test cases for upstream i3config issue submission
void main() {
  final cases = <String, String>{
    'Array syntax in block body': 'foo {\n  packages ["a", "b", "c"]\n}\n',
    'Array as command argument': 'bar {\n  items ["x", "y"]\n}\n',
    'Empty array': 'baz {\n  tags []\n}\n',
    'Single-element array': 'qux {\n  item ["single"]\n}\n',
    'Assignment with array value': 'myconfig {\n  packages = ["a", "b"]\n}\n',
  };

  print('=== Minimal Failing Cases for Upstream ===\n');
  print('Issue: i3config v2 parser rejects `[...]` array/list syntax\n');

  int failingCount = 0, passingCount = 0;

  for (final entry in cases.entries) {
    final name = entry.key;
    final inline = entry.value.replaceAll('\n', '\\n');
    try {
      i3.Config.parse(entry.value);
      passingCount++;
      print('  UNEXPECTED PASS: $name');
    } on Error catch (e) {
      failingCount++;
      print('  ✅ EXPECTED FAIL: $name');
    }
    print('     $inline');
  }

  print('\nSummary: $failingCount failing, $passingCount passing');
  print('');
  print('Root cause: The i3config v2 grammar does not accept `[...]` as');
  print('a value type in commands or assignments. It only supports:');
  print('  - String literals: "hello"');
  print('  - Number literals: 42, 3.14');
  print('  - Boolean literals: true, false');
  print('  - Variable references: \$var');
  print('');
  print('Workaround: Use comma-separated strings instead:');
  print('  packages "a, b, c"  instead of  packages ["a", "b", "c"]');
  print('');
  print('Feature request: Add support for `[...]` list/array values');
  print('in the grammar, both for command arguments and assignment values.');

  // Write to file for easy submission
  File(
    'upstream_issue_report.md',
  ).writeAsStringSync(_generateReport(cases, failingCount, passingCount));
  print('\n(Pssst — report also written to upstream_issue_report.md)');
}

String _generateReport(Map<String, String> cases, int failing, int passing) {
  final buf = StringBuffer();
  buf.writeln('# i3config v2 Parser: Array/List Syntax Not Supported');
  buf.writeln();
  buf.writeln('## Issue');
  buf.writeln(
    'The i3config v2 parser rejects `[...]` array/list syntax in command arguments and assignment values inside block bodies.',
  );
  buf.writeln();
  buf.writeln('## Expected Behavior');
  buf.writeln(
    'Arrays should be parseable as values, e.g. `packages ["a", "b", "c"]` or `items = ["x", "y"]`.',
  );
  buf.writeln();
  buf.writeln('## Actual Behavior');
  buf.writeln('`ParseError: end of input expected` at the `[` character.');
  buf.writeln();
  buf.writeln('## Minimal Reproducers');
  for (final entry in cases.entries) {
    buf.writeln('### ${entry.key}');
    buf.writeln('```i3');
    buf.writeln(entry.value.trim());
    buf.writeln('```');
    buf.writeln();
  }
  buf.writeln('## Additional Context');
  buf.writeln(
    '- The `[...]` syntax is common in tools built on i3config (like Configr) where arrays are used for package lists, environment variables, include/exclude patterns, etc.',
  );
  buf.writeln(
    '- Workaround: comma-separated strings (`packages "a, b, c"`) work fine.',
  );
  buf.writeln('- Version: i3config 2.1.1');
  buf.writeln();
  buf.writeln(
    '## Additional Feature Request: Support `resource` as a Top-Level Block',
  );
  buf.writeln(
    'The parser currently accepts `resources { resource { ... } }` but `resource { ... }` at the top level (without the `resources` wrapper) could also be supported for simpler config layouts. This would be consistent with how `echo { }`, `copy { }`, etc. work directly at the top level in Configr.',
  );
  return buf.toString();
}
