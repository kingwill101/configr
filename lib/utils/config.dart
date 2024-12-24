import 'dart:convert';

import 'package:configr/models/config.dart';
import 'package:configr/utils/config_reader.dart';
import 'package:configr/utils/fs.dart' show fs;
import 'package:file/file.dart' show FileSystemException, FileSystem;

enum ConfigFormat { json, i3 }

ConfigFormat detectFileFormat(String contents) {
  contents = contents.trim();
  if (contents.startsWith('{') && contents.endsWith('}')) {
    return ConfigFormat.json;
  } else {
    return ConfigFormat.i3;
  }
}

Future<(Config, ConfigFormat)> loadConfig(String configPath,
    {FileSystem? fileSystem}) async {
  final file = (fileSystem ?? fs).file(configPath);
  if (!await file.exists()) {
    throw FileSystemException('Configuration file not found', configPath);
  }
  final contents = await file.readAsString();
  final format = detectFileFormat(contents);

  final config = switch (format) {
    ConfigFormat.json =>
      Config.fromJson(jsonDecode(contents) as Map<String, dynamic>),
    ConfigFormat.i3 => parseConfig(contents),
  };
  return (config, format);
}

Future<void> updateConfig(String configPath, Config config,
    {ConfigFormat? format}) async {
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
      contents = config.toConfig();
      break;
  }

  await file.writeAsString(contents);
}
