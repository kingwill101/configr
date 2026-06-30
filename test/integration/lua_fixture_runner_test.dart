library;

import 'package:test/test.dart';
import 'lua_fixture_runner.dart';
import 'dart:io';

/// Normalizes a file path for embedding in Lua strings by replacing
/// Windows backslashes with forward slashes.
String _luaPath(String path) => path.replaceAll('\\', '/');

void main() {
  test('LuaFixtureRunner assertions work', () async {
    final dir = Directory.systemTemp.createTempSync('lua_test_');
    addTearDown(() => dir.deleteSync(recursive: true));

    File('${dir.path}/test.txt').writeAsStringSync('hello fixture runner');

    final testPath = _luaPath('${dir.path}/test.txt');
    final script = File('${dir.path}/assert.lua');
    script.writeAsStringSync('''
assertFileExists("$testPath")
assertFileContains("$testPath", "fixture")
assertFileNotContains("$testPath", "missing")
''');

    final runner = LuaFixtureRunner();
    final result = await runner.run(script.path);
    expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
    expect(result.stderr, isEmpty);
  });

  test('LuaFixtureRunner assertion failures', () async {
    final dir = Directory.systemTemp.createTempSync('lua_test2_');
    addTearDown(() => dir.deleteSync(recursive: true));

    final script = File('${dir.path}/fail.lua');
    script.writeAsStringSync('''
assertFileExists("/nonexistent/path")
''');

    final runner = LuaFixtureRunner();
    final result = await runner.run(script.path);
    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('ASSERT FAILED'));
  });
}
