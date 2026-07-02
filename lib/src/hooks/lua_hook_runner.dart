import 'package:configr/src/plugins/lua_library.dart';
import 'package:configr/src/plugins/plugin_context.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:file_lualike/file_lualike.dart' show useFileSystem;
import 'package:i3config/i3config_v2.dart' as i3;
import 'package:lualike/lualike.dart';

class LuaHookRunner {
  final LuaLike _luaLike = LuaLike();
  final FileSystem _fileSystem;
  final FileSystem _scriptFileSystem;
  final ProcessBackend? _processBackend;
  final Map<String, dynamic> _globals;

  LuaHookRunner({
    required this._globals,
    FileSystem? fileSystem,
    FileSystem? scriptFileSystem,
    EventBus? eventBus,
    this._processBackend,
  }) : _fileSystem = fileSystem ?? const LocalFileSystem(),
       _scriptFileSystem =
           scriptFileSystem ?? fileSystem ?? const LocalFileSystem();

  Future<bool> run(String scriptPath) async {
    final file = _scriptFileSystem.file(scriptPath);
    if (!await file.exists()) return false;

    await useFileSystem(_fileSystem);
    setProcessBackend(_processBackend);
    _luaLike.vm.libraryRegistry.register(
      ConfigrLibrary(_LuaHookHost(_fileSystem, _processBackend)),
    );
    _luaLike.vm.libraryRegistry.initializeAll();

    for (final entry in _globals.entries) {
      _luaLike.setGlobal(entry.key, entry.value);
    }

    try {
      final content = await file.readAsString();
      await _luaLike.execute(content, scriptPath: scriptPath);
      return true;
    } catch (e) {
      return false;
    }
  }
}

class _LuaHookHost implements LuaPluginHost {
  Map<String, dynamic>? _pluginContext;

  @override
  final FileSystem fileSystem;

  @override
  final ProcessBackend? processBackend;

  _LuaHookHost(this.fileSystem, this.processBackend);

  @override
  Map<String, dynamic> get pluginContext =>
      _pluginContext ??= PluginContext.create().toMap();

  @override
  i3.Context? get currentContext => null;

  @override
  EventBus? get eventBus => null;

  @override
  void registerBlockInPlugin(String blockType, Value callbacks) {
    // Hooks don't register blocks — silently ignored.
  }
}
