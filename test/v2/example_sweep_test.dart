import 'dart:io';

import 'package:file/local.dart';
import 'package:test/test.dart';

import 'package:configr/src/blocks/v2_apply.dart';
import 'package:configr/src/utils/event_bus.dart';

/// Sweeps through all example directories and verifies each config
/// parses and processes correctly with the v2 ActionBlock pipeline.
///
/// Each example config is:
///   1. Parsed and processed (dry-run, no file changes)
///   2. Checked for parse errors
///   3. Tested for basic block collection
void main() {
  final fs = const LocalFileSystem();
  final examplesDir = fs.directory('${Directory.current.path}/examples');

  for (final entry in examplesDir.listSync(followLinks: false)) {
    if (entry is! Directory) continue;
    final exampleName = entry.path.split('/').last;

    // Skip internal/private directories (starting with _)
    if (exampleName.startsWith('_')) {
      continue;
    }

    test('example: $exampleName parses with', () async {
      // Find the config file — could be named 'config', 'config.i3',
      // or have the example name without extension.
      File? configFile;
      for (final candidate in [
        '${entry.path}/config',
        '${entry.path}/config.i3',
        '${entry.path}/$exampleName.i3',
      ]) {
        final f = fs.file(candidate);
        if (await f.exists()) {
          configFile = f;
          break;
        }
      }

      if (configFile == null) {
        // Some examples don't have config files (e.g. test helpers)
        markTestSkipped('No config file found in $exampleName');
        return;
      }

      try {
        final blocks = await parseAndCollectBlocks(
          configFile.path,
          eventBus: EventBus(),
        );
        expect(blocks, isA<List>());
        // Blocks may be empty for some configs — that's fine.
      } catch (e) {
        fail('Failed to parse $exampleName: $e');
      }
    });
  }
}
