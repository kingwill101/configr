import 'package:configr/src/utils/event_bus.dart';
import 'package:file/file.dart' show FileSystem;
import 'package:file/local.dart';
import 'package:i3config/i3config_v2.dart' as i3;
import 'package:lualike/lualike.dart' show LuaLike, Value;
import 'configr_plugin.dart';
import 'package:configr/src/blocks/action_block.dart';
import 'plugin_context.dart';
import 'lua_library.dart';

class LuaPlugin implements ConfigrPlugin, LuaPluginHost {
  final LuaLike _luaLike = LuaLike();
  LuaLike get luaLike => _luaLike;
  final String? code;
  final String? scriptPath;
  final FileSystem _fileSystem;
  final Map<String, Value> _registeredBlocks = {};

  i3.Context? _currentContext;
  EventBus? _eventBus;
  bool _initialized = false;

  LuaPlugin({this.code, this.scriptPath, FileSystem? fileSystem})
    : _fileSystem = fileSystem ?? const LocalFileSystem();

  // --- LuaPluginHost implementation ---

  @override
  i3.Context? get currentContext => _currentContext;

  @override
  EventBus? get eventBus => _eventBus;

  @override
  FileSystem get fileSystem => _fileSystem;

  @override
  void registerBlockInPlugin(String blockType, Value callbacks) {
    _registeredBlocks[blockType] = callbacks;
  }

  // --- Plugin metadata ---

  @override
  String get name {
    final val = _luaLike.getGlobal("name");
    if (val is Value) {
      return val.raw?.toString() ?? 'lua_plugin';
    }
    return val?.toString() ?? 'lua_plugin';
  }

  @override
  String get description {
    final val = _luaLike.getGlobal("description");
    if (val is Value) {
      return val.raw?.toString() ?? 'Lua-based Configr Plugin';
    }
    return val?.toString() ?? 'Lua-based Configr Plugin';
  }

  @override
  String get version {
    final val = _luaLike.getGlobal("version");
    if (val is Value) {
      return val.raw?.toString() ?? '0.1.0';
    }
    return val?.toString() ?? '0.1.0';
  }

  // --- Initialization ---

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Register the ConfigrLibrary (all built-in API functions with docs)
    _luaLike.vm.libraryRegistry.register(ConfigrLibrary(this));
    _luaLike.vm.libraryRegistry.initializeAll();

    // Expose this plugin instance as a global so callbacks can find the
    // active context (used by LuaActionBlock / LuaCommandHandler)
    _luaLike.setGlobal('_activePlugin', this);

    // Provide default contextual info for all plugins
    _luaLike.setGlobal('context', _buildContextMap());

    // Load and run the Lua script to populate globals and trigger
    // registrations
    if (code != null) {
      await _luaLike.execute(code!, scriptPath: scriptPath);
    } else if (scriptPath != null) {
      final file = _fileSystem.file(scriptPath!);
      if (await file.exists()) {
        final fileContent = await file.readAsString();
        await _luaLike.execute(fileContent, scriptPath: scriptPath);
      }
    }
  }

  @override
  void registerBlocks(i3.ConfigProcessor processor, {EventBus? eventBus}) {
    _eventBus = eventBus;

    _registeredBlocks.forEach((blockType, callbacks) {
      final block = LuaActionBlock(blockType, _luaLike, this, callbacks);
      processor.registerBlockHandler(block);
    });
  }

  Map<String, dynamic> _buildContextMap() {
    return PluginContext.create().toMap();
  }

  @override
  Future<void> onConfigLoad(i3.Config config) async {
    final onConfigLoadFunc = _luaLike.getGlobal("onConfigLoad");
    if (onConfigLoadFunc != null &&
        onConfigLoadFunc is Value &&
        onConfigLoadFunc.raw != null) {
      await _luaLike.vm.callFunction(onConfigLoadFunc, [
        Value(config.toJson()),
      ]);
    }
  }

  @override
  Future<void> onConfigApplied(i3.Config config) async {
    final onConfigAppliedFunc = _luaLike.getGlobal("onConfigApplied");
    if (onConfigAppliedFunc != null &&
        onConfigAppliedFunc is Value &&
        onConfigAppliedFunc.raw != null) {
      await _luaLike.vm.callFunction(onConfigAppliedFunc, [
        Value(config.toJson()),
      ]);
    }
  }
}

class LuaActionBlock extends ActionBlock {
  @override
  final String blockType;
  final LuaLike _luaLike;
  final LuaPlugin _plugin;
  final Value _luaCallbacks;
  i3.Context? _currentContext;

  LuaActionBlock(
    this.blockType,
    this._luaLike,
    this._plugin,
    this._luaCallbacks,
  );

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    _currentContext = context;
    final props = <String, dynamic>{};
    for (final key in context.variables.keys) {
      props[key] = context.variables[key];
    }
    properties = props;
  }

  @override
  void registerScopedCommands(i3.BlockHandlerRegistry registry) {
    final commandsVal = _luaCallbacks['commands'];
    if (commandsVal is Value && commandsVal.raw is Map) {
      final commandsMap = commandsVal.raw as Map;
      for (final entry in commandsMap.entries) {
        final commandName = entry.key.toString();
        final commandFunc = entry.value;
        registry.registerCommand(
          commandName,
          LuaCommandHandler(commandName, _luaLike, this, commandFunc),
        );
      }
    }
  }

  @override
  Future<void> execute() async {
    _plugin._currentContext = _currentContext;
    final executeFunc = _luaCallbacks['execute'];
    if (executeFunc is Value && executeFunc.raw != null) {
      final blockData = {
        'id': id,
        'source': source,
        'destination': destination,
        'properties': properties,
      };
      await _luaLike.vm.callFunction(executeFunc, [Value(blockData)]);
    }
  }

  @override
  Future<void> rollback() async {
    _plugin._currentContext = _currentContext;
    final rollbackFunc = _luaCallbacks['rollback'];
    if (rollbackFunc is Value && rollbackFunc.raw != null) {
      final blockData = {
        'id': id,
        'source': source,
        'destination': destination,
        'properties': properties,
      };
      await _luaLike.vm.callFunction(rollbackFunc, [Value(blockData)]);
    }
  }
}

class LuaCommandHandler extends i3.BaseCommandHandler {
  @override
  final String commandName;
  final LuaLike _luaLike;
  final LuaActionBlock _block;
  final dynamic _commandFunc;

  LuaCommandHandler(
    this.commandName,
    this._luaLike,
    this._block,
    this._commandFunc,
  );

  @override
  Future<void> handle(i3.Command command, i3.Context context) async {
    _block._plugin._currentContext = context;
    final args = getAllArgsAsStrings(command, context);
    await _luaLike.vm.callFunction(
      _commandFunc is Value ? _commandFunc : Value(_commandFunc),
      args,
    );
  }
}
