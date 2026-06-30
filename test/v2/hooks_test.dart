import 'dart:io' show ProcessResult;

import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/di.dart';
import 'package:configr/src/hooks/hook_manager.dart';
import 'package:configr/src/hooks/lua_hook_runner.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:configr/src/utils/privilege_escalation.dart';
import 'package:configr/src/utils/execution_service.dart';
import 'package:configr/src/utils/command_runner.dart';
import 'package:configr/src/utils/file_service.dart';
import 'package:configr/src/reader/handlers/configr_handlers.dart';
import 'package:configr/src/blocks/secrets_block.dart';
import 'package:configr/src/blocks/echo_block.dart';
import 'package:file/file.dart' show FileSystem;
import 'package:file/memory.dart';
import 'package:i3config/i3config_v2.dart' as i3;
import 'package:test/test.dart';

void main() {
  group('LuaHookRunner', () {
    late MemoryFileSystem fs;

    setUp(() async {
      fs = MemoryFileSystem();
      await fs.directory('/tmp').create(recursive: true);
    });

    test('runs a Lua hook script', () async {
      final hookFile = fs.file('/hooks/pre-apply.lua');
      await hookFile.create(recursive: true);
      await hookFile.writeAsString('');

      final runner = LuaHookRunner(
        globals: {'event_name': 'pre-apply'},
        fileSystem: fs,
      );

      final result = await runner.run('/hooks/pre-apply.lua');
      expect(result, isTrue);
    });

    test('hook globals are accessible in Lua script via writeFile', () async {
      final hookFile = fs.file('/hooks/test.lua');
      await hookFile.create(recursive: true);
      await hookFile.writeAsString('''
        writeFile("/tmp/hook_ran.txt", event_name .. ":" .. config_path)
      ''');

      final runner = LuaHookRunner(
        globals: {
          'event_name': 'pre-apply',
          'config_path': '/etc/configr/config',
        },
        fileSystem: fs,
      );

      final result = await runner.run('/hooks/test.lua');
      expect(result, isTrue);

      final markerFile = fs.file('/tmp/hook_ran.txt');
      expect(await markerFile.exists(), isTrue);
      expect(await markerFile.readAsString(), 'pre-apply:/etc/configr/config');
    });

    test('uses getEnv from ConfigrLibrary', () async {
      final hookFile = fs.file('/hooks/env_test.lua');
      await hookFile.create(recursive: true);
      await hookFile.writeAsString('''
        local home = getEnv("HOME")
        writeFile("/tmp/home.txt", home)
      ''');

      final runner = LuaHookRunner(
        globals: {'event_name': 'test'},
        fileSystem: fs,
      );

      final result = await runner.run('/hooks/env_test.lua');
      expect(result, isTrue);

      final markerFile = fs.file('/tmp/home.txt');
      expect(await markerFile.exists(), isTrue);
    });

    test('returns false for nonexistent file', () async {
      final runner = LuaHookRunner(
        globals: {'event_name': 'test'},
        fileSystem: fs,
      );

      final result = await runner.run('/nonexistent.lua');
      expect(result, isFalse);
    });
  });

  group('HookManager', () {
    late MemoryFileSystem fs;

    setUp(() async {
      fs = MemoryFileSystem();
      await fs.directory('/tmp').create(recursive: true);
    });

    test('detects hook files by event name', () async {
      final hooksDir = '/.configr/hooks';
      final hookFile = fs.file('$hooksDir/pre-apply.lua');
      await hookFile.create(recursive: true);
      await hookFile.writeAsString('');

      final mgr = HookManager(hooksDir: hooksDir, fileSystem: fs);
      expect(mgr.hasEvent('pre-apply'), isTrue);
      expect(mgr.hasEvent('post-apply'), isFalse);
    });

    test('runs a Lua hook script successfully', () async {
      final hooksDir = '/.configr/hooks';
      final hookFile = fs.file('$hooksDir/pre-apply.lua');
      await hookFile.create(recursive: true);
      await hookFile.writeAsString('');

      final mgr = HookManager(hooksDir: hooksDir, fileSystem: fs);
      final result = await mgr.runEvent('pre-apply');
      expect(result, isTrue);
    });

    test('returns false when no hook exists for event', () async {
      final mgr = HookManager(hooksDir: '/.configr/hooks', fileSystem: fs);
      final result = await mgr.runEvent('pre-apply');
      expect(result, isFalse);
    });

    test('returns false when hooks directory does not exist', () async {
      final mgr = HookManager(hooksDir: '/nonexistent', fileSystem: fs);
      final result = await mgr.runEvent('pre-apply');
      expect(result, isFalse);
    });

    test('pre-block hook passes block context variables', () async {
      final hooksDir = '/.configr/hooks';
      final hookFile = fs.file('$hooksDir/pre-block.lua');
      await hookFile.create(recursive: true);
      await hookFile.writeAsString('''
        writeFile("/tmp/hook_block.txt",
                   event_name .. ":" .. block_type .. ":" .. block_id)
      ''');

      final mgr = HookManager(hooksDir: hooksDir, fileSystem: fs);
      final result = await mgr.runEvent(
        'pre-block',
        extraVars: {'block_type': 'echo', 'block_id': 'echo_0'},
      );

      expect(result, isTrue);
      final markerFile = fs.file('/tmp/hook_block.txt');
      expect(await markerFile.exists(), isTrue);
      expect(await markerFile.readAsString(), 'pre-block:echo:echo_0');
    });

    test('uploads and runs Bash hooks through execution service', () async {
      final hooksDir = '/.configr/hooks';
      final hookFile = fs.file('$hooksDir/pre-apply.sh');
      await hookFile.create(recursive: true);
      await hookFile.writeAsString(
        'echo "\$CONFIGR_EVENT:\$CONFIGR_CONFIG_PATH"',
      );
      final executionService = _FakeRemoteExecutionService();

      final mgr = HookManager(
        hooksDir: hooksDir,
        fileSystem: fs,
        executionService: executionService,
      );

      final result = await mgr.runEvent(
        'pre-apply',
        extraVars: {'config_path': '/workspace/config'},
      );

      expect(result, isTrue);
      expect(executionService.putDestinations, hasLength(1));
      expect(executionService.commands, contains(startsWith('bash /tmp/')));
      expect(
        executionService.environment?['CONFIGR_CONFIG_PATH'],
        equals('/workspace/config'),
      );
    });

    test('known events list is comprehensive', () async {
      expect(HookManager.knownEvents, contains('pre-apply'));
      expect(HookManager.knownEvents, contains('post-apply'));
      expect(HookManager.knownEvents, contains('pre-block'));
      expect(HookManager.knownEvents, contains('post-block'));
      expect(HookManager.knownEvents, contains('pre-connect'));
      expect(HookManager.knownEvents, contains('on-error'));
    });
  });

  group('Hook integration with ActionBlock', () {
    late MemoryFileSystem fs;
    late EventBus eventBus;

    setUp(() async {
      fs = MemoryFileSystem();
      await fs.directory('/tmp').create(recursive: true);
      eventBus = EventBus();

      di
        ..allowReassignment = true
        ..registerSingleton<DryRunFlag>(DryRunFlag(false))
        ..registerSingleton<EventBus>(eventBus)
        ..registerSingleton<PrivilegeEscalation>(NoPrivilegeEscalation())
        ..registerSingleton<FileSystem>(fs)
        ..registerSingleton<ExecutionService>(const LocalExecutionService())
        ..registerSingleton<FileService>(LocalFileService())
        ..registerSingleton<CommandRunner>(LocalCommandRunner())
        ..allowReassignment = false;
    });

    test('pre-block hook file written via HookManager in context', () async {
      final hooksDir = '/.configr/hooks';
      await fs.directory(hooksDir).create(recursive: true);
      await fs.file('$hooksDir/pre-block.lua').writeAsString('''
        writeFile("/tmp/pre_block.txt", block_type .. ":" .. block_id)
      ''');

      await fs.file('$hooksDir/post-block.lua').writeAsString('''
        writeFile("/tmp/post_block.txt", block_type .. ":" .. block_id)
      ''');

      final parsed = i3.Config.parse('''
        echo {
          message = "test-hook"
        }
      ''');

      final processor = i3.ConfigProcessor();
      final actionBlocks = <ActionBlock>[];
      processor.context.options['_actionBlocks'] = actionBlocks;
      processor.context.options['_hookManager'] = HookManager(
        hooksDir: hooksDir,
        fileSystem: fs,
      );

      _registerTestBlocks(processor);

      await processor.process(parsed);

      // Blocks executed
      expect(actionBlocks, hasLength(1));

      // Pre-block hook ran — wrote the marker file
      final preFile = fs.file('/tmp/pre_block.txt');
      expect(await preFile.exists(), isTrue);
      expect(await preFile.readAsString(), 'echo:echo_0');

      // Post-block hook ran
      final postFile = fs.file('/tmp/post_block.txt');
      expect(await postFile.exists(), isTrue);
      expect(await postFile.readAsString(), 'echo:echo_0');
    });
  });
}

void _registerTestBlocks(i3.ConfigProcessor processor) {
  processor.registerBlockHandler(SecretsBlock());
  processor.registerBlockHandler(CommandsBlockHandler());
  processor.registerBlockHandler(PackagesBlockHandler());
  processor.registerBlockHandler(ScriptsBlockHandler('pre_apply_scripts'));
  processor.registerBlockHandler(ScriptsBlockHandler('post_apply_scripts'));
  processor.registerBlockHandler(TemplateBlockHandler());
  processor.registerBlockHandler(TemplateVarsBlockHandler());
  processor.registerBlockHandler(SubCommandsBlockHandler());
  processor.registerBlockHandler(CommandEntryBlockHandler());
  processor.registerBlockHandler(PackageEntryBlockHandler());
  processor.registerBlockHandler(EchoBlock());
}

class _FakeRemoteExecutionService implements ExecutionService {
  final putDestinations = <String>[];
  final commands = <String>[];
  Map<String, String>? environment;

  @override
  String get platform => 'linux';

  @override
  bool get isConnected => true;

  @override
  Future<void> connect(Map<String, dynamic> config) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> fetchFile(String sourcePath, String destinationPath) async {}

  @override
  Future<void> putFile(String sourcePath, String destinationPath) async {
    putDestinations.add(destinationPath);
  }

  @override
  Future<ProcessResult> run(
    String command,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
    Map<String, String>? environment,
    CommandOutputHandler? onOutput,
    String? stdin,
  }) async {
    this.environment = environment ?? this.environment;
    commands.add([command, ...arguments].join(' '));
    return ProcessResult(0, 0, '', '');
  }
}
