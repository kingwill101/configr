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

/// The default i3-format writer that delegates to the i3config package's
/// built-in [i3.ConfigFormatter] for proper formatting and escaping.
class I3FormatWriter extends ConfigWriter {
  final i3.FormatterOptions options;

  I3FormatWriter({i3.FormatterOptions? options})
    : options = options ?? const i3.FormatterOptions();

  @override
  String write(i3.Config config) {
    final formatter = i3.ConfigFormatter(options: options);
    return formatter.format(config);
  }
}
