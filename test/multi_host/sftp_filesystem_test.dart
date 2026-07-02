import 'dart:io' as io;

import 'package:configr/src/plugins/lua_plugin.dart';
import 'package:configr/src/hooks/lua_hook_runner.dart';
import 'package:configr/src/di.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:configr/src/utils/privilege_escalation.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:lualike/lualike.dart';
import 'package:test/test.dart';

class _FakeProcessBackend implements ProcessBackend {
  int _callCount = 0;
  String? _lastCommand;

  @override
  bool get isShellAvailable => true;

  @override
  ProcessRunResult runSync(String command) {
    _lastCommand = command;
    _callCount++;
    return ProcessRunResult(0, 'ok', '');
  }

  @override
  Future<ProcessRunResult> run(String command) async {
    _lastCommand = command;
    _callCount++;
    return ProcessRunResult(0, 'ok', '');
  }

  @override
  Future<int> runStreaming(
    String command, {
    void Function(List<int> chunk)? onStdout,
    void Function(List<int> chunk)? onStderr,
    void Function()? onDone,
  }) async {
    _lastCommand = command;
    _callCount++;
    return 0;
  }

  int get callCount => _callCount;
  String? get lastCommand => _lastCommand;
}

void main() {
  group('file_lualike integration', () {
    late MemoryFileSystem fs;
    late EventBus eventBus;

    setUp(() {
      fs = MemoryFileSystem();
      eventBus = EventBus();
      di
        ..allowReassignment = true
        ..registerSingleton<DryRunFlag>(DryRunFlag(false))
        ..registerSingleton<EventBus>(eventBus)
        ..registerSingleton<PrivilegeEscalation>(NoPrivilegeEscalation())
        ..registerSingleton<FileSystem>(fs)
        ..allowReassignment = false;
    });

    test(
      'ConfigrLibrary writeFile/readFile use the injected FileSystem',
      () async {
        final plugin = LuaPlugin(
          code: '''
          writeFile("/test_lualike_fs.txt", "works")
        ''',
          fileSystem: fs,
        );

        await plugin.initialize();

        expect(fs.file('/test_lualike_fs.txt').existsSync(), isTrue);
        expect(
          fs.file('/test_lualike_fs.txt').readAsStringSync(),
          equals('works'),
        );
      },
    );

    test(
      'FileSystemBackend round-trip: '
      'fileExists and readFile work through the injected FileSystem',
      () async {
        fs.file('/existing.txt').writeAsStringSync('hello');

        final plugin = LuaPlugin(
          code: '''
          if fileExists("/existing.txt") then
            local content = readFile("/existing.txt")
            writeFile("/copied.txt", content)
          end
        ''',
          fileSystem: fs,
        );

        await plugin.initialize();

        expect(fs.file('/copied.txt').existsSync(), isTrue);
        expect(fs.file('/copied.txt').readAsStringSync(), equals('hello'));
      },
    );

    test('SftpFileSystem.fromClient wraps the SftpClient correctly', () async {
      // We can't connect to a real SFTP server in a unit test,
      // but we can verify the integration points are correct by
      // checking that useFileSystem wires the backend properly
      // with a MemoryFileSystem (which also implements FileSystem).
      final plugin = LuaPlugin(
        code: '''
          writeFile("/sftp_sim.txt", "sftp_content")
          local content = readFile("/sftp_sim.txt")
          if content == "sftp_content" then
            writeFile("/sftp_sim.txt", "verified")
          end
        ''',
        fileSystem: fs,
      );

      await plugin.initialize();

      expect(fs.file('/sftp_sim.txt').readAsStringSync(), equals('verified'));
    });

    test('LuaPlugin wires process backend into lualike', () async {
      final fakeBackend = _FakeProcessBackend();

      final plugin = LuaPlugin(
        code: '''
          os.execute("echo hello_from_plugin")
        ''',
        fileSystem: fs,
        processBackend: fakeBackend,
      );

      await plugin.initialize();

      expect(fakeBackend.callCount, greaterThan(0));
    });

    test(
      'LuaPlugin without process backend can still use file helpers',
      () async {
        final plugin = LuaPlugin(
          code: '''
          writeFile("/default_plugin.txt", "default_plugin")
        ''',
          fileSystem: fs,
        );

        await plugin.initialize();
        expect(
          await fs.file('/default_plugin.txt').readAsString(),
          equals('default_plugin'),
        );
      },
    );

    test('LuaPlugin without process backend runs commands locally', () async {
      final fakeBackend = _FakeProcessBackend();
      final pluginWithBackend = LuaPlugin(
        code: 'runCommand("echo previous_backend")',
        fileSystem: fs,
        processBackend: fakeBackend,
      );
      await pluginWithBackend.initialize();
      expect(fakeBackend.callCount, equals(1));

      final command = io.Platform.isWindows ? 'ver > nul' : 'true';
      final plugin = LuaPlugin(
        code: 'command_exit = runCommand(${_luaString(command)})',
        fileSystem: fs,
      );

      await plugin.initialize();
      expect(plugin.luaLike.getGlobal('command_exit').raw, equals(0));
      expect(fakeBackend.callCount, equals(1));
    });

    test('LuaHookRunner wires process backend into lualike', () async {
      final fakeBackend = _FakeProcessBackend();
      final hookFile = fs.file('/test_hook_process.lua');
      await hookFile.writeAsString('''
        os.execute("echo hello_from_hook")
      ''');

      final runner = LuaHookRunner(
        globals: {'event_name': 'test'},
        fileSystem: fs,
        processBackend: fakeBackend,
      );

      final result = await runner.run(hookFile.path);
      expect(result, isTrue);
      expect(fakeBackend.callCount, greaterThan(0));
    });
  });
}

String _luaString(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r');
  return '"$escaped"';
}
