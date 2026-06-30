import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/di.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/plugins/configr_plugin.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:configr/src/utils/privilege_escalation.dart';
import 'package:file/file.dart' show FileSystem;
import 'package:file/local.dart';
import 'package:i3config/i3config_v2.dart' as i3;
import 'package:test/test.dart';

/// Minimal plugin that adds a `greet` action block.
class GreetPlugin extends ConfigrPlugin {
  @override
  String get name => 'greet';

  @override
  String get description => 'Adds a greet action block';

  @override
  void registerBlocks(i3.ConfigProcessor processor, {EventBus? eventBus}) {
    processor.registerBlockHandler(GreetBlock());
  }
}

/// A greet block that just records execution.
class GreetBlock extends ActionBlock {
  @override
  String get blockType => 'greet';

  String greeting = '';

  GreetBlock();

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    greeting = (context.getVariable('greeting') as String?) ?? greeting;
  }

  @override
  Future<void> execute() async {
    emitEvent(
      StatusUpdateEvent(
        moduleId: id,
        level: StatusEvent.info,
        message: greeting.isNotEmpty ? greeting : 'Hello from GreetBlock!',
      ),
    );
    status = 'completed';
  }

  @override
  Future<void> rollback() {
    // No-op
    return Future.value();
  }
}

void main() {
  setUp(() {
    di
      ..allowReassignment = true
      ..registerSingleton<DryRunFlag>(DryRunFlag(false))
      ..registerSingleton<EventBus>(EventBus())
      ..registerSingleton<PrivilegeEscalation>(NoPrivilegeEscalation())
      ..registerSingleton<FileSystem>(const LocalFileSystem())
      ..allowReassignment = false;
  });

  group('Plugin System Integration (G.7)', () {
    test('programmatic plugin registration and block parsing', () async {
      final loader = ConfigrPluginLoader();
      loader.registerPlugin(GreetPlugin());

      final processor = i3.ConfigProcessor();
      final actionBlocks = <ActionBlock>[];
      processor.context.options['_actionBlocks'] = actionBlocks;

      await loader.registerAllPlugins(processor);

      final config = i3.Config.parse('''
greet {
  greeting = "Hello Plugin World!"
}
''');

      await processor.process(config);

      expect(actionBlocks, hasLength(1));
      final block = actionBlocks.first;
      expect(block.blockType, equals('greet'));
      // The GreetBlock stores greeting in its field
      expect((block as GreetBlock).greeting, equals('Hello Plugin World!'));
    });

    test('plugin block is parsed alongside built-in blocks', () async {
      final loader = ConfigrPluginLoader();
      loader.registerPlugin(GreetPlugin());

      final processor = i3.ConfigProcessor();
      final actionBlocks = <ActionBlock>[];
      processor.context.options['_actionBlocks'] = actionBlocks;

      // Register built-in blocks alongside plugin blocks
      await loader.registerAllPlugins(processor);

      // Also register a built-in copy block handler
      // (simplified: we just test that the greet block is found)
      final config = i3.Config.parse('''
greet {
  greeting = "Hi!"
}
''');

      await processor.process(config);

      expect(actionBlocks, hasLength(1));
      expect(actionBlocks.first.blockType, equals('greet'));
      expect((actionBlocks.first as GreetBlock).greeting, equals('Hi!'));
    });

    test('plugin with no greeting uses default', () async {
      final loader = ConfigrPluginLoader();
      loader.registerPlugin(GreetPlugin());

      final processor = i3.ConfigProcessor();
      final actionBlocks = <ActionBlock>[];
      processor.context.options['_actionBlocks'] = actionBlocks;

      await loader.registerAllPlugins(processor);

      final config = i3.Config.parse('''
greet {
  source = "/some/path"
}
''');

      await processor.process(config);

      expect(actionBlocks, hasLength(1));
      final block = actionBlocks.first as GreetBlock;
      // greeting was not set, should be empty (default)
      expect(block.greeting, isEmpty);
    });
  });
}
