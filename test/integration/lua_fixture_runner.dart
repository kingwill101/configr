import 'dart:io' show ProcessResult;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:file_lualike/file_lualike.dart' show useFileSystem;
import 'package:lualike/lualike.dart';

import 'package:configr/src/lua/fixture_assertion_library.dart';

class LuaFixtureRunner {
  final FileSystem _fileSystem;
  final StringBuffer _stdout;
  final StringBuffer _stderr;

  LuaFixtureRunner({
    FileSystem? fileSystem,
    StringBuffer? stdout,
    StringBuffer? stderr,
  }) : _fileSystem = fileSystem ?? const LocalFileSystem(),
       _stdout = stdout ?? StringBuffer(),
       _stderr = stderr ?? StringBuffer();

  Future<ProcessResult> run(String scriptPath) async {
    _stdout.clear();
    _stderr.clear();

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
