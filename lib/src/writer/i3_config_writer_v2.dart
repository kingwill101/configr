import 'package:configr/src/blocks/action_block.dart';
import 'package:i3config/i3config_v2.dart' as i3;

/// Serializes a list of [ActionBlock] instances back to i3-format text.
///
/// This is the v2 counterpart of [I3ConfigWriter]. It takes parsed and
/// executed `ActionBlock` objects (from the v2 pipeline) and produces
/// formatted i3 config text so that `configr format` can round-trip
/// a config file through parse → execute → serialize.
///
/// ## Output format
///
/// Every block is emitted as an i3 `Block` node:
/// ```i3
/// copy {
///   source = "/src/file.txt"
///   destination = "/dst/file.txt"
///   recursive = true
///   include = "*.dart"
/// }
/// ```
///
/// Common properties (`id`, `source`, `destination`, `type`, `sha256`)
/// are emitted as `Assignment` nodes. Subclass-specific properties are
/// collected from the block's public fields via [writeAdditionalProperties].
///
class I3ConfigWriterV2 {
  /// Indent size in spaces.
  static const _indentSize = 2;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Serialize a list of [ActionBlock]s to formatted i3 text.
  String writeBlocks(List<ActionBlock> blocks) {
    final statements = blocks.map(_buildBlock).toList();
    final ast = i3.Config(statements);
    return _serializeConfig(ast);
  }

  /// Serialize a single [ActionBlock] to formatted i3 text.
  String writeBlock(ActionBlock block) {
    return writeBlocks([block]);
  }

  // ---------------------------------------------------------------------------
  // AST building — ActionBlock → i3 Block
  // ---------------------------------------------------------------------------

  i3.Block _buildBlock(ActionBlock block) {
    final body = <i3.ConfigElement>[];

    // Common properties
    _addIfNotEmpty(body, 'id', block.id);
    _addIfNotEmpty(body, 'source', block.source);
    _addIfNotEmpty(body, 'destination', block.destination);
    if (block.type != null && block.type!.isNotEmpty) {
      _addAssignment(body, 'type', block.type!);
    }
    if (block.status != null && block.status!.isNotEmpty) {
      _addAssignment(body, 'status', block.status!);
    }
    if (block.sha256 != null && block.sha256!.isNotEmpty) {
      _addAssignment(body, 'sha256', block.sha256!);
    }

    // Let subclasses write additional block-specific properties.
    writeAdditionalProperties(block, body);

    // Children (nested action blocks)
    for (final child in block.children) {
      body.add(_buildBlock(child));
    }

    return i3.Block(block.blockType, null, body);
  }

  // ---------------------------------------------------------------------------
  // Subclass extension point
  // ---------------------------------------------------------------------------

  /// Override in subclasses to emit type-specific properties.
  ///
  /// Called by [_buildBlock] after common properties have been written.
  /// Subclasses should add [i3.Assignment] or [i3.Block] elements to [body].
  ///
  /// ```dart
  /// @override
  /// void writeAdditionalProperties(ActionBlock block, List<ConfigElement> body) {
  ///   if (block is EchoBlock) {
  ///     _addIfNotEmpty(body, 'message', block.message);
  ///     _addIfNotEmpty(body, 'level', block.level);
  ///   }
  /// }
  /// ```
  void writeAdditionalProperties(
    ActionBlock block,
    List<i3.ConfigElement> body,
  ) {
    // Write string properties
    for (final entry in block.additionalProperties.entries) {
      if (entry.value.isNotEmpty) {
        _addAssignment(body, entry.key, entry.value);
      }
    }

    // Write boolean properties
    for (final entry in block.additionalBoolProperties.entries) {
      if (entry.value) {
        _addAssignment(body, entry.key, 'true');
      } else {
        _addAssignment(body, entry.key, 'false');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Value helpers
  // ---------------------------------------------------------------------------

  /// Build an appropriate [i3.Value] for a string.
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

  void _addIfNotEmpty(
    List<i3.ConfigElement> body,
    String variable,
    String value,
  ) {
    if (value.isNotEmpty) {
      _addAssignment(body, variable, value);
    }
  }

  static bool _needsQuoting(String value) {
    if (value.isEmpty) return true;
    // Always quote values that contain these characters
    for (var i = 0; i < value.length; i++) {
      final c = value.codeUnitAt(i);
      if (c == 0x20 /* space */ ||
          c == 0x09 /* tab */ ||
          c == 0x22 /* " */ ||
          c == 0x23 /* # */ ||
          c == 0x2a /* * */ ||
          c == 0x3f /* ? */ ||
          c == 0x5b /* [ */ ||
          c == 0x5d /* ] */ ||
          c == 0x7b /* { */ ||
          c == 0x7d /* } */ ||
          c == 0x3b /* ; */ ) {
        return true;
      }
    }
    // Quote if starts with $ (potential variable ref confusion)
    if (value.startsWith(r'$')) return true;
    // Quote paths that start with / or ~
    if (value.startsWith('/') || value.startsWith('~')) return true;
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

  String _valueToString(i3.Value value) => value.toConfigString();
}
