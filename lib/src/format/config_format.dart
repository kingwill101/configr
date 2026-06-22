/// Configr Format Boundary
///
/// Abstract reader/writer interfaces and the i3-format implementation.
///
/// The format boundary separates the storage format (i3 syntax, JSON, YAML)
/// from the domain processing. Currently only i3 syntax is supported;
/// future formats implement [ConfigReader] / [ConfigWriter] and register
/// with [FormatService].
library;

export 'config_reader.dart';
export 'config_source.dart';
export 'config_writer.dart';
export 'format_service.dart';
