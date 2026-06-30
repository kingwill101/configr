library;

import 'package:test/test.dart';
import 'lua_fixture_runner.dart';
import 'dart:io';

void main() {
  test('LuaFixtureRunner assertions work', () async {
    final dir = Directory.systemTemp.createTempSync('lua_test_');
    File('${dir.path}/test.txt').writeAsStringSync('hello fixture runner');

    final script = File('${dir.path}/assert.lua');
    script.writeAsStringSync('''
assertFileExists("${dir.path}/test.txt")
assertFileContains("${dir.path}/test.txt", "fixture")
assertFileNotContains("${dir.path}/test.txt", "missing")
''');

    final runner = LuaFixtureRunner();
    final result = await runner.run(script.path);
    expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
    expect(result.stderr, isEmpty);

    dir.deleteSync(recursive: true);
  });

  test('LuaFixtureRunner assertion failures', () async {
    final dir = Directory.systemTemp.createTempSync('lua_test2_');
    final script = File('${dir.path}/fail.lua');
    script.writeAsStringSync('''
assertFileExists("/nonexistent/path")
''');

    final runner = LuaFixtureRunner();
    final result = await runner.run(script.path);
    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('ASSERT FAILED'));

    dir.deleteSync(recursive: true);
  });
}
