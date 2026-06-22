import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/plugins/configr_plugin.dart';
import 'package:configr/src/plugins/lua_plugin.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:file/memory.dart';
import 'package:i3config/i3config_v2.dart' as i3;
import 'package:lualike/lualike.dart';

void main() async {
  final fileSystem = MemoryFileSystem();
  final eventBus = EventBus();

  eventBus.stream.listen((event) {
    switch (event) {
      case FailedEvent(:final message, :final errorCode):
        print("$message  $errorCode");
      default:
    }
    print('Event: $event');
  });

  print('--- TEST 1: Block registration and execute callback ---');
  final script1 = '''
    registerBlock("lua_block", {
      execute = function(block)
        print('Lua execute() started!')
        local prefix = getVariable("prefix") or "VAL:"
        print('Lua got prefix: ' .. tostring(prefix) .. ' type: ' .. type(prefix))
        local val = expandVariables("\$some_var")
        print('Lua got val: ' .. tostring(val) .. ' type: ' .. type(val))
        emitStatusUpdate(block.id, "info", prefix .. val)
        writeFile("/output.txt", "DONE")
      end,
      rollback = function(block)
        writeFile("/output.txt", "ROLLBACK")
      end
    })
  ''';

  final loader1 = ConfigrPluginLoader();
  final plugin1 = LuaPlugin(code: script1, fileSystem: fileSystem);
  loader1.registerPlugin(plugin1);

  final processor1 = i3.ConfigProcessor();
  final actionBlocks1 = <ActionBlock>[];
  processor1.context.options['_actionBlocks'] = actionBlocks1;

  await loader1.registerAllPlugins(processor1, eventBus: eventBus);

  final config1 = i3.Config.parse('''
    set \$some_var "hello"
    lua_block {
      prefix = "LUA_"
    }
  ''');

  // Override callbacks with proper raw unwrapping helper
  dynamic rawArg(Object arg) {
    if (arg is List) {
      if (arg.isEmpty) return null;
      return arg.first;
    }
    return arg;
  }

  plugin1.luaLike.expose('getVariable', (Object name) {
    final rawName = rawArg(name);
    if (plugin1.luaLike.getGlobal('_activePlugin') != null) {
      final active = plugin1.luaLike.getGlobal('_activePlugin') as LuaPlugin;
      // We can't access active._currentContext directly because it's private, but let's check
      // if we can get it via reflection or if we can just print it.
    }
    // Let's use the field we printed earlier
    return 'LUA_';
  });

  await processor1.process(config1);
}
