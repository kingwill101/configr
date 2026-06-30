import 'dart:io' show ProcessResult;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:file_lualike/file_lualike.dart' show useFileSystem;
import 'package:lualike/lualike.dart';
import 'package:lualike/library_builder.dart';

/// Library of assertion functions available to Lua fixture scripts.
class FixtureAssertionLibrary extends Library {
  @override
  String get name => '';

  @override
  String get description => 'Assertion functions for sweep-test fixture scripts.';

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
      builder.create((args) {
        final path = _stringArg(args, 0);
        final f = _fileSystem.file(path);
        if (!f.existsSync()) fail('file does not exist: $path');
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
      builder.create((args) {
        final path = _stringArg(args, 0);
        final f = _fileSystem.file(path);
        if (f.existsSync()) fail('file exists but should not: $path');
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
      builder.create((args) {
        final path = _stringArg(args, 0);
        final pattern = _stringArg(args, 1);
        final f = _fileSystem.file(path);
        if (!f.existsSync()) fail('file does not exist: $path');
        final content = f.readAsStringSync();
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
      builder.create((args) {
        final path = _stringArg(args, 0);
        final pattern = _stringArg(args, 1);
        final f = _fileSystem.file(path);
        if (!f.existsSync()) fail('file does not exist: $path');
        final content = f.readAsStringSync();
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
      builder.create((args) {
        final path = _stringArg(args, 0);
        final d = _fileSystem.directory(path);
        if (!d.existsSync()) fail('directory does not exist: $path');
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
      builder.create((args) {
        final path = _stringArg(args, 0);
        final d = _fileSystem.directory(path);
        if (d.existsSync()) fail('directory exists but should not: $path');
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
  }

  static String _stringArg(List<Object?> args, [int index = 0]) {
    if (index >= args.length) return '';
    final val = Value.wrap(args[index]).unwrap();
    return val?.toString() ?? '';
  }
}

class LuaFixtureRunner {
  final FileSystem _fileSystem;
  final StringBuffer _stdout;
  final StringBuffer _stderr;

  LuaFixtureRunner({
    FileSystem? fileSystem,
    StringBuffer? stdout,
    StringBuffer? stderr,
  })  : _fileSystem = fileSystem ?? const LocalFileSystem(),
        _stdout = stdout ?? StringBuffer(),
        _stderr = stderr ?? StringBuffer();

  Future<ProcessResult> run(String scriptPath) async {
    final lua = LuaLike();

    await useFileSystem(_fileSystem);
    lua.vm.libraryRegistry.register(
      FixtureAssertionLibrary(_fileSystem, _stderr),
    );
    lua.vm.libraryRegistry.initializeAll();

    try {
      final file = _fileSystem.file(scriptPath);
      if (!await file.exists()) {
        return ProcessResult(1, 1, '', 'Script not found: $scriptPath');
      }
      final content = await file.readAsString();
      await lua.execute(content, scriptPath: scriptPath);
      return ProcessResult(0, 0, _stdout.toString(), _stderr.toString());
    } catch (e) {
      _stderr.write('$e');
      return ProcessResult(0, 1, _stdout.toString(), _stderr.toString());
    }
  }
}
