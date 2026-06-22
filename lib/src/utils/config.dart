import 'dart:convert';

import 'package:configr/src/format/config_source.dart';

import 'package:configr/src/format/format_service.dart';
import 'package:configr/src/models/config.dart';
import 'package:configr/src/reader/config_builder.dart';
import 'package:configr/src/reader/handlers/configr_handlers.dart';
import 'package:configr/src/writer/i3_config_writer.dart';
import 'package:file/file.dart' show FileSystemException, FileSystem;
import 'package:file/local.dart';

enum ConfigFormat { json, i3 }

ConfigFormat detectFileFormat(String contents) {
  contents = contents.trim();
  if (contents.startsWith('{') && contents.endsWith('}')) {
    return ConfigFormat.json;
  } else {
    return ConfigFormat.i3;
  }
}

Future<(Config, ConfigFormat)> loadConfig(
  String configPath, {
  FileSystem? fileSystem,
}) async {
  final fsInstance = fileSystem ?? LocalFileSystem();
  final file = fsInstance.file(configPath);
  if (!await file.exists()) {
    throw FileSystemException('Configuration file not found', configPath);
  }
  final contents = await file.readAsString();
  final format = detectFileFormat(contents);

  final config = switch (format) {
    ConfigFormat.json => Config.fromJson(
      jsonDecode(contents) as Map<String, dynamic>,
    ),
    ConfigFormat.i3 => await _loadI3ViaFormatService(configPath, fsInstance),
  };
  return (config, format);
}

/// Load an i3 config through the [FormatService] boundary.
///
/// Uses [FormatService.readConfig] to parse the text into an `i3.Config` AST,
/// then converts to the v1 [Config] domain model via [ConfigBuilder] + the
/// same handler pipeline used by [I3ConfigReader].
Future<Config> _loadI3ViaFormatService(
  String configPath,
  FileSystem fileSystem,
) async {
  final formatService = FormatService();
  final source = ConfigSource.fromPath(configPath, fileSystem: fileSystem);
  final i3Config = await formatService.readConfig(source);

  // Convert i3.Config AST → v1 Config domain model
  final builder = ConfigBuilder();
  final processor = createConfigrProcessor(builder);
  await processor.process(i3Config);
  return builder.build();
}

Future<void> updateConfig(
  String configPath,
  Config config, {
  ConfigFormat? format,
  FileSystem? fileSystem,
}) async {
  final localFs = fileSystem ?? LocalFileSystem();
  format ??= configPath.toLowerCase().endsWith('.json')
      ? ConfigFormat.json
      : ConfigFormat.i3;

  String contents;
  switch (format) {
    case ConfigFormat.json:
      final encoder = JsonEncoder.withIndent('  ');
      contents = encoder.convert(config.toJson());
      break;
    case ConfigFormat.i3:
      contents = await _writeI3ViaFormatService(configPath, config, localFs);
      break;
  }

  await localFs.file(configPath).writeAsString(contents);
}

/// Write an i3 config through the [FormatService] boundary.
///
/// Converts the v1 [Config] domain model to an `i3.Config` AST via
/// [I3ConfigWriter.buildConfigAst], then serializes via
/// [FormatService.writeConfig].
Future<String> _writeI3ViaFormatService(
  String configPath,
  Config config,
  FileSystem fileSystem,
) async {
  final formatService = FormatService();
  final writer = I3ConfigWriter();
  final i3Config = writer.buildConfigAst(config);
  final sink = ConfigSink.fromPath(configPath, fileSystem: fileSystem);
  await formatService.writeConfig(i3Config, sink);
  return formatService.serialize(i3Config);
}
