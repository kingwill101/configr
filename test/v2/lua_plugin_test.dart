import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/plugins/configr_plugin.dart';
import 'package:configr/src/plugins/lua_plugin.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:file/memory.dart';
import 'package:i3config/i3config_v2.dart' as i3;
import 'package:lualike/lualike.dart';
import 'package:test/test.dart';

void main() {
  group('LuaPlugin System (v2)', () {
    late MemoryFileSystem fileSystem;
    late EventBus eventBus;
    late List<ModuleEvent> emittedEvents;

    setUp(() {
      fileSystem = MemoryFileSystem();
      eventBus = EventBus();
      emittedEvents = [];
      eventBus.stream.listen(emittedEvents.add);
    });

    test('metadata extraction from Lua globals', () async {
      final script = '''
        name = "lua_test_plugin"
        description = "A plugin written in Lua for testing"
        version = "2.3.4"
      ''';

      final plugin = LuaPlugin(code: script, fileSystem: fileSystem);
      await plugin.initialize();

      expect(plugin.name, equals('lua_test_plugin'));
      expect(plugin.description, equals('A plugin written in Lua for testing'));
      expect(plugin.version, equals('2.3.4'));
    });

    test('block registration and execute lifecycle callback', () async {
      final script = '''
        registerBlock("lua_block", {
          execute = function(block)
            local prefix = getVariable("prefix") or "VAL:"
            local val = expandVariables("\$some_var")
            logInfo("Logging prefix " .. prefix .. " and val " .. val)
            emitStatusUpdate(block.id, "info", prefix .. val)
            writeFile("/output.txt", "DONE")
          end,
          rollback = function(block)
            writeFile("/output.txt", "ROLLBACK")
          end
        })
      ''';

      final loader = ConfigrPluginLoader();
      final plugin = LuaPlugin(code: script, fileSystem: fileSystem);
      loader.registerPlugin(plugin);

      final processor = i3.ConfigProcessor();
      final actionBlocks = <ActionBlock>[];
      processor.context.options['_actionBlocks'] = actionBlocks;

      await loader.registerAllPlugins(processor, eventBus: eventBus);

      final config = i3.Config.parse('''
        set \$some_var "hello"
        lua_block {
          prefix = "LUA_"
        }
      ''');

      await processor.process(config);

      // Verify block execution occurred
      expect(actionBlocks, hasLength(1));
      expect(actionBlocks.first.blockType, equals('lua_block'));
      
      // Verify file write occurred via exposed writeFile
      final outputFile = fileSystem.file('/output.txt');
      expect(await outputFile.exists(), isTrue);
      expect(await outputFile.readAsString(), equals('DONE'));

      // Verify event emission occurred via exposed emitStatusUpdate
      final statusEvents = emittedEvents.whereType<StatusUpdateEvent>().toList();
      expect(statusEvents, isNotEmpty);
      expect(statusEvents.first.message, equals('LUA_hello'));

      // Verify rollback execution
      await actionBlocks.first.rollback();
      expect(await outputFile.readAsString(), equals('ROLLBACK'));
    });

    test('scoped command handlers within registered block', () async {
      final script = '''
        registerBlock("lua_cmd_block", {
          commands = {
            my_cmd = function(arg1, arg2)
              setVariable("cmd_result", arg1 .. "_" .. arg2)
            end
          },
          execute = function(block)
          end
        })
      ''';

      final loader = ConfigrPluginLoader();
      final plugin = LuaPlugin(code: script, fileSystem: fileSystem);
      loader.registerPlugin(plugin);

      final processor = i3.ConfigProcessor();
      final actionBlocks = <ActionBlock>[];
      processor.context.options['_actionBlocks'] = actionBlocks;

      await loader.registerAllPlugins(processor, eventBus: eventBus);

      final config = i3.Config.parse('''
        lua_cmd_block {
          my_cmd "first" "second"
        }
      ''');

      await processor.process(config);

      // Verify scoped command executed and mutated context variable
      final result = processor.context.getVariable("cmd_result");
      expect(result, equals('first_second'));
    });

    test('onConfigLoad and onConfigApplied configuration lifecycle hooks', () async {
      final script = '''
        load_called = false
        applied_called = false
        
        function onConfigLoad(config)
          load_called = true
        end
        
        function onConfigApplied(config)
          applied_called = true
        end
      ''';

      final plugin = LuaPlugin(code: script, fileSystem: fileSystem);
      await plugin.initialize();

      final config = i3.Config.parse('set \$var "value"');
      
      await plugin.onConfigLoad(config);
      await plugin.onConfigApplied(config);

      final loadVal = plugin.luaLike.getGlobal("load_called");
      final appliedVal = plugin.luaLike.getGlobal("applied_called");

      expect(loadVal is Value ? loadVal.raw : loadVal, isTrue);
      expect(appliedVal is Value ? appliedVal.raw : appliedVal, isTrue);
    });
  });
}
