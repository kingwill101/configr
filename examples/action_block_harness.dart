import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/blocks/copy_block.dart';
import 'package:i3config/i3config_v2.dart';

/// Demo entrypoint showing the new ActionBlock shape running through the
/// i3config v2 state machine.
///
/// Usage:
///   dart run examples/action_block_harness.dart
Future<void> main() async {
  // ---------------------------------------------------------------------------
  // 1. Create the v2 processor and seed the block collector
  // ---------------------------------------------------------------------------
  final processor = ConfigProcessor();
  processor.context.options['_actionBlocks'] = <ActionBlock>[];

  // ---------------------------------------------------------------------------
  // 2. Register the new block handlers
  // ---------------------------------------------------------------------------
  processor.registerBlockHandler(CopyBlock());

  // ---------------------------------------------------------------------------
  // 3. Parse and process a config snippet
  // ---------------------------------------------------------------------------
  final config = Config.parse('''
    copy {
      source = "/tmp/source.txt"
      destination = "/tmp/dest.txt"
      conflict_resolution = "overwrite"
      recursive = "true"
    }
  ''');

  print('=== Processing config through v2 state machine ===');
  await processor.process(config);
  print('✓ Processing complete\n');

  // ---------------------------------------------------------------------------
  // 4. Collect and execute populated blocks
  // ---------------------------------------------------------------------------
  final blocks =
      processor.context.options['_actionBlocks'] as List<ActionBlock>;

  print('=== Collected ${blocks.length} action block(s) ===\n');

  for (final block in blocks) {
    print('Block type  : ${block.blockType}');
    print('  id        : ${block.id}');
    print('  source    : ${block.source}');
    print('  dest      : ${block.destination}');
    print('  status    : ${block.status}');

    if (block is CopyBlock) {
      print('  recursive : ${block.recursive}');
      print('  conflict  : ${block.conflictResolution}');
      print('  patterns  :');
      print('    include: ${block.includePatterns}');
      print('    exclude: ${block.excludePatterns}');
    }

    print('');

    // Execute the block (will fail with SourceNotFoundException since
    // /tmp/source.txt doesn't exist — that's expected in this demo).
    try {
      await block.execute();
    } catch (e) {
      // In a real runner you'd handle errors gracefully.
      // Here we just report and continue.
      print('  ⚠ execute() threw: $e');
    }

    print('');
  }

  print('=== Done ===');
}
