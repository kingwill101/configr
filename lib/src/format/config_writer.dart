import 'package:configr/src/format/config_source.dart';
import 'package:i3config/i3config_v2.dart' as i3;

/// Writes configuration to formatted text.
///
/// Implementations serialize an [i3.Config] AST to format-specific text
/// (i3 syntax, JSON, YAML, etc.).
abstract class ConfigWriter {
  /// Serialize [config] to format-specific text.
  String write(i3.Config config);

  /// Serialize and write [config] to [sink].
  Future<void> writeTo(i3.Config config, ConfigSink sink) {
    return sink.writeContent(write(config));
  }
}

/// The default i3-format writer that serializes [i3.Config] AST to text.
class I3FormatWriter extends ConfigWriter {
  I3FormatWriter();

  @override
  String write(i3.Config config) {
    // Collect all blocks from the config AST into a flat list for the v2
    // writer. This is a simplified approach — a full round-trip writer would
    // preserve comments and non-block elements.
    final buf = StringBuffer();
    _serializeConfig(buf, config);
    return buf.toString();
  }

  void _serializeConfig(StringBuffer buf, i3.Config config) {
    var first = true;
    for (final statement in config.statements) {
      if (!first) buf.writeln();
      first = false;
      _serializeElement(buf, statement, 0);
    }
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
    final prefix = ' ' * (indent * 2);
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
    final prefix = ' ' * (indent * 2);
    buf.write('$prefix${cmd.head}');
    for (final arg in cmd.args) {
      buf.write(' ${_valueToString(arg)}');
    }
    if (cmd.block != null) {
      buf.writeln(' {');
      for (final element in cmd.block!.body) {
        _serializeElement(buf, element, indent + 1);
      }
      buf.writeln('$prefix}');
    } else {
      buf.writeln();
    }
  }

  void _serializeAssignment(
    StringBuffer buf,
    i3.Assignment assign,
    int indent,
  ) {
    final prefix = ' ' * (indent * 2);
    buf.write('$prefix${assign.variable} ${assign.operator}');
    for (final value in assign.values) {
      buf.write(' ${_valueToString(value)}');
    }
    buf.writeln();
  }

  void _serializeComment(StringBuffer buf, i3.Comment comment, int indent) {
    final prefix = ' ' * (indent * 2);
    buf.writeln('$prefix# ${comment.content}');
  }

  String _valueToString(i3.Value value) {
    return switch (value) {
      i3.Quoted q => '"${q.value}"',
      i3.BareArg b => b.value,
      i3.VariableRef v => '\$${v.name}',
      i3.ArrayValue a =>
        '[${a.items.map((e) => _valueToString(e)).join(', ')}]',
    };
  }
}
