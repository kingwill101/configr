import 'dart:convert';

import 'package:configr/src/models/config.dart';
import 'package:configr/src/reader/i3_config_reader.dart';
import 'package:configr/src/utils/fs.dart';
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
    ConfigFormat.i3 => await I3ConfigReader().read(
      contents,
      sourceUri: Uri.file(configPath),
    ),
  };
  return (config, format);
}

Future<void> updateConfig(
  String configPath,
  Config config, {
  ConfigFormat? format,
}) async {
  final file = fs.file(configPath);
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
      final writer = I3ConfigWriter();
      contents = writer.write(config);
      break;
  }

  await file.writeAsString(contents);
}
