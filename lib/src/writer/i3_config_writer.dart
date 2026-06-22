import 'package:configr/src/models/action.dart';
import 'package:configr/src/models/command.dart';
import 'package:configr/src/models/config.dart';
import 'package:configr/src/models/file_model.dart';
import 'package:configr/src/models/package.dart';
import 'package:configr/src/models/template.dart';
import 'package:i3config/i3config_v2.dart' as i3;

/// Converts Configr domain models to i3-config-format text using AST-backed
/// serialization.
///
/// Domain models are first translated into an [i3.Config] AST, then serialized
/// to formatted text. This ensures ordering, quoting, and indentation are
/// handled in one place.
///
/// ## Output format
///
/// Property-style settings (source, destination, name, manager, etc.) are
/// emitted as `Assignment` nodes (`variable = "value"`), which the i3config v2
/// pipeline processes via [i3.AssignmentProcessingState] to set context
/// variables directly. Section blocks use [i3.Block] nodes, and command
/// entries use [i3.Command] nodes with attached sub-blocks.
///
/// Values that contain spaces or special characters are quoted; simple
/// alphanumeric values are emitted bare.
class I3ConfigWriter {
  /// Indent size in spaces.
  static const _indentSize = 2;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Serialize a [Config] to i3-format text.
  String write(Config config) {
    final ast = _buildConfig(config);
    return _serializeConfig(ast);
  }

  // ---------------------------------------------------------------------------
  // AST building — domain model → i3 Config
  // ---------------------------------------------------------------------------

  i3.Config _buildConfig(Config config) {
    final statements = <i3.ConfigElement>[];

    if (config.resources.isNotEmpty) {
      statements.add(_buildResourcesBlock(config.resources));
    }
    if (config.commands.isNotEmpty) {
      statements.add(_buildCommandsBlock(config.commands));
    }
    if (config.packages.isNotEmpty) {
      statements.add(_buildPackagesBlock(config.packages));
    }
    if (config.preApplyScripts.isNotEmpty) {
      statements.add(
        _buildScriptsBlock('pre_apply_scripts', config.preApplyScripts),
      );
    }
    if (config.postApplyScripts.isNotEmpty) {
      statements.add(
        _buildScriptsBlock('post_apply_scripts', config.postApplyScripts),
      );
    }

    return i3.Config(statements);
  }

  i3.Block _buildResourcesBlock(List<ResourceModel> resources) {
    final body = <i3.ConfigElement>[];
    for (final resource in resources) {
      body.add(_buildResourceBlock(resource));
    }
    return i3.Block('resources', null, body);
  }

  i3.Block _buildResourceBlock(ResourceModel resource) {
    final body = <i3.ConfigElement>[];

    _addAssignment(body, 'id', resource.id);
    _addAssignment(body, 'source', resource.source);
    _addAssignment(body, 'destination', resource.destination);
    if (resource.type != null && resource.type != ResourceType.file) {
      _addAssignment(body, 'type', resource.type!);
    }
    if (resource.status != null) {
      _addAssignment(body, 'status', resource.status!);
    }
    if (resource.sha256 != null && resource.sha256!.isNotEmpty) {
      _addAssignment(body, 'sha256', resource.sha256!);
    }

    if (resource.template != null) {
      body.add(_buildTemplateBlock(resource.template!));
    }

    if (resource.actions.isNotEmpty) {
      body.add(_buildActionsBlock(resource.actions));
    }

    if (resource.commands.isNotEmpty) {
      body.add(_buildSubCommandsBlock(resource.commands));
    }

    return i3.Block('resource', null, body);
  }

  i3.Block _buildActionsBlock(List<Action> actions) {
    final body = <i3.ConfigElement>[];
    for (final action in actions) {
      body.add(_buildActionBlock(action));
    }
    return i3.Block('actions', null, body);
  }

  i3.Block _buildActionBlock(Action action) {
    final body = <i3.ConfigElement>[];

    if (action.id.isNotEmpty) _addAssignment(body, 'id', action.id);
    if (action.status != null) _addAssignment(body, 'status', action.status!);
    if (action.timestamp != null) {
      _addAssignment(body, 'timestamp', action.timestamp!);
    }
    if (action.sha256 != null) _addAssignment(body, 'sha256', action.sha256!);

    // Non-reserved extra properties
    const reserved = {'id', 'status', 'timestamp', 'sha256'};
    for (final entry in action.properties.entries) {
      if (!reserved.contains(entry.key)) {
        _addAssignment(body, entry.key, '${entry.value}');
      }
    }

    if (action.backupPath != null) {
      _addAssignment(body, 'backupPath', action.backupPath!);
    }

    // Nested actions
    if (action.actions.isNotEmpty) {
      for (final nested in action.actions) {
        body.add(_buildActionBlock(nested));
      }
    }

    return i3.Block(action.type, null, body);
  }

  i3.Block _buildTemplateBlock(Template template) {
    final body = <i3.ConfigElement>[];
    if (template.template != null) {
      _addAssignment(body, 'template', template.template!);
    }
    if (template.vars != null && template.vars!.isNotEmpty) {
      final varsBody = <i3.ConfigElement>[];
      for (final entry in template.vars!.entries) {
        _addAssignment(varsBody, entry.key, '${entry.value}');
      }
      body.add(i3.Block('vars', null, varsBody));
    }
    return i3.Block('template', null, body);
  }

  i3.Block _buildCommandsBlock(List<Command> commands) {
    final body = <i3.ConfigElement>[];
    for (final cmd in commands) {
      body.add(_buildCommandEntry(cmd));
    }
    return i3.Block('commands', null, body);
  }

  /// Builds a `command <name> { ... }` entry.
  i3.Command _buildCommandEntry(Command cmd) {
    final body = <i3.ConfigElement>[];
    if (cmd.id != null) _addAssignment(body, 'id', cmd.id!);
    if (cmd.command != null) _addAssignment(body, 'command', cmd.command!);
    if (cmd.parameters.isNotEmpty) {
      _addAssignment(body, 'parameters', cmd.parameters.join(' '));
    }
    if (cmd.status != null) _addAssignment(body, 'status', cmd.status!);
    if (cmd.timestamp != null) {
      _addAssignment(body, 'timestamp', cmd.timestamp!);
    }
    if (cmd.sha256 != null) _addAssignment(body, 'sha256', cmd.sha256!);

    final block = i3.Block('command', null, body);
    return i3.Command('command', [_buildValue(cmd.name)], null, block);
  }

  i3.Block _buildSubCommandsBlock(List<Command> commands) {
    final body = <i3.ConfigElement>[];
    for (final cmd in commands) {
      body.add(_buildSubCommandEntry(cmd));
    }
    return i3.Block('subcommands', null, body);
  }

  /// Builds a `<name> { ... }` entry for subcommands.
  i3.Command _buildSubCommandEntry(Command cmd) {
    final body = <i3.ConfigElement>[];
    if (cmd.id != null) _addAssignment(body, 'id', cmd.id!);
    if (cmd.command != null) _addAssignment(body, 'command', cmd.command!);
    if (cmd.parameters.isNotEmpty) {
      _addAssignment(body, 'parameters', cmd.parameters.join(' '));
    }
    if (cmd.status != null) _addAssignment(body, 'status', cmd.status!);
    if (cmd.timestamp != null) {
      _addAssignment(body, 'timestamp', cmd.timestamp!);
    }
    if (cmd.sha256 != null) _addAssignment(body, 'sha256', cmd.sha256!);

    final block = i3.Block(cmd.name, null, body);
    return i3.Command(cmd.name, [], null, block);
  }

  i3.Block _buildPackagesBlock(List<Package> packages) {
    final body = <i3.ConfigElement>[];
    for (final pkg in packages) {
      body.add(_buildPackageBlock(pkg));
    }
    return i3.Block('packages', null, body);
  }

  i3.Block _buildPackageBlock(Package pkg) {
    final body = <i3.ConfigElement>[];

    if (pkg.id.isNotEmpty) _addAssignment(body, 'id', pkg.id);
    _addAssignment(body, 'name', pkg.name);
    _addAssignment(body, 'manager', pkg.manager);
    if (pkg.version != null) _addAssignment(body, 'version', pkg.version!);
    _addAssignment(body, 'scope', pkg.scope);
    if (pkg.status != null) _addAssignment(body, 'status', pkg.status!);
    if (pkg.timestamp != null) {
      _addAssignment(body, 'timestamp', pkg.timestamp!);
    }
    if (pkg.sha256 != null) _addAssignment(body, 'sha256', pkg.sha256!);

    return i3.Block('package', null, body);
  }

  i3.Block _buildScriptsBlock(String name, List<String> scripts) {
    final body = <i3.ConfigElement>[];
    for (final script in scripts) {
      // Use `run` as a descriptive command head for script entries.
      // The ScriptsBlockHandler ignores the head and only reads args.
      body.add(i3.Command('run', [_buildValue(script)]));
    }
    return i3.Block(name, null, body);
  }

  // ---------------------------------------------------------------------------
  // Value helpers
  // ---------------------------------------------------------------------------

  /// Build an appropriate [i3.Value] for a string.
  ///
  /// Simple alphanumeric values (with no spaces or special chars) are emitted
  /// as [i3.BareArg]; everything else is quoted with [i3.Quoted].
  i3.Value _buildValue(String value) {
    if (_needsQuoting(value)) {
      return i3.Quoted(_escapeQuotes(value), '"');
    }
    return i3.BareArg(value);
  }

  /// Build an [i3.Assignment] using a bare or quoted value.
  i3.Assignment _buildAssignment(String variable, String value) {
    return i3.Assignment(variable, i3.AssignmentOperator.assign, [
      _buildValue(value),
    ]);
  }

  void _addAssignment(
    List<i3.ConfigElement> body,
    String variable,
    String value,
  ) {
    body.add(_buildAssignment(variable, value));
  }

  static bool _needsQuoting(String value) {
    if (value.isEmpty) return true;
    // Check for characters that require quoting in i3 config
    for (var i = 0; i < value.length; i++) {
      final c = value.codeUnitAt(i);
      if (c == 0x20 /* space */ ||
          c == 0x09 /* tab */ ||
          c == 0x22 /* " */ ||
          c == 0x23 /* # */ ||
          c == 0x7b /* { */ ||
          c == 0x7d /* } */ ||
          c == 0x3b /* ; */ ) {
        return true;
      }
    }
    // Also quote if it starts with $ (potential variable ref confusion)
    if (value.startsWith(r'$')) return true;
    return false;
  }

  static String _escapeQuotes(String value) {
    return value.replaceAll('"', r'\"');
  }

  // ---------------------------------------------------------------------------
  // Serialization — i3 AST → formatted text
  // ---------------------------------------------------------------------------

  String _serializeConfig(i3.Config config) {
    final buf = StringBuffer();
    var first = true;
    for (final statement in config.statements) {
      if (!first) buf.writeln();
      first = false;
      _serializeElement(buf, statement, 0);
    }
    return buf.toString();
  }

  void _serializeElement(
    StringBuffer buf,
    i3.ConfigElement element,
    int indent,
  ) {
    switch (element) {
      case i3.Block block:
        _serializeBlock(buf, block, indent);
      case i3.Command cmd:
        _serializeCommand(buf, cmd, indent);
      case i3.Assignment assign:
        _serializeAssignment(buf, assign, indent);
      case i3.Comment comment:
        _serializeComment(buf, comment, indent);
      case i3.Config _:
        // Config nodes are handled at the top level.
        break;
    }
  }

  void _serializeBlock(StringBuffer buf, i3.Block block, int indent) {
    final prefix = ' ' * (indent * _indentSize);

    if (block.identifier != null) {
      buf.write(
        '$prefix${block.blockType} ${_valueToString(block.identifier!)} {',
      );
    } else {
      buf.write('$prefix${block.blockType} {');
    }

    if (block.body.isEmpty) {
      buf.writeln('}');
      return;
    }

    buf.writeln();
    for (final element in block.body) {
      _serializeElement(buf, element, indent + 1);
    }
    buf.writeln('$prefix}');
  }

  void _serializeCommand(StringBuffer buf, i3.Command cmd, int indent) {
    final prefix = ' ' * (indent * _indentSize);

    if (cmd.block != null) {
      // Command with block: `head arg {\n  ...\n}`
      buf.write('$prefix${cmd.head}');
      for (final arg in cmd.args) {
        buf.write(' ${_valueToString(arg)}');
      }
      buf.writeln(' {');
      for (final element in cmd.block!.body) {
        _serializeElement(buf, element, indent + 1);
      }
      buf.writeln('$prefix}');
    } else {
      // Simple command: `head arg1 arg2`
      buf.write('$prefix${cmd.head}');
      for (final arg in cmd.args) {
        buf.write(' ${_valueToString(arg)}');
      }
      buf.writeln();
    }
  }

  void _serializeAssignment(
    StringBuffer buf,
    i3.Assignment assign,
    int indent,
  ) {
    final prefix = ' ' * (indent * _indentSize);
    buf.write('$prefix${assign.variable} ${assign.operator}');
    for (final value in assign.values) {
      buf.write(' ${_valueToString(value)}');
    }
    buf.writeln();
  }

  void _serializeComment(StringBuffer buf, i3.Comment comment, int indent) {
    final prefix = ' ' * (indent * _indentSize);
    buf.writeln('$prefix# ${comment.content}');
  }

  /// Convert an i3 Value to its string representation.
  String _valueToString(i3.Value value) {
    return switch (value) {
      i3.Quoted q => '"${q.value}"',
      i3.BareArg b => b.value,
      i3.VariableRef v => '\$${v.name}',
    };
  }
}
