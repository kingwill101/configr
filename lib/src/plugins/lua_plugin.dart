import 'dart:io';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:file/file.dart' show FileSystem;
import 'package:file/local.dart';
import 'package:i3config/i3config_v2.dart' as i3;
import 'package:lualike/lualike.dart';
import 'configr_plugin.dart';
import 'package:configr/src/blocks/action_block.dart';
import 'plugin_context.dart';

class LuaPlugin implements ConfigrPlugin {
  final LuaLike _luaLike = LuaLike();
  LuaLike get luaLike => _luaLike;
  final String? code;
  final String? scriptPath;
  final FileSystem _fileSystem;
  final Map<String, Value> _registeredBlocks = {};

  i3.Context? _currentContext;
  i3.ConfigProcessor? _processor;
  EventBus? _eventBus;
  bool _initialized = false;

  LuaPlugin({this.code, this.scriptPath, FileSystem? fileSystem})
      : _fileSystem = fileSystem ?? const LocalFileSystem();

  static String _stringArg(List<Object?> args, int index) {
    if (index >= args.length) return '';
    final val = Value.wrap(args[index]).unwrap();
    if (val == null) return '';
    return val.toString();
  }

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

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Expose this plugin instance as a global so callbacks can find the active context
    _luaLike.setGlobal('_activePlugin', this);

    // Expose environment variables
    _luaLike.expose('getEnv', (List<Object?> args) {
      return Platform.environment[_stringArg(args, 0)];
    });

    // Expose context variables/options
    _luaLike.expose('getVariable', (List<Object?> args) {
      if (_currentContext == null) return null;
      return _currentContext!.getVariable(_stringArg(args, 0));
    });

    _luaLike.expose('setVariable', (List<Object?> args) {
      if (_currentContext == null || args.length < 2) return;
      final name = _stringArg(args, 0);
      final value = Value.wrap(args[1]).unwrap();
      _currentContext!.globalContext.setVariable(name, value);
    });

    _luaLike.expose('expandVariables', (List<Object?> args) {
      if (_currentContext == null) return '';
      return _currentContext!.expandVariables(_stringArg(args, 0));
    });

    // Expose logging functions
    _luaLike.expose('logInfo', (List<Object?> args) => logger.info(_stringArg(args, 0)));
    _luaLike.expose('logWarning', (List<Object?> args) => logger.warning(_stringArg(args, 0)));
    _luaLike.expose('logError', (List<Object?> args) => logger.severe(_stringArg(args, 0)));
    _luaLike.expose('logDebug', (List<Object?> args) => logger.fine(_stringArg(args, 0)));

    // Expose filesystem helper functions
    _luaLike.expose('fileExists', (List<Object?> args) => _fileSystem.file(_stringArg(args, 0)).existsSync());
    _luaLike.expose('readFile', (List<Object?> args) => _fileSystem.file(_stringArg(args, 0)).readAsStringSync());
    _luaLike.expose('writeFile', (List<Object?> args) {
      if (args.length < 2) return;
      _fileSystem.file(_stringArg(args, 0)).writeAsStringSync(_stringArg(args, 1));
    });
    _luaLike.expose('appendFile', (List<Object?> args) {
      if (args.length < 2) return;
      _fileSystem.file(_stringArg(args, 0)).writeAsStringSync(
        _stringArg(args, 1),
        mode: FileMode.append,
      );
    });

    // Expose configr directory helpers (read from processor context options)
    _luaLike.expose('configrCacheDir', (List<Object?> args) {
      if (_currentContext == null) return '';
      return (_currentContext!.globalContext.options['_configrCacheDir'] as String?) ?? '';
    });

    _luaLike.expose('configrBackupDir', (List<Object?> args) {
      if (_currentContext == null) return '';
      return (_currentContext!.globalContext.options['_configrBackupDir'] as String?) ?? '';
    });

    // Expose event bus emitter
    _luaLike.expose('emitStatusUpdate', (List<Object?> args) {
      if (args.length < 3) return;
      final statusLevel = switch (_stringArg(args, 1).toLowerCase()) {
        'warning' => StatusEvent.warning,
        'error' => StatusEvent.error,
        'debug' => StatusEvent.debug,
        _ => StatusEvent.info,
      };
      _eventBus?.emit(
        StatusUpdateEvent(
          moduleId: _stringArg(args, 0),
          level: statusLevel,
          message: _stringArg(args, 2),
        ),
      );
    });

    // Expose block registration callback
    _luaLike.expose('registerBlock', (List<Object?> args) {
      if (args.length < 2) return;
      _registeredBlocks[_stringArg(args, 0)] = Value.wrap(args[1]);
    });

    // Provide default contextual info for all plugins
    _luaLike.expose('getContext', (List<Object?> args) {
      final key = _stringArg(args, 0);
      return _buildContextMap()[key];
    });

    _luaLike.setGlobal('context', _buildContextMap());

    // Load and run the Lua script to populate globals and trigger registrations
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
    _processor = processor;
    _eventBus = eventBus;

    _registeredBlocks.forEach((blockType, callbacks) {
      final block = LuaActionBlock(
        blockType,
        _luaLike,
        this,
        callbacks,
      );
      processor.registerBlockHandler(block);
    });
  }

  Map<String, dynamic> _buildContextMap() {
    return PluginContext.create().toMap();
  }

  @override
  Future<void> onConfigLoad(i3.Config config) async {
    final onConfigLoadFunc = _luaLike.getGlobal("onConfigLoad");
    if (onConfigLoadFunc != null && onConfigLoadFunc is Value && onConfigLoadFunc.raw != null) {
      await _luaLike.vm.callFunction(onConfigLoadFunc, [Value(config.toJson())]);
    }
  }

  @override
  Future<void> onConfigApplied(i3.Config config) async {
    final onConfigAppliedFunc = _luaLike.getGlobal("onConfigApplied");
    if (onConfigAppliedFunc != null && onConfigAppliedFunc is Value && onConfigAppliedFunc.raw != null) {
      await _luaLike.vm.callFunction(onConfigAppliedFunc, [Value(config.toJson())]);
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
  Future<void> readAdditionalProperties(i3.Block block, i3.Context context) async {
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

  LuaCommandHandler(this.commandName, this._luaLike, this._block, this._commandFunc);

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
