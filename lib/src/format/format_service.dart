import 'package:configr/src/format/config_reader.dart';
import 'package:configr/src/format/config_source.dart';
import 'package:configr/src/format/config_writer.dart';
import 'package:i3config/i3config_v2.dart' as i3;

/// Resolves file paths to [ConfigReader] and [ConfigWriter] instances.
///
/// Currently only supports i3-format files (extensionless `config` files,
/// `.i3`, `.conf`). The API shape is designed to be extended with JSON/YAML
/// readers when those are added.
class FormatService {
  /// The default i3-format reader.
  final ConfigReader i3Reader;

  /// The default i3-format writer.
  final ConfigWriter i3Writer;

  FormatService({ConfigReader? i3Reader, ConfigWriter? i3Writer})
    : i3Reader = i3Reader ?? I3FormatReader(),
      i3Writer = i3Writer ?? I3FormatWriter();

  /// Resolve a reader for [path] based on its extension.
  ///
  /// Currently always returns the i3 reader (supports extensionless,
  /// `.i3`, `.conf`).
  ConfigReader readerFor(String path) {
    final ext = _extension(path);
    if (ext == '.json' || ext == '.yaml' || ext == '.yml') {
      // Future: return JSON/YAML reader when implemented.
    }
    return i3Reader;
  }

  /// Resolve a writer for [path] based on its extension.
  ///
  /// Currently always returns the i3 writer.
  ConfigWriter writerFor(String path) {
    return i3Writer;
  }

  /// Read configuration from [source] using the appropriate reader.
  Future<i3.Config> readConfig(ConfigSource source) {
    final reader = source.path != null ? readerFor(source.path!) : i3Reader;
    return reader.read(source);
  }

  /// Write [config] to [sink] using the appropriate writer.
  Future<void> writeConfig(i3.Config config, ConfigSink sink) {
    final writer = sink.path != null ? writerFor(sink.path!) : i3Writer;
    return writer.writeTo(config, sink);
  }

  /// Serialize [config] to formatted text using the i3 writer.
  String serialize(i3.Config config) => i3Writer.write(config);

  /// Returns true if [path] is an i3-format file.
  static bool isI3File(String path) {
    final ext = _extension(path);
    return ext.isEmpty || ext == '.i3' || ext == '.conf';
  }

  /// Returns true if [path] is a supported config file.
  static bool isSupported(String path) {
    final ext = _extension(path);
    return ext.isEmpty ||
        ext == '.i3' ||
        ext == '.conf' ||
        ext == '.json' ||
        ext == '.yaml' ||
        ext == '.yml';
  }

  /// Extract the extension from a path (including the dot).
  static String _extension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return '';
    // Ignore dotfiles like `.bashrc` — only treat as extension if
    // there's something before the dot.
    if (dot == 0) return '';
    return path.substring(dot);
  }
}
