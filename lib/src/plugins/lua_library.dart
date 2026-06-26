import 'dart:io';

import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:file/file.dart' show FileSystem;
import 'package:lualike/library_builder.dart';
import 'package:i3config/i3config_v2.dart' as i3;

import 'plugin_context.dart';

/// Host interface that [ConfigrLibrary] uses to access plugin-specific state.
abstract class LuaPluginHost {
  i3.Context? get currentContext;
  EventBus? get eventBus;
  FileSystem get fileSystem;

  void registerBlockInPlugin(String blockType, Value callbacks);
}

String _stringArg(List<Object?> args, int index) {
  if (index >= args.length) return '';
  final val = Value.wrap(args[index]).unwrap();
  if (val == null) return '';
  return val.toString();
}

/// Library of built-in Configr API functions exposed to Lua plugins.
///
/// All functions are registered in the global namespace (empty `name`) so they
/// are accessible directly in Lua scripts without a prefix.
class ConfigrLibrary extends Library {
  @override
  String get name => '';

  @override
  String get description =>
      'Built-in Configr plugin API functions (getEnv, '
      'getVariable, logInfo, fileExists, etc.)';

  final LuaPluginHost _host;

  ConfigrLibrary(this._host);

  @override
  void registerFunctions(LibraryRegistrationContext context) {
    final builder = BuiltinFunctionBuilder(context);

    context.define(
      'getEnv',
      builder.create((args) {
        return Platform.environment[_stringArg(args, 0)];
      }),
    );
    context.describe(
      'getEnv',
      FunctionDoc(
        summary: 'Gets the value of an environment variable.',
        params: [
          DocParam('name', 'string', 'The name of the environment variable.'),
        ],
        returns: 'string|nil',
        returnType: 'string?',
        category: 'system',
        example: 'local home = getEnv("HOME")',
      ),
    );

    context.define(
      'getVariable',
      builder.create((args) {
        if (_host.currentContext == null) return null;
        return _host.currentContext!.getVariable(_stringArg(args, 0));
      }),
    );
    context.describe(
      'getVariable',
      FunctionDoc(
        summary: 'Gets a variable from the current configuration context.',
        params: [DocParam('name', 'string', 'The variable name to look up.')],
        returns: 'any',
        returnType: 'any',
        category: 'context',
        example: 'local msg = getVariable("message")',
      ),
    );

    context.define(
      'setVariable',
      builder.create((args) {
        if (_host.currentContext == null || args.length < 2) return null;
        final name = _stringArg(args, 0);
        final value = Value.wrap(args[1]).unwrap();
        _host.currentContext!.globalContext.setVariable(name, value);
        return null;
      }),
    );
    context.describe(
      'setVariable',
      FunctionDoc(
        summary: 'Sets a variable in the global configuration context.',
        params: [
          DocParam('name', 'string', 'The variable name.'),
          DocParam('value', 'any', 'The value to assign.'),
        ],
        returns: 'nil',
        category: 'context',
        example: 'setVariable("notify_message", "hello")',
      ),
    );

    context.define(
      'expandVariables',
      builder.create((args) {
        if (_host.currentContext == null) return '';
        return _host.currentContext!.expandVariables(_stringArg(args, 0));
      }),
    );
    context.describe(
      'expandVariables',
      FunctionDoc(
        summary: r'Expands Configr variable references ($var) in a string.',
        params: [
          DocParam('str', 'string', r'String containing $variable references.'),
        ],
        returns: 'string',
        category: 'context',
        example: r'local val = expandVariables("prefix_$some_var")',
      ),
    );

    context.define(
      'logInfo',
      builder.create((args) {
        logger.info(_stringArg(args, 0));
        return null;
      }),
    );
    context.describe(
      'logInfo',
      FunctionDoc(
        summary: 'Logs an info-level message to the Configr logger.',
        params: [DocParam('message', 'string', 'The message to log.')],
        returns: 'nil',
        category: 'logging',
        example: 'logInfo("Block executed successfully")',
      ),
    );

    context.define(
      'logWarning',
      builder.create((args) {
        logger.warning(_stringArg(args, 0));
        return null;
      }),
    );
    context.describe(
      'logWarning',
      FunctionDoc(
        summary: 'Logs a warning-level message to the Configr logger.',
        params: [DocParam('message', 'string', 'The message to log.')],
        returns: 'nil',
        category: 'logging',
        example: 'logWarning("Deprecated option used")',
      ),
    );

    context.define(
      'logError',
      builder.create((args) {
        logger.error(_stringArg(args, 0));
        return null;
      }),
    );
    context.describe(
      'logError',
      FunctionDoc(
        summary: 'Logs an error-level message to the Configr logger.',
        params: [DocParam('message', 'string', 'The message to log.')],
        returns: 'nil',
        category: 'logging',
        example: 'logError("Failed to apply block")',
      ),
    );

    context.define(
      'logDebug',
      builder.create((args) {
        logger.debug(_stringArg(args, 0));
        return null;
      }),
    );
    context.describe(
      'logDebug',
      FunctionDoc(
        summary: 'Logs a debug-level message to the Configr logger.',
        params: [DocParam('message', 'string', 'The message to log.')],
        returns: 'nil',
        category: 'logging',
        example: 'logDebug("Variable value: " .. val)',
      ),
    );

    context.define(
      'fileExists',
      builder.create((args) {
        return _host.fileSystem.file(_stringArg(args, 0)).existsSync();
      }),
    );
    context.describe(
      'fileExists',
      FunctionDoc(
        summary: 'Checks whether a file exists at the given path.',
        params: [DocParam('path', 'string', 'Path to check.')],
        returns: 'boolean',
        category: 'filesystem',
        example: 'if fileExists("/tmp/flag") then ... end',
      ),
    );

    context.define(
      'readFile',
      builder.create((args) {
        return _host.fileSystem.file(_stringArg(args, 0)).readAsStringSync();
      }),
    );
    context.describe(
      'readFile',
      FunctionDoc(
        summary: 'Reads the entire contents of a file as a string.',
        params: [DocParam('path', 'string', 'Path to the file.')],
        returns: 'string',
        category: 'filesystem',
        example: 'local data = readFile("/etc/config.cfg")',
      ),
    );

    context.define(
      'writeFile',
      builder.create((args) {
        if (args.length < 2) return null;
        _host.fileSystem
            .file(_stringArg(args, 0))
            .writeAsStringSync(_stringArg(args, 1));
        return null;
      }),
    );
    context.describe(
      'writeFile',
      FunctionDoc(
        summary: 'Writes string content to a file, replacing existing content.',
        params: [
          DocParam('path', 'string', 'Destination file path.'),
          DocParam('content', 'string', 'Content to write.'),
        ],
        returns: 'nil',
        category: 'filesystem',
        example: 'writeFile("/tmp/out.txt", "hello")',
      ),
    );

    context.define(
      'appendFile',
      builder.create((args) {
        if (args.length < 2) return null;
        _host.fileSystem
            .file(_stringArg(args, 0))
            .writeAsStringSync(_stringArg(args, 1), mode: FileMode.append);
        return null;
      }),
    );
    context.describe(
      'appendFile',
      FunctionDoc(
        summary: 'Appends string content to the end of a file.',
        params: [
          DocParam('path', 'string', 'Destination file path.'),
          DocParam('content', 'string', 'Content to append.'),
        ],
        returns: 'nil',
        category: 'filesystem',
        example: 'appendFile("/tmp/log.csv", "entry,data\\n")',
      ),
    );

    context.define(
      'configrCacheDir',
      builder.create((args) {
        if (_host.currentContext == null) return '';
        return (_host.currentContext!.globalContext.options['_configrCacheDir']
                as String?) ??
            '';
      }),
    );
    context.describe(
      'configrCacheDir',
      FunctionDoc(
        summary: 'Returns the Configr cache directory path.',
        returns: 'string',
        category: 'configr',
        example: 'local dir = configrCacheDir()',
      ),
    );

    context.define(
      'configrBackupDir',
      builder.create((args) {
        if (_host.currentContext == null) return '';
        return (_host.currentContext!.globalContext.options['_configrBackupDir']
                as String?) ??
            '';
      }),
    );
    context.describe(
      'configrBackupDir',
      FunctionDoc(
        summary: 'Returns the Configr backup directory path.',
        returns: 'string',
        category: 'configr',
        example: 'local dir = configrBackupDir()',
      ),
    );

    context.define(
      'emitStatusUpdate',
      builder.create((args) {
        if (args.length < 3) return null;
        final statusLevel = switch (_stringArg(args, 1).toLowerCase()) {
          'warning' => StatusEvent.warning,
          'error' => StatusEvent.error,
          'debug' => StatusEvent.debug,
          _ => StatusEvent.info,
        };
        _host.eventBus?.emit(
          StatusUpdateEvent(
            moduleId: _stringArg(args, 0),
            level: statusLevel,
            message: _stringArg(args, 2),
          ),
        );
        return null;
      }),
    );
    context.describe(
      'emitStatusUpdate',
      FunctionDoc(
        summary: 'Emits a status update event to the Configr event bus.',
        params: [
          DocParam('moduleId', 'string', 'The module or block identifier.'),
          DocParam(
            'level',
            'string',
            'Severity level: "info", "warning", "error", or "debug".',
          ),
          DocParam('message', 'string', 'The status message.'),
        ],
        returns: 'nil',
        category: 'events',
        example:
            'emitStatusUpdate(block.id, "info", "Applying block " .. block.id)',
      ),
    );

    context.define(
      'registerBlock',
      builder.create((args) {
        if (args.length < 2) return null;
        _host.registerBlockInPlugin(_stringArg(args, 0), Value.wrap(args[1]));
        return null;
      }),
    );
    context.describe(
      'registerBlock',
      FunctionDoc(
        summary: 'Registers a Lua-defined action block type with callbacks.',
        params: [
          DocParam(
            'blockType',
            'string',
            'The block type name (e.g. "notify").',
          ),
          DocParam(
            'callbacks',
            'registerBlock.callbacks',
            'Callback table. See "registerBlock.callbacks" table schema for field types.',
          ),
        ],
        returns: 'nil',
        category: 'plugin',
        example: '''registerBlock("notify", {
  execute = function(block)
    logInfo("Running block: " .. block.id)
  end,
  rollback = function(block)
    logInfo("Rolling back: " .. block.id)
  end
})''',
      ),
    );

    context.define(
      'getContext',
      builder.create((args) {
        final key = _stringArg(args, 0);
        return PluginContext.create().toMap()[key];
      }),
    );
    context.describe(
      'getContext',
      FunctionDoc(
        summary:
            'Returns a value from the default plugin context table by key.',
        params: [
          DocParam(
            'key',
            'string',
            'Context key ("platform", "architecture", "hostname", "os", "user", "env", "configr").',
          ),
        ],
        returns: 'any',
        returnType: 'any',
        category: 'context',
        example: 'local platform = getContext("platform")',
      ),
    );

    // ── Table schema documentation ──────────────────────────────────────

    context.describeTable(
      'context',
      TableDoc(
        name: 'context',
        description: 'Default plugin context table with system information.',
        fields: [
          FieldDoc(
            key: 'platform',
            type: 'string',
            description: 'Operating system (linux, macos, windows, etc.).',
          ),
          FieldDoc(
            key: 'architecture',
            type: 'string',
            description: 'CPU architecture (x86_64, aarch64, etc.).',
          ),
          FieldDoc(
            key: 'hostname',
            type: 'string',
            description: 'System hostname.',
          ),
          FieldDoc(
            key: 'os',
            type: 'table',
            description: 'Operating system details.',
            fields: [
              FieldDoc(key: 'name', type: 'string', description: 'OS name.'),
              FieldDoc(
                key: 'version',
                type: 'string',
                description: 'OS version string.',
              ),
            ],
          ),
          FieldDoc(
            key: 'user',
            type: 'table',
            description: 'Current user information.',
            fields: [
              FieldDoc(
                key: 'username',
                type: 'string',
                description: 'Username.',
              ),
              FieldDoc(
                key: 'home',
                type: 'string',
                description: 'Home directory.',
              ),
              FieldDoc(
                key: 'shell',
                type: 'string',
                description: 'Default shell.',
              ),
            ],
          ),
          FieldDoc(
            key: 'env',
            type: 'table',
            description: 'Common environment variables.',
          ),
          FieldDoc(
            key: 'configr',
            type: 'table',
            description: 'Configr runtime configuration.',
            fields: [
              FieldDoc(
                key: 'version',
                type: 'string',
                description: 'Configr version.',
              ),
              FieldDoc(
                key: 'cacheDir',
                type: 'string',
                description: 'Cache directory.',
              ),
              FieldDoc(
                key: 'backupDir',
                type: 'string',
                description: 'Backup directory.',
              ),
            ],
          ),
        ],
      ),
    );

    context.describeTable(
      'block',
      TableDoc(
        name: 'block',
        description:
            'Block data table passed to execute() and rollback() callbacks.',
        fields: [
          FieldDoc(
            key: 'id',
            type: 'string',
            description: 'Unique block instance identifier.',
            required: true,
          ),
          FieldDoc(
            key: 'source',
            type: 'string',
            description: 'Source path (may be empty).',
          ),
          FieldDoc(
            key: 'destination',
            type: 'string',
            description: 'Destination path (may be empty).',
          ),
          FieldDoc(
            key: 'properties',
            type: 'table',
            description:
                'Block-specific configuration property key-value pairs.',
          ),
        ],
      ),
    );

    // ── Callback parameter type documentation ──────────────────────────

    context.describeTable(
      'registerBlock.callbacks',
      TableDoc(
        name: 'registerBlock.callbacks',
        description: 'Callback table passed to registerBlock().',
        fields: [
          FieldDoc(
            key: 'execute',
            type: 'fun(block: block): nil',
            description:
                'Required. Called when the block is executed. Receives a block table.',
            required: true,
          ),
          FieldDoc(
            key: 'rollback',
            type: 'fun(block: block): nil',
            description:
                'Optional. Called when the block is rolled back. Receives a block table.',
          ),
          FieldDoc(
            key: 'commands',
            type: '{ [string]: fun(...) }',
            description:
                'Optional. Table of scoped command name → handler mappings.',
          ),
        ],
      ),
    );
  }
}
