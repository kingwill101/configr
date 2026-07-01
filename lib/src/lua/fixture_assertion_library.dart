import 'dart:io' show Platform;

import 'package:file/file.dart';
import 'package:lualike/library_builder.dart';

/// Library of assertion functions available to Lua fixture scripts.
class FixtureAssertionLibrary extends Library {
  @override
  String get name => 'fixture_assertions';

  @override
  String get description =>
      'Assertion functions for sweep-test fixture scripts.';

  final FileSystem _fileSystem;
  final StringBuffer _stderr;

  FixtureAssertionLibrary(this._fileSystem, this._stderr);

  void fail(String msg) {
    _stderr.writeln('ASSERT FAILED: $msg');
    throw Exception(msg);
  }

  @override
  void registerFunctions(LibraryRegistrationContext context) {
    final builder = BuiltinFunctionBuilder(context);

    context.define(
      'assertFileExists',
      builder.create((args) async {
        final path = _stringArg(args, 0);
        final f = _fileSystem.file(path);
        if (!await f.exists()) fail('file does not exist: $path');
        return null;
      }),
    );
    context.describe(
      'assertFileExists',
      FunctionDoc(
        summary: 'Asserts that a file exists.',
        params: [DocParam('path', 'string', 'Path to the file.')],
        returns: 'nil',
        category: 'assertion',
        example: r"assertFileExists('/tmp/myfile.txt')",
      ),
    );

    context.define(
      'assertFileNotExists',
      builder.create((args) async {
        final path = _stringArg(args, 0);
        final f = _fileSystem.file(path);
        if (await f.exists()) fail('file exists but should not: $path');
        return null;
      }),
    );
    context.describe(
      'assertFileNotExists',
      FunctionDoc(
        summary: 'Asserts that a file does not exist.',
        params: [DocParam('path', 'string', 'Path to the file.')],
        returns: 'nil',
        category: 'assertion',
        example: r"assertFileNotExists('/tmp/deleted.txt')",
      ),
    );

    context.define(
      'assertFileContains',
      builder.create((args) async {
        final path = _stringArg(args, 0);
        final pattern = _stringArg(args, 1);
        final f = _fileSystem.file(path);
        if (!await f.exists()) fail('file does not exist: $path');
        final content = await f.readAsString();
        if (!content.contains(pattern)) {
          fail('file does not contain pattern "$pattern": $path');
        }
        return null;
      }),
    );
    context.describe(
      'assertFileContains',
      FunctionDoc(
        summary: 'Asserts that a file contains the given substring.',
        params: [
          DocParam('path', 'string', 'Path to the file.'),
          DocParam('pattern', 'string', 'Substring to search for.'),
        ],
        returns: 'nil',
        category: 'assertion',
        example: r"assertFileContains('/tmp/log.txt', 'success')",
      ),
    );

    context.define(
      'assertFileNotContains',
      builder.create((args) async {
        final path = _stringArg(args, 0);
        final pattern = _stringArg(args, 1);
        final f = _fileSystem.file(path);
        if (!await f.exists()) fail('file does not exist: $path');
        final content = await f.readAsString();
        if (content.contains(pattern)) {
          fail('file contains forbidden pattern "$pattern": $path');
        }
        return null;
      }),
    );
    context.describe(
      'assertFileNotContains',
      FunctionDoc(
        summary: 'Asserts that a file does not contain the given substring.',
        params: [
          DocParam('path', 'string', 'Path to the file.'),
          DocParam('pattern', 'string', 'Substring to search for.'),
        ],
        returns: 'nil',
        category: 'assertion',
        example: r"assertFileNotContains('/tmp/log.txt', 'ERROR')",
      ),
    );

    context.define(
      'assertDirExists',
      builder.create((args) async {
        final path = _stringArg(args, 0);
        final d = _fileSystem.directory(path);
        if (!await d.exists()) fail('directory does not exist: $path');
        return null;
      }),
    );
    context.describe(
      'assertDirExists',
      FunctionDoc(
        summary: 'Asserts that a directory exists.',
        params: [DocParam('path', 'string', 'Path to the directory.')],
        returns: 'nil',
        category: 'assertion',
        example: r"assertDirExists('/tmp/mydir')",
      ),
    );

    context.define(
      'assertDirNotExists',
      builder.create((args) async {
        final path = _stringArg(args, 0);
        final d = _fileSystem.directory(path);
        if (await d.exists()) fail('directory exists but should not: $path');
        return null;
      }),
    );
    context.describe(
      'assertDirNotExists',
      FunctionDoc(
        summary: 'Asserts that a directory does not exist.',
        params: [DocParam('path', 'string', 'Path to the directory.')],
        returns: 'nil',
        category: 'assertion',
        example: r"assertDirNotExists('/tmp/deleted_dir')",
      ),
    );

    context.define(
      'makeDir',
      builder.create((args) async {
        final path = _stringArg(args, 0);
        await _fileSystem.directory(path).create(recursive: true);
        return null;
      }),
    );
    context.describe(
      'makeDir',
      FunctionDoc(
        summary: 'Creates a directory recursively (like mkdir -p).',
        params: [DocParam('path', 'string', 'Directory path to create.')],
        returns: 'nil',
        category: 'filesystem',
        example: "makeDir(tempDir() .. '/mydir')",
      ),
    );

    context.define(
      'removeTree',
      builder.create((args) async {
        final path = _stringArg(args, 0);
        final d = _fileSystem.directory(path);
        if (await d.exists()) await d.delete(recursive: true);
        return null;
      }),
    );
    context.describe(
      'removeTree',
      FunctionDoc(
        summary: 'Removes a directory tree (like rm -rf).',
        params: [DocParam('path', 'string', 'Directory path to remove.')],
        returns: 'nil',
        category: 'filesystem',
        example: "removeTree(tempDir() .. '/mydir')",
      ),
    );

    context.define(
      'tempDir',
      builder.create((_) => _fileSystem.systemTempDirectory.path),
    );
    context.describe(
      'tempDir',
      FunctionDoc(
        summary: 'Returns the OS temporary directory path.',
        returns: 'string',
        category: 'system',
        example: "local tmp = tempDir()",
      ),
    );

    context.define('osName', builder.create((_) => Platform.operatingSystem));
    context.describe(
      'osName',
      FunctionDoc(
        summary: 'Returns the OS name (linux, macos, windows, etc).',
        returns: 'string',
        category: 'system',
        example: "if osName() == 'windows' then ... end",
      ),
    );
  }

  static String _stringArg(List<Object?> args, [int index = 0]) {
    if (index >= args.length) {
      throw ArgumentError('Missing required argument at index $index');
    }
    final val = Value.wrap(args[index]).unwrap();
    return val?.toString() ?? '';
  }
}
