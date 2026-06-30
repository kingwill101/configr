import 'package:configr/src/format/config_source.dart';
import 'package:i3config/i3config_v2.dart' as i3;

/// Reads configuration text into an i3config v2 [i3.Config] AST.
///
/// Implementations handle the format-specific parsing (i3 syntax, JSON, YAML)
/// and produce a uniform [i3.Config] AST that the processor pipeline can
/// traverse.  Domain-specific transformations (i3.Config → domain models,
/// i3.Config → ActionBlock execution) are handled separately.
///
/// ## Why i3.Config as the common AST?
///
/// The [i3.Config] AST is the shared intermediate representation that both
/// the v1 pipeline (I3ConfigReader → Config domain model) and the v2 pipeline
/// (i3.ConfigProcessor → ActionBlock execution) consume.  By defining the
/// format boundary at this level, future JSON/YAML/etc. readers only need to
/// produce [i3.Config] — they get all downstream processing for free.
abstract class ConfigReader {
  /// Read configuration from [source] and return the parsed [i3.Config] AST.
  Future<i3.Config> read(ConfigSource source);
}

/// The default i3-format reader that delegates to [i3.Config.parse].
class I3FormatReader extends ConfigReader {
  I3FormatReader();

  @override
  Future<i3.Config> read(ConfigSource source) async {
    final content = await source.readContent();
    return i3.Config.parse(content, url: source.uri);
  }
}
